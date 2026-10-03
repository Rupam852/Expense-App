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
import '../services/user_provider.dart';
import '../models/expense.dart';
import '../models/split_bill.dart';
import '../models/business_profile.dart';
import '../models/business_sale.dart';
import '../models/khata_entry.dart';
import '../widgets/ai_config_required_dialog.dart';
import '../widgets/custom_toast.dart';
import 'ai_config_screen.dart';

class AiActionProposal {
  final String actionType; // 'ADD_EXPENSE', 'SET_BUDGET', 'ADD_KHATA', 'ADD_SPLIT', 'ADD_BUSINESS_SALE', 'ADD_BUSINESS_EXPENSE'
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Multi-Session Chat State (ChatGPT / Gemini Style)
  String? _currentSessionId;
  String _currentSessionTitle = 'New Chat';
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoadingSessions = false;

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

  static const Map<String, String> _localizedWelcomeMessages = {
    'English':
        'Hello! 👋 I am your **Grow Expense AI Autonomous Financial Agent**.\n\nBesides analyzing your financial ledger, I can directly:\n• 💳 **Add Expenses** (e.g. "Add ₹350 for lunch")\n• 🎯 **Set Budgets** (e.g. "Set Groceries budget to ₹6,000")\n• 📖 **Record Khata / Dues** (e.g. "Lent ₹1,500 to Raju")\n• 👥 **Split Group Bills** (e.g. "Split ₹1,200 with Amit and Rahul")\n\nYou can type or speak your command!',
    'Hindi':
        'नमस्ते! 👋 मैं आपका **Grow Expense AI ऑटोनॉमस फाइनेंशियल एजेंट** हूँ।\n\nमैं आपके खर्चों का विश्लेषण करने के साथ-साथ सीधे:\n• 💳 **खर्च जोड़ सकता हूँ** (उदा. \"लंच के लिए ₹350 जोड़ें\")\n• 🎯 **बजट सेट कर सकता हूँ** (उदा. \"राशन का बजट ₹6,000 सेट करें\")\n• 📖 **खाता / उधार दर्ज कर सकता हूँ** (उदा. \"राजू को ₹1,500 उधार दिया\")\n• 👥 **ग्रुप बिल बाँट सकता हूँ** (उदा. \"अमित और राहुल के साथ ₹1,200 बाँटें\")\n\nआप बोलकर या लिखकर निर्देश दे सकते हैं!',
    'Hinglish':
        'Namaste! 👋 Main aapka **Grow Expense AI Autonomous Financial Agent** hoon.\n\nMai aapke ledger ko analyze karne ke sath-sath:\n• 💳 **Expenses add kar sakta hoon** (e.g. \"Add ₹350 for lunch\")\n• 🎯 **Budgets set kar sakta hoon** (e.g. \"Set Groceries budget to ₹6000\")\n• 📖 **Khata / Udhar record kar sakta hoon** (e.g. \"Raju ko ₹1500 udhar diya\")\n• 👥 **Group Bills split kar sakta hoon** (e.g. \"Split ₹1200 with Amit and Rahul\")\n\nAap bol kar ya likh kar command de sakte hain!',
    'Bengali':
        'নমস্কার! 👋 আমি আপনার **Grow Expense AI স্বায়ত্তশাসিত আর্থিক সহকারী**।\n\nআপনার ব্যয়ের হিসাব বিশ্লেষণের পাশাপাশি আমি সরাসরি:\n• 💳 **খরচ যোগ করতে পারি** (যেমন \"দুপুরের খাবারের জন্য ₹350 যোগ করুন\")\n• 🎯 **বাজেট নির্ধারণ করতে পারি** (যেমন \"মুদিখানার বাজেট ₹6,000 সেট করুন\")\n• 📖 **খাতা / বাকি হিসাব রাখতে পারি** (যেমন \"রাজুকে ₹1,500 ধার দিয়েছি\")\n• 👥 **গ্রুপ বিল ভাগ করতে পারি** (যেমন \"অমিত এবং রাহুলের সাথে ₹1,200 ভাগ করুন\")\n\nআপনি মুখে বলে বা লিখে নির্দেশ দিতে পারেন!',
    'Marathi':
        'नमस्कार! 👋 मी तुमचा **Grow Expense AI ऑटोनॉमस फायनान्शियल एजंट** आहे.\n\nतुमच्या खर्चाचे विश्लेषण करण्यासोबतच मी थेट:\n• 💳 **खर्च नोंदवू शकतो** (उदा. \"दुपारच्या जेवणासाठी ₹350 जोडा\")\n• 🎯 **बजेट ठरवू शकतो** (उदा. \"किराणा मालाचे बजेट ₹6,000 सेट करा\")\n• 📖 **खाते / उधारी नोंदवू शकतो** (उदा. \"राजूला ₹1,500 उसने दिले\")\n• 👥 **ग्रुप बिल विभागू शकतो** (उदा. \"अमित आणि राहुलसोबत ₹1,200 स्प्लिट करा\")\n\nतुम्ही बोलून किंवा टाईप करून सांगू शकता!',
    'Gujarati':
        'નમસ્તે! 👋 હું તમારો **Grow Expense AI ઓટોનોમસ ફાયનાન્સિયલ એજન્ટ** છું.\n\nતમારા ખર્ચનું વિશ્લેષણ કરવા ઉપરાંત હું સીધા:\n• 💳 **ખર્ચ ઉમેરી શકું છું** (દા.ત. \"લંચ માટે ₹350 ઉમેરો\")\n• 🎯 **બજેટ સેટ કરી શકું છું** (દા.ત. \"કરિયાણાનું બજેટ ₹6,000 સેટ કરો\")\n• 📖 **ખાતાવહી / ઉધાર નોંધી શકું છું** (દા.ત. \"રાજુને ₹1,500 ઉધાર આપ્યા\")\n• 👥 **ગ્રુપ બિલ વહેંચી શકું છું** (દા.ત. \"અમિત અને રાહુલ સાથે ₹1,200 સ્પ્લિટ કરો\")\n\nતમે બોલીને અથવા ટાઇપ કરીને જણાવી શકો છો!',
    'Tamil':
        'வணக்கம்! 👋 நான் உங்கள் **Grow Expense AI நிதி உதவியாளர்**.\n\nஉங்கள் செலவுகளைப் பகுப்பாய்வு செய்வதோடு, என்னால் நேரடியாக:\n• 💳 **செலவுகளைச் சேர்க்க முடியும்** (எ.கா. \"மதிய உணவிற்கு ₹350 சேர்க்கவும்\")\n• 🎯 **பட்ஜெட் அமைக்க முடியும்** (எ.கா. \"மளிகைப் பட்ஜெட்டை ₹6,000 ஆக அமைக்கவும்\")\n• 📖 **கடன் / பாக்கி கணக்கு பதிய முடியும்** (எ.கா. \"ராஜுவுக்கு ₹1,500 கடன் கொடுத்தேன்\")\n• 👥 **குழு பில்களைப் பிரிக்க முடியும்** (எ.கா. \"அமித் மற்றும் ராகுலுடன் ₹1,200 பிரிக்கவும்\")\n\nநீங்கள் பேசியோ அல்லது தட்டச்சு செய்தோ கட்டளையிடலாம்!',
    'Telugu':
        'నమస్కారం! 👋 నేను మీ **Grow Expense AI ఆర్థిక సహాయకుడిని**.\n\nమీ ఖర్చులను విశ్లేషించడంతో పాటు, నేను నేరుగా:\n• 💳 **ఖర్చులను జోడించగలను** (ఉదా. \"లంచ్ కోసం ₹350 జోడించండి\")\n• 🎯 **బడ్జెట్‌ను సెట్ చేయగలను** (ఉదా. \"కిరాణా బడ్జెట్ ₹6,000 సెట్ చేయండి\")\n• 📖 **ఖాతా / అప్పు వివరాలు నమోదు చేయగలను** (ఉదా. \"రాజుకు ₹1,500 అప్పు ఇచ్చాను\")\n• 👥 **గ్రూప్ బిల్లులను విభజించగలను** (ఉదా. \"అమిత్ మరియు రాహుల్‌తో ₹1,200 పంచుకోండి\")\n\nమీరు మాట్లాడి లేదా టైప్ చేసి ఆదేశించవచ్చు!',
    'Kannada':
        'ನಮಸ್ಕಾರ! 👋 ನಾನು ನಿಮ್ಮ **Grow Expense AI ಹಣಕಾಸು ಸಹಾಯಕ**.\n\nನಿಮ್ಮ ವೆಚ್ಚಗಳನ್ನು ವಿಶ್ಲೇಷಿಸುವುದರ ಜೊತೆಗೆ, ನಾನು ನೇರವಾಗಿ:\n• 💳 **ವೆಚ್ಚವನ್ನು ಸೇರಿಸಬಲ್ಲೆ** (ಉದಾ. \"ಊಟಕ್ಕಾಗಿ ₹350 ಸೇರಿಸಿ\")\n• 🎯 **ಬಜೆಟ್ ನಿಗದಿಪಡಿಸಬಲ್ಲೆ** (ಉದಾ. \"ಕಿರಾಣಿ ಬಜೆಟ್ ₹6,000 ನಿಗದಿಪಡಿಸಿ\")\n• 📖 **ಖಾತೆ / ಸಾಲದ ಲೆಕ್ಕ ದಾಖಲಿಸಬಲ್ಲೆ** (ಉದಾ. \"ರಾಜುಗೆ ₹1,500 ಸಾಲ ನೀಡಿದೆ\")\n• 👥 **ಗುಂಪು ಬಿಲ್‌ಗಳನ್ನು ಹಂಚಬಲ್ಲೆ** (ಉದಾ. \"ಅಮಿತ್ ಮತ್ತು ರಾಹುಲ್ ಜೊತೆ ₹1,200 ಹಂಚಿಕೊಳ್ಳಿ\")\n\nನೀವು ಮಾತನಾಡಿ ಅಥವಾ ಟೈಪ್ ಮಾಡಿ ತಿಳಿಸಬಹುದು!',
    'Malayalam':
        'നമസ്കാരം! 👋 ഞാൻ നിങ്ങളുടെ **Grow Expense AI ധനകാര്യ സഹായി** ആണ്.\n\nനിങ്ങളുടെ ചെലവുകൾ വിശകലനം ചെയ്യുന്നതിനൊപ്പം, എനിക്ക് നേരിട്ട്:\n• 💳 **ചെലവുകൾ ചേർക്കാം** (ഉദാ. \"ഉച്ചഭക്ഷണത്തിന് ₹350 ചേർക്കുക\")\n• 🎯 **ബജറ്റ് നിശ്ചയിക്കാം** (ഉദാ. \"പലചരക്ക് ബജറ്റ് ₹6,000 ആയി നിശ്ചയിക്കുക\")\n• 📖 **കടം / ബാക്കി കണക്ക് രേഖപ്പെടുത്താം** (ഉദാ. \"രാജുവിന് ₹1,500 കടം കൊടുത്തു\")\n• 👥 **ഗ്രൂപ്പ് ബില്ലുകൾ പങ്കിടാം** (ഉദാ. \"അമിതും രാഹുലുമായി ₹1,200 പങ്കിടുക\")\n\nനിങ്ങൾക്ക് സംസാരിച്ചോ ടൈപ്പ് ചെയ്തോ നിർദ്ദേശിക്കാം!',
    'Punjabi':
        'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ! 👋 ਮੈਂ ਤੁਹਾਡਾ **Grow Expense AI ਵਿੱਤੀ ਸਹਾਇਕ** ਹਾਂ।\n\nਤੁਹਾਡੇ ਖਰਚਿਆਂ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਕਰਨ ਤੋਂ ਇਲਾਵਾ, ਮੈਂ ਸਿੱਧਾ:\n• 💳 **ਖਰਚਾ ਜੋੜ ਸਕਦਾ ਹਾਂ** (ਜਿਵੇਂ \"ਦੁਪਹਿਰ ਦੇ ਖਾਣੇ ਲਈ ₹350 ਜੋੜੋ\")\n• 🎯 **ਬਜਟ ਸੈੱਟ ਕਰ ਸਕਦਾ ਹਾਂ** (ਜਿਵੇਂ \"ਰਾਸ਼ਨ ਦਾ ਬਜਟ ₹6,000 ਸੈੱਟ ਕਰੋ\")\n• 📖 **ਖਾਤਾ / ਉਧਾਰ ਦਰਜ ਕਰ ਸਕਦਾ ਹਾਂ** (ਜਿਵੇਂ \"ਰਾਜੂ ਨੂੰ ₹1,500 ਉਧਾਰ ਦਿੱਤਾ\")\n• 👥 **ਗਰੁੱਪ ਬਿੱਲ ਵੰਡ ਸਕਦਾ ਹਾਂ** (ਜਿਵੇਂ \"ਅਮਿਤ ਅਤੇ ਰਾਹੁਲ ਨਾਲ ₹1,200 ਵੰਡੋ\")\n\nਤੁਸੀਂ ਬੋਲ ਕੇ ਜਾਂ ਲਿਖ ਕੇ ਦੱਸ ਸਕਦੇ ਹੋ!',
  };

