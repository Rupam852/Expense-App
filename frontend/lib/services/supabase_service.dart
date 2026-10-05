import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';
import '../utils/pdf_unicode_helper.dart';
import 'database_helper.dart';

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

  /// Update auth user metadata (cloud-backed per user account)
  Future<UserResponse?> updateUserMetadata(Map<String, dynamic> data) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(data: data),
      );
    } catch (e) {
      print('[Supabase] updateUserMetadata error: $e');
      return null;
    }
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

  /// Sync Firebase Cloud Messaging (FCM) push token to Supabase users_profile
  Future<void> saveFcmToken(String token) async {
    final uid = currentUser?.id;
    if (uid == null || token.trim().isEmpty) return;
    try {
      await _client.from('users_profile').upsert({
        'id': uid,
        'fcm_token': token.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('[Supabase] FCM token synced successfully for user: $uid');
    } catch (e) {
      print('[Supabase] Error saving FCM token: $e');
    }
  }

  Future<void> deleteAccount() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    
    // Delete Storage files (e.g. business payment QR code)
    try {
      final qrFiles = await _client.storage.from('qr-codes').list(path: uid);
      if (qrFiles.isNotEmpty) {
        await _client.storage.from('qr-codes').remove(qrFiles.map((f) => '$uid/${f.name}').toList());
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
    try {
      final data = await _client
          .from('expenses')
          .select()
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .order('transaction_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchExpenses error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpensesSince(String? lastSyncTime) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      if (lastSyncTime != null && lastSyncTime.isNotEmpty) {
        final data = await _client
            .from('expenses')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .gte('updated_at', lastSyncTime)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _client
            .from('expenses')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('[Supabase] fetchExpensesSince error: $e');
      return [];
    }
  }

  Future<void> upsertExpenses(List<Map<String, dynamic>> expenses) async {
    if (expenses.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = expenses.map((e) {
      return <String, dynamic>{
        'id': e['id']?.toString(),
        'user_id': uid,
        'amount': (e['amount'] is num) ? (e['amount'] as num).toDouble() : (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0),
        'currency': e['currency']?.toString() ?? 'INR',
        'category': e['category']?.toString() ?? 'Others',
        'description': e['description']?.toString() ?? '',
        'transaction_date': e['transaction_date']?.toString() ?? DateTime.now().toIso8601String(),
        'receipt_url': e['receipt_url']?.toString(),
        'is_recurring': e['is_recurring'] == 1 || e['is_recurring'] == true,
        'recurrence_period': e['recurrence_period']?.toString() ?? 'none',
        'ledger_type': e['ledger_type']?.toString() ?? 'personal',
        'is_deleted': e['is_deleted'] == 1 || e['is_deleted'] == true,
        'created_at': e['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updated_at': e['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();
    await _client.from('expenses').upsert(rows);
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
    try {
      final data = await _client
          .from('budgets')
          .select()
          .eq('user_id', uid)
          .eq('is_deleted', false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchBudgets error: $e');
      return [];
    }
  }

  Future<void> upsertBudgets(List<Map<String, dynamic>> budgets) async {
    if (budgets.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = budgets.map((b) {
      return <String, dynamic>{
        'id': b['id']?.toString(),
        'user_id': uid,
        'category': b['category']?.toString() ?? 'Others',
        'amount_limit': (b['amount_limit'] is num) ? (b['amount_limit'] as num).toDouble() : (double.tryParse(b['amount_limit']?.toString() ?? '0') ?? 0.0),
        'month_year': b['month_year']?.toString() ?? '',
        'is_deleted': b['is_deleted'] == 1 || b['is_deleted'] == true,
        'created_at': b['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updated_at': b['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();
    await _client.from('budgets').upsert(rows);
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
    try {
      final data = await _client
          .from('payment_details')
          .select()
          .eq('user_id', uid)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchPaymentDetails error: $e');
      return [];
    }
  }

  Future<void> upsertPaymentDetails(List<Map<String, dynamic>> details) async {
    if (details.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = details.map((d) {
      return <String, dynamic>{
        'id': d['id']?.toString(),
        'user_id': uid,
        'name': d['name']?.toString() ?? 'Primary UPI',
        'upi_id': d['upi_id']?.toString() ?? '',
        'qr_code_url': d['qr_code_url']?.toString(),
        'is_primary': d['is_primary'] == 1 || d['is_primary'] == true,
        'sort_order': d['sort_order'] is int ? d['sort_order'] as int : (int.tryParse(d['sort_order']?.toString() ?? '0') ?? 0),
        'created_at': d['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updated_at': d['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();

    await _client.from('payment_details').upsert(rows);
  }

  Future<void> upsertPaymentDetail(Map<String, dynamic> detail) async {
    await upsertPaymentDetails([detail]);
  }

  Future<void> deletePaymentDetailOnServer(String id) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('payment_details').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      print('[Sync] deletePaymentDetailOnServer error: $e');
    }
  }

  Future<void> deletePaymentDetailsOnServer() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('payment_details').delete().eq('user_id', uid);
    } catch (e) {
      print('[Sync] deletePaymentDetailsOnServer error: $e');
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
  // INVOICE GENERATION (Local PDF Generator)
  // ══════════════════════════════════════════════════════

  /// Generates PDF invoice bytes with chronological sorting, wrapped descriptions,
  /// issuer info, repayment UPI ID, and official Grow Expense styling.
  Future<Uint8List?> generateInvoicePdf(List<Expense> expenses, {String? monthYear}) async {
    if (expenses.isEmpty) {
      print('[Invoice] No expenses provided. Aborting PDF generation.');
      return null;
    }
    try {
      final sortedExpenses = List<Expense>.from(expenses)..sort((a, b) {
        final dateCmp = a.transactionDate.compareTo(b.transactionDate);
        if (dateCmp != 0) return dateCmp;
        return a.createdAt.compareTo(b.createdAt);
      });

      // Fetch user profile info
      String userName = 'User';
      String userEmail = '';
      try {
        final profile = await fetchProfile();
        final user = currentUser;
        userName = profile?['name'] ?? user?.userMetadata?['name'] ?? user?.userMetadata?['full_name'] ?? 'User';
        userEmail = user?.email ?? profile?['email'] ?? '';
      } catch (_) {
        final user = currentUser;
        userName = user?.userMetadata?['name'] ?? user?.userMetadata?['full_name'] ?? 'User';
        userEmail = user?.email ?? '';
      }

      // If still default, try SharedPreferences cached profile
      if (userName == 'User' || userEmail.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedStr = prefs.getString('cached_user_profile');
          if (cachedStr != null) {
            final cached = json.decode(cachedStr) as Map<String, dynamic>;
            if (userName == 'User' && cached['name'] != null) {
              userName = cached['name'].toString();
            }
            if (userEmail.isEmpty && cached['email'] != null) {
              userEmail = cached['email'].toString();
            }
          }
        } catch (_) {}
      }

      // Fetch primary or only UPI ID from local SQLite database
      String upiId = '';
      try {
        final paymentDetails = await DatabaseHelper.instance.getPaymentDetails();
        if (paymentDetails.isNotEmpty) {
          final primary = paymentDetails.firstWhere(
            (p) => p.isPrimary,
            orElse: () => paymentDetails.first,
          );
          upiId = primary.upiId.trim();
        }
      } catch (_) {}

      final pdfTheme = await PdfUnicodeHelper.getUnicodePdfTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final double total = sortedExpenses.fold(0.0, (sum, e) => sum + e.amount);
      final issueDateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final mintColor = PdfColor.fromHex('#00D09C');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Brand Title
                pw.Text(
                  'GROW EXPENSE',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: mintColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Official Reimbursement & Billing Statement',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.8, color: PdfColors.grey300),
                pw.SizedBox(height: 8),

                // Issuer & Payment Info Row
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Column: Issued By, Email, Date of Issue
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'Issued By: ',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
                              ),
                              pw.TextSpan(
                                text: userName,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
                              ),
                            ],
                          ),
                        ),
                        if (userEmail.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Email: $userEmail',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                          ),
                        ],
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Date of Issue: $issueDateStr',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                        ),
                      ],
                    ),

                    // Right Column: UPI ID for Repayment
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'UPI ID for Repayment: ',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
                              ),
                              pw.TextSpan(
                                text: upiId,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Category', 'Description', 'Recurring', 'Amount'],
                data: sortedExpenses.map((e) {
                  return [
                    DateFormat('dd/MM/yyyy').format(e.transactionDate),
                    e.category,
                    _formatDescriptionForPdf(e.description),
                    e.isRecurring ? 'Yes (${e.recurrencePeriod})' : 'No',
                    '${e.amount.toStringAsFixed(2)} INR',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                  fontSize: 9.5,
                ),
                headerDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
                  ),
                ),
                cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  4: pw.Alignment.centerRight,
                },
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  ),
                ),
              ),
              pw.SizedBox(height: 14),

              // Total Expenses Section with Mint Accent Underline
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 180,
                        height: 2,
                        color: mintColor,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'Total Expenses:   ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            '${total.toStringAsFixed(2)} INR',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11.5,
                              color: mintColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
          footer: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                pw.Container(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Generated instantly by Grow Expense App. For any discrepancies, contact issuer above.',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      print('[Invoice] Local PDF generation error: $e');
      return null;
    }
  }

  /// Formats long description into maximum 2-3 lines with ellipsis if it overflows
  static String _formatDescriptionForPdf(String desc) {
    final trimmed = desc.trim();
    if (trimmed.isEmpty) return '-';

    final paragraphs = trimmed.split(RegExp(r'\r?\n'));
    final List<String> lines = [];
    bool hasMore = false;
    const maxLines = 3;
    const maxCharsPerLine = 28;

    for (final para in paragraphs) {
      if (lines.length >= maxLines) {
        hasMore = true;
        break;
      }
      final words = para.split(RegExp(r'\s+'));
      String currentLine = '';

      for (final word in words) {
        if (lines.length >= maxLines) {
          hasMore = true;
          break;
        }
        final testLine = currentLine.isEmpty ? word : '$currentLine $word';
        if (testLine.length <= maxCharsPerLine) {
          currentLine = testLine;
        } else {
          if (currentLine.isNotEmpty) {
            lines.add(currentLine);
            if (lines.length >= maxLines) {
              hasMore = true;
              currentLine = '';
              break;
            }
          }
          currentLine = word;
        }
      }
      if (currentLine.isNotEmpty) {
        if (lines.length < maxLines) {
          lines.add(currentLine);
        } else {
          hasMore = true;
        }
      }
    }

    if (hasMore && lines.isNotEmpty) {
      final last = lines.last;
      lines[lines.length - 1] = last.length > (maxCharsPerLine - 3)
          ? '${last.substring(0, maxCharsPerLine - 3)}...'
          : '$last...';
    }

    return lines.join('\n');
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
  // KHATA / UDHAR (Cloud Backup)
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchKhataEntries() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('khata_entries')
          .select()
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .order('entry_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchKhataEntries error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchKhataEntriesSince(String? lastSyncTime) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      if (lastSyncTime != null && lastSyncTime.isNotEmpty) {
        final data = await _client
            .from('khata_entries')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .gte('updated_at', lastSyncTime)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _client
            .from('khata_entries')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('[Supabase] fetchKhataEntriesSince error: $e');
      return [];
    }
  }

  Future<void> upsertKhataEntries(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = entries.map((e) {
      return <String, dynamic>{
        'id': e['id']?.toString(),
        'user_id': uid,
        'person_name': e['person_name']?.toString() ?? '',
        'phone_number': e['phone_number']?.toString(),
        'amount': (e['amount'] is num) ? (e['amount'] as num).toDouble() : (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0),
        'type': e['type']?.toString() ?? 'GIVE',
        'entry_date': e['entry_date']?.toString() ?? DateTime.now().toIso8601String(),
        'due_date': e['due_date']?.toString(),
        'note': e['note']?.toString(),
        'ledger_type': e['ledger_type']?.toString() ?? 'personal',
        'is_settled': e['is_settled'] == 1 || e['is_settled'] == true,
        'settled_at': e['settled_at']?.toString(),
        'is_deleted': e['is_deleted'] == 1 || e['is_deleted'] == true,
        'created_at': e['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updated_at': e['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();
    await _client.from('khata_entries').upsert(rows);
  }

  Future<void> softDeleteKhataEntry(String id) async {
    await _client.from('khata_entries').delete().eq('id', id);
  }

  // ══════════════════════════════════════════════════════
  // SUBSCRIPTIONS & RECURRING BILLS (Cloud Backup)
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('subscriptions')
          .select()
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .order('next_renewal_date', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchSubscriptions error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubscriptionsSince(String? lastSyncTime) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      if (lastSyncTime != null && lastSyncTime.isNotEmpty) {
        final data = await _client
            .from('subscriptions')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .gte('updated_at', lastSyncTime)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _client
            .from('subscriptions')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('[Supabase] fetchSubscriptionsSince error: $e');
      return [];
    }
  }

  Future<void> upsertSubscriptions(List<Map<String, dynamic>> subscriptions) async {
    if (subscriptions.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = subscriptions.map((s) {
      return <String, dynamic>{
        'id': s['id']?.toString(),
        'user_id': uid,
        'name': s['name']?.toString() ?? '',
        'amount': (s['amount'] is num) ? (s['amount'] as num).toDouble() : (double.tryParse(s['amount']?.toString() ?? '0') ?? 0.0),
        'billing_cycle': s['billing_cycle']?.toString() ?? 'monthly',
        'next_renewal_date': s['next_renewal_date']?.toString() ?? DateTime.now().toIso8601String(),
        'category': s['category']?.toString() ?? 'Subscription',
        'auto_renewal': s['auto_renewal'] == 1 || s['auto_renewal'] == true,
        'reminder_days_before': s['reminder_days_before'] is int ? s['reminder_days_before'] as int : (int.tryParse(s['reminder_days_before']?.toString() ?? '2') ?? 2),
        'payment_method': s['payment_method']?.toString(),
        'note': s['note']?.toString(),
        'is_active': s['is_active'] == 1 || s['is_active'] == true,
        'is_deleted': s['is_deleted'] == 1 || s['is_deleted'] == true,
        'created_at': s['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updated_at': s['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();
    await _client.from('subscriptions').upsert(rows);
  }

  Future<void> softDeleteSubscription(String id) async {
    await _client.from('subscriptions').delete().eq('id', id);
  }

  // ══════════════════════════════════════════════════════
  // SPLIT BILLS (Cloud Backup)
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchSplitBills() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('split_bills')
          .select()
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .order('bill_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchSplitBills error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSplitBillsSince(String? lastSyncTime) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      if (lastSyncTime != null && lastSyncTime.isNotEmpty) {
        final data = await _client
            .from('split_bills')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .gte('updated_at', lastSyncTime)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _client
            .from('split_bills')
            .select()
            .eq('user_id', uid)
            .eq('is_deleted', false)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('[Supabase] fetchSplitBillsSince error: $e');
      return [];
    }
  }

  Future<void> upsertSplitBills(List<Map<String, dynamic>> splitBills) async {
    if (splitBills.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = splitBills.map((b) {
      return <String, dynamic>{
        'id': b['id']?.toString(),
        'user_id': uid,
        'title': b['title']?.toString() ?? '',
        'total_amount': (b['total_amount'] is num) ? (b['total_amount'] as num).toDouble() : (double.tryParse(b['total_amount']?.toString() ?? '0') ?? 0.0),
        'paid_by': b['paid_by']?.toString() ?? 'You',
        'payer_upi_id': b['payer_upi_id']?.toString(),
        'note': b['note']?.toString(),
        'split_type': b['split_type']?.toString() ?? 'equal',
        'participants_json': b['participants_json']?.toString() ?? '[]',
        'bill_date': b['bill_date']?.toString() ?? DateTime.now().toIso8601String(),
        'is_deleted': b['is_deleted'] == 1 || b['is_deleted'] == true,
        'created_at': b['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updated_at': b['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();
    await _client.from('split_bills').upsert(rows);
  }

  Future<void> softDeleteSplitBill(String id) async {
    await _client.from('split_bills').delete().eq('id', id);
  }

  // ══════════════════════════════════════════════════════
  // BUSINESS PROFILE (Cloud Backup)
  // ══════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> fetchBusinessProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final data = await _client
          .from('business_profile')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      return data;
    } catch (e) {
      print('[Supabase] fetchBusinessProfile error: $e');
      return null;
    }
  }

  Future<void> upsertBusinessProfile(Map<String, dynamic> profile) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('business_profile').upsert({
        'id': profile['id']?.toString() ?? 'default_business',
        'user_id': uid,
        'business_name': profile['business_name']?.toString() ?? 'My Business',
        'business_type': profile['business_type']?.toString(),
        'address': profile['address']?.toString(),
        'phone': profile['phone']?.toString(),
        'email': profile['email']?.toString(),
        'gstin': profile['gstin']?.toString(),
        'upi_id': profile['upi_id']?.toString(),
        'logo_path': profile['logo_path']?.toString(),
        'terms_and_conditions': profile['terms_and_conditions']?.toString(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('[Supabase] upsertBusinessProfile error: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  // BUSINESS SALES (Cloud Backup)
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchBusinessSales() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('business_sales')
          .select()
          .eq('user_id', uid)
          .order('sale_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchBusinessSales error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchBusinessSalesSince(String? lastSyncTime) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      if (lastSyncTime != null && lastSyncTime.isNotEmpty) {
        final data = await _client
            .from('business_sales')
            .select()
            .eq('user_id', uid)
            .gte('updated_at', lastSyncTime)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _client
            .from('business_sales')
            .select()
            .eq('user_id', uid)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('[Supabase] fetchBusinessSalesSince error: $e');
      return [];
    }
  }

  Future<void> upsertBusinessSales(List<Map<String, dynamic>> sales) async {
    if (sales.isEmpty) return;
    final uid = currentUser?.id;
    if (uid == null) return;
    final rows = sales.map((s) {
      final subtotalVal = (s['subtotal'] is num)
          ? (s['subtotal'] as num).toDouble()
          : (s['total_amount'] is num)
              ? (s['total_amount'] as num).toDouble()
              : (double.tryParse(s['subtotal']?.toString() ?? s['total_amount']?.toString() ?? '0') ?? 0.0);
      final payMethod = s['payment_method']?.toString() ?? s['payment_mode']?.toString() ?? 'cash';
      return <String, dynamic>{
        'id': s['id']?.toString(),
        'user_id': uid,
        'customer_id': s['customer_id']?.toString(),
        'customer_name': s['customer_name']?.toString() ?? '',
        'customer_phone': s['customer_phone']?.toString(),
        'customer_address': s['customer_address']?.toString(),
        'customer_gstin': s['customer_gstin']?.toString(),
        'invoice_no': s['invoice_no']?.toString(),
        'sale_date': s['sale_date']?.toString() ?? DateTime.now().toIso8601String(),
        'subtotal': subtotalVal,
        'total_amount': subtotalVal,
        'discount_amount': (s['discount_amount'] is num) ? (s['discount_amount'] as num).toDouble() : (double.tryParse(s['discount_amount']?.toString() ?? '0') ?? 0.0),
        'tax_amount': (s['tax_amount'] is num) ? (s['tax_amount'] as num).toDouble() : (double.tryParse(s['tax_amount']?.toString() ?? '0') ?? 0.0),
        'final_amount': (s['final_amount'] is num) ? (s['final_amount'] as num).toDouble() : (double.tryParse(s['final_amount']?.toString() ?? '0') ?? 0.0),
        'paid_amount': (s['paid_amount'] is num) ? (s['paid_amount'] as num).toDouble() : (double.tryParse(s['paid_amount']?.toString() ?? '0') ?? 0.0),
        'balance_due': (s['balance_due'] is num) ? (s['balance_due'] as num).toDouble() : (double.tryParse(s['balance_due']?.toString() ?? '0') ?? 0.0),
        'payment_method': payMethod,
        'payment_mode': payMethod,
        'payment_status': s['payment_status']?.toString() ?? 'paid',
        'notes': s['notes']?.toString(),
        'items_json': s['items_json']?.toString(),
        'created_at': s['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updated_at': s['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();
    await _client.from('business_sales').upsert(rows);
  }

  Future<void> deleteBusinessSale(String id) async {
    await _client.from('business_sales').delete().eq('id', id);
  }

  // ══════════════════════════════════════════════════════
  // BUSINESS ITEMS / INVENTORY CATALOG (Cloud Backup)
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchBusinessItems() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      final data = await _client
          .from('business_items')
          .select()
          .eq('user_id', uid)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[Supabase] fetchBusinessItems error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchBusinessItemsSince(String? lastSyncTime) async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    try {
      if (lastSyncTime != null && lastSyncTime.isNotEmpty) {
        final data = await _client
            .from('business_items')
            .select()
            .eq('user_id', uid)
            .gte('updated_at', lastSyncTime)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _client
            .from('business_items')
            .select()
            .eq('user_id', uid)
            .order('updated_at');
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('[Supabase] fetchBusinessItemsSince error: $e');
      return [];
    }
  }

  Future<void> upsertBusinessItems(List<Map<String, dynamic>> items) async {
    final uid = currentUser?.id;
    if (uid == null || items.isEmpty) return;
    final rows = items.map((it) {
      return {
        'id': it['id']?.toString() ?? '',
        'user_id': uid,
        'name': it['name']?.toString() ?? '',
        'purchase_price': (it['purchase_price'] is num)
            ? (it['purchase_price'] as num).toDouble()
            : (double.tryParse(it['purchase_price']?.toString() ?? '0') ?? 0.0),
        'selling_price': (it['selling_price'] is num)
            ? (it['selling_price'] as num).toDouble()
            : (double.tryParse(it['selling_price']?.toString() ?? '0') ?? 0.0),
        'tax_rate': (it['tax_rate'] is num)
            ? (it['tax_rate'] as num).toDouble()
            : (double.tryParse(it['tax_rate']?.toString() ?? '0') ?? 0.0),
        'unit': it['unit']?.toString() ?? 'pcs',
        'category': it['category']?.toString(),
        'notes': it['notes']?.toString(),
        'barcode': it['barcode']?.toString() ?? '',
        'stock_quantity': (it['stock_quantity'] is num)
            ? (it['stock_quantity'] as num).toDouble()
            : (double.tryParse(it['stock_quantity']?.toString() ?? '0') ?? 0.0),
        'low_stock_limit': (it['low_stock_limit'] is num)
            ? (it['low_stock_limit'] as num).toDouble()
            : (double.tryParse(it['low_stock_limit']?.toString() ?? '5') ?? 5.0),
        'track_stock': it['track_stock'] == 1 || it['track_stock'] == true || it['track_stock'] == '1' || it['track_stock'] == null ? true : false,
        'updated_at': it['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }).toList();
    await _client.from('business_items').upsert(rows);
  }

  Future<void> deleteBusinessItem(String id) async {
    await _client.from('business_items').delete().eq('id', id);
  }

  // ══════════════════════════════════════════════════════
  // SYNC (Pull + Push with local SQLite)
  // ══════════════════════════════════════════════════════

  /// Full sync: push local unsynced → Supabase, pull server changes → local
  Future<Map<String, dynamic>?> sync({
    required List<Map<String, dynamic>> unsyncedExpenses,
    required List<Map<String, dynamic>> unsyncedBudgets,
    required List<Map<String, dynamic>> unsyncedPaymentDetails,
    List<Map<String, dynamic>> unsyncedKhataEntries = const [],
    List<Map<String, dynamic>> unsyncedSubscriptions = const [],
    List<Map<String, dynamic>> unsyncedSplitBills = const [],
    List<Map<String, dynamic>> unsyncedBusinessSales = const [],
    List<Map<String, dynamic>> unsyncedBusinessItems = const [],
    Map<String, dynamic>? unsyncedBusinessProfile,
    required List<String> deletedExpenseIds,
    required List<String> deletedBudgetIds,
    List<String> deletedPaymentDetailIds = const [],
    List<String> deletedKhataIds = const [],
    List<String> deletedSubscriptionIds = const [],
    List<String> deletedSplitBillIds = const [],
    List<String> deletedBusinessSaleIds = const [],
    List<String> deletedBusinessItemIds = const [],
    String? lastSyncTime,
  }) async {
    try {
      final uid = currentUser?.id;
      if (uid == null) {
        print('[Sync] No authenticated Supabase user found.');
        return null;
      }

      // 1. PUSH unsynced data to cloud in parallel with individual error protection
      await Future.wait([
        if (unsyncedExpenses.isNotEmpty)
          upsertExpenses(unsyncedExpenses).catchError((e) => print('[Sync Error] Expenses push failed: $e')),
        if (unsyncedBudgets.isNotEmpty)
          upsertBudgets(unsyncedBudgets).catchError((e) => print('[Sync Error] Budgets push failed: $e')),
        if (unsyncedPaymentDetails.isNotEmpty)
          upsertPaymentDetails(unsyncedPaymentDetails).catchError((e) => print('[Sync Error] PaymentDetails push failed: $e')),
        if (unsyncedKhataEntries.isNotEmpty)
          upsertKhataEntries(unsyncedKhataEntries).catchError((e) => print('[Sync Error] Khata push failed: $e')),
        if (unsyncedSubscriptions.isNotEmpty)
          upsertSubscriptions(unsyncedSubscriptions).catchError((e) => print('[Sync Error] Subscriptions push failed: $e')),
        if (unsyncedSplitBills.isNotEmpty)
          upsertSplitBills(unsyncedSplitBills).catchError((e) => print('[Sync Error] SplitBills push failed: $e')),
        if (unsyncedBusinessSales.isNotEmpty)
          upsertBusinessSales(unsyncedBusinessSales).catchError((e) => print('[Sync Error] BusinessSales push failed: $e')),
        if (unsyncedBusinessItems.isNotEmpty)
          upsertBusinessItems(unsyncedBusinessItems).catchError((e) => print('[Sync Error] BusinessItems push failed: $e')),
        if (unsyncedBusinessProfile != null)
          upsertBusinessProfile(unsyncedBusinessProfile).catchError((e) => print('[Sync Error] BusinessProfile push failed: $e')),
      ]).timeout(const Duration(seconds: 12));

      // 2. PUSH batch deletes in parallel with timeout
      await Future.wait([
        if (deletedExpenseIds.isNotEmpty)
          _client.from('expenses').delete().inFilter('id', deletedExpenseIds).eq('user_id', uid).catchError((e) => null),
        if (deletedBudgetIds.isNotEmpty)
          _client.from('budgets').delete().inFilter('id', deletedBudgetIds).eq('user_id', uid).catchError((e) => null),
        if (deletedPaymentDetailIds.isNotEmpty)
          _client.from('payment_details').delete().inFilter('id', deletedPaymentDetailIds).eq('user_id', uid).catchError((e) => null),
        if (deletedKhataIds.isNotEmpty)
          _client.from('khata_entries').delete().inFilter('id', deletedKhataIds).eq('user_id', uid).catchError((e) => null),
        if (deletedSubscriptionIds.isNotEmpty)
          _client.from('subscriptions').delete().inFilter('id', deletedSubscriptionIds).eq('user_id', uid).catchError((e) => null),
        if (deletedSplitBillIds.isNotEmpty)
          _client.from('split_bills').delete().inFilter('id', deletedSplitBillIds).eq('user_id', uid).catchError((e) => null),
        if (deletedBusinessSaleIds.isNotEmpty)
          _client.from('business_sales').delete().inFilter('id', deletedBusinessSaleIds).eq('user_id', uid).catchError((e) => null),
        if (deletedBusinessItemIds.isNotEmpty)
          _client.from('business_items').delete().inFilter('id', deletedBusinessItemIds).eq('user_id', uid).catchError((e) => null),
      ]).timeout(const Duration(seconds: 8));

      // 3. PULL fresh server data concurrently with timeout
      final pullResults = await Future.wait([
        fetchExpensesSince(lastSyncTime),
        fetchBudgets(),
        fetchPaymentDetails(),
        fetchKhataEntriesSince(lastSyncTime),
        fetchSubscriptionsSince(lastSyncTime),
        fetchSplitBillsSince(lastSyncTime),
        fetchBusinessSalesSince(lastSyncTime),
        fetchBusinessItemsSince(lastSyncTime),
        fetchBusinessProfile(),
      ]).timeout(const Duration(seconds: 15));

      final delExpSet = deletedExpenseIds.toSet();
      final delBudSet = deletedBudgetIds.toSet();
      final delPaySet = deletedPaymentDetailIds.toSet();
      final delKhataSet = deletedKhataIds.toSet();
      final delSubSet = deletedSubscriptionIds.toSet();
      final delSplitSet = deletedSplitBillIds.toSet();
      final delSaleSet = deletedBusinessSaleIds.toSet();
      final delItemSet = deletedBusinessItemIds.toSet();

      final serverExpenses = (pullResults[0] as List<Map<String, dynamic>>)
          .where((e) => !delExpSet.contains(e['id']?.toString()))
          .toList();
      final serverBudgets = (pullResults[1] as List<Map<String, dynamic>>)
          .where((b) => !delBudSet.contains(b['id']?.toString()))
          .toList();
      final serverPayments = (pullResults[2] as List<Map<String, dynamic>>)
          .where((p) => !delPaySet.contains(p['id']?.toString()))
          .toList();
      final serverKhata = (pullResults[3] as List<Map<String, dynamic>>)
          .where((k) => !delKhataSet.contains(k['id']?.toString()))
          .toList();
      final serverSubs = (pullResults[4] as List<Map<String, dynamic>>)
          .where((s) => !delSubSet.contains(s['id']?.toString()))
          .toList();
      final serverSplits = (pullResults[5] as List<Map<String, dynamic>>)
          .where((s) => !delSplitSet.contains(s['id']?.toString()))
          .toList();
      final serverBusinessSales = (pullResults[6] as List<Map<String, dynamic>>)
          .where((s) => !delSaleSet.contains(s['id']?.toString()))
          .toList();
      final serverBusinessItems = (pullResults[7] as List<Map<String, dynamic>>)
          .where((i) => !delItemSet.contains(i['id']?.toString()))
          .toList();
      final serverBusinessProfile = pullResults[8] as Map<String, dynamic>?;

      // Store new server time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());

      return {
        'expenses': serverExpenses,
        'budgets': serverBudgets,
        'paymentDetails': serverPayments,
        'khataEntries': serverKhata,
        'subscriptions': serverSubs,
        'splitBills': serverSplits,
        'businessSales': serverBusinessSales,
        'businessItems': serverBusinessItems,
        'businessProfile': serverBusinessProfile,
      };
    } catch (e) {
      print('[Sync] Error during Supabase sync: $e');
      return null;
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
    if (expenses.isEmpty) {
      print('[Invoice] No expenses to save statement.');
      return null;
    }
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
