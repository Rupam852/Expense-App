import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../services/expense_provider.dart';
import '../services/ai_config_service.dart';
import '../widgets/custom_toast.dart';
import 'ai_config_screen.dart';
import '../services/app_update_service.dart';
import 'app_update_screen.dart';
import 'about_screen.dart';
import 'cloud_backup_screen.dart';
import 'notification_settings_screen.dart';
import '../widgets/report_issue_modal.dart';
import 'business_settings_screen.dart';
import '../utils/app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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


  void _showEditProfileDialog(BuildContext context, UserProvider userProvider) {
    final nameController = TextEditingController(text: userProvider.userProfile?['name'] ?? '');
    final photoUrlController = TextEditingController(text: userProvider.userProfile?['photo_url'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppStrings.tr(context, 'edit_profile_title'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppStrings.tr(context, 'display_name'),
                  hintText: AppStrings.tr(context, 'enter_name_hint'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: photoUrlController,
                decoration: InputDecoration(
                  labelText: AppStrings.tr(context, 'profile_image_url'),
                  hintText: AppStrings.tr(context, 'profile_image_hint'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppStrings.tr(context, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final photoUrl = photoUrlController.text.trim();
                if (name.isNotEmpty) {
                  await userProvider.updateProfile(
                    name: name,
                    photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppStrings.tr(context, 'save_changes')),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, UserProvider userProvider, ExpenseProvider expenseProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.tr(context, 'delete_acc_title'),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.tr(context, 'delete_acc_warning'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.tr(context, 'delete_acc_desc'),
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                  ),
                  if (isDeleting) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    AppStrings.tr(context, 'cancel'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });

                          final success = await userProvider.deleteUserAccount();
                          if (success) {
                            await expenseProvider.clearAllDataOnSignout();
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close dialog
                              Navigator.of(context).pop(); // Close settings screen
                              CustomToast.show(
                                context,
                                'Your account and data have been permanently deleted.',
                                isError: false,
                              );
                            }
                          } else {
                            if (context.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                              });
                              CustomToast.show(
                                context,
                                userProvider.errorMessage ?? 'Failed to delete account.',
                                isError: true,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    AppStrings.tr(context, 'permanently_delete'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThemeSelectionBottomSheet(BuildContext context, UserProvider userProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final currentMode = userProvider.themeMode;

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
                AppStrings.tr(context, 'choose_app_theme'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.tr(context, 'choose_theme_sub'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeOptionTile(
                context: ctx,
                title: AppStrings.tr(context, 'theme_system'),
                subtitle: 'Automatically matches your phone’s dark/light mode',
                icon: Icons.smartphone_rounded,
                iconColor: Colors.blueAccent,
                isSelected: currentMode == ThemeMode.system,
                onTap: () {
                  userProvider.setThemeMode(ThemeMode.system);
                  Navigator.of(ctx).pop();
                },
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 8),
              _buildThemeOptionTile(
                context: ctx,
                title: AppStrings.tr(context, 'theme_dark'),
                subtitle: 'Sleek OLED deep slate background for low eye strain',
                icon: Icons.dark_mode_rounded,
                iconColor: const Color(0xFF8B5CF6),
                isSelected: currentMode == ThemeMode.dark,
                onTap: () {
                  userProvider.setThemeMode(ThemeMode.dark);
                  Navigator.of(ctx).pop();
                },
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 8),
              _buildThemeOptionTile(
                context: ctx,
                title: AppStrings.tr(context, 'theme_light'),
                subtitle: 'Clean soft-white background with high contrast elements',
                icon: Icons.light_mode_rounded,
                iconColor: Colors.amber,
                isSelected: currentMode == ThemeMode.light,
                onTap: () {
                  userProvider.setThemeMode(ThemeMode.light);
                  Navigator.of(ctx).pop();
                },
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.12 : 0.08)
              : (isDark ? const Color(0xFF14171E) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? primaryColor : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelectionBottomSheet(BuildContext context, UserProvider userProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final currentLang = userProvider.appLanguage;

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
                AppStrings.tr(context, 'choose_app_language'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.tr(context, 'choose_lang_sub'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              _buildLanguageOptionTile(
                context: ctx,
                title: '🇬🇧 English (Default)',
                subtitle: 'Standard English interface & AI responses',
                code: 'en',
                isSelected: currentLang == 'en',
                onTap: () {
                  userProvider.setAppLanguage('en');
                  Navigator.of(ctx).pop();
                  CustomToast.show(context, 'App language set to English 🇬🇧');
                },
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 8),
              _buildLanguageOptionTile(
                context: ctx,
                title: '🇮🇳 हिंदी (Hindi)',
                subtitle: 'हिंदी इंटरफेस एवं AI चैट प्रतिक्रियाएं',
                code: 'hi',
                isSelected: currentLang == 'hi',
                onTap: () {
                  userProvider.setAppLanguage('hi');
                  Navigator.of(ctx).pop();
                  CustomToast.show(context, 'ऐप की भाषा हिंदी सेट हो गई है 🇮🇳');
                },
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 8),
              _buildLanguageOptionTile(
                context: ctx,
                title: '🇮🇳 বাংলা (Bengali)',
                subtitle: 'বাংলা ইন্টারফেস এবং AI চ্যাট প্রতিক্রিয়া',
                code: 'bn',
                isSelected: currentLang == 'bn',
                onTap: () {
                  userProvider.setAppLanguage('bn');
                  Navigator.of(ctx).pop();
                  CustomToast.show(context, 'অ্যাপের ভাষা বাংলা সেট করা হয়েছে 🇮🇳');
                },
                isDark: isDark,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.12 : 0.08)
              : (isDark ? const Color(0xFF14171E) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isSelected ? primaryColor : Colors.indigoAccent).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.language_rounded,
                color: isSelected ? primaryColor : Colors.indigoAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? primaryColor : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 20),
          ],
        ),
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
          AppStrings.tr(context, 'settings_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: Consumer2<UserProvider, ExpenseProvider>(
        builder: (context, userProvider, expenseProvider, _) {
          final profile = userProvider.userProfile;
          final aiService = AiConfigService.instance;
          final currentThemeMode = userProvider.themeMode;

          String themeLabel = 'Device Default (System)';
          IconData themeIcon = Icons.smartphone_rounded;
          Color themeIconColor = Colors.blueAccent;
          if (currentThemeMode == ThemeMode.dark) {
            themeLabel = 'Dark Mode';
            themeIcon = Icons.dark_mode_rounded;
            themeIconColor = const Color(0xFF8B5CF6);
          } else if (currentThemeMode == ThemeMode.light) {
            themeLabel = 'Light Mode';
            themeIcon = Icons.light_mode_rounded;
            themeIconColor = Colors.amber;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Profile Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: primaryColor.withValues(alpha: 0.2),
                        backgroundImage: profile?['photo_url'] != null
                            ? NetworkImage(profile!['photo_url'])
                            : null,
                        child: profile?['photo_url'] == null
                            ? Text(
                                (profile?['name'] ?? 'U')[0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: primaryColor,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?['name'] ?? 'User Member',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile?['email'] ?? 'N/A',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          size: 20,
                        ),
                        onPressed: () => _showEditProfileDialog(context, userProvider),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 2. WORKING MODE SECTION (Personal vs Business)
                _buildSectionHeader(AppStrings.tr(context, 'app_working_mode'), isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: userProvider.isBusinessMode 
                      ? const Color(0xFF00D09C).withOpacity(0.4) 
                      : const Color(0xFF3B82F6).withOpacity(0.4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppStrings.tr(context, 'active_profile'),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (userProvider.isBusinessMode
                                          ? const Color(0xFF00D09C)
                                          : const Color(0xFF3B82F6))
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (userProvider.isBusinessMode
                                            ? const Color(0xFF00D09C)
                                            : const Color(0xFF3B82F6))
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: userProvider.isBusinessMode
                                            ? const Color(0xFF00D09C)
                                            : const Color(0xFF3B82F6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      userProvider.isBusinessMode 
                                          ? AppStrings.tr(context, 'business_mode_badge') 
                                          : AppStrings.tr(context, 'personal_mode_badge'),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: userProvider.isBusinessMode
                                            ? const Color(0xFF00D09C)
                                            : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Dual Mode Segmented Selector Pills
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131720) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Personal Pill
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (userProvider.isBusinessMode) {
                                        userProvider.toggleAppMode(false);
                                        CustomToast.show(context, 'Switched to Personal Mode 👤');
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        gradient: !userProvider.isBusinessMode
                                            ? const LinearGradient(
                                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                              )
                                            : null,
                                        color: !userProvider.isBusinessMode ? null : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !userProvider.isBusinessMode
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_rounded,
                                            size: 18,
                                            color: !userProvider.isBusinessMode
                                                ? Colors.white
                                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            AppStrings.tr(context, 'personal'),
                                            style: GoogleFonts.inter(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: !userProvider.isBusinessMode
                                                  ? Colors.white
                                                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 4),

                                // Business Pill
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!userProvider.isBusinessMode) {
                                        userProvider.toggleAppMode(true);
                                        CustomToast.show(context, 'Switched to Business Mode 🏢');
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        gradient: userProvider.isBusinessMode
                                            ? const LinearGradient(
                                                colors: [Color(0xFF00D09C), Color(0xFF059669)],
                                              )
                                            : null,
                                        color: userProvider.isBusinessMode ? null : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: userProvider.isBusinessMode
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF00D09C).withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.storefront_rounded,
                                            size: 18,
                                            color: userProvider.isBusinessMode
                                                ? Colors.white
                                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            AppStrings.tr(context, 'business'),
                                            style: GoogleFonts.inter(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: userProvider.isBusinessMode
                                                  ? Colors.white
                                                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Dynamic Descriptive Caption
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: (userProvider.isBusinessMode
                                      ? const Color(0xFF00D09C)
                                      : const Color(0xFF3B82F6))
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  userProvider.isBusinessMode
                                      ? Icons.info_outline_rounded
                                      : Icons.verified_user_outlined,
                                  size: 15,
                                  color: userProvider.isBusinessMode
                                      ? const Color(0xFF00D09C)
                                      : const Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    userProvider.isBusinessMode
                                        ? AppStrings.tr(context, 'mode_biz_caption')
                                        : AppStrings.tr(context, 'mode_personal_caption'),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2.1. DEDICATED BUSINESS SETTINGS SECTION (Visible only in Business Mode)
                if (userProvider.isBusinessMode) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(AppStrings.tr(context, 'business_settings'), isDark),
                  const SizedBox(height: 8),
                  _buildSettingsCard(
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: const Color(0xFF1E88E5).withValues(alpha: 0.35),
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF1E88E5), size: 22),
                        ),
                        title: Text(
                          AppStrings.tr(context, 'biz_settings_title'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        subtitle: Text(
                          AppStrings.tr(context, 'biz_settings_sub'),
                          style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BusinessSettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // 3. AI CONFIGURATION SECTION (Featured)
                _buildSectionHeader(AppStrings.tr(context, 'ai_extensions'), isDark),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: aiService,
                  builder: (context, _) {
                    final hasKey = aiService.hasAnyApiKey;
                    final isPrimaryGemini = aiService.primaryProvider == 'gemini';
                    final primaryModel = isPrimaryGemini ? aiService.geminiModel : aiService.nvidiaModel;
                    final providerLabel = isPrimaryGemini ? 'Gemini' : 'NVIDIA NIM';
                    final subtitle = hasKey
                        ? 'Primary: $providerLabel ($primaryModel)'
                        : AppStrings.tr(context, 'ai_config_sub');

                    return _buildSettingsCard(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: hasKey ? primaryColor.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.3),
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (hasKey ? primaryColor : Colors.amber).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.psychology_outlined,
                              color: hasKey ? primaryColor : Colors.amber,
                              size: 24,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                AppStrings.tr(context, 'ai_config_title'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (hasKey ? primaryColor : Colors.amber).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hasKey 
                                      ? AppStrings.tr(context, 'ai_configured') 
                                      : AppStrings.tr(context, 'ai_setup_required'),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: hasKey ? primaryColor : Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: hasKey ? (isDark ? Colors.grey[400] : Colors.grey[600]) : Colors.amber[700],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 22, color: Colors.grey),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AiConfigScreen()),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // 3. BACKUP & CLOUD SYNC SECTION
                _buildSectionHeader(AppStrings.tr(context, 'data_backup'), isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D09C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          expenseProvider.isSyncing ? Icons.sync_rounded : Icons.cloud_done_rounded,
                          color: const Color(0xFF00D09C),
                          size: 24,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            AppStrings.tr(context, 'backup_sync_title'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              expenseProvider.isSyncing 
                                  ? AppStrings.tr(context, 'syncing') 
                                  : AppStrings.tr(context, 'active'),
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00D09C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        expenseProvider.isSyncing
                            ? 'Syncing data to cloud...'
                            : (expenseProvider.lastSyncTime != null
                                ? 'Last synced: ${_formatSyncTime(expenseProvider.lastSyncTime!)} • Tap to manage'
                                : AppStrings.tr(context, 'backup_sync_sub')),
                        style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 22, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CloudBackupScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. APPEARANCE & THEME SECTION
                _buildSectionHeader(AppStrings.tr(context, 'appearance_theme'), isDark),
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
                          color: themeIconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(themeIcon, color: themeIconColor, size: 22),
                      ),
                      title: Text(
                        AppStrings.tr(context, 'app_theme'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        currentThemeMode == ThemeMode.dark 
                            ? AppStrings.tr(context, 'theme_dark') 
                            : (currentThemeMode == ThemeMode.light 
                                ? AppStrings.tr(context, 'theme_light') 
                                : AppStrings.tr(context, 'theme_system')),
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
                              AppStrings.tr(context, 'change'),
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
                      onTap: () => _showThemeSelectionBottomSheet(context, userProvider),
                    ),
                    Divider(height: 1, color: borderColor),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.language_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      title: Text(
                        AppStrings.tr(context, 'app_language'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        AppStrings.getLanguageLabel(userProvider.appLanguage),
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
                              AppStrings.tr(context, 'change'),
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
                      onTap: () => _showLanguageSelectionBottomSheet(context, userProvider),
                    ),
                    Divider(height: 1, color: borderColor),
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.speed_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      title: Text(
                        AppStrings.tr(context, 'max_refresh_rate'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        AppStrings.tr(context, 'max_refresh_rate_sub'),
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: userProvider.highRefreshRateEnabled,
                      onChanged: (val) => userProvider.toggleHighRefreshRate(val),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. SECURITY & PREFERENCES SECTION
                _buildSectionHeader(AppStrings.tr(context, 'security_preferences'), isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  children: [
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fingerprint, color: Colors.blue, size: 22),
                      ),
                      title: Text(
                        AppStrings.tr(context, 'biometric_lock'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        AppStrings.tr(context, 'biometric_lock_sub'),
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: userProvider.biometricsEnabled,
                      onChanged: (val) async {
                        final success = await userProvider.toggleBiometrics(val);
                        if (!success && context.mounted) {
                          CustomToast.show(
                            context,
                            userProvider.errorMessage ?? 'Failed to enable biometrics.',
                            isError: true,
                          );
                        }
                      },
                    ),
                    Divider(height: 1, color: borderColor),
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D09C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.analytics_outlined, color: Color(0xFF00D09C), size: 22),
                      ),
                      title: Text(
                        AppStrings.tr(context, 'spending_forecast'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        AppStrings.tr(context, 'spending_forecast_sub'),
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: userProvider.showSpendingPredictionInBudget,
                      onChanged: (val) => userProvider.toggleSpendingPredictionInBudget(val),
                    ),
                  ],
                ),


                const SizedBox(height: 24),

                // 6. APP UPDATES & SYSTEM
                _buildSectionHeader(AppStrings.tr(context, 'updates_system'), isDark),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: AppUpdateService.instance,
                  builder: (context, _) {
                    final updateService = AppUpdateService.instance;
                    final hasUpdate = updateService.latestUpdateInfo?.hasUpdate ?? false;
                    return _buildSettingsCard(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: hasUpdate ? const Color(0xFFEF4444).withValues(alpha: 0.4) : borderColor,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Badge(
                            isLabelVisible: hasUpdate,
                            backgroundColor: const Color(0xFFEF4444),
                            smallSize: 8,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasUpdate
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                    : Colors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                hasUpdate ? Icons.system_update_rounded : Icons.sync_rounded,
                                color: hasUpdate ? const Color(0xFFEF4444) : Colors.teal,
                                size: 22,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                AppStrings.tr(context, 'app_updates'),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              if (hasUpdate) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'UPDATE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            hasUpdate
                                ? 'Version ${updateService.latestUpdateInfo?.latestVersion} available'
                                : 'Current version: ${AppUpdateService.currentAppVersion}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: hasUpdate ? const Color(0xFFEF4444) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AppUpdateScreen()),
                            );
                          },
                        ),
                        Divider(height: 1, color: borderColor),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF38BDF8),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            AppStrings.tr(context, 'about_app'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            AppStrings.tr(context, 'about_app_sub'),
                            style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AboutScreen()),
                            );
                          },
                        ),
                        Divider(height: 1, color: borderColor),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.support_agent_rounded,
                              color: Color(0xFFF59E0B),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            AppStrings.tr(context, 'help_report'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            AppStrings.tr(context, 'help_report_sub'),
                            style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          onTap: () {
                            ReportIssueModal.show(context, category: 'General Bug / Feedback');
                          },
                        ),
                        Divider(height: 1, color: borderColor),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D09C).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: Color(0xFF00D09C),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            AppStrings.tr(context, 'notifications_settings'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            AppStrings.tr(context, 'notifications_settings_sub'),
                            style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // 7. ACCOUNT ACTIONS (Sign out & Delete Account)
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(AppStrings.tr(context, 'signout_title')),
                        content: Text(AppStrings.tr(context, 'signout_confirm')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(AppStrings.tr(context, 'cancel')),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            child: Text(AppStrings.tr(context, 'logout'), style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      Navigator.of(context).pop();
                      await expenseProvider.clearAllDataOnSignout();
                      await userProvider.logout();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: Text(AppStrings.tr(context, 'logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () {
                    _showDeleteAccountDialog(context, userProvider, expenseProvider);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined, size: 20),
                  label: Text(AppStrings.tr(context, 'delete_account'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}


