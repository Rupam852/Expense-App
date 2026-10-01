import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  static SupportService get instance => _instance;

  SupportService._internal();

  /// Send support/issue report to backend / SMTP email dispatcher
  Future<bool> sendIssueReport({
    required String name,
    required String email,
    required String category,
    required String message,
    String? errorDetails,
    String? deviceInfo,
    String appVersion = 'v1.2.0',
  }) async {
    final payload = {
      'name': name.trim().isEmpty ? 'Grow Expense User' : name.trim(),
      'email': email.trim().isEmpty ? 'user@growexpense.app' : email.trim(),
      'category': category,
      'message': message.trim(),
      'errorDetails': errorDetails?.trim(),
      'deviceInfo': deviceInfo ?? _getDefaultDeviceInfo(),
      'appVersion': appVersion,
    };

    bool sentSuccessfully = false;

    // 1. Try sending via Supabase Edge Function `report-issue`
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(
        'report-issue',
        body: payload,
      );
      if (response.status == 200) {
        sentSuccessfully = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SupportService] Edge function attempt error: $e');
      }
    }

    // 2. Try sending via Backend API (Render / Localhost)
    if (!sentSuccessfully) {
      final backendUrls = [
        'https://expense-app-backend-2cwr.onrender.com/auth/report-issue',
        'http://localhost:5000/auth/report-issue',
        'http://10.0.2.2:5000/auth/report-issue',
      ];

      for (final url in backendUrls) {
        try {
          final res = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 8));

          if (res.statusCode == 200 || res.statusCode == 201) {
            sentSuccessfully = true;
            break;
          }
        } catch (_) {}
      }
    }

    return sentSuccessfully;
  }

  static String _getDefaultDeviceInfo() {
    try {
      if (kIsWeb) return 'Web Browser';
      if (Platform.isAndroid) return 'Android Device (OS ${Platform.operatingSystemVersion})';
      if (Platform.isIOS) return 'iOS Device';
      if (Platform.isWindows) return 'Windows OS';
      return Platform.operatingSystem;
    } catch (_) {
      return 'Mobile/Desktop Client';
    }
  }
}
