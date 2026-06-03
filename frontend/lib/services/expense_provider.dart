import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'api_service.dart';
import 'sync_service.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/payment_detail.dart';

class ExpenseProvider with ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _apiService = ApiService.instance;
  final _syncService = SyncService.instance;

  List<Expense> _expenses = [];
  List<Budget> _budgets = [];
  List<PaymentDetail> _paymentDetails = [];
  
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _syncErrorMessage;

  DateTime _selectedMonthYear = DateTime(DateTime.now().year, DateTime.now().month);

  // Exchange Rates (1 INR = X of target currency)
  final Map<String, double> _exchangeRates = {
    'INR': 1.0,
    'USD': 0.012,
    'EUR': 0.011,
    'GBP': 0.0094,
    'AUD': 0.018,
    'CAD': 0.016,
  };

  Map<String, double> get exchangeRates => _exchangeRates;

  ExpenseProvider() {
    initExchangeRates();
  }

  double convertToINR(double amount, String currency) {
    final rate = _exchangeRates[currency.toUpperCase()] ?? 1.0;
    if (rate == 0.0) return amount;
    return amount / rate;
  }

  Future<void> initExchangeRates() async {
    // 1. Load cached rates
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRatesStr = prefs.getString('cached_exchange_rates');
      if (cachedRatesStr != null) {
        final decoded = json.decode(cachedRatesStr) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          _exchangeRates[key] = (value as num).toDouble();
        });
      }
    } catch (e) {
      print('Error loading cached exchange rates: $e');
    }

    // 2. Fetch fresh rates in background
    fetchFreshExchangeRates();
  }

  Future<void> fetchFreshExchangeRates() async {
    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/INR')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['result'] == 'success' && decoded['rates'] != null) {
          final rates = decoded['rates'] as Map<String, dynamic>;
          final List<String> supported = ['INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD'];
          Map<String, double> newRates = {};
          for (final curr in supported) {
            if (rates[curr] != null) {
              final val = (rates[curr] as num).toDouble();
              newRates[curr] = val;
              _exchangeRates[curr] = val;
            }
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_exchange_rates', json.encode(newRates));
          notifyListeners();
          print('[Rates] Successfully updated exchange rates from API.');
        }
      }
    } catch (e) {
      print('[Rates] Failed to fetch live exchange rates: $e');
    }
  }

  List<Expense> get expenses => _expenses;
  List<Budget> get budgets => _budgets;
  List<PaymentDetail> get paymentDetails => _paymentDetails;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get syncErrorMessage => _syncErrorMessage;
  DateTime get selectedMonthYear {
    final now = DateTime.now();
    if (_selectedMonthYear.year != now.year || _selectedMonthYear.month != now.month) {
      _selectedMonthYear = DateTime(now.year, now.month);
      Future.microtask(() => notifyListeners());
    }
    return _selectedMonthYear;
  }

  void setSelectedMonthYear(DateTime value) {
    if (_selectedMonthYear.year != value.year || _selectedMonthYear.month != value.month) {
      _selectedMonthYear = DateTime(value.year, value.month);
      notifyListeners();
    }
  }

  // 1. Initial Load of SQLite Caches
  Future<void> loadLocalData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _expenses = await _dbHelper.getExpenses();
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      _syncErrorMessage = null;
    } catch (e) {
      print('Error loading offline SQLite caches: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= EXPENSES OPERATIONS =================

  Future<void> addExpense({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    String currency = 'INR',
    bool isRecurring = false,
    String recurrencePeriod = 'none',
    String? receiptUrl,
  }) async {
    final expense = Expense(
      id: cryptoUuid(),
      amount: amount,
      category: category,
      description: description,
      transactionDate: date,
      currency: currency,
      isRecurring: isRecurring,
      recurrencePeriod: recurrencePeriod,
      receiptUrl: receiptUrl,
    );

    // Save locally instantly for high performance
    await _dbHelper.insertExpense(expense);
    _expenses.insert(0, expense);
    notifyListeners();

    // Trigger quiet background sync
    triggerQuietSync();
  }

  Future<void> editExpense(Expense updatedExpense) async {
    await _dbHelper.updateExpense(updatedExpense);
    final idx = _expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (idx != -1) {
      _expenses[idx] = updatedExpense;
      notifyListeners();
    }
    triggerQuietSync();
  }

  Future<void> deleteExpense(String id) async {
    await _dbHelper.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> deleteMultipleExpenses(List<String> ids) async {
    for (final id in ids) {
      await _dbHelper.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
    }
    notifyListeners();
    triggerQuietSync();
  }

  // ================= BUDGETS OPERATIONS =================

  Future<void> setBudget({
    required String category,
    required double amountLimit,
    required String monthYear,
  }) async {
    // Check if category budget already exists for this month
    final existingIdx = _budgets.indexWhere((b) => b.category == category && b.monthYear == monthYear);

    if (existingIdx != -1) {
      final updated = _budgets[existingIdx].copyWith(amountLimit: amountLimit, isDeleted: false, updatedAt: DateTime.now());
      await _dbHelper.updateBudget(updated);
      _budgets[existingIdx] = updated;
    } else {
      final budget = Budget(
        id: cryptoUuid(),
        category: category,
        amountLimit: amountLimit,
        monthYear: monthYear,
      );
      await _dbHelper.insertBudget(budget);
      _budgets.add(budget);
    }
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> deleteBudget(String id) async {
    await _dbHelper.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
    triggerQuietSync();
  }

  // ================= PAYMENT DETAILS OPERATIONS =================

  Future<void> savePaymentDetails({
    required String upiId,
    String? qrCodeUrl,
  }) async {
    // Simple logic: we only support one active payment profile per user
    await _dbHelper.clearTable('payment_details'); // Custom wipe, or clean insertion
    final db = await _dbHelper.database;
    await db.delete('payment_details'); // Direct clear

    final detail = PaymentDetail(
      id: cryptoUuid(),
      upiId: upiId,
      qrCodeUrl: qrCodeUrl,
    );

    await _dbHelper.insertPaymentDetail(detail);
    _paymentDetails = [detail];
    notifyListeners();
    triggerQuietSync();
  }

  // ================= SMART OCR & STATEMENT IMPORTING ACTIONS =================

  // Smart receipt OCR scanner trigger with fast image compressor
  Future<Map<String, dynamic>?> scanReceiptOCR(String imagePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      String finalPath = imagePath;
      try {
        final file = File(imagePath);
        final bytes = await file.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image != null) {
          // Downscale to max 1024px width for highly legible text at minimal file size
          final resized = img.copyResize(image, width: image.width > 1024 ? 1024 : image.width);
          final compressedBytes = img.encodeJpg(resized, quality: 75);
          
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/compressed_ocr.jpg');
          await tempFile.writeAsBytes(compressedBytes);
          finalPath = tempFile.path;
          
          final originalKB = bytes.lengthInBytes / 1024;
          final compressedKB = compressedBytes.lengthInBytes / 1024;
          print('OCR image compressed: ${originalKB.toStringAsFixed(1)} KB -> ${compressedKB.toStringAsFixed(1)} KB');
        }
      } catch (e) {
        print('Image compressor bypassed: $e');
      }

      final result = await _apiService.scanReceipt(finalPath);
      if (result['success'] == true) {
        return result['data']; // Extracted JSON fields
      } else {
        _syncErrorMessage = result['error'];
        return null;
      }
    } catch (e) {
      _syncErrorMessage = 'OCR scanning network error.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // File parsing (Excel/PDF) batch import trigger
  Future<String?> importStatement(String filePath, {String? password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.importStatement(filePath, password: password);
      if (result['success'] == true) {
        final List<dynamic> importedList = result['expenses'] ?? [];
        for (final item in importedList) {
          final Map<String, dynamic> mutableItem = Map<String, dynamic>.from(item);
          if (mutableItem['id'] == null) {
            mutableItem['id'] = cryptoUuid();
          }
          final exp = Expense.fromMap(mutableItem);
          await _dbHelper.insertExpense(exp, preventDuplicates: true);
        }
        await loadLocalData(); // Reload cache
        triggerQuietSync();
        return 'success';
      }
      _syncErrorMessage = result['message'] ?? result['error'];
      return result['error'];
    } catch (e) {
      _syncErrorMessage = 'Importing error: $e';
      return 'error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Invoice generate download PDF path helper
  Future<String?> downloadInvoice(List<String> expenseIds) async {
    _isSyncing = true;
    notifyListeners();
    final path = await _apiService.generateInvoice(expenseIds);
    _isSyncing = false;
    notifyListeners();
    return path;
  }

  // ================= SYSTEM SYNC ROUTINES =================

  // Quiet Sync (Fails silently without locking screen loader)
  Future<void> triggerQuietSync() async {
    await _syncService.synchronize();
    // Silently refresh state caches with any backend additions
    _expenses = await _dbHelper.getExpenses();
    _budgets = await _dbHelper.getBudgets();
    _paymentDetails = await _dbHelper.getPaymentDetails();
    notifyListeners();
  }

  // Active Sync (Triggers screen-level loader spinner)
  Future<bool> triggerManualSync() async {
    _isSyncing = true;
    _syncErrorMessage = null;
    notifyListeners();

    final result = await _syncService.synchronize();
    
    // Refresh local lists
    _expenses = await _dbHelper.getExpenses();
    _budgets = await _dbHelper.getBudgets();
    _paymentDetails = await _dbHelper.getPaymentDetails();

    if (!result) {
      _syncErrorMessage = 'Synchronization offline. Caches saved locally.';
    }

    _isSyncing = false;
    notifyListeners();
    return result;
  }

  // Wipe databases on sign-out
  Future<void> clearAllDataOnSignout() async {
    await _dbHelper.clearAllData();
    await _syncService.clearSyncTime();
    _expenses.clear();
    _budgets.clear();
    _paymentDetails.clear();
    notifyListeners();
  }

  // Calculate total expense of all months older than the current month
  double getOldExpensesTotal() {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    
    double total = 0.0;
    for (final exp in _expenses) {
      if (exp.transactionDate.isBefore(currentMonthStart)) {
        total += convertToINR(exp.amount, exp.currency);
      }
    }
    return total;
  }

  // Delete all local and remote expenses older than the current month
  Future<bool> deleteOldExpenses() async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // 1. Delete from remote database via API
      final result = await _apiService.deleteOldExpenses();
      
      // 2. Delete from local SQLite database
      await _dbHelper.deleteOldExpenses(currentMonthStart);
      
      // 3. Clear from in-memory list
      _expenses.removeWhere((e) => e.transactionDate.isBefore(currentMonthStart));
      
      // 4. Update the stored month/year key in shared preferences
      final prefs = await SharedPreferences.getInstance();
      final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await prefs.setString('last_known_month_year', currentMonthStr);
      
      _syncErrorMessage = null;
      notifyListeners();
      return result['success'] == true;
    } catch (e) {
      print('Error clearing old month data: $e');
      _syncErrorMessage = 'Clear old month data failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper UUID Generator for offline primary keys
  String cryptoUuid() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           '-' + 
           (100000 + (900000 * (DateTime.now().microsecond / 1000000))).toInt().toString();
  }
}
extension on DatabaseHelper {
  Future<void> clearTable(String name) async {}
}
