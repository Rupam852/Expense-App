import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
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
                      onTap: () => _showLanguageBottomSheet(context, service),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. GRANULAR FEATURE NOTIFICATIONS
                _buildSectionHeader('FEATURE ALERTS & REMINDERS', isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    // A. Budget & Spending Limits
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFFEF4444), size: 22),
                      ),
                      title: Text(
                        'Budget & Spending Limits',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Alerts when spending hits 90% or 100% of limits',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: isMasterOn && service.budgetAlertsEnabled,
                      onChanged: isMasterOn ? (val) => service.setBudgetAlertsEnabled(val) : null,
                    ),
                    Divider(height: 1, color: borderColor),

                    // B. Subscriptions & Bills
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.repeat_rounded, color: Color(0xFFF59E0B), size: 22),
                      ),
                      title: Text(
                        'Subscriptions & Bills',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Alerts for due dates, overdue bills & renewals',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: isMasterOn && service.subscriptionAlertsEnabled,
                      onChanged: isMasterOn ? (val) => service.setSubscriptionAlertsEnabled(val) : null,
                    ),
                    Divider(height: 1, color: borderColor),

                    // C. Khata & Udhar Reminders
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.handshake_outlined, color: Color(0xFF10B981), size: 22),
                      ),
                      title: Text(
                        'Khata & Udhar Reminders',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Reminders for pending lend & borrow settlements',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: isMasterOn && service.khataAlertsEnabled,
                      onChanged: isMasterOn ? (val) => service.setKhataAlertsEnabled(val) : null,
                    ),
                    Divider(height: 1, color: borderColor),

                    // D. Daily Evening Expense Log Reminder
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.nightlight_round, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      title: Text(
                        'Daily Expense Logging Reminder',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Evening nudge (9:00 PM) to record today\'s expenses',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: isMasterOn && service.dailyReminderEnabled,
                      onChanged: isMasterOn ? (val) => service.setDailyReminderEnabled(val) : null,
                    ),
                    Divider(height: 1, color: borderColor),

                    // E. Split Bill Pending Alerts
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.call_split_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      title: Text(
                        'Split Bill Pending Alerts',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Alerts when group members have pending shares',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: isMasterOn && service.splitBillAlertsEnabled,
                      onChanged: isMasterOn ? (val) => service.setSplitBillAlertsEnabled(val) : null,
                    ),
                    Divider(height: 1, color: borderColor),

                    // F. Monthly Savings & Financial Summary
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D09C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insights_rounded, color: Color(0xFF00D09C), size: 22),
                      ),
                      title: Text(
                        'Monthly Savings & Report',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Month-end savings analysis & category breakdowns',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: isMasterOn && service.monthlyReportEnabled,
                      onChanged: isMasterOn ? (val) => service.setMonthlyReportEnabled(val) : null,
                    ),
                    Divider(height: 1, color: borderColor),

                    // G. App Updates
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.system_update_rounded, color: Color(0xFF06B6D4), size: 22),
                      ),
                      title: Text(
                        'App Version Updates',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Alerts when new features & release APKs arrive',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: isMasterOn && service.appUpdatesEnabled,
                      onChanged: isMasterOn ? (val) => service.setAppUpdatesEnabled(val) : null,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. TEST BUTTON CARD
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
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.send_rounded, color: primaryColor, size: 22),
                      ),
                      title: Text(
                        'Send Test Push Notification',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Sends test alert in ${service.languageDisplayName}',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: Icon(Icons.play_arrow_rounded, color: primaryColor, size: 24),
                      onTap: () async {
                        final ok = await service.sendTestNotification();
                        if (context.mounted) {
                          if (ok) {
                            CustomToast.show(context, '🔔 Test notification sent to status bar!');
                          } else {
                            CustomToast.show(
                              context,
                              '⚠️ Please allow notification permission in Android Settings',
                              isError: true,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
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
