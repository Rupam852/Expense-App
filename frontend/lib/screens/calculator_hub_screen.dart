import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../services/ai_config_service.dart';
import '../services/database_helper.dart';
import '../services/user_provider.dart';
import '../widgets/ai_config_required_dialog.dart';
import '../widgets/custom_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTED VOICE & CALCULATION LANGUAGES
// ═══════════════════════════════════════════════════════════════════════════

class CalcVoiceLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final String sampleHint;

  const CalcVoiceLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.sampleHint,
  });
}

const String kPrefCalcVoiceLang = 'calc_hub_voice_lang_code';

const List<CalcVoiceLanguage> kSupportedCalcVoiceLanguages = [
  CalcVoiceLanguage(
    code: 'en_IN',
    name: 'English',
    nativeName: 'English (India)',
    flag: '🇮🇳',
    sampleHint: 'e.g. "Potato 30 per kg, onion 50 per 2 kg, tomato 20 per 500g"',
  ),
  CalcVoiceLanguage(
    code: 'bn_IN',
    name: 'Bengali',
    nativeName: 'বাংলা (ভারত)',
    flag: '🇮🇳',
    sampleHint: 'যেমন: "আলু ৩০ টাকা কেজি, পেঁয়াজ ৫০ টাকা ২ কেজি, পটল ২০ টাকা ৫০০ গ্রাম"',
  ),
  CalcVoiceLanguage(
    code: 'hi_IN',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    flag: '🇮🇳',
    sampleHint: 'जैसे: "आलू 30 रुपये किलो, प्याज 50 रुपये 2 किलो, टमाटर 20 रुपये 500 ग्राम"',
  ),
  CalcVoiceLanguage(
    code: 'hinglish',
    name: 'Hinglish / Banglish',
    nativeName: 'Colloquial Mix',
    flag: '🇮🇳',
    sampleHint: 'e.g. "Aloo 30 rs kg, pyaaz 50 rs 2 kg, tamatar 20 rs 500 gm"',
  ),
  CalcVoiceLanguage(
    code: 'ta_IN',
    name: 'Tamil',
    nativeName: 'தமிழ்',
    flag: '🇮🇳',
    sampleHint: 'எ.கா: "தக்காளி 40 ரூபாய் கிலோ, வெங்காயம் 50 ரூபாய் 2 கிலோ"',
  ),
  CalcVoiceLanguage(
    code: 'te_IN',
    name: 'Telugu',
    nativeName: 'తెలుగు',
    flag: '🇮🇳',
    sampleHint: 'ఉదా: "ఉల్లిపాయలు 50 రూపాయలు 2 కేజీలు, టమోటా 40 రూపాయలు కేజీ"',
  ),
  CalcVoiceLanguage(
    code: 'mr_IN',
    name: 'Marathi',
    nativeName: 'मराठी',
    flag: '🇮🇳',
    sampleHint: 'उदा: "बटाटा 30 रुपये किलो, कांदा 50 रुपये 2 किलो, टोमॅटो 20 रुपये 500 ग्रॅम"',
  ),
  CalcVoiceLanguage(
    code: 'gu_IN',
    name: 'Gujarati',
    nativeName: 'ગુજરાતી',
    flag: '🇮🇳',
    sampleHint: 'ઉદા: "બટાકા 30 રૂપિયા કિલો, ડુંગળી 50 રૂપિયા 2 કિલો"',
  ),
  CalcVoiceLanguage(
    code: 'kn_IN',
    name: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    flag: '🇮🇳',
    sampleHint: 'ಉದಾ: "ಆಲೂಗಡ್ಡೆ 30 ರೂ ಕೆಜಿ, ಈರುಳ್ಳಿ 50 ರೂ 2 ಕೆಜಿ"',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// LOCALIZATION STRINGS FOR FINANCIAL CALCULATOR HUB
// ═══════════════════════════════════════════════════════════════════════════

class CalcHubStrings {
  final String hubTitle;
  final String tabStandard;
  final String tabMarket;
  final String tabEmi;
  final String tabDaily;
  final String tabHistory;

  // Market Price
  final String manualRate;
  final String aiVoice;
  final String vegGroceryRateInput;
  final String itemNameOptional;
  final String basePrice;
  final String forQty;
  final String unit;
  final String stdUnitRate;
  final String quickBreakdown;
  final String customCalc;
  final String wantToBuy;
  final String budgetLabel;
  final String youWillGet;
  final String saveHistory;
  final String aiVoiceAnalyzer;
  final String tapMicToSpeak;
  final String listeningNow;
  final String processingAi;

  // EMI Loan
  final String monthlyEmi;
  final String totalInterest;
  final String totalAmount;
  final String principal;
  final String interest;
  final String loanAmount;
  final String interestRatePa;
  final String loanTenure;
  final String years;
  final String months;
  final String tapToEdit;
  final String enterAmount;
  final String enterRate;
  final String enterTenure;
  final String apply;
  final String cancel;

  // Daily Tools
  final String gstTax;
  final String discount;
  final String sipWealth;
  final String addGst;
  final String removeGst;
  final String originalPrice;
  final String discountPercent;
  final String finalPrice;
  final String youSave;
  final String monthlySip;
  final String returnRatePa;
  final String sipPeriod;
  final String investedAmount;
  final String estReturns;
  final String totalFutureValue;

  // History Tab & Filters
  final String historyAll;
  final String historyMandiVoice;
  final String historyUnitRates;
  final String historyEmi;
  final String historyGst;
  final String historyDiscount;
  final String historySip;
  final String historyStandard;
  final String historyClearTitle;
  final String historyClearConfirm;
  final String historyClearAll;
  final String historyNoRecords;
  final String historyCopied;
  final String historyCopy;
  final String historyDeleted;
  final String historyCleared;
  final String historyStorageNote;

  const CalcHubStrings({
    required this.hubTitle,
    required this.tabStandard,
    required this.tabMarket,
    required this.tabEmi,
    required this.tabDaily,
    required this.tabHistory,
    required this.manualRate,
    required this.aiVoice,
    required this.vegGroceryRateInput,
    required this.itemNameOptional,
    required this.basePrice,
    required this.forQty,
    required this.unit,
    required this.stdUnitRate,
    required this.quickBreakdown,
    required this.customCalc,
    required this.wantToBuy,
    required this.budgetLabel,
    required this.youWillGet,
    required this.saveHistory,
    required this.aiVoiceAnalyzer,
    required this.tapMicToSpeak,
    required this.listeningNow,
    required this.processingAi,
    required this.monthlyEmi,
    required this.totalInterest,
    required this.totalAmount,
    required this.principal,
    required this.interest,
    required this.loanAmount,
    required this.interestRatePa,
    required this.loanTenure,
    required this.years,
    required this.months,
    required this.tapToEdit,
    required this.enterAmount,
    required this.enterRate,
    required this.enterTenure,
    required this.apply,
    required this.cancel,
    required this.gstTax,
    required this.discount,
    required this.sipWealth,
    required this.addGst,
    required this.removeGst,
    required this.originalPrice,
    required this.discountPercent,
    required this.finalPrice,
    required this.youSave,
    required this.monthlySip,
    required this.returnRatePa,
    required this.sipPeriod,
    required this.investedAmount,
    required this.estReturns,
    required this.totalFutureValue,
    required this.historyAll,
    required this.historyMandiVoice,
    required this.historyUnitRates,
    required this.historyEmi,
    required this.historyGst,
    required this.historyDiscount,
    required this.historySip,
    required this.historyStandard,
    required this.historyClearTitle,
    required this.historyClearConfirm,
    required this.historyClearAll,
    required this.historyNoRecords,
    required this.historyCopied,
    required this.historyCopy,
    required this.historyDeleted,
    required this.historyCleared,
    required this.historyStorageNote,
  });

  static CalcHubStrings of(String langCode) {
    if (langCode.startsWith('bn')) {
      return const CalcHubStrings(
        hubTitle: 'ফিনান্সিয়াল ক্যালকুলেটর হাব',
        tabStandard: 'সাধারণ',
        tabMarket: 'বাজার দর',
        tabEmi: 'ঋণ / ইএমআই',
        tabDaily: 'দৈনিক টুলস',
        tabHistory: 'ইতিহাস',
        manualRate: 'ম্যানুয়াল রেট',
        aiVoice: 'এআই ভয়েস দর ✨',
        vegGroceryRateInput: 'সবজি ও মুদি দর ইনপুট',
        itemNameOptional: 'আইটেমের নাম',
        basePrice: 'দাম',
        forQty: 'পরিমাণ',
        unit: 'একক',
        stdUnitRate: 'আদর্শ একক দর',
        quickBreakdown: 'দ্রুত পরিমাণের মূল্য তালিকা',
        customCalc: 'কাস্টম পরিমাণ ও বাজেট হিসাব',
        wantToBuy: 'আমি কিনতে চাই',
        budgetLabel: 'আমার বাজেট',
        youWillGet: 'আপনি পাবেন',
        saveHistory: 'ইতিহাসে সংরক্ষণ',
        aiVoiceAnalyzer: 'এআই মাণ্ডি ভয়েস রেট অ্যানালাইজার',
        tapMicToSpeak: 'মাইক স্পর্শ করে বাজারের দর বলুন',
        listeningNow: 'শুনছি... এখন বলুন',
        processingAi: 'এআই বিশ্লেষণ করছে...',
        monthlyEmi: 'মাসিক ইএমআই',
        totalInterest: 'মোট সুদ',
        totalAmount: 'মোট পরিশোধ',
        principal: 'আসল',
        interest: 'সুদ',
        loanAmount: 'ঋণের পরিমাণ',
        interestRatePa: 'সুদের হার',
        loanTenure: 'ঋণের সময়কাল',
        years: 'বছর',
        months: 'মাস',
        tapToEdit: 'সরাসরি মান লিখতে স্পর্শ করুন',
        enterAmount: 'ঋণের পরিমাণ লিখুন',
        enterRate: 'সুদের হার লিখুন',
        enterTenure: 'সময়কাল লিখুন',
        apply: 'প্রয়োগ করুন',
        cancel: 'বাতিল',
        gstTax: 'জিএসটি কর',
        discount: 'ছাড় / ডিসকাউন্ট',
        sipWealth: 'এসআইপি সম্পদ',
        addGst: 'জিএসটি যোগ (+)',
        removeGst: 'জিএসটি বাদ (-)',
        originalPrice: 'আসল দাম',
        discountPercent: 'ছাড়',
        finalPrice: 'ছাড়ের পর দাম',
        youSave: 'আপনার সাশ্রয়',
        monthlySip: 'মাসিক বিনিয়োগ',
        returnRatePa: 'প্রত্যাশিত লাভ',
        sipPeriod: 'বিনিয়োগের সময়কাল',
        investedAmount: 'বিনিয়োগকৃত অর্থ',
        estReturns: 'আনুমানিক লাভ',
        totalFutureValue: 'মোট ভবিষ্যৎ মূল্য',
        historyAll: 'সব',
        historyMandiVoice: 'মান্ডি ভয়েস',
        historyUnitRates: 'একক দর',
        historyEmi: 'ইএমআই',
        historyGst: 'জিএসটি',
        historyDiscount: 'ছাড়',
        historySip: 'এসআইপি',
        historyStandard: 'সাধারণ',
        historyClearTitle: 'হিসাবের ইতিহাস মুছবেন?',
        historyClearConfirm: 'সমস্ত সংরক্ষিত হিসাব স্থায়ীভাবে মুছে যাবে।',
        historyClearAll: 'সব মুছুন',
        historyNoRecords: 'কোনো হিসাবের ইতিহাস পাওয়া যায়নি',
        historyCopied: 'ক্লিপবোর্ডে কপি করা হয়েছে 📋',
        historyCopy: 'কপি',
        historyDeleted: 'হিসাব মুছে ফেলা হয়েছে।',
        historyCleared: 'হিসাবের ইতিহাস মুছে ফেলা হয়েছে।',
        historyStorageNote: 'নোট: সর্বাধিক ৫০টি সাম্প্রতিক হিসাব সংরক্ষিত থাকে। নতুন হিসাব যুক্ত হলে পুরনো হিসাব স্বয়ংক্রিয়ভাবে মুছে যাবে।',
      );
    } else if (langCode.startsWith('hi') || langCode == 'hinglish') {
      return const CalcHubStrings(
        hubTitle: 'फाइनेंशियल कैलकुलेटर हब',
        tabStandard: 'साधारण',
        tabMarket: 'मंडी भाव',
        tabEmi: 'ईएमआई लोन',
        tabDaily: 'दैनिक टूल्स',
        tabHistory: 'इतिहास',
        manualRate: 'मैन्युअल दर',
        aiVoice: 'एआई वॉइस भाव ✨',
        vegGroceryRateInput: 'सब्जी व किराना दर इनपुट',
        itemNameOptional: 'सामग्री का नाम',
        basePrice: 'मूल्य',
        forQty: 'मात्रा के लिए',
        unit: 'इकाई',
        stdUnitRate: 'मानक इकाई दर',
        quickBreakdown: 'त्वरित मात्रा मूल्य विवरण',
        customCalc: 'कस्टम मात्रा व बजट हिसाब',
        wantToBuy: 'मुझे खरीदना है',
        budgetLabel: 'मेरा बजट',
        youWillGet: 'आपको मिलेगा',
        saveHistory: 'इतिहास में सहेजें',
        aiVoiceAnalyzer: 'एआई मंडी भाव वॉइस एनालाइज़र',
        tapMicToSpeak: 'माइक दबाएं और मंडी के भाव बोलें',
        listeningNow: 'सुन रहा है... अब बोलें',
        processingAi: 'एआई प्रोसेस कर रहा है...',
        monthlyEmi: 'मासिक ईएमआई',
        totalInterest: 'कुल ब्याज',
        totalAmount: 'कुल भुगतान',
        principal: 'मूलधन',
        interest: 'ब्याज',
        loanAmount: 'लोन राशि',
        interestRatePa: 'ब्याज दर',
        loanTenure: 'लोन की अवधि',
        years: 'वर्ष',
        months: 'महीने',
        tapToEdit: 'सीधा मान दर्ज करने के लिए टैप करें',
        enterAmount: 'लोन राशि दर्ज करें',
        enterRate: 'ब्याज दर दर्ज करें',
        enterTenure: 'अवधि दर्ज करें',
        apply: 'लागू करें',
        cancel: 'रद्द करें',
        gstTax: 'जीएसटी टैक्स',
        discount: 'छूट / डिस्काउंट',
        sipWealth: 'एसआईपी वेल्थ',
        addGst: 'जीएसटी जोड़ें (+)',
        removeGst: 'जीएसटी घटाएं (-)',
        originalPrice: 'मूल मूल्य',
        discountPercent: 'छूट',
        finalPrice: 'छूट के बाद अंतिम मूल्य',
        youSave: 'आपकी बचत',
        monthlySip: 'मासिक निवेश',
        returnRatePa: 'अपेक्षित रिटर्न दर',
        sipPeriod: 'निवेश की अवधि',
        investedAmount: 'निवेश की गई राशि',
        estReturns: 'अनुमानित रिटर्न',
        totalFutureValue: 'कुल भविष्य मूल्य',
        historyAll: 'सभी',
        historyMandiVoice: 'मंडी वॉइस',
        historyUnitRates: 'इकाई दर',
        historyEmi: 'ईएमआई',
        historyGst: 'जीएसटी',
        historyDiscount: 'छूट',
        historySip: 'एसआईपी',
        historyStandard: 'साधारण',
        historyClearTitle: 'हिसाब का इतिहास हटाएं?',
        historyClearConfirm: 'सभी सहेजे गए हिसाब स्थायी रूप से हटा दिए जाएंगे।',
        historyClearAll: 'सभी हटाएं',
        historyNoRecords: 'कोई हिसाब का इतिहास नहीं मिला',
        historyCopied: 'क्लिपबोर्ड पर कॉपी किया गया 📋',
        historyCopy: 'कॉपी',
        historyDeleted: 'हिसाब हटा दिया गया।',
        historyCleared: 'हिसाब का इतिहास हटा दिया गया।',
        historyStorageNote: 'नोट: अधिकतम 50 हालिया हिसाब सुरक्षित रहते हैं। नया हिसाब जुड़ने पर पुराना हिसाब अपने आप हट जाता है।',
      );
    } else if (langCode.startsWith('ta')) {
      return const CalcHubStrings(
        hubTitle: 'நிதி கால்குலேட்டர் மையம்',
        tabStandard: 'நிலையானது',
        tabMarket: 'சந்தை விலை',
        tabEmi: 'இஎம்ஐ கடன்',
        tabDaily: 'தினசரி கருவிகள்',
        tabHistory: 'வரலாறு',
        manualRate: 'கையேடு விகிதம்',
        aiVoice: 'AI குரல் விலை ✨',
        vegGroceryRateInput: 'காய்கறி மற்றும் மளிகை விலை உள்ளீடு',
        itemNameOptional: 'பொருளின் பெயர்',
        basePrice: 'விலை',
        forQty: 'அளவு',
        unit: 'அலகு',
        stdUnitRate: 'நிலையான அலகு விகிதம்',
        quickBreakdown: 'விரைவான விலை விவரம்',
        customCalc: 'தனிப்பயன் அளவு மற்றும் பட்ஜெட்',
        wantToBuy: 'நான் வாங்க விரும்புகிறேன்',
        budgetLabel: 'பட்ஜெட்',
        youWillGet: 'உங்களுக்கு கிடைக்கும்',
        saveHistory: 'வரலாற்றில் சேமிக்கவும்',
        aiVoiceAnalyzer: 'AI சந்தை குரல் பகுப்பாய்வி',
        tapMicToSpeak: 'மைக் தட்டி சந்தை விலைகளைப் பேசுங்கள்',
        listeningNow: 'கேட்கிறது... இப்போது பேசுங்கள்',
        processingAi: 'AI பகுப்பாய்வு செய்கிறது...',
        monthlyEmi: 'மாதாந்திர EMI',
        totalInterest: 'மொத்த வட்டி',
        totalAmount: 'மொத்த தொகை',
        principal: 'அசல்',
        interest: 'வட்டி',
        loanAmount: 'கடன் தொகை',
        interestRatePa: 'வட்டி விகிதம்',
        loanTenure: 'கடன் காலம்',
        years: 'ஆண்டுகள்',
        months: 'மாதங்கள்',
        tapToEdit: 'நேரடியாக உள்ளிட தட்டவும்',
        enterAmount: 'கடன் தொகையை உள்ளிடவும்',
        enterRate: 'வட்டி விகிதத்தை உள்ளிடவும்',
        enterTenure: 'காலத்தை உள்ளிடவும்',
        apply: 'பயன்படுத்து',
        cancel: 'ரத்துசெய்',
        gstTax: 'ஜிஎஸ்டி வரி',
        discount: 'தள்ளுபடி',
        sipWealth: 'எஸ்ஐபி செல்வம்',
        addGst: 'ஜிஎஸ்டி சேர் (+)',
        removeGst: 'ஜிஎஸ்டி நீக்கு (-)',
        originalPrice: 'அசல் விலை',
        discountPercent: 'தள்ளுபடி',
        finalPrice: 'தள்ளுபடிக்குப் பின் விலை',
        youSave: 'உங்கள் சேமிப்பு',
        monthlySip: 'மாதாந்திர முதலீடு',
        returnRatePa: 'எதிர்பார்க்கப்படும் வருவாய்',
        sipPeriod: 'முதலீட்டுக் காலம்',
        investedAmount: 'முதலீடு செய்த தொகை',
        estReturns: 'மதிப்பிடப்பட்ட வருவாய்',
        totalFutureValue: 'மொத்த எதிர்கால மதிப்பு',
        historyAll: 'அனைத்தும்',
        historyMandiVoice: 'சந்தை குரல்',
        historyUnitRates: 'அலகு விகிதங்கள்',
        historyEmi: 'EMI',
        historyGst: 'GST',
        historyDiscount: 'தள்ளுபடி',
        historySip: 'SIP',
        historyStandard: 'நிலையானது',
        historyClearTitle: 'கணக்கீட்டு வரலாற்றை அழிக்கவா?',
        historyClearConfirm: 'சேமிக்கப்பட்ட அனைத்து கணக்கீடுகளும் நிரந்தரமாக நீக்கப்படும்.',
        historyClearAll: 'அனைத்தையும் அழி',
        historyNoRecords: 'கணக்கீட்டு வரலாறு எதுவும் இல்லை',
        historyCopied: 'கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது 📋',
        historyCopy: 'நகலெடு',
        historyDeleted: 'வரலாறு நீக்கப்பட்டது.',
        historyCleared: 'வரலாறு அழிக்கப்பட்டது.',
        historyStorageNote: 'குறிப்பு: அதிகபட்சம் 50 சமீபத்திய கணக்கீடுகள் சேமிக்கப்படும். புதியவை சேர்க்கப்படும் போது பழையவை தானாக நீக்கப்படும்.',
      );
    } else if (langCode.startsWith('te')) {
      return const CalcHubStrings(
        hubTitle: 'ఫైనాన్షియల్ కాలిక్యులేటర్ హబ్',
        tabStandard: 'ప్రామాణికం',
        tabMarket: 'మార్కెట్ ధర',
        tabEmi: 'ఈఎమ్‌ఐ రుణం',
        tabDaily: 'రోజువారీ సాధనాలు',
        tabHistory: 'చరిత్ర',
        manualRate: 'మాన్యువల్ రేటు',
        aiVoice: 'AI వాయిస్ ధర ✨',
        vegGroceryRateInput: 'కూరగాయలు & కిరాణా ధర నమోదు',
        itemNameOptional: 'వస్తువు పేరు',
        basePrice: 'ధర',
        forQty: 'పరిమాణం',
        unit: 'యూనిట్',
        stdUnitRate: 'ప్రామాణిక యూనిట్ రేటు',
        quickBreakdown: 'త్వరిత పరిమాణ ధర విభజన',
        customCalc: 'కస్టమ్ లెక్క',
        wantToBuy: 'నేను కొనాలనుకుంటున్నాను',
        budgetLabel: 'బడ్జెట్',
        youWillGet: 'మీకు లభిస్తుంది',
        saveHistory: 'చరిత్రలో సేవ్ చేయండి',
        aiVoiceAnalyzer: 'AI మార్కెట్ వాయిస్ ఎనలైజర్',
        tapMicToSpeak: 'మైక్ నొక్కి మార్కెట్ రేట్లు మాట్లాడండి',
        listeningNow: 'వింటోంది... మాట్లాడండి',
        processingAi: 'AI విశ్లేషిస్తోంది...',
        monthlyEmi: 'నెలవారీ EMI',
        totalInterest: 'మొత్తం వడ్డీ',
        totalAmount: 'మొత్తం చెల్లింపు',
        principal: 'అసలు',
        interest: 'వడ్డీ',
        loanAmount: 'రుణ మొత్తం',
        interestRatePa: 'వడ్డీ రేటు',
        loanTenure: 'రుణ కాలపరిమితి',
        years: 'సంవత్సరాలు',
        months: 'నెలలు',
        tapToEdit: 'సవరించడానికి నొక్కండి',
        enterAmount: 'రుణ మొత్తం నమోదు చేయండి',
        enterRate: 'వడ్డీ రేటు నమోదు చేయండి',
        enterTenure: 'వ్యవధి నమోదు చేయండి',
        apply: 'వర్తింపజేయి',
        cancel: 'రద్దు చేయి',
        gstTax: 'జీఎస్టీ పన్ను',
        discount: 'డిస్కౌంట్',
        sipWealth: 'SIP సంపద',
        addGst: 'జీఎస్టీ జోడించు (+)',
        removeGst: 'జీఎస్టీ తీసివేయి (-)',
        originalPrice: 'అసలు ధర',
        discountPercent: 'డిస్కౌంట్',
        finalPrice: 'తుది ధర',
        youSave: 'మీ ఆదా',
        monthlySip: 'నెలవారీ పెట్టుబడి',
        returnRatePa: 'ఆశించిన రాబడి రేటు',
        sipPeriod: 'పెట్టుబడి కాలం',
        investedAmount: 'పెట్టుబడి పెట్టిన మొత్తం',
        estReturns: 'అంచనా రాబడి',
        totalFutureValue: 'మొత్తం భవిష్యత్ విలువ',
        historyAll: 'అన్నీ',
        historyMandiVoice: 'మార్కెట్ వాయిస్',
        historyUnitRates: 'యూనిట్ రేట్లు',
        historyEmi: 'EMI',
        historyGst: 'GST',
        historyDiscount: 'డిస్కౌంట్',
        historySip: 'SIP',
        historyStandard: 'ప్రామాణికం',
        historyClearTitle: 'చరిత్రను క్లియర్ చేయాలా?',
        historyClearConfirm: 'సేవ్ చేసిన అన్ని లెక్కలు శాశ్వతంగా తొలగించబడతాయి.',
        historyClearAll: 'అన్నీ క్లియర్ చేయి',
        historyNoRecords: 'ఎలాంటి చరిత్ర కనుగొనబడలేదు',
        historyCopied: 'క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది 📋',
        historyCopy: 'కాపీ',
        historyDeleted: 'చరిత్ర తొలగించబడింది.',
        historyCleared: 'చరిత్ర క్లియర్ చేయబడింది.',
        historyStorageNote: 'గమనిక: గరిష్టంగా 50 ఇటీవలి లెక్కలు సేవ్ చేయబడతాయి. కొత్తవి జోడించినప్పుడు పాతవి స్వయంచాలకంగా తొలగించబడతాయి.',
      );
    } else if (langCode.startsWith('mr')) {
      return const CalcHubStrings(
        hubTitle: 'फायनान्शियल कॅल्क्युलेटर हब',
        tabStandard: 'साधे',
        tabMarket: 'बाजार भाव',
        tabEmi: 'ईएमआय कर्ज',
        tabDaily: 'दैनंदिन टूल्स',
        tabHistory: 'इतिहास',
        manualRate: 'मॅन्युअल दर',
        aiVoice: 'AI व्हॉइस भाव ✨',
        vegGroceryRateInput: 'भाजीपाला व किराणा दर नोंदणी',
        itemNameOptional: 'वस्तूचे नाव',
        basePrice: 'किंमत',
        forQty: 'प्रमाण',
        unit: 'युनिट',
        stdUnitRate: 'मानक युनिट दर',
        quickBreakdown: 'त्वरित किंमत यादी',
        customCalc: 'कस्टम हिशोब',
        wantToBuy: 'मला खरेदी करायचे आहे',
        budgetLabel: 'बजेट आहे',
        youWillGet: 'तुम्हाला मिळेल',
        saveHistory: 'इतिहासामध्ये जतन करा',
        aiVoiceAnalyzer: 'AI बाजार भाव व्हॉइस विश्लेषक',
        tapMicToSpeak: 'माइक दाबा आणि बाजाराचे भाव बोला',
        listeningNow: 'ऐकत आहे... आता बोला',
        processingAi: 'AI प्रक्रिया करत आहे...',
        monthlyEmi: 'मासिक EMI',
        totalInterest: 'एकूण व्याज',
        totalAmount: 'एकूण रक्कम',
        principal: 'मुद्दल',
        interest: 'व्याज',
        loanAmount: 'कर्ज रक्कम',
        interestRatePa: 'व्याज दर',
        loanTenure: 'कर्ज कालावधी',
        years: 'वर्षे',
        months: 'महिने',
        tapToEdit: 'बदलण्यासाठी टॅप करा',
        enterAmount: 'कर्ज रक्कम प्रविष्ट करा',
        enterRate: 'व्याज दर प्रविष्ट करा',
        enterTenure: 'कालावधी प्रविष्ट करा',
        apply: 'लागू करा',
        cancel: 'रद्द करा',
        gstTax: 'जीएसटी कर',
        discount: 'सवलत / डिस्काउंट',
        sipWealth: 'SIP संपत्ती',
        addGst: 'जीएसटी जोडा (+)',
        removeGst: 'जीएसटी वजा करा (-)',
        originalPrice: 'मूळ किंमत',
        discountPercent: 'सवलत',
        finalPrice: 'सवलतीनंतरची किंमत',
        youSave: 'तुमची बचत',
        monthlySip: 'मासिक गुंतवणूक',
        returnRatePa: 'अपेक्षित परतावा दर',
        sipPeriod: 'गुंतवणूक कालावधी',
        investedAmount: 'गुंतवलेली रक्कम',
        estReturns: 'अंदाजे परतावा',
        totalFutureValue: 'एकूण भविष्य मूल्य',
        historyAll: 'सर्व',
        historyMandiVoice: 'बाजार व्हॉइस',
        historyUnitRates: 'युनिट दर',
        historyEmi: 'EMI',
        historyGst: 'GST',
        historyDiscount: 'सवलत',
        historySip: 'SIP',
        historyStandard: 'साधे',
        historyClearTitle: 'इतिहास हटवायचा का?',
        historyClearConfirm: 'सर्व जतन केलेले हिशोब कायमचे हटवले जातील.',
        historyClearAll: 'सर्व हटवा',
        historyNoRecords: 'कोणताही इतिहास आढळला नाही',
        historyCopied: 'कॉपी केले 📋',
        historyCopy: 'कॉपी',
        historyDeleted: 'हिशोब हटवला.',
        historyCleared: 'इतिहास हटवला.',
        historyStorageNote: 'टीप: कमाल 50 अलीकडील हिशोब जतन केले जातात. नवीन जोडल्यास जुने आपोआप हटवले जातात.',
      );
    } else if (langCode.startsWith('gu')) {
      return const CalcHubStrings(
        hubTitle: 'ફાઇનાન્સિયલ કેલ્ક્યુલેટર હબ',
        tabStandard: 'સામાન્ય',
        tabMarket: 'બજાર ભાવ',
        tabEmi: 'EMI લોન',
        tabDaily: 'દૈનિક સાધનો',
        tabHistory: 'ઇતિહાસ',
        manualRate: 'મેન્યુઅલ દર',
        aiVoice: 'AI વૉઇસ ભાવ ✨',
        vegGroceryRateInput: 'શાકભાજી અને કરિયાણા દર ઇનપુટ',
        itemNameOptional: 'વસ્તુનું નામ',
        basePrice: 'કિંમત',
        forQty: 'જથ્થો',
        unit: 'એકમ',
        stdUnitRate: 'પ્રમાણભૂત એકમ દર',
        quickBreakdown: 'ઝડપી કિંમત વિગતો',
        customCalc: 'કસ્ટમ હિસાબ',
        wantToBuy: 'મારે ખરીદવું છે',
        budgetLabel: 'બજેટ છે',
        youWillGet: 'તમને મળશે',
        saveHistory: 'ઇતિહાસમાં સાચવો',
        aiVoiceAnalyzer: 'AI માર્કેટ વૉઇસ એનાલાઇઝર',
        tapMicToSpeak: 'માઇક દબાવો અને બજાર ભાવ બોલો',
        listeningNow: 'સાંભળી રહ્યું છે... બોલો',
        processingAi: 'AI પ્રોસેસ કરી રહ્યું છે...',
        monthlyEmi: 'માસિક EMI',
        totalInterest: 'કુલ વ્યાજ',
        totalAmount: 'કુલ રકમ',
        principal: 'મુદ્દલ',
        interest: 'વ્યાજ',
        loanAmount: 'લોન રકમ',
        interestRatePa: 'વ્યાજ દર',
        loanTenure: 'લોન સમયગાળો',
        years: 'વર્ષ',
        months: 'મહિના',
        tapToEdit: 'લખવા માટે ટેપ કરો',
        enterAmount: 'લોન રકમ દાખલ કરો',
        enterRate: 'વ્યાજ દર દાખલ કરો',
        enterTenure: 'સમયગાળો દાખલ કરો',
        apply: 'લાગુ કરો',
        cancel: 'રદ કરો',
        gstTax: 'જીએસટી ટેક્સ',
        discount: 'ડિસ્કાઉન્ટ / છૂટ',
        sipWealth: 'SIP સંપત્તિ',
        addGst: 'જીએસટી ઉમેરો (+)',
        removeGst: 'જીએસટી બાદ કરો (-)',
        originalPrice: 'મૂળ કિંમત',
        discountPercent: 'ડિસ્કાઉન્ટ',
        finalPrice: 'ડિસ્કાઉન્ટ પછી કિંમત',
        youSave: 'તમારી બચત',
        monthlySip: 'માસિક રોકાણ',
        returnRatePa: 'અપેક્ષિત વળતર દર',
        sipPeriod: 'રોકાણ સમયગાળો',
        investedAmount: 'રોકાણ કરેલી રકમ',
        estReturns: 'અંદાજિત વળતર',
        totalFutureValue: 'કુલ ભવિષ્ય મૂલ્ય',
        historyAll: 'બધું',
        historyMandiVoice: 'માર્કેટ વૉઇસ',
        historyUnitRates: 'એકમ દર',
        historyEmi: 'EMI',
        historyGst: 'GST',
        historyDiscount: 'ડિસ્કાઉન્ટ',
        historySip: 'SIP',
        historyStandard: 'સામાન્ય',
        historyClearTitle: 'ઇતિહાસ સાફ કરવો?',
        historyClearConfirm: 'બધા સાચવેલા હિસાબ કાયમ માટે કાઢી નાખવામાં આવશે.',
        historyClearAll: 'બધું સાફ કરો',
        historyNoRecords: 'કોઈ ઇતિહાસ મળ્યો નથી',
        historyCopied: 'ક્લિપબોર્ડ પર કૉપિ કર્યું 📋',
        historyCopy: 'કૉપિ',
        historyDeleted: 'હિસાબ કાઢી નાખ્યો.',
        historyCleared: 'ઇતિહાસ સાફ કર્યો.',
        historyStorageNote: 'નોંધ: મહત્તમ 50 તાજેતરના હિસાબ સાચવવામાં આવે છે. નવું ઉમેરતાં જૂનું આપમેળે દૂર થઈ જાય છે.',
      );
    } else if (langCode.startsWith('kn')) {
      return const CalcHubStrings(
        hubTitle: 'ಹಣಕಾಸು ಕ್ಯಾಲ್ಕುಲೇಟರ್ ಹಬ್',
        tabStandard: 'ಸಾಮಾನ್ಯ',
        tabMarket: 'ಮಾರುಕಟ್ಟೆ ಬೆಲೆ',
        tabEmi: 'ಇಎಂಐ ಸಾಲ',
        tabDaily: 'ದೈನಂದಿನ ಪರಿಕರಗಳು',
        tabHistory: 'ಇತಿಹಾಸ',
        manualRate: 'ಮ್ಯಾನುಯಲ್ ದರ',
        aiVoice: 'AI ಧ್ವನಿ ದರ ✨',
        vegGroceryRateInput: 'ತರಕಾರಿ ಮತ್ತು ದಿನಸಿ ದರ ನಮೂದು',
        itemNameOptional: 'ವಸ್ತುವಿನ ಹೆಸರು',
        basePrice: 'ಬೆಲೆ',
        forQty: 'ಪ್ರಮಾಣ',
        unit: 'ಘಟಕ',
        stdUnitRate: 'ಪ್ರಮಾಣಿತ ಘಟಕ ದರ',
        quickBreakdown: 'ತ್ವರಿತ ಬೆಲೆ ವಿವರ',
        customCalc: 'ಕಸ್ಟಮ್ ಲೆಕ್ಕ',
        wantToBuy: 'ನಾನು ಖರೀದಿಸಲು ಬಯಸುತ್ತೇನೆ',
        budgetLabel: 'ಬಜೆಟ್',
        youWillGet: 'ನಿಮಗೆ ಸಿಗುತ್ತದೆ',
        saveHistory: 'ಇತಿಹಾಸದಲ್ಲಿ ಉಳಿಸಿ',
        aiVoiceAnalyzer: 'AI ಮಾರುಕಟ್ಟೆ ಧ್ವನಿ ವಿಶ್ಲೇಷಕ',
        tapMicToSpeak: 'ಮೈಕ್ ಒತ್ತಿ ಮಾರುಕಟ್ಟೆ ಬೆಲೆಗಳನ್ನು ಮಾತನಾಡಿ',
        listeningNow: 'ಕೇಳುತ್ತಿದೆ... ಮಾತನಾಡಿ',
        processingAi: 'AI ವಿಶ್ಲೇಷಿಸುತ್ತಿದೆ...',
        monthlyEmi: 'ಮಾಸಿಕ EMI',
        totalInterest: 'ಒಟ್ಟು ಬಡ್ಡಿ',
        totalAmount: 'ಒಟ್ಟು ಮೊತ್ತ',
        principal: 'ಅಸಲು',
        interest: 'ಬಡ್ಡಿ',
        loanAmount: 'ಸಾಲದ ಮೊತ್ತ',
        interestRatePa: 'ಬಡ್ಡಿ ದರ',
        loanTenure: 'ಸಾಲದ ಅವಧಿ',
        years: 'ವರ್ಷಗಳು',
        months: 'ತಿಂಗಳುಗಳು',
        tapToEdit: 'ಬದಲಾಯಿಸಲು ಟ್ಯಾಪ್ ಮಾಡಿ',
        enterAmount: 'ಸಾಲದ ಮೊತ್ತ ನಮೂದಿಸಿ',
        enterRate: 'ಬಡ್ಡಿ ದರ ನಮೂದಿಸಿ',
        enterTenure: 'ಅವಧಿ ನಮೂದಿಸಿ',
        apply: 'ಅನ್ವಯಿಸು',
        cancel: 'ರದ್ದುಮಾಡು',
        gstTax: 'ಜಿಎಸ್ಟಿ ತೆರಿಗೆ',
        discount: 'ರಿಯಾಯಿತಿ / ಡಿಸ್ಕೌಂಟ್',
        sipWealth: 'SIP ಸಂಪತ್ತು',
        addGst: 'ಜಿಎಸ್ಟಿ ಸೇರಿಸಿ (+)',
        removeGst: 'ಜಿಎಸ್ಟಿ ಕಳೆಯಿರಿ (-)',
        originalPrice: 'ಮೂಲ ಬೆಲೆ',
        discountPercent: 'ರಿಯಾಯಿತಿ',
        finalPrice: 'ಅಂತಿಮ ಬೆಲೆ',
        youSave: 'ನಿಮ್ಮ ಉಳಿತಾಯ',
        monthlySip: 'ಮಾಸಿಕ ಹೂಡಿಕೆ',
        returnRatePa: 'ನಿರೀಕ್ಷಿತ ಆದಾಯ ದರ',
        sipPeriod: 'ಹೂಡಿಕೆ ಅವಧಿ',
        investedAmount: 'ಹೂಡಿಕೆ ಮಾಡಿದ ಮೊತ್ತ',
        estReturns: 'ಅಂದಾಜು ಆದಾಯ',
        totalFutureValue: 'ಒಟ್ಟು ಭವಿಷ್ಯದ ಮೌಲ್ಯ',
        historyAll: 'ಎಲ್ಲವೂ',
        historyMandiVoice: 'ಮಾರುಕಟ್ಟೆ ಧ್ವನಿ',
        historyUnitRates: 'ಘಟಕ ದರಗಳು',
        historyEmi: 'EMI',
        historyGst: 'GST',
        historyDiscount: 'ರಿಯಾಯಿತಿ',
        historySip: 'SIP',
        historyStandard: 'ಸಾಮಾನ್ಯ',
        historyClearTitle: 'ಇತಿಹಾಸವನ್ನು ಅಳಿಸುವುದೇ?',
        historyClearConfirm: 'ಉಳಿಸಲಾದ ಎಲ್ಲಾ ಲೆಕ್ಕಾಚಾರಗಳು ಶಾಶ್ವತವಾಗಿ ಅಳಿಸಲ್ಪಡುತ್ತವೆ.',
        historyClearAll: 'ಎಲ್ಲವನ್ನೂ ಅಳಿಸಿ',
        historyNoRecords: 'ಯಾವುದೇ ಇತಿಹಾಸ ಕಂಡುಬಂದಿಲ್ಲ',
        historyCopied: 'ಕ್ಲಿಪ್‌ಬೋರ್ಡ್‌ಗೆ ನಕಲಿಸಲಾಗಿದೆ 📋',
        historyCopy: 'ನಕಲಿಸಿ',
        historyDeleted: 'ಇತಿಹಾಸ ಅಳಿಸಲಾಗಿದೆ.',
        historyCleared: 'ಇತಿಹಾಸ ತೆರವುಗೊಳಿಸಲಾಗಿದೆ.',
        historyStorageNote: 'ಗಮನಿಸಿ: ಗರಿಷ್ಠ 50 ಇತ್ತೀಚಿನ ಲೆಕ್ಕಾಚಾರಗಳನ್ನು ಉಳಿಸಲಾಗುತ್ತದೆ. ಹೊಸದನ್ನು ಸೇರಿಸಿದಾಗ ಹಳೆಯವು ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಅಳಿಸಲ್ಪಡುತ್ತವೆ.',
      );
    }

    return const CalcHubStrings(
      hubTitle: 'Financial Calculators Hub',
      tabStandard: 'Standard',
      tabMarket: 'Market Price',
      tabEmi: 'EMI Loan',
      tabDaily: 'Daily Tools',
      tabHistory: 'History',
      manualRate: 'Manual Unit Rate',
      aiVoice: 'AI Mandi Voice ✨',
      vegGroceryRateInput: 'Vegetable / Grocery Rate Input',
      itemNameOptional: 'Item Name',
      basePrice: 'Price',
      forQty: 'Qty',
      unit: 'Unit',
      stdUnitRate: 'STANDARD UNIT RATE',
      quickBreakdown: 'Quick Quantity Price Breakdown',
      customCalc: 'Custom Quantity & Budget Calc',
      wantToBuy: 'I want to buy',
      budgetLabel: 'Budget',
      youWillGet: 'You will get',
      saveHistory: 'Save to History',
      aiVoiceAnalyzer: 'AI Mandi Rate Voice Analyzer',
      tapMicToSpeak: 'Tap Mic & Speak Market Rates',
      listeningNow: 'Listening... Speak now',
      processingAi: 'Analyzing with AI...',
      monthlyEmi: 'Monthly EMI',
      totalInterest: 'Total Interest',
      totalAmount: 'Total Amount',
      principal: 'Principal',
      interest: 'Interest',
      loanAmount: 'Loan Amount',
      interestRatePa: 'Interest Rate',
      loanTenure: 'Loan Tenure',
      years: 'Years',
      months: 'Months',
      tapToEdit: 'Tap to edit exact value',
      enterAmount: 'Enter Loan Amount',
      enterRate: 'Enter Interest Rate',
      enterTenure: 'Enter Loan Tenure',
      apply: 'Apply',
      cancel: 'Cancel',
      gstTax: 'GST Tax',
      discount: 'Discount',
      sipWealth: 'SIP Wealth',
      addGst: 'Add GST (+)',
      removeGst: 'Remove GST (-)',
      originalPrice: 'Original Price',
      discountPercent: 'Discount',
      finalPrice: 'Final Discounted Price',
      youSave: 'You Save',
      monthlySip: 'Monthly Investment',
      returnRatePa: 'Expected Return Rate',
      sipPeriod: 'Investment Period',
      investedAmount: 'Invested Amount',
      estReturns: 'Est. Returns',
      totalFutureValue: 'Total Future Value',
      historyAll: 'All',
      historyMandiVoice: 'Mandi Voice',
      historyUnitRates: 'Unit Rates',
      historyEmi: 'EMI',
      historyGst: 'GST',
      historyDiscount: 'Discount',
      historySip: 'SIP',
      historyStandard: 'Standard',
      historyClearTitle: 'Clear Calculation History?',
      historyClearConfirm: 'All saved calculations will be deleted permanently.',
      historyClearAll: 'Clear All',
      historyNoRecords: 'No calculation history found',
      historyCopied: 'Copied to clipboard 📋',
      historyCopy: 'Copy',
      historyDeleted: 'History item deleted.',
      historyCleared: 'Calculation history cleared.',
      historyStorageNote: 'Note: Stores up to 50 recent calculations. Older records are automatically replaced as new ones are added.',
    );
  }
}

Future<void> showCalcLanguagePickerSheet({
  required BuildContext context,
  required String currentCode,
  required ValueChanged<String> onSelected,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  await showModalBottomSheet(
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
                    'Select Hub & Voice Language',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Calculators and voice tools will comfortably adapt to your chosen language.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: kSupportedCalcVoiceLanguages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = kSupportedCalcVoiceLanguages[idx];
                    final isSelected = item.code == currentCode;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00D09C).withOpacity(0.15)
                              : (isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
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
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00D09C), size: 22)
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onSelected(item.code);
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

class CalculatorHubScreen extends StatefulWidget {
  final int initialTabIndex;
  const CalculatorHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CalculatorHubScreen> createState() => _CalculatorHubScreenState();
}

class _CalculatorHubScreenState extends State<CalculatorHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedLangCode = 'en_IN';

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kPrefCalcVoiceLang);
    if (saved != null && mounted) {
      setState(() => _selectedLangCode = saved);
    } else if (mounted) {
      final appLang = Provider.of<UserProvider>(context, listen: false).appLanguage;
      if (appLang == 'hi') {
        setState(() => _selectedLangCode = 'hi_IN');
      } else if (appLang == 'bn') {
        setState(() => _selectedLangCode = 'bn_IN');
      } else {
        setState(() => _selectedLangCode = 'en_IN');
      }
    }
  }

  Future<void> _updateLanguage(String newCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefCalcVoiceLang, newCode);
    if (mounted) {
      setState(() => _selectedLangCode = newCode);
      final lang = kSupportedCalcVoiceLanguages.firstWhere(
        (l) => l.code == newCode,
        orElse: () => kSupportedCalcVoiceLanguages.first,
      );
      CustomToast.show(context, 'Language set to ${lang.name} (${lang.nativeName}) ${lang.flag}');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = kSupportedCalcVoiceLanguages.firstWhere(
      (l) => l.code == _selectedLangCode,
      orElse: () => kSupportedCalcVoiceLanguages.first,
    );
    final str = CalcHubStrings.of(_selectedLangCode);
    final userProvider = Provider.of<UserProvider>(context);
    final activeMode = userProvider.isBusinessMode ? 'business' : 'personal';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          str.hubTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () {
                showCalcLanguagePickerSheet(
                  context: context,
                  currentCode: _selectedLangCode,
                  onSelected: _updateLanguage,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00D09C).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentLang.flag, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      currentLang.name,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00D09C),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF00D09C)),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: const Color(0xFF00D09C),
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          indicatorColor: const Color(0xFF00D09C),
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
          tabs: [
            Tab(icon: const Icon(Icons.calculate_outlined, size: 20), text: str.tabStandard),
            Tab(icon: const Icon(Icons.shopping_basket_outlined, size: 20), text: str.tabMarket),
            Tab(icon: const Icon(Icons.account_balance_outlined, size: 20), text: str.tabEmi),
            Tab(icon: const Icon(Icons.percent_rounded, size: 20), text: str.tabDaily),
            Tab(icon: const Icon(Icons.history_rounded, size: 20), text: str.tabHistory),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StandardCalculatorView(langCode: _selectedLangCode, activeMode: activeMode),
          _MarketPriceCalculatorView(langCode: _selectedLangCode, activeMode: activeMode),
          _EmiCalculatorView(langCode: _selectedLangCode, activeMode: activeMode),
          _DailyFinancialToolsView(langCode: _selectedLangCode, activeMode: activeMode),
          _CalculatorHistoryView(langCode: _selectedLangCode, activeMode: activeMode),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: STANDARD CALCULATOR
// ═══════════════════════════════════════════════════════════════════════════

class _StandardCalculatorView extends StatefulWidget {
  final String langCode;
  final String activeMode;
  const _StandardCalculatorView({this.langCode = 'en_IN', this.activeMode = 'personal'});

  @override
  State<_StandardCalculatorView> createState() => _StandardCalculatorViewState();
}

class _StandardCalculatorViewState extends State<_StandardCalculatorView> {
  String _expression = '';
  String _result = '0';

  void _onBtnTap(String val) {
    HapticFeedback.lightImpact();
    setState(() {
      if (val == 'AC') {
        _expression = '';
        _result = '0';
      } else if (val == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _calculateResult(live: true);
        }
      } else if (val == '=') {
        _calculateResult(live: false, save: true);
      } else if (val == '%') {
        if (_expression.isNotEmpty && !'+-×÷%'.contains(_expression[_expression.length - 1])) {
          _expression += '%';
          _calculateResult(live: true);
        }
      } else if (['+', '-', '×', '÷'].contains(val)) {
        if (_expression.isEmpty) {
          if (val == '-') _expression = '-';
        } else {
          final lastChar = _expression[_expression.length - 1];
          if (['+', '-', '×', '÷'].contains(lastChar)) {
            _expression = _expression.substring(0, _expression.length - 1) + val;
          } else {
            _expression += val;
          }
        }
      } else {
        _expression += val;
        _calculateResult(live: true);
      }
    });
  }

  void _calculateResult({bool live = false, bool save = false}) {
    if (_expression.trim().isEmpty) {
      _result = '0';
      return;
    }

    try {
      String cleanExp = _expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '*0.01');

      // Simple safe expression evaluator
      final val = _evaluateSimpleExpression(cleanExp);
      if (val != null) {
        final formatted = (val == val.roundToDouble())
            ? val.toInt().toString()
            : NumberFormat('0.######').format(val);

        _result = formatted;

        if (save && _expression.isNotEmpty) {
          _saveStandardCalculation(_expression, formatted);
        }
      }
    } catch (_) {
      if (!live) {
        _result = 'Error';
      }
    }
  }

  double? _evaluateSimpleExpression(String expr) {
    try {
      List<String> tokens = [];
      String currentNum = '';

      for (int i = 0; i < expr.length; i++) {
        final ch = expr[i];
        if ('0123456789.'.contains(ch)) {
          currentNum += ch;
        } else if ('+-*/'.contains(ch)) {
          if (currentNum.isNotEmpty) {
            tokens.add(currentNum);
            currentNum = '';
          } else if (ch == '-' && (tokens.isEmpty || '+-*/'.contains(tokens.last))) {
            currentNum = '-';
            continue;
          }
          tokens.add(ch);
        }
      }
      if (currentNum.isNotEmpty) tokens.add(currentNum);

      if (tokens.isEmpty) return null;

      // Process * and /
      List<String> nextTokens = [];
      int idx = 0;
      while (idx < tokens.length) {
        if (tokens[idx] == '*' || tokens[idx] == '/') {
          final op = tokens[idx];
          final prevNum = double.parse(nextTokens.removeLast());
          final nextNum = double.parse(tokens[++idx]);
          final res = (op == '*') ? (prevNum * nextNum) : (nextNum == 0 ? 0.0 : prevNum / nextNum);
          nextTokens.add(res.toString());
        } else {
          nextTokens.add(tokens[idx]);
        }
        idx++;
      }

      // Process + and -
      double finalVal = double.parse(nextTokens[0]);
      idx = 1;
      while (idx < nextTokens.length) {
        final op = nextTokens[idx];
        final nextNum = double.parse(nextTokens[idx + 1]);
        if (op == '+') finalVal += nextNum;
        if (op == '-') finalVal -= nextNum;
        idx += 2;
      }
      return finalVal;
    } catch (_) {
      return null;
    }
  }

  void _saveStandardCalculation(String exp, String res) async {
    final id = 'calc-${DateTime.now().millisecondsSinceEpoch}';
    await DatabaseHelper.instance.insertCalculatorHistory(
      id: id,
      calcType: 'standard',
      title: 'Standard Calculation',
      summary: '$exp = $res',
      detailsJson: jsonEncode({'expression': exp, 'result': res}),
      mode: widget.activeMode,
    );
    if (mounted) {
      CustomToast.show(context, 'Calculation saved to history ✨');
    }
  }

  Widget _buildCalcBtn(String label, {Color? bg, Color? fg, bool isWide = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9);
    final defaultFg = isDark ? Colors.white : Colors.black87;

    return Expanded(
      flex: isWide ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: InkWell(
          onTap: () => _onBtnTap(label),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: bg ?? defaultBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
              ),
              boxShadow: bg != null
                  ? [
                      BoxShadow(
                        color: bg.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: fg ?? defaultFg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opColor = const Color(0xFF00D09C);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 24.0),
      child: Column(
        children: [
          // Display Screen Card (Spacious, bold, stable pro display)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 140),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Expression row (Always occupies fixed height to prevent jumping/flickering)
                Container(
                  height: 28,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _expression.isNotEmpty ? _expression : '',
                    style: GoogleFonts.firaCode(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                // Main Result Display
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _result,
                    style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00D09C),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Keypad Rows
          Row(
            children: [
              _buildCalcBtn('AC', fg: Colors.redAccent),
              _buildCalcBtn('⌫', fg: Colors.orangeAccent),
              _buildCalcBtn('%', fg: opColor),
              _buildCalcBtn('÷', fg: opColor),
            ],
          ),
          Row(
            children: [
              _buildCalcBtn('7'),
              _buildCalcBtn('8'),
              _buildCalcBtn('9'),
              _buildCalcBtn('×', fg: opColor),
            ],
          ),
          Row(
            children: [
              _buildCalcBtn('4'),
              _buildCalcBtn('5'),
              _buildCalcBtn('6'),
              _buildCalcBtn('-', fg: opColor),
            ],
          ),
          Row(
            children: [
              _buildCalcBtn('1'),
              _buildCalcBtn('2'),
              _buildCalcBtn('3'),
              _buildCalcBtn('+', fg: opColor),
            ],
          ),
          Row(
            children: [
              _buildCalcBtn('0', isWide: true),
              _buildCalcBtn('.'),
              _buildCalcBtn('=', bg: opColor, fg: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2: MARKET PRICE / SABJI MANDI UNIT CALCULATOR (Manual + AI Voice)
// ═══════════════════════════════════════════════════════════════════════════

class _MarketPriceCalculatorView extends StatefulWidget {
  final String langCode;
  final String activeMode;
  const _MarketPriceCalculatorView({this.langCode = 'en_IN', this.activeMode = 'personal'});

  @override
  State<_MarketPriceCalculatorView> createState() => _MarketPriceCalculatorViewState();
}

class _MarketPriceCalculatorViewState extends State<_MarketPriceCalculatorView> {
  int _modeIndex = 0; // 0: Manual Unit Calc, 1: AI Mandi Voice Rate Analyzer

  // Manual Unit State (Starts Fresh & Empty)
  final _itemNameCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();
  final _baseQuantityCtrl = TextEditingController(text: '1');
  String _selectedUnit = 'kg'; // 'kg', 'g', 'litre', 'ml', 'dozen', 'piece'

  // Custom Target Calc Box
  final _customQuantityCtrl = TextEditingController();
  String _customQuantityUnit = 'g';
  double _customResultPrice = 0.0;

  final _customBudgetCtrl = TextEditingController();
  String _customResultQuantity = '';

  // AI Voice State
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAiProcessing = false;
  String _spokenText = '';
  String _selectedVoiceLangCode = 'en_IN';
  Map<String, dynamic>? _aiParsedResult;

  final List<String> _units = ['kg', 'g', 'litre', 'ml', 'dozen', 'piece'];

  @override
  void initState() {
    super.initState();
    _selectedVoiceLangCode = widget.langCode;
    _loadVoiceLanguage();
    _recomputeManualRates();
  }

  @override
  void didUpdateWidget(covariant _MarketPriceCalculatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.langCode != widget.langCode) {
      _selectedVoiceLangCode = widget.langCode;
    }
  }

  Future<void> _loadVoiceLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kPrefCalcVoiceLang);
    if (saved != null && mounted) {
      setState(() => _selectedVoiceLangCode = saved);
    }
  }

  Future<void> _setVoiceLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefCalcVoiceLang, code);
    if (mounted) {
      setState(() => _selectedVoiceLangCode = code);
      final lang = kSupportedCalcVoiceLanguages.firstWhere(
        (l) => l.code == code,
        orElse: () => kSupportedCalcVoiceLanguages.first,
      );
      CustomToast.show(context, 'Voice language set to ${lang.name} (${lang.nativeName}) ${lang.flag}');
    }
  }

  String get _effectiveSttLocale {
    if (_selectedVoiceLangCode == 'hinglish') return 'en_IN';
    return _selectedVoiceLangCode;
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _basePriceCtrl.dispose();
    _baseQuantityCtrl.dispose();
    _customQuantityCtrl.dispose();
    _customBudgetCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  double get _ratePerBaseStandardUnit {
    final price = double.tryParse(_basePriceCtrl.text) ?? 0.0;
    final qty = double.tryParse(_baseQuantityCtrl.text) ?? 1.0;
    if (qty <= 0) return 0.0;

    if (_selectedUnit == 'g') {
      return (price / qty) * 1000.0; // Rate per 1 kg
    } else if (_selectedUnit == 'ml') {
      return (price / qty) * 1000.0; // Rate per 1 L
    }
    return price / qty;
  }

  void _recomputeManualRates() {
    setState(() {
      final ratePerStd = _ratePerBaseStandardUnit;

      // 1. Custom Quantity Price Calc
      final customQty = double.tryParse(_customQuantityCtrl.text) ?? 0.0;
      if (customQty > 0) {
        if (_customQuantityUnit == 'g') {
          _customResultPrice = (ratePerStd / 1000.0) * customQty;
        } else if (_customQuantityUnit == 'kg') {
          _customResultPrice = ratePerStd * customQty;
        } else if (_customQuantityUnit == 'ml') {
          _customResultPrice = (ratePerStd / 1000.0) * customQty;
        } else if (_customQuantityUnit == 'litre') {
          _customResultPrice = ratePerStd * customQty;
        } else {
          _customResultPrice = ratePerStd * customQty;
        }
      } else {
        _customResultPrice = 0.0;
      }

      // 2. Custom Budget Quantity Calc
      final budget = double.tryParse(_customBudgetCtrl.text) ?? 0.0;
      if (budget > 0 && ratePerStd > 0) {
        if (_selectedUnit == 'kg' || _selectedUnit == 'g') {
          final totalGrams = (budget / ratePerStd) * 1000.0;
          if (totalGrams >= 1000) {
            _customResultQuantity = '${(totalGrams / 1000.0).toStringAsFixed(2)} kg';
          } else {
            _customResultQuantity = '${totalGrams.toStringAsFixed(0)} g';
          }
        } else if (_selectedUnit == 'litre' || _selectedUnit == 'ml') {
          final totalMl = (budget / ratePerStd) * 1000.0;
          if (totalMl >= 1000) {
            _customResultQuantity = '${(totalMl / 1000.0).toStringAsFixed(2)} L';
          } else {
            _customResultQuantity = '${totalMl.toStringAsFixed(0)} ml';
          }
        } else {
          final pcs = budget / ratePerStd;
          _customResultQuantity = '${pcs.toStringAsFixed(1)} pcs';
        }
      } else {
        _customResultQuantity = '0';
      }
    });
  }

  void _saveManualMarketCalculation() async {
    final item = _itemNameCtrl.text.trim().isEmpty ? 'Market Item' : _itemNameCtrl.text.trim();
    final price = double.tryParse(_basePriceCtrl.text) ?? 0.0;
    final qty = _baseQuantityCtrl.text.trim();
    final stdRate = _ratePerBaseStandardUnit;

    final id = 'market-${DateTime.now().millisecondsSinceEpoch}';
    final summary = '$item: ₹$price for $qty $_selectedUnit (₹${stdRate.toStringAsFixed(2)} / std unit)';

    await DatabaseHelper.instance.insertCalculatorHistory(
      id: id,
      calcType: 'market_unit',
      title: 'Market Rate: $item',
      summary: summary,
      detailsJson: jsonEncode({
        'item_name': item,
        'base_price': price,
        'base_qty': qty,
        'unit': _selectedUnit,
        'rate_per_std': stdRate,
      }),
      mode: widget.activeMode,
    );

    if (mounted) {
      CustomToast.show(context, 'Market price saved to history! 🛒');
    }
  }

  // ─── AI VOICE RECOGNITION & GEMINI PARSING ───

  Future<void> _startAiListening() async {
    if (!checkAndPromptAiConfig(context)) return;

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
            if (_spokenText.trim().isNotEmpty && !_isAiProcessing) {
              _processMandiVoice(_spokenText);
            }
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isListening = false);
          CustomToast.show(context, 'Mic error: ${e.errorMsg}', isError: true);
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _spokenText = '';
        _aiParsedResult = null;
      });
      HapticFeedback.mediumImpact();

      await _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() => _spokenText = val.recognizedWords);
          }
        },
        localeId: _effectiveSttLocale,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      if (mounted) {
        CustomToast.show(context, 'Speech recognition not available on this device.', isError: true);
      }
    }
  }

  Future<void> _stopAiListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_spokenText.trim().isNotEmpty && !_isAiProcessing) {
      _processMandiVoice(_spokenText);
    }
  }

  Future<void> _processMandiVoice(String text) async {
    setState(() {
      _isAiProcessing = true;
    });

    final activeLang = kSupportedCalcVoiceLanguages.firstWhere(
      (l) => l.code == _selectedVoiceLangCode,
      orElse: () => kSupportedCalcVoiceLanguages.first,
    );

    final aiService = AiConfigService.instance;
    final result = await aiService.parseMarketVoicePrice(
      text,
      spokenLanguage: '${activeLang.name} (${activeLang.nativeName})',
    );

    if (!mounted) return;
    setState(() {
      _isAiProcessing = false;
    });

    if (result['success'] == true && result['data'] != null) {
      setState(() {
        _aiParsedResult = result['data'] as Map<String, dynamic>;
      });
      HapticFeedback.mediumImpact();
      CustomToast.show(context, 'Mandi rates parsed successfully! 🎉');
    } else {
      final errorMsg = result['error']?.toString() ?? 'Could not parse market voice.';
      if (aiService.isServerBusyError(errorMsg)) {
        showAiServerBusyDialog(context, onRetry: () => _processMandiVoice(text));
      } else {
        CustomToast.show(context, errorMsg, isError: true);
      }
    }
  }

  void _saveAiMarketShoppingList() async {
    if (_aiParsedResult == null) return;
    final items = _aiParsedResult!['items'] as List? ?? [];
    if (items.isEmpty) return;

    final id = 'mandi-ai-${DateTime.now().millisecondsSinceEpoch}';
    final summary = '${items.length} items parsed via AI Mandi Voice (${items.map((i) => i['item_name']).join(', ')})';

    await DatabaseHelper.instance.insertCalculatorHistory(
      id: id,
      calcType: 'market_voice',
      title: 'Mandi Voice Shopping List (${items.length} Items)',
      summary: summary,
      detailsJson: jsonEncode(_aiParsedResult),
      mode: widget.activeMode,
    );

    if (mounted) {
      CustomToast.show(context, 'Shopping breakdown saved to history! 🛒✨');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final str = CalcHubStrings.of(widget.langCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Switcher (Manual vs AI Voice)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _modeIndex = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _modeIndex == 0 ? const Color(0xFF00D09C) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: _modeIndex == 0 ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            str.manualRate,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: _modeIndex == 0 ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _modeIndex = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _modeIndex == 1 ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic_none_rounded,
                            size: 16,
                            color: _modeIndex == 1 ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            str.aiVoice,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: _modeIndex == 1 ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_modeIndex == 0) ...[
            _buildManualUnitCalculatorSection(isDark, primaryColor, str),
          ] else ...[
            _buildAiVoiceSection(isDark, primaryColor, str),
          ],
        ],
      ),
    );
  }

  Widget _buildManualUnitCalculatorSection(bool isDark, Color primaryColor, CalcHubStrings str) {
    final ratePerStd = _ratePerBaseStandardUnit;
    final stdUnitLabel = (_selectedUnit == 'g' || _selectedUnit == 'kg')
        ? 'kg'
        : (_selectedUnit == 'ml' || _selectedUnit == 'litre')
            ? 'L'
            : _selectedUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Inputs Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                str.vegGroceryRateInput,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _itemNameCtrl,
                decoration: InputDecoration(
                  labelText: str.itemNameOptional,
                  hintText: 'e.g. Tomato, Potato, Paneer, Oil',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                ),
                onChanged: (_) => _recomputeManualRates(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _basePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: str.basePrice,
                        hintText: 'e.g. 40',
                        prefixText: '₹ ',
                      ),
                      onChanged: (_) => _recomputeManualRates(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    str.forQty,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _baseQuantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: str.forQty,
                        hintText: '1',
                      ),
                      onChanged: (_) => _recomputeManualRates(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: InputDecoration(labelText: str.unit),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedUnit = val;
                            if (val == 'kg' || val == 'g') {
                              _customQuantityUnit = 'g';
                            } else if (val == 'litre' || val == 'ml') {
                              _customQuantityUnit = 'ml';
                            } else {
                              _customQuantityUnit = val;
                            }
                          });
                          _recomputeManualRates();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Standard Unit Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D09C), Color(0xFF02B589)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str.stdUnitRate,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    Text(
                      '₹${ratePerStd.toStringAsFixed(2)} / 1 $stdUnitLabel',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _saveManualMarketCalculation,
                icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
                tooltip: str.saveHistory,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Standard Quantity Matrix (100g, 250g, 500g, 1kg etc.)
        Text(
          str.quickBreakdown,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _buildQuantityGrid(ratePerStd, isDark),
        const SizedBox(height: 16),

        // Custom Calculator Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                str.customCalc,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              // Option A: Enter Custom Quantity -> Get Price
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _customQuantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${str.wantToBuy} ($_customQuantityUnit)',
                        hintText: 'e.g. 250',
                        prefixIcon: const Icon(Icons.scale_rounded, size: 18),
                      ),
                      onChanged: (_) => _recomputeManualRates(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D09C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00D09C).withOpacity(0.3)),
                      ),
                      child: Text(
                        _customResultPrice > 0 ? '₹${_customResultPrice.toStringAsFixed(2)}' : '₹0.00',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF00D09C)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Option B: Enter Budget -> Get Quantity
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _customBudgetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: str.budgetLabel,
                        hintText: 'e.g. 50',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                      ),
                      onChanged: (_) => _recomputeManualRates(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                      ),
                      child: Text(
                        _customResultQuantity.isNotEmpty ? _customResultQuantity : '-',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF38BDF8)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityGrid(double ratePerStd, bool isDark) {
    List<Map<String, dynamic>> items = [];

    if (_selectedUnit == 'kg' || _selectedUnit == 'g') {
      items = [
        {'label': '50g', 'price': (ratePerStd / 1000.0) * 50},
        {'label': '100g', 'price': (ratePerStd / 1000.0) * 100},
        {'label': '250g', 'price': (ratePerStd / 1000.0) * 250},
        {'label': '500g', 'price': (ratePerStd / 1000.0) * 500},
        {'label': '750g', 'price': (ratePerStd / 1000.0) * 750},
        {'label': '1 kg', 'price': ratePerStd},
        {'label': '1.5 kg', 'price': ratePerStd * 1.5},
        {'label': '2 kg', 'price': ratePerStd * 2},
        {'label': '5 kg', 'price': ratePerStd * 5},
      ];
    } else if (_selectedUnit == 'litre' || _selectedUnit == 'ml') {
      items = [
        {'label': '100 ml', 'price': (ratePerStd / 1000.0) * 100},
        {'label': '250 ml', 'price': (ratePerStd / 1000.0) * 250},
        {'label': '500 ml', 'price': (ratePerStd / 1000.0) * 500},
        {'label': '1 L', 'price': ratePerStd},
        {'label': '2 L', 'price': ratePerStd * 2},
        {'label': '5 L', 'price': ratePerStd * 5},
      ];
    } else {
      items = [
        {'label': '1 pc', 'price': ratePerStd},
        {'label': '2 pcs', 'price': ratePerStd * 2},
        {'label': '4 pcs', 'price': ratePerStd * 4},
        {'label': '6 pcs (Half Dozen)', 'price': ratePerStd * 6},
        {'label': '12 pcs (1 Dozen)', 'price': ratePerStd * 12},
      ];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item['label'],
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${(item['price'] as double).toStringAsFixed(1)}',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiVoiceSection(bool isDark, Color primaryColor, CalcHubStrings str) {
    final activeLang = kSupportedCalcVoiceLanguages.firstWhere(
      (l) => l.code == _selectedVoiceLangCode,
      orElse: () => kSupportedCalcVoiceLanguages.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Voice Control Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    str.aiVoiceAnalyzer,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Active Language Pill & Switcher
              InkWell(
                onTap: () {
                  showCalcLanguagePickerSheet(
                    context: context,
                    currentCode: _selectedVoiceLangCode,
                    onSelected: _setVoiceLanguage,
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(activeLang.flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        '${activeLang.name} (${activeLang.nativeName})',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                activeLang.sampleHint,
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Mic Action Button
              GestureDetector(
                onTap: _isListening ? _stopAiListening : _startAiListening,
                child: Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.redAccent : Colors.white).withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isListening ? Colors.white : const Color(0xFF6366F1),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isListening
                    ? '${str.listeningNow} (${activeLang.name})...'
                    : (_isAiProcessing ? str.processingAi : str.tapMicToSpeak),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Spoken transcript preview
        if (_spokenText.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.record_voice_over_rounded, size: 18, color: Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"$_spokenText"',
                    style: GoogleFonts.inter(fontSize: 12.5, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Parsed AI Result Cards
        if (_aiParsedResult != null) ...[
          _buildAiParsedResultView(isDark),
        ],
      ],
    );
  }

  Widget _buildAiParsedResultView(bool isDark) {
    final items = _aiParsedResult!['items'] as List? ?? [];
    final summary = _aiParsedResult!['market_summary']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Parsed Market Items (${items.length})',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            TextButton.icon(
              onPressed: _saveAiMarketShoppingList,
              icon: const Icon(Icons.bookmark_added_rounded, size: 18, color: Color(0xFF00D09C)),
              label: Text(
                'Save All',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
              ),
            ),
          ],
        ),
        if (summary.isNotEmpty) ...[
          Text(summary, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
        ],
        ...items.map((item) {
          final name = item['item_name']?.toString() ?? 'Item';
          final basePrice = item['base_price'];
          final baseQty = item['base_quantity'];
          final baseUnit = item['base_unit']?.toString() ?? 'kg';
          final rateStd = item['rate_per_standard_unit'];
          final stdUnit = item['standard_unit']?.toString() ?? 'kg';
          final qBreakdowns = item['quantity_breakdown'] as List? ?? [];
          final bBreakdowns = item['budget_breakdown'] as List? ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00D09C).withOpacity(0.35),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D09C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹$rateStd / $stdUnit',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF00D09C)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Base Quote: ₹$basePrice for $baseQty $baseUnit',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 18),

                // Quantity breakdown chips
                if (qBreakdowns.isNotEmpty) ...[
                  Text(
                    'Price by Weight / Quantity:',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: qBreakdowns.map((q) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222836) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${q['quantity']}: ₹${q['price']}',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // Budget breakdown chips
                if (bBreakdowns.isNotEmpty) ...[
                  Text(
                    'Quantity by Budget:',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: bBreakdowns.map((b) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'For ${b['budget']} ➔ ${b['quantity']}',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: EMI & LOAN CALCULATOR (With Dotted Tick Track & Direct Click Inputs)
// ═══════════════════════════════════════════════════════════════════════════

class _EmiCalculatorView extends StatefulWidget {
  final String langCode;
  final String activeMode;
  const _EmiCalculatorView({this.langCode = 'en_IN', this.activeMode = 'personal'});

  @override
  State<_EmiCalculatorView> createState() => _EmiCalculatorViewState();
}

class _EmiCalculatorViewState extends State<_EmiCalculatorView> {
  double _loanAmount = 0;
  double _interestRate = 0;
  double _tenureYears = 0;
  bool _isTenureInYears = true;

  final _loanAmountCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _loanAmountCtrl.dispose();
    _interestRateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    setState(() {});
  }

  double get _monthlyEmi {
    final P = _loanAmount;
    final r = (_interestRate / 12) / 100;
    final n = _isTenureInYears ? (_tenureYears * 12) : _tenureYears;
    if (P <= 0 || r <= 0 || n <= 0) return 0.0;
    final emi = (P * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    return emi.isNaN || emi.isInfinite ? 0.0 : emi;
  }

  double get _totalPayment {
    final n = _isTenureInYears ? (_tenureYears * 12) : _tenureYears;
    return _monthlyEmi * n;
  }

  double get _totalInterest {
    return _totalPayment - _loanAmount;
  }

  void _saveEmiCalculation() async {
    final id = 'emi-${DateTime.now().millisecondsSinceEpoch}';
    final summary = 'Loan: ₹${NumberFormat('#,##,###').format(_loanAmount)} at ${_interestRate}% for ${_tenureYears.toInt()} ${_isTenureInYears ? 'Yrs' : 'Mos'} ➔ EMI: ₹${NumberFormat('#,##,###').format(_monthlyEmi)}/mo';

    await DatabaseHelper.instance.insertCalculatorHistory(
      id: id,
      calcType: 'emi',
      title: 'EMI: ₹${NumberFormat('#,##,###').format(_loanAmount)} Loan',
      summary: summary,
      detailsJson: jsonEncode({
        'loan_amount': _loanAmount,
        'interest_rate': _interestRate,
        'tenure': _tenureYears,
        'is_years': _isTenureInYears,
        'monthly_emi': _monthlyEmi,
        'total_interest': _totalInterest,
        'total_payment': _totalPayment,
      }),
      mode: widget.activeMode,
    );

    if (mounted) {
      CustomToast.show(context, 'EMI calculation saved to history! 🏦');
    }
  }

  void _showEditValueDialog({
    required String title,
    required String initialValue,
    required String suffix,
    required ValueChanged<double> onSubmitted,
    double min = 0,
    double max = 100000000,
  }) {
    final str = CalcHubStrings.of(widget.langCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF00D09C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              str.tapToEdit,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                suffixText: suffix.isNotEmpty ? ' $suffix' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF00D09C), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(str.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val >= min && val <= max) {
                onSubmitted(val);
                Navigator.of(ctx).pop();
              } else {
                CustomToast.show(context, 'Please enter a valid value between $min and $max', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(str.apply, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##,###');
    final str = CalcHubStrings.of(widget.langCode);

    final principalShare = _totalPayment > 0 ? (_loanAmount / _totalPayment).clamp(0.0, 1.0) : 0.5;
    final interestShare = 1.0 - principalShare;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Highlight EMI Result Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D09C), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D09C).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      str.monthlyEmi,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70),
                    ),
                    IconButton(
                      onPressed: _saveEmiCalculation,
                      icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
                      tooltip: str.saveHistory,
                    ),
                  ],
                ),
                Text(
                  '₹${fmt.format(_monthlyEmi.round())}',
                  style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(str.totalInterest, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                        const SizedBox(height: 2),
                        Text('₹${fmt.format(_totalInterest.round())}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Container(height: 24, width: 1, color: Colors.white24),
                    Column(
                      children: [
                        Text(str.totalAmount, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                        const SizedBox(height: 2),
                        Text('₹${fmt.format(_totalPayment.round())}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Principal vs Interest Visual Ratio Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF00D09C), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${str.principal} (${(principalShare * 100).toStringAsFixed(1)}%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF6B6B), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${str.interest} (${(interestShare * 100).toStringAsFixed(1)}%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (principalShare * 100).round().clamp(1, 99),
                          child: Container(color: const Color(0xFF00D09C)),
                        ),
                        Expanded(
                          flex: (interestShare * 100).round().clamp(1, 99),
                          child: Container(color: const Color(0xFFFF6B6B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 1. Loan Amount Slider & Input (Interactive on tap + granular smooth slider + milestone dots)
          _buildInputCard(
            title: str.loanAmount,
            valueText: _loanAmount > 0 ? '₹${fmt.format(_loanAmount.round())}' : '₹0',
            sliderValue: _loanAmount > 0 ? _loanAmount.clamp(10000, 5000000) : 0,
            min: 0,
            max: 5000000,
            onSliderChanged: (val) {
              final stepped = (val / 10000).round() * 10000.0;
              setState(() {
                _loanAmount = stepped;
                _loanAmountCtrl.text = _loanAmount > 0 ? _loanAmount.round().toString() : '';
              });
            },
            onValueTap: () {
              _showEditValueDialog(
                title: str.enterAmount,
                initialValue: _loanAmount > 0 ? _loanAmount.round().toString() : '',
                suffix: '₹',
                min: 0,
                max: 100000000,
                onSubmitted: (val) {
                  setState(() {
                    _loanAmount = val;
                    _loanAmountCtrl.text = val > 0 ? val.round().toString() : '';
                  });
                },
              );
            },
            isDark: isDark,
            presets: [50000, 100000, 500000, 1000000, 2500000, 5000000],
            onPresetSelected: (val) {
              setState(() {
                _loanAmount = val.toDouble();
                _loanAmountCtrl.text = val.toString();
              });
            },
          ),
          const SizedBox(height: 14),

          // 2. Interest Rate Slider & Input (Interactive on tap + milestone dots)
          _buildInputCard(
            title: str.interestRatePa,
            valueText: _interestRate > 0 ? '${_interestRate.toStringAsFixed(1)}%' : '0.0%',
            sliderValue: _interestRate > 0 ? _interestRate.clamp(1, 30) : 0,
            min: 0,
            max: 30,
            onSliderChanged: (val) {
              final stepped = (val * 10).round() / 10.0;
              setState(() {
                _interestRate = stepped;
                _interestRateCtrl.text = stepped > 0 ? stepped.toStringAsFixed(1) : '';
              });
            },
            onValueTap: () {
              _showEditValueDialog(
                title: str.enterRate,
                initialValue: _interestRate > 0 ? _interestRate.toStringAsFixed(1) : '',
                suffix: '%',
                min: 0.0,
                max: 50.0,
                onSubmitted: (val) {
                  setState(() {
                    _interestRate = val;
                    _interestRateCtrl.text = val > 0 ? val.toStringAsFixed(1) : '';
                  });
                },
              );
            },
            isDark: isDark,
            presets: [7.5, 8.5, 10.5, 12.0, 14.5, 18.0],
            presetSuffix: '%',
            onPresetSelected: (val) {
              setState(() {
                _interestRate = val.toDouble();
                _interestRateCtrl.text = val.toString();
              });
            },
          ),
          const SizedBox(height: 14),

          // 3. Tenure Slider & Input (Interactive on tap + milestone dots)
          _buildInputCard(
            title: str.loanTenure,
            valueText: _tenureYears > 0 ? '${_tenureYears.toInt()} ${_isTenureInYears ? str.years : str.months}' : '0 ${_isTenureInYears ? str.years : str.months}',
            sliderValue: _tenureYears > 0 ? _tenureYears.clamp(1, _isTenureInYears ? 30 : 360) : 0,
            min: 0,
            max: _isTenureInYears ? 30 : 360,
            onSliderChanged: (val) {
              setState(() {
                _tenureYears = val.roundToDouble();
                _tenureCtrl.text = _tenureYears > 0 ? _tenureYears.round().toString() : '';
              });
            },
            onValueTap: () {
              _showEditValueDialog(
                title: str.enterTenure,
                initialValue: _tenureYears > 0 ? _tenureYears.round().toString() : '',
                suffix: _isTenureInYears ? str.years : str.months,
                min: 0,
                max: _isTenureInYears ? 50 : 600,
                onSubmitted: (val) {
                  setState(() {
                    _tenureYears = val;
                    _tenureCtrl.text = val > 0 ? val.round().toString() : '';
                  });
                },
              );
            },
            isDark: isDark,
            presets: _isTenureInYears
                ? [1, 3, 5, 10, 15, 20, 25, 30]
                : [6, 12, 24, 36, 60, 120, 240, 360],
            presetSuffix: _isTenureInYears ? ' Yr' : ' Mo',
            onPresetSelected: (val) {
              setState(() {
                _tenureYears = val.toDouble();
                _tenureCtrl.text = val.toInt().toString();
              });
            },
            headerWidget: Container(
              height: 28,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262E3D) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF333E50) : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isTenureInYears = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isTenureInYears ? const Color(0xFF00D09C) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Yr',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isTenureInYears ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isTenureInYears = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: !_isTenureInYears ? const Color(0xFF00D09C) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Mo',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: !_isTenureInYears ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required String valueText,
    required double sliderValue,
    required double min,
    required double max,
    required ValueChanged<double> onSliderChanged,
    required bool isDark,
    int? divisions,
    VoidCallback? onValueTap,
    Widget? headerWidget,
    List<num>? presets,
    String presetSuffix = '',
    ValueChanged<num>? onPresetSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (headerWidget != null) ...[
                const SizedBox(width: 8),
                headerWidget,
              ],
              const SizedBox(width: 8),
              InkWell(
                onTap: onValueTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D09C).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00D09C).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valueText,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00D09C),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF00D09C)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: const Color(0xFF00D09C),
              inactiveTrackColor: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF00D09C),
              overlayColor: const Color(0xFF00D09C).withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: sliderValue,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onSliderChanged,
            ),
          ),
          if (presets != null) ...[
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.map((p) {
                  final label = p >= 100000
                      ? '${(p / 100000).toStringAsFixed(p % 100000 == 0 ? 0 : 1)}L'
                      : (p >= 1000 ? '${(p / 1000).toStringAsFixed(0)}k' : '$p$presetSuffix');
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      onPressed: () => onPresetSelected?.call(p),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4: DAILY FINANCIAL TOOLS (GST, Discount, SIP)
// ═══════════════════════════════════════════════════════════════════════════

class _DailyFinancialToolsView extends StatefulWidget {
  final String langCode;
  final String activeMode;
  const _DailyFinancialToolsView({this.langCode = 'en_IN', this.activeMode = 'personal'});

  @override
  State<_DailyFinancialToolsView> createState() => _DailyFinancialToolsViewState();
}

class _DailyFinancialToolsViewState extends State<_DailyFinancialToolsView> {
  int _toolIndex = 0; // 0: GST, 1: Discount, 2: SIP

  // GST State (Starts Fresh & Empty)
  final _gstAmountCtrl = TextEditingController();
  double _gstRate = 18.0;
  bool _isGstExclusive = true; // true: Add GST, false: Remove GST

  // Discount State (Starts Fresh & Empty)
  final _originalPriceCtrl = TextEditingController();
  final _discountPercentCtrl = TextEditingController();

  // SIP State (Starts Fresh & Empty)
  double _monthlySip = 0;
  double _expectedReturnRate = 12.0;
  double _sipTenureYears = 10;

  @override
  void dispose() {
    _gstAmountCtrl.dispose();
    _originalPriceCtrl.dispose();
    _discountPercentCtrl.dispose();
    super.dispose();
  }

  void _saveToolCalculation(String type, String title, String summary, Map<String, dynamic> data) async {
    final id = '$type-${DateTime.now().millisecondsSinceEpoch}';
    await DatabaseHelper.instance.insertCalculatorHistory(
      id: id,
      calcType: type,
      title: title,
      summary: summary,
      detailsJson: jsonEncode(data),
      mode: widget.activeMode,
    );
    if (mounted) {
      CustomToast.show(context, 'Calculation saved to history! ✨');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final str = CalcHubStrings.of(widget.langCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tool Selector Chips
          Row(
            children: [
              _buildToolChip(str.gstTax, 0, Icons.receipt_long_outlined),
              const SizedBox(width: 8),
              _buildToolChip(str.discount, 1, Icons.local_offer_outlined),
              const SizedBox(width: 8),
              _buildToolChip(str.sipWealth, 2, Icons.trending_up_rounded),
            ],
          ),
          const SizedBox(height: 18),

          if (_toolIndex == 0) _buildGstView(isDark, str),
          if (_toolIndex == 1) _buildDiscountView(isDark, str),
          if (_toolIndex == 2) _buildSipView(isDark, str),
        ],
      ),
    );
  }

  Widget _buildToolChip(String label, int index, IconData icon) {
    final isSelected = _toolIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _toolIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00D09C) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF00D09C) : Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. GST CALCULATOR VIEW
  Widget _buildGstView(bool isDark, CalcHubStrings str) {
    final base = double.tryParse(_gstAmountCtrl.text) ?? 0.0;
    double gstAmount = 0.0;
    double totalAmount = 0.0;
    double netAmount = 0.0;

    if (_isGstExclusive) {
      // Add GST to base
      gstAmount = (base * _gstRate) / 100.0;
      totalAmount = base + gstAmount;
      netAmount = base;
    } else {
      // GST is inclusive in base
      netAmount = (base * 100.0) / (100.0 + _gstRate);
      gstAmount = base - netAmount;
      totalAmount = base;
    }

    final fmt = NumberFormat('#,##,###.##');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Result Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL AMOUNT (WITH GST)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  IconButton(
                    onPressed: () => _saveToolCalculation(
                      'gst',
                      'GST Calculation (₹$base @ $_gstRate%)',
                      'Total: ₹${fmt.format(totalAmount)} (Net: ₹${fmt.format(netAmount)}, GST: ₹${fmt.format(gstAmount)})',
                      {'base': base, 'rate': _gstRate, 'is_exclusive': _isGstExclusive, 'gst': gstAmount, 'total': totalAmount},
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
                  ),
                ],
              ),
              Text('₹${fmt.format(totalAmount)}', style: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 14),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Net Amount', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      Text('₹${fmt.format(netAmount)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('GST Amount (${_gstRate.toInt()}%)', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      Text('₹${fmt.format(gstAmount)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Inputs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _gstAmountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Initial Amount (₹)',
                  hintText: 'e.g. 1000',
                  prefixText: '₹ ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              Text('GST Rate Slab (%):', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [5.0, 12.0, 18.0, 28.0].map((r) {
                  final isSel = _gstRate == r;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: ChoiceChip(
                        label: Text('${r.toInt()}%'),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setState(() => _gstRate = r);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(str.addGst, style: const TextStyle(fontSize: 12.5)),
                      value: true,
                      groupValue: _isGstExclusive,
                      onChanged: (val) => setState(() => _isGstExclusive = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(str.removeGst, style: const TextStyle(fontSize: 12.5)),
                      value: false,
                      groupValue: _isGstExclusive,
                      onChanged: (val) => setState(() => _isGstExclusive = val!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. DISCOUNT CALCULATOR VIEW
  Widget _buildDiscountView(bool isDark, CalcHubStrings str) {
    final orig = double.tryParse(_originalPriceCtrl.text) ?? 0.0;
    final disc = double.tryParse(_discountPercentCtrl.text) ?? 0.0;

    final saved = (orig * disc) / 100.0;
    final finalPrice = orig - saved;
    final fmt = NumberFormat('#,##,###.##');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF9C27B0)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(str.finalPrice.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  IconButton(
                    onPressed: () => _saveToolCalculation(
                      'discount',
                      'Discount: $disc% off on ₹$orig',
                      'Final: ₹${fmt.format(finalPrice)} (You save ₹${fmt.format(saved)})',
                      {'original': orig, 'discount_pct': disc, 'saved': saved, 'final': finalPrice},
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
                  ),
                ],
              ),
              Text('₹${fmt.format(finalPrice)}', style: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 14),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(str.originalPrice, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      Text('₹${fmt.format(orig)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('${str.youSave} 🎉', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      Text('₹${fmt.format(saved)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _originalPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: str.originalPrice,
                  hintText: 'e.g. 2000',
                  prefixText: '₹ ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _discountPercentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: str.discountPercent,
                  hintText: 'e.g. 20',
                  suffixText: ' %',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [10, 15, 20, 25, 30, 40, 50, 70].map((d) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        label: Text('$d% off', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            _discountPercentCtrl.text = d.toString();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. SIP WEALTH CALCULATOR VIEW
  Widget _buildSipView(bool isDark, CalcHubStrings str) {
    final P = _monthlySip;
    final i = (_expectedReturnRate / 12) / 100.0;
    final n = _sipTenureYears * 12;

    double maturity = 0.0;
    if (i > 0 && n > 0 && P > 0) {
      maturity = P * ((pow(1 + i, n) - 1) / i) * (1 + i);
    }
    final invested = P * n;
    final wealthGained = maturity > invested ? maturity - invested : 0.0;
    final fmt = NumberFormat('#,##,###');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(str.totalFutureValue.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  IconButton(
                    onPressed: () => _saveToolCalculation(
                      'sip',
                      'SIP: ₹$P/mo @ ${_expectedReturnRate}% for ${_sipTenureYears.toInt()} yrs',
                      'Maturity: ₹${fmt.format(maturity.round())} (Wealth Gain: ₹${fmt.format(wealthGained.round())})',
                      {'monthly': P, 'rate': _expectedReturnRate, 'years': _sipTenureYears, 'invested': invested, 'maturity': maturity},
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
                  ),
                ],
              ),
              Text('₹${fmt.format(maturity.round())}', style: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 14),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(str.investedAmount, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      Text('₹${fmt.format(invested.round())}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('${str.estReturns} 🚀', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      Text('₹${fmt.format(wealthGained.round())}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(str.monthlySip, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                  Text(
                    _monthlySip > 0 ? '₹${fmt.format(_monthlySip.round())}' : '₹0',
                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                  ),
                ],
              ),
              Slider(
                value: _monthlySip.clamp(0, 100000),
                min: 0,
                max: 100000,
                divisions: 200,
                activeColor: const Color(0xFFF59E0B),
                onChanged: (val) => setState(() => _monthlySip = val),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(str.returnRatePa, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                  Text('${_expectedReturnRate.toStringAsFixed(1)} %', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                ],
              ),
              Slider(
                value: _expectedReturnRate,
                min: 5,
                max: 30,
                divisions: 50,
                activeColor: const Color(0xFFF59E0B),
                onChanged: (val) => setState(() => _expectedReturnRate = val),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(str.sipPeriod, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                  Text('${_sipTenureYears.toInt()} ${str.years}', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                ],
              ),
              Slider(
                value: _sipTenureYears,
                min: 1,
                max: 30,
                divisions: 29,
                activeColor: const Color(0xFFF59E0B),
                onChanged: (val) => setState(() => _sipTenureYears = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 5: CALCULATION HISTORY VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _CalculatorHistoryView extends StatefulWidget {
  final String langCode;
  final String activeMode;
  const _CalculatorHistoryView({this.langCode = 'en_IN', this.activeMode = 'personal'});

  @override
  State<_CalculatorHistoryView> createState() => _CalculatorHistoryViewState();
}

class _CalculatorHistoryViewState extends State<_CalculatorHistoryView> {
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getCalculatorHistory(
      type: _selectedFilter == 'all' ? null : _selectedFilter,
      mode: widget.activeMode,
    );
    if (mounted) {
      setState(() {
        _history = list;
        _isLoading = false;
      });
    }
  }

  void _deleteItem(String id, CalcHubStrings str) async {
    await DatabaseHelper.instance.deleteCalculatorHistory(id);
    _loadHistory();
    if (mounted) {
      CustomToast.show(context, str.historyDeleted);
    }
  }

  void _clearAll(CalcHubStrings str) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(str.historyClearTitle),
        content: Text(str.historyClearConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(str.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(str.historyClearAll),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.clearCalculatorHistory(
        type: _selectedFilter == 'all' ? null : _selectedFilter,
        mode: widget.activeMode,
      );
      _loadHistory();
      if (mounted) {
        CustomToast.show(context, str.historyCleared);
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'market_voice':
        return const Color(0xFF6366F1);
      case 'market_unit':
        return const Color(0xFF00D09C);
      case 'emi':
        return const Color(0xFF059669);
      case 'gst':
        return const Color(0xFF38BDF8);
      case 'discount':
        return const Color(0xFFE040FB);
      case 'sip':
        return const Color(0xFFF59E0B);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final str = CalcHubStrings.of(widget.langCode);

    return Column(
      children: [
        // Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(str.historyAll, 'all'),
                      const SizedBox(width: 6),
                      _buildFilterChip(str.historyMandiVoice, 'market_voice'),
                      const SizedBox(width: 6),
                      _buildFilterChip(str.historyUnitRates, 'market_unit'),
                      const SizedBox(width: 6),
                      _buildFilterChip(str.historyEmi, 'emi'),
                      const SizedBox(width: 6),
                      _buildFilterChip(str.historyGst, 'gst'),
                      const SizedBox(width: 6),
                      _buildFilterChip(str.historyDiscount, 'discount'),
                      const SizedBox(width: 6),
                      _buildFilterChip(str.historySip, 'sip'),
                      const SizedBox(width: 6),
                      _buildFilterChip(str.historyStandard, 'standard'),
                    ],
                  ),
                ),
              ),
              if (_history.isNotEmpty)
                IconButton(
                  onPressed: () => _clearAll(str),
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  tooltip: str.historyClearAll,
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Storage Note Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2B3245) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  str.historyStorageNote,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.35,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            str.historyNoRecords,
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (ctx, idx) {
                        final item = _history[idx];
                        final type = item['calc_type']?.toString() ?? 'standard';
                        final title = item['title']?.toString() ?? 'Calculation';
                        final summary = item['summary']?.toString() ?? '';
                        final dateStr = item['created_at']?.toString() ?? '';
                        final color = _getTypeColor(type);

                        DateTime? dt;
                        try {
                          dt = DateTime.parse(dateStr);
                        } catch (_) {}

                        final formattedDate = dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : dateStr;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF181B22) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      type.replaceAll('_', ' ').toUpperCase(),
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteItem(item['id'], str),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                summary,
                                style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: '$title\n$summary'));
                                      CustomToast.show(context, str.historyCopied);
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy_rounded, size: 13, color: color),
                                        const SizedBox(width: 4),
                                        Text(str.historyCopy, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSel = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: isSel,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = value);
          _loadHistory();
        }
      },
    );
  }
}
