import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String devWebsite = 'https://rupam852.github.io';
  static const String devInstagram = 'https://instagram.com/_rupambairagya_';
  static const String devLinkedIn = 'https://linkedin.com/in/rupam-bairagya';
  static const String appGitHub = 'https://github.com/Rupam852/Expense-App';
  static const String supportEmail = 'rupambairagya852@gmail.com';
  static const String upiId = 'expensetracker@ybl';

  Future<void> _launchUrlHelper(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        Clipboard.setData(ClipboardData(text: urlString));
        CustomToast.show(context, 'Copied link to clipboard: $urlString');
      }
    }
  }

  Future<void> _launchUpiPayment(BuildContext context) async {
    final upiUrl = 'upi://pay?pa=$upiId&pn=Expense%20Tracker%20Support&cu=INR&tn=Support%20Developer';
    try {
      final uri = Uri.parse(upiUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Clipboard.setData(const ClipboardData(text: upiId));
        if (context.mounted) {
          CustomToast.show(context, 'UPI ID copied: $upiId');
        }
      }
    } catch (_) {
      Clipboard.setData(const ClipboardData(text: upiId));
      if (context.mounted) {
        CustomToast.show(context, 'UPI ID copied: $upiId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF1E232E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3242) : const Color(0xFFE5E9F0);
    final currentVersion = AppUpdateService.currentAppVersion;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12141A) : const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ══════════════════════════════════════════════════════
            // 1. HERO CARD (App Logo + Name + Version Badges)
            // ══════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const AppLogo(size: 72),
                  const SizedBox(height: 16),
                  Text(
                    'GROWW EXPENSE TRACKER',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Smart • Secure • Offline-First',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262D3D) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentVersion,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262D3D) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'RELEASE BUILD',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════════
            // 2. DEVELOPER SECTION
            // ══════════════════════════════════════════════════════
            _buildSectionHeader('Developer', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                _buildActionTile(
                  isDark: isDark,
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Website',
                  subtitle: 'rupam852.github.io',
                  onTap: () => _launchUrlHelper(context, devWebsite),
                ),
                Divider(height: 1, color: borderColor),
                _buildActionTile(
                  isDark: isDark,
                  icon: Icons.camera_alt_outlined,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Instagram',
                  subtitle: '@_rupambairagya_',
                  onTap: () => _launchUrlHelper(context, devInstagram),
                ),
                Divider(height: 1, color: borderColor),
                _buildActionTile(
                  isDark: isDark,
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'LinkedIn',
                  subtitle: 'rupam-bairagya',
                  onTap: () => _launchUrlHelper(context, devLinkedIn),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════════
            // 3. APP / OPEN SOURCE SECTION
            // ══════════════════════════════════════════════════════
            _buildSectionHeader('App', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                _buildActionTile(
                  isDark: isDark,
                  icon: Icons.code_rounded,
                  iconColor: isDark ? Colors.white : Colors.black87,
                  title: 'GitHub',
                  subtitle: 'Rupam852/Expense-App',
                  onTap: () => _launchUrlHelper(context, appGitHub),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════════
            // 4. CONTACT & SUPPORT SECTION
            // ══════════════════════════════════════════════════════
            _buildSectionHeader('Contact & Support', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                _buildActionTile(
                  isDark: isDark,
                  icon: Icons.mail_outline_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Email Support',
                  subtitle: supportEmail,
                  onTap: () => _launchUrlHelper(context, 'mailto:$supportEmail?subject=Expense%20App%20Feedback'),
                ),
                Divider(height: 1, color: borderColor),
                _buildActionTile(
                  isDark: isDark,
                  icon: Icons.volunteer_activism_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Support & Donate (UPI)',
                  subtitle: '$upiId • Tap to Pay',
                  onTap: () => _launchUpiPayment(context),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ══════════════════════════════════════════════════════
            // 5. FOOTER: Proudly Made in India 🇮🇳
            // ══════════════════════════════════════════════════════
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Proudly Made in India ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  const Text(
                    '🇮🇳',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildActionTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262D3D) : const Color(0xFFF1F5F9),
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
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
