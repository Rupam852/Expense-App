import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_item.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/khata_entry.dart';
import '../screens/app_update_screen.dart';
import '../screens/subscription_screen.dart';
import '../screens/khata_screen.dart';
import '../screens/split_bill_screen.dart';
import '../screens/expense_entry_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/invoice_screen.dart';
import 'app_update_service.dart';
import 'supabase_service.dart';

class NotificationService with ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal() {
    loadPreferences();
  }

  factory NotificationService() => instance;

  GlobalKey<NavigatorState>? navigatorKey;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Notification Channels
  static const String _channelId = 'app_updates_channel';
  static const String _channelName = 'App Updates';
  static const String _channelDescription = 'Notifications for new app version updates and releases';

  static const String _subChannelId = 'subscription_reminders_channel';
  static const String _subChannelName = 'Subscription & Bill Reminders';
  static const String _subChannelDescription = 'Alerts for expiring and upcoming subscription and bill renewals';

  static const String _budgetChannelId = 'budget_alerts_channel';
  static const String _budgetChannelName = 'Budget & Spending Limits';
  static const String _budgetChannelDescription = 'Urgent alerts when your monthly budget limit is reached or exceeded';

  static const String _khataChannelId = 'khata_alerts_channel';
  static const String _khataChannelName = 'Khata & Udhar Reminders';
  static const String _khataChannelDescription = 'Reminders for pending lend and borrow payments';

  static const String _generalChannelId = 'general_alerts_channel';
  static const String _generalChannelName = 'Daily & Monthly Summaries';
  static const String _generalChannelDescription = 'Daily evening log reminders and monthly savings reports';

  // Preference states
  bool _masterEnabled = true;
  bool _budgetAlertsEnabled = true;
  bool _subscriptionAlertsEnabled = true;
  bool _khataAlertsEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _splitBillAlertsEnabled = true;
  bool _monthlyReportEnabled = true;
  bool _monthEndAlertsEnabled = true;
  bool _newMonthStartAlertsEnabled = true;
  bool _appUpdatesEnabled = true;
  String _notificationLanguage = 'en'; // 'en', 'hi', 'bn', 'hinglish'

  String? _fcmToken;

  // Getters
  String? get fcmToken => _fcmToken;
  bool get masterEnabled => _masterEnabled;
  bool get budgetAlertsEnabled => _budgetAlertsEnabled;
  bool get subscriptionAlertsEnabled => _subscriptionAlertsEnabled;
  bool get khataAlertsEnabled => _khataAlertsEnabled;
  bool get dailyReminderEnabled => _dailyReminderEnabled;
  bool get splitBillAlertsEnabled => _splitBillAlertsEnabled;
  bool get monthlyReportEnabled => _monthlyReportEnabled;
  bool get monthEndAlertsEnabled => _monthEndAlertsEnabled;
  bool get newMonthStartAlertsEnabled => _newMonthStartAlertsEnabled;
  bool get appUpdatesEnabled => _appUpdatesEnabled;
  String get notificationLanguage => _notificationLanguage;

  String get languageDisplayName {
    switch (_notificationLanguage) {
      case 'hi':
        return 'Hindi (हिंदी)';
      case 'bn':
        return 'Bengali (বাংলা)';
      case 'hinglish':
        return 'Hinglish (Hindi in English)';
      case 'en':
      default:
        return 'English';
    }
  }

  // Load preferences from local storage
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _masterEnabled = prefs.getBool('notif_master_enabled') ?? true;
      _budgetAlertsEnabled = prefs.getBool('notif_budget_enabled') ?? true;
      _subscriptionAlertsEnabled = prefs.getBool('notif_subscription_enabled') ?? true;
      _khataAlertsEnabled = prefs.getBool('notif_khata_enabled') ?? true;
      _dailyReminderEnabled = prefs.getBool('notif_daily_reminder_enabled') ?? true;
      _splitBillAlertsEnabled = prefs.getBool('notif_split_bill_enabled') ?? true;
      _monthlyReportEnabled = prefs.getBool('notif_monthly_report_enabled') ?? true;
      _monthEndAlertsEnabled = prefs.getBool('notif_month_end_enabled') ?? true;
      _newMonthStartAlertsEnabled = prefs.getBool('notif_new_month_start_enabled') ?? true;
      _appUpdatesEnabled = prefs.getBool('notif_app_updates_enabled') ?? true;
      _notificationLanguage = prefs.getString('notif_language') ?? 'en';
      _fcmToken = prefs.getString('cached_fcm_token');
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationService] Error loading preferences: $e');
    }
  }

  // Setters for preferences
  Future<void> setMasterEnabled(bool val) async {
    _masterEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_master_enabled', val);
  }

  Future<void> setBudgetAlertsEnabled(bool val) async {
    _budgetAlertsEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_budget_enabled', val);
  }

  Future<void> setSubscriptionAlertsEnabled(bool val) async {
    _subscriptionAlertsEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_subscription_enabled', val);
  }

  Future<void> setKhataAlertsEnabled(bool val) async {
    _khataAlertsEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_khata_enabled', val);
  }

  Future<void> setDailyReminderEnabled(bool val) async {
    _dailyReminderEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_daily_reminder_enabled', val);
  }

  Future<void> setSplitBillAlertsEnabled(bool val) async {
    _splitBillAlertsEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_split_bill_enabled', val);
  }

  Future<void> setMonthlyReportEnabled(bool val) async {
    _monthlyReportEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_monthly_report_enabled', val);
  }

  Future<void> setMonthEndAlertsEnabled(bool val) async {
    _monthEndAlertsEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_month_end_enabled', val);
  }

  Future<void> setNewMonthStartAlertsEnabled(bool val) async {
    _newMonthStartAlertsEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_new_month_start_enabled', val);
  }

  Future<void> setAppUpdatesEnabled(bool val) async {
    _appUpdatesEnabled = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_app_updates_enabled', val);
  }

  Future<void> setNotificationLanguage(String langCode) async {
    _notificationLanguage = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_language', langCode);
  }

  /// Manually sync FCM token to Supabase for the current logged in user
  Future<void> syncFcmTokenToCloud() async {
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      await SupabaseService.instance.saveFcmToken(_fcmToken!);
    }
  }

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
          handleNotificationPayload(response.payload);
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
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _khataChannelId,
              _khataChannelName,
              description: _khataChannelDescription,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _generalChannelId,
              _generalChannelName,
              description: _generalChannelDescription,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
        }
      }

      // Initialize Firebase Cloud Messaging
      await _initFcm();

      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  /// Initialize Firebase Cloud Messaging (FCM)
  Future<void> _initFcm() async {
    try {
      final fcm = FirebaseMessaging.instance;

      // Request FCM permission
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[NotificationService] FCM Authorization status: ${settings.authorizationStatus}');

      // Get initial device FCM token
      _fcmToken = await fcm.getToken();
      if (_fcmToken != null) {
        debugPrint('[NotificationService] FCM Device Token: $_fcmToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_fcm_token', _fcmToken!);
        await SupabaseService.instance.saveFcmToken(_fcmToken!);
      }

      // Listen for token refreshes
      fcm.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('[NotificationService] FCM Token refreshed: $newToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_fcm_token', newToken);
        await SupabaseService.instance.saveFcmToken(newToken);
      });

      // Handle Foreground FCM Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground FCM message received: ${message.messageId}');
        _handleForegroundFcmMessage(message);
      });

      // Handle FCM notification taps when app is in background/resumed
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Notification opened from background: ${message.data}');
        _handleFcmMessageClick(message);
      });

      // Check cold-boot launch from notification
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] Cold boot via notification: ${initialMessage.data}');
        _handleFcmMessageClick(initialMessage);
      }
    } catch (e) {
      debugPrint('[NotificationService] FCM initialization error: $e');
    }
  }

  /// Display a heads-up local notification when FCM arrives in Foreground
  void _handleForegroundFcmMessage(RemoteMessage message) {
    if (!_masterEnabled) return;

    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Grow Expense';
    final body = notification?.body ?? data['body'] ?? '';
    final channelId = data['channel_id'] ?? data['channelId'] ?? _generalChannelId;
    final payload = data['payload'] ?? data['type'] ?? 'fcm_message';

    String targetChannel = _generalChannelId;
    String targetName = _generalChannelName;
    String targetDesc = _generalChannelDescription;
    Importance targetImportance = Importance.high;

    if (channelId == _channelId || data['type'] == 'app_update') {
      if (!_appUpdatesEnabled) return;
      targetChannel = _channelId;
      targetName = _channelName;
      targetDesc = _channelDescription;
    } else if (channelId == _subChannelId || data['type'] == 'subscription') {
      if (!_subscriptionAlertsEnabled) return;
      targetChannel = _subChannelId;
      targetName = _subChannelName;
      targetDesc = _subChannelDescription;
      targetImportance = Importance.max;
    } else if (channelId == _budgetChannelId || data['type'] == 'budget') {
      if (!_budgetAlertsEnabled) return;
      targetChannel = _budgetChannelId;
      targetName = _budgetChannelName;
      targetDesc = _budgetChannelDescription;
    } else if (channelId == _khataChannelId || data['type'] == 'khata') {
      if (!_khataAlertsEnabled) return;
      targetChannel = _khataChannelId;
      targetName = _khataChannelName;
      targetDesc = _khataChannelDescription;
    }

    final bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: targetName,
      htmlFormatSummaryText: false,
    );

    final androidDetails = AndroidNotificationDetails(
      targetChannel,
      targetName,
      channelDescription: targetDesc,
      importance: targetImportance,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: bigTextStyleInformation,
      color: const Color(0xFF00D09C),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    _notificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Handle Notification Payload Clicks from Firebase Cloud Messaging
  void _handleFcmMessageClick(RemoteMessage message) async {
    final payload = message.data['type'] ?? message.data['payload'] ?? message.data['channel_id'];
    handleNotificationPayload(payload?.toString());
  }

  /// Global Deep Linking Handler for ALL notification types
  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('[NotificationService] Handling notification click with payload: $payload');

    final context = navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('[NotificationService] Navigator context not available yet for payload: $payload');
      return;
    }

    try {
      if (payload == 'app_update') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AppUpdateScreen()),
        );
      } else if (payload.startsWith('subscription')) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
        );
      } else if (payload.startsWith('khata')) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const KhataScreen()),
        );
      } else if (payload.startsWith('split_bill')) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SplitBillScreen()),
        );
      } else if (payload == 'daily_reminder') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ExpenseEntryScreen()),
        );
      } else if (payload.startsWith('budget')) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const BudgetScreen()),
        );
      } else if (payload == 'monthly_report') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
        );
      } else if (payload == 'month_end_reminder' || payload == 'new_month_start') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const InvoiceScreen()),
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Error navigating to screen for payload $payload: $e');
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

  // ──────────────────────────────────────────────────────────
  // 1. APP UPDATES NOTIFICATION
  // ──────────────────────────────────────────────────────────
  Future<void> showUpdateNotification(AppUpdateInfo info) async {
    if (!_masterEnabled || !_appUpdatesEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          title = '🚀 नया अपडेट उपलब्ध है! (${info.latestVersion})';
          body = 'ग्रो एक्सपेंस का नया वर्ज़न डाउनलोड के लिए तैयार है। अपडेट करने के लिए टैप करें।';
          break;
        case 'bn':
          title = '🚀 নতুন আপডেট উপলভ্য! (${info.latestVersion})';
          body = 'Grow Expense-এর নতুন সংস্করণ ডাউনলোডের জন্য প্রস্তুত। আপডেট করতে ট্যাপ করুন।';
          break;
        case 'hinglish':
          title = '🚀 Naya Update Available Hai! (${info.latestVersion})';
          body = 'Grow Expense ka new version ready hai. Update karne ke liye tap karein.';
          break;
        case 'en':
        default:
          title = '🚀 New Update Available! (${info.latestVersion})';
          body = 'A new version of Grow Expense is ready to download. Tap to view & update.';
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        'Version ${info.latestVersion} is now available!\n${info.description}\n\nTap to download APK (${info.formattedFileSize})',
        htmlFormatBigText: false,
        contentTitle: title,
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
        1001,
        title,
        body,
        notificationDetails,
        payload: 'app_update',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing update notification: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 2. SUBSCRIPTION & BILL DUE NOTIFICATION
  // ──────────────────────────────────────────────────────────
  Future<void> showSubscriptionDueNotification(SubscriptionItem item) async {
    if (!_masterEnabled || !_subscriptionAlertsEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      final days = item.daysUntilRenewal;
      final amt = '₹${item.amount.toStringAsFixed(0)}';
      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          if (days < 0) {
            title = '🚨 बिल बकाया: ${item.name}';
            body = '${item.name} का $amt का बिल ${days.abs()} दिन पहले देय था। रिन्यूअल पूरा करें।';
          } else if (days == 0) {
            title = '⚠️ आज देय है: ${item.name} रिन्यूअल';
            body = '${item.name} का $amt का भुगतान आज देय है। कृपया खाता तैयार रखें।';
          } else if (days == 1) {
            title = '🔔 कल देय है: ${item.name}';
            body = '${item.name} का $amt का रिन्यूअल कल है।';
          } else {
            title = '📅 आगामी रिन्यूअल: ${item.name}';
            body = '${item.name} का $amt का भुगतान $days दिनों में होगा।';
          }
          break;

        case 'bn':
          if (days < 0) {
            title = '🚨 বিল বকেয়া: ${item.name}';
            body = '${item.name}-এর $amt বিল ${days.abs()} দিন আগে পরিশোধ করার কথা ছিল।';
          } else if (days == 0) {
            title = '⚠️ আজ দিতে হবে: ${item.name}';
            body = '${item.name}-এর $amt সাবস্ক্রিপশন ফি আজ দিতে হবে।';
          } else if (days == 1) {
            title = '🔔 আগামীকাল দিতে হবে: ${item.name}';
            body = '${item.name}-এর $amt রিনিউয়াল আগামীকাল।';
          } else {
            title = '📅 আসন্ন রিনিউয়াল: ${item.name}';
            body = '${item.name}-এর $amt বিল $days দিনের মধ্যে পরিশোধ করতে হবে।';
          }
          break;

        case 'hinglish':
          if (days < 0) {
            title = '🚨 Overdue Bill: ${item.name}';
            body = '${item.name} ka $amt ka renewal ${days.abs()} din pehle due tha. Check karein.';
          } else if (days == 0) {
            title = '⚠️ Due Today: ${item.name} Renewal';
            body = '${item.name} ka $amt subscription aaj renew hona hai. Payment check karein.';
          } else if (days == 1) {
            title = '🔔 Due Tomorrow: ${item.name}';
            body = '${item.name} renewal $amt kal due hai. Account ready rakhein!';
          } else {
            title = '📅 Upcoming Renewal: ${item.name}';
            body = '${item.name} ka $amt renewal $days days me scheduled hai.';
          }
          break;

        case 'en':
        default:
          if (days < 0) {
            title = '🚨 Overdue: ${item.name} Bill';
            body = '${item.name} renewal of $amt was due ${days.abs()} day(s) ago. Tap to mark renewed.';
          } else if (days == 0) {
            title = '⚠️ Due Today: ${item.name} Renewal';
            body = '${item.name} subscription of $amt is due today (${item.billingCycle.toUpperCase()}).';
          } else if (days == 1) {
            title = '🔔 Due Tomorrow: ${item.name}';
            body = '${item.name} renewal of $amt is due tomorrow. Keep payment account ready!';
          } else {
            title = '📅 Upcoming Renewal: ${item.name}';
            body = '${item.name} renewal of $amt is scheduled in $days days.';
          }
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
      debugPrint('[NotificationService] Fired subscription notification for: ${item.name}');
    } catch (e) {
      debugPrint('[NotificationService] Error showing subscription notification: $e');
    }
  }

  Future<void> checkAndNotifyDueSubscriptions(List<SubscriptionItem> subscriptions) async {
    if (!_masterEnabled || !_subscriptionAlertsEnabled) return;

    try {
      if (subscriptions.isEmpty) return;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final prefs = await SharedPreferences.getInstance();

      for (final sub in subscriptions) {
        if (!sub.isActive || sub.isDeleted) continue;
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

  // ──────────────────────────────────────────────────────────
  // 3. BUDGET EXCEEDED & 90% WARNING NOTIFICATION
  // ──────────────────────────────────────────────────────────
  Future<void> showBudgetLimitNotification({
    required String category,
    required double spent,
    required double limit,
    required double percentage,
  }) async {
    if (!_masterEnabled || !_budgetAlertsEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      final isExceeded = percentage >= 100.0;
      final spentStr = '₹${spent.toStringAsFixed(0)}';
      final limitStr = '₹${limit.toStringAsFixed(0)}';
      final pctStr = '${percentage.toStringAsFixed(0)}%';

      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          title = isExceeded
              ? '🚨 बजट सीमा पार: $category'
              : '⚠️ बजट चेतावनी: $category ($pctStr)';
          body = isExceeded
              ? 'आपने $limitStr के बजट में से $spentStr ($pctStr) खर्च कर दिया है।'
              : 'आपने इस महीने $limitStr की सीमा का $pctStr ($spentStr) उपयोग कर लिया है।';
          break;

        case 'bn':
          title = isExceeded
              ? '🚨 বাজেট অতিক্রম করেছে: $category'
              : '⚠️ বাজেট সতর্কতা: $category ($pctStr)';
          body = isExceeded
              ? 'আপনি $limitStr বাজেটের মধ্যে $spentStr ($pctStr) খরচ করেছেন।'
              : 'আপনি এই মাসে আপনার $limitStr সীমার $pctStr ($spentStr) খরচ করেছেন।';
          break;

        case 'hinglish':
          title = isExceeded
              ? '🚨 Budget Exceeded: $category'
              : '⚠️ Budget Alert: $category ($pctStr)';
          body = isExceeded
              ? 'Aapne $limitStr budget me se $spentStr ($pctStr) kharch kar diya hai.'
              : 'Aapne is month apne $limitStr limit ka $pctStr ($spentStr) spend kar liya hai.';
          break;

        case 'en':
        default:
          title = isExceeded
              ? '🚨 Budget Exceeded: $category'
              : '⚠️ Budget Alert: $category ($pctStr)';
          body = isExceeded
              ? 'You spent $spentStr which exceeds your $limitStr limit ($pctStr). Tap to manage.'
              : 'You have used $pctStr of your $limitStr limit ($spentStr spent).';
      }

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
    } catch (e) {
      debugPrint('[NotificationService] Error showing budget notification: $e');
    }
  }

  Future<void> checkAndNotifyBudgetLimits({
    required List<Budget> budgets,
    required List<Expense> expenses,
    required DateTime currentMonth,
  }) async {
    if (!_masterEnabled || !_budgetAlertsEnabled) return;

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

  // ──────────────────────────────────────────────────────────
  // 4. KHATA (UDHAR) REMINDERS (LEND & BORROW)
  // ──────────────────────────────────────────────────────────
  Future<void> showKhataReminderNotification({
    required String personName,
    required double amount,
    required bool isLent,
    DateTime? dueDate,
  }) async {
    if (!_masterEnabled || !_khataAlertsEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      final amtStr = '₹${amount.toStringAsFixed(0)}';
      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          title = isLent ? '💸 खाता बकाया: $personName' : '🤝 उधारी वापसी रिमाइंडर: $personName';
          body = isLent
              ? '$personName से $amtStr लेना बाकी है। पेमेंट के लिए याद दिलाएं।'
              : '$personName को $amtStr वापस करना बाकी है।';
          break;

        case 'bn':
          title = isLent ? '💸 খাতা বকেয়া: $personName' : '🤝 দেনা পরিশোধের সতর্কতা: $personName';
          body = isLent
              ? '$personName-এর থেকে $amtStr পাওয়া বাকি আছে।'
              : '$personName-কে $amtStr ফেরত দেওয়ার সময় হয়েছে।';
          break;

        case 'hinglish':
          title = isLent ? '💸 Khata Alert: $personName' : '🤝 Udhar Return Reminder: $personName';
          body = isLent
              ? '$personName se $amtStr lena pending hai. Reminder send karein.'
              : '$personName ko $amtStr return karna baki hai.';
          break;

        case 'en':
        default:
          title = isLent ? '💸 Khata Reminder: $personName' : '🤝 Payment Reminder: $personName';
          body = isLent
              ? '$personName owes you $amtStr. Tap to review or remind.'
              : 'You need to return $amtStr to $personName.';
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Khata Udhar Alert',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _khataChannelId,
        _khataChannelName,
        channelDescription: _khataChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: isLent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final notificationId = (personName.hashCode ^ (isLent ? 11 : 22)) & 0x7FFFFFFF;

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'khata_$personName',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing khata notification: $e');
    }
  }

  Future<void> checkAndNotifyKhataEntries(List<KhataEntry> entries) async {
    if (!_masterEnabled || !_khataAlertsEnabled) return;

    try {
      if (entries.isEmpty) return;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final prefs = await SharedPreferences.getInstance();

      for (final entry in entries) {
        if (entry.isDeleted || entry.isSettled || entry.amount <= 0) continue;

        final isDue = entry.dueDate != null &&
            entry.dueDate!.isBefore(DateTime.now().add(const Duration(days: 1)));

        if (isDue) {
          final notifyKey = 'khata_notified_${entry.id}_$todayStr';
          final alreadyNotified = prefs.getBool(notifyKey) ?? false;
          if (!alreadyNotified) {
            await showKhataReminderNotification(
              personName: entry.personName,
              amount: entry.amount,
              isLent: entry.isLent,
              dueDate: entry.dueDate,
            );
            await prefs.setBool(notifyKey, true);
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking khata entries: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 5. SPLIT BILL PENDING COLLECTION ALERT
  // ──────────────────────────────────────────────────────────
  Future<void> showSplitBillPendingNotification({
    required String titleText,
    required double pendingAmount,
    required int pendingPeopleCount,
  }) async {
    if (!_masterEnabled || !_splitBillAlertsEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      final amtStr = '₹${pendingAmount.toStringAsFixed(0)}';
      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          title = '👥 स्प्लिट बिल रिमाइंडर: $titleText';
          body = '$pendingPeopleCount लोगों से $amtStr का कलेक्शन अभी बाकी है।';
          break;

        case 'bn':
          title = '👥 স্প্লিট বিল সতর্কতা: $titleText';
          body = '$pendingPeopleCount জনের থেকে $amtStr তোলা এখনও বাকি আছে।';
          break;

        case 'hinglish':
          title = '👥 Split Bill Alert: $titleText';
          body = '$pendingPeopleCount logo se $amtStr collect karna pending hai.';
          break;

        case 'en':
        default:
          title = '👥 Split Bill Reminder: $titleText';
          body = '$pendingPeopleCount participant(s) have pending collection of $amtStr.';
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Split Bill Reminder',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _generalChannelId,
        _generalChannelName,
        channelDescription: _generalChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFF6366F1),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final notificationId = (titleText.hashCode ^ 33) & 0x7FFFFFFF;

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'split_bill_$titleText',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing split bill notification: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 6. DAILY EVENING LOGGING REMINDER (9:00 PM)
  // ──────────────────────────────────────────────────────────
  Future<void> showDailyEveningReminder() async {
    if (!_masterEnabled || !_dailyReminderEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          title = '🌙 आज का खर्चा नोट किया?';
          body = 'सोने से पहले आज के सभी नकद या ऑनलाइन खर्चों को Grow Expense में जोड़ें।';
          break;

        case 'bn':
          title = '🌙 আজকের খরচ যোগ করেছেন?';
          body = 'ঘুমোতে যাওয়ার আগে আজকের নগদ বা অনলাইন খরচগুলো Grow Expense-এ রেকর্ড করুন।';
          break;

        case 'hinglish':
          title = '🌙 Aaj ka kharcha add kiya?';
          body = 'Sone se pehle aaj ke sabhi transactions Grow Expense me log karein.';
          break;

        case 'en':
        default:
          title = '🌙 Track Today\'s Expenses';
          body = 'Take 30 seconds to log today\'s spending and keep your budget in check!';
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Daily Expense Habit',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _generalChannelId,
        _generalChannelName,
        channelDescription: _generalChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFF8B5CF6),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        8888,
        title,
        body,
        notificationDetails,
        payload: 'daily_reminder',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing daily reminder: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 7. MONTHLY REPORT & SAVINGS TARGET NOTIFICATION
  // ──────────────────────────────────────────────────────────
  Future<void> showMonthlySavingsReportNotification({
    required double totalSpent,
    required double totalSaved,
    required String monthName,
  }) async {
    if (!_masterEnabled || !_monthlyReportEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      final spentStr = '₹${totalSpent.toStringAsFixed(0)}';
      final savedStr = '₹${totalSaved.toStringAsFixed(0)}';

      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          title = '🎉 $monthName की मासिक रिपोर्ट';
          body = 'आपने पिछले महीने $spentStr खर्च किए और $savedStr की बचत की! पूरा विश्लेषण देखें।';
          break;

        case 'bn':
          title = '🎉 $monthName মাসের ফাইনান্সিয়াল রিপোর্ট';
          body = 'আপনি গত মাসে $spentStr খরচ করেছেন এবং $savedStr সঞ্চয় করেছেন!';
          break;

        case 'hinglish':
          title = '🎉 $monthName Monthly Report Ready!';
          body = 'Aapne last month $spentStr spend kiye aur $savedStr save kiya! Check breakdown.';
          break;

        case 'en':
        default:
          title = '🎉 $monthName Monthly Financial Report';
          body = 'You spent $spentStr and saved $savedStr last month! Tap to view insights.';
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Monthly Financial Summary',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _generalChannelId,
        _generalChannelName,
        channelDescription: _generalChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFF00D09C),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        7777,
        title,
        body,
        notificationDetails,
        payload: 'monthly_report',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing monthly report: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 8. MONTH-END INVOICE & ROLLOVER REMINDER (8:00 - 9:00 PM on Last Day)
  // ──────────────────────────────────────────────────────────
  Future<void> showMonthEndReminderNotification() async {
    if (!_masterEnabled || !_monthEndAlertsEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      String title;
      String body;

      switch (_notificationLanguage) {
        case 'hi':
          title = '🗓️ कल से नया महीना शुरू हो रहा है!';
          body = 'कल आपके इस महीने के पूरे खर्चे PDF इनवॉइस में कन्वर्ट होकर आपके फोन के Downloads फोल्डर में सुरक्षित सेव होंगे।';
          break;

        case 'bn':
          title = '🗓️ আগামীকাল থেকে নতুন মাস শুরু হচ্ছে!';
          body = 'আগামীকাল আপনার এই মাসের সমস্ত খরচ PDF ইনভয়েসে কনভার্ট হয়ে আপনার ফোনের Downloads ফোল্ডারে সেভ হবে।';
          break;

        case 'hinglish':
          title = '🗓️ Kal Se New Month Start Ho Raha Hai!';
          body = 'Kal aapka is mahine ka pura expenses invoice PDF me convert hokar phone ke Downloads folder me auto-save hoga.';
          break;

        case 'en':
        default:
          title = '🗓️ Month-End Tomorrow: New Month Starting!';
          body = 'Tomorrow all your current month expenses will be converted to a PDF invoice and saved to your phone\'s Downloads folder.';
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Month-End Invoice Alert',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _generalChannelId,
        _generalChannelName,
        channelDescription: _generalChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFFF97316),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        6601,
        title,
        body,
        notificationDetails,
        payload: 'month_end_reminder',
      );
      debugPrint('[NotificationService] Fired Month-End Reminder notification.');
    } catch (e) {
      debugPrint('[NotificationService] Error showing month end notification: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 9. NEW MONTH START ACTION NOTIFICATION (8:00 - 9:00 AM on 1st Day)
  // ──────────────────────────────────────────────────────────
  Future<void> showNewMonthStartNotification({required bool hasExpenses}) async {
    if (!_masterEnabled || !_newMonthStartAlertsEnabled) return;

    try {
      if (!_isInitialized) await initialize();

      String title;
      String body;

      if (hasExpenses) {
        switch (_notificationLanguage) {
          case 'hi':
            title = '🚀 नया महीना शुरू! पुराना इनवॉइस डाउनलोड करें';
            body = 'कृपया ऐप खोलकर अपने पिछले महीने के खर्चों का इनवॉइस PDF डाउनलोड करें और नया महीना शुरू करें।';
            break;

          case 'bn':
            title = '🚀 নতুন মাস শুরু! পুরোনো ইনভয়েস ডাউনলোড করুন';
            body = 'অনুগ্রহ করে অ্যাপ খুলে আপনার গত মাসের খরচের PDF ইনভয়েস ডাউনলোড করে নতুন মাস শুরু করুন।';
            break;

          case 'hinglish':
            title = '🚀 New Month Started! Purana Invoice Download Karein';
            body = 'Please app khol kar apna purane month ke expenses ko invoice PDF me download kar lein aur new month start karein.';
            break;

          case 'en':
          default:
            title = '🚀 New Month Started! Download Previous Invoice';
            body = 'Please open the app to download your previous month\'s expense invoice PDF and start your new month fresh.';
        }
      } else {
        // If user recorded 0 expenses in previous month
        switch (_notificationLanguage) {
          case 'hi':
            title = '🚀 नया महीना शुरू हो चुका है!';
            body = 'ऐप खोलें और नए महीने के लिए अपनी फ्रेश खर्च ट्रैकिंग और बजट शुरू करें।';
            break;

          case 'bn':
            title = '🚀 নতুন মাস শুরু হয়ে গেছে!';
            body = 'অ্যাপ খুলুন এবং এই নতুন মাসের জন্য নতুন খরচ ট্র্যাকিং ও বাজেট শুরু করুন।';
            break;

          case 'hinglish':
            title = '🚀 Naya Mahina Shuru Ho Chuka Hai!';
            body = 'App open karein aur new month ke liye fresh expense tracking aur budget start karein.';
            break;

          case 'en':
          default:
            title = '🚀 Welcome to the New Month!';
            body = 'Open the app and kickstart your fresh expense tracking and budget for this month!';
        }
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'New Month Started',
        htmlFormatSummaryText: false,
      );

      final androidDetails = AndroidNotificationDetails(
        _generalChannelId,
        _generalChannelName,
        channelDescription: _generalChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        color: const Color(0xFF10B981),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        6602,
        title,
        body,
        notificationDetails,
        payload: 'new_month_start',
      );
      debugPrint('[NotificationService] Fired New Month Start notification (hasExpenses=$hasExpenses).');
    } catch (e) {
      debugPrint('[NotificationService] Error showing new month start notification: $e');
    }
  }

  /// Automated check for Month-End (last day 8-9 PM) & New Month Start (1st day 8-9 AM)
  Future<void> checkAndNotifyMonthEndAndNewMonth({required List<Expense> expenses}) async {
    if (!_masterEnabled) return;

    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      // 1. Month-End Check (Last day of current month, evening >= 20:00)
      final tomorrow = now.add(const Duration(days: 1));
      final isLastDayOfMonth = tomorrow.month != now.month;

      if (isLastDayOfMonth && now.hour >= 20 && _monthEndAlertsEnabled) {
        final notifKey = 'notif_fired_month_end_${now.year}_${now.month}';
        final alreadyFired = prefs.getBool(notifKey) ?? false;
        if (!alreadyFired) {
          await showMonthEndReminderNotification();
          await prefs.setBool(notifKey, true);
        }
      }

      // 2. New Month Start Check (1st day of month, morning >= 8:00)
      final isFirstDayOfMonth = now.day == 1;
      if (isFirstDayOfMonth && now.hour >= 8 && _newMonthStartAlertsEnabled) {
        final notifKey = 'notif_fired_new_month_start_${now.year}_${now.month}';
        final alreadyFired = prefs.getBool(notifKey) ?? false;
        if (!alreadyFired) {
          final prevMonth = DateTime(now.year, now.month - 1, 1);
          final prevMonthExpenses = expenses.where((e) {
            if (e.isDeleted) return false;
            return e.transactionDate.year == prevMonth.year && e.transactionDate.month == prevMonth.month;
          }).toList();
          final hasExpenses = prevMonthExpenses.isNotEmpty;

          await showNewMonthStartNotification(hasExpenses: hasExpenses);
          await prefs.setBool(notifKey, true);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error in checkAndNotifyMonthEndAndNewMonth: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 10. TEST NOTIFICATION
  // ──────────────────────────────────────────────────────────
  Future<bool> sendTestNotification({
    String? title,
    String? body,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final hasPermission = await requestNotificationPermission();
      if (!hasPermission) {
        debugPrint('[NotificationService] Notification permission not granted');
        return false;
      }

      String finalTitle = title ?? '';
      String finalBody = body ?? '';

      if (finalTitle.isEmpty) {
        switch (_notificationLanguage) {
          case 'hi':
            finalTitle = '🔔 टेस्ट नोटिफिकेशन: Grow Expense';
            finalBody = 'नोटिफिकेशन सिस्टम ठीक से काम कर रहा है! भाषा: $languageDisplayName';
            break;
          case 'bn':
            finalTitle = '🔔 টেস্ট নোটিফিকেশন: Grow Expense';
            finalBody = 'নোটিফিকেশন সিস্টেম সঠিকভাবে কাজ করছে! ভাষা: $languageDisplayName';
            break;
          case 'hinglish':
            finalTitle = '🔔 Test Notification: Grow Expense';
            finalBody = 'Notification system smoothly kaam kar raha hai! Language: $languageDisplayName';
            break;
          case 'en':
          default:
            finalTitle = '🔔 Test Notification: Grow Expense';
            finalBody = 'Notifications are working perfectly! Language: $languageDisplayName';
        }
      }

      final bigTextStyleInformation = BigTextStyleInformation(
        finalBody,
        htmlFormatBigText: false,
        contentTitle: finalTitle,
        htmlFormatContentTitle: false,
        summaryText: 'Test Alert',
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
        finalTitle,
        finalBody,
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
