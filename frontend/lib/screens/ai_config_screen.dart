import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_config_service.dart';
import '../widgets/custom_toast.dart';

class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key});

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  final AiConfigService _aiService = AiConfigService.instance;

  late String _selectedGeminiModel;
  late String _selectedNvidiaModel;
  late String _primaryProvider;
  late String _secondaryProvider;

  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _nvidiaKeyController = TextEditingController();

  bool _obscureGeminiKey = true;
  bool _obscureNvidiaKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedGeminiModel = _aiService.geminiModel;
    _selectedNvidiaModel = _aiService.nvidiaModel;
    _geminiKeyController.text = _aiService.geminiApiKey;
    _nvidiaKeyController.text = _aiService.nvidiaApiKey;
    _primaryProvider = _aiService.primaryProvider;
    _secondaryProvider = _aiService.secondaryProvider;
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _nvidiaKeyController.dispose();
    super.dispose();
  }

  // Mutual switch logic for Primary Provider
  void _onSetPrimary(String provider) {
    setState(() {
      if (provider == 'gemini') {
        _primaryProvider = 'gemini';
        _secondaryProvider = 'nvidia';
      } else {
        _primaryProvider = 'nvidia';
        _secondaryProvider = 'gemini';
      }
    });
  }

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
    });

    final success = await _aiService.saveCustomConfiguration(
      geminiModel: _selectedGeminiModel,
      geminiApiKey: _geminiKeyController.text,
      nvidiaModel: _selectedNvidiaModel,
      nvidiaApiKey: _nvidiaKeyController.text,
      primaryProvider: _primaryProvider,
      secondaryProvider: _secondaryProvider,
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      if (success) {
        CustomToast.show(context, 'AI Configuration saved to Phone Storage!');
      } else {
        CustomToast.show(context, 'Failed to save configuration.', isError: true);
      }
    }
  }

  // Trigger testing custom configuration
  Future<void> _checkConfigurationStatus() async {
    if (_geminiKeyController.text.trim().isEmpty && _nvidiaKeyController.text.trim().isEmpty) {
      CustomToast.show(
        context,
        'Please enter at least one API key (Gemini or NVIDIA) to test.',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfigurationTestingDialog(
        aiService: _aiService,
        geminiKey: _geminiKeyController.text,
        geminiModel: _selectedGeminiModel,
        nvidiaKey: _nvidiaKeyController.text,
        nvidiaModel: _selectedNvidiaModel,
        primary: _primaryProvider,
        secondary: _secondaryProvider,
      ),
    );
  }

  Future<void> _openExternalUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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
          'AI Configuration',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.vpn_key_rounded, color: primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal API Keys Required',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI Receipt Scanning & Smart Categorization use your own API keys. All keys are stored strictly on your device (Phone Storage) and never uploaded to any remote server.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Engine Role Selector (Primary ↔ Backup Failover)
            _buildSectionHeader('PRIMARY ENGINE & BACKUP FAILOVER', isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select which AI provider should process your scans first. If the primary fails, the backup will automatically take over.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEngineSelectCard(
                          title: 'Google Gemini',
                          isPrimary: _primaryProvider == 'gemini',
                          isDark: isDark,
                          accentColor: const Color(0xFF3B82F6),
                          icon: Icons.auto_awesome_rounded,
                          onTap: () => _onSetPrimary('gemini'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEngineSelectCard(
                          title: 'NVIDIA NIM',
                          isPrimary: _primaryProvider == 'nvidia',
                          isDark: isDark,
                          accentColor: const Color(0xFF10B981),
                          icon: Icons.memory_rounded,
                          onTap: () => _onSetPrimary('nvidia'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Google Gemini Setup Card
            _buildSectionHeader('GOOGLE GEMINI CONFIGURATION', isDark),
            const SizedBox(height: 8),
            _buildProviderCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              providerName: 'Google Gemini',
              accentColor: const Color(0xFF3B82F6),
              icon: Icons.auto_awesome_rounded,
              isPrimary: _primaryProvider == 'gemini',
              selectedModel: _selectedGeminiModel,
              availableModels: AiConfigService.availableGeminiModels,
              onModelChanged: (val) {
                if (val != null) setState(() => _selectedGeminiModel = val);
              },
              keyController: _geminiKeyController,
              obscureKey: _obscureGeminiKey,
              onToggleObscure: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
              helpUrl: 'https://aistudio.google.com/app/apikey',
              helpText: 'Get free Gemini API Key → Google AI Studio',
            ),

            const SizedBox(height: 24),

            // 4. NVIDIA NIM Setup Card
            _buildSectionHeader('NVIDIA NIM CONFIGURATION', isDark),
            const SizedBox(height: 8),
            _buildProviderCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              providerName: 'NVIDIA NIM',
              accentColor: const Color(0xFF10B981),
              icon: Icons.memory_rounded,
              isPrimary: _primaryProvider == 'nvidia',
              selectedModel: _selectedNvidiaModel,
              availableModels: AiConfigService.availableNvidiaModels,
              onModelChanged: (val) {
                if (val != null) setState(() => _selectedNvidiaModel = val);
              },
              keyController: _nvidiaKeyController,
              obscureKey: _obscureNvidiaKey,
              onToggleObscure: () => setState(() => _obscureNvidiaKey = !_obscureNvidiaKey),
              helpUrl: 'https://build.nvidia.com',
              helpText: 'Get free NVIDIA NIM Key (nvapi-...) → build.nvidia.com',
            ),

            const SizedBox(height: 32),

            // 5. Action Buttons (Test & Save)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _checkConfigurationStatus,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor),
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.speed_rounded, size: 20),
                    label: Text(
                      'Test Keys',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveConfiguration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Configuration',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildEngineSelectCard({
    required String title,
    required bool isPrimary,
    required bool isDark,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isPrimary ? accentColor.withOpacity(0.12) : (isDark ? const Color(0xFF161920) : const Color(0xFFF1F4F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? accentColor : (isDark ? const Color(0xFF2C3242) : const Color(0xFFE5E9F0)),
            width: isPrimary ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isPrimary ? accentColor : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isPrimary ? accentColor : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isPrimary ? accentColor.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isPrimary ? 'PRIMARY' : 'BACKUP',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? accentColor : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required String providerName,
    required Color accentColor,
    required IconData icon,
    required bool isPrimary,
    required String selectedModel,
    required List<String> availableModels,
    required ValueChanged<String?> onModelChanged,
    required TextEditingController keyController,
    required bool obscureKey,
    required VoidCallback onToggleObscure,
    required String helpUrl,
    required String helpText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                providerName,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPrimary ? accentColor.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPrimary ? 'Primary Engine' : 'Backup Failover',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPrimary ? accentColor : Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Model Selection Dropdown
          Text(
            'Select Model',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161920) : const Color(0xFFF1F4F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableModels.contains(selectedModel) ? selectedModel : availableModels.first,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E232E) : Colors.white,
                items: availableModels.map((m) {
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Text(
                      m,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onModelChanged,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // API Key Field
          Text(
            'API Key',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: keyController,
            obscureText: obscureKey,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter $providerName API Key',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              filled: true,
              fillColor: isDark ? const Color(0xFF161920) : const Color(0xFFF1F4F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: onToggleObscure,
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste_rounded, size: 18, color: Colors.grey),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        keyController.text = data!.text!.trim();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Help URL Button
          GestureDetector(
            onTap: () => _openExternalUrl(helpUrl),
            child: Row(
              children: [
                Icon(Icons.open_in_new_rounded, size: 13, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    helpText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TEST RESULTS DIALOG
// ══════════════════════════════════════════════════════════════════
class _ConfigurationTestingDialog extends StatefulWidget {
  final AiConfigService aiService;
  final String geminiKey;
  final String geminiModel;
  final String nvidiaKey;
  final String nvidiaModel;
  final String primary;
  final String secondary;

  const _ConfigurationTestingDialog({
    required this.aiService,
    required this.geminiKey,
    required this.geminiModel,
    required this.nvidiaKey,
    required this.nvidiaModel,
    required this.primary,
    required this.secondary,
  });

  @override
  State<_ConfigurationTestingDialog> createState() => _ConfigurationTestingDialogState();
}

class _ConfigurationTestingDialogState extends State<_ConfigurationTestingDialog> {
  bool _isLoading = true;
  List<ModelCheckResult> _results = [];

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    final res = await widget.aiService.checkCustomConfiguration(
      testGeminiKey: widget.geminiKey,
      testGeminiModel: widget.geminiModel,
      testNvidiaKey: widget.nvidiaKey,
      testNvidiaModel: widget.nvidiaModel,
      testPrimary: widget.primary,
      testSecondary: widget.secondary,
    );

    if (mounted) {
      setState(() {
        _results = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: const Color(0xFF00D09C), size: 24),
                const SizedBox(width: 10),
                Text(
                  'AI Key Validation',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator(color: Color(0xFF00D09C))),
              const SizedBox(height: 16),
              Text(
                'Testing live connection to AI models...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ] else ...[
              ..._results.map((r) {
                final isSuccess = r.isWorking;
                final statusColor = isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: statusColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.provider,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (isSuccess)
                            Text(
                              '${r.latencyMs}ms',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Model: ${r.modelName}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.message,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D09C),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
