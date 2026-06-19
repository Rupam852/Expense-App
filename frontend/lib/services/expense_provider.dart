import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'supabase_service.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import 'package:csv/csv.dart';
import '../models/payment_detail.dart';


class ExpenseProvider with ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _supabase = SupabaseService.instance;

  List<Expense> _expenses = [];
  List<Budget> _budgets = [];
  List<PaymentDetail> _paymentDetails = [];

  final List<String> _categories = [
    'Shopping',
    'Groceries',
    'Food & dining',
    'Transport',
    'Bills & recharges',
    'Transfers',
    'Medical',
    'Travel',
    'Repayments',
    'Personal',
    'Services',
    'Insurance',
    'Entertainment',
    'Gaming',
    'Small shops',
    'Rent',
    'Logistics',
    'Subscription',
    'Investment',
    'Fitness',
    'Pet',
    'Miscellaneous',
  ];

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
    loadLocalData();
  }

  double convertToINR(double amount, String currency) {
    final rate = _exchangeRates[currency.toUpperCase()] ?? 1.0;
    if (rate == 0.0) return amount;
    return amount / rate;
  }

  Future<void> initExchangeRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRatesStr = prefs.getString('cached_exchange_rates');
      if (cachedRatesStr != null) {
        final decoded = json.decode(cachedRatesStr) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          _exchangeRates[key] = (value as num).toDouble();
        });
      }
    } catch (_) {}
    fetchFreshExchangeRates();
  }

  Future<void> fetchFreshExchangeRates() async {
    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/INR'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['result'] == 'success' && decoded['rates'] != null) {
          final rates = decoded['rates'] as Map<String, dynamic>;
          const supported = ['INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD'];
          final newRates = <String, double>{};
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
        }
      }
    } catch (_) {}
  }

  List<Expense> get expenses => _expenses;
  List<Budget> get budgets => _budgets;
  List<PaymentDetail> get paymentDetails => _paymentDetails;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get syncErrorMessage => _syncErrorMessage;

  DateTime get selectedMonthYear => _selectedMonthYear;

  void setSelectedMonthYear(DateTime value) {
    if (_selectedMonthYear.year != value.year || _selectedMonthYear.month != value.month) {
      _selectedMonthYear = DateTime(value.year, value.month);
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────
  // LOAD LOCAL DATA
  // ──────────────────────────────────────────────────────
  Future<void> loadLocalData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _expenses = await _dbHelper.getExpenses();
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      _syncErrorMessage = null;

      // Auto-deduplicate local cached expenses on startup
      await deduplicateExpenses(triggerSync: true);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // EXPENSES
  // ──────────────────────────────────────────────────────
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
    await _dbHelper.insertExpense(expense);
    _expenses.insert(0, expense);
    notifyListeners();
    // Silent background sync after adding
    triggerQuietSync();
  }

  Future<void> editExpense(Expense updatedExpense) async {
    await _dbHelper.updateExpense(updatedExpense);
    final idx = _expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (idx != -1) {
      _expenses[idx] = updatedExpense;
      notifyListeners();
    }
    // Silent background sync after editing
    triggerQuietSync();
  }

  Future<void> deleteExpense(String id) async {
    await _dbHelper.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> restoreExpense(Expense expense) async {
    await _dbHelper.clearSyncedDeletions([expense.id]);
    await _dbHelper.insertExpense(expense);
    _expenses.insert(0, expense);
    _expenses.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> deleteMultipleExpenses(List<String> ids) async {
    for (final id in ids) {
      await _dbHelper.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
    }
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // BUDGETS
  // ──────────────────────────────────────────────────────
  Future<void> setBudget({
    required String category,
    required double amountLimit,
    required String monthYear,
  }) async {
    final existingIdx = _budgets.indexWhere((b) => b.category == category && b.monthYear == monthYear);
    if (existingIdx != -1) {
      final updated = _budgets[existingIdx].copyWith(amountLimit: amountLimit, isDeleted: false, updatedAt: DateTime.now());
      await _dbHelper.updateBudget(updated);
      _budgets[existingIdx] = updated;
    } else {
      final budget = Budget(id: cryptoUuid(), category: category, amountLimit: amountLimit, monthYear: monthYear);
      await _dbHelper.insertBudget(budget);
      _budgets.add(budget);
    }
    notifyListeners();
    // Silent background sync after budget set
    triggerQuietSync();
  }

  Future<void> deleteBudget(String id) async {
    await _dbHelper.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // PAYMENT DETAILS
  // ──────────────────────────────────────────────────────
  Future<void> savePaymentDetails({
    required String upiId,
    String? qrCodeUrl,
  }) async {
    final db = await _dbHelper.database;
    await db.delete('payment_details');

    final detail = PaymentDetail(
      id: cryptoUuid(),
      upiId: upiId,
      qrCodeUrl: qrCodeUrl,
    );
    await _dbHelper.insertPaymentDetail(detail);
    _paymentDetails = [detail];
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // RECEIPT OCR (via Supabase Edge Function)
  // ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> scanReceiptOCR(String imagePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Compress image first
      Uint8List imageBytes;
      try {
        final file = File(imagePath);
        final bytes = await file.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image != null) {
          final resized = img.copyResize(image, width: image.width > 1024 ? 1024 : image.width);
          imageBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
        } else {
          imageBytes = await file.readAsBytes();
        }
      } catch (_) {
        imageBytes = await File(imagePath).readAsBytes();
      }

      final result = await _supabase.scanReceipt(imageBytes);
      if (result['success'] == true) {
        return result['data'] as Map<String, dynamic>?;
      }
      _syncErrorMessage = result['error']?.toString();
      return null;
    } catch (e) {
      _syncErrorMessage = 'OCR scanning failed: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Statement import (using local CSV parsing)
  Future<String?> importStatement(String filePath, {String? password}) async {
    _isLoading = true;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      final file = File(filePath);
      final filename = file.path.toLowerCase();

      if (!filename.endsWith('.csv')) {
        _syncErrorMessage = 'Currently only CSV statement import is supported offline. Please convert your statement to CSV.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final csvString = await file.readAsString();
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.isEmpty) {
        _syncErrorMessage = 'The CSV file is empty.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Step 1: Detect column indices
      int dateIdx = -1;
      int amountIdx = -1;
      int descIdx = -1;
      int catIdx = -1;
      int currIdx = -1;

      // Scan first few rows to find headers
      for (int r = 0; r < rows.length && r < 5; r++) {
        final row = rows[r];
        for (int c = 0; c < row.length; c++) {
          final val = row[c].toString().toLowerCase().trim();
          if (val.contains('date') || val.contains('time')) dateIdx = c;
          if (val.contains('amount') || val.contains('spent') || val.contains('value')) amountIdx = c;
          if (val.contains('desc') || val.contains('narr') || val.contains('remarks') || val.contains('particulars')) descIdx = c;
          if (val.contains('cat') || val.contains('tag') || val.contains('type') || val.contains('group')) catIdx = c;
          if (val.contains('curr')) currIdx = c;
        }
        if (dateIdx != -1 && amountIdx != -1) {
          // Found headers! Skip preceding rows
          break;
        }
      }

      // Fallbacks if not detected
      if (dateIdx == -1) dateIdx = 0;
      if (amountIdx == -1) amountIdx = 1;
      if (descIdx == -1) descIdx = 2;

      // Auto-detect date format (DD/MM/YYYY vs MM/DD/YYYY) by scanning rows
      bool isMonthFirst = false;
      for (int r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.length <= dateIdx) continue;
        final rawDate = row[dateIdx].toString().trim();
        if (rawDate.isEmpty) continue;
        try {
          final cleanDateStr = rawDate.split(' ')[0].trim();
          final parts = cleanDateStr.split(RegExp(r'[/\-\.]'));
          if (parts.length == 3) {
            int part0 = int.parse(parts[0].trim());
            int part1 = int.parse(parts[1].trim());
            if (part0 > 12 && part0 <= 31 && part1 <= 12) {
              isMonthFirst = false; // DD/MM/YYYY
              break;
            }
            if (part1 > 12 && part1 <= 31 && part0 <= 12) {
              isMonthFirst = true; // MM/DD/YYYY
              break;
            }
          }
        } catch (_) {}
      }

      int importedCount = 0;
      final startRow = 1; // Assume row 0 is header

      for (int i = startRow; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= dateIdx || row.length <= amountIdx) continue;

        final rawDate = row[dateIdx].toString().trim();
        final rawAmount = row[amountIdx].toString().trim();
        if (rawDate.isEmpty || rawAmount.isEmpty) continue;

        // Parse date
        DateTime parsedDate;
        try {
          parsedDate = DateTime.parse(rawDate);
        } catch (_) {
          // Try custom formats or fallback to now
          try {
            // Clean date string (remove time if present like "18/06/2026 14:30")
            final cleanDateStr = rawDate.split(' ')[0].trim();
            final parts = cleanDateStr.split(RegExp(r'[/\-\.]'));
            if (parts.length == 3) {
              final monthsMap = {
                'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
                'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
                'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
                'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
              };

              int day = 1;
              int month = 1;
              int year = DateTime.now().year;

              // 1. Check for textual month first (e.g. Jun or June)
              int textualMonthIdx = -1;
              for (int pIdx = 0; pIdx < 3; pIdx++) {
                final pLower = parts[pIdx].toLowerCase().trim();
                if (monthsMap.containsKey(pLower)) {
                  textualMonthIdx = pIdx;
                  month = monthsMap[pLower]!;
                  break;
                }
              }

              if (textualMonthIdx != -1) {
                // Year is usually the one with length 4, or last part
                int yearPart = int.parse(parts[2].trim());
                if (yearPart < 100) yearPart += 2000;
                year = yearPart;

                if (textualMonthIdx == 0) {
                  day = int.parse(parts[1].trim());
                } else if (textualMonthIdx == 1) {
                  day = int.parse(parts[0].trim());
                }
              } else {
                // 2. Numerical parts only
                int part0 = int.parse(parts[0].trim());
                int part1 = int.parse(parts[1].trim());
                int part2 = int.parse(parts[2].trim());

                if (part0 > 1000) {
                  // Year is first: YYYY/MM/DD
                  year = part0;
                  month = part1;
                  day = part2;
                } else {
                  // Year is last
                  year = part2;
                  if (year < 100) year += 2000;

                  if (isMonthFirst) {
                    month = part0;
                    day = part1;
                  } else {
                    day = part0;
                    month = part1;
                  }
                }
              }

              // Constrain values to prevent invalid dates
              if (month < 1) month = 1;
              if (month > 12) month = 12;
              if (day < 1) day = 1;
              if (day > 31) day = 31;

              parsedDate = DateTime(year, month, day);
            } else {
              parsedDate = DateTime.now();
            }
          } catch (_) {
            parsedDate = DateTime.now();
          }
        }


        // Parse amount (support negative values or removing currency symbols)
        final cleanAmtStr = rawAmount.replaceAll(RegExp(r'[^\d\.\-]'), '');
        final amount = double.tryParse(cleanAmtStr) ?? 0.0;
        if (amount == 0.0) continue;

        // Description
        final description = row.length > descIdx ? row[descIdx].toString().trim() : 'Imported CSV Transaction';

        // Category matching
        String category = 'Others';
        if (catIdx != -1 && row.length > catIdx) {
          final rawCat = row[catIdx].toString().trim();
          
          // Helper to normalize strings for comparison (lowercase, handle 'and'/'&', strip special chars)
          String normalize(String s) {
            return s.toLowerCase()
                    .replaceAll('and', '&')
                    .replaceAll(RegExp(r'[^a-z0-9&]'), '')
                    .trim();
          }
          
          final normalizedRaw = normalize(rawCat);
          final matched = _categories.firstWhere(
            (c) => normalize(c) == normalizedRaw,
            orElse: () {
              // Try substring match as fallback
              return _categories.firstWhere(
                (c) => normalize(c).contains(normalizedRaw) || normalizedRaw.contains(normalize(c)),
                orElse: () => 'Others',
              );
            },
          );
          category = matched;
        } else {
          // Guess category from description
          category = _guessCategory(description);
        }

        // Currency
        String currency = 'INR';
        if (currIdx != -1 && row.length > currIdx) {
          final rawCurr = row[currIdx].toString().trim().toUpperCase();
          if (['INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD'].contains(rawCurr)) {
            currency = rawCurr;
          }
        }

        final now = DateTime.now();
        if (parsedDate.year != now.year || parsedDate.month != now.month) {
          // Skip transactions from other months
          continue;
        }

        final exp = Expense(
          id: cryptoUuid(),
          amount: amount.abs(), // expenses are positive values in UI
          currency: currency,
          category: category,
          description: description,
          transactionDate: parsedDate,
        );

        final insertResult = await _dbHelper.insertExpense(exp, preventDuplicates: true);
        if (insertResult != -1) {
          importedCount++;
        }
      }

      if (importedCount > 0) {
        _expenses = await _dbHelper.getExpenses();
        notifyListeners();
        _isLoading = false;
        notifyListeners();
        // Silent background sync after import
        triggerQuietSync();
        return 'Parsed $importedCount transactions successfully!';
      } else {
        _syncErrorMessage = 'No valid transactions found in the CSV file.';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _syncErrorMessage = 'Import failed: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  String _guessCategory(String desc) {
    final cleanDesc = desc.toLowerCase();
    if (cleanDesc.contains('shop') || cleanDesc.contains('zara') || cleanDesc.contains('amazon') || cleanDesc.contains('flipkart')) return 'Shopping';
    if (cleanDesc.contains('grocer') || cleanDesc.contains('supermarket') || cleanDesc.contains('blinkit') || cleanDesc.contains('instamart') || cleanDesc.contains('bigbasket')) return 'Groceries';
    if (cleanDesc.contains('food') || cleanDesc.contains('dining') || cleanDesc.contains('swiggy') || cleanDesc.contains('zomato') || cleanDesc.contains('restaurant') || cleanDesc.contains('cafe')) return 'Food & dining';
    if (cleanDesc.contains('cab') || cleanDesc.contains('taxi') || cleanDesc.contains('uber') || cleanDesc.contains('ola') || cleanDesc.contains('fuel') || cleanDesc.contains('petrol') || cleanDesc.contains('metro')) return 'Transport';
    if (cleanDesc.contains('bill') || cleanDesc.contains('recharge') || cleanDesc.contains('electricity') || cleanDesc.contains('water') || cleanDesc.contains('gas')) return 'Bills & recharges';
    if (cleanDesc.contains('transfer') || cleanDesc.contains('send') || cleanDesc.contains('paytm') || cleanDesc.contains('phonepe') || cleanDesc.contains('gpay')) return 'Transfers';
    if (cleanDesc.contains('medical') || cleanDesc.contains('health') || cleanDesc.contains('doctor') || cleanDesc.contains('hospital') || cleanDesc.contains('pharmacy') || cleanDesc.contains('medicine')) return 'Medical';
    if (cleanDesc.contains('travel') || cleanDesc.contains('flight') || cleanDesc.contains('hotel') || cleanDesc.contains('irctc') || cleanDesc.contains('train')) return 'Travel';
    if (cleanDesc.contains('loan') || cleanDesc.contains('emi') || cleanDesc.contains('repay') || cleanDesc.contains('credit card')) return 'Repayments';
    if (cleanDesc.contains('rent') || cleanDesc.contains('house')) return 'Rent';
    if (cleanDesc.contains('sub') || cleanDesc.contains('netflix') || cleanDesc.contains('spotify') || cleanDesc.contains('youtube premium')) return 'Subscription';
    if (cleanDesc.contains('invest') || cleanDesc.contains('mutual fund') || cleanDesc.contains('stock') || cleanDesc.contains('groww')) return 'Investment';
    return 'Miscellaneous';
  }

  // ──────────────────────────────────────────────────────
  // INVOICE GENERATION (via Supabase Edge Function)
  // ──────────────────────────────────────────────────────
  Future<String?> downloadInvoice(List<String> expenseIds, {String? monthYear}) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final matchingExpenses = _expenses.where((e) => expenseIds.contains(e.id)).toList();
      final path = await _supabase.generateAndSaveInvoice(matchingExpenses, monthYear: monthYear);
      return path;
    } catch (e) {
      print('[Invoice] Download error: $e');
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────
  // SYNC (SQLite ↔ Supabase)
  // ──────────────────────────────────────────────────────
  Future<bool> triggerQuietSync() async {
    try {
      final unsyncedExps = await _dbHelper.getUnsyncedExpenses();
      final unsyncedBuds = await _dbHelper.getUnsyncedBudgets();
      final unsyncedPays = await _dbHelper.getUnsyncedPaymentDetails();
      final unsyncedDeletes = await _dbHelper.getUnsyncedDeletions();
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('last_sync_time');

      final deletedExpIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'expenses')
          .map((d) => d['id'] as String)
          .toList();
      final deletedBudIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'budgets')
          .map((d) => d['id'] as String)
          .toList();

      final syncResult = await _supabase.sync(
        unsyncedExpenses: unsyncedExps,
        unsyncedBudgets: unsyncedBuds,
        unsyncedPaymentDetails: unsyncedPays,
        deletedExpenseIds: deletedExpIds,
        deletedBudgetIds: deletedBudIds,
        lastSyncTime: lastSync,
      );

      if (syncResult != null) {
        // Mark local entries as synced
        await _dbHelper.markExpensesSynced(unsyncedExps.map((e) => e['id'] as String).toList());
        await _dbHelper.markBudgetsSynced(unsyncedBuds.map((b) => b['id'] as String).toList());
        await _dbHelper.markPaymentDetailsSynced(unsyncedPays.map((p) => p['id'] as String).toList());
        await _dbHelper.clearSyncedDeletions(unsyncedDeletes.map((d) => d['id'] as String).toList());

        // Extract server data returned from the sync payload
        final List<dynamic> serverExpenses = syncResult['expenses'] ?? [];
        final List<dynamic> serverBudgets = syncResult['budgets'] ?? [];
        final List<dynamic> serverPayments = syncResult['paymentDetails'] ?? [];

        await _dbHelper.syncDownExpenses(serverExpenses.map((e) => Expense.fromMap(Map<String, dynamic>.from(e))).toList());
        await _dbHelper.syncDownBudgets(serverBudgets.map((b) => Budget.fromMap(Map<String, dynamic>.from(b))).toList());
        await _dbHelper.syncDownPaymentDetails(serverPayments.map((p) => PaymentDetail.fromMap(Map<String, dynamic>.from(p))).toList());

        // Deduplicate local cached expenses after pulling from Supabase
        await deduplicateExpenses(triggerSync: false);
      }

      _expenses = await _dbHelper.getExpenses();
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      notifyListeners();
      return syncResult != null;
    } catch (e) {
      print('[Sync] Quiet sync error (offline?): $e');
      return false;
    }
  }

  Future<bool> _checkIfGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString('cached_user_profile');
      if (cachedProfileStr != null) {
        final cachedProfile = json.decode(cachedProfileStr);
        return cachedProfile['id'] == 'guest-user-uuid';
      }
    } catch (_) {}
    return false;
  }

  Future<bool> triggerManualSync() async {
    _isSyncing = true;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      if (await _checkIfGuest()) {
        _syncErrorMessage = 'Cloud Sync is only available for registered accounts. Please log in.';
        _isSyncing = false;
        notifyListeners();
        return false;
      }
      final success = await triggerQuietSync();
      _isSyncing = false;
      if (!success) {
        _syncErrorMessage = 'Sync failed. Please check internet connection or database setup.';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _syncErrorMessage = 'Sync failed. Running in offline mode.';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreFromCloud() async {
    _isSyncing = true;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      if (await _checkIfGuest()) {
        _syncErrorMessage = 'Restore is only available for registered accounts. Please log in.';
        _isSyncing = false;
        notifyListeners();
        return false;
      }
      // 1. Clear local SQLite cached database
      await _dbHelper.clearAllData();
      
      // 2. Remove last sync time to force a full pull from Supabase
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_time');

      // 3. Trigger sync with empty local arrays and null timestamp to fetch all records
      final syncResult = await _supabase.sync(
        unsyncedExpenses: [],
        unsyncedBudgets: [],
        unsyncedPaymentDetails: [],
        deletedExpenseIds: [],
        deletedBudgetIds: [],
        lastSyncTime: null,
      );

      if (syncResult != null) {
        final List<dynamic> serverExpenses = syncResult['expenses'] ?? [];
        final List<dynamic> serverBudgets = syncResult['budgets'] ?? [];
        final List<dynamic> serverPayments = syncResult['paymentDetails'] ?? [];

        // Insert fetched items into local database
        await _dbHelper.syncDownExpenses(serverExpenses.map((e) => Expense.fromMap(Map<String, dynamic>.from(e))).toList());
        await _dbHelper.syncDownBudgets(serverBudgets.map((b) => Budget.fromMap(Map<String, dynamic>.from(b))).toList());
        await _dbHelper.syncDownPaymentDetails(serverPayments.map((p) => PaymentDetail.fromMap(Map<String, dynamic>.from(p))).toList());

        // Mark all restored items as synced in SQLite
        final expenseIds = serverExpenses.map((e) => e['id'] as String).toList();
        final budgetIds = serverBudgets.map((b) => b['id'] as String).toList();
        final paymentIds = serverPayments.map((p) => p['id'] as String).toList();
        await _dbHelper.markExpensesSynced(expenseIds);
        await _dbHelper.markBudgetsSynced(budgetIds);
        await _dbHelper.markPaymentDetailsSynced(paymentIds);
      } else {
        throw Exception('Cloud restoration returned empty database payload.');
      }

      // Reload memory lists
      _expenses = await _dbHelper.getExpenses();
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('[Sync] Restore Backup error: $e');
      _syncErrorMessage = 'Backup restore failed: $e';
      _isSyncing = false;
      // Re-load whatever lists are left
      _expenses = await _dbHelper.getExpenses();
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      notifyListeners();
      return false;
    }
  }

  Future<void> clearAllDataOnSignout() async {
    await _dbHelper.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_sync_time');
    _expenses.clear();
    _budgets.clear();
    _paymentDetails.clear();
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // OLD EXPENSES CLEANUP
  // ──────────────────────────────────────────────────────
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

  Future<bool> deleteOldExpenses() async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    _isLoading = true;
    notifyListeners();

    try {
      // Delete from Supabase (soft-delete via is_deleted flag won't work here, use hard delete)
      final oldIds = _expenses
          .where((e) => e.transactionDate.isBefore(currentMonthStart))
          .map((e) => e.id)
          .toList();
      if (oldIds.isNotEmpty) {
        await _supabase.hardDeleteExpenses(oldIds);
      }

      // Delete from local SQLite
      await _dbHelper.deleteOldExpenses(currentMonthStart);

      // Remove from in-memory list
      _expenses.removeWhere((e) => e.transactionDate.isBefore(currentMonthStart));

      final prefs = await SharedPreferences.getInstance();
      final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await prefs.setString('last_known_month_year', currentMonthStr);

      _syncErrorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      print('[ExpenseProvider] Error deleting old expenses: $e');
      _syncErrorMessage = 'Failed to delete old data: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────
  // AUTO-DEDUPLICATION
  // ──────────────────────────────────────────────────────
  Future<void> deduplicateExpenses({bool triggerSync = true}) async {
    final List<Expense> allExpenses = await _dbHelper.getExpenses();
    if (allExpenses.isEmpty) return;

    final Map<String, Expense> uniqueExpenses = {};
    final List<String> duplicateIdsToDelete = [];

    for (final exp in allExpenses) {
      if (exp.isDeleted) continue;

      // Deduplicate on same-day level: YYYY-MM-DD
      final dateStr = exp.transactionDate.toIso8601String().substring(0, 10);
      
      // Clean and normalize description to avoid casing/spacing duplicates
      final cleanDesc = exp.description.trim().toLowerCase();
      
      // Normalize amount to 2 decimal places (handles double precision representation mismatch)
      final key = '${exp.amount.toStringAsFixed(2)}__${cleanDesc}__$dateStr';

      if (uniqueExpenses.containsKey(key)) {
        final existing = uniqueExpenses[key]!;
        Expense keep;
        Expense discard;

        // Preference Rule 1: Keep the one with a non-generic category
        final existingHasSpecificCategory = existing.category != 'Others' && existing.category != 'Miscellaneous';
        final expHasSpecificCategory = exp.category != 'Others' && exp.category != 'Miscellaneous';

        if (existingHasSpecificCategory && !expHasSpecificCategory) {
          keep = existing;
          discard = exp;
        } else if (!existingHasSpecificCategory && expHasSpecificCategory) {
          keep = exp;
          discard = existing;
        } else {
          // Preference Rule 2: Keep the one with the newer updatedAt timestamp
          if (exp.updatedAt.isAfter(existing.updatedAt)) {
            keep = exp;
            discard = existing;
          } else {
            keep = existing;
            discard = exp;
          }
        }

        uniqueExpenses[key] = keep;
        duplicateIdsToDelete.add(discard.id);
        print('[Deduplication] Duplicate detected for key: $key. Keeping ${keep.id} (${keep.category}), discarding ${discard.id} (${discard.category})');
      } else {
        uniqueExpenses[key] = exp;
      }
    }

    if (duplicateIdsToDelete.isNotEmpty) {
      print('[Deduplication] Removing ${duplicateIdsToDelete.length} duplicates from SQLite...');
      for (final id in duplicateIdsToDelete) {
        await _dbHelper.deleteExpense(id);
        _expenses.removeWhere((e) => e.id == id);
      }
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────
  // UUID GENERATOR
  // ──────────────────────────────────────────────────────
  String cryptoUuid() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        '-' +
        (100000 + (900000 * (DateTime.now().microsecond / 1000000))).toInt().toString();
  }
}
