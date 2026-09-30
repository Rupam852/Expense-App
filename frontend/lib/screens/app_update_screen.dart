import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/app_update_service.dart';
import '../services/notification_service.dart';
import '../widgets/custom_toast.dart';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  final AppUpdateService _updateService = AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    // Perform automatic check on opening screen if not already checked recently
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateService.checkForUpdates(isManual: true);
    });
  }

  Future<void> _handleDownload() async {
    final success = await _updateService.openDownloadLink();
    if (!success && mounted) {
      CustomToast.show(context, 'Could not open download link.', isError: true);
    }
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
          'App Updates',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _updateService,
        builder: (context, _) {
          final isChecking = _updateService.isChecking;
          final updateInfo = _updateService.latestUpdateInfo;
          final hasUpdate = updateInfo?.hasUpdate ?? false;
          final errorMsg = _updateService.errorMessage;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Status Card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: hasUpdate ? primaryColor.withOpacity(0.4) : borderColor,
                      width: hasUpdate ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Icon Animation Container
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasUpdate
                              ? primaryColor.withOpacity(0.15)
                              : const Color(0xFF3B82F6).withOpacity(0.12),
                          border: Border.all(
                            color: hasUpdate ? primaryColor : const Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isChecking
                              ? SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: primaryColor,
                                  ),
                                )
                              : Icon(
                                  hasUpdate ? Icons.system_update_rounded : Icons.check_circle_outline_rounded,
                                  size: 44,
                                  color: hasUpdate ? primaryColor : const Color(0xFF3B82F6),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isChecking
                            ? 'Checking for updates...'
                            : (hasUpdate ? 'New Update Available!' : 'Your App is Up to Date'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isChecking
                            ? 'Connecting to update servers...'
                            : (hasUpdate
                                ? 'Version ${updateInfo?.latestVersion} is ready to install'
                                : 'You have the latest version installed (${AppUpdateService.currentAppVersion})'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. What's New / Update Details Card (When update is available)
                if (hasUpdate && updateInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.new_releases_outlined, color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'What’s New in ${updateInfo.latestVersion}',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161920) : const Color(0xFFF1F4F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            updateInfo.description,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Package: ${updateInfo.fileName}',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            ),
                            if (updateInfo.formattedFileSize.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  updateInfo.formattedFileSize,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleDownload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1,
                              shadowColor: primaryColor.withOpacity(0.3),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 22, color: Colors.black87),
                            label: Text(
                              'Download Update',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 3. Error Notification (if any)
                if (errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            errorMsg,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 4. Auto-Check Toggle & Version Info Card
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeColor: primaryColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.autorenew_rounded, color: primaryColor, size: 22),
                        ),
                        title: Text(
                          'Auto-Check on App Open',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Automatically check for new releases when app launches',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                        value: _updateService.autoCheckEnabled,
                        onChanged: (val) async {
                          await _updateService.setAutoCheck(val);
                        },
                      ),
                      Divider(height: 1, color: borderColor),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Version',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                            ),
                            Text(
                              AppUpdateService.currentAppVersion,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_updateService.lastCheckedTimestamp != null) ...[
                        Divider(height: 1, color: borderColor),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Last Checked',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                              ),
                              Text(
                                DateFormat('dd MMM, hh:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(_updateService.lastCheckedTimestamp!),
                                ),
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Manual "Check for Updates" Button
                OutlinedButton.icon(
                  onPressed: isChecking
                      ? null
                      : () async {
                          final res = await _updateService.checkForUpdates(isManual: true);
                          if (!mounted) return;
                          if (res != null) {
                            if (res.hasUpdate) {
                              await NotificationService.instance.showUpdateNotification(res);
                              if (mounted) {
                                CustomToast.show(context, 'New version ${res.latestVersion} found!');
                              }
                            } else {
                              CustomToast.show(context, 'You are using the latest version.');
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isChecking ? Colors.grey : primaryColor),
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(
                    isChecking ? 'Checking Server...' : 'Check for Updates Now',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
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

// ══════════════════════════════════════════════════════════════════
// UPDATE DIALOG FOR AUTO-CHECK ON APP OPEN
// ══════════════════════════════════════════════════════════════════
void showAppUpdatePromptDialog(BuildContext context, AppUpdateInfo info) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primaryColor = const Color(0xFF00D09C);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.system_update_rounded, color: primaryColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Version ${info.latestVersion}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'A new version of Grow Expense is available to download with recent updates and improvements:',
                style: GoogleFonts.inter(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF202531) : const Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  info.description,
                  style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Later',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await AppUpdateService.instance.openDownloadLink();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(
                        'Download',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
