import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  static SupportService get instance => _instance;

  SupportService._internal();

  static const String developerEmail = 'rupambairagya08@gmail.com';

  /// Prepares formatted report, opens native Email/Gmail client to send to `rupambairagya08@gmail.com`
  /// and silently logs report to backend as backup.
  Future<bool> sendIssueReport({
    required String name,
    required String email,
    required String category,
    required String message,
    String? errorDetails,
    String? deviceInfo,
    String appVersion = 'v1.1.0',
  }) async {
    final cleanName = name.trim().isEmpty ? 'Grow Expense User' : name.trim();
    final cleanEmail = email.trim().isEmpty ? 'Not Provided' : email.trim();
    final cleanDeviceInfo = deviceInfo ?? _getDefaultDeviceInfo();
    final timestamp = DateTime.now().toLocal().toString().split('.')[0];

    // 1. Format clean, professional email body draft
    final formattedBody = StringBuffer();
    formattedBody.writeln('Grow Expense - Problem Report & Feedback');
    formattedBody.writeln('════════════════════════════════════════');
    formattedBody.writeln('');
    formattedBody.writeln('👤 User Details:');
    formattedBody.writeln('• Name: $cleanName');
    formattedBody.writeln('• User Email: $cleanEmail');
    formattedBody.writeln('• Date & Time: $timestamp');
    formattedBody.writeln('');
    formattedBody.writeln('📌 Problem Category:');
    formattedBody.writeln('• $category');
    formattedBody.writeln('');
    formattedBody.writeln('📝 Problem Description:');
    formattedBody.writeln(message.trim());
    formattedBody.writeln('');
    if (errorDetails != null && errorDetails.trim().isNotEmpty) {
      formattedBody.writeln('⚠️ Error & Diagnostics:');
      formattedBody.writeln(errorDetails.trim());
      formattedBody.writeln('');
    }
    formattedBody.writeln('⚙️ Device & App Info:');
    formattedBody.writeln('• App Version: $appVersion');
    formattedBody.writeln('• Operating System: $cleanDeviceInfo');
    formattedBody.writeln('');
    formattedBody.writeln('════════════════════════════════════════');
    formattedBody.writeln('(Sent automatically via Grow Expense App)');

    // 2. Build mailto URI targeting rupambairagya08@gmail.com
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: developerEmail,
      queryParameters: {
        'subject': '[Grow Expense Report] $category - $cleanName',
        'body': formattedBody.toString(),
      },
    );

    bool launchedEmailApp = false;
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        launchedEmailApp = true;
      } else {
        // Fallback launch attempt
        await launchUrl(emailUri);
        launchedEmailApp = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SupportService] Error launching mail client: $e');
      }
    }

    // 3. Silently backup report payload to backend/Supabase as well
    _silentCloudBackup(
      name: cleanName,
      email: cleanEmail,
      category: category,
      message: message,
      errorDetails: errorDetails,
      deviceInfo: cleanDeviceInfo,
      appVersion: appVersion,
    );

    return launchedEmailApp;
  }

  /// Background backup to Edge function / server
  Future<void> _silentCloudBackup({
    required String name,
    required String email,
    required String category,
    required String message,
    String? errorDetails,
    required String deviceInfo,
    required String appVersion,
  }) async {
    final payload = {
      'name': name,
      'email': email,
      'category': category,
      'message': message.trim(),
      'errorDetails': errorDetails?.trim(),
      'deviceInfo': deviceInfo,
      'appVersion': appVersion,
      'recipient': developerEmail,
    };

    try {
      final client = Supabase.instance.client;
      await client.functions.invoke('report-issue', body: payload);
    } catch (_) {
      try {
        final backendUrls = [
          'https://expense-app-backend-2cwr.onrender.com/auth/report-issue',
          'http://localhost:5000/auth/report-issue',
          'http://10.0.2.2:5000/auth/report-issue',
        ];
        for (final url in backendUrls) {
          final res = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200 || res.statusCode == 201) break;
        }
      } catch (_) {}
    }
  }

  static String _getDefaultDeviceInfo() {
    try {
      if (kIsWeb) return 'Web Browser';
      if (Platform.isAndroid) return 'Android (SDK ${Platform.operatingSystemVersion})';
      if (Platform.isIOS) return 'iOS Device';
      if (Platform.isWindows) return 'Windows OS';
      return Platform.operatingSystem;
    } catch (_) {
      return 'Mobile/Desktop Client';
    }
  }
}