  static const Map<String, String> _localizedActionExecutionFollowUps = {
    'English': '✅ Action successfully recorded and synced! What would you like to do next? You can track another expense, check your remaining budget, or ask for category insights.',
    'Hindi': '✅ कार्य सफलतापूर्वक पूरा और दर्ज हो गया! अब आप क्या करना चाहेंगे? आप कोई अन्य खर्च जोड़ सकते हैं, अपना बचा हुआ बजट देख सकते हैं या वित्तीय विश्लेषण मांग सकते हैं।',
    'Hinglish': '✅ Action successfully record ho gaya! Ab aap kya karna chahenge? Aap dusra expense add kar sakte hain, remaining budget check kar sakte hain ya savings insights pooch sakte hain.',
    'Bengali': '✅ কাজ সফলভাবে সম্পন্ন এবং সংরক্ষিত হয়েছে! এরপরে আপনি কী করতে চান? আপনি অন্য খরচ যোগ করতে পারেন, অবশিষ্ট বাজেট দেখতে পারেন বা পরামর্শ চাইতে পারেন।',
    'Marathi': '✅ कृती यशस्वीरित्या पूर्ण आणि नोंदवली गेली! पुढे काय करू इच्छिता? तुम्ही दुसरा खर्च जोडू शकता, शिल्लक बजेट तपासू शकता किंवा विश्लेषण मागू शकता.',
    'Gujarati': '✅ કાર્ય સફળતાપૂર્વક પૂર્ણ અને રેકોર્ડ થઈ ગયું! આગળ તમે શું કરવા માંગો છો? તમે બીજો ખર્ચ ઉમેરી શકો છો, બાકીનું બજેટ ચકાસી શકો છો અથવા સલાહ લઈ શકો છો.',
    'Tamil': '✅ செயல் வெற்றிகரமாக முடிந்து பதிவு செய்யப்பட்டது! அடுத்து என்ன செய்ய விரும்புகிறீர்கள்? நீங்கள் மற்றொரு செலவைச் சேர்க்கலாம் அல்லது மீதமுள்ள பட்ஜெட்டைச் சரிபார்க்கலாம்.',
    'Telugu': '✅ చర్య విజయవంతంగా పూర్తయింది మరియు నమోదు చేయబడింది! తర్వాత మీరు ఏమి చేయాలనుకుంటున్నారు? మీరు మరొక ఖర్చును జోడించవచ్చు లేదా మిగిలిన బడ్జెట్‌ను తనిఖీ చేయవచ్చు.',
    'Kannada': '✅ ಕ್ರಿಯೆಯು ಯಶಸ್ವಿಯಾಗಿ ಪೂರ್ಣಗೊಂಡಿದೆ ಮತ್ತು ದಾಖಲಾಗಿದೆ! ಮುಂದೆ ನೀವು ಏನು ಮಾಡಲು ಬಯಸುತ್ತೀರಿ? ನೀವು ಇನ್ನೊಂದು ವೆಚ್ಚವನ್ನು ಸೇರಿಸಬಹುದು ಅಥವಾ ಉಳಿದ ಬಜೆಟ್ ಪರಿಶೀಲಿಸಬಹುದು.',
    'Malayalam': '✅ നടപടി വിജയകരമായി പൂർത്തിയാക്കി രേഖപ്പെടുത്തി! അടുത്തതായി നിങ്ങൾ എന്താണ് ചെയ്യാൻ ആഗ്രഹിക്കുന്നത്? നിങ്ങൾക്ക് മറ്റൊരു ചെലവ് ചേർക്കാം അല്ലെങ്കിൽ ബാക്കി ബജറ്റ് പരിശോധിക്കാം.',
    'Punjabi': '✅ ਕੰਮ ਸਫਲਤਾਪੂਰਵਕ ਪੂਰਾ ਹੋ ਗਿਆ ਅਤੇ ਦਰਜ ਕੀਤਾ ਗਿਆ! ਅੱਗੇ ਤੁਸੀਂ ਕੀ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ? ਤੁਸੀਂ ਕੋਈ ਹੋਰ ਖਰਚਾ ਜੋੜ ਸਕਦੇ ਹੋ ਜਾਂ ਬਾਕੀ ਬਚਿਆ ਬਜਟ ਚੈੱਕ ਕਰ ਸਕਦੇ ਹੋ।',
  };

