import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTED LANGUAGES FOR BACKUP SCOPE SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class BackupScopeLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const BackupScopeLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

const String kPrefBackupScopeLang = 'backup_scope_lang_code';

const List<BackupScopeLanguage> kSupportedBackupScopeLanguages = [
  BackupScopeLanguage(code: 'en_IN', name: 'English', nativeName: 'English (India)', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'bn_IN', name: 'Bengali', nativeName: 'বাংলা (ভারত)', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'hi_IN', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'hinglish', name: 'Hinglish', nativeName: 'Colloquial Mix', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'ta_IN', name: 'Tamil', nativeName: 'தமிழ்', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'te_IN', name: 'Telugu', nativeName: 'తెలుగు', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'mr_IN', name: 'Marathi', nativeName: 'मराठी', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'gu_IN', name: 'Gujarati', nativeName: 'ગુજરાતી', flag: '🇮🇳'),
  BackupScopeLanguage(code: 'kn_IN', name: 'Kannada', nativeName: 'ಕನ್ನಡ', flag: '🇮🇳'),
];

// ═══════════════════════════════════════════════════════════════════════════
// LOCALIZATION STRINGS
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
  final String selectLanguage;
  final String selectLanguageDesc;
  final String langUpdated;

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
    required this.selectLanguage,
    required this.selectLanguageDesc,
    required this.langUpdated,
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
        selectLanguage: 'ভাষা নির্বাচন করুন',
        selectLanguageDesc: 'আপনার পছন্দের ভাষায় ব্যাকআপ সংক্রান্ত তথ্য দেখুন।',
        langUpdated: 'ভাষা সফলভাবে পরিবর্তিত হয়েছে 🌐',
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
        itemInvoicesDesc: 'তৈরি করা সর্বশেষ ১৫টি মাসিক পিডিএফ স্টেটমেন্ট নিরাপদে সংরক্ষিত থাকে।',
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
    } else if (code.startsWith('hi') || code == 'hinglish') {
      return const BackupScopeStrings(
        title: 'बैकअप व प्राइवेसी विवरण',
        subtitle: 'क्लाउड में क्या सेव होता है और क्या सिर्फ फोन में रहता है',
        tabBackup: 'बैकअप होगा (Cloud)',
        tabNoBackup: 'बैकअप नहीं होगा (Local)',
        backupHeaderTitle: 'क्लाउड में सुरक्षित बैकअप',
        backupHeaderDesc: 'फोन बदलने या ऐप री-इंस्टॉल करने पर यह सारा डेटा अपने आप रीस्टोर हो जाएगा।',
        noBackupHeaderTitle: '100% लोकल व प्राइवेट डेटा',
        noBackupHeaderDesc: 'यह डेटा सिर्फ आपके फोन की मेमोरी में सुरक्षित रहता है और कभी क्लाउड पर नहीं जाता।',
        selectLanguage: 'भाषा चुनें',
        selectLanguageDesc: 'अपनी पसंदीदा भाषा में बैकअप का पूरा विवरण देखें।',
        langUpdated: 'भाषा सफलतापूर्वक बदली गई 🌐',
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
        itemInvoicesDesc: 'जनरेट किए गए मासिक PDF स्टेटमेंट्स (अधिकतम 15 स्टेटमेंट्स क्लाउड में सेफ़)।',
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
    } else if (code.startsWith('ta')) {
      return const BackupScopeStrings(
        title: 'காப்புப்பிரதி மற்றும் தனியுரிமை',
        subtitle: 'கிளவுடில் எது சேமிக்கப்படுகிறது மற்றும் போனில் மட்டுமே இருப்பது எது',
        tabBackup: 'காப்புப்பிரதி (Cloud)',
        tabNoBackup: 'காப்புப்பிரதி இல்லை (Local)',
        backupHeaderTitle: 'கிளவுடில் பாதுகாப்பான காப்புப்பிரதி',
        backupHeaderDesc: 'போனை மாற்றினாலும் இந்தத் தரவு தானாகவே மீட்டமைக்கப்படும்.',
        noBackupHeaderTitle: '100% உள்ளூர் மற்றும் தனிப்பட்ட தரவு',
        noBackupHeaderDesc: 'இந்தத் தரவு உங்கள் போனில் மட்டுமே இருக்கும், சேவையகத்திற்கு பதிவேற்றப்படாது.',
        selectLanguage: 'மொழியைத் தேர்ந்தெடுக்கவும்',
        selectLanguageDesc: 'உங்கள் விருப்பமான மொழியில் தகவல்களைக் காண்க.',
        langUpdated: 'மொழி மாற்றப்பட்டது 🌐',
        itemExpensesTitle: 'செலவுகள் மற்றும் பரிவர்த்தனைகள்',
        itemExpensesDesc: 'தொகை, வகை, விவரம், தேதி மற்றும் கட்டண முறை.',
        itemBudgetsTitle: 'மாதாந்திர வரவு செலவு திட்டம்',
        itemBudgetsDesc: 'ஒவ்வொரு வகைக்குமான மாதாந்திர வரம்புகள்.',
        itemKhataTitle: 'கடன் / உதார்கணக்கு',
        itemKhataDesc: 'பெயர், தொலைபேசி எண், கடன் தொகை மற்றும் நிலுவைத் தேதி.',
        itemSubsTitle: 'சந்தாக்கள் மற்றும் கட்டணங்கள்',
        itemSubsDesc: 'சேவை பெயர், தொகை, புதுப்பித்தல் தேதி மற்றும் நினைவூட்டல்கள்.',
        itemSplitsTitle: 'பகிர்வு பில்கள்',
        itemSplitsDesc: 'குழு பில்கள், மொத்த தொகை மற்றும் பகிர்வு கணக்குகள்.',
        itemPaymentTitle: 'கட்டண விவரங்கள் & QR குறியீடு',
        itemPaymentDesc: 'UPI ஐடி மற்றும் பாதுகாப்பான QR குறியீடு படங்கள்.',
        itemProfileTitle: 'பயனர் சுயவிவரம்',
        itemProfileDesc: 'பெயர், அவதார், நாணயம் மற்றும் தனிப்பயன் விசைகள்.',
        itemInvoicesTitle: 'மாதாந்திர அறிக்கைகள் (PDF)',
        itemInvoicesDesc: 'உருவாக்கப்பட்ட சமீபத்திய 15 PDF அறிக்கைகள்.',
        itemChatTitle: 'AI அரட்டை உரையாடல்கள்',
        itemChatDesc: 'போனில் மட்டுமே உள்ள 100% தனிப்பட்ட உரையாடல்கள்.',
        itemCalcHistoryTitle: 'கால்குலேட்டர் வரலாறு',
        itemCalcHistoryDesc: 'சந்தை விலை மற்றும் EMI வரலாற்றின் 50 பதிவுகள்.',
        itemBiometricsTitle: 'பயோமெட்ரிக் & ஆப் லாக்',
        itemBiometricsDesc: 'கைரேகை மற்றும் பின் போனின் பாதுகாப்பான நினைவகத்தில் சேமிக்கப்படுகிறது.',
        itemThemeTitle: 'தீம் அமைப்புகள்',
        itemThemeDesc: 'டார்க்/லைட் பயன்முறை அமைப்புகள்.',
        itemTempScanTitle: 'ஸ்கேன் செய்யப்பட்ட தற்காலிக கோப்புகள்',
        itemTempScanDesc: 'AI செயலாக்கத்திற்குப் பிறகு ரசீது படங்கள் தானாக நீக்கப்படும்.',
        badgeCloud: 'கிளவுட் ஒத்திசைவு',
        badgeLocalOnly: 'உள்ளூர் மட்டும்',
        badgeEncrypted: 'குறியாக்கம்',
      );
    } else if (code.startsWith('te')) {
      return const BackupScopeStrings(
        title: 'బ్యాకప్ మరియు గోప్యతా వివరాలు',
        subtitle: 'క్లౌడ్‌లో ఏమి సేవ్ చేయబడుతుంది మరియు ఫోన్‌లో మాత్రమే ఉండేది ఏమిటి',
        tabBackup: 'బ్యాకప్ అవుతుంది (Cloud)',
        tabNoBackup: 'బ్యాకప్ కాదు (Local)',
        backupHeaderTitle: 'క్లౌడ్‌లో సురక్షిత బ్యాకప్',
        backupHeaderDesc: 'ఫోన్ మార్చినా ఈ డేటా స్వయంచాలకంగా పునరుద్ధరించబడుతుంది.',
        noBackupHeaderTitle: '100% స్థానిక మరియు వ్యక్తిగత డేటా',
        noBackupHeaderDesc: 'ఈ డేటా మీ ఫోన్‌లో మాత్రమే సురక్షితంగా ఉంటుంది, క్లౌడ్‌కు అప్‌లోడ్ చేయబడదు.',
        selectLanguage: 'భాషను ఎంచుకోండి',
        selectLanguageDesc: 'మీకు నచ్చిన భాషలో వివరాలను చూడండి.',
        langUpdated: 'భాష విజయవంతంగా మార్చబడింది 🌐',
        itemExpensesTitle: 'ఖర్చులు మరియు లావాదేవీలు',
        itemExpensesDesc: 'మొత్తం, వర్గం, వివరణ, తేదీ మరియు చెల్లింపు విధానం.',
        itemBudgetsTitle: 'నెలవారీ బడ్జెట్ పరిమితులు',
        itemBudgetsDesc: 'ప్రతి వర్గానికి నిర్ణయించిన బడ్జెట్.',
        itemKhataTitle: 'ఖాతా మరియు అప్పుల లెక్కలు',
        itemKhataDesc: 'పేరు, ఫోన్ నంబర్, ఇచ్చిన/తీసుకున్న మొత్తం మరియు గడువు తేదీ.',
        itemSubsTitle: 'సబ్‌స్క్రిప్షన్లు మరియు బిల్లులు',
        itemSubsDesc: 'సర్వీస్ పేరు, మొత్తం, పునరుద్ధరణ తేదీ మరియు రిమైండర్లు.',
        itemSplitsTitle: 'స్ప్లిట్ బిల్లులు',
        itemSplitsDesc: 'గ్రూప్ బిల్లులు, మొత్తం మరియు వ్యక్తుల వాటాలు.',
        itemPaymentTitle: 'చెల్లింపు వివరాలు & QR కోడ్',
        itemPaymentDesc: 'UPI ID మరియు సురక్షిత QR కోడ్ చిత్రాలు.',
        itemProfileTitle: 'వినియోగదారు ప్రొఫైల్',
        itemProfileDesc: 'పేరు, అవతార్, కరెన్సీ మరియు నోటిఫికేషన్ టోకెన్.',
        itemInvoicesTitle: 'నెలవారీ స్టేట్‌మెంట్‌లు (PDF)',
        itemInvoicesDesc: 'క్లౌడ్‌లో భద్రపరచబడిన తాజా 15 PDF స్టేట్‌మెంట్‌లు.',
        itemChatTitle: 'AI చాట్ సంభాషణలు',
        itemChatDesc: 'మీ ఫోన్ SQLite డేటాబేస్‌లో మాత్రమే ఉండే 100% ప్రైవేట్ చాట్.',
        itemCalcHistoryTitle: 'కాలిక్యులేటర్ చరిత్ర',
        itemCalcHistoryDesc: 'మార్కెట్ ధరలు, EMI మరియు SIP 50 ఇటీవలి రికార్డులు.',
        itemBiometricsTitle: 'బయోమెట్రిక్ & యాప్ లాక్',
        itemBiometricsDesc: 'ఫింగర్‌ప్రింట్ మరియు పిన్ ఫోన్ సెక్యూర్ ఎన్‌క్లేవ్‌లో ఉంటాయి.',
        itemThemeTitle: 'యాప్ థీమ్ సెట్టింగ్‌లు',
        itemThemeDesc: 'డార్క్/లైట్ మోడ్ ప్రాధాన్యతలు.',
        itemTempScanTitle: 'తాత్కాలిక స్కాన్ ఫైళ్లు',
        itemTempScanDesc: 'AI ప్రాసెసింగ్ తర్వాత రసీదు ఫోటోలు స్వయంచాలకంగా తొలగించబడతాయి.',
        badgeCloud: 'క్లౌడ్ సింక్',
        badgeLocalOnly: 'స్థానిక మాత్రమే',
        badgeEncrypted: 'ఎన్‌క్రిప్ట్ చేయబడింది',
      );
    } else if (code.startsWith('mr')) {
      return const BackupScopeStrings(
        title: 'बॅकअप व गोपनीयता तपशील',
        subtitle: 'क्लाउडवर काय सेव्ह होते आणि काय फक्त फोनमध्ये राहते',
        tabBackup: 'बॅकअप होईल (Cloud)',
        tabNoBackup: 'बॅकअप होणार नाही (Local)',
        backupHeaderTitle: 'क्लाउडवर सुरक्षित बॅकअप',
        backupHeaderDesc: 'फोन बदलल्यास किंवा अ‍ॅप री-इन्स्टॉल केल्यास हा डेटा आपोआप परत मिळेल.',
        noBackupHeaderTitle: '100% स्थानिक व खाजगी डेटा',
        noBackupHeaderDesc: 'हा डेटा फक्त तुमच्या फोनमध्ये सुरक्षित राहतो आणि कधीही सर्व्हरवर जात नाही.',
        selectLanguage: 'भाषा निवडा',
        selectLanguageDesc: 'तुमच्या पसंतीच्या भाषेत तपशील पहा.',
        langUpdated: 'भाषा यशस्वीरित्या बदलली 🌐',
        itemExpensesTitle: 'दैनिक खर्च व व्यवहार',
        itemExpensesDesc: 'खर्च रक्कम, श्रेणी, तपशील, तारीख आणि पेमेंट मोड.',
        itemBudgetsTitle: 'मासिक बजेट व मर्यादा',
        itemBudgetsDesc: 'प्रत्येक श्रेणीसाठी ठरवलेले बजेट आणि मासिक मर्यादा.',
        itemKhataTitle: 'खाते व उधारी लेझर',
        itemKhataDesc: 'व्यक्तीचे नाव, फोन नंबर, दिलेली/घेतलेली रक्कम आणि सेटलमेंट स्थिती.',
        itemSubsTitle: 'सदस्यता व नियमित बिले',
        itemSubsDesc: 'अ‍ॅप/सर्व्हिस नाव, बिलाची रक्कम, रिन्यूअल तारीख आणि रिमाइंडर्स.',
        itemSplitsTitle: 'स्प्लिट बिले व ग्रुप खर्च',
        itemSplitsDesc: 'ग्रुप बिल, एकूण रक्कम, प्रत्येकाचा वाटा आणि हिशोब.',
        itemPaymentTitle: 'पेमेंट तपशील व QR कोड',
        itemPaymentDesc: 'UPI आयडी आणि क्लाउडवर सुरक्षित ठेवलेला QR कोड.',
        itemProfileTitle: 'वापरकर्ता प्रोफाइल',
        itemProfileDesc: 'नाव, प्रोफाइल फोटो, चलन आणि सूचना टोकन.',
        itemInvoicesTitle: 'मासिक स्टेटमेंट (PDF)',
        itemInvoicesDesc: 'तयार केलेली नवीनतम 15 मासिक PDF स्टेटमेंट्स.',
        itemChatTitle: 'AI चॅट संभाषणे',
        itemChatDesc: '100% खाजगी संभाषणे जी फक्त फोनच्या SQLite डेटाबेसमध्ये राहतात.',
        itemCalcHistoryTitle: 'कॅल्क्युलेटर इतिहास',
        itemCalcHistoryDesc: 'बाजार भाव, EMI, GST आणि SIP च्या 50 अलीकडील नोंदी.',
        itemBiometricsTitle: 'बायोमेट्रिक व अ‍ॅप लॉक',
        itemBiometricsDesc: 'फिंगरप्रिंट आणि पिन फोनच्या सुरक्षित मेमरीमध्ये राहतात.',
        itemThemeTitle: 'थीम व डिस्प्ले सेटिंग्ज',
        itemThemeDesc: 'डार्क/लाइट मोड प्राधान्ये.',
        itemTempScanTitle: 'तात्पुरत्या स्कॅन फाइल्स',
        itemTempScanDesc: 'AI द्वारे डेटा काढल्यानंतर पावत्यांचे फोटो आपोआप हटवले जातात.',
        badgeCloud: 'क्लाउड सिंक',
        badgeLocalOnly: 'फक्त फोनमध्ये',
        badgeEncrypted: 'एनक्रिप्टेड',
      );
    } else if (code.startsWith('gu')) {
      return const BackupScopeStrings(
        title: 'બેકઅપ અને ગોપનીયતા વિગતો',
        subtitle: 'ક્લાઉડમાં શું સાચવવામાં આવે છે અને શું માત્ર ફોનમાં રહે છે',
        tabBackup: 'બેકઅપ થશે (Cloud)',
        tabNoBackup: 'બેકઅપ નહીં થાય (Local)',
        backupHeaderTitle: 'ક્લાઉડમાં સુરક્ષિત બેકઅપ',
        backupHeaderDesc: 'ફોન બદલવા પર આ તમામ ડેટા આપમેળે પુનઃપ્રાપ્ત થઈ જશે.',
        noBackupHeaderTitle: '100% સ્થાનિક અને ખાનગી ડેટા',
        noBackupHeaderDesc: 'આ ડેટા ફક્ત તમારા ફોનમાં રહે છે અને સર્વર પર અપલોડ થતો નથી.',
        selectLanguage: 'ભાષા પસંદ કરો',
        selectLanguageDesc: 'તમારી મનપસંદ ભાષામાં વિગતો જુઓ.',
        langUpdated: 'ભાષા સફળતાપૂર્વક બદલાઈ 🌐',
        itemExpensesTitle: 'દૈનિક ખર્ચા અને વ્યવહારો',
        itemExpensesDesc: 'ખર્ચ રકમ, શ્રેણી, વિગત, તારીખ અને ચુકવણી મોડ.',
        itemBudgetsTitle: 'માસિક બજેટ અને મર્યાદા',
        itemBudgetsDesc: 'દરેક શ્રેણીનું નિર્ધારિત બજેટ.',
        itemKhataTitle: 'ખાતાવહી અને ઉધાર-જમા',
        itemKhataDesc: 'વ્યક્તિનું નામ, ફોન નંબર, આપેલ/લીધેલ રકમ અને બાકી તારીખ.',
        itemSubsTitle: 'સબ્સ્ક્રિપ્શન્સ અને બિલ',
        itemSubsDesc: 'સેવાનું નામ, બિલ રકમ, રિન્યુઅલ તારીખ અને રિમાઇન્ડર્સ.',
        itemSplitsTitle: 'સ્પ્લિટ બિલ અને ગ્રુપ ખર્ચા',
        itemSplitsDesc: 'ગ્રુપ બિલ, કુલ રકમ અને દરેકનો હિસ્સો.',
        itemPaymentTitle: 'ચુકવણી વિગતો અને QR કોડ',
        itemPaymentDesc: 'UPI ID અને સુરક્ષિત QR કોડ ઈમેજ.',
        itemProfileTitle: 'વપરાશકર્તા પ્રોફાઇલ',
        itemProfileDesc: 'નામ, અવતાર, ચલણ અને કસ્ટમ કીઝ.',
        itemInvoicesTitle: 'માસિક સ્ટેટમેન્ટ્સ (PDF)',
        itemInvoicesDesc: 'ક્લાઉડમાં સાચવેલા છેલ્લા 15 PDF સ્ટેટમેન્ટ્સ.',
        itemChatTitle: 'AI ચેટ વાતચીત',
        itemChatDesc: '100% ખાનગી વાતચીત જે ફક્ત ફોનના SQLite ડેટાબેઝમાં રહે છે.',
        itemCalcHistoryTitle: 'કેલ્ક્યુલેટર ઇતિહાસ',
        itemCalcHistoryDesc: 'બજાર ભાવ અને EMI ના 50 તાજેતરના હિસાબ.',
        itemBiometricsTitle: 'બાયોમેટ્રિક અને એપ લૉક',
        itemBiometricsDesc: 'ફિંગરપ્રિન્ટ અને પિન ફોનની સુરક્ષિત મેમરીમાં રહે છે.',
        itemThemeTitle: 'થીમ સેટિંગ્સ',
        itemThemeDesc: 'ડાર્ક/લાઇટ મોડ પસંદગીઓ.',
        itemTempScanTitle: 'કામચલાઉ સ્કેન ફાઇલો',
        itemTempScanDesc: 'AI પ્રોસેસિંગ પછી રસીદના ફોટા આપમેળે કાઢી નાખવામાં આવે છે.',
        badgeCloud: 'ક્લાઉડ સિંક',
        badgeLocalOnly: 'માત્ર ફોનમાં',
        badgeEncrypted: 'એન્ક્રિપ્ટેડ',
      );
    } else if (code.startsWith('kn')) {
      return const BackupScopeStrings(
        title: 'ಬ್ಯಾಕಪ್ ಮತ್ತು ಗೌಪ್ಯತೆ ವಿವರಗಳು',
        subtitle: 'ಕ್ಲೌಡ್‌ನಲ್ಲಿ ಏನು ಉಳಿಸಲಾಗುತ್ತದೆ ಮತ್ತು ಫೋನ್‌ನಲ್ಲಿ ಮಾತ್ರ ಉಳಿಯುವುದು ಏನು',
        tabBackup: 'ಬ್ಯಾಕಪ್ ಆಗುತ್ತದೆ (Cloud)',
        tabNoBackup: 'ಬ್ಯಾಕಪ್ ಆಗುವುದಿಲ್ಲ (Local)',
        backupHeaderTitle: 'ಕ್ಲೌಡ್‌ನಲ್ಲಿ ಸುರಕ್ಷಿತ ಬ್ಯಾಕಪ್',
        backupHeaderDesc: 'ಫೋನ್ ಬದಲಾಯಿಸಿದರೂ ಈ ಎಲ್ಲಾ ಡೇಟಾ ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಮರುಸ್ಥಾಪನೆಯಾಗುತ್ತದೆ.',
        noBackupHeaderTitle: '100% ಸ್ಥಳೀಯ ಮತ್ತು ಖಾಸಗಿ ಡೇಟಾ',
        noBackupHeaderDesc: 'ಈ ಡೇಟಾ ನಿಮ್ಮ ಫೋನ್‌ನಲ್ಲಿ ಮಾತ್ರ ಇರುತ್ತದೆ ಮತ್ತು ಸರ್ವರ್‌ಗೆ ಅಪ್‌ಲೋಡ್ ಆಗುವುದಿಲ್ಲ.',
        selectLanguage: 'ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ',
        selectLanguageDesc: 'ನಿಮ್ಮ ನೆಚ್ಚಿನ ಭಾಷೆಯಲ್ಲಿ ವಿವರಗಳನ್ನು ನೋಡಿ.',
        langUpdated: 'ಭಾಷೆ ಯಶಸ್ವಿಯಾಗಿ ಬದಲಾಗಿದೆ 🌐',
        itemExpensesTitle: 'ದೈನಂದಿನ ಖರ್ಚುಗಳು ಮತ್ತು ವಹಿವಾಟುಗಳು',
        itemExpensesDesc: 'ಮೊತ್ತ, ವರ್ಗ, ವಿವರಣೆ, ದಿನಾಂಕ ಮತ್ತು ಪಾವತಿ ವಿಧಾನ.',
        itemBudgetsTitle: 'ಮಾಸಿಕ ಬಜೆಟ್ ಮತ್ತು ಮಿತಿಗಳು',
        itemBudgetsDesc: 'ಪ್ರತಿ ವರ್ಗಕ್ಕೆ ನಿಗದಿಪಡಿಸಿದ ಬಜೆಟ್.',
        itemKhataTitle: 'ಖಾತೆ ಮತ್ತು ಸಾಲದ ಲೆಕ್ಕಗಳು',
        itemKhataDesc: 'ಹೆಸರು, ಫೋನ್ ಸಂಖ್ಯೆ, ನೀಡಿದ/ಪಡೆದ ಮೊತ್ತ ಮತ್ತು ಅಂತಿಮ ದಿನಾಂಕ.',
        itemSubsTitle: 'ಚಂದಾದಾರಿಕೆಗಳು ಮತ್ತು ಬಿಲ್‌ಗಳು',
        itemSubsDesc: 'ಸೇವೆಯ ಹೆಸರು, ಬಿಲ್ ಮೊತ್ತ, ನವೀಕರಣ ದಿನಾಂಕ ಮತ್ತು ಜ್ಞಾಪನೆಗಳು.',
        itemSplitsTitle: 'ಸ್ಪ್ಲಿಟ್ ಬಿಲ್‌ಗಳು ಮತ್ತು ಗುಂಪು ಖರ್ಚುಗಳು',
        itemSplitsDesc: 'ಗುಂಪು ಬಿಲ್‌ಗಳು, ಒಟ್ಟು ಮೊತ್ತ ಮತ್ತು ಪ್ರತಿಯೊಬ್ಬರ ಪಾಲು.',
        itemPaymentTitle: 'ಪಾವತಿ ವಿವರಗಳು ಮತ್ತು QR ಕೋಡ್',
        itemPaymentDesc: 'UPI ID ಮತ್ತು ಸುರಕ್ಷಿತ QR ಕೋಡ್ ಚಿತ್ರಗಳು.',
        itemProfileTitle: 'ಬಳಕೆದಾರರ ಪ್ರೊಫೈಲ್',
        itemProfileDesc: 'ಹೆಸರು, ಅವತಾರ, ಕರೆನ್ಸಿ ಮತ್ತು ಪುಶ್ ಟೋಕನ್.',
        itemInvoicesTitle: 'ಮಾಸಿಕ ಸ್ಟೇಟ್‌ಮೆಂಟ್‌ಗಳು (PDF)',
        itemInvoicesDesc: 'ಕ್ಲೌಡ್‌ನಲ್ಲಿ ಉಳಿಸಲಾದ ಇತ್ತೀಚಿನ 15 PDF ಸ್ಟೇಟ್‌ಮೆಂಟ್‌ಗಳು.',
        itemChatTitle: 'AI ಚಾಟ್ ಸಂಭಾಷಣೆಗಳು',
        itemChatDesc: 'ನಿಮ್ಮ ಫೋನ್‌ನ SQLite ಡೇಟಾಬೇಸ್‌ನಲ್ಲಿ ಮಾತ್ರ ಇರುವ 100% ಖಾಸಗಿ ಚಾಟ್.',
        itemCalcHistoryTitle: 'ಕ್ಯಾಲ್ಕುಲೇಟರ್ ಇತಿಹಾಸ',
        itemCalcHistoryDesc: 'ಮಾರುಕಟ್ಟೆ ಬೆಲೆಗಳು, EMI ಮತ್ತು SIP ಯ 50 ಇತ್ತೀಚಿನ ದಾಖಲೆಗಳು.',
        itemBiometricsTitle: 'ಬಯೋಮೆಟ್ರಿಕ್ ಮತ್ತು ಆ್ಯಪ್ ಲಾಕ್',
        itemBiometricsDesc: 'ಫಿಂಗರ್‌ಪ್ರಿಂಟ್ ಮತ್ತು ಪಿನ್ ಫೋನ್‌ನ ಸುರಕ್ಷಿತ ಮೆಮೊರಿಯಲ್ಲಿರುತ್ತದೆ.',
        itemThemeTitle: 'ಥೀಮ್ ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
        itemThemeDesc: 'ಡಾರ್ಕ್/ಲೈಟ್ ಮೋಡ್ ಆದ್ಯತೆಗಳು.',
        itemTempScanTitle: 'ತಾತ್ಕಾಲಿಕ ಸ್ಕ್ಯಾನ್ ಫೈಲ್‌ಗಳು',
        itemTempScanDesc: 'AI ಪ್ರಕ್ರಿಯೆಯ ನಂತರ ರಸೀದಿ ಫೋಟೋಗಳು ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಅಳಿಸಲ್ಪಡುತ್ತವೆ.',
        badgeCloud: 'ಕ್ಲೌಡ್ ಸಿಂಕ್',
        badgeLocalOnly: 'ಸ್ಥಳೀಯ ಮಾತ್ರ',
        badgeEncrypted: 'ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಲಾಗಿದೆ',
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
      selectLanguage: 'Select Screen Language',
      selectLanguageDesc: 'Information will comfortably adapt to your chosen language.',
      langUpdated: 'Language preference saved 🌐',
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
      itemInvoicesDesc: 'Your latest 15 monthly PDF invoices backed up for easy re-download anywhere.',
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
  String _selectedLangCode = 'en_IN';
  bool _isLoadingLang = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadSavedLanguage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kPrefBackupScopeLang);
    if (mounted) {
      setState(() {
        if (saved != null && saved.isNotEmpty) {
          _selectedLangCode = saved;
        }
        _isLoadingLang = false;
      });
    }
  }

  Future<void> _changeLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefBackupScopeLang, code);
    if (mounted) {
      setState(() => _selectedLangCode = code);
      final str = BackupScopeStrings.of(code);
      CustomToast.show(context, str.langUpdated);
    }
  }

  void _showLanguagePicker(BuildContext context, BackupScopeStrings str, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.translate_rounded, color: Color(0xFF00D09C), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      str.selectLanguage,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  str.selectLanguageDesc,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: kSupportedBackupScopeLanguages.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = kSupportedBackupScopeLanguages[idx];
                      final isSelected = item.code == _selectedLangCode;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00D09C).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00D09C) : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(item.flag, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Row(
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.inter(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                                color: isSelected ? const Color(0xFF00D09C) : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.nativeName,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00D09C), size: 22)
                            : null,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _changeLanguage(item.code);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final str = BackupScopeStrings.of(_selectedLangCode);
    const primaryColor = Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF181B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0);

    if (_isLoadingLang) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00D09C))),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          str.title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.translate_rounded, color: Color(0xFF00D09C), size: 18),
            ),
            tooltip: str.selectLanguage,
            onPressed: () => _showLanguagePicker(context, str, isDark),
          ),
          const SizedBox(width: 8),
        ],
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
      _ScopeItemData(
        title: str.itemInvoicesTitle,
        desc: str.itemInvoicesDesc,
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFFF97316),
        badge: str.badgeCloud,
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
        // Informative Hero Banner for No-Backup
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
              const Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 22),
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
