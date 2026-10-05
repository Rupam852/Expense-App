import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
import '../models/khata_entry.dart';
import '../models/split_bill.dart';
import '../models/subscription_item.dart';
import '../models/business_sale.dart';
import '../models/business_profile.dart';
import '../models/business_item.dart';
import 'ai_config_service.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';

class ExpenseProvider with ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _supabase = SupabaseService.instance;

  List<Expense> _expenses = [];
  List<Budget> _budgets = [];
  List<PaymentDetail> _paymentDetails = [];
  List<KhataEntry> _khataEntries = [];
  List<SplitBill> _splitBills = [];
  List<SubscriptionItem> _subscriptions = [];
  List<BusinessItem> _businessItems = [];

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
  bool _isQuietSyncing = false;
  String? _syncErrorMessage;
  String? _lastSyncTime;

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
  List<KhataEntry> get khataEntries => _khataEntries;
  List<SplitBill> get splitBills => _splitBills;
  List<SubscriptionItem> get subscriptions => _subscriptions;
  List<BusinessItem> get businessItems => _businessItems;
  List<BusinessItem> get lowStockBusinessItems => _businessItems.where((it) => it.isLowStock || it.isOutOfStock).toList();
  
  double get totalYouWillGet => _khataEntries
      .where((k) => !k.isDeleted && !k.isSettled && k.isLent)
      .fold<double>(0.0, (sum, k) => sum + k.amount);

  double get totalYouWillGive => _khataEntries
      .where((k) => !k.isDeleted && !k.isSettled && k.isBorrowed)
      .fold<double>(0.0, (sum, k) => sum + k.amount);

  double get netKhataBalance => totalYouWillGet - totalYouWillGive;

  List<KhataEntry> khataEntriesFor(String ledgerType) {
    return _khataEntries.where((k) => !k.isDeleted && (k.ledgerType == ledgerType || (ledgerType == 'personal' && k.ledgerType.isEmpty))).toList();
  }

  double totalYouWillGetFor(String ledgerType) => _khataEntries
      .where((k) => !k.isDeleted && !k.isSettled && k.isLent && (k.ledgerType == ledgerType || (ledgerType == 'personal' && k.ledgerType.isEmpty)))
      .fold<double>(0.0, (sum, k) => sum + k.amount);

  double totalYouWillGiveFor(String ledgerType) => _khataEntries
      .where((k) => !k.isDeleted && !k.isSettled && k.isBorrowed && (k.ledgerType == ledgerType || (ledgerType == 'personal' && k.ledgerType.isEmpty)))
      .fold<double>(0.0, (sum, k) => sum + k.amount);

  double netKhataBalanceFor(String ledgerType) => totalYouWillGetFor(ledgerType) - totalYouWillGiveFor(ledgerType);

  double get totalSplitReceivable => _splitBills
      .where((b) => !b.isDeleted)
      .fold<double>(0.0, (sum, b) => sum + b.pendingCollection);

  double get totalSplitPayable => _splitBills
      .where((b) => !b.isDeleted)
      .fold<double>(0.0, (sum, b) => sum + b.myPendingToPay);

  double get totalMonthlySubscriptionCost => _subscriptions
      .where((s) => !s.isDeleted && s.isActive)
      .fold<double>(0.0, (sum, s) => sum + s.monthlyEquivalent);

  double get totalAnnualSubscriptionCost => totalMonthlySubscriptionCost * 12.0;

  int get subscriptionsDueThisWeekCount => _subscriptions
      .where((s) => !s.isDeleted && s.isActive && s.daysUntilRenewal >= 0 && s.daysUntilRenewal <= 7)
      .length;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get syncErrorMessage => _syncErrorMessage;
  String? get lastSyncTime => _lastSyncTime;

  DateTime get selectedMonthYear => _selectedMonthYear;

  void setSelectedMonthYear(DateTime value) {
    if (_selectedMonthYear.year != value.year || _selectedMonthYear.month != value.month) {
      _selectedMonthYear = DateTime(value.year, value.month);
      notifyListeners();
    }
  }

  int _businessDataVersion = 0;
  int get businessDataVersion => _businessDataVersion;

  void notifyBusinessDataChanged() {
    _businessDataVersion++;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // LOAD LOCAL DATA
  // ──────────────────────────────────────────────────────
  Future<void> loadLocalData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSyncTime = prefs.getString('last_sync_time');
      _expenses = await _dbHelper.getExpenses(ledgerType: 'personal');
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      _khataEntries = await _dbHelper.getKhataEntries();
      _splitBills = await _dbHelper.getSplitBills();
      _subscriptions = await _dbHelper.getSubscriptions();
      _businessItems = await _dbHelper.getBusinessItems();
      _syncErrorMessage = null;
      _businessDataVersion++;

      // Check subscriptions, budgets and khata reminders on app load only if authenticated
      final currentUser = _supabase.currentUser;
      final cachedProfile = prefs.getString('cached_user_profile');
      final isGuest = cachedProfile != null && cachedProfile.contains('guest-user-uuid');
      if (currentUser != null || isGuest) {
        NotificationService.instance.checkAndNotifyDueSubscriptions(_subscriptions);
        NotificationService.instance.checkAndNotifyBudgetLimits(
          budgets: _budgets,
          expenses: _expenses,
          currentMonth: _selectedMonthYear,
        );
        NotificationService.instance.checkAndNotifyKhataEntries(_khataEntries);
        NotificationService.instance.checkAndNotifyMonthEndAndNewMonth(expenses: _expenses);
      }
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
    String ledgerType = 'personal',
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
      ledgerType: ledgerType,
    );
    await _dbHelper.insertExpense(expense);
    if (ledgerType == 'personal') {
      _expenses.insert(0, expense);
      notifyListeners();
      // Check and push budget alert notification if threshold reached
      NotificationService.instance.checkAndNotifyBudgetLimits(
        budgets: _budgets,
        expenses: _expenses,
        currentMonth: _selectedMonthYear,
      );
    } else {
      notifyBusinessDataChanged();
    }
    // Silent background sync after adding
    triggerQuietSync();
  }

  Future<void> editExpense(Expense updatedExpense) async {
    await _dbHelper.updateExpense(updatedExpense);
    final idx = _expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (idx != -1) {
      _expenses[idx] = updatedExpense;
      notifyListeners();
      NotificationService.instance.checkAndNotifyBudgetLimits(
        budgets: _budgets,
        expenses: _expenses,
        currentMonth: _selectedMonthYear,
      );
    }
    notifyBusinessDataChanged();
    // Silent background sync after editing
    triggerQuietSync();
  }

  Future<void> deleteExpense(String id) async {
    await _dbHelper.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    notifyBusinessDataChanged();
    triggerQuietSync();
  }

  Future<void> deleteBusinessSale(String id) async {
    await _dbHelper.deleteBusinessSale(id);
    notifyBusinessDataChanged();
    triggerQuietSync();
  }

  Future<void> restoreExpense(Expense expense) async {
    await _dbHelper.clearSyncedDeletions([expense.id]);
    await _dbHelper.insertExpense(expense);
    _expenses.insert(0, expense);
    _expenses.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> restoreMultipleExpenses(List<Expense> expenses) async {
    if (expenses.isEmpty) return;
    final ids = expenses.map((e) => e.id).toList();
    await _dbHelper.clearSyncedDeletions(ids);
    for (final expense in expenses) {
      await _dbHelper.insertExpense(expense);
      _expenses.insert(0, expense);
    }
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
    triggerQuietSync();
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
    NotificationService.instance.checkAndNotifyBudgetLimits(
      budgets: _budgets,
      expenses: _expenses,
      currentMonth: _selectedMonthYear,
    );
    // Silent background sync after budget set
    triggerQuietSync();
  }

  Future<void> deleteBudget(String id) async {
    await _dbHelper.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
    triggerQuietSync();
  }

  // ──────────────────────────────────────────────────────
  // PAYMENT DETAILS
  // ──────────────────────────────────────────────────────
  Future<void> savePaymentDetails({
    required String upiId,
    String? qrCodeUrl,
  }) async {
    final db = await _dbHelper.database;
    
    // Preserve existing ID if present to prevent multiple duplicate rows on cloud
    final detailId = _paymentDetails.isNotEmpty ? _paymentDetails.first.id : cryptoUuid();
    final now = DateTime.now();

    await db.delete('payment_details');

    final detail = PaymentDetail(
      id: detailId,
      upiId: upiId,
      qrCodeUrl: qrCodeUrl,
      createdAt: _paymentDetails.isNotEmpty ? _paymentDetails.first.createdAt : now,
      updatedAt: now,
    );
    await _dbHelper.insertPaymentDetail(detail);
    _paymentDetails = [detail];
    notifyListeners();

    // Trigger immediate background sync to Supabase so changes are permanently backed up!
    triggerQuietSync();
  }

  Future<void> deletePaymentDetails() async {
    await _dbHelper.deletePaymentDetails();
    _paymentDetails = [];
    notifyListeners();

    // Remove from cloud as well
    try {
      await _supabase.deletePaymentDetailsOnServer();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────
  // KHATA / UDHAR (Borrow & Lend Ledger)
  // ──────────────────────────────────────────────────────
  Future<void> fetchKhataEntries() async {
    _khataEntries = await _dbHelper.getKhataEntries();
    notifyListeners();
  }

  Future<void> addKhataEntry({
    required String personName,
    String? phoneNumber,
    required double amount,
    required String type,
    required DateTime entryDate,
    DateTime? dueDate,
    String? note,
    String ledgerType = 'personal',
  }) async {
    final entry = KhataEntry(
      id: cryptoUuid(),
      personName: personName.trim(),
      phoneNumber: phoneNumber?.trim().isEmpty == true ? null : phoneNumber?.trim(),
      amount: amount,
      type: type,
      entryDate: entryDate,
      dueDate: dueDate,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      ledgerType: ledgerType,
    );

    await _dbHelper.insertKhataEntry(entry);
    _khataEntries.insert(0, entry);
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> updateKhataEntry(KhataEntry entry) async {
    await _dbHelper.updateKhataEntry(entry);
    final index = _khataEntries.indexWhere((k) => k.id == entry.id);
    if (index != -1) {
      _khataEntries[index] = entry;
      notifyListeners();
      triggerQuietSync();
    }
  }

  Future<void> toggleSettleKhata(String id, bool isSettled) async {
    await _dbHelper.toggleSettleKhataEntry(id, isSettled);
    final index = _khataEntries.indexWhere((k) => k.id == id);
    if (index != -1) {
      _khataEntries[index] = _khataEntries[index].copyWith(
        isSettled: isSettled,
        settledAt: isSettled ? DateTime.now() : null,
      );
      notifyListeners();
      triggerQuietSync();
    }
  }

  Future<void> deleteKhataEntry(String id) async {
    await _dbHelper.deleteKhataEntry(id);
    _khataEntries.removeWhere((k) => k.id == id);
    notifyListeners();
    triggerQuietSync();
  }

  // ──────────────────────────────────────────────────────
  // SPLIT BILLS (Group / Shared Expense Ledger)
  // ──────────────────────────────────────────────────────
  Future<void> fetchSplitBills() async {
    _splitBills = await _dbHelper.getSplitBills();
    notifyListeners();
  }

  Future<void> addSplitBill({
    required String title,
    required double totalAmount,
    required String paidBy,
    String? payerUpiId,
    required DateTime billDate,
    String splitType = 'equal',
    required List<SplitParticipant> participants,
    String? note,
  }) async {
    final bill = SplitBill(
      id: cryptoUuid(),
      title: title.trim(),
      totalAmount: totalAmount,
      paidBy: paidBy.trim(),
      payerUpiId: payerUpiId?.trim().isEmpty == true ? null : payerUpiId?.trim(),
      billDate: billDate,
      splitType: splitType,
      participants: participants,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );

    await _dbHelper.insertSplitBill(bill);
    _splitBills.insert(0, bill);
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> updateSplitBill(SplitBill bill) async {
    await _dbHelper.updateSplitBill(bill);
    final index = _splitBills.indexWhere((b) => b.id == bill.id);
    if (index != -1) {
      _splitBills[index] = bill;
      notifyListeners();
      triggerQuietSync();
    }
  }

  Future<void> toggleParticipantSettled(String billId, String participantName, bool isSettled) async {
    final index = _splitBills.indexWhere((b) => b.id == billId);
    if (index != -1) {
      final bill = _splitBills[index];
      final updatedParts = bill.participants.map((p) {
        if (p.name.trim().toLowerCase() == participantName.trim().toLowerCase()) {
          return p.copyWith(
            isSettled: isSettled,
            settledAt: isSettled ? DateTime.now() : null,
          );
        }
        return p;
      }).toList();

      final updatedBill = bill.copyWith(participants: updatedParts);
      await _dbHelper.updateSplitBill(updatedBill);
      _splitBills[index] = updatedBill;
      notifyListeners();
      triggerQuietSync();
    }
  }

  Future<void> deleteSplitBill(String id) async {
    await _dbHelper.deleteSplitBill(id);
    _splitBills.removeWhere((b) => b.id == id);
    notifyListeners();
    triggerQuietSync();
  }

  // ──────────────────────────────────────────────────────
  // SUBSCRIPTIONS & RECURRING BILLS
  // ──────────────────────────────────────────────────────
  Future<void> fetchSubscriptions() async {
    _subscriptions = await _dbHelper.getSubscriptions();
    notifyListeners();
    NotificationService.instance.checkAndNotifyDueSubscriptions(_subscriptions);
  }

  Future<void> addSubscription({
    required String name,
    required double amount,
    String billingCycle = 'monthly',
    required DateTime nextRenewalDate,
    String category = 'Subscription',
    bool autoRenewal = true,
    int reminderDaysBefore = 2,
    String? paymentMethod,
    String? note,
  }) async {
    final item = SubscriptionItem(
      id: cryptoUuid(),
      name: name.trim(),
      amount: amount,
      billingCycle: billingCycle,
      nextRenewalDate: nextRenewalDate,
      category: category,
      autoRenewal: autoRenewal,
      reminderDaysBefore: reminderDaysBefore,
      paymentMethod: paymentMethod?.trim().isEmpty == true ? null : paymentMethod?.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );

    await _dbHelper.insertSubscription(item);
    _subscriptions.add(item);
    _subscriptions.sort((a, b) => a.nextRenewalDate.compareTo(b.nextRenewalDate));
    notifyListeners();
    NotificationService.instance.checkAndNotifyDueSubscriptions(_subscriptions);
    triggerQuietSync();
  }

  Future<void> updateSubscription(SubscriptionItem item) async {
    await _dbHelper.updateSubscription(item);
    final index = _subscriptions.indexWhere((s) => s.id == item.id);
    if (index != -1) {
      _subscriptions[index] = item;
      _subscriptions.sort((a, b) => a.nextRenewalDate.compareTo(b.nextRenewalDate));
      notifyListeners();
      NotificationService.instance.checkAndNotifyDueSubscriptions(_subscriptions);
      triggerQuietSync();
    }
  }

  Future<void> toggleSubscriptionActive(String id, bool isActive) async {
    await _dbHelper.toggleSubscriptionActive(id, isActive);
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _subscriptions[index] = _subscriptions[index].copyWith(isActive: isActive);
      notifyListeners();
      triggerQuietSync();
    }
  }

  Future<void> markSubscriptionRenewed(String id, {bool logExpenseRecord = true}) async {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index != -1) {
      final item = _subscriptions[index];
      final nextDate = item.nextCycleDate;
      final updated = item.copyWith(nextRenewalDate: nextDate);

      await _dbHelper.updateSubscription(updated);
      _subscriptions[index] = updated;
      _subscriptions.sort((a, b) => a.nextRenewalDate.compareTo(b.nextRenewalDate));

      if (logExpenseRecord) {
        await addExpense(
          amount: item.amount,
          category: item.category,
          description: '${item.name} Renewal',
          date: DateTime.now(),
          isRecurring: true,
          recurrencePeriod: item.billingCycle,
        );
      }
      notifyListeners();
      triggerQuietSync();
    }
  }

  Future<void> deleteSubscription(String id) async {
    await _dbHelper.deleteSubscription(id);
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
    triggerQuietSync();
  }

  // ──────────────────────────────────────────────────────
  // PAYMENT METHODS (MULTI-ACCOUNT, PRIMARY & REORDERING)
  // ──────────────────────────────────────────────────────
  PaymentDetail? get primaryPaymentDetail {
    if (_paymentDetails.isEmpty) return null;
    final primary = _paymentDetails.where((p) => p.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first;
    return _paymentDetails.first;
  }

  Future<void> fetchPaymentDetails() async {
    _paymentDetails = await _dbHelper.getPaymentDetails();
    notifyListeners();
  }

  Future<void> addPaymentDetail({
    required String name,
    required String upiId,
    String? qrCodeUrl,
    bool isPrimary = false,
  }) async {
    final makePrimary = isPrimary || _paymentDetails.isEmpty;
    final item = PaymentDetail(
      id: cryptoUuid(),
      name: name.trim().isEmpty ? 'Primary UPI' : name.trim(),
      upiId: upiId.trim(),
      qrCodeUrl: qrCodeUrl,
      isPrimary: makePrimary,
      sortOrder: _paymentDetails.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _dbHelper.insertPaymentDetail(item);
    _paymentDetails = await _dbHelper.getPaymentDetails();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> updatePaymentDetail(PaymentDetail item) async {
    await _dbHelper.updatePaymentDetail(item);
    _paymentDetails = await _dbHelper.getPaymentDetails();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> setPrimaryPaymentDetail(String id) async {
    await _dbHelper.setPrimaryPaymentDetail(id);
    _paymentDetails = await _dbHelper.getPaymentDetails();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> reorderPaymentDetails(List<PaymentDetail> reorderedList) async {
    _paymentDetails = reorderedList;
    notifyListeners();
    await _dbHelper.reorderPaymentDetails(reorderedList);
    _paymentDetails = await _dbHelper.getPaymentDetails();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> deletePaymentDetail(String id) async {
    await _dbHelper.deletePaymentDetail(id);
    _paymentDetails = await _dbHelper.getPaymentDetails();
    if (_paymentDetails.isNotEmpty && !_paymentDetails.any((p) => p.isPrimary)) {
      await _dbHelper.setPrimaryPaymentDetail(_paymentDetails.first.id);
      _paymentDetails = await _dbHelper.getPaymentDetails();
    }
    notifyListeners();
    try {
      if (_supabase.currentUser != null) {
        await _supabase.deletePaymentDetailOnServer(id);
      }
    } catch (_) {}
    triggerQuietSync();
  }

  Future<void> deleteAllPaymentDetails() async {
    await _dbHelper.deletePaymentDetails();
    _paymentDetails = [];
    notifyListeners();
    triggerQuietSync();
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

      // Scan receipt using User-Configured AI API Keys (Gemini / NVIDIA)
      final aiService = AiConfigService.instance;
      final result = await aiService.parseReceiptWithConfig(imageBytes);

      if (result['success'] == true) {
        return result['data'] as Map<String, dynamic>?;
      }

      _syncErrorMessage = result['error']?.toString() ?? 'OCR scanning failed. Please verify your API Key in Settings → AI Configuration.';
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

      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      int importedCount = 0;
      int skippedDuplicatesCount = 0;
      int skippedOtherMonthCount = 0;
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

        // Current Month Session Rule: Only import transactions belonging to current active month
        if (parsedDate.isBefore(firstDay) || parsedDate.isAfter(lastDay)) {
          skippedOtherMonthCount++;
          continue;
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
        } else {
          skippedDuplicatesCount++;
        }
      }

      if (importedCount > 0) {
        _expenses = await _dbHelper.getExpenses(ledgerType: 'personal');
        notifyListeners();
        _isLoading = false;
        notifyListeners();
        // Silent background sync after import
        triggerQuietSync();
        
        final List<String> details = [];
        if (skippedOtherMonthCount > 0) details.add('$skippedOtherMonthCount other month rows skipped');
        if (skippedDuplicatesCount > 0) details.add('$skippedDuplicatesCount duplicates skipped');
        
        if (details.isNotEmpty) {
          return '✅ $importedCount current month transactions imported! (${details.join(', ')})';
        }
        return '✅ $importedCount transactions imported for ${DateFormat('MMMM yyyy').format(now)}!';
      } else if (skippedOtherMonthCount > 0 && skippedDuplicatesCount == 0) {
        _syncErrorMessage = 'No transactions from current month (${DateFormat('MMMM yyyy').format(now)}) found ($skippedOtherMonthCount past/future month rows skipped).';
        _isLoading = false;
        notifyListeners();
        return 'ℹ️ No transactions from current month (${DateFormat('MMMM yyyy').format(now)}) found ($skippedOtherMonthCount other month rows skipped).';
      } else if (skippedDuplicatesCount > 0) {
        _syncErrorMessage = 'All $skippedDuplicatesCount transactions already exist in the app.';
        _isLoading = false;
        notifyListeners();
        return 'ℹ️ All $skippedDuplicatesCount transactions were duplicate and already exist.';
      } else {
        _syncErrorMessage = 'No valid current month transactions found in the file.';
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
    final matchingExpenses = _expenses.where((e) => expenseIds.contains(e.id)).toList();
    if (matchingExpenses.isEmpty) {
      return null;
    }
    _isSyncing = true;
    notifyListeners();
    try {
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
  // ──────────────────────────────────────────────────────
  // SYNC (SQLite ↔ Supabase)
  // ──────────────────────────────────────────────────────
  Future<bool> _performSync() async {
    try {
      if (await _checkIfGuest()) return false;

      final unsyncedExps = await _dbHelper.getUnsyncedExpenses();
      final unsyncedBuds = await _dbHelper.getUnsyncedBudgets();
      final unsyncedPays = await _dbHelper.getUnsyncedPaymentDetails();
      final unsyncedKhata = await _dbHelper.getUnsyncedKhataEntries();
      final unsyncedSubs = await _dbHelper.getUnsyncedSubscriptions();
      final unsyncedSplits = await _dbHelper.getUnsyncedSplitBills();
      final unsyncedBusinessSales = await _dbHelper.getUnsyncedBusinessSales();
      final unsyncedBusinessItems = await _dbHelper.getUnsyncedBusinessItems();
      final unsyncedBusinessProfile = (await _dbHelper.getBusinessProfile()).toMap();
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
      final deletedPayIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'payment_details')
          .map((d) => d['id'] as String)
          .toList();
      final deletedKhataIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'khata_entries')
          .map((d) => d['id'] as String)
          .toList();
      final deletedSubIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'subscriptions')
          .map((d) => d['id'] as String)
          .toList();
      final deletedSplitIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'split_bills')
          .map((d) => d['id'] as String)
          .toList();
      final deletedBusinessSaleIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'business_sales')
          .map((d) => d['id'] as String)
          .toList();
      final deletedBusinessItemIds = unsyncedDeletes
          .where((d) => d['table_name'] == 'business_items')
          .map((d) => d['id'] as String)
          .toList();

      final syncResult = await _supabase.sync(
        unsyncedExpenses: unsyncedExps,
        unsyncedBudgets: unsyncedBuds,
        unsyncedPaymentDetails: unsyncedPays,
        unsyncedKhataEntries: unsyncedKhata,
        unsyncedSubscriptions: unsyncedSubs,
        unsyncedSplitBills: unsyncedSplits,
        unsyncedBusinessSales: unsyncedBusinessSales,
        unsyncedBusinessItems: unsyncedBusinessItems,
        unsyncedBusinessProfile: unsyncedBusinessProfile,
        deletedExpenseIds: deletedExpIds,
        deletedBudgetIds: deletedBudIds,
        deletedPaymentDetailIds: deletedPayIds,
        deletedKhataIds: deletedKhataIds,
        deletedSubscriptionIds: deletedSubIds,
        deletedSplitBillIds: deletedSplitIds,
        deletedBusinessSaleIds: deletedBusinessSaleIds,
        deletedBusinessItemIds: deletedBusinessItemIds,
        lastSyncTime: lastSync,
      );

      if (syncResult != null) {
        // Mark local entries as synced
        await _dbHelper.markExpensesSynced(unsyncedExps.map((e) => e['id'] as String).toList());
        await _dbHelper.markBudgetsSynced(unsyncedBuds.map((b) => b['id'] as String).toList());
        await _dbHelper.markPaymentDetailsSynced(unsyncedPays.map((p) => p['id'] as String).toList());
        await _dbHelper.markKhataEntriesSynced(unsyncedKhata.map((k) => k['id'] as String).toList());
        await _dbHelper.markSubscriptionsSynced(unsyncedSubs.map((s) => s['id'] as String).toList());
        await _dbHelper.markSplitBillsSynced(unsyncedSplits.map((sb) => sb['id'] as String).toList());
        await _dbHelper.markBusinessSalesSynced(unsyncedBusinessSales.map((bs) => bs['id'] as String).toList());
        await _dbHelper.markBusinessItemsSynced(unsyncedBusinessItems.map((bi) => bi['id'] as String).toList());
        await _dbHelper.clearSyncedDeletions(unsyncedDeletes.map((d) => d['id'] as String).toList());

        // Extract server data returned from the sync payload
        final List<dynamic> serverExpenses = syncResult['expenses'] ?? [];
        final List<dynamic> serverBudgets = syncResult['budgets'] ?? [];
        final List<dynamic> serverPayments = syncResult['paymentDetails'] ?? [];
        final List<dynamic> serverKhata = syncResult['khataEntries'] ?? [];
        final List<dynamic> serverSubs = syncResult['subscriptions'] ?? [];
        final List<dynamic> serverSplits = syncResult['splitBills'] ?? [];
        final List<dynamic> serverBusinessSales = syncResult['businessSales'] ?? [];
        final List<dynamic> serverBusinessItems = syncResult['businessItems'] ?? [];
        final Map<String, dynamic>? serverBusinessProf = syncResult['businessProfile'] as Map<String, dynamic>?;

        await _dbHelper.syncDownExpenses(serverExpenses.map((e) => Expense.fromMap(Map<String, dynamic>.from(e))).toList());
        await _dbHelper.syncDownBudgets(serverBudgets.map((b) => Budget.fromMap(Map<String, dynamic>.from(b))).toList());
        await _dbHelper.syncDownPaymentDetails(serverPayments.map((p) => PaymentDetail.fromMap(Map<String, dynamic>.from(p))).toList());
        await _dbHelper.syncDownKhataEntries(serverKhata.map((k) => KhataEntry.fromMap(Map<String, dynamic>.from(k))).toList());
        await _dbHelper.syncDownSubscriptions(serverSubs.map((s) => SubscriptionItem.fromMap(Map<String, dynamic>.from(s))).toList());
        await _dbHelper.syncDownSplitBills(serverSplits.map((sb) => SplitBill.fromMap(Map<String, dynamic>.from(sb))).toList());
        await _dbHelper.syncDownBusinessSales(serverBusinessSales.map((bs) => BusinessSale.fromMap(Map<String, dynamic>.from(bs))).toList());
        await _dbHelper.syncDownBusinessItems(serverBusinessItems.map((bi) => BusinessItem.fromMap(Map<String, dynamic>.from(bi))).toList());
        if (serverBusinessProf != null) {
          await _dbHelper.syncDownBusinessProfile(BusinessProfile.fromMap(serverBusinessProf));
        }

        _lastSyncTime = prefs.getString('last_sync_time');
        _syncErrorMessage = null;
      }

      _expenses = await _dbHelper.getExpenses(ledgerType: 'personal');
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      _khataEntries = await _dbHelper.getKhataEntries();
      _subscriptions = await _dbHelper.getSubscriptions();
      _splitBills = await _dbHelper.getSplitBills();
      _businessItems = await _dbHelper.getBusinessItems();
      notifyListeners();
      return syncResult != null;
    } catch (e) {
      print('[Sync] Sync error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // BUSINESS ITEMS / CATALOG CRUD
  // ──────────────────────────────────────────────────────
  Future<void> loadBusinessItems() async {
    _businessItems = await _dbHelper.getBusinessItems();
    notifyListeners();
  }

  Future<void> addBusinessItem(BusinessItem item) async {
    await _dbHelper.insertBusinessItem(item);
    _businessItems = await _dbHelper.getBusinessItems();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> updateBusinessItem(BusinessItem item) async {
    await _dbHelper.updateBusinessItem(item);
    _businessItems = await _dbHelper.getBusinessItems();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> deleteBusinessItem(String id) async {
    await _dbHelper.deleteBusinessItem(id);
    _businessItems = await _dbHelper.getBusinessItems();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> updateBusinessItemStock(String id, double newStock) async {
    await _dbHelper.updateItemStockDirectly(id, newStock);
    _businessItems = await _dbHelper.getBusinessItems();
    notifyListeners();
    triggerQuietSync();
  }

  Future<void> deductStockForSale(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dbHelper.deductStockForItems(items);
    _businessItems = await _dbHelper.getBusinessItems();
    notifyListeners();
    triggerQuietSync();

    // Check if any sold item dropped to low stock or out of stock and notify
    for (final it in items) {
      final name = (it['item_name'] ?? it['itemName'] ?? it['name'] ?? it['title'] ?? '').toString().trim();
      final matched = _businessItems.firstWhere(
        (bi) => bi.name.trim().toLowerCase() == name.toLowerCase(),
        orElse: () => BusinessItem(id: '', name: ''),
      );
      if (matched.id.isNotEmpty && matched.trackStock && (matched.isLowStock || matched.isOutOfStock)) {
        NotificationService.instance.showLowStockNotification(
          itemName: matched.name,
          currentStock: matched.stockQuantity,
          unit: matched.unit,
          limit: matched.lowStockLimit,
        );
      }
    }
  }

  Future<bool> triggerQuietSync() async {
    if (_isQuietSyncing || _isSyncing) return false;
    _isQuietSyncing = true;
    try {
      return await _performSync();
    } finally {
      _isQuietSyncing = false;
    }
  }

  Future<bool> _checkIfGuest() async {
    try {
      if (_supabase.currentUser == null) return true;
      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString('cached_user_profile');
      if (cachedProfileStr != null) {
        final cachedProfile = json.decode(cachedProfileStr);
        return cachedProfile['id'] == 'guest-user-uuid';
      }
    } catch (_) {}
    return _supabase.currentUser == null;
  }

  Future<bool> triggerManualSync() async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      if (await _checkIfGuest()) {
        _syncErrorMessage = 'Cloud Sync is only available for registered accounts. Please log in.';
        return false;
      }
      final success = await _performSync();
      if (!success) {
        _syncErrorMessage = 'Sync failed. Please check internet connection.';
      } else {
        _syncErrorMessage = null;
      }
      return success;
    } catch (e) {
      _syncErrorMessage = 'Sync failed. Operating in offline mode.';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> restoreFromCloud() async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      if (await _checkIfGuest()) {
        _syncErrorMessage = 'Restore is only available for registered accounts. Please log in.';
        return false;
      }

      // 1. Trigger sync with empty local arrays and null timestamp to fetch all records
      final syncResult = await _supabase.sync(
        unsyncedExpenses: [],
        unsyncedBudgets: [],
        unsyncedPaymentDetails: [],
        unsyncedKhataEntries: [],
        unsyncedSubscriptions: [],
        unsyncedSplitBills: [],
        unsyncedBusinessSales: [],
        unsyncedBusinessItems: [],
        deletedExpenseIds: [],
        deletedBudgetIds: [],
        deletedPaymentDetailIds: [],
        deletedKhataIds: [],
        deletedSubscriptionIds: [],
        deletedSplitBillIds: [],
        deletedBusinessSaleIds: [],
        deletedBusinessItemIds: [],
        lastSyncTime: null,
      );

      if (syncResult != null) {
        // Clear local synchronized tables safely only after cloud payload is verified (preserves local chat)
        await _dbHelper.clearSyncTables();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_sync_time');

        final List<dynamic> serverExpenses = syncResult['expenses'] ?? [];
        final List<dynamic> serverBudgets = syncResult['budgets'] ?? [];
        final List<dynamic> serverPayments = syncResult['paymentDetails'] ?? [];
        final List<dynamic> serverKhata = syncResult['khataEntries'] ?? [];
        final List<dynamic> serverSubs = syncResult['subscriptions'] ?? [];
        final List<dynamic> serverSplits = syncResult['splitBills'] ?? [];
        final List<dynamic> serverBusinessSales = syncResult['businessSales'] ?? [];
        final List<dynamic> serverBusinessItems = syncResult['businessItems'] ?? [];
        final Map<String, dynamic>? serverBusinessProf = syncResult['businessProfile'] as Map<String, dynamic>?;

        // Insert fetched items into local database
        await _dbHelper.syncDownExpenses(serverExpenses.map((e) => Expense.fromMap(Map<String, dynamic>.from(e))).toList());
        await _dbHelper.syncDownBudgets(serverBudgets.map((b) => Budget.fromMap(Map<String, dynamic>.from(b))).toList());
        await _dbHelper.syncDownPaymentDetails(serverPayments.map((p) => PaymentDetail.fromMap(Map<String, dynamic>.from(p))).toList());
        await _dbHelper.syncDownKhataEntries(serverKhata.map((k) => KhataEntry.fromMap(Map<String, dynamic>.from(k))).toList());
        await _dbHelper.syncDownSubscriptions(serverSubs.map((s) => SubscriptionItem.fromMap(Map<String, dynamic>.from(s))).toList());
        await _dbHelper.syncDownSplitBills(serverSplits.map((sb) => SplitBill.fromMap(Map<String, dynamic>.from(sb))).toList());
        await _dbHelper.syncDownBusinessSales(serverBusinessSales.map((bs) => BusinessSale.fromMap(Map<String, dynamic>.from(bs))).toList());
        await _dbHelper.syncDownBusinessItems(serverBusinessItems.map((bi) => BusinessItem.fromMap(Map<String, dynamic>.from(bi))).toList());
        if (serverBusinessProf != null) {
          await _dbHelper.syncDownBusinessProfile(BusinessProfile.fromMap(serverBusinessProf));
        }

        // Mark all restored items as synced in SQLite
        final expenseIds = serverExpenses.map((e) => e['id'] as String).toList();
        final budgetIds = serverBudgets.map((b) => b['id'] as String).toList();
        final paymentIds = serverPayments.map((p) => p['id'] as String).toList();
        final khataIds = serverKhata.map((k) => k['id'] as String).toList();
        final subIds = serverSubs.map((s) => s['id'] as String).toList();
        final splitIds = serverSplits.map((sb) => sb['id'] as String).toList();
        final businessSaleIds = serverBusinessSales.map((bs) => bs['id'] as String).toList();
        final businessItemIds = serverBusinessItems.map((bi) => bi['id'] as String).toList();
        await _dbHelper.markExpensesSynced(expenseIds);
        await _dbHelper.markBudgetsSynced(budgetIds);
        await _dbHelper.markPaymentDetailsSynced(paymentIds);
        await _dbHelper.markKhataEntriesSynced(khataIds);
        await _dbHelper.markSubscriptionsSynced(subIds);
        await _dbHelper.markSplitBillsSynced(splitIds);
        await _dbHelper.markBusinessSalesSynced(businessSaleIds);
        await _dbHelper.markBusinessItemsSynced(businessItemIds);

        _lastSyncTime = prefs.getString('last_sync_time');

        // Reload memory lists
        _expenses = await _dbHelper.getExpenses(ledgerType: 'personal');
        _budgets = await _dbHelper.getBudgets();
        _paymentDetails = await _dbHelper.getPaymentDetails();
        _khataEntries = await _dbHelper.getKhataEntries();
        _subscriptions = await _dbHelper.getSubscriptions();
        _splitBills = await _dbHelper.getSplitBills();
        _businessItems = await _dbHelper.getBusinessItems();
        return true;
      } else {
        _syncErrorMessage = 'Cloud backup restore failed. Please check your internet connection.';
        return false;
      }
    } catch (e) {
      print('[Sync] Restore Backup error: $e');
      _syncErrorMessage = 'Backup restore failed: $e';
      // Re-load whatever lists are left
      _expenses = await _dbHelper.getExpenses(ledgerType: 'personal');
      _budgets = await _dbHelper.getBudgets();
      _paymentDetails = await _dbHelper.getPaymentDetails();
      _khataEntries = await _dbHelper.getKhataEntries();
      _subscriptions = await _dbHelper.getSubscriptions();
      _splitBills = await _dbHelper.getSplitBills();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> clearAllDataOnSignout() async {
    await _dbHelper.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_sync_time');
    _lastSyncTime = null;
    _expenses.clear();
    _budgets.clear();
    _paymentDetails.clear();
    _khataEntries.clear();
    _splitBills.clear();
    _subscriptions.clear();
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
  // UUID GENERATOR (RFC 4122 v4 Cryptographically Secure)
  // ──────────────────────────────────────────────────────
  static final Random _secureRandom = Random.secure();

  String cryptoUuid() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}

