import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// LOCALIZATION STRINGS (English, Hindi, Bengali)
// ═══════════════════════════════════════════════════════════════════════════

class BackupScopeStrings {
  final String title;
  final String subtitle;
  final String tabBackup;
  final String tabNoBackup;
  final String backupHeaderTitle;
  final String backupHeaderDesc;
  final String noBackupHeaderTitle;
  final String noBackupHeaderDesc;

  // Backup Item Titles & Descs
  final String itemExpensesTitle;
  final String itemExpensesDesc;
  final String itemBudgetsTitle;
  final String itemBudgetsDesc;
  final String itemKhataTitle;
  final String itemKhataDesc;
  final String itemSubsTitle;
  final String itemSubsDesc;
  final String itemSplitsTitle;
  final String itemSplitsDesc;
  final String itemPaymentTitle;
  final String itemPaymentDesc;
  final String itemProfileTitle;
  final String itemProfileDesc;
  final String itemInvoicesTitle;
  final String itemInvoicesDesc;

  // No Backup Item Titles & Descs
  final String itemChatTitle;
  final String itemChatDesc;
  final String itemCalcHistoryTitle;
  final String itemCalcHistoryDesc;
  final String itemBiometricsTitle;
  final String itemBiometricsDesc;
  final String itemThemeTitle;
  final String itemThemeDesc;
  final String itemTempScanTitle;
  final String itemTempScanDesc;

  // Badges
  final String badgeCloud;
  final String badgeLocalOnly;
  final String badgeEncrypted;

  const BackupScopeStrings({
    required this.title,
    required this.subtitle,
    required this.tabBackup,
    required this.tabNoBackup,
    required this.backupHeaderTitle,
    required this.backupHeaderDesc,
    required this.noBackupHeaderTitle,
    required this.noBackupHeaderDesc,
    required this.itemExpensesTitle,
    required this.itemExpensesDesc,
    required this.itemBudgetsTitle,
    required this.itemBudgetsDesc,
    required this.itemKhataTitle,
    required this.itemKhataDesc,
    required this.itemSubsTitle,
    required this.itemSubsDesc,
    required this.itemSplitsTitle,
    required this.itemSplitsDesc,
    required this.itemPaymentTitle,
    required this.itemPaymentDesc,
    required this.itemProfileTitle,
    required this.itemProfileDesc,
    required this.itemInvoicesTitle,
    required this.itemInvoicesDesc,
    required this.itemChatTitle,
    required this.itemChatDesc,
    required this.itemCalcHistoryTitle,
    required this.itemCalcHistoryDesc,
    required this.itemBiometricsTitle,
    required this.itemBiometricsDesc,
    required this.itemThemeTitle,
    required this.itemThemeDesc,
    required this.itemTempScanTitle,
    required this.itemTempScanDesc,
    required this.badgeCloud,
    required this.badgeLocalOnly,
    required this.badgeEncrypted,
  });