  static const Map<String, String> _localizedActionDismissFollowUps = {
    'English': 'No problem, I have dismissed this action. Let me know if you want to modify the details or need help with anything else!',
    'Hindi': 'कोई बात नहीं, मैंने इस प्रस्ताव को रद्द कर दिया है। यदि आप विवरण बदलना चाहते हैं या कुछ और पूछना चाहते हैं तो मुझे बताएं!',
    'Hinglish': 'Koi baat nahi, maine is proposal ko dismiss kar diya hai. Agar details change karni ho ya kuch aur help chahiye to batayein!',
    'Bengali': 'কোনো সমস্যা নেই, আমি এটি বাতিল করেছি। বিবরণ পরিবর্তন করতে চাইলে বা অন্য কোনো সহায়তা লাগলে জানান!',
    'Marathi': 'काही हरकत नाही, मी हा प्रस्ताव रद्द केला आहे. तुम्हाला तपशील बदलायचे असतील किंवा इतर मदत हवी असल्यास सांगा!',
    'Gujarati': 'કોઈ વાંધો નહીં, મેં આ દરખાસ્ત રદ કરી દીધી છે. જો તમારે વિગતો બદલવી હોય અથવા બીજી મદદ જોઈતી હોય તો જણાવો!',
    'Tamil': 'பிரச்சினை இல்லை, நான் இதை நிராகரித்துள்ளேன். விவரங்களை மாற்ற விரும்பினால் அல்லது வேறு ஏதேனும் உதவி தேவைப்பட்டால் தெரியப்படுத்துங்கள்!',
    'Telugu': 'పర్వాలేదు, నేను ఈ ప్రతిపాదనను రద్దు చేసాను. మీరు వివరాలను మార్చాలనుకుంటే లేదా మరేదైనా సహాయం కావాలంటే తెలియజేయండి!',
    'Kannada': 'ಪರವಾಗಿಲ್ಲ, ನಾನು ಈ ಪ್ರಸ್ತಾಪವನ್ನು ರದ್ದುಗೊಳಿಸಿದ್ದೇನೆ. ವಿವರಗಳನ್ನು ಬದಲಾಯಿಸಲು ಅಥವಾ ಬೇರೆ ಯಾವುದೇ ಸಹಾಯ ಬೇಕಾದರೆ ತಿಳಿಸಿ!',
    'Malayalam': 'കുഴപ്പമില്ല, ഞാൻ ഇത് റദ്ദാക്കിയിട്ടുണ്ട്. വിശദാംശങ്ങൾ മാറ്റണമെങ്കിലോ മറ്റ് എന്തെങ്കിലും സഹായം വേണമെങ്കിലോ അറിയിക്കുക!',
    'Punjabi': 'ਕੋਈ ਗੱਲ ਨਹੀਂ, ਮੈਂ ਇਸਨੂੰ ਰੱਦ ਕਰ ਦਿੱਤਾ ਹੈ। ਜੇਕਰ ਵੇਰਵੇ ਬਦਲਣੇ ਹਨ ਜਾਂ ਕੋਈ ਹੋਰ ਮਦਦ ਚਾਹੀਦੀ ਹੈ ਤਾਂ ਦੱਸੋ!',
  };

  static const Map<String, List<String>> _localizedBusinessSuggestions = {
    'English': [
      '📊 Analyze today\'s sales & net profit margin',
      '👥 Show pending customer dues & Khata balance',
      '🧾 What is my GST collection this month?',
      '💡 Give tips to reduce shop operating expenses',
      '📈 How can I increase daily customer sales?',
      '📖 Record ₹2,000 credit given to customer',
      '➕ Record ₹1,500 inventory stock purchase',
      '🔍 Compare this month sales with last month',
    ],
    'Hinglish': [
      '📊 Aaj ki shop sales aur net profit margin dikhao',
      '👥 Customers ka pending Khata/Udhar kitna baki hai?',
      '🧾 Is mahine total kitna GST collect hua?',
      '💡 Shop ke operating expenses kam karne ke tips do',
      '📈 Dukan ki daily sales kaise badhayein?',
      '📖 Customer ko ₹2,000 udhar diya note karo',
      '➕ ₹1,500 ka stock purchase expense add karo',
      '🔍 Pichle mahine aur is mahine ki sales compare karo',
    ],
    'Hindi': [
      '📊 आज की बिक्री और शुद्ध लाभ (प्रॉफिट) मार्जिन बताएं',
      '👥 ग्राहकों का कितना उधार (खाता) बाकी है?',
      '🧾 इस महीने कुल कितना GST संग्रह हुआ?',
      '💡 दुकान के परिचालन खर्च कम करने के उपाय बताएं',
      '📈 दुकान की दैनिक बिक्री कैसे बढ़ाएं?',
      '📖 ग्राहक को ₹2,000 उधार दिया खाते में दर्ज करें',
      '➕ ₹1,500 का माल खरीद खर्च जोड़ें',
      '🔍 पिछले महीने और इस महीने की बिक्री की तुलना करें',
    ],
    'Bengali': [
      '📊 আজকের মোট বিক্রি এবং লাভ বিশ্লেষণ করুন',
      '👥 গ্রাহকদের কত টাকা বাকি (খাতা) আছে?',
      '🧾 এই মাসে মোট কত জিএসটি (GST) জমা হয়েছে?',
      '💡 দোকানের খরচ কমানোর পরামর্শ দিন',
      '📈 দোকানের দৈনিক বিক্রি কীভাবে বাড়াব?',
      '📖 গ্রাহককে ₹2,000 বাকি দিয়েছি খাতায় লিখুন',
      '➕ ₹1,500 মালের স্টক ক্রয় খরচ যোগ করুন',
      '🔍 গত মাসের সাথে এই মাসের বিক্রির তুলনা করুন',
    ],
    'Marathi': [
      '📊 आजची विक्री आणि निव्वळ नफा मार्जिन दाखवा',
      '👥 ग्राहकांचे किती उधारी (खाते) बाकी आहे?',
      '🧾 या महिन्यात किती GST गोळा झाला?',
      '💡 दुकानाचे खर्च कमी करण्यासाठी टिप्स द्या',
      '📈 दुकानाची विक्री कशी वाढवायची?',
      '📖 ग्राहकाला ₹2,000 उधारी दिली नोंद करा',
      '➕ ₹1,500 स्टॉक खरेदी खर्च जोडा',
      '🔍 मागील महिना आणि या महिन्याच्या विक्रीची तुलना करा',
    ],
    'Gujarati': [
      '📊 આજનું વેચાણ અને નફો (પ્રોફિટ) વિશ્લેષણ કરો',
      '👥 ગ્રાહકોનું કેટલું ઉધાર (ખાતાવહી) બાકી છે?',
      '🧾 આ મહિને કેટલો GST જમા થયો?',
      '💡 દુકાનનો ખર્ચ ઘટાડવાની ટિપ્સ આપો',
      '📈 દુકાનનું દૈનિક વેચાણ કેવી રીતે વધારવું?',
      '📖 ગ્રાહકને ₹2,000 ઉધાર આપ્યા નોંધ કરો',
      '➕ ₹1,500 નો સ્ટોક ખરીદ ખર્ચ ઉમેરો',
      '🔍 ગયા મહિના અને આ મહિનાના વેચાણની સરખામણી કરો',
    ],
    'Tamil': [
      '📊 இன்றைய விற்பனை மற்றும் லாப விபரங்களை பகுப்பாய்வு செய்யுங்கள்',
      '👥 வாடிக்கையாளர்களின் நிலுவைத் தொகை எவ்வளவு?',
      '🧾 இந்த மாதம் வசூலிக்கப்பட்ட GST எவ்வளவு?',
      '💡 வணிகச் செலவுகளைக் குறைப்பதற்கான குறிப்புகள் கொடுங்கள்',
      '📈 தினசரி விற்பனையை எவ்வாறு அதிகரிப்பது?',
      '📖 வாடிக்கையாளருக்கு ₹2,000 கடன் கொடுத்துள்ளேன் பதிவு செய்',
      '➕ ₹1,500 சரக்கு வாங்கிய செலவைச் சேர்க்கவும்',
      '🔍 கடந்த மாத விற்பனையுடன் ஒப்பிட்டுப் பார்க்கவும்',
    ],
    'Telugu': [
      '📊 నేటి వ్యాపార అమ్మకాలు మరియు లాభాల విశ్లేషణ చూపండి',
      '👥 కస్టమర్ల నుండి రావాల్సిన బాకీలు (ఖాతా) ఎంత?',
      '🧾 ఈ నెల ఎంత GST వసూలు అయింది?',
      '💡 వ్యాపార ఖర్చులను తగ్గించడానికి సూచనలు ఇవ్వండి',
      '📈 రోజువారీ అమ్మకాలను ఎలా పెంచుకోవాలి?',
      '📖 కస్టమర్‌కు ₹2,000 అప్పు ఇచ్చాను రికార్డ్ చేయండి',
      '➕ ₹1,500 సరుకు కొనుగోలు ఖర్చును జోడించండి',
      '🔍 గత నెలతో పోల్చి అమ్మకాల వివరాలు చూపండి',
    ],
    'Kannada': [
      '📊 ಇಂದಿನ ವ್ಯಾಪಾರ ಮಾರಾಟ ಮತ್ತು ಲಾಭದ ವಿವರ ನೀಡಿ',
      '👥 ಗ್ರಾಹಕರಿಂದ ಬರಬೇಕಾದ ಬಾಕಿ (ಖಾತೆ) ಎಷ್ಟು?',
      '🧾 ಈ ತಿಂಗಳು ಎಷ್ಟು GST ಸಂಗ್ರಹವಾಗಿದೆ?',
      '💡 ಅಂಗಡಿಯ ಖರ್ಚು ಕಡಿಮೆ ಮಾಡಲು ಸಲಹೆ ನೀಡಿ',
      '📈 ದೈನಂದಿನ ಮಾರಾಟವನ್ನು ಹೆಚ್ಚಿಸುವುದು ಹೇಗೆ?',
      '📖 ಗ್ರಾಹಕರಿಗೆ ₹2,000 ಸಾಲ ನೀಡಿದ್ದನ್ನು ದಾಖಲಿಸಿ',
      '➕ ₹1,500 ಸ್ಟಾಕ್ ಖರೀದಿ ವೆಚ್ಚವನ್ನು ಸೇರಿಸಿ',
      '🔍 ಕಳೆದ ತಿಂಗಳೊಂದಿಗೆ ಮಾರಾಟವನ್ನು ಹೋಲಿಕೆ ಮಾಡಿ',
    ],
    'Malayalam': [
      '📊 ഇന്നത്തെ വിൽപ്പനയും ലാഭവും വിശകലനം ചെയ്യുക',
      '👥 ഉപഭോക്താക്കളിൽ നിന്ന് ലഭിക്കാനുള്ള കുടിശ്ശിക എത്ര?',
      '🧾 ഈ മാസം എത്ര GST ലഭിച്ചു?',
      '💡 കടയുടെ ചെലവ് കുറയ്ക്കാനുള്ള വഴികൾ പറയൂ',
      '📈 പ്രതിദിന വിൽപ്പന എങ്ങനെ വർദ്ധിപ്പിക്കാം?',
      '📖 ഉപഭോക്താവിന് ₹2,000 കടം കൊടുത്തത് രേഖപ്പെടുത്തുക',
      '➕ ₹1,500 സ്റ്റോക്ക് വാങ്ങിയ ചെലവ് ചേർക്കുക',
      '🔍 കഴിഞ്ഞ മാസത്തെ വിൽപ്പനയുമായി താരതമ്യം ചെയ്യുക',
    ],
    'Punjabi': [
      '📊 ਅੱਜ ਦੀ ਵਿਕਰੀ ਅਤੇ ਮੁਨਾਫ਼ੇ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਕਰੋ',
      '👥 ਗਾਹਕਾਂ ਦਾ ਕਿੰਨਾ ਉਧਾਰ (ਖਾਤਾ) ਬਾਕੀ ਹੈ?',
      '🧾 ਇਸ ਮਹੀਨੇ ਕਿੰਨਾ GST ਇਕੱਠਾ ਹੋਇਆ?',
      '💡 ਦੁਕਾਨ ਦੇ ਖਰਚੇ ਘਟਾਉਣ ਦੇ ਸੁਝਾਅ ਦਿਓ',
      '📈 ਰੋਜ਼ਾਨਾ ਵਿਕਰੀ ਕਿਵੇਂ ਵਧਾਈਏ?',
      '📖 ਗਾਹਕ ਨੂੰ ₹2,000 ਉਧਾਰ ਦਿੱਤਾ ਦਰਜ ਕਰੋ',
      '➕ ₹1,500 ਦਾ ਸਟਾਕ ਖਰੀਦ ਖਰਚਾ ਜੋੜੋ',
      '🔍 ਪਿਛਲੇ ਮਹੀਨੇ ਨਾਲ ਵਿਕਰੀ ਦੀ ਤੁਲਨਾ ਕਰੋ',
    ],
  };

