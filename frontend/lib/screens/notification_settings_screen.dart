import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
import '../models/subscription_item.dart';
import '../services/app_update_service.dart';
import '../widgets/custom_toast.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  void _showLanguageBottomSheet(BuildContext context, NotificationService notifService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final currentLang = notifService.notificationLanguage;

    final languages = [
      {'code': 'en', 'title': 'English', 'native': 'Default English', 'icon': '🇬🇧'},
      {'code': 'hi', 'title': 'Hindi', 'native': 'हिंदी (Hindi)', 'icon': '🇮🇳'},
      {'code': 'bn', 'title': 'Bengali', 'native': 'বাংলা (Bengali)', 'icon': '🇮🇳'},
      {'code': 'hinglish', 'title': 'Hinglish', 'native': 'Hindi in English Script', 'icon': '🇮🇳'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E232E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Notification Language',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the language for all push notification alerts',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ...languages.map((l) {
                final isSelected = currentLang == l['code'];
                return InkWell(
                  onTap: () async {
                    await notifService.setNotificationLanguage(l['code']!);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) {
                      CustomToast.show(context, '✅ Notification language set to ${l['title']}');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withValues(alpha: isDark ? 0.15 : 0.08)
                          : (isDark ? const Color(0xFF252A36) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(l['icon']!, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l['title']!,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                l['native']!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
                        else
                          Icon(Icons.radio_button_unchecked,
                              color: isDark ? Colors.grey[600] : Colors.grey[400], size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showNewMonthTestOptionsSheet(BuildContext context, NotificationService notifService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E232E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Test New Month Notification',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Test both notification scenarios in your selected language:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              // Scenario A: Had previous month expenses
              InkWell(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await notifService.showNewMonthStartNotification(hasExpenses: true);
                  if (context.mounted) {
                    CustomToast.show(context, '🚀 Scenario A Test: "PDF Download" Notification sent!');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252A36) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('📄', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scenario A: Had Previous Month Expenses',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Content: "Download PDF invoice & start new month"',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.send_rounded, color: Color(0xFF00D09C), size: 18),
                    ],
                  ),
                ),
              ),
              // Scenario B: 0 Expenses
              InkWell(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await notifService.showNewMonthStartNotification(hasExpenses: false);
                  if (context.mounted) {
                    CustomToast.show(context, '🚀 Scenario B Test: "Fresh Start" Notification sent!');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252A36) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scenario B: Zero Expenses (0 Records)',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Content: "Welcome to new month, start fresh tracking"',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.send_rounded, color: Color(0xFF38BDF8), size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
          'Notification Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 19,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: NotificationService.instance,
        builder: (context, _) {
          final service = NotificationService.instance;
          final isMasterOn = service.masterEnabled;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. MASTER TOGGLE CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMasterOn
                          ? primaryColor.withValues(alpha: isDark ? 0.3 : 0.4)
                          : borderColor,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isMasterOn ? primaryColor : Colors.black)
                            .withValues(alpha: isDark ? 0.1 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMasterOn
                              ? primaryColor.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isMasterOn
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          color: isMasterOn ? primaryColor : Colors.grey,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allow Push Notifications',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              isMasterOn
                                  ? 'System tray notifications are ACTIVE'
                                  : 'All notifications are PAUSED',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isMasterOn ? primaryColor : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        activeColor: primaryColor,
                        value: isMasterOn,
                        onChanged: (val) => service.setMasterEnabled(val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2 & 3. CHILD SETTINGS (Language & Granular Alerts) - Grayed out and deactivated if Master is OFF
                AnimatedOpacity(
                  opacity: isMasterOn ? 1.0 : 0.38,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !isMasterOn,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 2. NOTIFICATION LANGUAGE SELECTOR
                        _buildSectionHeader('NOTIFICATION LANGUAGE', isDark),
                        const SizedBox(height: 8),
                        _buildSettingsCard(
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.translate_rounded, color: Color(0xFF3B82F6), size: 22),
                              ),
                              title: Text(
                                'Alerts Language',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                service.languageDisplayName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'Change',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                                ],
                              ),
                              onTap: isMasterOn ? () => _showLanguageBottomSheet(context, service) : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 3. GRANULAR FEATURE NOTIFICATIONS WITH INDIVIDUAL TEST BUTTONS
                        _buildSectionHeader('FEATURE ALERTS & SEPARATE TEST', isDark),
                        const SizedBox(height: 8),
                        _buildSettingsCard(
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          children: [
                            // A. Budget & Spending Limits
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.pie_chart_outline_rounded,
                              iconColor: const Color(0xFFEF4444),
                              title: 'Budget & Spending Limits',
                              subtitle: 'Alerts when spending hits 90% or 100% of limits',
                              isEnabled: isMasterOn && service.budgetAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setBudgetAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showBudgetLimitNotification(
                                  category: 'Shopping',
                                  spent: 5500,
                                  limit: 5000,
                                  percentage: 110,
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '🚨 Test Budget Exceeded Alert sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // B. Subscriptions & Bills
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.repeat_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Subscriptions & Bills',
                              subtitle: 'Alerts for due dates, overdue bills & renewals',
                              isEnabled: isMasterOn && service.subscriptionAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setSubscriptionAlertsEnabled(val),
                              onTestTap: () async {
                                final sampleSub = SubscriptionItem(
                                  id: 'sample-netflix',
                                  name: 'Netflix Premium',
                                  amount: 649,
                                  billingCycle: 'monthly',
                                  nextRenewalDate: DateTime.now(),
                                  category: 'Subscription',
                                );
                                await service.showSubscriptionDueNotification(sampleSub);
                                if (context.mounted) {
                                  CustomToast.show(context, '🔔 Test Subscription Due Alert sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // C. Khata & Udhar Reminders
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.handshake_outlined,
                              iconColor: const Color(0xFF10B981),
                              title: 'Khata & Udhar Reminders',
                              subtitle: 'Reminders for pending lend & borrow settlements',
                              isEnabled: isMasterOn && service.khataAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setKhataAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showKhataReminderNotification(
                                  personName: 'Rahul Sharma',
                                  amount: 1500,
                                  isLent: true,
                                  dueDate: DateTime.now(),
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '💸 Test Khata Reminder sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // D. Daily Evening Expense Log Reminder
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.nightlight_round,
                              iconColor: const Color(0xFF8B5CF6),
                              title: 'Daily Expense Logging Reminder',
                              subtitle: 'Evening nudge (9:00 PM) to record today\'s expenses',
                              isEnabled: isMasterOn && service.dailyReminderEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setDailyReminderEnabled(val),
                              onTestTap: () async {
                                await service.showDailyEveningReminder();
                                if (context.mounted) {
                                  CustomToast.show(context, '🌙 Test Daily Evening Reminder sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // E. Split Bill Pending Alerts
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.call_split_rounded,
                              iconColor: const Color(0xFF6366F1),
                              title: 'Split Bill Pending Alerts',
                              subtitle: 'Alerts when group members have pending shares',
                              isEnabled: isMasterOn && service.splitBillAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setSplitBillAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showSplitBillPendingNotification(
                                  titleText: 'Goa Trip Dinner',
                                  pendingAmount: 1850,
                                  pendingPeopleCount: 3,
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '👥 Test Split Bill Alert sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // F. Monthly Savings & Financial Summary
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.insights_rounded,
                              iconColor: const Color(0xFF00D09C),
                              title: 'Monthly Savings & Report',
                              subtitle: 'Month-end savings analysis & category breakdowns',
                              isEnabled: isMasterOn && service.monthlyReportEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setMonthlyReportEnabled(val),
                              onTestTap: () async {
                                await service.showMonthlySavingsReportNotification(
                                  totalSpent: 16500,
                                  totalSaved: 4200,
                                  monthName: 'September',
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '🎉 Test Monthly Report sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // G. Month-End Invoice Rollover Reminder
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.calendar_month_rounded,
                              iconColor: const Color(0xFFF97316),
                              title: 'Month-End Invoice Reminder',
                              subtitle: 'Evening alert (8-9 PM) on the last day before month ends',
                              isEnabled: isMasterOn && service.monthEndAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setMonthEndAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showMonthEndReminderNotification();
                                if (context.mounted) {
                                  CustomToast.show(context, '🗓️ Test Month-End Invoice Alert sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // H. New Month Start Action Alert
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.rocket_launch_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: 'New Month Start Alert',
                              subtitle: 'Morning alert (8-9 AM) on the 1st of every month',
                              isEnabled: isMasterOn && service.newMonthStartAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setNewMonthStartAlertsEnabled(val),
                              onTestTap: () => _showNewMonthTestOptionsSheet(context, service),
                            ),
                            Divider(height: 1, color: borderColor),

                            // I. App Updates
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.system_update_rounded,
                              iconColor: const Color(0xFF06B6D4),
                              title: 'App Version Updates',
                              subtitle: 'Alerts when new features & release APKs arrive',
                              isEnabled: isMasterOn && service.appUpdatesEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setAppUpdatesEnabled(val),
                              onTestTap: () async {
                                final sampleUpdate = AppUpdateInfo(
                                  hasUpdate: true,
                                  currentVersion: 'v1.0.0',
                                  latestVersion: 'v2.1.0',
                                  fileName: 'GrowExpense-v2.1.0.apk',
                                  downloadUrl: AppUpdateService.defaultDownloadWebUrl,
                                  webUrl: AppUpdateService.defaultDownloadWebUrl,
                                  description: '• Multi-language push notifications\n• Granular alert toggles\n• 120Hz display support',
                                  fileSizeBytes: 26948403,
                                );
                                await service.showUpdateNotification(sampleUpdate);
                                if (context.mounted) {
                                  CustomToast.show(context, '🚀 Test Update Alert sent to status bar!');
                                }
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 4. BUSINESS & SHOP MODE ALERTS (Active even in Personal Mode)
                        _buildSectionHeader('BUSINESS & SHOP ALERTS', isDark),
                        const SizedBox(height: 8),
                        _buildSettingsCard(
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          children: [
                            // 1. Invoice Due & Overdue
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.receipt_long_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              title: 'Invoice Due & Overdue Alerts',
                              subtitle: 'Alerts when customer invoices are due or overdue with 1-tap WhatsApp link',
                              isEnabled: isMasterOn && service.invoiceAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setInvoiceAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showInvoiceDueNotification(
                                  customerName: 'Ramesh Trading Co.',
                                  invoiceNumber: 'INV-1048',
                                  amount: 8500,
                                  isOverdue: true,
                                  daysOverdue: 3,
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '🧾 Test Overdue Invoice Alert sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // 2. Daily Shop Closing
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.storefront_rounded,
                              iconColor: const Color(0xFF00D09C),
                              title: 'Daily Shop Closing (EOD Summary)',
                              subtitle: 'Raat ko 8:30 PM par din bhar ki sales, cash aur udhar ka tally hisab',
                              isEnabled: isMasterOn && service.dailyBusinessSummaryEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setDailyBusinessSummaryEnabled(val),
                              onTestTap: () async {
                                await service.showDailyBusinessSummaryNotification(
                                  totalSales: 24500,
                                  netCash: 18200,
                                  pendingCredit: 6300,
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '🏪 Test Daily Shop Closing Summary sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // 3. Vendor Payable Dues
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.local_shipping_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Supplier & Vendor Payable Alerts',
                              subtitle: 'Wholesalers aur suppliers ko diye jaane wale payments ki upcoming reminder',
                              isEnabled: isMasterOn && service.vendorPayableAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setVendorPayableAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showVendorPayableNotification(
                                  vendorName: 'Metro Wholesalers',
                                  amount: 15000,
                                  dueDate: DateTime.now().add(const Duration(days: 1)),
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '🔔 Test Vendor Payable Alert sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // 4. Weekly Business P&L Report
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.trending_up_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              title: 'Weekly Profit & Loss (P&L) Report',
                              subtitle: 'Sunday evening ko business ka net profit, margin aur sales growth report',
                              isEnabled: isMasterOn && service.weeklyBusinessReportEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setWeeklyBusinessReportEnabled(val),
                              onTestTap: () async {
                                await service.showWeeklyBusinessReportNotification(
                                  netProfit: 34200,
                                  marginPercent: 28.5,
                                  totalRevenue: 120000,
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '📈 Test Weekly P&L Report sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // 5. GST & Tax Filing Reminder
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.account_balance_rounded,
                              iconColor: const Color(0xFF0EA5E9),
                              title: 'GST & Tax Filing Reminders',
                              subtitle: 'Monthly GSTR-1, 3B returns aur invoice sales export reminders',
                              isEnabled: isMasterOn && service.gstAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setGstAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showGstFilingNotification(
                                  monthName: 'October',
                                  daysLeft: 3,
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '🏛️ Test GST Filing Reminder sent to status bar!');
                                }
                              },
                            ),
                            Divider(height: 1, color: borderColor),

                            // 6. Low Stock Inventory Alert
                            _buildFeatureTileWithTest(
                              context: context,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              icon: Icons.inventory_2_rounded,
                              iconColor: const Color(0xFFEF4444),
                              title: 'Low Stock & Inventory Alerts',
                              subtitle: 'Dukan ke items khatam hone ya low threshold par aane par turant alert notification',
                              isEnabled: isMasterOn && service.lowStockAlertsEnabled,
                              isMasterOn: isMasterOn,
                              onToggle: (val) => service.setLowStockAlertsEnabled(val),
                              onTestTap: () async {
                                await service.showLowStockNotification(
                                  itemName: 'Fortune Sunflower Oil 1L',
                                  currentStock: 2,
                                  unit: 'ltr',
                                  limit: 5,
                                );
                                if (context.mounted) {
                                  CustomToast.show(context, '📦 Test Low Stock Alert sent to status bar!');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureTileWithTest({
    required BuildContext context,
    required bool isDark,
    required Color primaryColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool isMasterOn,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTestTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // SEPARATE TEST BUTTON FOR THIS FEATURE
          InkWell(
            onTap: onTestTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: primaryColor, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    'Test',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // ON / OFF TOGGLE SWITCH
          Switch(
            activeColor: primaryColor,
            value: isEnabled,
            onChanged: isMasterOn ? onToggle : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
