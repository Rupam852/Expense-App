import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../services/expense_provider.dart';
import '../services/database_helper.dart';
import '../models/business_sale.dart';
import '../widgets/custom_toast.dart';
import '../widgets/report_issue_modal.dart';
import 'backup_scope_screen.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  String _formatSyncTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  void _showRestoreBackupDialog(BuildContext context, ExpenseProvider expenseProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFF00D09C).withValues(alpha: 0.3),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF00D09C), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Restore Cloud Backup?',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'This will pull your complete cloud backup from Supabase (Expenses, Budgets, Payment Accounts, Khata, Split Bills, Subscriptions) and restore it to this device.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D09C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                CustomToast.show(context, 'Restoring backup from Supabase Cloud...');
                try {
                  final success = await expenseProvider.restoreFromCloud();
                  if (context.mounted) {
                    if (success) {
                      CustomToast.show(
                        context,
                        '✅ Backup restored! (${expenseProvider.expenses.length} expenses, ${expenseProvider.khataEntries.length} khata entries, ${expenseProvider.paymentDetails.length} payment methods)',
                      );
                    } else {
                      CustomToast.show(
                        context,
                        expenseProvider.syncErrorMessage ?? 'Failed to restore backup from cloud.',
                        isError: true,
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    CustomToast.show(context, 'Restore error: $e', isError: true);
                  }
                }
              },
              child: Text('Restore Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteMonthRecordsDialog(
    BuildContext context,
    bool isBusinessMode,
    ExpenseProvider expenseProvider,
  ) async {
    DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final monthStr = DateFormat('yyyy-MM').format(selectedMonth);
            final monthLabel = DateFormat('MMMM yyyy').format(selectedMonth);

            int personalExpenseCount = 0;
            int businessExpenseCount = 0;

            if (!isBusinessMode) {
              personalExpenseCount = expenseProvider.expenses
                  .where((e) =>
                      !e.isDeleted &&
                      e.ledgerType == 'personal' &&
                      DateFormat('yyyy-MM').format(e.transactionDate) == monthStr)
                  .length;
            } else {
              businessExpenseCount = expenseProvider.expenses
                  .where((e) =>
                      !e.isDeleted &&
                      e.ledgerType == 'business' &&
                      DateFormat('yyyy-MM').format(e.transactionDate) == monthStr)
                  .length;
            }

            return FutureBuilder<List<BusinessSale>>(
              future: isBusinessMode ? DatabaseHelper.instance.getBusinessSales() : Future.value([]),
              builder: (context, snapshot) {
                final sales = snapshot.data ?? [];
                final salesCount = sales.where((s) => DateFormat('yyyy-MM').format(s.saleDate) == monthStr).length;

                final totalRecords = isBusinessMode
                    ? (businessExpenseCount + salesCount)
                    : personalExpenseCount;

                final hasData = totalRecords > 0;

                return AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF1E2433) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isBusinessMode ? 'Delete Month Business Data' : 'Delete Month Personal Data',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Select the month you wish to clean up:',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedMonth,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                            helpText: 'Select Month to Clean Data',
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedMonth = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.redAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    monthLabel,
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!hasData)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No ${isBusinessMode ? 'business' : 'personal'} records found for $monthLabel. Nothing to delete.',
                                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Found ${isBusinessMode ? '$salesCount sales & $businessExpenseCount business expenses' : '$personalExpenseCount personal expenses'} in $monthLabel. This action is irreversible.',
                                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.redAccent.shade100 : Colors.red.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: !hasData
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              if (!isBusinessMode) {
                                final toDelete = expenseProvider.expenses
                                    .where((e) =>
                                        !e.isDeleted &&
                                        e.ledgerType == 'personal' &&
                                        DateFormat('yyyy-MM').format(e.transactionDate) == monthStr)
                                    .toList();
                                for (var exp in toDelete) {
                                  await expenseProvider.deleteExpense(exp.id);
                                }
                                if (context.mounted) {
                                  CustomToast.show(context, 'Deleted ${toDelete.length} personal expenses for $monthLabel.');
                                }
                              } else {
                                final expToDelete = expenseProvider.expenses
                                    .where((e) =>
                                        !e.isDeleted &&
                                        e.ledgerType == 'business' &&
                                        DateFormat('yyyy-MM').format(e.transactionDate) == monthStr)
                                    .toList();
                                for (var exp in expToDelete) {
                                  await expenseProvider.deleteExpense(exp.id);
                                }

                                final salesToDelete = sales
                                    .where((s) => DateFormat('yyyy-MM').format(s.saleDate) == monthStr)
                                    .toList();
                                for (var sale in salesToDelete) {
                                  await DatabaseHelper.instance.deleteBusinessSale(sale.id);
                                }
                                if (context.mounted) {
                                  CustomToast.show(
                                    context,
                                    'Deleted ${salesToDelete.length} sales and ${expToDelete.length} expenses for $monthLabel.',
                                  );
                                }
                              }
                            },
                      child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF1E232E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12141A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Backup & Cloud Sync',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: primaryColor),
            tooltip: 'Sync Help & Support',
            onPressed: () => ReportIssueModal.show(context, category: 'Cloud Sync & Database'),
          ),
        ],
      ),
      body: Consumer2<UserProvider, ExpenseProvider>(
        builder: (context, userProvider, expenseProvider, _) {
          final isSyncing = expenseProvider.isSyncing;
          final lastSync = expenseProvider.lastSyncTime;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── 1. HERO SYNC STATUS CARD ───
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                          : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isSyncing
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF00D09C),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.cloud_done_rounded,
                                      color: Color(0xFF00D09C),
                                      size: 30,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Supabase Cloud',
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF065F46),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isSyncing ? 'SYNCING' : 'ACTIVE',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isSyncing
                                      ? 'Synchronizing records with cloud database...'
                                      : (lastSync != null
                                          ? 'Last Synced: ${_formatSyncTime(lastSync)}'
                                          : 'Auto-sync active on transaction save'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSyncing
                              ? null
                              : () async {
                                  HapticFeedback.mediumImpact();
                                  final success = await expenseProvider.triggerManualSync();
                                  if (context.mounted) {
                                    if (success) {
                                      CustomToast.show(context, 'Data synced to cloud successfully! ✨');
                                    } else {
                                      CustomToast.show(
                                        context,
                                        expenseProvider.syncErrorMessage ?? 'Sync failed.',
                                        isError: true,
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D09C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync_rounded, size: 20),
                          label: Text(
                            isSyncing ? 'Syncing...' : 'Sync Cloud Now',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── 2. RESTORE & RECOVERY ───
                _buildSectionHeader('RESTORE & DATA RECOVERY', isDark),
                _buildCardContainer(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_download_rounded, color: Colors.blueAccent, size: 22),
                      ),
                      title: Text(
                        'Restore Complete Cloud Backup',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Pull all expenses, budgets, khata entries, split bills & accounts from cloud',
                        style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      onTap: () => _showRestoreBackupDialog(context, expenseProvider),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 3. BACKUP SCOPE & TRANSPARENCY ───
                _buildSectionHeader('BACKUP SCOPE & PRIVACY', isDark),
                _buildCardContainer(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      title: Text(
                        'What Gets Backed Up?',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Transparent breakdown of cloud-synced items vs local-only device data',
                        style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BackupScopeScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 4. DATA CLEANUP TOOLS ───
                _buildSectionHeader('DATA CLEANUP TOOLS', isDark),
                _buildCardContainer(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                      ),
                      title: Text(
                        userProvider.isBusinessMode
                            ? 'Delete Month Business Data'
                            : 'Delete Month Personal Data',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent),
                      ),
                      subtitle: Text(
                        userProvider.isBusinessMode
                            ? 'Permanently delete sales & expenses of a chosen month'
                            : 'Permanently delete personal expenses of a chosen month',
                        style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.redAccent),
                      onTap: () => _showDeleteMonthRecordsDialog(context, userProvider.isBusinessMode, expenseProvider),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 5. SECURITY BADGE FOOTER ───
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20, color: primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your data is stored locally with AES-256 encryption and synchronized securely with PostgreSQL Cloud Storage.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            height: 1.3,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
