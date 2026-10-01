import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_item.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/khata_entry.dart';
import 'app_update_service.dart';

class NotificationService with ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal() {
    loadPreferences();
  }

  factory NotificationService() => instance;

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
  bool _appUpdatesEnabled = true;
  String _notificationLanguage = 'en'; // 'en', 'hi', 'bn', 'hinglish'

  // Getters
  bool get masterEnabled => _masterEnabled;
  bool get budgetAlertsEnabled => _budgetAlertsEnabled;
  bool get subscriptionAlertsEnabled => _subscriptionAlertsEnabled;
  bool get khataAlertsEnabled => _khataAlertsEnabled;
  bool get dailyReminderEnabled => _dailyReminderEnabled;
  bool get splitBillAlertsEnabled => _splitBillAlertsEnabled;
  bool get monthlyReportEnabled => _monthlyReportEnabled;
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
      _appUpdatesEnabled = prefs.getBool('notif_app_updates_enabled') ?? true;
      _notificationLanguage = prefs.getString('notif_language') ?? 'en';
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
  // 8. TEST NOTIFICATION
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
