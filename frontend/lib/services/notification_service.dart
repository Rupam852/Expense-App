import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_item.dart';
import '../models/budget.dart';
import '../models/expense.dart';
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

  static const String _subChannelId = 'subscription_reminders_channel';
  static const String _subChannelName = 'Subscription & Bill Reminders';
  static const String _subChannelDescription = 'Alerts for expiring and upcoming subscription and bill renewals';

  static const String _budgetChannelId = 'budget_alerts_channel';
  static const String _budgetChannelName = 'Budget & Spending Limits';
  static const String _budgetChannelDescription = 'Urgent alerts when your monthly budget limit is reached or exceeded';

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

      // Create Android Notification Channels
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
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _subChannelId,
              _subChannelName,
              description: _subChannelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _budgetChannelId,
              _budgetChannelName,
              description: _budgetChannelDescription,
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

  /// Show rich system notification for subscription renewal / due reminder
  Future<void> showSubscriptionDueNotification(SubscriptionItem item) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final days = item.daysUntilRenewal;
      String title;
      String body;

      if (days < 0) {
        title = '🚨 Overdue: ${item.name} Bill';
        body = '${item.name} renewal of ₹${item.amount.toStringAsFixed(2)} was due ${days.abs()} day(s) ago. Tap to view or mark renewed.';
      } else if (days == 0) {
        title = '⚠️ Due Today: ${item.name} Renewal';
        body = '${item.name} subscription of ₹${item.amount.toStringAsFixed(2)} is due today (${item.billingCycle.toUpperCase()}). Tap to manage.';
      } else if (days == 1) {
        title = '🔔 Due Tomorrow: ${item.name}';
        body = '${item.name} renewal of ₹${item.amount.toStringAsFixed(2)} is due tomorrow. Keep payment account ready!';
      } else {
        title = '📅 Upcoming Renewal: ${item.name}';
        body = '${item.name} renewal of ₹${item.amount.toStringAsFixed(2)} is scheduled in $days days.';
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Subscription Reminder',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _subChannelId,
        _subChannelName,
        channelDescription: _subChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFF00D09C),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final notificationId = (item.id.hashCode & 0x7FFFFFFF);

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'subscription_${item.id}',
      );
      debugPrint('[NotificationService] Fired subscription reminder notification for: ${item.name}');
    } catch (e) {
      debugPrint('[NotificationService] Error showing subscription notification: $e');
    }
  }

  /// Automatically checks all active subscriptions and notifies if due today or due soon
  Future<void> checkAndNotifyDueSubscriptions(List<SubscriptionItem> subscriptions) async {
    try {
      if (subscriptions.isEmpty) return;

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final prefs = await SharedPreferences.getInstance();

      for (final sub in subscriptions) {
        if (!sub.isActive || sub.isDeleted) continue;

        // Condition: Due today, overdue, or within reminder days
        final days = sub.daysUntilRenewal;
        final shouldNotify = (days <= 0) || (days <= sub.reminderDaysBefore);

        if (shouldNotify) {
          final notifyKey = 'sub_notified_${sub.id}_$todayStr';
          final alreadyNotifiedToday = prefs.getBool(notifyKey) ?? false;

          if (!alreadyNotifiedToday) {
            await showSubscriptionDueNotification(sub);
            await prefs.setBool(notifyKey, true);
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking due subscriptions: $e');
    }
  }

  /// Show rich system notification for budget limit reached / exceeded
  Future<void> showBudgetLimitNotification({
    required String category,
    required double spent,
    required double limit,
    required double percentage,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final isExceeded = percentage >= 100.0;
      final title = isExceeded
          ? '🚨 Budget Exceeded: $category'
          : '⚠️ Budget Alert: $category (${percentage.toStringAsFixed(0)}%)';
      final body = isExceeded
          ? 'You spent ₹${spent.toStringAsFixed(0)} which exceeds your ₹${limit.toStringAsFixed(0)} limit (${percentage.toStringAsFixed(0)}%). Tap to manage budgets.'
          : 'You have used ${percentage.toStringAsFixed(0)}% of your ₹${limit.toStringAsFixed(0)} limit (₹${spent.toStringAsFixed(0)} spent).';

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: isExceeded ? 'Budget Exceeded' : 'Budget Warning',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _budgetChannelId,
        _budgetChannelName,
        channelDescription: _budgetChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final notificationId = (category.hashCode ^ (isExceeded ? 1 : 2)) & 0x7FFFFFFF;

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'budget_$category',
      );
      debugPrint('[NotificationService] Fired budget notification for: $category ($percentage%)');
    } catch (e) {
      debugPrint('[NotificationService] Error showing budget notification: $e');
    }
  }

  /// Automatically checks budgets against expenses for the month and alerts if >= 90% or >= 100%
  Future<void> checkAndNotifyBudgetLimits({
    required List<Budget> budgets,
    required List<Expense> expenses,
    required DateTime currentMonth,
  }) async {
    try {
      if (budgets.isEmpty) return;

      final monthStr = '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}';
      final monthExpenses = expenses.where((e) {
        if (e.isDeleted) return false;
        final d = e.transactionDate;
        return d.year == currentMonth.year && d.month == currentMonth.month;
      }).toList();

      final prefs = await SharedPreferences.getInstance();

      for (final budget in budgets) {
        if (budget.isDeleted || budget.monthYear != monthStr || budget.amountLimit <= 0) continue;

        double spent = 0.0;
        if (budget.category == 'Total Budget') {
          spent = monthExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
        } else {
          spent = monthExpenses
              .where((e) => e.category.toLowerCase() == budget.category.toLowerCase())
              .fold<double>(0.0, (sum, e) => sum + e.amount);
        }

        final percentage = (spent / budget.amountLimit) * 100.0;

        if (percentage >= 100.0) {
          final notifyKey = 'budget_notified_100_${budget.id}_$monthStr';
          final alreadyNotified = prefs.getBool(notifyKey) ?? false;
          if (!alreadyNotified) {
            await showBudgetLimitNotification(
              category: budget.category,
              spent: spent,
              limit: budget.amountLimit,
              percentage: percentage,
            );
            await prefs.setBool(notifyKey, true);
          }
        } else if (percentage >= 90.0) {
          final notifyKey = 'budget_notified_90_${budget.id}_$monthStr';
          final alreadyNotified = prefs.getBool(notifyKey) ?? false;
          if (!alreadyNotified) {
            await showBudgetLimitNotification(
              category: budget.category,
              spent: spent,
              limit: budget.amountLimit,
              percentage: percentage,
            );
            await prefs.setBool(notifyKey, true);
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking budget limits: $e');
    }
  }

  /// Sends an instant Test Notification to verify sound, vibration & status bar alerts
  Future<bool> sendTestNotification({
    String title = '🔔 Test Notification: Grow Expense',
    String body = 'Notifications are working perfectly! You will receive subscription & update alerts.',
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final hasPermission = await requestNotificationPermission();
      if (!hasPermission) {
        debugPrint('[NotificationService] Notification permission not granted');
        return false;
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Test Notification',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _subChannelId,
        _subChannelName,
        channelDescription: _subChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFF00D09C),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        9999,
        title,
        body,
        notificationDetails,
        payload: 'test_notification',
      );
      debugPrint('[NotificationService] Test notification fired successfully!');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Error firing test notification: $e');
      return false;
    }
  }
}
