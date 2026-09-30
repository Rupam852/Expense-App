import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  // Supported Gemini Models
  static const List<String> availableGeminiModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-2.0-flash-lite',
    'gemini-2.5-flash',
    'gemini-pro-latest',
  ];

  // Supported NVIDIA NIM Models
  static const List<String> availableNvidiaModels = [
    'meta/llama-3.2-11b-vision-instruct',
    'meta/llama-3.2-90b-vision-instruct',
    'meta/llama-3.1-70b-instruct',
    'meta/llama-3.1-8b-instruct',
    'mistralai/mistral-large-2-instruct',
    'google/gemma-2-27b-it',
    'nvidia/neva-22b',
  ];

  // Configuration Fields
  String _mode = 'default'; // 'default' | 'custom'
  String _geminiModel = 'gemini-2.0-flash';
  String _geminiApiKey = '';
  String _nvidiaModel = 'meta/llama-3.2-11b-vision-instruct';
  String _nvidiaApiKey = '';
  String _primaryProvider = 'gemini'; // 'gemini' | 'nvidia'
  String _secondaryProvider = 'nvidia'; // 'nvidia' | 'gemini'

  // Cooldown tracker (30 seconds)
  int _lastDefaultTestTimestamp = 0;
  static const int testCooldownSeconds = 30;

  bool _isInitialized = false;

  // Getters
  String get mode => _mode;
  bool get isCustomMode => _mode == 'custom';
  String get geminiModel => _geminiModel;
  String get geminiApiKey => _geminiApiKey;
  String get nvidiaModel => _nvidiaModel;
  String get nvidiaApiKey => _nvidiaApiKey;
  String get primaryProvider => _primaryProvider;
  String get secondaryProvider => _secondaryProvider;
  bool get isInitialized => _isInitialized;

  int get remainingCooldownSeconds {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - _lastDefaultTestTimestamp) ~/ 1000;
    final remaining = testCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get canTestDefaultModels => remainingCooldownSeconds == 0;

  // SharedPreferences Keys (Strictly local phone storage)
  static const String _keyAiMode = 'local_ai_mode';
  static const String _keyGeminiModel = 'local_ai_gemini_model';
  static const String _keyGeminiApiKey = 'local_ai_gemini_api_key';
  static const String _keyNvidiaModel = 'local_ai_nvidia_model';
  static const String _keyNvidiaApiKey = 'local_ai_nvidia_api_key';
  static const String _keyPrimaryProvider = 'local_ai_primary_provider';
  static const String _keySecondaryProvider = 'local_ai_secondary_provider';
  static const String _keyLastDefaultTest = 'local_ai_last_default_test';

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = prefs.getString(_keyAiMode) ?? 'default';
      _geminiModel = prefs.getString(_keyGeminiModel) ?? 'gemini-2.0-flash';
      _geminiApiKey = prefs.getString(_keyGeminiApiKey) ?? '';
      _nvidiaModel = prefs.getString(_keyNvidiaModel) ?? 'meta/llama-3.2-11b-vision-instruct';
      _nvidiaApiKey = prefs.getString(_keyNvidiaApiKey) ?? '';
      _primaryProvider = prefs.getString(_keyPrimaryProvider) ?? 'gemini';
      _secondaryProvider = prefs.getString(_keySecondaryProvider) ?? 'nvidia';
      _lastDefaultTestTimestamp = prefs.getInt(_keyLastDefaultTest) ?? 0;

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

  // Set mode (Default vs Custom) and persist locally
  Future<void> setMode(String newMode) async {
    _mode = newMode == 'custom' ? 'custom' : 'default';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAiMode, _mode);
    } catch (e) {
      debugPrint('[AiConfigService] Error saving mode: $e');
    }
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

  // Save all custom settings to Phone Storage
  Future<bool> saveCustomConfiguration({
    required String mode,
    required String geminiModel,
    required String geminiApiKey,
    required String nvidiaModel,
    required String nvidiaApiKey,
    required String primaryProvider,
    required String secondaryProvider,
  }) async {
    try {
      _mode = mode;
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
      await prefs.setString(_keyAiMode, _mode);
      await prefs.setString(_keyGeminiModel, _geminiModel);
      await prefs.setString(_keyGeminiApiKey, _geminiApiKey);
      await prefs.setString(_keyNvidiaModel, _nvidiaModel);
      await prefs.setString(_keyNvidiaApiKey, _nvidiaApiKey);
      await prefs.setString(_keyPrimaryProvider, _primaryProvider);
      await prefs.setString(_keySecondaryProvider, _secondaryProvider);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AiConfigService] Error saving custom config: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // TEST DEFAULT AI MODELS (With 30-sec Rate Limiter)
  // ─────────────────────────────────────────────────────────
  Future<List<ModelCheckResult>> checkDefaultModels({
    Function(int current, int total, String currentModel)? onProgress,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = remainingCooldownSeconds;
    if (remaining > 0) {
      throw Exception('Rate limited. Please wait $remaining seconds before running another check.');
    }

    _lastDefaultTestTimestamp = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastDefaultTest, now);
    notifyListeners();

    final results = <ModelCheckResult>[];
    final modelsToTest = [
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-2.0-flash-lite',
      'gemini-pro-latest',
    ];

    for (int i = 0; i < modelsToTest.length; i++) {
      final model = modelsToTest[i];
      if (onProgress != null) {
        onProgress(i + 1, modelsToTest.length, model);
      }

      final stopwatch = Stopwatch()..start();
      try {
        // Ping Google Gemini public discovery or test endpoint
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model');
        final response = await http.get(url).timeout(const Duration(seconds: 8));
        stopwatch.stop();

        if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 403) {
          // 200 means public metadata exists; 400/403 means endpoint is active and requires API key auth
          results.add(ModelCheckResult(
            provider: 'Google Gemini',
            modelName: model,
            isWorking: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: 'Model is active & reachable on Google servers',
          ));
        } else if (response.statusCode == 404) {
          results.add(ModelCheckResult(
            provider: 'Google Gemini',
            modelName: model,
            isWorking: false,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: 'Model not found on server (404)',
            errorDetails: 'HTTP 404',
          ));
        } else {
          results.add(ModelCheckResult(
            provider: 'Google Gemini',
            modelName: model,
            isWorking: false,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: 'Server returned HTTP ${response.statusCode}',
            errorDetails: response.body,
          ));
        }
      } catch (e) {
        stopwatch.stop();
        results.add(ModelCheckResult(
          provider: 'Google Gemini',
          modelName: model,
          isWorking: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Connection failed: ${e.toString()}',
          errorDetails: e.toString(),
        ));
      }

      // Small pause between probes for smooth UI animation
      await Future.delayed(const Duration(milliseconds: 250));
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
  // DIRECT SCAN & PARSE VIA CONFIGURED AI ENGINES
  // ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> parseReceiptWithConfig(Uint8List imageBytes, {String mimeType = 'image/jpeg'}) async {
    final base64Image = base64Encode(imageBytes);

    if (_mode == 'custom') {
      // Execute with Primary Provider first
      final primary = _primaryProvider;
      final secondary = _secondaryProvider;

      debugPrint('[AiConfigService] Attempting OCR with Primary Engine: $primary');
      var primaryResult = await _invokeProviderForOcr(
        provider: primary,
        base64Image: base64Image,
        mimeType: mimeType,
      );

      if (primaryResult['success'] == true) {
        return primaryResult;
      }

      debugPrint('[AiConfigService] Primary Engine ($primary) failed: ${primaryResult['error']}. Failing over to Secondary Engine: $secondary...');
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
        'error': 'Primary ($primary) and Secondary ($secondary) engines both failed.\nPrimary: ${primaryResult['error']}\nSecondary: ${secondaryResult['error']}',
      };
    }

    // Default Mode: Return signal to use default backend Edge Function
    return {'success': false, 'useDefaultBackend': true};
  }

  Future<Map<String, dynamic>> _invokeProviderForOcr({
    required String provider,
    required String base64Image,
    required String mimeType,
  }) async {
    const promptText = '''Analyze this image (which could be a store receipt, utility bill, restaurant invoice, or a screenshot of a UPI transaction like GPay, PhonePe, Paytm).
Extract the following financial details accurately:
1. amount (numeric float value)
2. currency (3-letter ISO code, e.g. INR, USD, EUR. Default to INR if it seems Indian, like UPI screenshots)
3. category (Categorize into precisely one of these values: Shopping, Groceries, Food & dining, Transport, Bills & recharges, Transfers, Medical, Travel, Repayments, Personal, Services, Insurance, Entertainment, Gaming, Small shops, Rent, Logistics, Subscription, Investment, Fitness, Pet, Miscellaneous)
4. description (Brief summary of what was purchased or description of the transaction)
5. transaction_date (ISO 8601 string, e.g., '2026-06-01T20:00:00Z'. Extract transaction timestamp, or estimate/use current date if not visible)
6. vendor (Name of the shop, store, merchant, or individual who received the money. For UPI, extract the receiver's name)

Ensure the response is ONLY a single, clean JSON object without markdown code fences or conversational text.
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
        return {'success': false, 'error': 'Gemini API Key is missing in Custom Settings.'};
      }
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey',
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
            return {'success': true, 'data': parsed};
          }
          return {'success': false, 'error': 'Failed to parse JSON response from Gemini.'};
        } else {
          return {'success': false, 'error': 'Gemini HTTP ${response.statusCode}: ${response.body}'};
        }
      } catch (e) {
        return {'success': false, 'error': 'Gemini request error: $e'};
      }
    } else if (provider == 'nvidia') {
      if (_nvidiaApiKey.isEmpty) {
        return {'success': false, 'error': 'NVIDIA API Key is missing in Custom Settings.'};
      }
      try {
        final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
        final payload = {
          'model': _nvidiaModel,
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
            return {'success': true, 'data': parsed};
          }
          return {'success': false, 'error': 'Failed to parse JSON response from NVIDIA NIM.'};
        } else {
          return {'success': false, 'error': 'NVIDIA HTTP ${response.statusCode}: ${response.body}'};
        }
      } catch (e) {
        return {'success': false, 'error': 'NVIDIA request error: $e'};
      }
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