  static const Map<String, String> _localizedBusinessWelcomeMessages = {
    'English':
        'Hello! 🏢 Welcome to **Grow Expense Business AI CFO & Tax Advisor**.\n\nI can help you grow your business with:\n• 📊 **Sales & Margin Analysis** (Daily & Monthly P&L)\n• 👥 **Customer Khata Dues** (Udhar recovery tracking)\n• 🧾 **GST & Tax Accounting** (Slab calculations & invoicing)\n• 💼 **Operating Expenses** (Stock, rent, utilities & salaries)\n\nWhat would you like to analyze or record today?',
    'Hindi':
        'नमस्ते! 🏢 **Grow Expense Business AI CFO और टैक्स सलाहकार** में आपका स्वागत है।\n\nमैं आपके व्यापार को आगे बढ़ाने में मदद कर सकता हूँ:\n• 📊 **बिक्री और मुनाफा विश्लेषण** (दैनिक और मासिक लाभ-हानि)\n• 👥 **ग्राहक खाता उधारी** (उधार वसूली ट्रैकिंग)\n• 🧾 **GST और टैक्स गणना** (बिलिंग और टैक्स फाइलिंग सहायता)\n• 💼 **व्यापारिक खर्च** (स्टॉक, किराया, बिजली और वेतन)\n\nआज आपके व्यापार के लिए क्या सहायता करूँ?',
    'Hinglish':
        'Namaste! 🏢 **Grow Expense Business AI CFO & Tax Advisor** me aapka swagat hai.\n\nMain aapki business growth ke liye help kar sakta hoon:\n• 📊 **Sales & Margin Analysis** (Daily & Monthly P&L check)\n• 👥 **Customer Khata/Udhar Tracking** (Pending dues recovery)\n• 🧾 **GST & Tax Calculation** (Slabs & Invoicing insights)\n• 💼 **Business Expenses** (Stock purchase, rent, bills & salary)\n\nAaj aapke business me kya check ya record karna hai?',
    'Bengali':
        'নমস্কার! 🏢 **Grow Expense Business AI CFO & Tax Advisor**-এ আপনাকে স্বাগতম।\n\nআপনার ব্যবসার উন্নতিতে আমি সাহায্য করতে পারি:\n• 📊 **বিক্রি ও লাভ বিশ্লেষণ** (দৈনিক ও মাসিক লাভ-ক্ষতি)\n• 👥 **গ্রাহকদের খাতার হিসাব** (বাকি টাকা আদায়ের হিসাব)\n• 🧾 **জিএসটি ও ট্যাক্স হিসাব** (ইনভয়েসিং ও ট্যাক্স হিসাব)\n• 💼 **দোকানের খরচ** (স্টক ক্রয়, ভাড়া, বিল ও বেতন)\n\nআজ আপনার ব্যবসার জন্য কী করতে পারি?',
    'Marathi':
        'नमस्कार! 🏢 **Grow Expense Business AI CFO & Tax Advisor** मध्ये आपले स्वागत आहे.\n\nमी तुमच्या व्यवसायाच्या वाढीसाठी मदत करू शकतो:\n• 📊 **विक्री आणि नफा विश्लेषण** (दैनिक आणि मासिक नफा-तोटा)\n• 👥 **ग्राहक खाते आणि उधारी** (उधारी वसुली ट्रॅकिंग)\n• 🧾 **GST आणि कर हिशोब** (बिलिंग आणि कर विश्लेषण)\n• 💼 **व्यवसाय खर्च** (स्टॉक खरेदी, भाडे आणि पगार)\n\nआज आपल्या व्यवसायासाठी काय मदत करू?',
    'Gujarati':
        'નમસ્તે! 🏢 **Grow Expense Business AI CFO & Tax Advisor** માં આપનું સ્વાગત છે.\n\nહું તમારા વ્યવસાયના વિકાસમાં મદદ કરી શકું છું:\n• 📊 **વેચાણ અને નફાનું વિશ્લેષણ** (દૈનિક અને માસિક નફો-નુકસાન)\n• 👥 **ગ્રાહક ખાતાવહી અને ઉધાર** (બાકી નાણાં વસૂલાત)\n• 🧾 **GST અને ટેક્સ ગણતરી** (બિલિંગ અને ટેક્સ)\n• 💼 **વ્યવસાયિક ખર્ચ** (માલસામાન, ભાડું અને પગાર)\n\nઆજે તમારા વેપાર માટે શું વિશ્લેષણ કરવું છે?',
    'Tamil':
        'வணக்கம்! 🏢 **Grow Expense Business AI CFO & Tax Advisor**-க்கு உங்களை வரவேற்கிறோம்.\n\nஉங்கள் வணிக வளர்ச்சிக்கு நான் உதவ முடியும்:\n• 📊 **விற்பனை மற்றும் லாப பகுப்பாய்வு** (P&L கணக்கீடு)\n• 👥 **வாடிக்கையாளர் கடன் கணக்கு** (நிலுவைத் தொகை வசூல்)\n• 🧾 **GST மற்றும் வரி கணக்கு** (வரி கணக்கீடுகள்)\n• 💼 **வணிகச் செலவுகள்** (சரக்கு கொள்முதல், வாடகை மற்றும் சம்பளம்)\n\nஇன்று உங்கள் வணிகத்திற்கு நான் என்ன உதவி செய்ய வேண்டும்?',
    'Telugu':
        'నమస్కారం! 🏢 **Grow Expense Business AI CFO & Tax Advisor** కు స్వాగతం.\n\nమీ వ్యాపార వృద్ధికి నేను సహాయపడగలను:\n• 📊 **అమ్మకాలు & లాభాల విశ్లేషణ** (లాభనష్టాల లెక్కలు)\n• 👥 **కస్టమర్ ఖాతా బాకీలు** (వసూలు ట్రాకింగ్)\n• 🧾 **GST మరియు పన్ను గణన** (ఇన్వాయిస్ లెక్కలు)\n• 💼 **వ్యాపార ఖర్చులు** (సరుకు, అద్దె සහ జీతాలు)\n\nఈ రోజు మీ వ్యాపారం కోసం ఏమి చెక్ చేద్దాం?',
    'Kannada':
        'ನಮಸ್ಕಾರ! 🏢 **Grow Expense Business AI CFO & Tax Advisor** ಗೆ ಸುಸ್ವಾಗತ.\n\nನಿಮ್ಮ ವ್ಯವಹಾರದ ಬೆಳವಣಿಗೆಗೆ ನಾನು ಸಹಾಯ ಮಾಡಬಲ್ಲೆ:\n• 📊 **ಮಾರಾಟ ಮತ್ತು ಲಾಭದ ವಿಶ್ಲೇಷಣೆ** (ದೈನಂದಿನ P&L)\n• 👥 **ಗ್ರಾಹಕರ ಖಾತೆ ಬಾಕಿ** (ಸಾಲ ವಸೂಲಾತಿ ಟ್ರ್ಯಾಕಿಂಗ್)\n• 🧾 **GST ಮತ್ತು ತೆರಿಗೆ ಲೆಕ್ಕಾಚಾರ** (ಇನ್‌ವಾಯ್ಸ್ ವಿವರ)\n• 💼 **ವ್ಯವಹಾರ ವೆಚ್ಚಗಳು** (ಸ್ಟಾಕ್, ಬಾಡಿಗೆ ಮತ್ತು ಸಂಬಳ)\n\nಇಂದು ನಿಮ್ಮ ವ್ಯವಹಾರಕ್ಕಾಗಿ ಏನು ಪರಿಶೀಲಿಸಬೇಕು?',
    'Malayalam':
        'നമസ്കാരം! 🏢 **Grow Expense Business AI CFO & Tax Advisor**-ലേക്ക് സ്വാഗതം.\n\nനിങ്ങളുടെ ബിസിനസ്സ് വളർച്ചയ്ക്ക് എനിക്ക് സഹായിക്കാനാകും:\n• 📊 **വിൽപ്പനയും ലാഭവും വിശകലനം** (P&L കണക്കുകൾ)\n• 👥 **ഉപഭോക്തൃ കടം കണക്കുകൾ** (കുടിശ്ശിക ട്രാക്കിംഗ്)\n• 🧾 **GST & നികുതി കണക്കുകൂട്ടൽ** (ഇൻവോയ്സ് സഹായം)\n• 💼 **ബിസിനസ്സ് ചെലവുകൾ** (സ്റ്റോക്ക്, വാടക, ശമ്പളം)\n\nഇന്ന് നിങ്ങളുടെ ബിസിനസിനായി എന്താണ് വിശകലനം ചെയ്യേണ്ടത്?',
    'Punjabi':
        'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ! 🏢 **Grow Expense Business AI CFO & Tax Advisor** ਵਿੱਚ ਤੁਹਾਡਾ ਸਵਾਗਤ ਹੈ।\n\nਮੈਂ ਤੁਹਾਡੇ ਕਾਰੋਬਾਰ ਦੇ ਵਾਧੇ ਲਈ ਮਦਦ ਕਰ ਸਕਦਾ ਹਾਂ:\n• 📊 **ਵਿਕਰੀ ਅਤੇ ਮੁਨਾਫ਼ਾ ਵਿਸ਼ਲੇਸ਼ਣ** (ਰੋਜ਼ਾਨਾ ਅਤੇ ਮਹੀਨਾਵਾਰ P&L)\n• 👥 **ਗਾਹਕ ਖਾਤਾ ਉਧਾਰ** (ਉਗਰਾਹੀ ਟ੍ਰੈਕਿੰਗ)\n• 🧾 **GST ਅਤੇ ਟੈਕਸ ਹਿਸਾਬ** (ਬਿਲਿੰਗ ਅਤੇ ਟੈਕਸ)\n• 💼 **ਕਾਰੋਬਾਰੀ ਖਰਚੇ** (ਸਟਾਕ ਖਰੀਦ, ਕਿਰਾਇਆ ਅਤੇ ਤਨਖਾਹਾਂ)\n\nਅੱਜ ਤੁਹਾਡੇ ਕਾਰੋਬਾਰ ਲਈ ਕੀ ਚੈੱਕ ਕਰਨਾ ਹੈ?',
  };

