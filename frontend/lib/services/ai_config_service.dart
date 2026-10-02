import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class ModelCheckResult {
  final String provider;
  final String modelName;
  final bool isWorking;
  final int latencyMs;
  final String message;
  final String? errorDetails;

  ModelCheckResult({
    required this.provider,
    required this.modelName,
    required this.isWorking,
    required this.latencyMs,
    required this.message,
    this.errorDetails,
  });
}

class AiConfigService with ChangeNotifier {
  static final AiConfigService instance = AiConfigService._internal();
  AiConfigService._internal() {
    _loadConfig();
  }

  factory AiConfigService() => instance;

  // Supported Gemini Models (Organized hierarchically: 3.x Series ➔ 2.5 Series ➔ Auto Aliases)
  static const List<String> availableGeminiModels = [
    // 1. Gemini 3.x Generation (Flagship & Ultra Fast)
    'gemini-3.8-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-pro-preview',
    'gemini-3.1-flash-lite',
    'gemini-3-flash-preview',
    // 2. Gemini 2.5 Generation (Stable High Performance)
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    // 3. Dynamic Auto-Updating Aliases
    'gemini-flash-latest',
    'gemini-pro-latest',
  ];

  // Supported NVIDIA NIM Vision Models (Best Free Multimodal OCR on build.nvidia.com)
  static const List<String> availableNvidiaModels = [
    'meta/llama-3.2-11b-vision-instruct',
    'meta/llama-3.2-90b-vision-instruct',
    'nvidia/neva-22b',
  ];

  // Configuration Fields
  String _aiMode = 'default'; // 'default' (Server Cloud AI) | 'custom' (My Own Keys)
  String _geminiModel = 'gemini-2.5-flash';
  String _geminiApiKey = '';
  String _nvidiaModel = 'meta/llama-3.2-11b-vision-instruct';
  String _nvidiaApiKey = '';
  String _primaryProvider = 'gemini'; // 'gemini' | 'nvidia'
  String _secondaryProvider = 'nvidia'; // 'nvidia' | 'gemini'
  String _responseLanguage = 'English'; // Default English

  // Remote Server Default AI Configuration (Safely fetched from Supabase, never hardcoded in code)
  String _defaultGeminiApiKey = '';
  String _defaultNvidiaApiKey = '';
  String _defaultPrimaryProvider = 'gemini';
  String _defaultSecondaryProvider = 'nvidia';
  String _defaultGeminiModel = 'gemini-2.5-flash';
  String _defaultNvidiaModel = 'meta/llama-3.3-70b-instruct';
  bool _isFetchingRemoteDefaults = false;

  bool _isInitialized = false;

  // Getters
  String get aiMode => _aiMode;
  bool get isCustomMode => _aiMode == 'custom';
  bool get isDefaultMode => _aiMode == 'default';

  String get geminiModel => _geminiModel;
  String get geminiApiKey => _geminiApiKey;
  String get nvidiaModel => _nvidiaModel;
  String get nvidiaApiKey => _nvidiaApiKey;
  String get primaryProvider => _primaryProvider;
  String get secondaryProvider => _secondaryProvider;
  String get responseLanguage => _responseLanguage;
  bool get isInitialized => _isInitialized;

  // Effective Configuration (Seamlessly uses Custom when enabled and configured, otherwise uses Default Server AI)
  String get effectiveGeminiApiKey {
    if (isCustomMode && _geminiApiKey.trim().isNotEmpty) {
      return _geminiApiKey.trim();
    }
    return _defaultGeminiApiKey.trim().isNotEmpty ? _defaultGeminiApiKey.trim() : _geminiApiKey.trim();
  }

  String get effectiveNvidiaApiKey {
    if (isCustomMode && _nvidiaApiKey.trim().isNotEmpty) {
      return _nvidiaApiKey.trim();
    }
    return _defaultNvidiaApiKey.trim().isNotEmpty ? _defaultNvidiaApiKey.trim() : _nvidiaApiKey.trim();
  }

  String get effectiveGeminiModel {
    if (isCustomMode && _geminiModel.trim().isNotEmpty) {
      return _geminiModel.trim();
    }
    return _defaultGeminiModel.trim().isNotEmpty ? _defaultGeminiModel.trim() : 'gemini-2.5-flash';
  }

  String get effectiveNvidiaModel {
    if (isCustomMode && _nvidiaModel.trim().isNotEmpty) {
      return _nvidiaModel.trim();
    }
    return _defaultNvidiaModel.trim().isNotEmpty ? _defaultNvidiaModel.trim() : 'meta/llama-3.2-11b-vision-instruct';
  }

  String get effectivePrimaryProvider {
    if (isCustomMode) return _primaryProvider;
    return _defaultPrimaryProvider;
  }

  String get effectiveSecondaryProvider {
    if (isCustomMode) return _secondaryProvider;
    return _defaultSecondaryProvider;
  }

  bool get hasAnyApiKey => effectiveGeminiApiKey.isNotEmpty || effectiveNvidiaApiKey.isNotEmpty;
  bool get hasPrimaryApiKey => effectivePrimaryProvider == 'gemini' 
      ? effectiveGeminiApiKey.isNotEmpty 
      : effectiveNvidiaApiKey.isNotEmpty;
  bool get hasSecondaryConfig => effectiveSecondaryProvider == 'gemini'
      ? effectiveGeminiApiKey.isNotEmpty
      : effectiveNvidiaApiKey.isNotEmpty;

  // SharedPreferences Keys (Strictly local phone storage)
  static const String _keyAiMode = 'local_ai_mode';
  static const String _keyGeminiModel = 'local_ai_gemini_model';
  static const String _keyGeminiApiKey = 'local_ai_gemini_api_key';
  static const String _keyNvidiaModel = 'local_ai_nvidia_model';
  static const String _keyNvidiaApiKey = 'local_ai_nvidia_api_key';
  static const String _keyPrimaryProvider = 'local_ai_primary_provider';
  static const String _keySecondaryProvider = 'local_ai_secondary_provider';
  static const String _keyResponseLanguage = 'local_ai_response_language';

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _aiMode = prefs.getString(_keyAiMode) ?? 'default';
      _geminiModel = prefs.getString(_keyGeminiModel) ?? 'gemini-2.5-flash';
      _geminiApiKey = prefs.getString(_keyGeminiApiKey) ?? '';
      _nvidiaModel = prefs.getString(_keyNvidiaModel) ?? 'meta/llama-3.2-11b-vision-instruct';
      _nvidiaApiKey = prefs.getString(_keyNvidiaApiKey) ?? '';
      _primaryProvider = prefs.getString(_keyPrimaryProvider) ?? 'gemini';
      _secondaryProvider = prefs.getString(_keySecondaryProvider) ?? 'nvidia';
      _responseLanguage = prefs.getString(_keyResponseLanguage) ?? 'English';

      // Ensure valid primary/secondary pairing
      if (_primaryProvider == _secondaryProvider) {
        if (_primaryProvider == 'gemini') {
          _secondaryProvider = 'nvidia';
        } else {
          _secondaryProvider = 'gemini';
        }
      }

      _isInitialized = true;
      notifyListeners();

