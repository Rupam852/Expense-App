import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/ai_config_screen.dart';
import '../services/ai_config_service.dart';

/// Shows a dialog prompting the user to set up AI Configuration first if no API key is present.
/// Returns `true` if AI is already configured, `false` if prompted.
bool checkAndPromptAiConfig(BuildContext context) {
  final aiService = AiConfigService.instance;
  if (!aiService.hasAnyApiKey) {
    showAiConfigRequiredDialog(context);
    return false;
  }
  return true;
}

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
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
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
                'Smart OCR receipt scanning and auto-categorization require your personal AI API Key (Google Gemini or NVIDIA NIM).\n\nPlease first configure your AI key in settings to start scanning receipts.',
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
            ],
          ),
        ),
      );
    },
  );
}
