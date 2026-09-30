import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../services/expense_provider.dart';
import '../services/ai_config_service.dart';
import '../widgets/custom_toast.dart';
import 'ai_config_screen.dart';
import 'invoice_history_screen.dart';
import 'payment_details_screen.dart';
import '../services/app_update_service.dart';
import 'app_update_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  color: Colors.redAccent.withOpacity(0.2),
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
                    'Aapka account aur usse juda saara data (transactions, statement history, budgets, UPI settings) cloud database aur local storage se hamesha ke liye delete ho jayega.',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF1E232E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3242) : const Color(0xFFE5E9F0);

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
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: primaryColor.withOpacity(0.2),
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
                                color: Colors.grey,
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

                // 2. AI CONFIGURATION SECTION (Featured)
                _buildSectionHeader('AI & SMART RECOGNITION', isDark),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: aiService,
                  builder: (context, _) {
                    final isCustom = aiService.isCustomMode;
                    final subtitle = isCustom
                        ? 'Custom: ${aiService.primaryProvider == 'gemini' ? 'Gemini ➔ NVIDIA' : 'NVIDIA ➔ Gemini'}'
                        : 'Default: Auto-Managed Cloud Models';

                    return _buildSettingsCard(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: isCustom ? primaryColor.withOpacity(0.4) : borderColor,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.psychology_outlined, color: primaryColor, size: 24),
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
                                  color: isCustom
                                      ? const Color(0xFF6366F1).withOpacity(0.15)
                                      : primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isCustom ? 'CUSTOM' : 'DEFAULT',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCustom ? const Color(0xFF818CF8) : primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            subtitle,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
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

                // 3. SECURITY & PREFERENCES SECTION
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
                          color: Colors.blue.withOpacity(0.12),
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
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
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
                  ],
                ),

                const SizedBox(height: 24),

                // 4. FINANCIAL RECORDS & EXPORTS
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
                          color: const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.history_edu_outlined, color: Color(0xFFF59E0B), size: 22),
                      ),
                      title: Text(
                        'Invoice History',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'View & download saved monthly invoices',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
                        );
                      },
                    ),
                    Divider(height: 1, color: borderColor),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
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
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
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

                // 5. APP UPDATES & SYSTEM
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
                      borderColor: hasUpdate ? primaryColor.withOpacity(0.4) : borderColor,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hasUpdate
                                  ? primaryColor.withOpacity(0.15)
                                  : Colors.teal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              hasUpdate ? Icons.system_update_rounded : Icons.sync_rounded,
                              color: hasUpdate ? primaryColor : Colors.teal,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                'App Updates',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              if (hasUpdate)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'UPDATE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            hasUpdate
                                ? 'Version ${updateService.latestUpdateInfo?.latestVersion} available'
                                : 'Current version: ${AppUpdateService.currentAppVersion}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AppUpdateScreen()),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // 6. ACCOUNT ACTIONS (Sign out & Delete Account)
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
                    backgroundColor: Colors.red.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.03),
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
