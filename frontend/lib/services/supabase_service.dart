import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';

/// Central Supabase service — replaces the old ApiService + SyncService
class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  static const String supabaseUrl = 'https://xszewvmriitjvoidgwnd.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_eNtJ2u6EqJPn8_y65n16fQ_H9m6yNNn';

  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  // ══════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════

  /// Email + Password Sign Up
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: name != null ? {'name': name} : null,
    );
  }

  /// Email + Password Sign In
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign In with Google ID Token (from google_sign_in package)
  Future<AuthResponse> signInWithGoogleIdToken({
    required String idToken,
    String? accessToken,
  }) async {
    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send Password Reset OTP to email
  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Verify OTP (for email verification or password reset)
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: type,
    );
  }

  /// Update password after reset
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Resend OTP (signup verification)
  Future<ResendResponse> resendSignupOtp(String email) async {
    return await _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  // ══════════════════════════════════════════════════════
  // USER PROFILE
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final data = await _client
        .from('users_profile')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return data;
  }

  Future<void> upsertProfile(Map<String, dynamic> updates) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _client.from('users_profile').upsert({
      'id': uid,
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteAccount() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    
    // Delete Storage files
    try {
      final qrFiles = await _client.storage.from('qr-codes').list(path: uid);
      if (qrFiles.isNotEmpty) {
        await _client.storage.from('qr-codes').remove(qrFiles.map((f) => '$uid/${f.name}').toList());
      }
      final invFiles = await _client.storage.from('invoices').list(path: uid);
      if (invFiles.isNotEmpty) {
        await _client.storage.from('invoices').remove(invFiles.map((f) => '$uid/${f.name}').toList());
      }
    } catch (_) {}

    // Complete account deletion from auth.users (cascades to all user data)
    try {
      await _client.rpc('delete_user_account');
    } catch (e) {
      // Fallback or rethrow if database function is missing
      print('Error deleting account via RPC: $e');
    }

    // Sign out
    await signOut();
  }

  // ══════════════════════════════════════════════════════
  // EXPENSES
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('expenses')
        .select()
        .eq('user_id', uid)
        .eq('is_deleted', false)
        .order('transaction_date', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchExpensesSince(String? lastSyncTime) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    var query = _client.from('expenses').select().eq('user_id', uid);
    if (lastSyncTime != null) {
      query = query.gte('updated_at', lastSyncTime);
    }
    final data = await query.order('updated_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> upsertExpenses(List<Map<String, dynamic>> expenses) async {
    if (expenses.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = expenses.map((e) {
      final copy = Map<String, dynamic>.from(e);
      copy['user_id'] = uid;
      copy['updated_at'] = e['updated_at'] ?? DateTime.now().toIso8601String();
      if (copy['is_recurring'] != null) {
        copy['is_recurring'] = copy['is_recurring'] == 1 || copy['is_recurring'] == true;
      }
      if (copy['is_deleted'] != null) {
        copy['is_deleted'] = copy['is_deleted'] == 1 || copy['is_deleted'] == true;
      }
      copy.remove('is_synced');
      return copy;
    }).toList();
    final res = await _client.from('expenses').upsert(rows).select('id');
    if (res.length < rows.length) {
      throw Exception('Upsert failed: RLS policy or database restriction prevented writing some rows to the expenses table.');
    }
  }

  Future<void> softDeleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  Future<void> hardDeleteExpenses(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('expenses').delete().inFilter('id', ids);
  }

  // ══════════════════════════════════════════════════════
  // BUDGETS
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchBudgets() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('budgets')
        .select()
        .eq('user_id', uid)
        .eq('is_deleted', false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> upsertBudgets(List<Map<String, dynamic>> budgets) async {
    if (budgets.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = budgets.map((b) {
      final copy = Map<String, dynamic>.from(b);
      copy['user_id'] = uid;
      copy['updated_at'] = b['updated_at'] ?? DateTime.now().toIso8601String();
      if (copy['is_deleted'] != null) {
        copy['is_deleted'] = copy['is_deleted'] == 1 || copy['is_deleted'] == true;
      }
      copy.remove('is_synced');
      return copy;
    }).toList();
    final res = await _client.from('budgets').upsert(rows).select('id');
    if (res.length < rows.length) {
      throw Exception('Upsert failed: RLS policy or database restriction prevented writing some rows to the budgets table.');
    }
  }

  Future<void> softDeleteBudget(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }

  // ══════════════════════════════════════════════════════
  // PAYMENT DETAILS
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchPaymentDetails() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('payment_details')
        .select()
        .eq('user_id', uid);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> upsertPaymentDetail(Map<String, dynamic> detail) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    final copy = Map<String, dynamic>.from(detail);
    copy['user_id'] = uid;
    copy['updated_at'] = detail['updated_at'] ?? DateTime.now().toIso8601String();
    copy.remove('is_synced');
    final res = await _client.from('payment_details').upsert(copy).select('id');
    if (res.isEmpty) {
      throw Exception('Upsert failed: RLS policy or database restriction prevented writing to the payment_details table.');
    }
  }

  /// Upload QR code image to Supabase Storage and return public URL
  Future<String?> uploadQrCode(Uint8List bytes, String fileName) async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final path = '$uid/$fileName';
    await _client.storage.from('qr-codes').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
    );
    return _client.storage.from('qr-codes').getPublicUrl(path);
  }

  // ══════════════════════════════════════════════════════
  // INVOICE GENERATION (Edge Function)
  // ══════════════════════════════════════════════════════

  /// Call Edge Function to generate PDF invoice — returns PDF bytes
  Future<Uint8List?> generateInvoicePdf(List<Expense> expenses, {String? monthYear}) async {
    try {
      final response = await _client.functions.invoke(
        'generate-invoice',
        body: {
          'expenses': expenses.map((e) => e.toMap()).toList(),
          'month_year': monthYear,
        },
      );
      if (response.data != null) {
        if (response.data is Map) {
          final data = response.data as Map;
          if (data['success'] == true && data['pdf_base64'] != null) {
            return base64Decode(data['pdf_base64'] as String);
          }
        }
        if (response.data is Uint8List) return response.data as Uint8List;
        if (response.data is List) return Uint8List.fromList(List<int>.from(response.data as List));
      }
      return null;
    } catch (e) {
      print('[Invoice] Edge Function error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  // INVOICE HISTORY (Supabase Storage + DB)
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchInvoiceHistory() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('invoice_history')
        .select('id, file_name, month_year, storage_path, file_size_bytes, created_at, updated_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> saveInvoiceToHistory({
    required String fileName,
    required String monthYear,
    required Uint8List pdfBytes,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    // 1. Check and enforce 15 invoices limit per user
    try {
      final existing = await _client
          .from('invoice_history')
          .select('id, storage_path, file_name')
          .eq('user_id', uid)
          .order('created_at', ascending: true); // Oldest first

      if (existing != null && existing.length >= 15) {
        final deleteCount = existing.length - 14; // Bring count down to 14 so we can add 1 to make it 15
        for (int i = 0; i < deleteCount; i++) {
          final oldInvoice = existing[i];
          final oldId = oldInvoice['id'];
          final oldPath = oldInvoice['storage_path'] as String;
          final oldName = oldInvoice['file_name'] as String;

          // A. Delete from Supabase Storage
          try {
            await _client.storage.from('invoices').remove([oldPath]);
          } catch (e) {
            print('[History Cleanup] Storage delete failed for $oldPath: $e');
          }

          // B. Delete from local storage documents directory
          try {
            final dir = await getApplicationDocumentsDirectory();
            final localFile = File('${dir.path}/$oldName');
            if (await localFile.exists()) {
              await localFile.delete();
            }
          } catch (e) {
            print('[History Cleanup] Local file delete failed for $oldName: $e');
          }

          // C. Delete from Supabase Database
          try {
            await _client.from('invoice_history').delete().eq('id', oldId);
          } catch (e) {
            print('[History Cleanup] Database record delete failed for $oldId: $e');
          }
        }
      }
    } catch (e) {
      print('[History Cleanup] Limit check error: $e');
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final storagePath = '$uid/${ts}_$safeFileName';

    // Upload PDF to Supabase Storage
    await _client.storage.from('invoices').uploadBinary(
      storagePath,
      pdfBytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
    );

    // Insert metadata record
    final record = await _client.from('invoice_history').insert({
      'user_id': uid,
      'file_name': safeFileName,
      'month_year': monthYear,
      'storage_path': storagePath,
      'file_size_bytes': pdfBytes.length,
    }).select().single();
    return record;
  }

  Future<Uint8List?> downloadInvoiceBytes(String storagePath) async {
    try {
      final data = await _client.storage.from('invoices').download(storagePath);
      return data;
    } catch (e) {
      print('[History] Download error: $e');
      return null;
    }
  }

  Future<bool> renameInvoice(String id, String newName) async {
    final safeFileName = newName.endsWith('.pdf') ? newName : '$newName.pdf';
    await _client.from('invoice_history').update({
      'file_name': safeFileName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    return true;
  }

  Future<bool> deleteInvoice(String id, String storagePath) async {
    try {
      await _client.storage.from('invoices').remove([storagePath]);
    } catch (_) {}
    await _client.from('invoice_history').delete().eq('id', id);
    return true;
  }

  // ══════════════════════════════════════════════════════
  // AI / GEMINI (Edge Function passthrough)
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> invokeAiFunction(String functionName, Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      if (response.data != null) return Map<String, dynamic>.from(response.data as Map);
      return {'success': false, 'error': 'No response from AI function'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════
  // SYNC (Pull + Push with local SQLite)
  // ══════════════════════════════════════════════════════

  /// Full sync: push local unsynced → Supabase, pull server changes → local
  Future<Map<String, dynamic>?> sync({
    required List<Map<String, dynamic>> unsyncedExpenses,
    required List<Map<String, dynamic>> unsyncedBudgets,
    required List<Map<String, dynamic>> unsyncedPaymentDetails,
    required List<String> deletedExpenseIds,
    required List<String> deletedBudgetIds,
    String? lastSyncTime,
  }) async {
    try {
      // PUSH: upsert all unsynced local data
      await upsertExpenses(unsyncedExpenses);
      await upsertBudgets(unsyncedBudgets);
      for (final pd in unsyncedPaymentDetails) {
        await upsertPaymentDetail(pd);
      }

      // PUSH: apply server-side soft deletes
      for (final id in deletedExpenseIds) {
        await softDeleteExpense(id);
      }
      for (final id in deletedBudgetIds) {
        await softDeleteBudget(id);
      }

      // PULL: fetch server data since last sync
      final serverExpenses = await fetchExpensesSince(lastSyncTime);
      final serverBudgets = await fetchBudgets();
      final serverPayments = await fetchPaymentDetails();

      // Store new server time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());

      return {
        'expenses': serverExpenses,
        'budgets': serverBudgets,
        'paymentDetails': serverPayments,
      };
    } catch (e) {
      print('[Sync] Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  // RECEIPT SCAN (AI via old backend URL or Edge Function)
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>> scanReceipt(Uint8List imageBytes, {String? geminiApiKey}) async {
    try {
      // Upload to receipts bucket temporarily
      final uid = currentUser?.id;
      if (uid == null) return {'success': false, 'error': 'Not authenticated'};
      final path = '$uid/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('receipts').uploadBinary(
        path, imageBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      // Invoke scan Edge Function
      final response = await _client.functions.invoke(
        'scan-receipt',
        body: {'storage_path': path, 'gemini_api_key': geminiApiKey},
      );
      // Cleanup temp file
      try { await _client.storage.from('receipts').remove([path]); } catch (_) {}
      if (response.data != null) return Map<String, dynamic>.from(response.data as Map);
      return {'success': false, 'error': 'Scan failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════
  // FILE DOWNLOAD HELPER (Android Scoped Storage)
  // ══════════════════════════════════════════════════════

  static Future<bool> saveFileToDownloads({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.example.groww_expense_tracker/save_file');
        final bool success = await platform.invokeMethod('saveFileToDownloads', {
          'fileName': fileName,
          'fileBytes': bytes,
          'mimeType': mimeType,
        });
        return success;
      } catch (e) {
        print('Native saveFileToDownloads failed: $e');
        return false;
      }
    }
    return false;
  }

  // Generate invoice locally and save to history
  Future<String?> generateAndSaveInvoice(List<Expense> expenses, {String? monthYear}) async {
    final now = DateTime.now();
    final myMonthYear = monthYear ?? '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthLabel = _monthLabel(myMonthYear);
    final formattedTime = '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final fileName = 'Statement_${monthLabel}_${now.year}_$formattedTime.pdf';

    // Try Edge Function first
    Uint8List? pdfBytes = await generateInvoicePdf(expenses, monthYear: myMonthYear);

    if (pdfBytes == null) return null;

    // Save locally
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    // Auto-save to Downloads on Android
    if (Platform.isAndroid) {
      try {
        await saveFileToDownloads(fileName: fileName, bytes: pdfBytes, mimeType: 'application/pdf');
      } catch (_) {}
    }

    // Save to cloud history (silent)
    saveInvoiceToHistory(
      fileName: fileName,
      monthYear: myMonthYear,
      pdfBytes: pdfBytes,
    ).catchError((Object e) {
      print('[History] Silent cloud save failed: $e');
      return null;
    });

    return file.path;
  }

  String _monthLabel(String monthYear) {
    try {
      final parts = monthYear.split('-');
      final month = int.parse(parts[1]);
      const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
      return months[month];
    } catch (_) {
      return monthYear;
    }
  }
}