  List<String> get _currentSuggestedPrompts {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final lang = AiConfigService.instance.responseLanguage;
    if (userProvider.isBusinessMode) {
      return _localizedBusinessSuggestions[lang] ?? _localizedBusinessSuggestions['English']!;
    }
    return _localizedSuggestions[lang] ?? _localizedSuggestions['English']!;
  }

  @override
  void initState() {
    super.initState();
    AiConfigService.instance.addListener(_onAiConfigUpdated);
    _loadChatHistoryAndSessions();
  }

  void _onAiConfigUpdated() {
    if (!mounted) return;
    setState(() {
      // If the chat only has the initial welcome greeting, update it to the new language immediately
      if (_messages.length == 1 && !_messages[0].isUser && _messages[0].id == 'initial_welcome') {
        final lang = AiConfigService.instance.responseLanguage;
        final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
        final msgText = isBusiness
            ? (_localizedBusinessWelcomeMessages[lang] ?? _localizedBusinessWelcomeMessages['English']!)
            : (_localizedWelcomeMessages[lang] ?? _localizedWelcomeMessages['English']!);
        _messages[0] = ChatMessage(
          id: 'initial_welcome',
          text: msgText,
          isUser: false,
          timestamp: _messages[0].timestamp,
        );
      }
    });
  }

  String _generateTitleFromPrompt(String prompt) {
    // Strip leading decorative emojis / action command characters
    String clean = prompt.replaceAll(
      RegExp(r'^[^\w₹0-9\u0900-\u097F\u0980-\u09FF\u0A00-\u0A7F\u0A80-\u0AFF\u0B00-\u0B7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F]+\s*'),
      '',
    ).trim();
    if (clean.isEmpty) clean = prompt.trim();
    clean = clean.replaceAll(RegExp(r'<!--ACTION_INTENT:(.*?)-->', dotAll: true), '').trim();
    if (clean.length > 36) {
      return '${clean.substring(0, 36).trim()}...';
    }
    return clean.isEmpty ? 'New Conversation' : clean;
  }

  Future<void> _refreshSessionsList() async {
    try {
      final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
      final rows = await DatabaseHelper.instance.getAiChatSessions(mode: isBusiness ? 'business' : 'personal');
      if (mounted) {
        setState(() {
          _sessions = rows;
        });
      }
    } catch (e) {
      debugPrint('[AiAdvisorScreen] Error refreshing sessions: $e');
    }
  }

