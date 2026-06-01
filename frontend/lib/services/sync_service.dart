import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'api_service.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/payment_detail.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  final _dbHelper = DatabaseHelper.instance;
  final _apiService = ApiService.instance;

  SyncService._init();

  // Primary Synchronization sequence
  Future<bool> synchronize() async {
    try {
      // 1. Gather all local unsynced records and deletions queue
      final unsyncedExps = await _dbHelper.getUnsyncedExpenses();
      final unsyncedBuds = await _dbHelper.getUnsyncedBudgets();
      final unsyncedPays = await _dbHelper.getUnsyncedPaymentDetails();
      final unsyncedDeletes = await _dbHelper.getUnsyncedDeletions();

      // If we don't have a token, we are in guest mode and cannot sync with the cloud
      final token = await _apiService.getToken();
      if (token == null) {
        print('Guest Mode active: Skipping synchronization.');
        return false;
      }

      // 2. Fetch last synchronization timestamp
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('last_sync_time');

      print('Starting synchronization: Pushing ${unsyncedExps.length} exps, '
            '${unsyncedBuds.length} budgets, ${unsyncedPays.length} payment details, '
            '${unsyncedDeletes.length} deletions.');

      // 3. Make HTTP request to bulk sync endpoint
      final response = await _apiService.syncData(
        expenses: unsyncedExps,
        budgets: unsyncedBuds,
        paymentDetails: unsyncedPays,
        deletedRecords: unsyncedDeletes,
        lastSyncTime: lastSync,
      );

      if (response['success'] == true) {
        final serverData = response['data'];
        final serverTime = serverData['server_time'];

        // --- PUSH OPERATIONS (Mark locally uploaded items as Synced / Clear deletes) ---
        final localExpIds = unsyncedExps.map((e) => e['id'] as String).toList();
        final localBudIds = unsyncedBuds.map((b) => b['id'] as String).toList();
        final localPayIds = unsyncedPays.map((p) => p['id'] as String).toList();
        final localDeleteIds = unsyncedDeletes.map((d) => d['id'] as String).toList();

        await _dbHelper.markExpensesSynced(localExpIds);
        await _dbHelper.markBudgetsSynced(localBudIds);
        await _dbHelper.markPaymentDetailsSynced(localPayIds);
        await _dbHelper.clearSyncedDeletions(localDeleteIds);

        // --- PULL OPERATIONS (Apply server modifications and server deletions locally) ---
        final List<dynamic> serverExpensesJson = serverData['expenses'] ?? [];
        final List<dynamic> serverBudgetsJson = serverData['budgets'] ?? [];
        final List<dynamic> serverPaymentsJson = serverData['payment_details'] ?? [];
        final List<dynamic> serverDeletes = serverData['deleted_records'] ?? [];

        final serverExpenses = serverExpensesJson.map((e) => Expense.fromMap(e)).toList();
        final serverBudgets = serverBudgetsJson.map((b) => Budget.fromMap(b)).toList();
        final serverPayments = serverPaymentsJson.map((p) => PaymentDetail.fromMap(p)).toList();

        // 1. Process server active upserts
        await _dbHelper.syncDownExpenses(serverExpenses);
        await _dbHelper.syncDownBudgets(serverBudgets);
        await _dbHelper.syncDownPaymentDetails(serverPayments);

        // 2. Process server hard-deletions cleanly
        await _dbHelper.applyDownloadedDeletions(serverDeletes);

        // 4. Set the new synchronization timestamp
        if (serverTime != null) {
          await prefs.setString('last_sync_time', serverTime);
        }

        print('Sync completed successfully at $serverTime.');
        return true;
      } else {
        print('Sync API returned failure: ${response['error']}');
        return false;
      }
    } catch (e) {
      // Catch network timeouts or loopback failures and fail gracefully
      print('Synchronization network failure: $e');
      return false;
    }
  }

  // Wipe sync timestamps upon user log-out
  Future<void> clearSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_sync_time');
  }
}
