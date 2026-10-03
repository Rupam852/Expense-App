import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_config_service.dart';
import '../services/database_helper.dart';
import '../services/expense_provider.dart';
import '../models/expense.dart';
import '../models/split_bill.dart';
import '../widgets/ai_config_required_dialog.dart';
import '../widgets/custom_toast.dart';
import 'ai_config_screen.dart';

class AiActionProposal {
  final String actionType; // 'ADD_EXPENSE', 'SET_BUDGET', 'ADD_KHATA', 'ADD_SPLIT'
  final Map<String, dynamic> data;
  bool isExecuted;
  bool isDismissed;

  AiActionProposal({
    required this.actionType,
    required this.data,
    this.isExecuted = false,
    this.isDismissed = false,
  });

  Map<String, dynamic> toJson() => {
    'type': actionType,
    'data': data,
    'isExecuted': isExecuted,
    'isDismissed': isDismissed,
  };

  factory AiActionProposal.fromJson(Map<String, dynamic> json) => AiActionProposal(
    actionType: json['type']?.toString() ?? json['actionType']?.toString() ?? '',
    data: Map<String, dynamic>.from(json['data'] ?? {}),
    isExecuted: json['isExecuted'] == true,
    isDismissed: json['isDismissed'] == true,
  );
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? modelUsed;
  AiActionProposal? actionProposal;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.modelUsed,
    this.actionProposal,
  }) : id = id ?? '${timestamp.millisecondsSinceEpoch}_${isUser ? 'user' : 'ai'}';

  String toRawText() {
    if (actionProposal != null) {
      return '$text\n<!--ACTION_INTENT:${json.encode(actionProposal!.toJson())}-->';
    }
    return text;
  }

  static ChatMessage fromRawText({
    String? id,
    required String rawText,
    required bool isUser,
    required DateTime timestamp,
    String? modelUsed,
  }) {
    if (isUser) {
      return ChatMessage(
        id: id,
        text: rawText,
        isUser: true,
        timestamp: timestamp,
        modelUsed: modelUsed,
      );
    }

    AiActionProposal? proposal;
    String cleanText = rawText;

    final match = RegExp(r'<!--ACTION_INTENT:(.*?)-->', dotAll: true).firstMatch(rawText);
    if (match != null) {
      try {
        final jsonStr = match.group(1)?.trim() ?? '';
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        proposal = AiActionProposal.fromJson(map);
        cleanText = rawText.replaceAll(match.group(0)!, '').trim();
      } catch (e) {
        debugPrint('[ChatMessage] Error parsing ACTION_INTENT: $e');
      }
    }

    return ChatMessage(
      id: id,
      text: cleanText,
      isUser: false,
      timestamp: timestamp,
      modelUsed: modelUsed,
      actionProposal: proposal,
    );
  }
}

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Voice speech integration for chat
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  static const List<Map<String, String>> _languageOptions = [
    {'code': 'English', 'label': 'English', 'native': 'English (Default)'},
    {'code': 'Hindi', 'label': 'Hindi', 'native': 'हिंदी'},
    {'code': 'Hinglish', 'label': 'Hinglish', 'native': 'Hinglish (Hindi in Roman)'},
    {'code': 'Bengali', 'label': 'Bengali', 'native': 'বাংলা'},
    {'code': 'Marathi', 'label': 'Marathi', 'native': 'मराठी'},
    {'code': 'Gujarati', 'label': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'Tamil', 'label': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'Telugu', 'label': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'Kannada', 'label': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'Malayalam', 'label': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'Punjabi', 'label': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
  ];

  static const Map<String, List<String>> _localizedSuggestions = {
    'English': [
      '➕ Add ₹500 for petrol expense',
      '➕ Add ₹250 for tea & snacks',
      '➕ Add ₹1,200 for grocery shopping',
      '➕ Add ₹350 for dinner on Swiggy',
      '➕ Add ₹1,500 electricity bill paid',
      '🎯 Set Food budget to ₹5,000',
      '🎯 Set Shopping budget to ₹8,000',
      '🎯 Show my monthly budget status',
      '📖 Lent ₹1,000 to Rahul, record in khata',
      '📖 Borrowed ₹500 from Aman, record it',
      '📖 Show all khata balances and dues',
      '👥 Split ₹1,500 dinner with Aman and Rohit',
      '👥 Split ₹600 cab fare with Rahul',
      '📊 How much did I spend this month?',
      '🍕 How much did I spend on Food & Dining?',
      '📊 What is my highest single expense?',
      '📅 Compare this month with last month',
      '💡 How can I save ₹3,000 every month?',
      '💡 Give me tips to reduce my expenses',
      '📈 What is my average daily spending?',
    ],
    'Hinglish': [
      '➕ ₹500 petrol kharcha add karo',
      '➕ ₹250 Chai & Nashta add karo',
      '➕ ₹1,200 Grocery shopping add karo',
      '➕ ₹350 Swiggy dinner add karo',
      '➕ ₹1,500 Electricity bill paid add karo',
      '🎯 Set Food budget to ₹5,000',
      '🎯 Set Shopping budget to ₹8,000',
      '🎯 Mera budget status dikhao',
      '📖 Rahul ko ₹1,000 udhar diya khate me likho',
      '📖 Aman se ₹500 udhar liya note karo',
      '📖 Khata list aur balances dikhao',
      '👥 Split ₹1,500 dinner with Aman and Rohit',
      '👥 Split ₹600 cab fare with Rahul',
      '📊 Is mahine total kitna kharcha hua?',
      '🍕 Food & Dining pe kitna kharcha hua?',
      '📊 Mera sabse bada kharcha kaunsa hai?',
      '📅 Pichle mahine aur is mahine ka comparison dikhao',
      '💡 Main har mahine ₹3,000 kaise bachaun?',
      '💡 Mere kharche kam karne ke tips do',
      '📈 Meri daily spending average kitni hai?',
    ],
    'Hindi': [
      '➕ ₹500 पेट्रोल का खर्च जोड़ें',
      '➕ ₹250 चाय और नाश्ता जोड़ें',
      '➕ ₹1,200 किराने का सामान जोड़ें',
      '➕ ₹350 रात के खाने का खर्च जोड़ें',
      '➕ ₹1,500 बिजली का बिल भरा जोड़ें',
      '🎯 भोजन का बजट ₹5,000 सेट करें',
      '🎯 शॉपिंग का बजट ₹8,000 सेट करें',
      '🎯 मेरा बजट स्टेटस दिखाएं',
      '📖 राहुल को ₹1,000 उधार दिया खाते में लिखें',
      '📖 अमन से ₹500 उधार लिया नोट करें',
      '📖 खाता बही और बाकी पैसे दिखाएं',
      '👥 ₹1,500 डिनर अमन और रोहित के साथ बांटें',
      '👥 ₹600 कैब किराया राहुल के साथ बांटें',
      '📊 इस महीने कुल कितना खर्च हुआ?',
      '🍕 भोजन पर कितना खर्च हुआ?',
      '📊 मेरा सबसे बड़ा खर्च कौन सा है?',
      '📅 पिछले महीने और इस महीने की तुलना करें',
      '💡 मैं हर महीने ₹3,000 कैसे बचा सकता हूँ?',
      '💡 खर्च कम करने के टिप्स दें',
      '📈 मेरा दैनिक औसत खर्च कितना है?',
    ],
    'Bengali': [
      '➕ ₹500 পেট্রোল খরচ যোগ করুন',
      '➕ ₹250 চা ও জলখাবার যোগ করুন',
      '➕ ₹1,200 মুদি বাজার যোগ করুন',
      '➕ ₹350 রাতের খাবারের খরচ যোগ করুন',
      '➕ ₹1,500 বিদ্যুৎ বিল পরিশোধ যোগ করুন',
      '🎯 খাবারের বাজেট ₹5,000 নির্ধারণ করুন',
      '🎯 শপিং বাজেট ₹8,000 নির্ধারণ করুন',
      '🎯 আমার বাজেট স্ট্যাটাস দেখান',
      '📖 রাহুলকে ₹1,000 ধার দিয়েছি খাতায় লিখুন',
      '📖 আমনের থেকে ₹500 ধার নিয়েছি নোট করুন',
      '📖 খাতার হিসাব এবং বকেয়া তালিকা দেখান',
      '👥 ₹1,500 ডিনার আমন এবং রোহিতের সাথে ভাগ করুন',
      '👥 ₹600 ক্যাব ভাড়া রাহুলের সাথে ভাগ করুন',
      '📊 এই মাসে মোট কত খরচ হয়েছে?',
      '🍕 খাবারের পিছনে কত খরচ হয়েছে?',
      '📊 আমার সবচেয়ে বড় খরচ কোনটি?',
      '📅 গত মাসের সাথে এই মাসের তুলনা দেখান',
      '💡 আমি প্রতি মাসে ₹3,000 কীভাবে সঞ্চয় করব?',
      '💡 খরচ কমানোর কিছু পরামর্শ দিন',
      '📈 আমার দৈনিক গড় খরচ কত?',
    ],
    'Marathi': [
      '➕ ₹500 पेट्रोलचा खर्च जोडा',
      '➕ ₹250 चहा-नाश्ता जोडा',
      '➕ ₹1,200 किराणा खरेदी जोडा',
      '➕ ₹350 जेवणाचा खर्च जोडा',
      '➕ ₹1,500 वीज बिल भरले जोडा',
      '🎯 खाण्याचे बजेट ₹5,000 सेट करा',
      '🎯 शॉपिंग बजेट ₹8,000 सेट करा',
      '🎯 माझे बजेट स्टेटस दाखवा',
      '📖 राहुलला ₹1,000 उधार दिले खात्यात लिहा',
      '📖 अमनकडून ₹500 उधार घेतले नोंद करा',
      '📖 खातेवही आणि बाकी रक्कम दाखवा',
      '👥 ₹1,500 जेवण अमन आणि रोहित सोबत वाटा',
      '👥 ₹600 टॅक्सी भाडे राहुल सोबत वाटा',
      '📊 या महिन्यात एकूण किती खर्च झाला?',
      '🍕 जेवणावर किती खर्च झाला?',
      '📊 माझा सर्वात मोठा खर्च कोणता आहे?',
      '📅 गेल्या महिन्याची आणि या महिन्याची तुलना दाखवा',
      '💡 मी दरमहा ₹3,000 कसे वाचवू शकतो?',
      '💡 खर्च कमी करण्यासाठी टिप्स द्या',
      '📈 माझा दैनंदिन सरासरी खर्च किती आहे?',
    ],
    'Gujarati': [
      '➕ ₹500 પેટ્રોલનો ખર્ચ ઉમેરો',
      '➕ ₹250 ચા-નાસ્તો ઉમેરો',
      '➕ ₹1,200 કરિયાણું ઉમેરો',
      '➕ ₹350 જમવાનો ખર્ચ ઉમેરો',
      '➕ ₹1,500 લાઇટ બિલ ભર્યું ઉમેરો',
      '🎯 ફૂડ બજેટ ₹5,000 સેટ કરો',
      '🎯 શોપિંગ બજેટ ₹8,000 સેટ કરો',
      '🎯 મારું બજેટ સ્ટેટસ બતાવો',
      '📖 રાહુલને ₹1,000 ઉધાર આપ્યા ખાતામાં લખો',
      '📖 અમન પાસેથી ₹500 ઉધાર લીધા નોંધ કરો',
      '📖 ખાતાવહી અને બાકી રકમ બતાવો',
      '👥 ₹1,500 ડિનર અમન અને રોહિત સાથે વહેંચો',
      '👥 ₹600 કેબ ભાડું રાહુલ સાથે વહેંચો',
      '📊 આ મહિને કુલ કેટલો ખર્ચ થયો?',
      '🍕 જમવા પાછળ કેટલો ખર્ચ થયો?',
      '📊 મારો સૌથી મોટો ખર્ચ કયો છે?',
      '📅 ગયા મહિના સાથે સરખામણી બતાવો',
      '💡 હું દર મહિને ₹3,000 કેવી રીતે બચાવી શકું?',
      '💡 ખર્ચ ઘટાડવા માટે ટિપ્સ આપો',
      '📈 મારો દૈનિક સરેરાશ ખર્ચ કેટલો છે?',
    ],
    'Tamil': [
      '➕ ₹500 பெட்ரோல் செலவைச் சேர்க்கவும்',
      '➕ ₹250 டீ & சிற்றுண்டி சேர்க்கவும்',
      '➕ ₹1,200 மளிகைப் பொருட்கள் சேர்க்கவும்',
      '➕ ₹350 இரவு உணவு செலவைச் சேர்க்கவும்',
      '➕ ₹1,500 மின்சாரக் கட்டணம் செலுத்தியதைச் சேர்க்கவும்',
      '🎯 உணவு பட்ஜெட்டை ₹5,000 ஆக அமைக்கவும்',
      '🎯 ஷாப்பிங் பட்ஜெட்டை ₹8,000 ஆக அமைக்கவும்',
      '🎯 எனது பட்ஜெட் நிலையை காட்டுங்கள்',
      '📖 ராகுலுக்கு ₹1,000 கடன் கொடுத்ததை கணக்கில் எழுதுங்கள்',
      '📖 அமனிடம் ₹500 கடன் வாங்கியதை குறிக்கவும்',
      '📖 கணக்கு புத்தகம் மற்றும் நிலுவைகளைக் காட்டுங்கள்',
      '👥 ₹1,500 இரவு உணவை அமன் மற்றும் ரோஹித்துடன் பகிரவும்',
      '👥 ₹600 வாடகைக்கார் கட்டணத்தை ராகுலுடன் பகிரவும்',
      '📊 இந்த மாதம் மொத்தம் எவ்வளவு செலவானது?',
      '🍕 உணவுக்காக எவ்வளவு செலவானது?',
      '📊 எனது மிகப்பெரிய செலவு எது?',
      '📅 கடந்த மாதத்துடன் இந்த மாதத்தை ஒப்பிடுங்கள்',
      '💡 நான் ஒவ்வொரு மாதமும் ₹3,000 எப்படி சேமிப்பது?',
      '💡 செலவுகளைக் குறைக்க குறிப்புகள் கொடுங்கள்',
      '📈 எனது தினசரி சராசரி செலவு என்ன?',
    ],
    'Telugu': [
      '➕ ₹500 పెట్రోల్ ఖర్చు జోడించండి',
      '➕ ₹250 టీ & స్నాక్స్ జోడించండి',
      '➕ ₹1,200 కిరాణా సరుకులు జోడించండి',
      '➕ ₹350 డిన్నర్ ఖర్చు జోడించండి',
      '➕ ₹1,500 కరెంట్ బిల్లు చెల్లించినట్లు జోడించండి',
      '🎯 ఆహార బడ్జెట్‌ను ₹5,000గా సెట్ చేయండి',
      '🎯 షాపింగ్ బడ్జెట్‌ను ₹8,000గా సెట్ చేయండి',
      '🎯 నా బడ్జెట్ స్థితిని చూపించండి',
      '📖 రాహుల్‌కు ₹1,000 అప్పు ఇచ్చినట్లు ఖాతాలో రాయండి',
      '📖 అమన్ నుండి ₹500 అప్పు తీసుకున్నట్లు రాయండి',
      '📖 ఖాతా పుస్తకం మరియు బాకీలను చూపించండి',
      '👥 ₹1,500 డిన్నర్‌ను అమన్ మరియు రోహిత్‌తో పంచుకోండి',
      '👥 ₹600 క్యాబ్ చార్జీని రాహుల్‌తో పంచుకోండి',
      '📊 ఈ నెలలో మొత్తం ఎంత ఖర్చయింది?',
      '🍕 ఆహారం కోసం ఎంత ఖర్చు చేశాను?',
      '📊 నా అత్యధిక సింగిల్ ఖర్చు ఏది?',
      '📅 గత నెలతో పోలిక చూపించండి',
      '💡 నేను ప్రతి నెలా ₹3,000 ఎలా ఆదా చేయగలను?',
      '💡 ఖర్చులు తగ్గించుకోవడానికి చిట్కాలు ఇవ్వండి',
      '📈 నా రోజువారీ సగటు ఖర్చు ఎంత?',
    ],
    'Kannada': [
      '➕ ₹500 ಪೆಟ್ರೋಲ್ ವೆಚ್ಚವನ್ನು ಸೇರಿಸಿ',
      '➕ ₹250 ಚಹಾ ಮತ್ತು ತಿಂಡಿ ಸೇರಿಸಿ',
      '➕ ₹1,200 ಕಿರಾಣಿ ಸಾಮಾನು ಸೇರಿಸಿ',
      '➕ ₹350 ಊಟದ ವೆಚ್ಚ ಸೇರಿಸಿ',
      '➕ ₹1,500 ವಿದ್ಯುತ್ ಬಿಲ್ ಪಾವತಿ ಸೇರಿಸಿ',
      '🎯 ಆಹಾರ ಬಜೆಟ್ ₹5,000 ನಿಗದಿಪಡಿಸಿ',
      '🎯 ಶಾಪಿಂಗ್ ಬಜೆಟ್ ₹8,000 ನಿಗದಿಪಡಿಸಿ',
      '🎯 ನನ್ನ ಬಜೆಟ್ ಸ್ಥಿತಿಯನ್ನು ತೋರಿಸಿ',
      '📖 ರಾಹುಲ್‌ಗೆ ₹1,000 ಸಾಲ ನೀಡಿದ್ದನ್ನು ಖಾತೆಯಲ್ಲಿ ಬರೆಯಿರಿ',
      '📖 ಅಮನ್‌ನಿಂದ ₹500 ಸಾಲ ಪಡೆದದ್ದನ್ನು ದಾಖಲಿಸಿ',
      '📖 ಖಾತೆ ಪುಸ್ತಕ ಮತ್ತು ಬಾಕಿಗಳನ್ನು ತೋರಿಸಿ',
      '👥 ₹1,500 ಊಟದ ಬಿಲ್ ಅಮನ್ ಮತ್ತು ರೋಹಿತ್ ಜೊತೆ ಹಂಚಿಕೊಳ್ಳಿ',
      '👥 ₹600 ಕ್ಯಾಬ್ ಶುಲ್ಕ ರಾಹುಲ್ ಜೊತೆ ಹಂಚಿಕೊಳ್ಳಿ',
      '📊 ಈ ತಿಂಗಳು ಒಟ್ಟು ಎಷ್ಟು ಖರ್ಚಾಗಿದೆ?',
      '🍕 ಆಹಾರಕ್ಕಾಗಿ ಎಷ್ಟು ಖರ್ಚಾಗಿದೆ?',
      '📊 ನನ್ನ ಅತಿ ದೊಡ್ಡ ವೆಚ್ಚ ಯಾವುದು?',
      '📅 ಕಳೆದ ತಿಂಗಳಿಗೆ ಹೋಲಿಸಿ ತೋರಿಸಿ',
      '💡 ನಾನು ಪ್ರತಿ ತಿಂಗಳು ₹3,000 ಹೇಗೆ ಉಳಿಸಬಹುದು?',
      '💡 ಖರ್ಚು ಕಡಿಮೆ ಮಾಡಲು ಸಲಹೆಗಳನ್ನು ನೀಡಿ',
      '📈 ನನ್ನ ದೈನಂದಿನ ಸರಾಸರಿ ವೆಚ್ಚ ಎಷ್ಟು?',
    ],
    'Malayalam': [
      '➕ ₹500 പെട്രോൾ ചെലവ് ചേർക്കുക',
      '➕ ₹250 ചായയും പലഹാരവും ചേർക്കുക',
      '➕ ₹1,200 പലചരക്ക് സാധനങ്ങൾ ചേർക്കുക',
      '➕ ₹350 അത്താഴ ചെലവ് ചേർക്കുക',
      '➕ ₹1,500 വൈദ്യുതി ബിൽ അടച്ചത് ചേർക്കുക',
      '🎯 ഭക്ഷണ ബജറ്റ് ₹5,000 ആയി നിശ്ചയിക്കുക',
      '🎯 ഷോപ്പിംഗ് ബജറ്റ് ₹8,000 ആയി നിശ്ചയിക്കുക',
      '🎯 എന്റെ ബജറ്റ് നില കാണിക്കുക',
      '📖 രാഹുലിന് ₹1,000 കടം കൊടുത്തത് കണക്കിൽ എഴുതുക',
      '📖 അമനിൽ നിന്ന് ₹500 കടം വാങ്ങിയത് രേഖപ്പെടുത്തുക',
      '📖 കണക്ക് പുസ്തകവും കുടിശ്ശികകളും കാണിക്കുക',
      '👥 ₹1,500 ഡിന്നർ അമനും രോഹിത്തുമായി പങ്കിടുക',
      '👥 ₹600 ക്യാബ് ചാർജ് രാഹുലുമായി പങ്കിടുക',
      '📊 ഈ മാസം ആകെ എത്ര രൂപ ചെലവായി?',
      '🍕 ഭക്ഷണത്തിനായി എത്ര രൂപ ചെലവായി?',
      '📊 എന്റെ ഏറ്റവും വലിയ ചെലവ് ഏതാണ്?',
      '📅 കഴിഞ്ഞ മാസവുമായി താരതമ്യം കാണിക്കുക',
      '💡 എല്ലാ മാസവും ₹3,000 എങ്ങനെ ലാഭിക്കാം?',
      '💡 ചെലവ് കുറയ്ക്കാനുള്ള നുറുങ്ങുകൾ തരൂ',
      '📈 എന്റെ ദിവസേനയുള്ള ശരാശരി ചെലവ് എത്രയാണ്?',
    ],
    'Punjabi': [
      '➕ ₹500 ਪੈਟਰੋਲ ਦਾ ਖਰਚਾ ਜੋੜੋ',
      '➕ ₹250 ਚਾਹ ਅਤੇ ਨਾਸ਼ਤਾ ਜੋੜੋ',
      '➕ ₹1,200 ਰਾਸ਼ਨ ਦੀ ਖਰੀਦਦਾਰੀ ਜੋੜੋ',
      '➕ ₹350 ਰਾਤ ਦੇ ਖਾਣੇ ਦਾ ਖਰਚਾ ਜੋੜੋ',
      '➕ ₹1,500 ਬਿਜਲੀ ਦਾ ਬਿੱਲ ਭਰਿਆ ਜੋੜੋ',
      '🎯 ਖਾਣੇ ਦਾ ਬਜਟ ₹5,000 ਸੈੱਟ ਕਰੋ',
      '🎯 ਖਰੀਦਦਾਰੀ ਦਾ ਬਜਟ ₹8,000 ਸੈੱਟ ਕਰੋ',
      '🎯 ਮੇਰਾ ਬਜਟ ਸਟੇਟਸ ਦਿਖਾਓ',
      '📖 ਰਾਹੁਲ ਨੂੰ ₹1,000 ਉਧਾਰ ਦਿੱਤਾ ਖਾਤੇ ਵਿੱਚ ਲਿਖੋ',
      '📖 ਅਮਨ ਤੋਂ ₹500 ਉਧਾਰ ਲਿਆ ਨੋਟ ਕਰੋ',
      '📖 ਖਾਤਾ ਬਹੀ ਅਤੇ ਬਾਕੀ ਰਕਮ ਦਿਖਾਓ',
      '👥 ₹1,500 ਡਿਨਰ ਅਮਨ ਅਤੇ ਰੋਹਿਤ ਨਾਲ ਵੰਡੋ',
      '👥 ₹600 ਕੈਬ ਕਿਰਾਇਆ ਰਾਹੁਲ ਨਾਲ ਵੰਡੋ',
      '📊 ਇਸ ਮਹੀਨੇ ਕੁੱਲ ਕਿੰਨਾ ਖਰਚ ਹੋਇਆ?',
      '🍕 ਖਾਣੇ ਉੱਤੇ ਕਿੰਨਾ ਖਰਚ ਹੋਇਆ?',
      '📊 ਮੇਰਾ ਸਭ ਤੋਂ ਵੱਡਾ ਖਰਚਾ ਕਿਹੜਾ ਹੈ?',
      '📅 ਪਿਛਲੇ ਮਹੀਨੇ ਨਾਲ ਤੁਲਨਾ ਦਿਖਾਓ',
      '💡 ਮੈਂ ਹਰ ਮਹੀਨੇ ₹3,000 ਕਿਵੇਂ ਬਚਾ ਸਕਦਾ ਹਾਂ?',
      '💡 ਖਰਚਾ ਘਟਾਉਣ ਦੇ ਸੁਝਾਅ ਦਿਓ',
      '📈 ਮੇਰਾ ਰੋਜ਼ਾਨਾ ਔਸਤ ਖਰਚਾ ਕਿੰਨਾ ਹੈ?',
    ],
  };

  List<String> get _currentSuggestedPrompts {
    final lang = AiConfigService.instance.responseLanguage;
    return _localizedSuggestions[lang] ?? _localizedSuggestions['English']!;
  }

  @override
  void initState() {
    super.initState();
    AiConfigService.instance.addListener(_onAiConfigUpdated);
    _loadChatHistory();
  }

  void _onAiConfigUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final rows = await DatabaseHelper.instance.getAiChatMessages();
      if (!mounted) return;
      if (rows.isNotEmpty) {
        setState(() {
          _messages.clear();
          for (var row in rows) {
            _messages.add(
              ChatMessage.fromRawText(
                id: row['id']?.toString(),
                rawText: row['text']?.toString() ?? '',
                isUser: (row['is_user'] == 1),
                timestamp: DateTime.tryParse(row['timestamp']?.toString() ?? '') ?? DateTime.now(),
                modelUsed: row['model_used']?.toString(),
              ),
            );
          }
        });
        _scrollToBottom();
      } else {
        _addInitialWelcomeMessage();
      }

      // Check for month rollover prompt
      await _checkMonthRolloverPrompt();
    } catch (e) {
      debugPrint('[AiAdvisorScreen] Error loading chat history: $e');
      _addInitialWelcomeMessage();
    }
  }

  Future<void> _checkMonthRolloverPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonthKey = DateFormat('yyyy-MM').format(now);
    final monthName = DateFormat('MMMM yyyy').format(now);
    final lastSeenMonth = prefs.getString('last_seen_chat_month');

    if (lastSeenMonth == null) {
      await prefs.setString('last_seen_chat_month', currentMonthKey);
      return;
    }

    if (lastSeenMonth != currentMonthKey && _messages.isNotEmpty) {
      // Check if there are past messages from a different month
      final hasPastMessages = _messages.any((m) {
        final monthKey = DateFormat('yyyy-MM').format(m.timestamp);
        return monthKey != currentMonthKey;
      });

      if (hasPastMessages && mounted) {
        await _showNewMonthChatDialog(currentMonthKey, monthName, prefs);
      } else {
        await prefs.setString('last_seen_chat_month', currentMonthKey);
      }
    }
  }

  Future<void> _showNewMonthChatDialog(String currentMonthKey, String monthName, SharedPreferences prefs) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final startFresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: primaryColor.withValues(alpha: 0.2),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00D09C), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'New Month, Fresh Start! 🗓️',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new month ($monthName) has started! Would you like to clear previous months\' conversation and start fresh for $monthName?',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your saved expenses and budgets are always 100% safe in History.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.grey,
                  ),
                  child: const Text('Keep Old Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D09C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Start Fresh 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await prefs.setString('last_seen_chat_month', currentMonthKey);

    if (startFresh == true && mounted) {
      await DatabaseHelper.instance.clearAiChatMessages();
      setState(() {
        _messages.clear();
      });
      _addInitialWelcomeMessage();
      CustomToast.show(context, 'Started fresh chat for $monthName! ✨');
    }
  }

  void _addInitialWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'Namaste! 👋 Main aapka **GrowwAI Autonomous Financial Agent** hoon.\n\nMai aapke ledger ko analyze karne ke sath-sath:\n• 💳 **Expenses add kar sakta hoon** (e.g. "Add ₹350 for lunch")\n• 🎯 **Budgets set kar sakta hoon** (e.g. "Set Groceries budget to ₹6000")\n• 📖 **Khata / Udhar record kar sakta hoon** (e.g. "Raju ko ₹1500 udhar diya")\n• 👥 **Group Bills split kar sakta hoon** (e.g. "Split ₹1200 with Amit and Rahul")\n\nAap bol kar ya likh kar command de sakte hain!',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  @override
  void dispose() {
    AiConfigService.instance.removeListener(_onAiConfigUpdated);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onPromptTapped(String prompt) {
    HapticFeedback.lightImpact();
    // Strip leading decorative emojis across English, Devanagari, Bengali, Gujarati, Tamil, Telugu, Kannada, Malayalam, Gurmukhi
    String cleanText = prompt.replaceAll(RegExp(r'^[^\w₹0-9\u0900-\u097F\u0980-\u09FF\u0A00-\u0A7F\u0A80-\u0AFF\u0B00-\u0B7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F]+\s*'), '').trim();
    if (cleanText.isEmpty) cleanText = prompt;

    _textController.text = cleanText;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    _focusNode.requestFocus();
  }

  String _buildFinancialContext(ExpenseProvider provider) {
    final expenses = provider.expenses;
    final budgets = provider.budgets;
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0);

    final currentExpenses = expenses.where((e) => !e.transactionDate.isBefore(currentMonthStart)).toList();
    final previousExpenses = expenses.where((e) =>
        !e.transactionDate.isBefore(previousMonthStart) && !e.transactionDate.isAfter(previousMonthEnd)).toList();

    final double currentTotal = currentExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final double previousTotal = previousExpenses.fold(0.0, (sum, e) => sum + e.amount);

    // Category breakdown
    final Map<String, double> categorySpent = {};
    for (var e in currentExpenses) {
      categorySpent[e.category] = (categorySpent[e.category] ?? 0.0) + e.amount;
    }

    // Sort categories by highest spend
    final sortedCategories = categorySpent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Highest single transaction
    Expense? maxExpense;
    if (currentExpenses.isNotEmpty) {
      maxExpense = currentExpenses.reduce((curr, next) => curr.amount > next.amount ? curr : next);
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Active Month: ${DateFormat('MMMM yyyy').format(now)}');
    buffer.writeln('Total Expenses Count (Current Month): ${currentExpenses.length}');
    buffer.writeln('Total Amount Spent (Current Month): INR ${currentTotal.toStringAsFixed(2)}');
    buffer.writeln('Total Amount Spent (Previous Month): INR ${previousTotal.toStringAsFixed(2)}');

    if (maxExpense != null) {
      buffer.writeln('Highest Single Expense: ${maxExpense.description} (INR ${maxExpense.amount.toStringAsFixed(2)} in ${maxExpense.category})');
    }

    buffer.writeln('\nCategory Spend Breakdown (Current Month):');
    for (var entry in sortedCategories) {
      buffer.writeln('- ${entry.key}: INR ${entry.value.toStringAsFixed(2)}');
    }

    buffer.writeln('\nActive Monthly Budgets Set:');
    if (budgets.isEmpty) {
      buffer.writeln('No category budgets set currently.');
    } else {
      for (var b in budgets) {
        final spent = categorySpent[b.category] ?? 0.0;
        final pct = b.amountLimit > 0 ? ((spent / b.amountLimit) * 100).toInt() : 0;
        buffer.writeln('- ${b.category}: Limit INR ${b.amountLimit.toStringAsFixed(0)}, Spent INR ${spent.toStringAsFixed(0)} ($pct% used)');
      }
    }

    buffer.writeln('\nRecent Transactions (Last 8 items):');
    final recent = currentExpenses.take(8).toList();
    for (var e in recent) {
      buffer.writeln('- ${DateFormat('dd MMM').format(e.transactionDate)}: INR ${e.amount.toStringAsFixed(2)} on ${e.description.isNotEmpty ? e.description : e.category} (${e.category})');
    }

    return buffer.toString();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (!checkAndPromptAiConfig(context)) return;

    final question = text.trim();
    _textController.clear();

    final userMsg = ChatMessage(
      text: question,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    // Persist user question in SQLite
    await DatabaseHelper.instance.insertAiChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_user',
      text: userMsg.text,
      isUser: true,
      timestamp: userMsg.timestamp,
    );

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final contextSummary = _buildFinancialContext(expenseProvider);

    final chatHistory = _messages
        .sublist(0, _messages.length - 1)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'content': m.text,
            })
        .toList();

    final aiService = AiConfigService.instance;
    final result = await aiService.askFinancialAdvisor(
      userQuestion: question,
      financialContextSummary: contextSummary,
      chatHistory: chatHistory,
    );

    if (!mounted) return;

    ChatMessage aiMsg;
    String rawReply = '';
    final aiMsgId = '${DateTime.now().millisecondsSinceEpoch}_ai';
    if (result['success'] == true && result['reply'] != null) {
      rawReply = result['reply'] as String;
      aiMsg = ChatMessage.fromRawText(
        id: aiMsgId,
        rawText: rawReply,
        isUser: false,
        timestamp: DateTime.now(),
        modelUsed: result['modelUsed'],
      );
    } else {
      final errorMsg = result['error']?.toString() ?? 'Failed to get response from AI. Please check your AI Configuration in Settings.';
      rawReply = '⚠️ $errorMsg';
      aiMsg = ChatMessage(
        id: aiMsgId,
        text: rawReply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      if (aiService.isServerBusyError(errorMsg)) {
        showAiServerBusyDialog(context, onRetry: () => _sendMessage(question));
      }
    }

    setState(() {
      _isLoading = false;
      _messages.add(aiMsg);
    });

    // Persist AI response in SQLite (preserving action metadata for persistence)
    await DatabaseHelper.instance.insertAiChatMessage(
      id: aiMsg.id,
      text: aiMsg.toRawText(),
      isUser: false,
      timestamp: aiMsg.timestamp,
      modelUsed: aiMsg.modelUsed,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      if (_textController.text.trim().isNotEmpty) {
        _sendMessage(_textController.text.trim());
      }
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() {
                _isListening = false;
              });
              if (_textController.text.trim().isNotEmpty) {
                _sendMessage(_textController.text.trim());
              }
            }
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
        });
        HapticFeedback.mediumImpact();

        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _textController.text = result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_IN',
          listenOptions: stt.SpeechListenOptions(cancelOnError: true, partialResults: true),
        );
      } else {
        CustomToast.show(context, 'Microphone permission denied.', isError: true);
      }
    }
  }

  Future<void> _confirmClearChat() async {
    final stats = await DatabaseHelper.instance.getAiChatStats();
    final count = stats['count'] as int? ?? _messages.where((m) => m.isUser || m.text.isNotEmpty).length;
    final formattedSize = stats['formattedSize'] as String? ?? '0 KB';
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Clear Chat History?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chat Storage Info Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storage_rounded, size: 22, color: Color(0xFF00D09C)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stored Chat Size: $formattedSize',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count saved messages on this device',
                          style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'All your AI conversations, suggestions, and action intents will be permanently wiped from local phone storage. This action cannot be undone.',
              style: GoogleFonts.inter(fontSize: 12.5, height: 1.45, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear History ($formattedSize)',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.clearAiChatMessages();
      setState(() {
        _messages.clear();
        _addInitialWelcomeMessage();
      });
      if (mounted) {
        CustomToast.show(context, 'Chat history cleared successfully ($formattedSize freed)');
      }
    }
  }

  void _openChatSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryColor = Theme.of(ctx).primaryColor;
        final aiService = AiConfigService.instance;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14171F) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.tune_rounded, color: primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Chat Settings',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Language preference & message history',
                                style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 1: AI Response Language
                    Text(
                      'AI RESPONSE LANGUAGE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AI will automatically respond in your selected preferred language.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: aiService.responseLanguage,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
                          items: _languageOptions.map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt['code'],
                              child: Row(
                                children: [
                                  const Icon(Icons.translate_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Text(
                                    opt['label']!,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${opt['native']})',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              aiService.setResponseLanguage(val);
                              setModalState(() {});
                              setState(() {});
                              CustomToast.show(context, 'Language set to $val');
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 2: Engine Configuration Shortcut
                    InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AiConfigScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.memory_rounded, color: primaryColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Engine: ${aiService.primaryProvider.toUpperCase()}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    'Configure Gemini & NVIDIA API keys',
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 3: Delete / Clear Chat History Button
                    FutureBuilder<Map<String, dynamic>>(
                      future: DatabaseHelper.instance.getAiChatStats(),
                      builder: (context, snapshot) {
                        final sizeStr = snapshot.data?['formattedSize'] ?? '0 KB';
                        final count = snapshot.data?['count'] ?? 0;
                        return InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _confirmClearChat();
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Clear All Chat History',
                                      style: GoogleFonts.inter(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$sizeStr ($count)',
                                    style: GoogleFonts.inter(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.psychology_alt_rounded, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Advisor',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16.5),
                ),
                Text(
                  'Live Expense Intelligence',
                  style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openChatSettingsModal,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Chat Settings & Language',
          ),
          IconButton(
            onPressed: _confirmClearChat,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear Chat History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, isDark, primaryColor);
              },
            ),
          ),

          // Loading typing indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'GrowwAI is analyzing your expenses...',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Suggested Prompts Horizontal Bar (Always available when not loading)
          if (!_isLoading)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _currentSuggestedPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _currentSuggestedPrompts[index];
                  return InkWell(
                    onTap: () => _onPromptTapped(prompt),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF181B22) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          prompt,
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Modern Docked Input Bar (Clean Keyboard-Aware)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF11141B) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E2430) : const Color(0xFFEEF2F6),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Sleek Combined Input Pill
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1F2B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? const Color(0xFF293245) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Voice Mic Button inside input bar
                          IconButton(
                            iconSize: 21,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            onPressed: _toggleVoiceInput,
                            icon: Icon(
                              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                              color: _isListening ? Colors.redAccent : primaryColor,
                            ),
                            tooltip: 'Voice Input',
                          ),

                          // Text Input Field
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              textCapitalization: TextCapitalization.sentences,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 4,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: _isListening ? 'Listening...' : 'Ask about expenses, savings, tips...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              ),
                              onSubmitted: _sendMessage,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Button
                  Material(
                    color: primaryColor,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _sendMessage(_textController.text),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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

  // Chat message bubble with custom Markdown & Asterisk Parsing
  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: primaryColor.withValues(alpha: 0.15),
              child: Icon(Icons.psychology_alt_rounded, color: primaryColor, size: 17),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? primaryColor
                    : (isDark ? const Color(0xFF1A1F2B) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: msg.isUser
                      ? Colors.transparent
                      : (isDark ? const Color(0xFF273142) : const Color(0xFFE2E8F0)),
                ),
                boxShadow: [
                  if (!isDark && !msg.isUser)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.isUser)
                    Text(
                      msg.text,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    _buildAiFormattedContent(msg.text, isDark, primaryColor),
                    if (msg.actionProposal != null) ...[
                      _buildActionProposalCard(msg, msg.actionProposal!, isDark, primaryColor),
                    ],
                  ],
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(msg.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: msg.isUser ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      if (msg.modelUsed != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${msg.modelUsed}',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Future<void> _executeActionProposal(ChatMessage msg, AiActionProposal proposal) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    HapticFeedback.mediumImpact();

    try {
      switch (proposal.actionType) {
        case 'ADD_EXPENSE':
          final amount = double.tryParse(proposal.data['amount'].toString()) ?? 0.0;
          final category = proposal.data['category']?.toString() ?? 'General';
          final description = proposal.data['description']?.toString() ?? category;

          await expenseProvider.addExpense(
            amount: amount,
            category: category,
            description: description,
            date: DateTime.now(),
            currency: 'INR',
          );
          if (mounted) {
            CustomToast.show(context, 'Expense ₹${amount.toStringAsFixed(0)} added & synced to Cloud! ☁️');
          }
          break;

        case 'SET_BUDGET':
          final category = proposal.data['category']?.toString() ?? 'Others';
          final amountLimit = double.tryParse(proposal.data['amountLimit'].toString()) ?? 0.0;
          final monthYear = DateFormat('yyyy-MM').format(DateTime.now());

          await expenseProvider.setBudget(
            category: category,
            amountLimit: amountLimit,
            monthYear: monthYear,
          );
          if (mounted) {
            CustomToast.show(context, '$category Budget set to ₹${amountLimit.toStringAsFixed(0)} & synced! ☁️');
          }
          break;

        case 'ADD_KHATA':
          final personName = proposal.data['personName']?.toString() ?? 'Friend';
          final amount = double.tryParse(proposal.data['amount'].toString()) ?? 0.0;
          final type = proposal.data['type']?.toString().toLowerCase() == 'borrowed' ? 'borrowed' : 'lent';
          final note = proposal.data['note']?.toString();

          await expenseProvider.addKhataEntry(
            personName: personName,
            amount: amount,
            type: type,
            entryDate: DateTime.now(),
            note: note != null && note.isNotEmpty ? note : null,
          );
          if (mounted) {
            CustomToast.show(context, 'Khata: $personName (₹${amount.toStringAsFixed(0)}) recorded! 📖');
          }
          break;

        case 'ADD_SPLIT':
          final title = proposal.data['title']?.toString() ?? 'Group Expense';
          final totalAmount = double.tryParse(proposal.data['totalAmount'].toString()) ?? 0.0;
          final rawParts = (proposal.data['participants'] as List?)?.map((p) => p.toString().trim()).where((p) => p.isNotEmpty).toList() ?? ['You', 'Friend'];

          final count = rawParts.length;
          final perPerson = count > 0 ? (totalAmount / count) : totalAmount;

          final participants = rawParts.map((name) {
            final isUser = name.toLowerCase() == 'you' || name.toLowerCase() == 'me';
            return SplitParticipant(
              name: name,
              shareAmount: perPerson,
              isSettled: isUser,
              settledAt: isUser ? DateTime.now() : null,
            );
          }).toList();

          await expenseProvider.addSplitBill(
            title: title,
            totalAmount: totalAmount,
            paidBy: 'You',
            billDate: DateTime.now(),
            splitType: 'equal',
            participants: participants,
            note: proposal.data['note']?.toString(),
          );
          if (mounted) {
            CustomToast.show(context, 'Split bill "$title" created for $count members! 👥');
          }
          break;
      }

      setState(() {
        proposal.isExecuted = true;
      });

      // Persist executed proposal state to SQLite so reopening chat/app remembers it
      await DatabaseHelper.instance.updateAiChatMessageText(
        id: msg.id,
        text: msg.toRawText(),
      );
    } catch (e) {
      debugPrint('[AiAdvisorScreen] Error executing AI action: $e');
      if (mounted) {
        CustomToast.show(context, 'Failed to perform action: $e', isError: true);
      }
    }
  }

  Widget _buildActionProposalCard(ChatMessage msg, AiActionProposal proposal, bool isDark, Color primaryColor) {
    IconData actionIcon;
    Color actionColor;
    String actionTitle;
    String badgeText;

    switch (proposal.actionType) {
      case 'ADD_EXPENSE':
        actionIcon = Icons.receipt_long_rounded;
        actionColor = const Color(0xFF00D09C);
        badgeText = 'EXPENSE ACTION';
        final amt = double.tryParse(proposal.data['amount']?.toString() ?? '0') ?? 0.0;
        actionTitle = 'Add Expense • ₹${amt.toStringAsFixed(0)}';
        break;
      case 'SET_BUDGET':
        actionIcon = Icons.pie_chart_rounded;
        actionColor = const Color(0xFF38BDF8);
        badgeText = 'BUDGET ACTION';
        final amt = double.tryParse(proposal.data['amountLimit']?.toString() ?? '0') ?? 0.0;
        final cat = proposal.data['category']?.toString() ?? 'Category';
        actionTitle = 'Set $cat Budget • ₹${amt.toStringAsFixed(0)}';
        break;
      case 'ADD_KHATA':
        actionIcon = Icons.menu_book_rounded;
        actionColor = const Color(0xFFF59E0B);
        badgeText = 'KHATA ACTION';
        final amt = double.tryParse(proposal.data['amount']?.toString() ?? '0') ?? 0.0;
        final isLent = proposal.data['type']?.toString().toLowerCase() != 'borrowed';
        actionTitle = 'Khata (${isLent ? 'Lent' : 'Borrowed'}) • ₹${amt.toStringAsFixed(0)}';
        break;
      case 'ADD_SPLIT':
        actionIcon = Icons.call_split_rounded;
        actionColor = const Color(0xFF818CF8);
        badgeText = 'SPLIT ACTION';
        final amt = double.tryParse(proposal.data['totalAmount']?.toString() ?? '0') ?? 0.0;
        actionTitle = 'Split Bill • ₹${amt.toStringAsFixed(0)}';
        break;
      default:
        actionIcon = Icons.bolt_rounded;
        actionColor = primaryColor;
        badgeText = 'AI ACTION';
        actionTitle = 'Proposed Action';
    }

    if (proposal.isDismissed) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              'Action proposal dismissed',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12161F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: proposal.isExecuted ? const Color(0xFF00D09C) : actionColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (proposal.isExecuted ? const Color(0xFF00D09C) : actionColor).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actionIcon, size: 12, color: actionColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: actionColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (proposal.isExecuted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_done_rounded, size: 12, color: Color(0xFF00D09C)),
                      const SizedBox(width: 4),
                      Text(
                        'SYNCED',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00D09C),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            actionTitle,
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          // Details breakdown
          _buildProposalDetails(proposal, isDark),
          const SizedBox(height: 10),

          // Action Buttons
          if (proposal.isExecuted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00D09C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF00D09C), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Recorded in Database & Cloud Synced ☁️',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00D09C),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _executeActionProposal(msg, proposal),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text(
                      'Confirm & Execute',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    setState(() {
                      proposal.isDismissed = true;
                    });
                    await DatabaseHelper.instance.updateAiChatMessageText(
                      id: msg.id,
                      text: msg.toRawText(),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProposalDetails(AiActionProposal proposal, bool isDark) {
    final data = proposal.data;
    final textStyle = GoogleFonts.inter(
      fontSize: 12,
      color: isDark ? Colors.grey[300] : Colors.grey[700],
    );

    switch (proposal.actionType) {
      case 'ADD_EXPENSE':
        final cat = data['category']?.toString() ?? 'General';
        final desc = data['description']?.toString() ?? cat;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Category: $cat', style: textStyle),
            if (desc != cat && desc.isNotEmpty) Text('• Note: $desc', style: textStyle),
          ],
        );

      case 'SET_BUDGET':
        final cat = data['category']?.toString() ?? 'Others';
        return Text('• Category: $cat (Active Month)', style: textStyle);

      case 'ADD_KHATA':
        final person = data['personName']?.toString() ?? 'Friend';
        final isLent = data['type']?.toString().toLowerCase() != 'borrowed';
        final note = data['note']?.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Person: $person', style: textStyle),
            Text('• Status: ${isLent ? "You will get money" : "You will pay"}', style: textStyle),
            if (note != null && note.isNotEmpty) Text('• Note: $note', style: textStyle),
          ],
        );

      case 'ADD_SPLIT':
        final title = data['title']?.toString() ?? 'Group Bill';
        final parts = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Bill: $title', style: textStyle),
            if (parts.isNotEmpty) Text('• Split between: ${parts.join(', ')}', style: textStyle),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // Formatted RichText & Markdown renderer removing raw * and ** and LaTeX artifacts
  Widget _buildAiFormattedContent(String text, bool isDark, Color primaryColor) {
    final sanitizedText = AiConfigService.sanitizeLatexMath(text);
    final lines = sanitizedText.split('\n');
    final List<Widget> widgets = [];
    final baseStyle = GoogleFonts.inter(
      fontSize: 13.5,
      height: 1.48,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (widgets.isNotEmpty && i < lines.length - 1) {
          widgets.add(const SizedBox(height: 5));
        }
        continue;
      }

      // Headers: ###, ##, #
      if (line.startsWith('### ') || line.startsWith('## ') || line.startsWith('# ')) {
        final headerText = line.replaceFirst(RegExp(r'^#+\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Text(
              headerText.replaceAll('*', ''),
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        );
        continue;
      }

      // Bullet points: * , - , • 
      if (line.startsWith('* ') || line.startsWith('- ') || line.startsWith('• ')) {
        final bulletContent = line.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6.5, right: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _parseInlineSpans(bulletContent, baseStyle, primaryColor),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Numbered items: 1. , 2. , etc.
      final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
      if (numMatch != null) {
        final numStr = numMatch.group(1)!;
        final numContent = numMatch.group(2)!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 7, top: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '$numStr.',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: _parseInlineSpans(numContent, baseStyle, primaryColor),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Regular line/paragraph
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: _parseInlineSpans(line, baseStyle, primaryColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Parses **bold** and *italic* into TextSpans and strips raw * artifacts
  Widget _parseInlineSpans(String text, TextStyle baseStyle, Color primaryColor) {
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
    final matches = pattern.allMatches(text);
    if (matches.isEmpty) {
      final cleanText = text.replaceAll('*', '');
      return Text(cleanText, style: baseStyle);
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        final sub = text.substring(lastIndex, match.start).replaceAll('*', '');
        if (sub.isNotEmpty) {
          spans.add(TextSpan(text: sub, style: baseStyle));
        }
      }

      final matchStr = match.group(0)!;
      if (matchStr.startsWith('**') && matchStr.endsWith('**') && matchStr.length >= 4) {
        final boldContent = matchStr.substring(2, matchStr.length - 2);
        spans.add(
          TextSpan(
            text: boldContent,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: baseStyle.color,
            ),
          ),
        );
      } else if (matchStr.startsWith('*') && matchStr.endsWith('*') && matchStr.length >= 2) {
        final italicContent = matchStr.substring(1, matchStr.length - 1);
        spans.add(
          TextSpan(
            text: italicContent,
            style: baseStyle.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex).replaceAll('*', '');
      if (remaining.isNotEmpty) {
        spans.add(TextSpan(text: remaining, style: baseStyle));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