      // Silently fetch remote defaults from Supabase in background
      fetchRemoteDefaultConfig();
    } catch (e) {
      debugPrint('[AiConfigService] Error loading local config: $e');
      _isInitialized = true;
      notifyListeners();
      fetchRemoteDefaultConfig();
    }
  }

  /// Silently fetches the server default AI fallback keys from Supabase `app_remote_config` table
  Future<void> fetchRemoteDefaultConfig({bool force = false}) async {
    if (_isFetchingRemoteDefaults && !force) return;
    _isFetchingRemoteDefaults = true;

    try {
      final url = Uri.parse('${SupabaseService.supabaseUrl}/rest/v1/app_remote_config?select=*');
      final response = await http.get(
        url,
        headers: {
          'apikey': SupabaseService.supabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseService.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        for (final row in list) {
          final key = row['key']?.toString();
          final val = row['value']?.toString() ?? '';
          if (key == 'default_gemini_api_key' && val.isNotEmpty) _defaultGeminiApiKey = val;
          if (key == 'default_nvidia_api_key' && val.isNotEmpty) _defaultNvidiaApiKey = val;
          if (key == 'default_primary_provider' && val.isNotEmpty) _defaultPrimaryProvider = val;
          if (key == 'default_secondary_provider' && val.isNotEmpty) _defaultSecondaryProvider = val;
          if (key == 'default_gemini_model' && val.isNotEmpty) _defaultGeminiModel = val;
          if (key == 'default_nvidia_model' && val.isNotEmpty) _defaultNvidiaModel = val;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AiConfigService] Error fetching remote default AI config from Supabase: $e');
    } finally {
      _isFetchingRemoteDefaults = false;
    }
  }

  /// Switch AI Mode ('default' or 'custom') with automatic safety check
  Future<void> setAiMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == 'custom') {
      // If user tries to set custom but has 0 keys entered, keep on default
      if (_geminiApiKey.trim().isEmpty && _nvidiaApiKey.trim().isEmpty) {
        _aiMode = 'default';
        await prefs.setString(_keyAiMode, 'default');
      } else {
        _aiMode = 'custom';
        await prefs.setString(_keyAiMode, 'custom');
      }
    } else {
      _aiMode = 'default';
      await prefs.setString(_keyAiMode, 'default');
    }
    _backupToCloudQuietly();
    notifyListeners();
  }

  // Set AI response language
  Future<void> setResponseLanguage(String language) async {
    _responseLanguage = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyResponseLanguage, language);
    } catch (e) {
      debugPrint('[AiConfigService] Error saving response language: $e');
    }
    notifyListeners();
  }

  // Update Primary Provider with mutual auto-switch
  void setPrimaryProvider(String provider) {
    if (provider == 'gemini') {
      _primaryProvider = 'gemini';
      _secondaryProvider = 'nvidia';
    } else if (provider == 'nvidia') {
      _primaryProvider = 'nvidia';
      _secondaryProvider = 'gemini';
    }
    notifyListeners();
  }

  // Update Secondary Provider with mutual auto-switch
  void setSecondaryProvider(String provider) {
    if (provider == 'gemini') {
      _secondaryProvider = 'gemini';
      _primaryProvider = 'nvidia';
    } else if (provider == 'nvidia') {
      _secondaryProvider = 'nvidia';
      _primaryProvider = 'gemini';
    }
    notifyListeners();
  }

  // Save all custom settings to Phone Storage & Cloud
  Future<bool> saveCustomConfiguration({
    required String geminiModel,
    required String geminiApiKey,
    required String nvidiaModel,
    required String nvidiaApiKey,
    required String primaryProvider,
    required String secondaryProvider,
    String aiMode = 'custom',
  }) async {
    try {
      _geminiModel = geminiModel.trim().isNotEmpty ? geminiModel.trim() : 'gemini-2.5-flash';
      _geminiApiKey = geminiApiKey.trim();
      _nvidiaModel = nvidiaModel.trim().isNotEmpty ? nvidiaModel.trim() : 'meta/llama-3.2-11b-vision-instruct';
      _nvidiaApiKey = nvidiaApiKey.trim();

      if (primaryProvider == 'nvidia') {
        _primaryProvider = 'nvidia';
        _secondaryProvider = 'gemini';
      } else {
        _primaryProvider = 'gemini';
        _secondaryProvider = 'nvidia';
      }

      // Automatically determine AI mode: if at least 1 key is present, set to custom; otherwise default
      if (_geminiApiKey.isNotEmpty || _nvidiaApiKey.isNotEmpty) {
        _aiMode = aiMode;
      } else {
        _aiMode = 'default';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAiMode, _aiMode);
      await prefs.setString(_keyGeminiModel, _geminiModel);
      await prefs.setString(_keyGeminiApiKey, _geminiApiKey);
      await prefs.setString(_keyNvidiaModel, _nvidiaModel);
      await prefs.setString(_keyNvidiaApiKey, _nvidiaApiKey);
      await prefs.setString(_keyPrimaryProvider, _primaryProvider);
      await prefs.setString(_keySecondaryProvider, _secondaryProvider);

      notifyListeners();

      // Automatically backup to Supabase Cloud profile
      _backupToCloudQuietly();

      return true;
    } catch (e) {
      debugPrint('[AiConfigService] Error saving custom config: $e');
      return false;
    }
  }

  /// Automatically sync AI config and keys from Supabase Cloud Profile on login / restore
  Future<void> syncFromCloudProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool changed = false;

      final cloudGeminiKey = profile['gemini_api_key']?.toString().trim();
      if (cloudGeminiKey != null && cloudGeminiKey.isNotEmpty) {
        _geminiApiKey = cloudGeminiKey;
        await prefs.setString(_keyGeminiApiKey, cloudGeminiKey);
        changed = true;
      }

      final cloudNvidiaKey = profile['nvidia_api_key']?.toString().trim();
      if (cloudNvidiaKey != null && cloudNvidiaKey.isNotEmpty) {
        _nvidiaApiKey = cloudNvidiaKey;
        await prefs.setString(_keyNvidiaApiKey, cloudNvidiaKey);
        changed = true;
      }

      // Restore AI Mode: if cloud has an active choice ('custom' or 'default'), restore it; otherwise default to 'default'
      final cloudMode = profile['ai_mode']?.toString().trim();
      final localMode = prefs.getString(_keyAiMode);
      if (cloudMode != null && (cloudMode == 'custom' || cloudMode == 'default')) {
        _aiMode = cloudMode;
        await prefs.setString(_keyAiMode, _aiMode);
        changed = true;
      } else if (localMode != null && localMode.isNotEmpty) {
        _aiMode = localMode;
      } else {
        _aiMode = 'default';
        await prefs.setString(_keyAiMode, 'default');
      }

      // Safety check: if mode is custom but user has no keys, safely fallback to default
      if (_aiMode == 'custom' && _geminiApiKey.isEmpty && _nvidiaApiKey.isEmpty) {
        _aiMode = 'default';
        await prefs.setString(_keyAiMode, 'default');
        changed = true;
      }

      final cloudGeminiModel = profile['gemini_model']?.toString().trim();
      if (cloudGeminiModel != null && cloudGeminiModel.isNotEmpty) {
        _geminiModel = cloudGeminiModel;
        await prefs.setString(_keyGeminiModel, cloudGeminiModel);
        changed = true;
      }

      final cloudNvidiaModel = profile['nvidia_model']?.toString().trim();
      if (cloudNvidiaModel != null && cloudNvidiaModel.isNotEmpty) {
        _nvidiaModel = cloudNvidiaModel;
        await prefs.setString(_keyNvidiaModel, cloudNvidiaModel);
        changed = true;
      }

      final cloudPrimary = profile['primary_provider']?.toString().trim();
      if (cloudPrimary != null && (cloudPrimary == 'gemini' || cloudPrimary == 'nvidia')) {
        _primaryProvider = cloudPrimary;
        _secondaryProvider = cloudPrimary == 'gemini' ? 'nvidia' : 'gemini';
        await prefs.setString(_keyPrimaryProvider, _primaryProvider);
        await prefs.setString(_keySecondaryProvider, _secondaryProvider);
        changed = true;
      }

      final cloudLang = profile['response_language']?.toString().trim();
      if (cloudLang != null && cloudLang.isNotEmpty) {
        _responseLanguage = cloudLang;
        await prefs.setString(_keyResponseLanguage, cloudLang);
        changed = true;
      }

      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AiConfigService] Error syncing from cloud profile: $e');
    }
  }

  /// Quietly sync AI configuration to Supabase Cloud profile
  Future<void> _backupToCloudQuietly() async {
    try {
      final supabase = SupabaseService.instance;
      if (supabase.currentUser != null) {
        await supabase.upsertProfile({
          'ai_mode': _aiMode,
          'gemini_api_key': _geminiApiKey,
          'nvidia_api_key': _nvidiaApiKey,
          'gemini_model': _geminiModel,
          'nvidia_model': _nvidiaModel,
          'primary_provider': _primaryProvider,
          'response_language': _responseLanguage,
        });
        debugPrint('[AiConfigService] AI profile (NVIDIA & Gemini) synced to Supabase successfully for user ${supabase.currentUser!.id}');
      }
    } catch (e) {
      debugPrint('[AiConfigService] Quiet cloud backup error: $e');
    }
  }

  /// Cleanly reset / clear all AI API keys and models on user logout
  Future<void> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGeminiModel);
      await prefs.remove(_keyGeminiApiKey);
      await prefs.remove(_keyNvidiaModel);
      await prefs.remove(_keyNvidiaApiKey);
      await prefs.remove(_keyPrimaryProvider);
      await prefs.remove(_keySecondaryProvider);
      await prefs.remove(_keyResponseLanguage);

      _geminiModel = 'gemini-2.5-flash';
      _geminiApiKey = '';
      _nvidiaModel = 'meta/llama-3.2-11b-vision-instruct';
      _nvidiaApiKey = '';
      _primaryProvider = 'gemini';
      _secondaryProvider = 'nvidia';
      _responseLanguage = 'English';

      notifyListeners();
    } catch (e) {
      debugPrint('[AiConfigService] Error clearing AI config: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // TEST DEFAULT SERVER AI CONFIGURATION
  // ─────────────────────────────────────────────────────────
  Future<List<ModelCheckResult>> checkDefaultServerConfiguration() async {
    // Ensure remote config is fetched
    if (_defaultGeminiApiKey.isEmpty && _defaultNvidiaApiKey.isEmpty) {
      await fetchRemoteDefaultConfig(force: true);
    }

    final results = <ModelCheckResult>[];

    // 1. Check Default Gemini Server AI starting from top of availableGeminiModels
    final geminiKey = _defaultGeminiApiKey.isNotEmpty ? _defaultGeminiApiKey : effectiveGeminiApiKey;
    final geminiModel = _defaultGeminiModel.isNotEmpty ? _defaultGeminiModel : availableGeminiModels.first;
    if (geminiKey.isNotEmpty) {
      final res = await _testGeminiApiKeyAndModel(geminiKey, geminiModel, role: 'Primary Server Cloud Engine');
      results.add(res);
    } else {
      results.add(ModelCheckResult(
        provider: 'Google Gemini (Server Cloud)',
        modelName: availableGeminiModels.first,
        isWorking: false,
        latencyMs: 0,
        message: 'Connecting to Cloud Configuration...',
      ));
    }

    // 2. Check Default NVIDIA Server AI (Backup) starting from top of availableNvidiaModels
    final nvidiaKey = _defaultNvidiaApiKey.isNotEmpty ? _defaultNvidiaApiKey : effectiveNvidiaApiKey;
    final nvidiaModel = _defaultNvidiaModel.isNotEmpty ? _defaultNvidiaModel : availableNvidiaModels.first;
    if (nvidiaKey.isNotEmpty) {
      final res = await _testNvidiaApiKeyAndModel(nvidiaKey, nvidiaModel, role: 'Backup Server Cloud Engine');
      results.add(res);
    } else {
      results.add(ModelCheckResult(
        provider: 'NVIDIA NIM (Server Cloud Backup)',
        modelName: availableNvidiaModels.first,
        isWorking: false,
        latencyMs: 0,
        message: 'Connecting to Cloud Configuration...',
      ));
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────
  // TEST CUSTOM AI CONFIGURATION (Primary & Secondary)
  // ─────────────────────────────────────────────────────────
  Future<List<ModelCheckResult>> checkCustomConfiguration({
    String? testGeminiKey,
    String? testGeminiModel,
    String? testNvidiaKey,
    String? testNvidiaModel,
    String? testPrimary,
    String? testSecondary,
  }) async {
    final gKey = (testGeminiKey ?? _geminiApiKey).trim();
    final gModel = (testGeminiModel ?? _geminiModel).trim();
    final nKey = (testNvidiaKey ?? _nvidiaApiKey).trim();
    final nModel = (testNvidiaModel ?? _nvidiaModel).trim();
    final primary = testPrimary ?? _primaryProvider;

    final results = <ModelCheckResult>[];

    // Build order based on primary/secondary
    final checkQueue = <Map<String, String>>[];
    if (primary == 'gemini') {
      checkQueue.add({'provider': 'gemini', 'role': 'Primary Engine'});
      checkQueue.add({'provider': 'nvidia', 'role': 'Secondary Engine (Failover)'});
    } else {
      checkQueue.add({'provider': 'nvidia', 'role': 'Primary Engine'});
      checkQueue.add({'provider': 'gemini', 'role': 'Secondary Engine (Failover)'});
    }

    for (final item in checkQueue) {
      if (item['provider'] == 'gemini') {
        if (gKey.isEmpty) {
          results.add(ModelCheckResult(
            provider: 'Google Gemini (${item['role']})',
            modelName: gModel,
            isWorking: false,
            latencyMs: 0,
            message: 'API Key not provided',
            errorDetails: 'Please enter a Gemini API Key to use this provider.',
          ));
        } else {
          final res = await _testGeminiApiKeyAndModel(gKey, gModel, role: item['role']!);
          results.add(res);
        }
      } else if (item['provider'] == 'nvidia') {
        if (nKey.isEmpty) {
          results.add(ModelCheckResult(
            provider: 'NVIDIA NIM (${item['role']})',
            modelName: nModel,
            isWorking: false,
            latencyMs: 0,
            message: 'API Key not provided',
            errorDetails: 'Please enter an NVIDIA API Key (nvapi-...) to use this provider.',
          ));
        } else {
          final res = await _testNvidiaApiKeyAndModel(nKey, nModel, role: item['role']!);
          results.add(res);
        }
      }
    }

    return results;
  }

  // Helper: Live Gemini Verification with model failover fallback
  Future<ModelCheckResult> _testGeminiApiKeyAndModel(String apiKey, String modelName, {required String role}) async {
    final candidateModels = <String>[modelName];
    for (final m in availableGeminiModels) {
      if (!candidateModels.contains(m)) candidateModels.add(m);
    }

    final stopwatch = Stopwatch()..start();
    String? lastError;
    int lastStatusCode = 0;

    for (final currentModel in candidateModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$currentModel:generateContent?key=$apiKey',
        );
        final body = json.encode({
          'contents': [
            {
              'parts': [
                {'text': 'Hello, reply with only the word OK.'}
              ]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 5,
          }
        });

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 12));

        lastStatusCode = response.statusCode;

        if (response.statusCode == 200) {
          stopwatch.stop();
          return ModelCheckResult(
            provider: 'Google Gemini ($role)',
            modelName: currentModel,
            isWorking: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: currentModel == modelName 
                ? 'Key validated & model responded successfully! (HTTP 200)'
                : 'Key validated via fallback model: $currentModel (HTTP 200)',
          );
        } else {
          try {
            final jsonMap = json.decode(response.body);
            if (jsonMap['error'] != null && jsonMap['error']['message'] != null) {
              lastError = jsonMap['error']['message'].toString();
            }
          } catch (_) {
            lastError = response.body;
          }

          // If key is definitely invalid (400 / 401), stop immediately (no point checking other models)
          if (response.statusCode == 400 || response.statusCode == 401) {
            final errLower = (lastError ?? '').toLowerCase();
            if (errLower.contains('api_key_invalid') || errLower.contains('invalid api key') || errLower.contains('api key not valid')) {
              stopwatch.stop();
              return ModelCheckResult(
                provider: 'Google Gemini ($role)',
                modelName: currentModel,
                isWorking: false,
                latencyMs: stopwatch.elapsedMilliseconds,
                message: 'Invalid API Key. Please check your Gemini API key from Google AI Studio.',
                errorDetails: lastError,
              );
            }
          }
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    stopwatch.stop();
    final errLower = (lastError ?? '').toLowerCase();
    final isRateLimit = lastStatusCode == 429 || errLower.contains('quota') || errLower.contains('rate limit') || errLower.contains('resource_exhausted');

    return ModelCheckResult(
      provider: 'Google Gemini ($role)',
      modelName: modelName,
      isWorking: isRateLimit, // Mark as usable if it's just a temporary rate limit
      latencyMs: stopwatch.elapsedMilliseconds,
      message: isRateLimit 
          ? 'Key is valid (currently high demand / rate-limited).'
          : 'Failed: ${lastError ?? "HTTP $lastStatusCode"}',
      errorDetails: lastError,
    );
  }

  // Helper: Live NVIDIA NIM Verification with model failover fallback
  Future<ModelCheckResult> _testNvidiaApiKeyAndModel(String apiKey, String modelName, {required String role}) async {
    final candidateModels = <String>[modelName];
    for (final m in availableNvidiaModels) {
      if (!candidateModels.contains(m)) candidateModels.add(m);
    }

    final stopwatch = Stopwatch()..start();
    String? lastError;
    int lastStatusCode = 0;

    for (final currentModel in candidateModels) {
      try {
        final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
        final body = json.encode({
          'model': currentModel,
          'messages': [
            {'role': 'user', 'content': 'Hello, reply with only the word OK.'}
          ],
          'max_tokens': 5,
          'temperature': 0.1,
        });

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 12));

        lastStatusCode = response.statusCode;

        if (response.statusCode == 200) {
          stopwatch.stop();
          return ModelCheckResult(
            provider: 'NVIDIA NIM ($role)',
            modelName: currentModel,
            isWorking: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: currentModel == modelName
                ? 'Key validated & model responded successfully! (HTTP 200)'
                : 'Key validated via fallback model: $currentModel (HTTP 200)',
          );
        } else {
          try {
            final jsonMap = json.decode(response.body);
            if (jsonMap['error'] != null) {
              if (jsonMap['error'] is Map && jsonMap['error']['message'] != null) {
                lastError = jsonMap['error']['message'].toString();
              } else {
                lastError = jsonMap['error'].toString();
              }
            }
          } catch (_) {
            lastError = response.body;
          }

          // If invalid authorization / 401, stop immediately
          if (response.statusCode == 401 || response.statusCode == 403) {
            stopwatch.stop();
            return ModelCheckResult(
              provider: 'NVIDIA NIM ($role)',
              modelName: currentModel,
              isWorking: false,
              latencyMs: stopwatch.elapsedMilliseconds,
              message: 'Invalid NVIDIA API Key. Please verify your nvapi-... key from build.nvidia.com.',
              errorDetails: lastError,
            );
          }
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    stopwatch.stop();
    final errLower = (lastError ?? '').toLowerCase();
    final isRateLimit = lastStatusCode == 429 || errLower.contains('quota') || errLower.contains('rate limit') || errLower.contains('429');

    return ModelCheckResult(
      provider: 'NVIDIA NIM ($role)',
      modelName: modelName,
      isWorking: isRateLimit,
      latencyMs: stopwatch.elapsedMilliseconds,
      message: isRateLimit
          ? 'Key is valid (currently high demand / rate-limited).'
          : 'Failed: ${lastError ?? "HTTP $lastStatusCode"}',
      errorDetails: lastError,
    );
  }

  // ─────────────────────────────────────────────────────────
  // DIRECT SCAN & PARSE VIA USER'S CONFIGURED AI ENGINES
  // ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> parseReceiptWithConfig(Uint8List imageBytes, {String mimeType = 'image/jpeg'}) async {
    final base64Image = base64Encode(imageBytes);

    if (!hasAnyApiKey) {
      return {
        'success': false,
        'error': 'No AI API Key found. Please add your Gemini or NVIDIA API Key in Settings → AI Configuration to use AI Receipt Scanning.',
        'isServerBusy': false,
      };
    }

    // Execute with Primary Provider first
    final primary = effectivePrimaryProvider;
    final secondary = effectiveSecondaryProvider;

    final primaryKey = primary == 'gemini' ? effectiveGeminiApiKey : effectiveNvidiaApiKey;
    final secondaryKey = secondary == 'gemini' ? effectiveGeminiApiKey : effectiveNvidiaApiKey;

    Map<String, dynamic>? primaryResult;
    if (primaryKey.trim().isNotEmpty) {
      debugPrint('[AiConfigService] Attempting OCR with Primary Engine: $primary');
      primaryResult = await _invokeProviderForOcr(
        provider: primary,
        base64Image: base64Image,
        mimeType: mimeType,
      );

      if (primaryResult['success'] == true) {
        return primaryResult;
      }
      debugPrint('[AiConfigService] Primary Engine ($primary) failed: ${primaryResult['error']}. Checking Secondary Engine...');
    }

    // Attempt Secondary Engine Failover
    if (secondaryKey.trim().isNotEmpty) {
      debugPrint('[AiConfigService] Failing over to Secondary Engine: $secondary...');
      var secondaryResult = await _invokeProviderForOcr(
        provider: secondary,
        base64Image: base64Image,
        mimeType: mimeType,
      );

      if (secondaryResult['success'] == true) {
        return secondaryResult;
      }

      final isBusy = isServerBusyError(primaryResult?['error']) || isServerBusyError(secondaryResult['error']);
      return {
        'success': false,
        'isServerBusy': isBusy,
        'error': isBusy
            ? 'Server AI is currently experiencing high traffic. Please try again in a moment or add your personal free API Key.'
            : 'Both Primary ($primary) and Backup ($secondary) AI engines failed.\nPrimary: ${primaryResult?['error'] ?? 'No key'}\nBackup: ${secondaryResult['error']}',
      };
    }

    final isBusy = isServerBusyError(primaryResult?['error']);
    return {
      'success': false,
      'isServerBusy': isBusy,
      'error': isBusy
          ? 'Server AI is currently experiencing high traffic. Please try again in a moment or add your personal free API Key.'
          : (primaryResult?['error'] ?? 'Configured AI provider failed. Please check your API Key in Settings.'),
    };
  }

  Future<Map<String, dynamic>> _invokeProviderForOcr({
    required String provider,
    required String base64Image,
    required String mimeType,
  }) async {
    const promptText = '''You are an expert AI Smart Financial Receipt & OCR Extraction Engine.
Analyze the provided image (which could be a store invoice, printed/handwritten restaurant receipt, grocery bill, utility bill, fuel invoice, or an Indian UPI transaction screenshot from Google Pay, PhonePe, Paytm, CRED, BHIM, Amazon Pay).

### MANDATORY EXTRACTION RULES:
1. AMOUNT (Float Number):
   - Identify the FINAL GRAND TOTAL or NET PAID AMOUNT (the actual money paid).
   - Do NOT pick up tax amounts (CGST, SGST, GST), discounts, sub-totals, or tip amounts if grand total is visible.
   - Return ONLY a numeric float value (e.g. 249.50, not "Rs. 249.50").

2. CURRENCY (ISO 3-Letter Code):
   - Extract 3-letter currency code (e.g. INR, USD, EUR, GBP).
   - If Indian Rupee symbol (₹, Rs, INR) is visible or if it's an Indian UPI payment, strictly use "INR".

3. VENDOR / MERCHANT / PAYEE:
   - Extract the business name, shop name, merchant, or individual who received the money.
   - For UPI screenshots, extract the recipient's name from "Paid to [Name]", "To: [Name]", "Transfer to [Name]".
   - If business logos or invoice headers (e.g. Starbucks, D-Mart, Reliance Fresh, Swiggy, Zomato, Blinkit, Zepto) are present, use that merchant name.

4. CATEGORY (Strict Classification):
   - MUST match EXACTLY ONE of the following valid categories:
     Shopping, Groceries, Food & dining, Transport, Bills & recharges, Transfers, Medical, Travel, Repayments, Personal, Services, Insurance, Entertainment, Gaming, Small shops, Rent, Logistics, Subscription, Investment, Fitness, Pet, Miscellaneous

5. TRANSACTION DATE (ISO 8601):
   - Extract the timestamp of the transaction in ISO 8601 string format (e.g. "2026-06-01T14:30:00.000Z").
   - If time is missing, use "T12:00:00.000Z". If year is missing, assume current year.

6. DESCRIPTION:
   - Provide a concise summary of the transaction (e.g. "Grocery items from D-Mart", "Lunch at Burger King", "UPI transfer to Ramesh", "Electricity bill").

### OUTPUT FORMAT:
Return ONLY a valid, single JSON object without markdown code blocks, backticks, or extra text.

JSON structure:
{
  "amount": 150.00,
  "currency": "INR",
  "category": "Food & dining",
  "description": "Lunch at restaurant",
  "transaction_date": "2026-06-01T13:45:00.000Z",
  "vendor": "Burger King"
}''';

    if (provider == 'gemini') {
      final key = effectiveGeminiApiKey;
      if (key.isEmpty) {
        return {'success': false, 'error': 'Gemini API Key is missing.'};
      }

      // Build model candidate list: user-selected/effective model first, then all available Gemini models
      final candidateModels = <String>[effectiveGeminiModel];
      for (final m in availableGeminiModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      String? lastGeminiError;
      for (final model in candidateModels) {
        debugPrint('[AiConfigService] Attempting Gemini OCR with model: $model');
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
          );
          final payload = {
            'contents': [
              {
                'parts': [
                  {'text': promptText},
                  {
                    'inlineData': {
                      'mimeType': mimeType,
                      'data': base64Image,
                    }
                  }
                ]
              }
            ],
            'generationConfig': {
              'maxOutputTokens': 1024,
              'temperature': 0.1,
            }
          };

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final rawText = resJson['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString() ?? '';
            final parsed = _extractJsonFromText(rawText);
            if (parsed != null) {
              debugPrint('[AiConfigService] Gemini model $model succeeded!');
              return {'success': true, 'data': parsed, 'modelUsed': model};
            }
            lastGeminiError = 'Model $model: JSON parsing failed';
          } else {
            lastGeminiError = 'Model $model: HTTP ${response.statusCode}';
            debugPrint('[AiConfigService] Gemini model $model failed (${response.statusCode}). Failing over to next Gemini model...');
          }
        } catch (e) {
          lastGeminiError = 'Model $model: $e';
          debugPrint('[AiConfigService] Gemini model $model error: $e. Failing over to next Gemini model...');
        }
      }

      return {'success': false, 'error': 'All Gemini models failed ($lastGeminiError).'};
    } else if (provider == 'nvidia') {
      final key = effectiveNvidiaApiKey;
      if (key.isEmpty) {
        return {'success': false, 'error': 'NVIDIA API Key is missing.'};
      }

      // Build model candidate list: user-selected/effective model first, then all available NVIDIA models
      final candidateModels = <String>[effectiveNvidiaModel];
      for (final m in availableNvidiaModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      String? lastNvidiaError;
      for (final model in candidateModels) {
        debugPrint('[AiConfigService] Attempting NVIDIA OCR with model: $model');
        try {
          final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
          final payload = {
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': promptText},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:$mimeType;base64,$base64Image'}
                  }
                ]
              }
            ],
            'max_tokens': 1024,
            'temperature': 0.1,
          };

          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final rawText = resJson['choices']?[0]?['message']?['content']?.toString() ?? '';
            final parsed = _extractJsonFromText(rawText);
            if (parsed != null) {
              debugPrint('[AiConfigService] NVIDIA model $model succeeded!');
              return {'success': true, 'data': parsed, 'modelUsed': model};
            }
            lastNvidiaError = 'Model $model: JSON parsing failed';
          } else {
            lastNvidiaError = 'Model $model: HTTP ${response.statusCode}';
            debugPrint('[AiConfigService] NVIDIA model $model failed (${response.statusCode}). Failing over to next NVIDIA model...');
          }
        } catch (e) {
          lastNvidiaError = 'Model $model: $e';
          debugPrint('[AiConfigService] NVIDIA model $model error: $e. Failing over to next NVIDIA model...');
        }
      }

      return {'success': false, 'error': 'All NVIDIA NIM models failed ($lastNvidiaError).'};
    }

    return {'success': false, 'error': 'Unknown provider: $provider'};
  }

  // ══════════════════════════════════════════════════════════════════════
  // VOICE & NATURAL LANGUAGE EXPENSE PARSER (Cascaded Failover)
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> parseExpenseFromNaturalText(String naturalSpeechText) async {
    if (naturalSpeechText.trim().isEmpty) {
      return {'success': false, 'error': 'No speech or text detected.'};
    }

    if (!hasAnyApiKey) {
      return {
        'success': false,
        'error': 'No API Key configured. Please add your Gemini or NVIDIA NIM API key in Settings → AI Configuration.',
        'needsConfig': true,
      };
    }

    final primary = effectivePrimaryProvider;
    final secondary = effectiveSecondaryProvider;

    final primaryKey = primary == 'gemini' ? effectiveGeminiApiKey : effectiveNvidiaApiKey;
    final secondaryKey = secondary == 'gemini' ? effectiveGeminiApiKey : effectiveNvidiaApiKey;

    Map<String, dynamic>? primaryResult;
    if (primaryKey.trim().isNotEmpty) {
      debugPrint('[AiConfigService] Attempting Voice Natural Text Parse with Primary Engine: $primary');
      primaryResult = await _invokeProviderForNaturalText(
        provider: primary,
        naturalSpeechText: naturalSpeechText,
      );

      if (primaryResult['success'] == true) {
        return primaryResult;
      }
      debugPrint('[AiConfigService] Primary Engine ($primary) failed for Voice: ${primaryResult['error']}. Checking Secondary Engine...');
    }

    // Attempt Secondary Engine Failover
    if (secondaryKey.trim().isNotEmpty) {
      debugPrint('[AiConfigService] Failing over to Secondary Engine for Voice: $secondary...');
      var secondaryResult = await _invokeProviderForNaturalText(
        provider: secondary,
        naturalSpeechText: naturalSpeechText,
      );

      if (secondaryResult['success'] == true) {
        return secondaryResult;
      }

      return {
        'success': false,
        'error': 'Both Primary ($primary) and Backup ($secondary) AI engines failed.\nPrimary: ${primaryResult?['error'] ?? 'No key'}\nBackup: ${secondaryResult['error']}',
      };
    }

    return {
      'success': false,
      'error': primaryResult?['error'] ?? 'Configured AI provider failed. Please check your API Key in Settings.',
    };
  }

  Future<Map<String, dynamic>> _invokeProviderForNaturalText({
    required String provider,
    required String naturalSpeechText,
  }) async {
    final now = DateTime.now();
    final currentDateIso = now.toIso8601String();
    final promptText = '''You are an expert Universal Multilingual Financial Expense Voice Parser and Translator.
The user speaks their expense in ANY language or mixture of languages (such as Bengali, Hindi, Hinglish, Marathi, Tamil, Telugu, Gujarati, Kannada, Malayalam, Punjabi, Urdu, English, etc.).
Your job is to deeply understand their intent, extract all expense parameters, and ALWAYS TRANSLATE & STANDARDIZE the description and merchant to clean, concise, natural ENGLISH.

Current Timestamp: $currentDateIso

USER SPOKEN TEXT:
"$naturalSpeechText"

### MANDATORY EXTRACTION & TRANSLATION RULES:
1. UNIVERSAL LANGUAGE COMPREHENSION & ENGLISH TRANSLATION:
   - Understand the input regardless of the spoken language, regional dialect, or phonetic spelling.
   - ALWAYS TRANSLATE the final "description" and "vendor" into concise, professional ENGLISH.
   - Examples:
     * Bengali: "Ami 150 takar mach kinechi" -> description: "Bought fish", vendor: "Fish Market", category: "Groceries", amount: 150.0
     * Bengali: "Dada ke 500 taka pathiyechi gpay te" -> description: "Money sent to brother via GPay", category: "Transfers", amount: 500.0
     * Hindi/Hinglish: "Dost ke sath dhabe pe 450 ka khana khaya" -> description: "Dinner with friends at Dhaba", category: "Food & dining", amount: 450.0
     * Marathi: "300 rupaye cha petrol bharla Indian Oil var" -> description: "Petrol fuel at Indian Oil", category: "Transport", amount: 300.0
     * English: "Bought groceries at DMart for 1250" -> description: "Groceries at DMart", category: "Groceries", amount: 1250.0

2. AMOUNT & NUMBER RECOGNITION (Float Number):
   - Identify the exact expense amount mentioned.
   - Accurately convert spoken numbers from any language into numeric float:
     (e.g., "eksho ponchash" -> 150, "dedh sau" -> 150, "dhai hazaar" -> 2500, "paanch sau" -> 500, "duto" -> 2, "saath" -> 60, "panjaas" -> 50, "tin hajar" -> 3000, "two thousand five hundred" -> 2500.0).
   - Return ONLY a numeric float (e.g. 150.0).

3. CURRENCY (ISO 3-Letter Code):
   - Default to "INR" (Indian Rupee) unless another currency (USD, EUR, GBP, AED, etc.) is explicitly stated. If spoken "taka" or "rupaye" or "rupees" or "bucks", use "INR".

4. CATEGORY (Strict Classification):
   - MUST match EXACTLY ONE of the following 22 valid categories:
     Shopping, Groceries, Food & dining, Transport, Bills & recharges, Transfers, Medical, Travel, Repayments, Personal, Services, Insurance, Entertainment, Gaming, Small shops, Rent, Logistics, Subscription, Investment, Fitness, Pet, Miscellaneous

5. PAYMENT METHOD:
   - Identify payment method: "UPI", "Cash", "Credit Card", "Debit Card", "Net Banking", "Wallet".
   - If user mentioned "GPay", "Google Pay", "PhonePe", "Paytm", "UPI", "scanner", "online transfer", classify as "UPI".
   - If user mentioned "cash", "nagad", "rokh", classify as "Cash". Default is "UPI".

6. TRANSACTION DATE (ISO 8601):
   - If user mentions "yesterday" / "kal" / "gatokal" / "last night" / "2 days ago" / specific day, calculate the relative date from $currentDateIso.
   - Otherwise, use $currentDateIso.

### OUTPUT FORMAT:
Return ONLY a valid, single JSON object without markdown fences, backticks, or conversational text.

JSON format:
{
  "amount": 150.0,
  "currency": "INR",
  "category": "Food & dining",
  "description": "Bought snacks and tea with friends",
  "vendor": "Tea Stall",
  "payment_method": "UPI",
  "transaction_date": "$currentDateIso"
}''';

    if (provider == 'gemini') {
      final geminiKey = effectiveGeminiApiKey;
      if (geminiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[effectiveGeminiModel];
      for (final m in availableGeminiModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      String? lastGeminiError;
      for (final model in candidateModels) {
        debugPrint('[AiConfigService] Attempting Gemini Voice parsing with model: $model');
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$geminiKey',
          );
          final payload = {
            'contents': [
              {
                'parts': [
                  {'text': promptText},
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
            }
          };

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final candidates = resJson['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final rawText = parts[0]['text']?.toString() ?? '';
                final parsed = _extractJsonFromText(rawText);
                if (parsed != null && parsed.containsKey('amount')) {
                  debugPrint('[AiConfigService] Gemini Voice model $model succeeded!');
                  return {'success': true, 'data': parsed, 'modelUsed': model};
                }
              }
            }
            lastGeminiError = 'Model $model returned unparseable content';
          } else {
            lastGeminiError = 'Model $model: HTTP ${response.statusCode}';
            debugPrint('[AiConfigService] Gemini Voice model $model failed (${response.statusCode}). Failing over to next Gemini model...');
          }
        } catch (e) {
          lastGeminiError = 'Model $model: $e';
          debugPrint('[AiConfigService] Gemini Voice model $model error: $e. Failing over to next Gemini model...');
        }
      }

      return {'success': false, 'error': 'All Gemini models failed ($lastGeminiError).'};
    }

    if (provider == 'nvidia') {
      final nvidiaKey = effectiveNvidiaApiKey;
      if (nvidiaKey.isEmpty) {
        return {'success': false, 'error': 'NVIDIA NIM API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[effectiveNvidiaModel];
      for (final m in availableNvidiaModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      String? lastNvidiaError;
      for (final model in candidateModels) {
        debugPrint('[AiConfigService] Attempting NVIDIA NIM Voice parsing with model: $model');
        try {
          final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
          final payload = {
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': promptText,
              }
            ],
            'max_tokens': 512,
            'temperature': 0.1,
          };

          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $nvidiaKey',
            },
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final rawText = resJson['choices']?[0]?['message']?['content']?.toString() ?? '';
            final parsed = _extractJsonFromText(rawText);
            if (parsed != null && parsed.containsKey('amount')) {
              debugPrint('[AiConfigService] NVIDIA Voice model $model succeeded!');
              return {'success': true, 'data': parsed, 'modelUsed': model};
            }
            lastNvidiaError = 'Model $model: JSON parsing failed';
          } else {
            lastNvidiaError = 'Model $model: HTTP ${response.statusCode}';
            debugPrint('[AiConfigService] NVIDIA Voice model $model failed (${response.statusCode}). Failing over to next model...');
          }
        } catch (e) {
          lastNvidiaError = 'Model $model: $e';
          debugPrint('[AiConfigService] NVIDIA Voice model $model error: $e. Failing over to next model...');
        }
      }

      return {'success': false, 'error': 'All NVIDIA NIM models failed ($lastNvidiaError).'};
    }

    return {'success': false, 'error': 'Unknown provider: $provider'};
  }

  // ══════════════════════════════════════════════════════════════════════
  // AI FINANCIAL ADVISOR CHATBOT (Conversational Intelligence)
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> askFinancialAdvisor({
    required String userQuestion,
    required String financialContextSummary,
    required List<Map<String, String>> chatHistory,
  }) async {
    if (userQuestion.trim().isEmpty) {
      return {'success': false, 'error': 'Please enter a question.'};
    }

    if (!hasAnyApiKey) {
      return {
        'success': false,
        'error': 'No API Key configured. Please add your Gemini or NVIDIA NIM API key in Settings → AI Configuration.',
        'needsConfig': true,
      };
    }

    final primary = effectivePrimaryProvider;
    final secondary = effectiveSecondaryProvider;

    final primaryKey = primary == 'gemini' ? effectiveGeminiApiKey : effectiveNvidiaApiKey;
    final secondaryKey = secondary == 'gemini' ? effectiveGeminiApiKey : effectiveNvidiaApiKey;

    Map<String, dynamic>? primaryResult;
    if (primaryKey.trim().isNotEmpty) {
      debugPrint('[AiConfigService] Attempting Financial Advisor Chat with Primary Engine: $primary');
      primaryResult = await _invokeProviderForFinancialAdvisor(
        provider: primary,
        userQuestion: userQuestion,
        financialContextSummary: financialContextSummary,
        chatHistory: chatHistory,
      );

      if (primaryResult['success'] == true) {
        return primaryResult;
      }
      debugPrint('[AiConfigService] Primary Engine ($primary) failed for Advisor: ${primaryResult['error']}. Checking Secondary Engine...');
    }

    // Attempt Secondary Engine Failover
    if (secondaryKey.trim().isNotEmpty) {
      debugPrint('[AiConfigService] Failing over to Secondary Engine for Advisor: $secondary...');
      var secondaryResult = await _invokeProviderForFinancialAdvisor(
        provider: secondary,
        userQuestion: userQuestion,
        financialContextSummary: financialContextSummary,
        chatHistory: chatHistory,
      );

      if (secondaryResult['success'] == true) {
        return secondaryResult;
      }

      return {
        'success': false,
        'error': 'Both Primary ($primary) and Backup ($secondary) AI engines failed.\nPrimary: ${primaryResult?['error'] ?? 'No key'}\nBackup: ${secondaryResult['error']}',
      };
    }

    return {
      'success': false,
      'error': primaryResult?['error'] ?? 'Configured AI provider failed. Please check your API Key in Settings.',
    };
  }

  Future<Map<String, dynamic>> _invokeProviderForFinancialAdvisor({
    required String provider,
    required String userQuestion,
    required String financialContextSummary,
    required List<Map<String, String>> chatHistory,
  }) async {
    final systemPrompt = '''You are GrowwAI — a smart, friendly, empathetic, and data-driven Personal Financial Advisor & Expense Specialist.
Your job is to answer the user's questions about their expenses, provide actionable saving tips, analyze category spending, identify overspending risks, and help them achieve their financial goals.

### STRICT RESPONSE LANGUAGE MANDATE:
The user has configured their preferred response language to: "$_responseLanguage".
You MUST generate your entire conversational reply strictly in $_responseLanguage.
${_responseLanguage == 'Hinglish' ? '- Use conversational, natural Hinglish (Hindi written in Latin/English alphabet, e.g. "Aapka sabse zyada kharcha food par hua hai ₹2,500.").' : ''}
${_responseLanguage == 'Hindi' ? '- Use standard Hindi in Devanagari script (e.g. "आपका इस महीने का कुल खर्च ₹12,450 है।").' : ''}
${_responseLanguage == 'Bengali' ? '- Use Bengali language in Bengali script (বাংলা).' : ''}
${_responseLanguage == 'Marathi' ? '- Use Marathi language in Devanagari script (मराठी).' : ''}
${_responseLanguage == 'Gujarati' ? '- Use Gujarati language in Gujarati script (ગુજરાતી).' : ''}
${_responseLanguage == 'Tamil' ? '- Use Tamil language in Tamil script (தமிழ்).' : ''}
${_responseLanguage == 'Telugu' ? '- Use Telugu language in Telugu script (తెలుగు).' : ''}
${_responseLanguage == 'Kannada' ? '- Use Kannada language in Kannada script (ಕನ್ನಡ).' : ''}
${_responseLanguage == 'Malayalam' ? '- Use Malayalam language in Malayalam script (മലയാളം).' : ''}
${_responseLanguage == 'Punjabi' ? '- Use Punjabi language in Gurmukhi script (ਪੰਜਾਬੀ).' : ''}

### USER'S LIVE FINANCIAL LEDGER CONTEXT:
$financialContextSummary

### CRITICAL FORMATTING & MATHEMATICAL EXPRESSION RULE:
- NEVER EVER output LaTeX formatting, MathJax, or TeX syntax (such as \$\$, \$, \\frac, \\text, \\times, \\div, \\cdot, \\left, \\right, etc.).
- ALWAYS write all calculations, quantities, and equations in simple, human-friendly plain text (e.g. "6 kg ÷ 2 = 3 kg", "₹120 / 2 = ₹60", "₹50 × 3 = ₹150").
- Use clean formatting with simple bullet points and bold numbers/amounts (e.g. **₹4,500**) only.

### AUTONOMOUS AI AGENT ACTIONS (REAL-TIME DATABASE CONTROL):
You have the autonomous power to control the user's ledger and perform real in-app database actions when the user asks you to add, record, split, or budget anything!
Whenever the user wants to execute an action, generate your conversational reply in their chosen language, AND append the exact machine-readable Action Intent JSON at the very end of your response:

1. Add an Expense (e.g., "Add ₹350 for lunch", "₹500 petrol kharcha add karo", "Dinner ₹1200"):
   Append:
   <!--ACTION_INTENT:{"type":"ADD_EXPENSE","data":{"amount":350.0,"category":"Food & Dining","description":"Lunch","paymentMethod":"UPI"}}-->
   (Standard categories: "Food & Dining", "Shopping", "Transportation", "Bills & Utilities", "Entertainment", "Healthcare", "Groceries", "General")

2. Set or Update a Category Budget (e.g., "Set Food budget to ₹5000", "Groceries budget ₹8000 kar do"):
   Append:
   <!--ACTION_INTENT:{"type":"SET_BUDGET","data":{"category":"Food & Dining","amountLimit":5000.0}}-->

3. Record Khata / Udhar (Lend or Borrow) (e.g., "Rohan ko ₹1500 udhar diya", "Priya se ₹800 lena hai", "Manoj se ₹2000 udhar liya"):
   - If user gave money (user will get back): "type": "lent"
   - If user took/borrowed money (user will give back): "type": "borrowed"
   Append:
   <!--ACTION_INTENT:{"type":"ADD_KHATA","data":{"personName":"Rohan","amount":1500.0,"type":"lent","note":"Udhar"}}-->

4. Split a Group Bill (e.g., "Split ₹1200 dinner bill with Amit and Rahul", "Room rent ₹9000 3 logo me split karo"):
   Append:
   <!--ACTION_INTENT:{"type":"ADD_SPLIT","data":{"title":"Dinner bill","totalAmount":1200.0,"paidBy":"You","participants":["You","Amit","Rahul"],"note":"Dinner split"}}-->

IMPORTANT:
- ONLY append <!--ACTION_INTENT:...--> when the user explicitly requests an action/entry/update. For general financial queries or advice, DO NOT append it.
- Always explain what you've prepared in a warm, helpful tone so the user can tap to confirm.

### GUIDELINES:
1. Always reference the user's ACTUAL expense numbers and categories from the provided context when answering.
2. Be concise, punchy, and use structured bullets and bold figures (e.g. **₹4,500**) for clarity.
3. Give concrete, realistic money-saving advice based on their highest spending categories.
4. If the user asks something outside personal finance or their expenses, politely steer the conversation back to their money management.''';

    if (provider == 'gemini') {
      final geminiKey = effectiveGeminiApiKey;
      if (geminiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[effectiveGeminiModel];
      for (final m in availableGeminiModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      // Build Gemini multi-turn contents list
      final contents = <Map<String, dynamic>>[];
      
      // First turn: system instruction & ledger context
      contents.add({
        'role': 'user',
        'parts': [{'text': '$systemPrompt\n\nInitial query: Hi GrowwAI, please be ready to analyze my expenses.'}],
      });
      contents.add({
        'role': 'model',
        'parts': [{'text': 'Hello! I have reviewed your expense ledger. How can I help you manage your money, analyze your spending, or save more today?'}],
      });

      // Add recent chat history (last 8 turns max to stay light)
      final recentHistory = chatHistory.length > 8 ? chatHistory.sublist(chatHistory.length - 8) : chatHistory;
      for (final turn in recentHistory) {
        final role = turn['role'] == 'user' ? 'user' : 'model';
        final text = turn['content'] ?? '';
        if (text.isNotEmpty) {
          contents.add({
            'role': role,
            'parts': [{'text': text}],
          });
        }
      }

      // Add current user question
      contents.add({
        'role': 'user',
        'parts': [{'text': userQuestion}],
      });

      String? lastGeminiError;
      for (final model in candidateModels) {
        debugPrint('[AiConfigService] Attempting Gemini Financial Advisor with model: $model');
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$geminiKey',
          );
          final payload = {
            'contents': contents,
            'generationConfig': {
              'temperature': 0.4,
              'maxOutputTokens': 1024,
            },
          };

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final candidates = resJson['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final replyText = parts[0]['text']?.toString() ?? '';
                if (replyText.trim().isNotEmpty) {
                  debugPrint('[AiConfigService] Gemini Financial Advisor model $model succeeded!');
                  final cleaned = sanitizeLatexMath(replyText.trim());
                  return {'success': true, 'reply': cleaned, 'modelUsed': model};
                }
              }
            }
            lastGeminiError = 'Model $model returned empty reply';
          } else {
            lastGeminiError = 'Model $model: HTTP ${response.statusCode}';
            debugPrint('[AiConfigService] Gemini Advisor model $model failed (${response.statusCode}). Failing over to next Gemini model...');
          }
        } catch (e) {
          lastGeminiError = 'Model $model: $e';
          debugPrint('[AiConfigService] Gemini Advisor model $model error: $e. Failing over to next Gemini model...');
        }
      }

      return {'success': false, 'error': 'All Gemini models failed ($lastGeminiError).'};
    }

    if (provider == 'nvidia') {
      final nvidiaKey = effectiveNvidiaApiKey;
      if (nvidiaKey.isEmpty) {
        return {'success': false, 'error': 'NVIDIA NIM API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[effectiveNvidiaModel];
      for (final m in availableNvidiaModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      final recentHistory = chatHistory.length > 8 ? chatHistory.sublist(chatHistory.length - 8) : chatHistory;
      for (final turn in recentHistory) {
        final role = turn['role'] == 'user' ? 'user' : 'assistant';
        final text = turn['content'] ?? '';
        if (text.isNotEmpty) {
          messages.add({'role': role, 'content': text});
        }
      }

      messages.add({'role': 'user', 'content': userQuestion});

      String? lastNvidiaError;
      for (final model in candidateModels) {
        debugPrint('[AiConfigService] Attempting NVIDIA NIM Advisor with model: $model');
        try {
          final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
          final payload = {
            'model': model,
            'messages': messages,
            'max_tokens': 1024,
            'temperature': 0.4,
          };

          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $nvidiaKey',
            },
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final replyText = resJson['choices']?[0]?['message']?['content']?.toString() ?? '';
            if (replyText.trim().isNotEmpty) {
              debugPrint('[AiConfigService] NVIDIA Advisor model $model succeeded!');
              final cleaned = sanitizeLatexMath(replyText.trim());
              return {'success': true, 'reply': cleaned, 'modelUsed': model};
            }
            lastNvidiaError = 'Model $model returned empty reply';
          } else {
            lastNvidiaError = 'Model $model: HTTP ${response.statusCode}';
            debugPrint('[AiConfigService] NVIDIA Advisor model $model failed (${response.statusCode}). Failing over to next model...');
          }
        } catch (e) {
          lastNvidiaError = 'Model $model: $e';
          debugPrint('[AiConfigService] NVIDIA Advisor model $model error: $e. Failing over to next model...');
        }
      }

      return {'success': false, 'error': 'All NVIDIA NIM models failed ($lastNvidiaError).'};
    }

    return {'success': false, 'error': 'Unknown provider: $provider'};
  }

  Map<String, dynamic>? _extractJsonFromText(String raw) {
    var clean = raw.trim();
    final firstCurly = clean.indexOf('{');
    final lastCurly = clean.lastIndexOf('}');
    if (firstCurly != -1 && lastCurly != -1 && lastCurly > firstCurly) {
      clean = clean.substring(firstCurly, lastCurly + 1);
    }
    try {
      final decoded = json.decode(clean);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // 4. SABJI MANDI / MARKET VOICE UNIT PRICE PARSER
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> parseMarketVoicePrice(
    String naturalSpeechText, {
    String spokenLanguage = 'English',
  }) async {
    if (!hasAnyApiKey) {
      return {
        'success': false,
        'error': 'API Key is missing. Please configure your Gemini API Key in Settings → AI Configuration.',
      };
    }

    final primary = effectivePrimaryProvider;
    final secondary = effectiveSecondaryProvider;

    final primaryResult = await _invokeProviderForMarketVoice(
      provider: primary,
      naturalSpeechText: naturalSpeechText,
      spokenLanguage: spokenLanguage,
    );

    if (primaryResult['success'] == true) {
      return primaryResult;
    }

    if (hasSecondaryConfig && secondary != primary) {
      debugPrint('[AiConfigService] Primary ($primary) failed for Market Voice. Failing over to Backup ($secondary)...');
      final secondaryResult = await _invokeProviderForMarketVoice(
        provider: secondary,
        naturalSpeechText: naturalSpeechText,
        spokenLanguage: spokenLanguage,
      );

      if (secondaryResult['success'] == true) {
        return secondaryResult;
      }

      return {
        'success': false,
        'error': 'Both Primary ($primary) and Backup ($secondary) AI engines failed.\nPrimary: ${primaryResult['error'] ?? 'No key'}\nBackup: ${secondaryResult['error']}',
      };
    }

    return {
      'success': false,
      'error': primaryResult['error'] ?? 'Configured AI provider failed. Please check your API Key in Settings.',
    };
  }

  Future<Map<String, dynamic>> _invokeProviderForMarketVoice({
    required String provider,
    required String naturalSpeechText,
    String spokenLanguage = 'English',
  }) async {
    final promptText = '''You are an expert Local Market, Sabji Mandi, and Grocery Rate Analyzer.
The user speaks items and their rates at a local market or grocery store in $spokenLanguage or any mix of Indian regional languages (such as Bengali / বাংলা, Hindi / हिन्दी, Hinglish, Marathi, Tamil, Telugu, Gujarati, English, etc.).

CRITICAL REGIONAL TRADE KNOWLEDGE:
- Bengali:
  - Numbers: "এক (1)", "দুই / দুটো (2)", "তিন / তিনটে (3)", "চার / চারটে (4)", "পাঁচ (5)", "দশ (10)", "কুড়ি (20)", "তিরিশ (30)", "চল্লিশ (40)", "পঞ্চাশ (50)", "একশো (100)"
  - Fractions: "এক পোয়া (250 grams)", "আধ কেজি / আধা কিলো (500 grams)", "দেড় কেজি (1.5 kg)", "আড়াই কেজি (2.5 kg)", "পৌনে এক কেজি (750 grams)"
  - Common items: "আলু (Potato)", "পেঁয়াজ (Onion)", "রসুন (Garlic)", "আদা (Ginger)", "টমেটো (Tomato)", "পটল (Pointed Gourd)", "বেগুন (Brinjal / Eggplant)", "কাঁচা লঙ্কা (Green Chilli)", "ডিম (Eggs)", "মাছ (Fish)", "মাংস (Chicken / Meat)", "তেল (Oil)", "চাল (Rice)", "ডাল (Lentils)", "দুধ (Milk)", "চিনি (Sugar)", "ফুলকপি (Cauliflower)", "বাঁধাকপি (Cabbage)", "গাজর (Carrot)", "শসা (Cucumber)"
  - Units & Money: "টাকা (Taka / Rs)", "কেজি / কিলো (kg)", "গ্রাম (g)", "লিটার (Litre)", "ডজন (Dozen)", "পিস / টা (piece)"
- Hindi:
  - Numbers & Fractions: "एक (1)", "दो (2)", "तीन (3)", "चार (4)", "पाव / एक पाव (250g)", "आधा किलो (500g)", "डेढ़ किलो (1.5kg)", "ढाई किलो (2.5kg)", "सवा किलो (1.25kg)"
  - Common items: "आलू (Potato)", "प्याज (Onion)", "लहसुन (Garlic)", "अदरक (Ginger)", "टमाटर (Tomato)", "बैंगन (Brinjal)", "हरी मिर्च (Green Chilli)", "अंडे (Eggs)", "तेल (Oil)", "चावल (Rice)", "दाल (Lentils)", "दूध (Milk)"
  - Units & Money: "रुपये / रु (Rupees)", "किलो (kg)", "ग्राम (g)", "लीटर (Litre)", "दर्जन (Dozen)", "पीस (piece)"

Examples:
- "Aloo 30 rupaye kilo, pyaaz 50 rupaye 2 kilo, tamatar 30 rupaye 500 gram, adrak 20 rupaye 100 gram, sarson tel 160 rupaye litre"
- "Ek kg begun 60 taka, potol 40 taka kilo, duto dim 16 taka, ek poa kacha lonka 15 taka, adha kilo aloo 15 taka"
- "Apple 180 per kg, banana 50 dozen, milk 64 per litre"

Your job:
1. Identify all distinct items mentioned.
2. Standardize the item name with clear English & Regional naming (e.g. "Potato (Aloo / আলু)", "Onion (Pyaaz / পেঁয়াজ)", "Tomato (Tamatar / টমেটো)", "Pointed Gourd (Potol / পটল)", "Brinjal (Begun / বেগুন)", "Ginger (Adrak / আদা)", "Mustard Oil", "Egg (Dim / अंडा)", "Apple", "Banana").
3. Extract base quantity (e.g. 1.0, 2.0, 500.0, 100.0, 250.0), base unit ("kg", "g", "litre", "ml", "dozen", "piece"), and base price (INR number).
4. Compute standard rate per standard unit (e.g. Rate per 1 kg for weight, Rate per 1 litre for volume, Rate per 1 dozen, Rate per 1 piece).
5. For weight items ("kg" or "g"), generate:
   - quantity_breakdown: [
       {"quantity": "50g", "price": calculated_num},
       {"quantity": "100g", "price": calculated_num},
       {"quantity": "250g", "price": calculated_num},
       {"quantity": "500g", "price": calculated_num},
       {"quantity": "1 kg", "price": calculated_num},
       {"quantity": "2 kg", "price": calculated_num},
       {"quantity": "5 kg", "price": calculated_num}
     ]
   - budget_breakdown: [
       {"budget": "₹10", "quantity": "e.g. 333g"},
       {"budget": "₹20", "quantity": "e.g. 667g"},
       {"budget": "₹50", "quantity": "e.g. 1.67 kg"},
       {"budget": "₹100", "quantity": "e.g. 3.33 kg"}
     ]
6. For liquid items ("litre" or "ml"), generate breakdowns for 100ml, 250ml, 500ml, 1L, 2L and budget breakdowns for ₹10, ₹20, ₹50, ₹100.
7. For dozen/piece items, generate breakdowns for 1 pc, 2 pcs, 4 pcs, 6 pcs (half dozen), 12 pcs (1 dozen).

USER SPOKEN INPUT:
"$naturalSpeechText"

Return ONLY a valid single JSON object without markdown fences, backticks, or other text:
{
  "items": [
    {
      "item_name": "Potato (Aloo)",
      "category": "Vegetables",
      "base_quantity": 1.0,
      "base_unit": "kg",
      "base_price": 30.0,
      "rate_per_standard_unit": 30.0,
      "standard_unit": "kg",
      "quantity_breakdown": [
        {"quantity": "100g", "price": 3.0},
        {"quantity": "250g", "price": 7.5},
        {"quantity": "500g", "price": 15.0},
        {"quantity": "1 kg", "price": 30.0},
        {"quantity": "2 kg", "price": 60.0},
        {"quantity": "5 kg", "price": 150.0}
      ],
      "budget_breakdown": [
        {"budget": "₹10", "quantity": "333g"},
        {"budget": "₹20", "quantity": "667g"},
        {"budget": "₹50", "quantity": "1.67 kg"},
        {"budget": "₹100", "quantity": "3.33 kg"}
      ]
    }
  ],
  "market_summary": "Extracted items summary..."
}''';

    if (provider == 'gemini') {
      final geminiKey = effectiveGeminiApiKey;
      if (geminiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[effectiveGeminiModel];
      for (final m in availableGeminiModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      String? lastGeminiError;
      for (final model in candidateModels) {
        debugPrint('[AiConfigService] Attempting Gemini Market Voice with model: $model');
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$geminiKey',
          );
          final payload = {
            'contents': [
              {
                'parts': [
                  {'text': promptText},
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
            }
          };

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final candidates = resJson['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final rawText = parts[0]['text']?.toString() ?? '';
                final parsed = _extractJsonFromText(rawText);
                if (parsed != null && parsed.containsKey('items')) {
                  debugPrint('[AiConfigService] Gemini Market Voice model $model succeeded!');
                  return {'success': true, 'data': parsed, 'modelUsed': model};
                }
              }
            }
            lastGeminiError = 'Model $model returned unparseable content';
          } else {
            lastGeminiError = 'Model $model: HTTP ${response.statusCode}';
          }
        } catch (e) {
          lastGeminiError = 'Model $model: $e';
        }
      }

      return {'success': false, 'error': 'All Gemini models failed ($lastGeminiError).'};
    }

    if (provider == 'nvidia') {
      final nvidiaKey = effectiveNvidiaApiKey;
      if (nvidiaKey.isEmpty) {
        return {'success': false, 'error': 'NVIDIA NIM API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[effectiveNvidiaModel];
      for (final m in availableNvidiaModels) {
        if (!candidateModels.contains(m)) {
          candidateModels.add(m);
        }
      }

      String? lastNvidiaError;
      for (final model in candidateModels) {
        try {
          final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
          final payload = {
            'model': model,
            'messages': [
              {'role': 'system', 'content': 'You are an accurate local market unit price analyzer. Return raw JSON only.'},
              {'role': 'user', 'content': promptText},
            ],
            'temperature': 0.1,
            'max_tokens': 2048,
          };

          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $nvidiaKey',
            },
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final rawText = resJson['choices']?[0]?['message']?['content']?.toString() ?? '';
            final parsed = _extractJsonFromText(rawText);
            if (parsed != null && parsed.containsKey('items')) {
              return {'success': true, 'data': parsed, 'modelUsed': model};
            }
            lastNvidiaError = 'Model $model returned invalid JSON';
          } else {
            lastNvidiaError = 'Model $model: HTTP ${response.statusCode}';
          }
        } catch (e) {
          lastNvidiaError = 'Model $model: $e';
        }
      }

      return {'success': false, 'error': 'All NVIDIA NIM models failed ($lastNvidiaError).'};
    }

    return {'success': false, 'error': 'Unknown provider: $provider'};
  }

  /// Helper to check if an AI failure error was due to server busy / rate limit / quota exhaustion
  bool isServerBusyError(dynamic error) {
    if (error == null) return false;
    final str = error.toString().toLowerCase();
    return str.contains('429') ||
        str.contains('quota') ||
        str.contains('rate limit') ||
        str.contains('resource_exhausted') ||
        str.contains('overloaded') ||
        str.contains('service unavailable') ||
        str.contains('503') ||
        str.contains('all gemini models failed') ||
        str.contains('all nvidia nim models failed') ||
        str.contains('both primary');
  }

  /// Sanitizes any raw LaTeX math artifacts (e.g. \frac, \text, $$, $) into clean, human-readable plain text
  static String sanitizeLatexMath(String text) {
    if (text.isEmpty) return text;

    String cleaned = text;

    // 1. Replace \text{...} with inner content
    cleaned = cleaned.replaceAllMapped(RegExp(r'\\text\{([^}]*)\}'), (m) => m.group(1) ?? '');

    // 2. Replace \frac{A}{B} with A / B (up to 4 passes for nested)
    for (int i = 0; i < 4; i++) {
      cleaned = cleaned.replaceAllMapped(RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'), (m) {
        final num = m.group(1)?.trim() ?? '';
        final den = m.group(2)?.trim() ?? '';
        return '$num / $den';
      });
    }

    // 3. Replace common math symbols & commands
    cleaned = cleaned.replaceAll(r'\times', '×');
    cleaned = cleaned.replaceAll(r'\cdot', '×');
    cleaned = cleaned.replaceAll(r'\div', '÷');
    cleaned = cleaned.replaceAll(r'\pm', '±');
    cleaned = cleaned.replaceAll(r'\approx', '≈');
    cleaned = cleaned.replaceAll(r'\le', '≤');
    cleaned = cleaned.replaceAll(r'\ge', '≥');
    cleaned = cleaned.replaceAll(r'\neq', '≠');
    cleaned = cleaned.replaceAll(r'\left', '');
    cleaned = cleaned.replaceAll(r'\right', '');

    // 4. Remove $$ and $ math block delimiters
    cleaned = cleaned.replaceAll(RegExp(r'\$\$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\\)\$'), '');

    // 5. Clean up any double spaces resulting from replacements
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');

    return cleaned.trim();
  }
}