  Future<void> _loadChatHistoryAndSessions() async {
    setState(() => _isLoadingSessions = true);
    try {
      final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
      final activeMode = isBusiness ? 'business' : 'personal';
      var sessionRows = await DatabaseHelper.instance.getAiChatSessions(mode: activeMode);

      // Legacy migration: If existing unassigned messages exist and sessions is empty, bundle them into a session
      final legacyRows = await DatabaseHelper.instance.getAiChatMessages();
      if (sessionRows.isEmpty && legacyRows.isNotEmpty && !isBusiness) {
        final firstUserMsg = legacyRows.firstWhere((m) => m['is_user'] == 1, orElse: () => legacyRows.first);
        final rawTitle = firstUserMsg['text']?.toString() ?? 'Financial Advice';
        final cleanTitle = _generateTitleFromPrompt(rawTitle);
        final legacySessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

        await DatabaseHelper.instance.createAiChatSession(
          id: legacySessionId,
          title: cleanTitle,
          createdAt: DateTime.tryParse(legacyRows.first['timestamp']?.toString() ?? '') ?? DateTime.now(),
          mode: 'personal',
        );

        // Assign legacy messages to this session
        for (var m in legacyRows) {
          final mId = m['id']?.toString();
          if (mId != null) {
            await DatabaseHelper.instance.insertAiChatMessage(
              id: mId,
              sessionId: legacySessionId,
              text: m['text']?.toString() ?? '',
              isUser: m['is_user'] == 1,
              timestamp: DateTime.tryParse(m['timestamp']?.toString() ?? '') ?? DateTime.now(),
              modelUsed: m['model_used']?.toString(),
            );
          }
        }
        sessionRows = await DatabaseHelper.instance.getAiChatSessions(mode: 'personal');
      }

      if (!mounted) return;
      setState(() {
        _sessions = sessionRows;
        _isLoadingSessions = false;
      });

      if (_sessions.isNotEmpty) {
        final latest = _sessions.first;
        final sId = latest['id']?.toString() ?? '';
        final sTitle = latest['title']?.toString() ?? (isBusiness ? 'Business Advisor' : 'Financial Advisor');
        _currentSessionId = sId;
        _currentSessionTitle = sTitle;
        await _loadSessionMessages(sId);
      } else {
        _startNewChat();
      }

      await _checkMonthRolloverPrompt();
    } catch (e) {
      debugPrint('[AiAdvisorScreen] Error loading sessions/chat: $e');
      if (mounted) {
        setState(() => _isLoadingSessions = false);
        _startNewChat();
      }
    }
  }

