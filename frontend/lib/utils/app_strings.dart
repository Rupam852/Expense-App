import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';

class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Grow Expense',
      // Navigation
      'nav_dashboard': 'Dashboard',
      'nav_analytics': 'Analytics',
      'nav_split': 'Split Bill',
      'nav_khata': 'Khata Book',
      'nav_settings': 'Settings',
      'nav_invoices': 'Invoices',

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
      'total_outstanding': 'Total Outstanding Balance',
      'recent_transactions': 'Recent Transactions',
      'quick_actions': 'Quick Actions',
      'new_sale': 'New Sale',
      'business_expense': 'Business Expense',

      // Settings
      'settings_title': 'Settings',
      'appearance_theme': 'APPEARANCE & THEME',
      'app_theme': 'App Theme',
      'app_language': 'App Language',
      'select_language': 'Select App Language',
      'max_refresh_rate': 'Max Refresh Rate (120Hz / 90Hz)',
      'biometric_lock': 'Biometric / Device Lock',
      'ai_config': 'AI & Smart Recognition',
      'cloud_sync': 'Backup & Cloud Sync',
      'business_settings': 'Business Settings',
      'notifications': 'Notifications & Reminders',
      'help_support': 'Help & Support',

      // Languages
      'lang_en': 'English (Default)',
      'lang_hi': 'हिंदी (Hindi)',
      'lang_bn': 'বাংলা (Bengali)',
    },
    'hi': {
      'app_name': 'ग्रो एक्सपेंस',
      // Navigation
      'nav_dashboard': 'डैशबोर्ड',
      'nav_analytics': 'एनालिटिक्स',
      'nav_split': 'बिल स्प्लिट',
      'nav_khata': 'खाता बुक',
      'nav_settings': 'सेटिंग्स',
      'nav_invoices': 'इनवॉइस',

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

      // Metrics & Finances
      'sales': 'कुल बिक्री (Sales)',
      'expenses': 'कुल खर्चे (Expenses)',
      'net_profit': 'शुद्ध लाभ एवं मार्जिन',
      'margin': 'मार्जिन',
      'to_receive': 'पाना है (To Receive)',
      'to_pay': 'देना है (To Pay)',
      'you_will_get': 'आपको मिलेगा',
      'you_will_give': 'आपको देना है',
      'customer_udhar': 'ग्राहक उधार',
      'vendor_payable': 'सप्लायर बकाया',
      'total_outstanding': 'कुल बकाया बैलेंस',
      'recent_transactions': 'हालिया लेनदेन',
      'quick_actions': 'त्वरित कार्य',
      'new_sale': 'नई बिक्री',
      'business_expense': 'दुकान का खर्चा',

      // Settings
      'settings_title': 'सेटिंग्स',
      'appearance_theme': 'दिखावट एवं थीम',
      'app_theme': 'ऐप थीम',
      'app_language': 'ऐप की भाषा (Language)',
      'select_language': 'ऐप की भाषा चुनें',
      'max_refresh_rate': 'सुपर स्मूथ फ्रेम रेट (120Hz / 90Hz)',
      'biometric_lock': 'फिंगरप्रिंट / स्क्रीन लॉक',
      'ai_config': 'AI सलाहकार एवं मान्यता',
      'cloud_sync': 'बैकअप एवं क्लाउड सिंक',
      'business_settings': 'व्यापार सेटिंग्स',
      'notifications': 'नोटिफ़िकेशन एवं रिमाइंडर',
      'help_support': 'सहायता एवं फ़ीडबैक',

      // Languages
      'lang_en': 'English (अंग्रेज़ी)',
      'lang_hi': 'हिंदी (Hindi)',
      'lang_bn': 'বাংলা (बंगाली)',
    },
    'bn': {
      'app_name': 'গ্রো এক্সপেন্স',
      // Navigation
      'nav_dashboard': 'ড্যাশবোর্ড',
      'nav_analytics': 'অ্যানালিটিক্স',
      'nav_split': 'বিল ভাগ',
      'nav_khata': 'খাতা বুক',
      'nav_settings': 'সেটিংস',
      'nav_invoices': 'ইনভয়েস',

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

      // Metrics & Finances
      'sales': 'মোট বিক্রি (Sales)',
      'expenses': 'মোট খরচ (Expenses)',
      'net_profit': 'নিট লাভ ও মার্জিন',
      'margin': 'মার্জিন',
      'to_receive': 'পাওনা (To Receive)',
      'to_pay': 'দেনা (To Pay)',
      'you_will_get': 'আপনি পাবেন',
      'you_will_give': 'আপনি দেবেন',
      'customer_udhar': 'কাস্টমার ধার',
      'vendor_payable': 'মহাজন বাকি',
      'total_outstanding': 'মোট বাকি ব্যালেন্স',
      'recent_transactions': 'সাম্প্রতিক লেনদেন',
      'quick_actions': 'দ্রুত অ্যাকশন',
      'new_sale': 'নতুন বিক্রি',
      'business_expense': 'দোকানের খরচ',

      // Settings
      'settings_title': 'সেটিংস',
      'appearance_theme': 'রূপ ও থিম',
      'app_theme': 'অ্যাপ থিম',
      'app_language': 'অ্যাপের ভাষা (Language)',
      'select_language': 'অ্যাপের ভাষা নির্বাচন করুন',
      'max_refresh_rate': 'আল্ট্রা স্মুথ ফ্রেম রেট (120Hz / 90Hz)',
      'biometric_lock': 'ফিঙ্গারপ্রিন্ট / স্ক্রিন লক',
      'ai_config': 'AI সহকারী কনফিগারেশন',
      'cloud_sync': 'ব্যাকআপ ও ক্লাউড সিঙ্ক',
      'business_settings': 'ব্যবসার সেটিংস',
      'notifications': 'বিজ্ঞপ্তি ও রিমাইন্ডার',
      'help_support': 'সহায়তা ও প্রতিক্রিয়া',

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