  static BackupScopeStrings of(String code) {
    if (code.startsWith('bn')) {
      return const BackupScopeStrings(
        title: 'ব্যাকআপ ও গোপনীয়তা বিবরণ',
        subtitle: 'ক্লাউডে কী সংরক্ষিত হয় এবং কী শুধুমাত্র ডিভাইসে থাকে',
        tabBackup: 'ব্যাকআপ হবে (Cloud)',
        tabNoBackup: 'ব্যাকআপ হবে না (Local)',
        backupHeaderTitle: 'ক্লাউডে নিরাপদ ব্যাকআপ',
        backupHeaderDesc: 'ফোন পরিবর্তন বা অ্যাপ পুনরায় ইনস্টল করলে এই সমস্ত ডেটা স্বয়ংক্রিয়ভাবে পুনরুদ্ধার হবে।',
        noBackupHeaderTitle: '১০০% স্থানীয় ও ব্যক্তিগত ডেটা',
        noBackupHeaderDesc: 'এই সমস্ত ডেটা শুধুমাত্র আপনার ফোনে সুরক্ষিত থাকে এবং কখনোই কোনো সার্ভারে আপলোড হয় না।',
        itemExpensesTitle: 'দৈনিক খরচ ও লেনদেন',
        itemExpensesDesc: 'টাকার পরিমাণ, বিভাগ, বিবরণ, তারিখ, পেমেন্ট মাধ্যম এবং রিকারিং স্ট্যাটাস।',
        itemBudgetsTitle: 'মাসিক বাজেট ও সীমা',
        itemBudgetsDesc: 'প্রতিটি বিভাগের নির্ধারিত মাসিক বাজেট এবং আর্থিক লক্ষ্যমাত্রা।',
        itemKhataTitle: 'খাতা ও বাকি-ধার খতিয়ান',
        itemKhataDesc: 'গ্রাহক/বন্ধুর নাম, ফোন নম্বর, দেওয়া/নেওয়া অর্থ, পরিশোধের তারিখ ও নিষ্পত্তির স্ট্যাটাস।',
        itemSubsTitle: 'সাবস্ক্রিপশন ও নিয়মিত বিল',
        itemSubsDesc: 'সেবার নাম, বিলের পরিমাণ, পরবর্তী বিলিং তারিখ ও রিমাইন্ডার সেটিংস।',
        itemSplitsTitle: 'স্প্লিট বিল ও দলীয় খরচ',
        itemSplitsDesc: 'গ্রুপ বিল, মোট খরচ, সদস্যদের ভাগ এবং নিষ্পত্তির হিসাব।',
        itemPaymentTitle: 'পেমেন্ট ও কিউআর কোড বিবরণ',
        itemPaymentDesc: 'ইউপিআই আইডি এবং ক্লাউড স্টোরেজে সংরক্ষিত কিউআর কোড ইমেজ।',
        itemProfileTitle: 'ব্যবহারকারীর প্রোফাইল',
        itemProfileDesc: 'নাম, অবতার ছবি, পছন্দের মুদ্রা, কাস্টম এআই কি এবং পুশ টোকেন।',
        itemInvoicesTitle: 'মাসিক স্টেটমেন্ট পিডিএফ',
        itemInvoicesDesc: 'PDF ফাইল ক্লাউডে জমা হয় না। প্রয়োজন মতো অ্যাপটি আপনার লেনদেন ডেটা থেকে সরাসরি ফোনে নতুন PDF তৈরি করে নেয়।',
        itemChatTitle: 'এআই চ্যাট বার্তা',
        itemChatDesc: 'সম্পূর্ণ ব্যক্তিগত কথোপকথন যা কেবল আপনার ফোনের SQLite ডেটাবেসে থাকে।',
        itemCalcHistoryTitle: 'ক্যালকুলেটর ইতিহাস',
        itemCalcHistoryDesc: 'সবজির দর, ইএমআই এবং এসআইপি হিসাবের ৫০টি সাম্প্রতিক হিসাব শুধু ডিভাইসে থাকে।',
        itemBiometricsTitle: 'বায়োমেট্রিক ও অ্যাপ লক',
        itemBiometricsDesc: 'ফিঙ্গারপ্রিন্ট ও পিন কোড ফোনের সিকিউর হার্ডওয়্যারে থাকে, ইন্টারনেটে যায় না।',
        itemThemeTitle: 'থিম ও ডিসপ্লে সেটিংস',
        itemThemeDesc: 'ডার্ক/লাইট মোড এবং অন্যান্য ব্যক্তিগত ইন্টারফেস সেটিংস।',
        itemTempScanTitle: 'রসিদ স্ক্যানের অস্থায়ী ফাইল',
        itemTempScanDesc: 'এআই দিয়ে রসিদ স্ক্যান হওয়ার পর ছবি স্বয়ংক্রিয়ভাবে মুছে ফেলা হয়।',
        badgeCloud: 'ক্লাউড সিঙ্ক',
        badgeLocalOnly: 'স্থানীয় নিরাপদ',
        badgeEncrypted: 'এনক্রিপ্টেড',
      );
    } else if (code.startsWith('hi')) {
      return const BackupScopeStrings(
        title: 'बैकअप व प्राइवेसी विवरण',
        subtitle: 'क्लाउड में क्या सेव होता है और क्या सिर्फ फोन में रहता है',
        tabBackup: 'बैकअप होगा (Cloud)',
        tabNoBackup: 'बैकअप नहीं होगा (Local)',
        backupHeaderTitle: 'क्लाउड में सुरक्षित बैकअप',
        backupHeaderDesc: 'फोन बदलने या ऐप री-इंस्टॉल करने पर यह सारा डेटा अपने आप रीस्टोर हो जाएगा।',
        noBackupHeaderTitle: '100% लोकल व प्राइवेट डेटा',
        noBackupHeaderDesc: 'यह डेटा सिर्फ आपके फोन की मेमोरी में सुरक्षित रहता है और कभी क्लाउड पर नहीं जाता।',
        itemExpensesTitle: 'दैनिक खर्चे व लेनदेन',
        itemExpensesDesc: 'खर्च राशि, कैटेगरी, विवरण, तारीख, पेमेंट मोड और रिकरिंग सेटिंग्स।',
        itemBudgetsTitle: 'मासिक बजट व सीमाएं',
        itemBudgetsDesc: 'हर कैटेगरी का तय किया गया बजट और मासिक खर्च सीमा।',
        itemKhataTitle: 'खाता / उधार-बाकी लेज़र',
        itemKhataDesc: 'व्यक्ति का नाम, मोबाइल नंबर, दिया/लिया गया उधार, देय तारीख व सेटलमेंट स्थिति।',
        itemSubsTitle: 'सब्सक्रिप्शन्स व बिल रिमाइंडर्स',
        itemSubsDesc: 'ऐप/सर्विस नाम, बिल राशि, बिलिंग साइकल, रिन्यूअल डेट और रिमाइंडर्स।',
        itemSplitsTitle: 'स्प्लिट बिल्स व ग्रुप खर्चे',
        itemSplitsDesc: 'ग्रुप बिल, कुल राशि, किसने पे किया, प्रत्येक का शेयर व सेटलमेंट।',
        itemPaymentTitle: 'पेमेंट व क्यूआर कोड डिटेल्स',
        itemPaymentDesc: 'प्राइमरी UPI ID और क्लाउड स्टोरेज में सुरक्षित अपलोड किया गया QR कोड।',
        itemProfileTitle: 'यूज़र प्रोफ़ाइल व सेटिंग्स',
        itemProfileDesc: 'नाम, प्रोफ़ाइल फोटो, पसंदीदा करेंसी, कस्टम AI कीज़ और नोटिफिकेशन टोकन।',
        itemInvoicesTitle: 'मासिक स्टेटमेंट (PDFs)',
        itemInvoicesDesc: 'PDF फाइलें क्लाउड में स्टोर नहीं होतीं। जब भी जरूरत हो, ऐप आपके लेनदेन डेटा से सीधे फोन में नया PDF जनरेट करता है।',
        itemChatTitle: 'AI चैट बातचीत',
        itemChatDesc: '100% प्राइवेट बातचीत जो केवल आपके फोन के SQLite डेटाबेस में रहती है।',
        itemCalcHistoryTitle: 'कैलकुलेटर हिसाब इतिहास',
        itemCalcHistoryDesc: 'मंडी भाव, EMI, GST, SIP की 50 हालिया गणनाएं सिर्फ फोन में रहती हैं।',
        itemBiometricsTitle: 'बायोमेट्रिक व ऐप लॉक PIN',
        itemBiometricsDesc: 'फिंगरप्रिंट और PIN फोन के सिक्योर एंक्लेव में रहता है, कभी इंटरनेट पर नहीं जाता।',
        itemThemeTitle: 'ऐप थीम व UI सेटिंग्स',
        itemThemeDesc: 'डार्क/लाइट मोड और स्क्रीन रिफ्रेश रेट सेटिंग्स फोन मेमोरी में सेव रहती हैं।',
        itemTempScanTitle: 'रसीद स्कैन टेम्पररी फ़ाइलें',
        itemTempScanDesc: 'AI से रसीद डेटा निकालने के तुरंत बाद इमेज अपने आप डिलीट हो जाती है।',
        badgeCloud: 'क्लाउड सिंक',
        badgeLocalOnly: 'सिर्फ फोन में',
        badgeEncrypted: 'एन्क्रिप्टेड',
      );
    }

    // Default English
    return const BackupScopeStrings(
      title: 'Backup & Privacy Scope',
      subtitle: 'Know exactly what gets backed up to cloud vs stored privately on device',
      tabBackup: 'Backed Up (Cloud)',
      tabNoBackup: 'No Backup (Local)',
      backupHeaderTitle: 'Secure Cloud Backup',
      backupHeaderDesc: 'Synced to your private Supabase cloud account. Seamlessly restored when you log in on any device.',
      noBackupHeaderTitle: '100% Local & Device-Private',
      noBackupHeaderDesc: 'Stored strictly on your phone’s SQLite memory. Never uploaded to the cloud for complete privacy.',
      itemExpensesTitle: 'Daily Expenses & Transactions',
      itemExpensesDesc: 'Amounts, categories, notes, transaction dates, payment methods, and recurring settings.',
      itemBudgetsTitle: 'Monthly Budgets & Category Limits',
      itemBudgetsDesc: 'Spending targets and limits configured for each expense category.',
      itemKhataTitle: 'Khata / Udhar Ledger',
      itemKhataDesc: 'Customer/borrower names, phone numbers, Give/Got balances, due dates, and settlement status.',
      itemSubsTitle: 'Subscriptions & Recurring Bills',
      itemSubsDesc: 'Service names, billing frequencies, renewal dates, payment methods, and alert reminders.',
      itemSplitsTitle: 'Split Bills & Group Expenses',
      itemSplitsDesc: 'Group bills, participant splits, payer assignments, and settlement progress.',
      itemPaymentTitle: 'Payment Methods & QR Codes',
      itemPaymentDesc: 'Primary UPI IDs and QR code images stored in secure cloud storage buckets.',
      itemProfileTitle: 'User Profile & Preferences',
      itemProfileDesc: 'Full name, profile photo, preferred currency, custom AI keys, and push notification tokens.',
      itemInvoicesTitle: 'Generated Monthly Statements (PDFs)',
      itemInvoicesDesc: 'PDF files are not stored on cloud. Statements are generated on-demand directly on your phone from your synced data.',
      itemChatTitle: 'AI Chat Conversations',
      itemChatDesc: '100% private financial chats stored locally in your SQLite database. Never sent to cloud.',
      itemCalcHistoryTitle: 'Financial Calculator Hub History',
      itemCalcHistoryDesc: 'Mandi rates, EMI, GST, and SIP calculations (stores up to 50 items locally).',
      itemBiometricsTitle: 'Biometrics & App Lock PIN',
      itemBiometricsDesc: 'Fingerprint and PIN credentials protected by Android Secure Keystore. Never sent over internet.',
      itemThemeTitle: 'App Theme & Display Settings',
      itemThemeDesc: 'Dark/Light mode preference, high refresh rate, and animation settings stored in local cache.',
      itemTempScanTitle: 'Receipt Scanner Temporary Cache',
      itemTempScanDesc: 'Scanned receipt photos are automatically wiped immediately after AI extraction.',
      badgeCloud: 'Cloud Synced',
      badgeLocalOnly: 'Local Only',
      badgeEncrypted: 'Encrypted',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BACKUP SCOPE SCREEN WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class BackupScopeScreen extends StatefulWidget {
  const BackupScopeScreen({super.key});

  @override
  State<BackupScopeScreen> createState() => _BackupScopeScreenState();
}

class _BackupScopeScreenState extends State<BackupScopeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _ScopeItemData _getCatalogItemData(String langCode, String badge) {
    if (langCode.startsWith('bn')) {
      return _ScopeItemData(
        title: 'পণ্য ক্যাটালগ ও স্টক ইনভেন্টরি',
        desc: 'পণ্যের নাম, কেনা/বেচা দাম, বারকোড নম্বর, বর্তমান স্টক পরিমাণ ও কম স্টক সতর্কতা সীমা।',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF10B981),
        badge: badge,
      );
    } else if (langCode.startsWith('hi')) {
      return _ScopeItemData(
        title: 'सामान कैटलॉग व इन्वेंटरी स्टॉक',
        desc: 'सामान का नाम, खरीद/बिक्री मूल्य, बारकोड नंबर, स्टॉक मात्रा और लो-स्टॉक सीमा।',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF10B981),
        badge: badge,
      );
    }
    return _ScopeItemData(
      title: 'Product Catalog & Inventory Stock',
      desc: 'Product names, buy/sell prices, barcode numbers, available stock & low-stock limits.',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFF10B981),
      badge: badge,
    );
  }

  _ScopeItemData _getBizSalesItemData(String langCode, String badge) {
    if (langCode.startsWith('bn')) {
      return _ScopeItemData(
        title: 'দোকান বিক্রি ও GST চালান',
        desc: 'কাস্টমার বিল, বিক্রিত পণ্য, ট্যাক্স, ছাড়, নগদ/অনলাইন/বাকি পেমেন্ট ও নিট লাভ।',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF6366F1),
        badge: badge,
      );
    } else if (langCode.startsWith('hi')) {
      return _ScopeItemData(
        title: 'दुकान बिक्री व GST बिलिंग',
        desc: 'ग्राहक बिल, बेचे गए सामान, टैक्स, छूट, नकद/ऑनलाइन/उधार पेमेंट और मुनाफा मार्जिन।',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF6366F1),
        badge: badge,
      );
    }
    return _ScopeItemData(
      title: 'Business Sales & GST Invoices',
      desc: 'Customer sale bills, item lists, GST taxes, discounts, cash/online/udhar payments & profit margins.',
      icon: Icons.point_of_sale_rounded,
      color: const Color(0xFF6366F1),
      badge: badge,
    );
  }

  _ScopeItemData _getBizProfileItemData(String langCode, String badge) {
    if (langCode.startsWith('bn')) {
      return _ScopeItemData(
        title: 'দোকান ও ব্যবসা প্রোফাইল',
        desc: 'দোকানের নাম, মালিকের নাম, মোবাইল নম্বর, ঠিকানা, GSTIN ও সংযুক্ত UPI আইডি।',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF3B82F6),
        badge: badge,
      );
    } else if (langCode.startsWith('hi')) {
      return _ScopeItemData(
        title: 'दुकान व व्यापार प्रोफ़ाइल',
        desc: 'दुकान का नाम, मालिक, मोबाइल नंबर, पता, GSTIN और लिंक्ड UPI पेमेंट ID।',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF3B82F6),
        badge: badge,
      );
    }
    return _ScopeItemData(
      title: 'Shop & Business Profile',
      desc: 'Shop name, contact person, phone number, address, GSTIN and linked UPI QR payment ID.',
      icon: Icons.storefront_rounded,
      color: const Color(0xFF3B82F6),
      badge: badge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final currentLang = userProvider.appLanguage;
    final str = BackupScopeStrings.of(currentLang);
    final cardBg = isDark ? const Color(0xFF181B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          str.title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
      ),
      body: Column(
        children: [
          // Subtitle header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            child: Text(
              str.subtitle,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500], height: 1.3),
            ),
          ),
          const Divider(height: 1),

          // Segment Tab Selector (Backup | No Backup)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _tabController.index == 0
                    ? const Color(0xFF00D09C)
                    : const Color(0xFFEF4444),
                boxShadow: [
                  BoxShadow(
                    color: (_tabController.index == 0
                            ? const Color(0xFF00D09C)
                            : const Color(0xFFEF4444))
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[700],
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_done_rounded, size: 15),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              str.tabBackup,
                              maxLines: 1,
                              style: const TextStyle(letterSpacing: -0.2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phonelink_lock_rounded, size: 15),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              str.tabNoBackup,
                              maxLines: 1,
                              style: const TextStyle(letterSpacing: -0.2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Views Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: BACKUP ITEMS
                _buildBackupList(
                  isDark: isDark,
                  str: str,
                  currentLang: currentLang,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),

                // TAB 2: NO BACKUP ITEMS
                _buildNoBackupList(
                  isDark: isDark,
                  str: str,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupList({
    required bool isDark,
    required BackupScopeStrings str,
    required String currentLang,
    required Color cardBg,
    required Color borderColor,
  }) {
    final items = [
      _ScopeItemData(
        title: str.itemExpensesTitle,
        desc: str.itemExpensesDesc,
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF00D09C),
        badge: str.badgeCloud,
      ),
      _ScopeItemData(
        title: str.itemBudgetsTitle,
        desc: str.itemBudgetsDesc,
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF3B82F6),
        badge: str.badgeCloud,
      ),
      _ScopeItemData(
        title: str.itemKhataTitle,
        desc: str.itemKhataDesc,
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF8B5CF6),
        badge: str.badgeCloud,
      ),
      _ScopeItemData(
        title: str.itemSubsTitle,
        desc: str.itemSubsDesc,
        icon: Icons.event_repeat_rounded,
        color: const Color(0xFFEC4899),
        badge: str.badgeCloud,
      ),
      _ScopeItemData(
        title: str.itemSplitsTitle,
        desc: str.itemSplitsDesc,
        icon: Icons.call_split_rounded,
        color: const Color(0xFFF59E0B),
        badge: str.badgeCloud,
      ),
      _ScopeItemData(
        title: str.itemPaymentTitle,
        desc: str.itemPaymentDesc,
        icon: Icons.qr_code_2_rounded,
        color: const Color(0xFF10B981),
        badge: str.badgeCloud,
      ),
      _ScopeItemData(
        title: str.itemProfileTitle,
        desc: str.itemProfileDesc,
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFF06B6D4),
        badge: str.badgeCloud,
      ),
      _getCatalogItemData(currentLang, str.badgeCloud),
      _getBizSalesItemData(currentLang, str.badgeCloud),
      _getBizProfileItemData(currentLang, str.badgeCloud),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Informative Hero Banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00D09C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00D09C).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_sync_rounded, color: Color(0xFF00D09C), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str.backupHeaderTitle,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF00D09C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      str.backupHeaderDesc,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List of Backed-up Cards
        ...items.map((item) => _buildItemCard(item, isDark, cardBg, borderColor)),
      ],
    );
  }

  Widget _buildNoBackupList({
    required bool isDark,
    required BackupScopeStrings str,
    required Color cardBg,
    required Color borderColor,
  }) {
    final items = [
      _ScopeItemData(
        title: str.itemInvoicesTitle,
        desc: str.itemInvoicesDesc,
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFFF97316),
        badge: str.badgeLocalOnly,
      ),
      _ScopeItemData(
        title: str.itemChatTitle,
        desc: str.itemChatDesc,
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF6366F1),
        badge: str.badgeLocalOnly,
      ),
      _ScopeItemData(
        title: str.itemCalcHistoryTitle,
        desc: str.itemCalcHistoryDesc,
        icon: Icons.calculate_rounded,
        color: const Color(0xFF0EA5E9),
        badge: str.badgeLocalOnly,
      ),
      _ScopeItemData(
        title: str.itemBiometricsTitle,
        desc: str.itemBiometricsDesc,
        icon: Icons.fingerprint_rounded,
        color: const Color(0xFF10B981),
        badge: str.badgeEncrypted,
      ),
      _ScopeItemData(
        title: str.itemThemeTitle,
        desc: str.itemThemeDesc,
        icon: Icons.palette_rounded,
        color: const Color(0xFFF59E0B),
        badge: str.badgeLocalOnly,
      ),
      _ScopeItemData(
        title: str.itemTempScanTitle,
        desc: str.itemTempScanDesc,
        icon: Icons.document_scanner_rounded,
        color: const Color(0xFFEC4899),
        badge: str.badgeLocalOnly,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Informative Hero Banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.phonelink_lock_rounded, color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str.noBackupHeaderTitle,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      str.noBackupHeaderDesc,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List of Non-Backed-up Cards
        ...items.map((item) => _buildItemCard(item, isDark, cardBg, borderColor)),
      ],
    );
  }

  Widget _buildItemCard(
    _ScopeItemData item,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: item.color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        item.badge,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.desc,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeItemData {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final String badge;

  const _ScopeItemData({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.badge,
  });
}