  Future<void> _loadSessionMessages(String sessionId) async {
    try {
      final rows = await DatabaseHelper.instance.getAiChatMessages(sessionId: sessionId);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        if (rows.isNotEmpty) {
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
        } else {
          _addInitialWelcomeMessage();
        }
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[AiAdvisorScreen] Error loading messages for session $sessionId: $e');
      _addInitialWelcomeMessage();
    }
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = null;
      _currentSessionTitle = 'New Chat';
      _messages.clear();
      _addInitialWelcomeMessage();
    });
  }

  Future<void> _switchSession(String? sessionId, String title) async {
    if (sessionId == null) {
      _startNewChat();
      return;
    }
    setState(() {
      _currentSessionId = sessionId;
      _currentSessionTitle = title;
    });
    await _loadSessionMessages(sessionId);
  }

  Future<void> _showRenameSessionDialog(String sessionId, String currentTitle) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final ctrl = TextEditingController(text: currentTitle);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_note_rounded, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rename Chat',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter chat title',
            filled: true,
            fillColor: isDark ? const Color(0xFF14171F) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Save Title', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.trim().isNotEmpty && mounted) {
      await DatabaseHelper.instance.updateAiChatSessionTitle(id: sessionId, title: newTitle.trim());
      setState(() {
        if (_currentSessionId == sessionId) {
          _currentSessionTitle = newTitle.trim();
        }
      });
      await _refreshSessionsList();
      if (mounted) {
        CustomToast.show(context, 'Chat renamed to "$newTitle" ✨');
      }
    }
  }

  Future<void> _confirmDeleteSession(String sessionId, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
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
                'Delete Chat?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$title"? All messages in this chat session will be permanently removed.',
          style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await DatabaseHelper.instance.deleteAiChatSession(sessionId);
      await _refreshSessionsList();
      if (_currentSessionId == sessionId) {
        if (_sessions.isNotEmpty) {
          final next = _sessions.first;
          await _switchSession(next['id']?.toString(), next['title']?.toString() ?? 'Financial Advisor');
        } else {
          _startNewChat();
        }
      }
      if (mounted) {
        CustomToast.show(context, 'Chat deleted successfully 🗑️');
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupSessionsByTimeline(List<Map<String, dynamic>> sessions) {
    final Map<String, List<Map<String, dynamic>>> groups = {
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Older': [],
    };

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));

    for (var s in sessions) {
      final dateStr = s['updated_at']?.toString() ?? s['created_at']?.toString() ?? '';
      final dt = DateTime.tryParse(dateStr) ?? now;
      if (dt.isAfter(todayStart)) {
        groups['Today']!.add(s);
      } else if (dt.isAfter(yesterdayStart)) {
        groups['Yesterday']!.add(s);
      } else if (dt.isAfter(sevenDaysAgo)) {
        groups['Previous 7 Days']!.add(s);
      } else {
        groups['Older']!.add(s);
      }
    }

    return groups;
  }

  String _formatSessionTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);
    if (dtDay == today) {
      return DateFormat('hh:mm a').format(dt);
    } else if (dtDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE, dd MMM').format(dt);
    } else {
      return DateFormat('dd MMM yyyy').format(dt);
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
      final hasPastMessages = _messages.any((m) {
        final monthKey = DateFormat('yyyy-MM').format(m.timestamp);
        return monthKey != currentMonthKey;
      });

      if (hasPastMessages && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showNewMonthChatDialog(currentMonthKey, monthName, prefs);
          }
        });
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
              'A new month ($monthName) has started! Would you like to start a fresh chat session for $monthName? Your past conversations will stay securely saved in History.',
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
                      'Your saved expenses and budgets are always 100% safe.',
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
                  child: const Text('Keep Current Chat', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  child: const Text('New Chat 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await prefs.setString('last_seen_chat_month', currentMonthKey);

    if (startFresh == true && mounted) {
      _startNewChat();
      CustomToast.show(context, 'Started fresh chat for $monthName! ✨');
    }
  }

  void _addInitialWelcomeMessage() {
    final lang = AiConfigService.instance.responseLanguage;
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    final msgText = isBusiness
        ? (_localizedBusinessWelcomeMessages[lang] ?? _localizedBusinessWelcomeMessages['English']!)
        : (_localizedWelcomeMessages[lang] ?? _localizedWelcomeMessages['English']!);
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'initial_welcome',
          text: msgText,
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

  Future<String> _buildBusinessFinancialContext() async {
    final prof = await DatabaseHelper.instance.getBusinessProfile();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final monthStart = DateTime(now.year, now.month, 1);

    final todayMetrics = await DatabaseHelper.instance.getBusinessMetrics(start: todayStart, end: todayEnd);
    final monthMetrics = await DatabaseHelper.instance.getBusinessMetrics(start: monthStart, end: todayEnd);

    // Business Operating Expenses
    final expRows = await DatabaseHelper.instance.getExpenses(ledgerType: 'business');
    double todayBExp = 0.0;
    double monthBExp = 0.0;
    for (var e in expRows) {
      if (e.transactionDate.isAfter(todayStart) && e.transactionDate.isBefore(todayEnd)) {
        todayBExp += e.amount;
      }
      if (e.transactionDate.isAfter(monthStart) && e.transactionDate.isBefore(todayEnd)) {
        monthBExp += e.amount;
      }
    }

    // Customer Dues & Vendor Dues from Khata (Strictly Business Ledger)
    final khataEntries = await DatabaseHelper.instance.getKhataEntries(ledgerType: 'business');
    double customerLenaHai = 0.0;
    double vendorDenaHai = 0.0;
    for (var k in khataEntries) {
      if (!k.isSettled && k.ledgerType == 'business') {
        if (k.type == 'lent') {
          customerLenaHai += k.amount;
        } else {
          vendorDenaHai += k.amount;
        }
      }
    }

    final recentSales = await DatabaseHelper.instance.getBusinessSales(limit: 6);

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('=== BUSINESS / SHOP PROFILE ===');
    buffer.writeln('Business Name: ${prof.businessName}');
    if (prof.gstin != null && prof.gstin!.isNotEmpty) buffer.writeln('GSTIN: ${prof.gstin}');
    buffer.writeln('Active Month: ${DateFormat('MMMM yyyy').format(now)}');

    buffer.writeln('\n=== TODAY\'S PERFORMANCE ===');
    buffer.writeln('Today\'s Total Sales: INR ${(todayMetrics['totalSales'] ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Today\'s GST Collected: INR ${(todayMetrics['taxCollected'] ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Today\'s Business Operating Expenses: INR ${todayBExp.toStringAsFixed(2)}');
    final todayNet = (todayMetrics['totalSales'] ?? 0.0) - todayBExp;
    buffer.writeln('Today\'s Net Estimated Profit: INR ${todayNet.toStringAsFixed(2)}');

    buffer.writeln('\n=== THIS MONTH\'S METRICS ===');
    buffer.writeln('Monthly Total Sales: INR ${(monthMetrics['totalSales'] ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Monthly GST Collected: INR ${(monthMetrics['taxCollected'] ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Monthly Business Expenses (Stock, Rent, Bills): INR ${monthBExp.toStringAsFixed(2)}');
    final monthNet = (monthMetrics['totalSales'] ?? 0.0) - monthBExp;
    buffer.writeln('Monthly Net Estimated Profit: INR ${monthNet.toStringAsFixed(2)}');

    buffer.writeln('\n=== KHATA / CREDIT RECOVERY STATUS ===');
    buffer.writeln('Total Customer Pending Dues (Lena Hai / Receivable): INR ${customerLenaHai.toStringAsFixed(2)}');
    buffer.writeln('Total Supplier / Vendor Payables (Dena Hai): INR ${vendorDenaHai.toStringAsFixed(2)}');

    if (recentSales.isNotEmpty) {
      buffer.writeln('\n=== RECENT SALES INVOICES ===');
      for (var s in recentSales) {
        buffer.writeln('- Inv #${s.invoiceNo} to ${s.customerName}: INR ${s.finalAmount.toStringAsFixed(2)} (${s.paymentStatus}, ${s.paymentMode}) on ${DateFormat('dd MMM').format(s.saleDate)}');
      }
    }

    return buffer.toString();
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

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isBusiness = userProvider.isBusinessMode;
    final modeStr = isBusiness ? 'business' : 'personal';

    // Auto-create session if starting on a new draft chat
    if (_currentSessionId == null) {
      final newSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      final autoTitle = _generateTitleFromPrompt(question);
      await DatabaseHelper.instance.createAiChatSession(
        id: newSessionId,
        title: autoTitle,
        mode: modeStr,
      );
      setState(() {
        _currentSessionId = newSessionId;
        _currentSessionTitle = autoTitle;
      });
      _refreshSessionsList();
    }

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
      sessionId: _currentSessionId,
      text: userMsg.text,
      isUser: true,
      timestamp: userMsg.timestamp,
    );

    String contextSummary;
    if (isBusiness) {
      contextSummary = await _buildBusinessFinancialContext();
    } else {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      contextSummary = _buildFinancialContext(expenseProvider);
    }

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
      isBusinessMode: isBusiness,
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
      sessionId: _currentSessionId,
      text: aiMsg.toRawText(),
      isUser: false,
      timestamp: aiMsg.timestamp,
      modelUsed: aiMsg.modelUsed,
    );

    _refreshSessionsList();
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
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    final modeStr = isBusiness ? 'business' : 'personal';
    final stats = await DatabaseHelper.instance.getAiChatStats(mode: modeStr);
    final count = stats['count'] as int? ?? _messages.where((m) => m.isUser || m.text.isNotEmpty).length;
    final sessionCount = stats['sessionCount'] as int? ?? _sessions.length;
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
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isBusiness ? 'Clear Business AI History?' : 'Clear Personal AI History?',
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
                          '${isBusiness ? "Business" : "Personal"} Chat Size: $formattedSize',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count messages in $sessionCount conversations',
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
              isBusiness
                  ? 'All your past Business AI CFO chat history will be permanently cleared from this device. Your business sales, inventory, and khata records remain 100% safe.'
                  : 'All your past Personal AI Advisor chat history will be permanently cleared from this device. Your personal expenses and budgets remain 100% safe.',
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
              'Clear All ($formattedSize)',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.clearAllAiChatData(mode: modeStr);
      _startNewChat();
      await _refreshSessionsList();
      if (mounted) {
        CustomToast.show(context, '${isBusiness ? "Business" : "Personal"} chat history cleared ($formattedSize freed)');
      }
    }
  }

  void _openLanguagePickerSheet(
    BuildContext context,
    AiConfigService aiService,
    VoidCallback onUpdated,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E2430) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF212121);
        final primaryColor = Theme.of(context).primaryColor;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.translate_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select AI Language',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'AI responses will automatically be in this language',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.8),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _languageOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) {
                    final opt = _languageOptions[idx];
                    final code = opt['code']!;
                    final label = opt['label']!;
                    final native = opt['native']!;
                    final isSelected = aiService.responseLanguage.toLowerCase() == code.toLowerCase();

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          aiService.setResponseLanguage(code);
                          onUpdated();
                          Navigator.pop(sheetCtx);
                          CustomToast.show(context, 'Language set to $label ($native)');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withOpacity(0.1)
                                : (isDark ? const Color(0xFF272F3E) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                              width: isSelected ? 1.6 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor.withOpacity(0.2)
                                      : (isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.language_rounded,
                                  size: 18,
                                  color: isSelected ? primaryColor : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: isSelected ? primaryColor : textColor,
                                      ),
                                    ),
                                    Text(
                                      native,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: isSelected ? primaryColor.withOpacity(0.8) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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

                    Builder(
                      builder: (_) {
                        final currentLangCode = aiService.responseLanguage;
                        final currentLangOption = _languageOptions.firstWhere(
                          (opt) => opt['code']?.toLowerCase() == currentLangCode.toLowerCase(),
                          orElse: () => {'code': currentLangCode, 'label': currentLangCode, 'native': currentLangCode},
                        );

                        return InkWell(
                          onTap: () {
                            _openLanguagePickerSheet(context, aiService, () {
                              setModalState(() {});
                              setState(() {});
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.translate_rounded, size: 18, color: primaryColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentLangOption['label'] ?? currentLangCode,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        currentLangOption['native'] ?? '',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_right_rounded, color: primaryColor, size: 22),
                              ],
                            ),
                          ),
                        );
                      },
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
                      future: DatabaseHelper.instance.getAiChatStats(
                        mode: Provider.of<UserProvider>(context, listen: false).isBusinessMode ? 'business' : 'personal',
                      ),
                      builder: (context, snapshot) {
                        final sizeStr = snapshot.data?['formattedSize'] ?? '0 KB';
                        final count = snapshot.data?['count'] ?? 0;
                        final isBiz = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
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
                                      isBiz ? 'Clear Business Chat History' : 'Clear Personal Chat History',
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

  Widget _buildHistoryDrawer(BuildContext context, bool isDark, Color primaryColor) {
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    final grouped = _groupSessionsByTimeline(_sessions);
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF14171F) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1F2633) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isBusiness
                                ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                                : [const Color(0xFF00D09C), const Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isBusiness ? Icons.insights_rounded : Icons.psychology_alt_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBusiness ? 'Business AI History' : 'Grow Expense AI History',
                              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_sessions.length} saved conversations',
                              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close History',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // "➕ New Chat" Button
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      _startNewChat();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.15),
                            primaryColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isBusiness ? 'New Business Chat' : 'New Chat',
                            style: GoogleFonts.outfit(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sessions List
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isBusiness ? Icons.insights_rounded : Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: isDark ? const Color(0xFF2E384D) : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isBusiness ? 'No Business Chat History Yet' : 'No Chat History Yet',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isBusiness
                                  ? 'Ask Business AI CFO any question about sales, GST, khata or profits!'
                                  : 'Ask Grow Expense AI any expense question to start your first conversation!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      children: [
                        for (final entry in grouped.entries)
                          if (entry.value.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                              child: Text(
                                entry.key.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: primaryColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            for (final session in entry.value)
                              _buildSessionTile(session, isDark, primaryColor),
                          ],
                      ],
                    ),
            ),

            // Drawer Bottom Actions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1F2633) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _confirmClearChat();
                      },
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                      label: Text(
                        isBusiness ? 'Clear Business AI History' : 'Clear All History',
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> session, bool isDark, Color primaryColor) {
    final id = session['id']?.toString() ?? '';
    final title = session['title']?.toString() ?? 'Conversation';
    final msgCount = session['message_count'] as int? ?? 0;
    final isActive = (id == _currentSessionId);
    final dateStr = session['updated_at']?.toString() ?? session['created_at']?.toString() ?? '';
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
    final timeFormatted = _formatSessionTime(dt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? primaryColor.withValues(alpha: 0.12)
            : (isDark ? const Color(0xFF1A1F2B) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isActive ? primaryColor : Colors.transparent,
            width: 3.5,
          ),
          top: BorderSide(
            color: isActive
                ? primaryColor.withValues(alpha: 0.3)
                : (isDark ? const Color(0xFF262C3D) : const Color(0xFFE2E8F0)),
          ),
          right: BorderSide(
            color: isActive
                ? primaryColor.withValues(alpha: 0.3)
                : (isDark ? const Color(0xFF262C3D) : const Color(0xFFE2E8F0)),
          ),
          bottom: BorderSide(
            color: isActive
                ? primaryColor.withValues(alpha: 0.3)
                : (isDark ? const Color(0xFF262C3D) : const Color(0xFFE2E8F0)),
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        dense: true,
        leading: Icon(
          isActive ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
          color: isActive ? primaryColor : Colors.grey,
          size: 18,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 13.5,
            color: isActive ? (isDark ? Colors.white : primaryColor) : null,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              timeFormatted,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
            if (msgCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                '• $msgCount msgs',
                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ],
        ),
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          if (!isActive) {
            _switchSession(id, title);
          }
        },
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (val) {
            if (val == 'rename') {
              _showRenameSessionDialog(id, title);
            } else if (val == 'delete') {
              _confirmDeleteSession(id, title);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text('Rename', style: GoogleFonts.inter(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text('Delete', style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final isBusiness = userProvider.isBusinessMode;
    final primaryColor = isBusiness ? const Color(0xFF3B82F6) : Theme.of(context).primaryColor;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildHistoryDrawer(context, isDark, primaryColor),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Conversations History',
        ),
        title: GestureDetector(
          onTap: _currentSessionId != null
              ? () => _showRenameSessionDialog(_currentSessionId!, _currentSessionTitle)
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isBusiness ? Icons.insights_rounded : Icons.psychology_alt_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _currentSessionTitle,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_currentSessionId != null) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                        ],
                      ],
                    ),
                    Text(
                      isBusiness ? '🏢 Business AI CFO & Tax Advisor' : 'Live Expense Intelligence',
                      style: GoogleFonts.inter(fontSize: 10.5, color: isBusiness ? primaryColor : Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
          ),
          IconButton(
            onPressed: _openChatSettingsModal,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Chat Settings & Language',
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
                          'Grow Expense AI is analyzing your expenses...',
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

        case 'ADD_BUSINESS_SALE':
          final custName = proposal.data['customerName']?.toString() ?? 'Customer';
          final totalAmt = double.tryParse(proposal.data['totalAmount']?.toString() ?? '0') ?? 0.0;
          final payMode = proposal.data['paymentMode']?.toString() ?? 'Cash';
          final payStatus = proposal.data['paymentStatus']?.toString() ?? 'paid';
          final notes = proposal.data['notes']?.toString();
          final paidAmt = payStatus == 'paid' ? totalAmt : (payStatus == 'unpaid' ? 0.0 : (totalAmt * 0.5));
          final balDue = (totalAmt - paidAmt).clamp(0.0, double.infinity);
          final saleId = 'sale_${DateTime.now().millisecondsSinceEpoch}';
          final invNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

          final sale = BusinessSale(
            id: saleId,
            customerName: custName,
            totalAmount: totalAmt,
            taxAmount: 0.0,
            discountAmount: 0.0,
            finalAmount: totalAmt,
            paidAmount: paidAmt,
            balanceDue: balDue,
            paymentMode: payMode,
            paymentStatus: payStatus,
            saleDate: DateTime.now(),
            invoiceNo: invNo,
            notes: notes,
            items: [
              BusinessSaleItem(
                id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                saleId: saleId,
                itemName: notes != null && notes.isNotEmpty ? notes : 'General Sale Item',
                quantity: 1.0,
                unitPrice: totalAmt,
                totalPrice: totalAmt,
                taxRate: 0.0,
              ),
            ],
          );
          await DatabaseHelper.instance.insertBusinessSale(sale);
          if (balDue > 0 && custName.isNotEmpty && custName != 'Walk-in Customer') {
            try {
              final khataEntry = KhataEntry(
                id: 'khata_${DateTime.now().millisecondsSinceEpoch}',
                personName: custName,
                amount: balDue,
                type: 'lent',
                entryDate: DateTime.now(),
                note: 'Sale Inv #$invNo: Due ₹${balDue.toStringAsFixed(0)}',
                isSettled: false,
                ledgerType: 'business',
              );
              await DatabaseHelper.instance.insertKhataEntry(khataEntry);
            } catch (_) {}
          }
          if (mounted) {
            CustomToast.show(context, 'Sale #$invNo (₹${totalAmt.toStringAsFixed(0)}) recorded in Business Store! 🏢');
          }
          break;

        case 'ADD_BUSINESS_EXPENSE':
          final amount = double.tryParse(proposal.data['amount']?.toString() ?? '0') ?? 0.0;
          final category = proposal.data['category']?.toString() ?? 'Stock Purchase';
          final description = proposal.data['description']?.toString() ?? category;

          await expenseProvider.addExpense(
            amount: amount,
            category: category,
            description: description,
            date: DateTime.now(),
            currency: 'INR',
            ledgerType: 'business',
          );
          if (mounted) {
            CustomToast.show(context, 'Business Expense ₹${amount.toStringAsFixed(0)} ($category) recorded! 🏢');
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

      // Localized follow-up guidance message after execution
      final lang = AiConfigService.instance.responseLanguage;
      final followUpText = _localizedActionExecutionFollowUps[lang] ?? _localizedActionExecutionFollowUps['English']!;
      final followUpMsg = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_followup',
        text: followUpText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(followUpMsg);
      });
      await DatabaseHelper.instance.insertAiChatMessage(
        id: followUpMsg.id,
        sessionId: _currentSessionId,
        text: followUpMsg.toRawText(),
        isUser: false,
        timestamp: followUpMsg.timestamp,
      );
      _scrollToBottom();
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
      case 'ADD_BUSINESS_SALE':
        actionIcon = Icons.point_of_sale_rounded;
        actionColor = const Color(0xFF3B82F6);
        badgeText = 'BUSINESS SALE';
        final amt = double.tryParse(proposal.data['totalAmount']?.toString() ?? '0') ?? 0.0;
        final cust = proposal.data['customerName']?.toString() ?? 'Customer';
        actionTitle = 'Record Sale • ₹${amt.toStringAsFixed(0)} ($cust)';
        break;
      case 'ADD_BUSINESS_EXPENSE':
        actionIcon = Icons.storefront_rounded;
        actionColor = const Color(0xFFEC4899);
        badgeText = 'BUSINESS EXPENSE';
        final amt = double.tryParse(proposal.data['amount']?.toString() ?? '0') ?? 0.0;
        final cat = proposal.data['category']?.toString() ?? 'Expense';
        actionTitle = 'Record Expense • ₹${amt.toStringAsFixed(0)} ($cat)';
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
                    final lang = AiConfigService.instance.responseLanguage;
                    final dismissText = _localizedActionDismissFollowUps[lang] ?? _localizedActionDismissFollowUps['English']!;
                    final dismissMsg = ChatMessage(
                      id: '${DateTime.now().millisecondsSinceEpoch}_dismiss',
                      text: dismissText,
                      isUser: false,
                      timestamp: DateTime.now(),
                    );
                    setState(() {
                      _messages.add(dismissMsg);
                    });
                    await DatabaseHelper.instance.insertAiChatMessage(
                      id: dismissMsg.id,
                      sessionId: _currentSessionId,
                      text: dismissMsg.toRawText(),
                      isUser: false,
                      timestamp: dismissMsg.timestamp,
                    );
                    _scrollToBottom();
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

      case 'ADD_BUSINESS_SALE':
        final cust = data['customerName']?.toString() ?? 'Customer';
        final payMode = data['paymentMode']?.toString() ?? 'Cash';
        final payStatus = data['paymentStatus']?.toString() ?? 'paid';
        final notes = data['notes']?.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Customer: $cust', style: textStyle),
            Text('• Payment: $payMode ($payStatus)', style: textStyle),
            if (notes != null && notes.isNotEmpty) Text('• Item / Notes: $notes', style: textStyle),
          ],
        );

      case 'ADD_BUSINESS_EXPENSE':
        final cat = data['category']?.toString() ?? 'Stock Purchase';
        final desc = data['description']?.toString() ?? cat;
        final payMethod = data['paymentMethod']?.toString() ?? 'Cash';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Category: $cat', style: textStyle),
            Text('• Payment Method: $payMethod', style: textStyle),
            if (desc != cat && desc.isNotEmpty) Text('• Details: $desc', style: textStyle),
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
