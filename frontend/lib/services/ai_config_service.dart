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

  // Supported Gemini Models (Latest Gemini 3.x / 2.5 / Flash Vision series)
  static const List<String> availableGeminiModels = [
    'gemini-2.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3-flash-preview',
    'gemini-3.8-flash',
    'gemini-3.5-flash',
    'gemini-3.1-pro-preview',
    'gemini-3.1-flash-lite',
    'gemini-2.5-pro',
    'gemini-flash-latest',
    'gemini-pro-latest',
    'gemini-2.0-flash',
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

  bool _isInitialized = false;

  // Getters
  String get geminiModel => _geminiModel;
  String get geminiApiKey => _geminiApiKey;
  String get nvidiaModel => _nvidiaModel;
  String get nvidiaApiKey => _nvidiaApiKey;
  String get primaryProvider => _primaryProvider;
  String get secondaryProvider => _secondaryProvider;
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

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _geminiModel = prefs.getString(_keyGeminiModel) ?? 'gemini-2.0-flash';
      _geminiApiKey = prefs.getString(_keyGeminiApiKey) ?? '';
      _nvidiaModel = prefs.getString(_keyNvidiaModel) ?? 'meta/llama-3.2-11b-vision-instruct';
      _nvidiaApiKey = prefs.getString(_keyNvidiaApiKey) ?? '';
      _primaryProvider = prefs.getString(_keyPrimaryProvider) ?? 'gemini';
      _secondaryProvider = prefs.getString(_keySecondaryProvider) ?? 'nvidia';

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
      return true;
    } catch (e) {
      debugPrint('[AiConfigService] Error saving custom config: $e');
      return false;
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
        return {'success': false, 'error': 'NVIDIA API Key is missing. Please add it in Settings → AI Configuration.'};
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
