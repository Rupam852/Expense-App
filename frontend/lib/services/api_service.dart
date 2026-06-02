import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Standard cloud server URL deployed on Render
  static const String baseUrl = 'https://expense-tracker-backend-5pc1.onrender.com';
  
  static final ApiService instance = ApiService._init();
  final _secureStorage = const FlutterSecureStorage();

  ApiService._init();

  // Retrieve cached JWT token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  // Save JWT token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
  }

  // Clear JWT token (Sign out)
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: 'jwt_token');
  }

  // Get common headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Auth Register
  Future<Map<String, dynamic>> register({
    required String email,
    String? password,
    String? name,
    String? photoUrl,
    String? googleId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          if (password != null) 'password': password,
          if (name != null) 'name': name,
          if (photoUrl != null) 'photo_url': photoUrl,
          if (googleId != null) 'google_id': googleId,
        }),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 201) {
        final token = decoded['token'];
        if (token != null) {
          await saveToken(token);
        }
        return {'success': true, 'user': decoded['user']};
      }
      return {'success': false, 'error': decoded['error'] ?? 'Registration failed.'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to backend server: $e'};
    }
  }

  // 2. Auth Login (Manual + Google Fallback)
  Future<Map<String, dynamic>> login({
    required String email,
    String? password,
    String? googleId,
    String? name,
    String? photoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          if (password != null) 'password': password,
          if (googleId != null) 'google_id': googleId,
          if (name != null) 'name': name,
          if (photoUrl != null) 'photo_url': photoUrl,
        }),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 200) {
        final token = decoded['token'];
        if (token != null) {
          await saveToken(token);
        }
        return {'success': true, 'user': decoded['user']};
      }
      return {'success': false, 'error': decoded['error'] ?? 'Login failed.'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to backend server: $e'};
    }
  }

  // 3. Sync SQLite Data to Postgres Neon
  Future<Map<String, dynamic>> syncData({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> budgets,
    required List<Map<String, dynamic>> paymentDetails,
    required List<Map<String, dynamic>> deletedRecords,
    String? lastSyncTime,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/expenses/sync'),
        headers: headers,
        body: json.encode({
          'expenses': expenses,
          'budgets': budgets,
          'payment_details': paymentDetails,
          'deleted_records': deletedRecords,
          if (lastSyncTime != null) 'last_sync_time': lastSyncTime,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      }
      return {'success': false, 'error': 'Sync server returned error: ${response.body}'};
    } catch (e) {
      return {'success': false, 'error': 'Failed to sync: $e'};
    }
  }

  // 4. Smart OCR Receipt Scanning (File Upload)
  Future<Map<String, dynamic>> scanReceipt(String imagePath) async {
    try {
      final token = await getToken();
      final uri = Uri.parse('$baseUrl/expenses/scan-receipt');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Check for user-defined custom Gemini API key
      try {
        final prefs = await SharedPreferences.getInstance();
        final userKey = prefs.getString('user_gemini_api_key');
        if (userKey != null && userKey.trim().isNotEmpty) {
          request.headers['x-user-gemini-key'] = userKey.trim();
        }
      } catch (err) {
        print('Error reading user_gemini_api_key: $err');
      }

      request.files.add(
        await http.MultipartFile.fromPath('receipt', imagePath),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': decoded['data']};
      }
      return {'success': false, 'error': decoded['error'] ?? 'Receipt scanning failed.'};
    } catch (e) {
      return {'success': false, 'error': 'OCR scan connection error: $e'};
    }
  }

  // 5. Batch Imports (PDF / Excel File Upload)
  // Uses a dedicated HTTP client with 3-minute timeout for large PDFs + AI processing time
  Future<Map<String, dynamic>> importStatement(String filePath) async {
    // Step 1: Warm-up ping — wakes Render server if sleeping (avoids cold-start timeout)
    try {
      print('[Import] Sending warm-up ping to wake server...');
      await http.get(Uri.parse('$baseUrl/')).timeout(const Duration(seconds: 30));
      print('[Import] Server is awake. Proceeding with file upload...');
    } catch (e) {
      print('[Import] Warm-up ping failed, proceeding anyway: $e');
    }

    // Small delay after warm-up to let server fully initialize
    await Future.delayed(const Duration(seconds: 2));

    try {
      final token = await getToken();
      final uri = Uri.parse('$baseUrl/expenses/import');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Pass user Gemini/Groq API key in header for AI processing
      try {
        final prefs = await SharedPreferences.getInstance();
        final userKey = prefs.getString('user_gemini_api_key');
        if (userKey != null && userKey.trim().isNotEmpty) {
          request.headers['x-user-gemini-key'] = userKey.trim();
        }
      } catch (err) {
        print('Error reading user_gemini_api_key: $err');
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      // 3-minute timeout: PDF upload + Gemini AI processing can take up to 60-90 seconds
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw Exception(
          'Request timed out after 3 minutes. Please try again with a smaller PDF or check your internet connection.'
        ),
      );
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(minutes: 3));

      final decoded = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'expenses': decoded['expenses']};
      }
      return {'success': false, 'error': decoded['error'] ?? 'Failed to parse file.'};
    } catch (e) {
      return {'success': false, 'error': 'Import failed: ${e.toString().replaceAll('Exception: ', '')}'}; 
    }
  }

  // 6. Analytics Fetch Summary
  Future<Map<String, dynamic>> fetchAnalyticsSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/summary'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch analytics summary.'};
    } catch (e) {
      return {'success': false, 'error': 'Analytics fetching error: $e'};
    }
  }

  // 7. Generate Invoice PDF Download
  Future<String?> generateInvoice(List<String> expenseIds) async {
    try {
      final token = await getToken();
      final queryParams = 'ids=${expenseIds.join(',')}';
      final uri = Uri.parse('$baseUrl/invoices/generate?$queryParams');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Save the byte array to device local directory as a PDF file
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/Invoice_${DateTime.now().millisecondsSinceEpoch}.pdf');
        
        await file.writeAsBytes(bytes);
        return file.path; // Return saved file path
      }
      return null;
    } catch (e) {
      print('Invoice download connection error: $e');
      return null;
    }
  }
}
