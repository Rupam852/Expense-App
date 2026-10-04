import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../services/expense_provider.dart';
import '../services/ai_config_service.dart';
import '../widgets/custom_toast.dart';
import 'ai_config_screen.dart';
import 'payment_details_screen.dart';
import '../services/app_update_service.dart';
import 'app_update_screen.dart';
import 'about_screen.dart';
import 'cloud_backup_screen.dart';
import 'notification_settings_screen.dart';
import '../widgets/report_issue_modal.dart';
import '../models/business_profile.dart';
import '../models/business_sale.dart';
import '../models/payment_detail.dart';
import '../services/database_helper.dart';
import '../services/supabase_service.dart';
import 'business_catalog_screen.dart';

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
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Profile Details',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your name',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: photoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Profile Image URL',
                  hintText: 'Paste image link (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Changes'),
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
                      'Delete Account?',
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
                    'Warning: This action is permanent and irreversible.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your account and all associated data (transactions, statement history, budgets, UPI settings) will be permanently deleted from the cloud database and local storage.',
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
                    'Cancel',
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
                    'Permanently Delete',
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
                'Choose App Theme',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select your preferred visual style or sync with device',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeOptionTile(
                context: ctx,
                title: 'Device Default (System)',
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
                title: 'Dark Mode',
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
                title: 'Light Mode',
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
          'Settings',
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
                        icon: Icon(Icons.edit_outlined, color: primaryColor, size: 22),
                        onPressed: () => _showEditProfileDialog(context, userProvider),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. WORKING MODE SECTION (Personal vs Business)
                _buildSectionHeader('APP WORKING MODE', isDark),
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
                                'ACTIVE PROFILE',
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
                                      userProvider.isBusinessMode ? 'BUSINESS MODE' : 'PERSONAL MODE',
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
                                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
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
                                            'Personal',
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
                                            'Business',
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
                                        ? 'Sales billing, GST invoices, customer Udhar Khata & Business Net Profit enabled.'
                                        : 'Personal budgeting, daily expenses, subscriptions & trip tags enabled.',
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
                  _buildSectionHeader('BUSINESS SETTINGS', isDark),
                  const SizedBox(height: 8),
                  _buildSettingsCard(
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: const Color(0xFF1E88E5).withOpacity(0.35),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BusinessProfileSettingsCard(isDark: isDark),
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            // Business Sales Items & Catalog Tile
                            Consumer<ExpenseProvider>(
                              builder: (context, expProv, _) {
                                final itemCount = expProv.businessItems.length;
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const BusinessCatalogScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF131720) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF1E88E5).withOpacity(0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E88E5).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.inventory_2_outlined,
                                            color: Color(0xFF1E88E5),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Sales Items & Catalog',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1E88E5).withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '$itemCount items',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF1E88E5),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Add / Edit products, buy price & GST for fast billing',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFF1E88E5),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // 3. AI CONFIGURATION SECTION (Featured)
                _buildSectionHeader('AI & SMART RECOGNITION', isDark),
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
                        : 'API keys not configured (Tap to setup)';

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
                                'AI Configuration',
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
                                  hasKey ? 'CONFIGURED' : 'SETUP REQUIRED',
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
                _buildSectionHeader('BACKUP & CLOUD SYNC', isDark),
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
                            'Backup & Cloud Sync',
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
                              expenseProvider.isSyncing ? 'SYNCING' : 'ACTIVE',
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
                                : 'Auto-backup enabled • Tap to manage & restore'),
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
                _buildSectionHeader('APPEARANCE & THEME', isDark),
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
                        'App Theme',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        themeLabel,
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
                      onTap: () => _showThemeSelectionBottomSheet(context, userProvider),
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
                        'Max Refresh Rate (120Hz / 90Hz)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Unlock ultra-smooth frame rate (Default ON)',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: userProvider.highRefreshRateEnabled,
                      onChanged: (val) => userProvider.toggleHighRefreshRate(val),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. SECURITY & PREFERENCES SECTION
                _buildSectionHeader('SECURITY & PREFERENCES', isDark),
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
                        'Biometric / Device Lock',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Lock app access with fingerprint / screen lock',
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
                        'Spending Forecast & Runway',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Show burn rate & budget forecast inside Budgets screen (Default OFF)',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      value: userProvider.showSpendingPredictionInBudget,
                      onChanged: (val) => userProvider.toggleSpendingPredictionInBudget(val),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 5. FINANCIAL RECORDS & EXPORTS
                _buildSectionHeader('FINANCIAL RECORDS', isDark),
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
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      title: Text(
                        'Saved Payment Accounts',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Manage linked bank and UPI accounts',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 6. APP UPDATES & SYSTEM
                _buildSectionHeader('UPDATES & SYSTEM', isDark),
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
                                'App Updates',
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
                            'About App & Developer',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Developer social handles, project repo & support',
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
                            'Help & Problem Report',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Encountered an error or bug? Contact developer directly',
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
                            'Notification Settings',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Master on/off, alert language & feature reminders',
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
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out from this device?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
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
                  label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  label: const Text('Delete Account Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
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

class BusinessProfileSettingsCard extends StatefulWidget {
  final bool isDark;
  const BusinessProfileSettingsCard({super.key, required this.isDark});

  @override
  State<BusinessProfileSettingsCard> createState() => _BusinessProfileSettingsCardState();
}

class _BusinessProfileSettingsCardState extends State<BusinessProfileSettingsCard> {
  BusinessProfile _profile = BusinessProfile(
    id: 'default_business',
    businessName: 'My Business',
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prof = await DatabaseHelper.instance.getBusinessProfile();
      if (mounted) {
        setState(() {
          if (prof != null) _profile = prof;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditDialog() async {
    final nameCtrl = TextEditingController(text: _profile.businessName);
    final phoneCtrl = TextEditingController(text: _profile.phone ?? '');
    final gstinCtrl = TextEditingController(text: _profile.gstin ?? '');
    final addrCtrl = TextEditingController(text: _profile.address ?? '');
    final upiCtrl = TextEditingController(text: _profile.upiId ?? '');

    List<PaymentDetail> savedPayments = Provider.of<ExpenseProvider>(context, listen: false).paymentDetails;
    if (savedPayments.isEmpty) {
      savedPayments = await DatabaseHelper.instance.getPaymentDetails();
    }
    final validPayments = savedPayments.where((p) => p.upiId.trim().isNotEmpty).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E232D) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Edit Business Profile',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'My Business / Shop Name *',
                      hintText: 'e.g. Ramesh General Store',
                      prefixIcon: Icon(Icons.business_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Business Phone Number',
                      hintText: 'e.g. +91 9876543210',
                      prefixIcon: Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gstinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN (Optional)',
                      hintText: 'e.g. 27AAAAA0000A1Z5',
                      prefixIcon: Icon(Icons.receipt_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Office Address',
                      hintText: 'e.g. Shop 12, Main Market, Mumbai',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: upiCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Business UPI ID (for QR Code)',
                      hintText: 'e.g. storename@okaxis',
                      prefixIcon: const Icon(Icons.qr_code_rounded),
                      suffixIcon: upiCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                upiCtrl.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  if (validPayments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Text(
                          'Select from saved app UPI IDs:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: validPayments.map((p) {
                        final isSelected = upiCtrl.text.trim().toLowerCase() == p.upiId.trim().toLowerCase();
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              upiCtrl.text = p.upiId.trim();
                              setDialogState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF3B82F6)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.account_balance_wallet_outlined,
                                    size: 13,
                                    color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.name.isNotEmpty ? p.name : 'UPI',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${p.upiId})',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: isSelected
                                          ? const Color(0xFF3B82F6).withValues(alpha: 0.85)
                                          : (isDark ? Colors.white38 : Colors.black45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newName = nameCtrl.text.trim().isEmpty ? 'My Business' : nameCtrl.text.trim();
                  final updated = BusinessProfile(
                    id: _profile.id,
                    businessName: newName,
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                    gstin: gstinCtrl.text.trim().isNotEmpty ? gstinCtrl.text.trim() : null,
                    address: addrCtrl.text.trim().isNotEmpty ? addrCtrl.text.trim() : null,
                    upiId: upiCtrl.text.trim().isNotEmpty ? upiCtrl.text.trim() : null,
                    updatedAt: DateTime.now(),
                  );

                  await DatabaseHelper.instance.saveBusinessProfile(updated);

                  try {
                    await SupabaseService.instance.upsertBusinessProfile(updated.toMap());
                  } catch (e) {
                    debugPrint('[BusinessProfile] Cloud sync failed: $e');
                  }

                  if (mounted) {
                    setState(() => _profile = updated);
                    Navigator.of(ctx).pop();
                    CustomToast.show(context, '✅ Business Profile saved: $newName');
                  }
                },
                child: Text('Save Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131720) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 6),
                  Text(
                    'BUSINESS / SHOP PROFILE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showEditDialog,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 13, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _profile.businessName.isNotEmpty ? _profile.businessName : 'My Business',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (_profile.phone != null && _profile.phone!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.phone_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 5),
                Text(
                  _profile.phone!,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ],
            ),
          ],
          if (_profile.gstin != null && _profile.gstin!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.receipt_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 5),
                Text(
                  'GSTIN: ${_profile.gstin!}',
                  style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ],
          if (_profile.address != null && _profile.address!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _profile.address!,
                    style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

