import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';

class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Grow Expense',
      
      // Tabs & Navigation
      'tab_home': 'Home',
      'tab_business': 'Business',
      'tab_invoices': 'Invoices',
      'tab_khata': 'Khata',
      'tab_analytics': 'Analytics',
      'tab_budgets': 'Budgets',
      'tab_payments': 'Payments',
      'nav_dashboard': 'Dashboard',
      'nav_settings': 'Settings',

      // Speed Dial Actions
      'speed_new_sale': 'New Sale / GST Bill',
      'speed_new_sale_sub': 'Cash / Udhar + Bill PDF',
      'speed_business_expense': 'Business Expense',
      'speed_business_expense_sub': 'Stock, Rent, Bills, Salary',
      'speed_voice_entry': 'AI Voice Entry',
      'speed_voice_entry_sub': 'Speak sale or expense',
      'speed_ocr_scan': 'Smart OCR Scan',
      'speed_ocr_scan_sub': 'Scan vendor bills & receipts',

      // General & Common Actions
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'change': 'Change',
      'search': 'Search',
      'filter': 'Filter',
      'add': 'Add',
      'close': 'Close',
      'done': 'Done',
      'total': 'Total',
      'active': 'Active',
      'configured': 'Configured',
      'personal': 'Personal',
      'business': 'Business',

      // Metrics & Finances
      'sales': 'Sales',
      'expenses': 'Expenses',
      'net_profit': 'Net Profit & Margin',
      'margin': 'Margin',
      'to_receive': 'To Receive',
      'to_pay': 'To Pay',
      'you_will_get': 'You Will Get',
      'you_will_give': 'You Will Give',
      'customer_udhar': 'Customer Udhar',
      'vendor_payable': 'Vendor Payable',
      'total_outstanding': 'Total Outstanding',
      'recent_transactions': 'Recent Transactions',
      'quick_actions': 'Quick Actions',
      'new_sale': 'New Sale',
      'business_expense': 'Business Expense',
      'cash_flow': 'Cash Flow',
      'this_month': 'This Month',
      'today': 'Today',
      'this_week': 'This Week',
      'last_month': 'Last Month',
      'all_time': 'All Time',

      // Settings Headers & Items
      'settings_title': 'Settings',
      'appearance_theme': 'APPEARANCE & THEME',
      'app_theme': 'App Theme',
      'app_language': 'App Language',
      'select_language': 'Select App Language',
      'max_refresh_rate': 'Max Refresh Rate (120Hz / 90Hz)',
      'max_refresh_rate_sub': 'Unlock ultra-smooth frame rate',
      'security_preferences': 'SECURITY & PREFERENCES',
      'biometric_lock': 'Biometric / Device Lock',
      'data_backup': 'DATA & BACKUP',
      'cloud_sync': 'Backup & Cloud Sync',
      'ai_extensions': 'AI & SMART EXTENSIONS',
      'ai_config': 'AI & Smart Recognition',
      'business_settings': 'BUSINESS SETTINGS',
      'notifications_settings': 'NOTIFICATIONS & REMINDERS',
      'notifications': 'Notification Alerts',
      'help_support': 'HELP & SUPPORT',
      'report_issue': 'Report an Issue / Feedback',
      'about_app': 'About Grow Expense',
      'account_session': 'ACCOUNT & SESSION',
      'logout': 'Log Out',
      'delete_account': 'Delete Account',

      // Languages
      'lang_en': 'English (Default)',
      'lang_hi': 'हिंदी (Hindi)',
      'lang_bn': 'বাংলা (Bengali)',
    },
    'hi': {
      'app_name': 'ग्रो एक्सपेंस',

      // Tabs & Navigation
      'tab_home': 'होम',
      'tab_business': 'दुकान/व्यापार',
      'tab_invoices': 'इनवॉइस',
      'tab_khata': 'खाता बुक',
      'tab_analytics': 'एनालिटिक्स',
      'tab_budgets': 'बजट',
      'tab_payments': 'पेमेंट्स',
      'nav_dashboard': 'डैशबोर्ड',
      'nav_settings': 'सेटिंग्स',

      // Speed Dial Actions
      'speed_new_sale': 'नई बिक्री / बिल',
      'speed_new_sale_sub': 'नकद / उधार + बिल PDF',
      'speed_business_expense': 'दुकान का खर्चा',
      'speed_business_expense_sub': 'स्टॉक, किराया, बिजली, सैलरी',
      'speed_voice_entry': 'AI वॉइस एंट्री',
      'speed_voice_entry_sub': 'बोलकर हिसाब जोड़ें',
      'speed_ocr_scan': 'स्मार्ट बिल स्कैन',
      'speed_ocr_scan_sub': 'रसीद व बिल स्कैन करें',

      // General & Common Actions
      'save': 'सुरक्षित करें',
      'cancel': 'रद्द करें',
      'delete': 'हटाएं',
      'edit': 'बदलें',
      'change': 'बदलें',
      'search': 'खोजें',
      'filter': 'फ़िल्टर',
      'add': 'जोड़ें',
      'close': 'बंद करें',
      'done': 'संपन्न',
      'total': 'कुल',
      'active': 'सक्रिय',
      'configured': 'सेट है',
      'personal': 'व्यक्तिगत (Personal)',
      'business': 'व्यापार (Business)',

      // Metrics & Finances
      'sales': 'कुल बिक्री',
      'expenses': 'कुल खर्चे',
      'net_profit': 'शुद्ध लाभ एवं मार्जिन',
      'margin': 'मार्जिन',
      'to_receive': 'पाना है',
      'to_pay': 'देना है',
      'you_will_get': 'आपको मिलेगा',
      'you_will_give': 'आपको देना है',
      'customer_udhar': 'ग्राहक उधार',
      'vendor_payable': 'सप्लायर बकाया',
      'total_outstanding': 'कुल बकाया',
      'recent_transactions': 'हालिया लेनदेन',
      'quick_actions': 'त्वरित कार्य',
      'new_sale': 'नई बिक्री',
      'business_expense': 'दुकान का खर्चा',
      'cash_flow': 'कैश फ्लो',
      'this_month': 'इस महीने',
      'today': 'आज',
      'this_week': 'इस हफ्ते',
      'last_month': 'पिछले महीने',
      'all_time': 'शुरू से अब तक',

      // Settings Headers & Items
      'settings_title': 'सेटिंग्स',
      'appearance_theme': 'दिखावट एवं थीम (APPEARANCE & THEME)',
      'app_theme': 'ऐप थीम',
      'app_language': 'ऐप की भाषा (App Language)',
      'select_language': 'ऐप की भाषा चुनें',
      'max_refresh_rate': 'सुपर स्मूथ फ्रेम रेट (120Hz / 90Hz)',
      'max_refresh_rate_sub': 'अल्ट्रा स्मूथ फ्रेम रेट अनलॉक करें',
      'security_preferences': 'सुरक्षा एवं प्राथमिकताएं',
      'biometric_lock': 'फिंगरप्रिंट / स्क्रीन लॉक',
      'data_backup': 'डेटा एवं बैकअप',
      'cloud_sync': 'बैकअप एवं क्लाउड सिंक',
      'ai_extensions': 'AI एवं स्मार्ट सुविधाएं',
      'ai_config': 'AI सलाहकार एवं मान्यता',
      'business_settings': 'व्यापार सेटिंग्स (GST, दुकान नाम)',
      'notifications_settings': 'नोटिफ़िकेशन एवं रिमाइंडर',
      'notifications': 'अलर्ट्स व नोटिफ़िकेशन',
      'help_support': 'सहायता एवं फ़ीडबैक',
      'report_issue': 'समस्या बताएं / फ़ीडबैक भेजें',
      'about_app': 'ग्रो एक्सपेंस के बारे में',
      'account_session': 'अकाउंट एवं सत्र',
      'logout': 'लॉग आउट',
      'delete_account': 'अकाउंट हटाएं',

      // Languages
      'lang_en': 'English (अंग्रेज़ी)',
      'lang_hi': 'हिंदी (Hindi)',
      'lang_bn': 'বাংলা (बंगाली)',
    },
    'bn': {
      'app_name': 'গ্রো এক্সপেন্স',

      // Tabs & Navigation
      'tab_home': 'হোম',
      'tab_business': 'ব্যবসা/দোকান',
      'tab_invoices': 'ইনভয়েস',
      'tab_khata': 'খাতা বুক',
      'tab_analytics': 'অ্যানালিটিক্স',
      'tab_budgets': 'বাজেট',
      'tab_payments': 'পেমেন্টস',
      'nav_dashboard': 'ড্যাশবোর্ড',
      'nav_settings': 'সেটিংস',

      // Speed Dial Actions
      'speed_new_sale': 'নতুন বিক্রি / বিল',
      'speed_new_sale_sub': 'নগদ / বাকি + বিল PDF',
      'speed_business_expense': 'দোকানের খরচ',
      'speed_business_expense_sub': 'স্টক, ভাড়া, বিল, বেতন',
      'speed_voice_entry': 'AI ভয়েস এন্ট্রি',
      'speed_voice_entry_sub': 'মুখে বলে হিসাব যোগ করুন',
      'speed_ocr_scan': 'স্মার্ট বিল স্ক্যান',
      'speed_ocr_scan_sub': 'রসিদ ও বিল স্ক্যান করুন',

      // General & Common Actions
      'save': 'সংরক্ষণ করুন',
      'cancel': 'বাতিল',
      'delete': 'মুছুন',
      'edit': 'সম্পাদনা',
      'change': 'পরিবর্তন',
      'search': 'অনুসন্ধান',
      'filter': 'ফিল্টার',
      'add': 'যুক্ত করুন',
      'close': 'বন্ধ করুন',
      'done': 'সম্পন্ন',
      'total': 'মোট',
      'active': 'সক্রিয়',
      'configured': 'সেট আছে',
      'personal': 'ব্যক্তিগত (Personal)',
      'business': 'ব্যবসা (Business)',

      // Metrics & Finances
      'sales': 'মোট বিক্রি',
      'expenses': 'মোট খরচ',
      'net_profit': 'নিট লাভ ও মার্জিন',
      'margin': 'মার্জিন',
      'to_receive': 'পাওনা (To Receive)',
      'to_pay': 'দেনা (To Pay)',
      'you_will_get': 'আপনি পাবেন',
      'you_will_give': 'আপনি দেবেন',
      'customer_udhar': 'কাস্টমার বাকি',
      'vendor_payable': 'মহাজন বাকি',
      'total_outstanding': 'মোট বাকি',
      'recent_transactions': 'সাম্প্রতিক লেনদেন',
      'quick_actions': 'দ্রুত অ্যাকশন',
      'new_sale': 'নতুন বিক্রি',
      'business_expense': 'দোকানের খরচ',
      'cash_flow': 'ক্যাশ ফ্লো',
      'this_month': 'এই মাস',
      'today': 'আজ',
      'this_week': 'এই সপ্তাহ',
      'last_month': 'গত মাস',
      'all_time': 'সর্বমোট',

      // Settings Headers & Items
      'settings_title': 'সেটিংস',
      'appearance_theme': 'রূপ ও থিম (APPEARANCE & THEME)',
      'app_theme': 'অ্যাপ থিম',
      'app_language': 'অ্যাপের ভাষা (App Language)',
      'select_language': 'অ্যাপের ভাষা নির্বাচন করুন',
      'max_refresh_rate': 'আল্ট্রা স্মুথ ফ্রেম রেট (120Hz / 90Hz)',
      'max_refresh_rate_sub': 'সুপার স্মুথ ফ্রেম রেট আনলক করুন',
      'security_preferences': 'নিরাপত্তা ও পছন্দ',
      'biometric_lock': 'ফিঙ্গারপ্রিন্ট / স্ক্রিন লক',
      'data_backup': 'ডাটা ও ব্যাকআপ',
      'cloud_sync': 'ব্যাকআপ ও ক্লাউড সিঙ্ক',
      'ai_extensions': 'AI ও স্মার্ট ফিচার',
      'ai_config': 'AI সহকারী কনফিগারেশন',
      'business_settings': 'ব্যবসার সেটিংস (GST, দোকানের নাম)',
      'notifications_settings': 'বিজ্ঞপ্তি ও রিমাইন্ডার',
      'notifications': 'বিজ্ঞপ্তি অ্যালার্ট',
      'help_support': 'সহায়তা ও প্রতিক্রিয়া',
      'report_issue': 'সমস্যা জানান / প্রতিক্রিয়া দিন',
      'about_app': 'গ্রো এক্সপেন্স সম্পর্কে',
      'account_session': 'অ্যাকাউন্ট ও সেশন',
      'logout': 'লগ আউট',
      'delete_account': 'অ্যাকাউন্ট মুছুন',

      // Languages
      'lang_en': 'English (ইংরেজি)',
      'lang_hi': 'हिंदी (হিন্দি)',
      'lang_bn': 'বাংলা (Bengali)',
    },
  };

  /// Get translation by key with context
  static String tr(BuildContext context, String key) {
    try {
      final lang = Provider.of<UserProvider>(context, listen: true).appLanguage;
      return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
    } catch (_) {
      return _localizedValues['en']?[key] ?? key;
    }
  }

  /// Get translation by key and explicit language code
  static String get(String key, [String lang = 'en']) {
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  /// Get human-readable language label with flag
  static String getLanguageLabel(String code) {
    switch (code) {
      case 'hi':
        return '🇮🇳 हिंदी (Hindi)';
      case 'bn':
        return '🇮🇳 বাংলা (Bengali)';
      case 'en':
      default:
        return '🇬🇧 English (Default)';
    }
  }
}
