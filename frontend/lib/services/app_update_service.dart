import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String description;
  final String fileName;
  final int fileSizeBytes;
  final String downloadUrl;
  final String webUrl;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.description,
    required this.fileName,
    required this.fileSizeBytes,
    required this.downloadUrl,
    required this.webUrl,
  });

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '';
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class AppUpdateService with ChangeNotifier {
  static final AppUpdateService instance = AppUpdateService._internal();
  AppUpdateService._internal() {
    _init();
  }

  factory AppUpdateService() => instance;

  static const String currentAppVersion = 'v1.0.0';
  static const String updateApiUrl = 'https://api.neofilestransfer.site/api/version/apk_473b1286700c42a2';
  static const String defaultDownloadWebUrl = 'https://neofilestransfer.site/download/a1d6633466f3';
  static const String _keyAutoCheck = 'app_auto_check_updates_enabled';
  static const String _keyLastChecked = 'app_last_checked_update_time';

  bool _autoCheckEnabled = true;
  bool _isChecking = false;
  AppUpdateInfo? _latestUpdateInfo;
  String? _errorMessage;
  int? _lastCheckedTimestamp;

  bool get autoCheckEnabled => _autoCheckEnabled;
  bool get isChecking => _isChecking;
  AppUpdateInfo? get latestUpdateInfo => _latestUpdateInfo;
  String? get errorMessage => _errorMessage;
  int? get lastCheckedTimestamp => _lastCheckedTimestamp;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCheckEnabled = prefs.getBool(_keyAutoCheck) ?? true;
      _lastCheckedTimestamp = prefs.getInt(_keyLastChecked);
      notifyListeners();
    } catch (e) {
      debugPrint('[AppUpdateService] Init error: $e');
    }
  }

  Future<void> setAutoCheck(bool enabled) async {
    _autoCheckEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoCheck, enabled);
    } catch (e) {
      debugPrint('[AppUpdateService] Error saving auto check preference: $e');
    }
  }

  /// Parses and compares semver strings like "v1.0.1" and "v1.0.0"
  bool _isServerVersionNewer(String serverVer, String currentVer) {
    try {
      final cleanServer = serverVer.toLowerCase().replaceAll('v', '').trim();
      final cleanCurrent = currentVer.toLowerCase().replaceAll('v', '').trim();

      final serverParts = cleanServer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (serverParts.length < 3) {
        serverParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (serverParts[i] > currentParts[i]) return true;
        if (serverParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return serverVer != currentVer;
    }
  }

  /// Checks the official API for updates
  Future<AppUpdateInfo?> checkForUpdates({bool isManual = false}) async {
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(updateApiUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['status'] == 'success') {
          final serverVer = data['version']?.toString() ?? currentAppVersion;
          final description = data['description']?.toString() ?? '';
          final fileName = data['file_name']?.toString() ?? 'Grow_Expense.apk';
          final fileSize = int.tryParse(data['file_size']?.toString() ?? '0') ?? 0;
          final downloadUrl = data['download_url']?.toString() ?? defaultDownloadWebUrl;
          final webUrl = data['web_url']?.toString() ?? defaultDownloadWebUrl;

          final hasNewUpdate = _isServerVersionNewer(serverVer, currentAppVersion);

          _latestUpdateInfo = AppUpdateInfo(
            hasUpdate: hasNewUpdate,
            currentVersion: currentAppVersion,
            latestVersion: serverVer,
            description: description.isNotEmpty ? description : 'Bug fixes, performance improvements, and enhanced AI features.',
            fileName: fileName,
            fileSizeBytes: fileSize,
            downloadUrl: downloadUrl,
            webUrl: webUrl,
          );

          _lastCheckedTimestamp = DateTime.now().millisecondsSinceEpoch;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_keyLastChecked, _lastCheckedTimestamp!);

          _isChecking = false;
          notifyListeners();
          return _latestUpdateInfo;
        } else {
          _errorMessage = 'Invalid response from update server.';
        }
      } else {
        _errorMessage = 'Update server returned HTTP ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Could not reach update server: $e';
    }

    _isChecking = false;
    notifyListeners();
    return _latestUpdateInfo;
  }

  /// Opens the download link in the browser
  Future<bool> openDownloadLink() async {
    final targetUrl = _latestUpdateInfo?.webUrl.isNotEmpty == true
        ? _latestUpdateInfo!.webUrl
        : (_latestUpdateInfo?.downloadUrl.isNotEmpty == true
            ? _latestUpdateInfo!.downloadUrl
            : defaultDownloadWebUrl);

    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to launch update URL: $e');
    }
    return false;
  }
}
