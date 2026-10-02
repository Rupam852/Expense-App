import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_config_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/report_issue_modal.dart';

class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key});

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  final AiConfigService _aiService = AiConfigService.instance;

  late String _aiMode; // 'default' or 'custom'
  late String _selectedGeminiModel;
  late String _selectedNvidiaModel;
  late String _primaryProvider;
  late String _secondaryProvider;

  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _nvidiaKeyController = TextEditingController();

  bool _obscureGeminiKey = true;
  bool _obscureNvidiaKey = true;
  bool _isSaving = false;

  static const int _testCooldownSeconds = 45;
  static DateTime? _lastDefaultTestTime;
  static DateTime? _lastCustomTestTime;

  Timer? _cooldownTicker;

  int get _defaultCooldownRemaining {
    if (_lastDefaultTestTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastDefaultTestTime!).inSeconds;
    final remaining = _testCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  int get _customCooldownRemaining {
    if (_lastCustomTestTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastCustomTestTime!).inSeconds;
    final remaining = _testCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get _isDefaultCooldownActive => _defaultCooldownRemaining > 0;
  bool get _isCustomCooldownActive => _customCooldownRemaining > 0;

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_defaultCooldownRemaining > 0 || _customCooldownRemaining > 0) {
        setState(() {});
      } else {
        setState(() {});
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _aiMode = _aiService.aiMode;
    _selectedGeminiModel = _aiService.geminiModel;
    _selectedNvidiaModel = _aiService.nvidiaModel;
    _geminiKeyController.text = _aiService.geminiApiKey;
    _nvidiaKeyController.text = _aiService.nvidiaApiKey;
    _primaryProvider = _aiService.primaryProvider;
    _secondaryProvider = _aiService.secondaryProvider;

    if (_isDefaultCooldownActive || _isCustomCooldownActive) {
      _startCooldownTicker();
    }
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _geminiKeyController.dispose();
    _nvidiaKeyController.dispose();
    super.dispose();
  }

  // Auto-save all configuration and exit cleanly
  Future<void> _handleAutoSaveAndExit() async {
    final hasGeminiKey = _geminiKeyController.text.trim().isNotEmpty;
    final hasNvidiaKey = _nvidiaKeyController.text.trim().isNotEmpty;

    if (_aiMode == 'custom') {
      if (hasGeminiKey || hasNvidiaKey) {
        // Save custom configuration and activate custom mode
        await _aiService.saveCustomConfiguration(
          geminiModel: _selectedGeminiModel,
          geminiApiKey: _geminiKeyController.text,
          nvidiaModel: _selectedNvidiaModel,
          nvidiaApiKey: _nvidiaKeyController.text,
          primaryProvider: _primaryProvider,
          secondaryProvider: _secondaryProvider,
          aiMode: 'custom',
        );
        if (mounted) {
          CustomToast.show(context, 'Custom AI configuration saved & active! ✨');
        }
      } else {
        // User chosen custom mode but entered no keys -> auto-fallback to default
        await _aiService.saveCustomConfiguration(
          geminiModel: _selectedGeminiModel,
          geminiApiKey: '',
          nvidiaModel: _selectedNvidiaModel,
          nvidiaApiKey: '',
          primaryProvider: _primaryProvider,
          secondaryProvider: _secondaryProvider,
          aiMode: 'default',
        );
        if (mounted) {
          CustomToast.show(context, 'No custom keys entered. Default Server AI active.');
        }
      }
    } else {
      // User chosen default mode -> save default mode (and preserve entered keys for later)
      await _aiService.saveCustomConfiguration(
        geminiModel: _selectedGeminiModel,
        geminiApiKey: _geminiKeyController.text,
        nvidiaModel: _selectedNvidiaModel,
        nvidiaApiKey: _nvidiaKeyController.text,
        primaryProvider: _primaryProvider,
        secondaryProvider: _secondaryProvider,
        aiMode: 'default',
      );
      if (mounted) {
        CustomToast.show(context, 'Default Server Cloud AI active!');
      }
    }
  }

  // Instant mode switcher in UI state
  void _onSelectMode(String mode) {
    setState(() => _aiMode = mode);
  }

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

  // Testing Dialog trigger for Custom Keys
  Future<void> _checkCustomConfigurationStatus() async {
    if (_geminiKeyController.text.trim().isEmpty && _nvidiaKeyController.text.trim().isEmpty) {
      CustomToast.show(
        context,
        'Please enter at least one API key (Gemini or NVIDIA) to test.',
        isError: true,
      );
      return;
    }

    final remaining = _customCooldownRemaining;
    if (remaining > 0) {
      CustomToast.show(
        context,
        '⏳ Please wait ${remaining}s before running another test.',
        isError: false,
      );
      return;
    }

    _lastCustomTestTime = DateTime.now();
    _startCooldownTicker();
    setState(() {});

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfigurationTestingDialog(
        aiService: _aiService,
        isDefaultServerTest: false,
        geminiKey: _geminiKeyController.text,
        geminiModel: _selectedGeminiModel,
        nvidiaKey: _nvidiaKeyController.text,
        nvidiaModel: _selectedNvidiaModel,
        primary: _primaryProvider,
        secondary: _secondaryProvider,
      ),
    );
  }

  // Testing Dialog trigger for Default Server AI
  Future<void> _checkDefaultServerStatus() async {
    final remaining = _defaultCooldownRemaining;
    if (remaining > 0) {
      CustomToast.show(
        context,
        '⏳ Please wait ${remaining}s before running another test.',
        isError: false,
      );
      return;
    }

    _lastDefaultTestTime = DateTime.now();
    _startCooldownTicker();
    setState(() {});

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfigurationTestingDialog(
        aiService: _aiService,
        isDefaultServerTest: true,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleAutoSaveAndExit();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF12141A) : const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
            onPressed: () async {
              await _handleAutoSaveAndExit();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'AI Configuration',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Help & Support',
              icon: Icon(Icons.help_outline_rounded, color: isDark ? Colors.white70 : Colors.black87),
              onPressed: () {
                ReportIssueModal.show(
                  context,
                  category: 'AI Assistant / Models',
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Mode Selector (Default vs Custom)
              _buildSectionHeader('AI ENGINE MODE', isDark),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181B22) : const Color(0xFFEAEFF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        title: 'Default (Server Cloud AI)',
                        subtitle: 'Zero Setup • Auto Ready',
                        isSelected: _aiMode == 'default',
                        icon: Icons.cloud_done_rounded,
                        accentColor: primaryColor,
                        isDark: isDark,
                        onTap: () => _onSelectMode('default'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeTab(
                        title: 'Custom (My Own Keys)',
                        subtitle: 'Personal API Quotas',
                        isSelected: _aiMode == 'custom',
                        icon: Icons.vpn_key_rounded,
                        accentColor: const Color(0xFF3B82F6),
                        isDark: isDark,
                        onTap: () => _onSelectMode('custom'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Default Mode UI vs Custom Mode UI
              if (_aiMode == 'default') ...[
                // Default Mode Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: primaryColor.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.verified_rounded, color: primaryColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Server Cloud AI Active',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Zero configuration required',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You are connected to the official Cloud AI engine. Smart OCR Receipt Scanning, Multilingual Voice Expense Logging, Mandi Price Analyzer, and the Financial Advisor Chatbot work seamlessly out of the box.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: primaryColor.withOpacity(0.2), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'If you experience high traffic delays, switch to "Custom (My Own Keys)" anytime for dedicated personal quotas.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Test Default Server AI Button
                OutlinedButton.icon(
                  onPressed: _isDefaultCooldownActive ? null : _checkDefaultServerStatus,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isDefaultCooldownActive
                          ? (isDark ? Colors.grey[700]! : Colors.grey[400]!)
                          : primaryColor.withValues(alpha: 0.6),
                    ),
                    foregroundColor: _isDefaultCooldownActive
                        ? Colors.grey
                        : primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(
                    _isDefaultCooldownActive ? Icons.timer_outlined : Icons.speed_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _isDefaultCooldownActive
                        ? 'Test Cooldown (${_defaultCooldownRemaining}s)'
                        : 'Test Default Server AI Latency',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ] else ...[
                // Custom Keys Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Private Device Storage',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Your personal API keys are encrypted and stored strictly on your local phone storage.',
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

                const SizedBox(height: 20),

                // Engine Priority Selector
                _buildSectionHeader('CUSTOM ENGINE PRIORITY & FAILOVER', isDark),
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
                        'Select primary provider. If one provider fails, the other will automatically serve as backup failover.',
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

                const SizedBox(height: 20),

                // Google Gemini Setup Card
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

                const SizedBox(height: 20),

                // NVIDIA NIM Setup Card
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

                const SizedBox(height: 20),

                // Custom Mode Action: Test API Keys (Auto-saved on Back)
                OutlinedButton.icon(
                  onPressed: _isCustomCooldownActive ? null : _checkCustomConfigurationStatus,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isCustomCooldownActive
                          ? (isDark ? Colors.grey[700]! : Colors.grey[400]!)
                          : const Color(0xFF3B82F6),
                    ),
                    foregroundColor: _isCustomCooldownActive ? Colors.grey : const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(
                    _isCustomCooldownActive ? Icons.timer_outlined : Icons.speed_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _isCustomCooldownActive
                        ? 'Test Cooldown (${_customCooldownRemaining}s)'
                        : 'Test Custom API Keys',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done_outlined, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                      const SizedBox(width: 6),
                      Text(
                        'Changes are automatically saved & synced to cloud on exit.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF222836) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: accentColor, width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accentColor : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? accentColor : Colors.grey,
              ),
            ),
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
                  final tag = _getModelTag(m);
                  final tagColor = _getModelTagColor(m);
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: tagColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  String _getModelTag(String model) {
    if (model.contains('3.8')) return '3.8 FLASH';
    if (model.contains('3.5-flash-lite')) return '3.5 LITE';
    if (model.contains('3.5')) return '3.5 FLASH';
    if (model.contains('3.1-pro')) return '3.1 PRO';
    if (model.contains('3.1')) return '3.1 LITE';
    if (model.contains('3-flash')) return '3.0 FLASH';
    if (model.contains('2.5-flash')) return '2.5 FLASH';
    if (model.contains('2.5-pro')) return '2.5 PRO';
    if (model.contains('latest')) return 'LATEST';
    if (model.contains('11b')) return '11B FAST';
    if (model.contains('90b')) return '90B PRO';
    if (model.contains('neva')) return 'NEVA 22B';
    return 'MODEL';
  }

  Color _getModelTagColor(String model) {
    if (model.contains('3.8') || model.contains('3.5') || model.contains('3-') || model.contains('3.1')) {
      return const Color(0xFF3B82F6);
    }
    if (model.contains('2.5')) {
      return const Color(0xFF10B981);
    }
    if (model.contains('pro')) {
      return const Color(0xFF8B5CF6);
    }
    if (model.contains('llama') || model.contains('neva')) {
      return const Color(0xFF10B981);
    }
    return Colors.teal;
  }
}

// ══════════════════════════════════════════════════════════════════
// TEST RESULTS DIALOG (Supports both Default Server AI and Custom Keys)
// ══════════════════════════════════════════════════════════════════
class _ConfigurationTestingDialog extends StatefulWidget {
  final AiConfigService aiService;
  final bool isDefaultServerTest;
  final String? geminiKey;
  final String? geminiModel;
  final String? nvidiaKey;
  final String? nvidiaModel;
  final String? primary;
  final String? secondary;

  const _ConfigurationTestingDialog({
    required this.aiService,
    required this.isDefaultServerTest,
    this.geminiKey,
    this.geminiModel,
    this.nvidiaKey,
    this.nvidiaModel,
    this.primary,
    this.secondary,
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
    List<ModelCheckResult> res;
    if (widget.isDefaultServerTest) {
      res = await widget.aiService.checkDefaultServerConfiguration();
    } else {
      res = await widget.aiService.checkCustomConfiguration(
        testGeminiKey: widget.geminiKey,
        testGeminiModel: widget.geminiModel,
        testNvidiaKey: widget.nvidiaKey,
        testNvidiaModel: widget.nvidiaModel,
        testPrimary: widget.primary,
        testSecondary: widget.secondary,
      );
    }

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
                  widget.isDefaultServerTest ? 'Server AI Connection' : 'Custom AI Validation',
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
                widget.isDefaultServerTest
                    ? 'Pinging default cloud AI models & checking latency...'
                    : 'Testing live connection to AI models with multi-model fallback...',
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
                          if (isSuccess && r.latencyMs > 0)
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
              if (_results != null && _results!.any((r) => !r.isWorking)) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      final failedLogs = _results!
                          .where((r) => !r.isWorking)
                          .map((r) => '${r.provider} (${r.modelName}): ${r.message}')
                          .join('\n');
                      Navigator.of(context).pop();
                      ReportIssueModal.show(
                        context,
                        category: 'AI Assistant / Models',
                        initialError: failedLogs,
                        initialMessage: 'My AI test run encountered an error.',
                      );
                    },
                    icon: const Icon(Icons.help_outline_rounded, size: 15, color: Colors.grey),
                    label: Text(
                      'Tests Failed? Contact Support',
                      style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
