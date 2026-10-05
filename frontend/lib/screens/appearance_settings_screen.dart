import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../utils/app_strings.dart';
import '../widgets/custom_toast.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF00D09C);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final currentThemeMode = userProvider.themeMode;
    final currentLang = userProvider.appLanguage;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.tr(context, 'appearance_theme'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP HERO BANNER ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFF1F5F9), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.palette_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tr(context, 'appearance_theme'),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize theme style, regional language & display refresh smoothness.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // ── SECTION 1: APP THEME ────────────────────────────────────
            _buildSectionHeader(
              title: AppStrings.tr(context, 'app_theme'),
              subtitle: 'Select your preferred visual style',
              icon: Icons.brightness_medium_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            _buildThemeCard(
              context: context,
              title: AppStrings.tr(context, 'theme_system'),
              subtitle: 'Automatically adapts to your device system settings',
              icon: Icons.smartphone_rounded,
              iconColor: const Color(0xFF3B82F6),
              isSelected: currentThemeMode == ThemeMode.system,
              onTap: () {
                HapticFeedback.selectionClick();
                userProvider.setThemeMode(ThemeMode.system);
                CustomToast.show(context, 'Theme set to System Default 🌓');
              },
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 10),

            _buildThemeCard(
              context: context,
              title: AppStrings.tr(context, 'theme_dark'),
              subtitle: 'Deep OLED slate black background for low eye strain & battery saving',
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isSelected: currentThemeMode == ThemeMode.dark,
              onTap: () {
                HapticFeedback.selectionClick();
                userProvider.setThemeMode(ThemeMode.dark);
                CustomToast.show(context, 'Theme set to Dark Mode 🌙');
              },
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 10),

            _buildThemeCard(
              context: context,
              title: AppStrings.tr(context, 'theme_light'),
              subtitle: 'Clean soft-white background with high contrast readable elements',
              icon: Icons.light_mode_rounded,
              iconColor: const Color(0xFFF59E0B),
              isSelected: currentThemeMode == ThemeMode.light,
              onTap: () {
                HapticFeedback.selectionClick();
                userProvider.setThemeMode(ThemeMode.light);
                CustomToast.show(context, 'Theme set to Light Mode ☀️');
              },
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),

            const SizedBox(height: 28),

            // ── SECTION 2: APP LANGUAGE ─────────────────────────────────
            _buildSectionHeader(
              title: AppStrings.tr(context, 'app_language'),
              subtitle: 'Choose your regional interface language',
              icon: Icons.language_rounded,
              iconColor: const Color(0xFF6366F1),
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            _buildLanguageCard(
              context: context,
              title: 'English (Default)',
              nativeTitle: 'English Interface & AI',
              flagEmoji: '🇬🇧',
              code: 'en',
              isSelected: currentLang == 'en',
              onTap: () {
                HapticFeedback.selectionClick();
                userProvider.setAppLanguage('en');
                CustomToast.show(context, 'App language set to English 🇬🇧');
              },
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 10),

            _buildLanguageCard(
              context: context,
              title: 'हिन्दी (Hindi)',
              nativeTitle: 'सम्पूर्ण ऐप हिंदी भाषा में',
              flagEmoji: '🇮🇳',
              code: 'hi',
              isSelected: currentLang == 'hi',
              onTap: () {
                HapticFeedback.selectionClick();
                userProvider.setAppLanguage('hi');
                CustomToast.show(context, 'ऐप की भाषा हिन्दी सेट हो गई 🇮🇳');
              },
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 10),

            _buildLanguageCard(
              context: context,
              title: 'বাংলা (Bengali)',
              nativeTitle: 'সম্পূর্ণ অ্যাপ বাংলা ভাষায়',
              flagEmoji: '🇮🇳',
              code: 'bn',
              isSelected: currentLang == 'bn',
              onTap: () {
                HapticFeedback.selectionClick();
                userProvider.setAppLanguage('bn');
                CustomToast.show(context, 'অ্যাপের ভাষা বাংলা সেট করা হয়েছে 🇮🇳');
              },
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),

            const SizedBox(height: 28),

            // ── SECTION 3: DISPLAY & SMOOTHNESS ─────────────────────────
            _buildSectionHeader(
              title: 'Display Smoothness',
              subtitle: 'Hardware refresh rate & animation responsiveness',
              icon: Icons.speed_rounded,
              iconColor: const Color(0xFF10B981),
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: userProvider.highRefreshRateEnabled
                      ? primaryColor.withValues(alpha: 0.5)
                      : borderColor,
                  width: userProvider.highRefreshRateEnabled ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.speed_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    AppStrings.tr(context, 'max_refresh_rate'),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (userProvider.highRefreshRateEnabled ? const Color(0xFF10B981) : Colors.grey)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                userProvider.highRefreshRateEnabled ? '120Hz ULTRA SMOOTH' : '60Hz STANDARD',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: userProvider.highRefreshRateEnabled
                                      ? const Color(0xFF10B981)
                                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: userProvider.highRefreshRateEnabled,
                        activeColor: primaryColor,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          userProvider.toggleHighRefreshRate(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.tr(context, 'max_refresh_rate_sub'),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
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
      ],
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.12 : 0.08)
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isSelected ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? primaryColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryColor : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String title,
    required String nativeTitle,
    required String flagEmoji,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.12 : 0.08)
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Text(flagEmoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? primaryColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nativeTitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryColor : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
