import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_config_service.dart';
import '../widgets/custom_toast.dart';

class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key});

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  final AiConfigService _aiService = AiConfigService.instance;

  late String _selectedMode;
  late String _selectedGeminiModel;
  late String _selectedNvidiaModel;
  late String _primaryProvider;
  late String _secondaryProvider;

  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _nvidiaKeyController = TextEditingController();

  bool _obscureGeminiKey = true;
  bool _obscureNvidiaKey = true;
  bool _isSaving = false;

  Timer? _cooldownTimer;
  int _currentCooldown = 0;

  @override
  void initState() {
    super.initState();
    _selectedMode = _aiService.mode;
    _selectedGeminiModel = _aiService.geminiModel;
    _selectedNvidiaModel = _aiService.nvidiaModel;
    _geminiKeyController.text = _aiService.geminiApiKey;
    _nvidiaKeyController.text = _aiService.nvidiaApiKey;
    _primaryProvider = _aiService.primaryProvider;
    _secondaryProvider = _aiService.secondaryProvider;

    _updateCooldownState();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _updateCooldownState();
    });
  }

  void _updateCooldownState() {
    final remaining = _aiService.remainingCooldownSeconds;
    if (remaining != _currentCooldown) {
      setState(() {
        _currentCooldown = remaining;
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
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

  // Mutual switch logic for Secondary Provider
  void _onSetSecondary(String provider) {
    setState(() {
      if (provider == 'gemini') {
        _secondaryProvider = 'gemini';
        _primaryProvider = 'nvidia';
      } else {
        _secondaryProvider = 'nvidia';
        _primaryProvider = 'gemini';
      }
    });
  }

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
    });

    final success = await _aiService.saveCustomConfiguration(
      mode: _selectedMode,
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
        CustomToast.show(context, 'AI Configuration saved locally to phone storage.');
      } else {
        CustomToast.show(context, 'Failed to save configuration.', isError: true);
      }
    }
  }

  // Trigger testing default models with a 30s cooldown
  Future<void> _checkDefaultModelsStatus() async {
    if (_currentCooldown > 0) {
      CustomToast.show(
        context,
        'Please wait $_currentCooldown seconds before testing default models again.',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DefaultModelTestingDialog(
        aiService: _aiService,
        onDone: () {
          _updateCooldownState();
        },
      ),
    );
  }

  // Trigger testing custom configuration
  Future<void> _checkCustomConfigurationStatus() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CustomModelTestingDialog(
        aiService: _aiService,
        geminiKey: _geminiKeyController.text,
        geminiModel: _selectedGeminiModel,
        nvidiaKey: _nvidiaKeyController.text,
        nvidiaModel: _selectedNvidiaModel,
        primaryProvider: _primaryProvider,
        secondaryProvider: _secondaryProvider,
      ),
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
          'AI Configuration',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          if (_selectedMode == 'custom')
            TextButton.icon(
              onPressed: _isSaving ? null : _saveConfiguration,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D09C)),
                    )
                  : const Icon(Icons.check, color: Color(0xFF00D09C), size: 20),
              label: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00D09C),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Segmented Switcher (Default vs Custom)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E232E) : const Color(0xFFE9EDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _selectedMode = 'default');
                        await _aiService.setMode('default');
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedMode == 'default' ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _selectedMode == 'default'
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: _selectedMode == 'default' ? Colors.black87 : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Default AI',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _selectedMode == 'default' ? Colors.black87 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _selectedMode = 'custom');
                        await _aiService.setMode('custom');
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedMode == 'custom' ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _selectedMode == 'custom'
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune,
                              size: 18,
                              color: _selectedMode == 'custom' ? Colors.black87 : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Custom AI',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _selectedMode == 'custom' ? Colors.black87 : Colors.grey,
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

            const SizedBox(height: 20),

            // CONTENT: DEFAULT MODE
            if (_selectedMode == 'default') ...[
              _buildDefaultModeSection(isDark, cardBg, borderColor, primaryColor),
            ],

            // CONTENT: CUSTOM MODE
            if (_selectedMode == 'custom') ...[
              _buildCustomModeSection(isDark, cardBg, borderColor, primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 1. DEFAULT MODE VIEW
  // ════════════════════════════════════════════════════════════
  Widget _buildDefaultModeSection(bool isDark, Color cardBg, Color borderColor, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Overview Card
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.cloud_done_outlined, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud Managed AI Models',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zero setup required. Ready to scan receipts & analyze bills.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Default models included in rotation with intelligent auto-failover:',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildDefaultModelTile(
                name: 'Gemini 2.0 Flash',
                type: 'Primary Engine',
                desc: 'Ultra-fast multimodal recognition for instant receipts',
                isPrimary: true,
                isDark: isDark,
              ),
              _buildDefaultModelTile(
                name: 'Gemini 1.5 Flash',
                type: 'Failover Backup',
                desc: 'High-throughput secondary image extraction',
                isPrimary: false,
                isDark: isDark,
              ),
              _buildDefaultModelTile(
                name: 'Gemini 1.5 Pro',
                type: 'Reasoning Engine',
                desc: 'Complex receipt structure & itemization analysis',
                isPrimary: false,
                isDark: isDark,
              ),
              _buildDefaultModelTile(
                name: 'Gemini 2.0 Flash Lite',
                type: 'Low-latency Backup',
                desc: 'Lightweight rapid financial parser',
                isPrimary: false,
                isDark: isDark,
              ),
              _buildDefaultModelTile(
                name: 'Gemini Pro Latest',
                type: 'Standard Fallback',
                desc: 'Long-term baseline cloud fallback',
                isPrimary: false,
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Test Default AI Models Button with 30s Cooldown
        ElevatedButton.icon(
          onPressed: _currentCooldown > 0 ? null : _checkDefaultModelsStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.black87,
            disabledBackgroundColor: isDark ? const Color(0xFF252A36) : const Color(0xFFE2E7F0),
            disabledForegroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          icon: _currentCooldown > 0
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                )
              : const Icon(Icons.network_check_outlined, size: 20),
          label: Text(
            _currentCooldown > 0
                ? 'Check Default AI Models (${_currentCooldown}s)'
                : 'Check Default AI Models Status',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        if (_currentCooldown > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Cooldown active to prevent rate limits. You can re-test every 30s.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultModelTile({
    required String name,
    required String type,
    required String desc,
    required bool isPrimary,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161920) : const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? const Color(0xFF00D09C).withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPrimary ? Icons.star_rounded : Icons.check_circle_outline,
            color: isPrimary ? const Color(0xFF00D09C) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? const Color(0xFF00D09C).withOpacity(0.15)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPrimary ? const Color(0xFF00D09C) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  desc,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 2. CUSTOM MODE VIEW
  // ════════════════════════════════════════════════════════════
  Widget _buildCustomModeSection(bool isDark, Color cardBg, Color borderColor, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Storage Notice Badge
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00D09C).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00D09C).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF00D09C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Custom API keys and model choices are securely saved in your phone storage only (never sent to Supabase cloud).',
                  style: GoogleFonts.inter(fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Primary / Secondary Engine Assignment Banner
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
                'AI Engine Hierarchy (Auto-Failover)',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select which provider serves as Primary (main execution) and Secondary (automatic backup on rate limits).',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildRoleSelectorCard(
                      title: 'Gemini Primary',
                      subtitle: 'NVIDIA Secondary',
                      isSelected: _primaryProvider == 'gemini',
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onTap: () => _onSetPrimary('gemini'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRoleSelectorCard(
                      title: 'NVIDIA Primary',
                      subtitle: 'Gemini Secondary',
                      isSelected: _primaryProvider == 'nvidia',
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onTap: () => _onSetPrimary('nvidia'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 1. GEMINI SECTION CARD
        _buildProviderCard(
          providerId: 'gemini',
          providerTitle: 'Google Gemini AI',
          icon: Icons.flash_on_rounded,
          iconColor: const Color(0xFF3B82F6),
          isPrimary: _primaryProvider == 'gemini',
          modelList: AiConfigService.availableGeminiModels,
          selectedModel: _selectedGeminiModel,
          onModelChanged: (val) {
            if (val != null) setState(() => _selectedGeminiModel = val);
          },
          apiKeyController: _geminiKeyController,
          isObscured: _obscureGeminiKey,
          onToggleObscure: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
          hintText: 'AIzaSy...',
          helperTitle: 'Google AI Studio',
          helperUrl: 'aistudio.google.com',
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          primaryColor: primaryColor,
          onSetAsPrimary: () => _onSetPrimary('gemini'),
          onSetAsSecondary: () => _onSetSecondary('gemini'),
        ),

        const SizedBox(height: 20),

        // 2. NVIDIA NIM SECTION CARD
        _buildProviderCard(
          providerId: 'nvidia',
          providerTitle: 'NVIDIA NIM (Cloud API)',
          icon: Icons.memory,
          iconColor: const Color(0xFF76B900),
          isPrimary: _primaryProvider == 'nvidia',
          modelList: AiConfigService.availableNvidiaModels,
          selectedModel: _selectedNvidiaModel,
          onModelChanged: (val) {
            if (val != null) setState(() => _selectedNvidiaModel = val);
          },
          apiKeyController: _nvidiaKeyController,
          isObscured: _obscureNvidiaKey,
          onToggleObscure: () => setState(() => _obscureNvidiaKey = !_obscureNvidiaKey),
          hintText: 'nvapi-...',
          helperTitle: 'NVIDIA Build Cloud',
          helperUrl: 'build.nvidia.com',
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          primaryColor: primaryColor,
          onSetAsPrimary: () => _onSetPrimary('nvidia'),
          onSetAsSecondary: () => _onSetSecondary('nvidia'),
        ),

        const SizedBox(height: 28),

        // Action Buttons: Check Custom & Save Configuration
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveConfiguration,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                )
              : const Icon(Icons.save_outlined, size: 20),
          label: Text(
            _isSaving ? 'Saving to Local Storage...' : 'Save Configuration',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _checkCustomConfigurationStatus,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: primaryColor),
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.verified_outlined, size: 20),
          label: Text(
            'Check Your Custom AI Configuration',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildRoleSelectorCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.12)
              : (isDark ? const Color(0xFF161920) : const Color(0xFFF1F4F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? primaryColor : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? primaryColor : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard({
    required String providerId,
    required String providerTitle,
    required IconData icon,
    required Color iconColor,
    required bool isPrimary,
    required List<String> modelList,
    required String selectedModel,
    required ValueChanged<String?> onModelChanged,
    required TextEditingController apiKeyController,
    required bool isObscured,
    required VoidCallback onToggleObscure,
    required String hintText,
    required String helperTitle,
    required String helperUrl,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryColor,
    required VoidCallback onSetAsPrimary,
    required VoidCallback onSetAsSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? primaryColor.withOpacity(0.5) : borderColor,
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Primary/Secondary Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerTitle,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      isPrimary ? 'Primary Engine (Main)' : 'Secondary Engine (Failover)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isPrimary ? primaryColor : Colors.grey,
                        fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              // Role Toggle Chip
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'primary') onSetAsPrimary();
                  if (val == 'secondary') onSetAsSecondary();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'primary',
                    child: Text('Set as Primary Engine'),
                  ),
                  const PopupMenuItem(
                    value: 'secondary',
                    child: Text('Set as Secondary Backup'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? primaryColor.withOpacity(0.15)
                        : const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPrimary ? 'PRIMARY' : 'SECONDARY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPrimary ? primaryColor : const Color(0xFF818CF8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: isPrimary ? primaryColor : const Color(0xFF818CF8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 1. Model Selector Dropdown
          Text(
            'Select AI Model',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
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
                value: modelList.contains(selectedModel) ? selectedModel : modelList.first,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E232E) : Colors.white,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: modelList.map((m) {
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

          // 2. API Key Input Field
          Text(
            'API Key',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: apiKeyController,
            obscureText: isObscured,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: isDark ? const Color(0xFF161920) : const Color(0xFFF1F4F9),
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
                borderSide: BorderSide(color: primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: onToggleObscure,
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste_outlined, size: 20, color: Colors.grey),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        apiKeyController.text = data!.text!.trim();
                        if (mounted) {
                          CustomToast.show(context, 'Pasted from clipboard');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Helper Link
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Get key at ',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
              ),
              Text(
                helperUrl,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// 3. TESTING MODAL DIALOG: DEFAULT MODELS (Live Diagnostics)
// ══════════════════════════════════════════════════════════════════
class _DefaultModelTestingDialog extends StatefulWidget {
  final AiConfigService aiService;
  final VoidCallback onDone;

  const _DefaultModelTestingDialog({
    required this.aiService,
    required this.onDone,
  });

  @override
  State<_DefaultModelTestingDialog> createState() => _DefaultModelTestingDialogState();
}

class _DefaultModelTestingDialogState extends State<_DefaultModelTestingDialog> {
  bool _isRunning = true;
  String _currentTesting = 'Initializing...';
  List<ModelCheckResult> _results = [];
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    _startTest();
  }

  Future<void> _startTest() async {
    try {
      final res = await widget.aiService.checkDefaultModels(
        onProgress: (current, total, modelName) {
          if (mounted) {
            setState(() {
              _currentTesting = 'Testing $modelName ($current/$total)...';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _results = res;
          _isRunning = false;
        });
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fatalError = e.toString();
          _isRunning = false;
        });
        widget.onDone();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.network_check, color: primaryColor, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Default AI Status Check',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isRunning) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(color: Color(0xFF00D09C)),
                ),
              ),
              Text(
                _currentTesting,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ] else if (_fatalError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _fatalError!,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            ] else ...[
              Text(
                'Diagnostic Results (${_results.where((r) => r.isWorking).length}/${_results.length} operational):',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (ctx, idx) {
                    final item = _results[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202531) : const Color(0xFFF3F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.isWorking ? Icons.check_circle : Icons.cancel,
                            color: item.isWorking ? const Color(0xFF00D09C) : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.modelName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  item.message,
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          if (item.latencyMs > 0)
                            Text(
                              '${item.latencyMs}ms',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isWorking ? const Color(0xFF00D09C) : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (!_isRunning)
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// 4. TESTING MODAL DIALOG: CUSTOM CONFIGURATION (Live Diagnostics)
// ══════════════════════════════════════════════════════════════════
class _CustomModelTestingDialog extends StatefulWidget {
  final AiConfigService aiService;
  final String geminiKey;
  final String geminiModel;
  final String nvidiaKey;
  final String nvidiaModel;
  final String primaryProvider;
  final String secondaryProvider;

  const _CustomModelTestingDialog({
    required this.aiService,
    required this.geminiKey,
    required this.geminiModel,
    required this.nvidiaKey,
    required this.nvidiaModel,
    required this.primaryProvider,
    required this.secondaryProvider,
  });

  @override
  State<_CustomModelTestingDialog> createState() => _CustomModelTestingDialogState();
}

class _CustomModelTestingDialogState extends State<_CustomModelTestingDialog> {
  bool _isRunning = true;
  List<ModelCheckResult> _results = [];
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    _startTest();
  }

  Future<void> _startTest() async {
    try {
      final res = await widget.aiService.checkCustomConfiguration(
        testGeminiKey: widget.geminiKey,
        testGeminiModel: widget.geminiModel,
        testNvidiaKey: widget.nvidiaKey,
        testNvidiaModel: widget.nvidiaModel,
        testPrimary: widget.primaryProvider,
        testSecondary: widget.secondaryProvider,
      );
      if (mounted) {
        setState(() {
          _results = res;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fatalError = e.toString();
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: primaryColor, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Custom AI Verification',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isRunning) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(color: Color(0xFF00D09C)),
                ),
              ),
              Text(
                'Verifying your custom API keys and models with live test queries...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ] else if (_fatalError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _fatalError!,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            ] else ...[
              Text(
                'Configuration Status Summary:',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._results.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202531) : const Color(0xFFF3F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.isWorking
                          ? const Color(0xFF00D09C).withOpacity(0.3)
                          : Colors.redAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.isWorking ? Icons.check_circle : Icons.error_outline,
                            color: item.isWorking ? const Color(0xFF00D09C) : Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.provider,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (item.latencyMs > 0)
                            Text(
                              '${item.latencyMs}ms',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isWorking ? const Color(0xFF00D09C) : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 30.0),
                        child: Text(
                          'Model: ${item.modelName}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 30.0, top: 2),
                        child: Text(
                          item.message,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: item.isWorking ? Colors.grey : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
            if (!_isRunning)
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
