import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
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

  List<Expense> get expenses => _expenses;
  List<Budget> get budgets => _budgets;
  List<PaymentDetail> get paymentDetails => _paymentDetails;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get syncErrorMessage => _syncErrorMessage;

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
  Future<bool> importStatement(String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.importStatement(filePath);
      if (result['success'] == true) {
        final List<dynamic> importedList = result['expenses'] ?? [];
        for (final item in importedList) {
          final exp = Expense.fromMap(item);
          await _dbHelper.insertExpense(exp);
        }
        await loadLocalData(); // Reload cache
        triggerQuietSync();
        return true;
      }
      _syncErrorMessage = result['error'];
      return false;
    } catch (e) {
      _syncErrorMessage = 'Importing error: $e';
      return false;
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
