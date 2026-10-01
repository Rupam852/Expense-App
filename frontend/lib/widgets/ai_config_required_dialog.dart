import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/ai_config_screen.dart';
import '../services/ai_config_service.dart';
import 'report_issue_modal.dart';

/// Checks if AI service has active keys. With Server Remote Config, default AI is active out of the box.
/// Returns `true` if AI is available.
bool checkAndPromptAiConfig(BuildContext context) {
  final aiService = AiConfigService.instance;
  if (!aiService.hasAnyApiKey) {
    showAiConfigRequiredDialog(context);
    return false;
  }
  return true;
}

/// Shown if neither server remote config nor custom keys are available.
void showAiConfigRequiredDialog(BuildContext context) {
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
              // Header Icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    color: primaryColor,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'AI Configuration Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'AI features require an active AI key connection. Please configure your API key in Settings to activate AI receipt scanning, voice expense logging, and the financial advisor.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AiConfigScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.settings_suggest_rounded, size: 18, color: Colors.black87),
                      label: Text(
                        'Configure AI',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ReportIssueModal.show(
                      context,
                      category: 'AI Assistant / Models',
                      initialMessage: 'I need assistance setting up AI Configuration in Grow Expense.',
                    );
                  },
                  icon: const Icon(Icons.help_outline_rounded, size: 15, color: Colors.grey),
                  label: Text(
                    'Need Help? Contact Support',
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shown when default cloud AI server is rate-limited or busy, prompting the user non-intrusively
/// with option to Retry or Set their own free API key for instant responses.
void showAiServerBusyDialog(BuildContext context, {VoidCallback? onRetry}) {
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
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row with Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 5),
                        Text(
                          'High Server Traffic',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[800] ?? Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white54 : Colors.black45),
                    onPressed: () => Navigator.of(ctx).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'AI Server Busy',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'The default cloud AI server is currently handling high traffic or rate limits.\n\nFor ultra-fast, unlimited AI responses, you can configure your own free Google Gemini or NVIDIA API key in AI Configuration.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  if (onRetry != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onRetry();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AiConfigScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.vpn_key_rounded, size: 16, color: Colors.black87),
                      label: Text(
                        'Set My Own Key',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ReportIssueModal.show(
                      context,
                      category: 'AI Assistant / Models',
                      initialMessage: 'Encountered AI server high traffic or rate limits in Grow Expense.',
                    );
                  },
                  icon: const Icon(Icons.help_outline_rounded, size: 15, color: Colors.grey),
                  label: Text(
                    'Need Help? Report to Support',
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
