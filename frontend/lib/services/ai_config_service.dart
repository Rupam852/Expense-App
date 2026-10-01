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
  String _geminiModel = 'gemini-2.5-flash';
  String _geminiApiKey = '';
  String _nvidiaModel = 'meta/llama-3.2-11b-vision-instruct';
  String _nvidiaApiKey = '';
  String _primaryProvider = 'gemini'; // 'gemini' | 'nvidia'
  String _secondaryProvider = 'nvidia'; // 'nvidia' | 'gemini'
  String _responseLanguage = 'English'; // Default English

  bool _isInitialized = false;

  // Getters
  String get geminiModel => _geminiModel;
  String get geminiApiKey => _geminiApiKey;
  String get nvidiaModel => _nvidiaModel;
  String get nvidiaApiKey => _nvidiaApiKey;
  String get primaryProvider => _primaryProvider;
  String get secondaryProvider => _secondaryProvider;
  String get responseLanguage => _responseLanguage;
  bool get isInitialized => _isInitialized;

  bool get hasAnyApiKey => _geminiApiKey.trim().isNotEmpty || _nvidiaApiKey.trim().isNotEmpty;
  bool get hasPrimaryApiKey => _primaryProvider == 'gemini' 
      ? _geminiApiKey.trim().isNotEmpty 
      : _nvidiaApiKey.trim().isNotEmpty;

  // SharedPreferences Keys (Strictly local phone storage)
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
      _geminiModel = prefs.getString(_keyGeminiModel) ?? 'gemini-2.0-flash';
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
    } catch (e) {
      debugPrint('[AiConfigService] Error loading local config: $e');
      _isInitialized = true;
      notifyListeners();
    }
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
  }) async {
    try {
      _geminiModel = geminiModel.trim().isNotEmpty ? geminiModel.trim() : 'gemini-2.0-flash';
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

      final prefs = await SharedPreferences.getInstance();
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
          'gemini_api_key': _geminiApiKey,
          'nvidia_api_key': _nvidiaApiKey,
          'gemini_model': _geminiModel,
          'nvidia_model': _nvidiaModel,
          'primary_provider': _primaryProvider,
          'response_language': _responseLanguage,
        });
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

  // Helper: Live Gemini Verification
  Future<ModelCheckResult> _testGeminiApiKeyAndModel(String apiKey, String modelName, {required String role}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
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

      stopwatch.stop();

      if (response.statusCode == 200) {
        return ModelCheckResult(
          provider: 'Google Gemini ($role)',
          modelName: modelName,
          isWorking: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Key validated & model responded successfully!',
        );
      } else {
        String errorDesc = 'Error HTTP ${response.statusCode}';
        try {
          final jsonMap = json.decode(response.body);
          if (jsonMap['error'] != null && jsonMap['error']['message'] != null) {
            errorDesc = jsonMap['error']['message'].toString();
          }
        } catch (_) {
          errorDesc = response.body;
        }

        return ModelCheckResult(
          provider: 'Google Gemini ($role)',
          modelName: modelName,
          isWorking: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Failed: $errorDesc',
          errorDetails: response.body,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ModelCheckResult(
        provider: 'Google Gemini ($role)',
        modelName: modelName,
        isWorking: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Network / Connection error: $e',
        errorDetails: e.toString(),
      );
    }
  }

  // Helper: Live NVIDIA NIM Verification
  Future<ModelCheckResult> _testNvidiaApiKeyAndModel(String apiKey, String modelName, {required String role}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
      final body = json.encode({
        'model': modelName,
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

      stopwatch.stop();

      if (response.statusCode == 200) {
        return ModelCheckResult(
          provider: 'NVIDIA NIM ($role)',
          modelName: modelName,
          isWorking: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Key validated & model responded successfully!',
        );
      } else {
        String errorDesc = 'Error HTTP ${response.statusCode}';
        try {
          final jsonMap = json.decode(response.body);
          if (jsonMap['error'] != null) {
            if (jsonMap['error'] is Map && jsonMap['error']['message'] != null) {
              errorDesc = jsonMap['error']['message'].toString();
            } else {
              errorDesc = jsonMap['error'].toString();
            }
          }
        } catch (_) {
          errorDesc = response.body;
        }

        return ModelCheckResult(
          provider: 'NVIDIA NIM ($role)',
          modelName: modelName,
          isWorking: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Failed: $errorDesc',
          errorDetails: response.body,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ModelCheckResult(
        provider: 'NVIDIA NIM ($role)',
        modelName: modelName,
        isWorking: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Network / Connection error: $e',
        errorDetails: e.toString(),
      );
    }
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
      };
    }

    // Execute with Primary Provider first
    final primary = _primaryProvider;
    final secondary = _secondaryProvider;

    final primaryKey = primary == 'gemini' ? _geminiApiKey : _nvidiaApiKey;
    final secondaryKey = secondary == 'gemini' ? _geminiApiKey : _nvidiaApiKey;

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
      if (_geminiApiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      // Build model candidate list: user-selected model first, then all available Gemini models
      final candidateModels = <String>[_geminiModel];
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
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey',
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
      if (_nvidiaApiKey.isEmpty) {
        return {'success': false, 'error': 'NVIDIA API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      // Build model candidate list: user-selected model first, then all available NVIDIA models
      final candidateModels = <String>[_nvidiaModel];
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
              'Authorization': 'Bearer $_nvidiaApiKey',
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

    final primary = _primaryProvider;
    final secondary = _secondaryProvider;

    final primaryKey = primary == 'gemini' ? _geminiApiKey : _nvidiaApiKey;
    final secondaryKey = secondary == 'gemini' ? _geminiApiKey : _nvidiaApiKey;

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
      if (_geminiApiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[_geminiModel];
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
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey',
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
      if (_nvidiaApiKey.isEmpty) {
        return {'success': false, 'error': 'NVIDIA NIM API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[_nvidiaModel];
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
              'Authorization': 'Bearer $_nvidiaApiKey',
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

    final primary = _primaryProvider;
    final secondary = _secondaryProvider;

    final primaryKey = primary == 'gemini' ? _geminiApiKey : _nvidiaApiKey;
    final secondaryKey = secondary == 'gemini' ? _geminiApiKey : _nvidiaApiKey;

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

### GUIDELINES:
1. Always reference the user's ACTUAL expense numbers and categories from the provided context when answering.
2. Be concise, punchy, and use structured bullets and bold figures (e.g. **₹4,500**) for clarity.
3. Give concrete, realistic money-saving advice based on their highest spending categories.
4. If the user asks something outside personal finance or their expenses, politely steer the conversation back to their money management.''';

    if (provider == 'gemini') {
      if (_geminiApiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[_geminiModel];
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
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey',
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
                  return {'success': true, 'reply': replyText.trim(), 'modelUsed': model};
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
      if (_nvidiaApiKey.isEmpty) {
        return {'success': false, 'error': 'NVIDIA NIM API Key is missing. Please add it in Settings → AI Configuration.'};
      }

      final candidateModels = <String>[_nvidiaModel];
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
              'Authorization': 'Bearer $_nvidiaApiKey',
            },
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final resJson = json.decode(response.body);
            final replyText = resJson['choices']?[0]?['message']?['content']?.toString() ?? '';
            if (replyText.trim().isNotEmpty) {
              debugPrint('[AiConfigService] NVIDIA Advisor model $model succeeded!');
              return {'success': true, 'reply': replyText.trim(), 'modelUsed': model};
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
}
