import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_update_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _channelId = 'app_updates_channel';
  static const String _channelName = 'App Updates';
  static const String _channelDescription = 'Notifications for new app version updates and releases';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.payload == 'app_update') {
            await AppUpdateService.instance.openDownloadLink();
          }
        },
      );

      // Create Android Notification Channel
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  /// Check and request notification permission on Android 13+ (API 33+)
  Future<bool> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          return result.isGranted;
        }
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Permission request error: $e');
      return false;
    }
  }

  /// Show rich system notification with App Logo & Changelog for updates
  Future<void> showUpdateNotification(AppUpdateInfo info) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        'Version ${info.latestVersion} is now available!\n${info.description}\n\nTap to download APK (${info.formattedFileSize})',
        htmlFormatBigText: false,
        contentTitle: '🚀 Grow Expense Update Available (${info.latestVersion})',
        htmlFormatContentTitle: false,
        summaryText: 'New Update Ready',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFF00D09C),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        1001, // Notification ID for App Updates
        '🚀 New Update Available! (${info.latestVersion})',
        'A new version of Grow Expense is ready to download. Tap to view & update.',
        notificationDetails,
        payload: 'app_update',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing update notification: $e');
    }
  }
}
