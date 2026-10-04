import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_config_service.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import '../services/database_helper.dart';
import '../models/business_sale.dart';
import '../models/khata_entry.dart';
import '../screens/expense_entry_screen.dart';
import '../screens/add_business_sale_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_toast.dart';
import 'ai_config_required_dialog.dart';

class VoiceExpenseDialog extends StatefulWidget {
  const VoiceExpenseDialog({super.key});

  static Future<void> show(BuildContext context) async {
    if (!checkAndPromptAiConfig(context)) {
      return;
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const VoiceExpenseDialog(),
    );
  }

  @override
  State<VoiceExpenseDialog> createState() => _VoiceExpenseDialogState();
}

class _VoiceExpenseDialogState extends State<VoiceExpenseDialog>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcribedText = '';
  String? _statusMessage = 'Tap mic and speak in any language';
  Map<String, dynamic>? _extractedData;
  Timer? _silenceTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, String>> _supportedLanguages = const [
    {'code': 'hi_IN', 'name': 'Hindi', 'native': 'हिंदी', 'flag': '🇮🇳'},
    {'code': 'bn_IN', 'name': 'Bengali', 'native': 'বাংলা', 'flag': '🇮🇳'},
    {'code': 'en_IN', 'name': 'English / Hinglish', 'native': 'English', 'flag': '🇮🇳'},
    {'code': 'gu_IN', 'name': 'Gujarati', 'native': 'ગુજરાતી', 'flag': '🇮🇳'},
    {'code': 'mr_IN', 'name': 'Marathi', 'native': 'मराठी', 'flag': '🇮🇳'},
    {'code': 'ta_IN', 'name': 'Tamil', 'native': 'தமிழ்', 'flag': '🇮🇳'},
    {'code': 'te_IN', 'name': 'Telugu', 'native': 'తెలుగు', 'flag': '🇮🇳'},
    {'code': 'kn_IN', 'name': 'Kannada', 'native': 'ಕನ್ನಡ', 'flag': '🇮🇳'},
    {'code': 'pa_IN', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ', 'flag': '🇮🇳'},
    {'code': 'ur_IN', 'name': 'Urdu', 'native': 'اردو', 'flag': '🇮🇳'},
  ];
  String _selectedLocale = 'hi_IN';

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-start listening after bottom sheet appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('preferred_voice_stt_locale');
      if (saved != null && mounted) {
        setState(() {
          _selectedLocale = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _changeLocale(String newLocale) async {
    if (_selectedLocale == newLocale) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLocale = newLocale;
      _transcribedText = '';
      _statusMessage = 'Listening in ${_getLanguageName(newLocale)}... Speak now';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preferred_voice_stt_locale', newLocale);
    } catch (_) {}

    if (_isListening) {
      _silenceTimer?.cancel();
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _startListening();
    }
  }

  String _getLanguageName(String code) {
    final found = _supportedLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => {'name': 'selected language'},
    );
    return found['name'] ?? 'selected language';
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted && _isListening && _transcribedText.trim().isNotEmpty) {
        debugPrint('[VoiceExpense] Silence detected after speech. Auto-processing: $_transcribedText');
        _stopListeningAndProcess();
      }
    });
  }

  Future<void> _startListening() async {
    _silenceTimer?.cancel();
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[VoiceExpense] STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() {
                _isListening = false;
              });
              if (_transcribedText.trim().isNotEmpty && _extractedData == null && !_isProcessing) {
                _processVoiceInput(_transcribedText);
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('[VoiceExpense] STT Error: ${errorNotification.errorMsg}');
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Speech error: ${errorNotification.errorMsg}';
            });
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _statusMessage = 'Listening in ${_getLanguageName(_selectedLocale)}... Speak now';
          _transcribedText = '';
          _extractedData = null;
        });
        HapticFeedback.mediumImpact();

        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _transcribedText = result.recognizedWords;
              });

              if (result.finalResult && _transcribedText.trim().isNotEmpty) {
                _stopListeningAndProcess();
              } else if (_transcribedText.trim().isNotEmpty) {
                // Smart auto-detection: Wait for 2.2s of silence before auto-analyzing
                _resetSilenceTimer();
              }
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            cancelOnError: true,
            partialResults: true,
            listenFor: const Duration(seconds: 40),
            pauseFor: const Duration(seconds: 4),
            localeId: _selectedLocale,
          ),
        );
      } else {
        setState(() {
          _statusMessage = 'Microphone permission denied or speech recognition unavailable.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize mic: $e';
      });
    }
  }

  Future<void> _stopListeningAndProcess() async {
    _silenceTimer?.cancel();
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }

    if (_transcribedText.trim().isNotEmpty) {
      _processVoiceInput(_transcribedText);
    } else {
      setState(() {
        _statusMessage = 'No speech detected. Tap mic to try again.';
      });
    }
  }

  Future<void> _processVoiceInput(String text) async {
    if (text.trim().isEmpty) return;

    final isBusinessMode = Provider.of<UserProvider>(context, listen: false).isBusinessMode;

    _silenceTimer?.cancel();
    setState(() {
      _isProcessing = true;
      _statusMessage = isBusinessMode
          ? 'AI analyzing sale / expense & items...'
          : 'AI is analyzing & standardizing to English...';
    });

    final aiService = AiConfigService.instance;
    final result = await aiService.parseExpenseFromNaturalText(text, isBusinessMode: isBusinessMode);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      setState(() {
        _extractedData = data;
        final entryType = data['entry_type']?.toString().toLowerCase();
        if (entryType == 'sale') {
          _statusMessage = 'Customer sale & items detected!';
        } else {
          _statusMessage = 'Expense parsed & standardized!';
        }
      });
      HapticFeedback.lightImpact();
    } else {
      final errorMsg = result['error']?.toString() ?? 'Could not parse input. Please try again.';
      setState(() {
        _statusMessage = errorMsg;
      });
      if (aiService.isServerBusyError(errorMsg)) {
        showAiServerBusyDialog(context, onRetry: () => _processVoiceInput(text));
      } else {
        CustomToast.show(
          context,
          errorMsg,
          isError: true,
        );
      }
    }
  }

  void _saveExpenseDirectly() async {
    if (_extractedData == null) return;
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    final data = _extractedData!;
    final entryType = data['entry_type']?.toString().toLowerCase() ?? 'expense';

    if (isBusiness && entryType == 'sale') {
      await _saveBusinessSaleDirectly();
      return;
    }

    final double amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
    final String category = data['category']?.toString() ?? (isBusiness ? 'Stock / Inventory' : 'Miscellaneous');
    final String description = (data['description'] != null && data['description'].toString().trim().isNotEmpty)
        ? data['description'].toString().trim()
        : ((data['vendor'] != null && data['vendor'].toString().trim().isNotEmpty)
            ? data['vendor'].toString().trim()
            : category);
    final String currency = data['currency']?.toString() ?? 'INR';
    final String paymentMethod = data['payment_method']?.toString() ?? 'UPI';

    DateTime date = DateTime.now();
    if (data['transaction_date'] != null) {
      try {
        date = DateTime.parse(data['transaction_date'].toString());
      } catch (_) {}
    }

    if (amount <= 0) {
      CustomToast.show(context, 'Invalid amount detected.', isError: true);
      return;
    }

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    await expenseProvider.addExpense(
      amount: amount,
      category: category,
      description: description,
      date: date,
      currency: currency,
      ledgerType: isBusiness ? 'business' : 'personal',
    );

    if (mounted) {
      Navigator.of(context).pop();
      CustomToast.show(
        context,
        'Saved ₹${amount.toStringAsFixed(2)} for $category ($paymentMethod)',
      );
    }
  }

  Future<void> _saveBusinessSaleDirectly() async {
    final data = _extractedData!;
    final double totalAmount = (data['total_amount'] is num)
        ? (data['total_amount'] as num).toDouble()
        : ((data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0);
    final double paidAmount = (data['paid_amount'] is num)
        ? (data['paid_amount'] as num).toDouble()
        : totalAmount;
    final double dueAmount = (totalAmount - paidAmount).clamp(0.0, totalAmount);
    final String customerName = (data['customer_name'] != null && data['customer_name'].toString().trim().isNotEmpty)
        ? data['customer_name'].toString().trim()
        : 'Walk-in Customer';
    final String customerPhone = data['customer_phone']?.toString().trim() ?? '';
    final String paymentMode = data['payment_mode']?.toString() ?? 'Cash';
    final String paymentStatus = dueAmount <= 0 ? 'Paid' : (paidAmount > 0 ? 'Partial' : 'Unpaid');
    final String notes = data['notes']?.toString() ?? '';

    final rawItems = data['items'] as List<dynamic>? ?? [];
    final List<BusinessSaleItem> saleItems = [];
    final saleId = 'bs_${DateTime.now().millisecondsSinceEpoch}';

    if (rawItems.isNotEmpty) {
      for (int i = 0; i < rawItems.length; i++) {
        final m = rawItems[i] as Map<String, dynamic>;
        final qty = (m['quantity'] is num) ? (m['quantity'] as num).toDouble() : 1.0;
        final up = (m['unit_price'] is num)
            ? (m['unit_price'] as num).toDouble()
            : ((m['price'] is num) ? (m['price'] as num).toDouble() : 0.0);
        final cp = (m['purchase_price'] is num) ? (m['purchase_price'] as num).toDouble() : null;
        final tr = (m['tax_rate'] is num) ? (m['tax_rate'] as num).toDouble() : 0.0;
        final u = m['unit']?.toString() ?? 'pcs';
        final name = m['item_name']?.toString() ?? m['name']?.toString() ?? 'Item';
        saleItems.add(BusinessSaleItem(
          id: '${saleId}_it_$i',
          saleId: saleId,
          itemName: name,
          quantity: qty,
          unitPrice: up,
          unit: u,
          purchasePrice: cp,
          taxRate: tr,
          totalPrice: qty * up,
        ));
      }
    } else {
      saleItems.add(BusinessSaleItem(
        id: '${saleId}_it_0',
        saleId: saleId,
        itemName: 'General Sale',
        quantity: 1,
        unitPrice: totalAmount,
        unit: 'pcs',
        totalPrice: totalAmount,
      ));
    }

    final autoInvNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final newSale = BusinessSale(
      id: saleId,
      invoiceNo: autoInvNo,
      customerName: customerName,
      customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
      saleDate: DateTime.now(),
      items: saleItems,
      totalAmount: totalAmount,
      finalAmount: totalAmount,
      paidAmount: paidAmount,
      balanceDue: dueAmount,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      notes: notes.isNotEmpty ? notes : null,
    );

    try {
      await DatabaseHelper.instance.insertBusinessSale(newSale);

      // If udhar / due amount exists, record in Khata automatically
      if (dueAmount > 0 && customerName.isNotEmpty && customerName != 'Walk-in Customer') {
        final khata = KhataEntry(
          id: 'khata_${DateTime.now().millisecondsSinceEpoch}',
          personName: customerName,
          phoneNumber: customerPhone.isNotEmpty ? customerPhone : null,
          amount: dueAmount,
          type: 'lent',
          entryDate: DateTime.now(),
          note: 'Sale Bill #$autoInvNo (${saleItems.map((e) => "${e.itemName} x${e.quantity}").join(", ")})',
          ledgerType: 'business',
          isSettled: false,
        );
        await DatabaseHelper.instance.insertKhataEntry(khata);
      }

      if (mounted) {
        final expProvider = Provider.of<ExpenseProvider>(context, listen: false);
        if (saleItems.isNotEmpty) {
          await expProvider.deductStockForSale(saleItems.map((e) => e.toMap()).toList());
        }
        await expProvider.loadLocalData();
        expProvider.triggerQuietSync();
        if (mounted) {
          Navigator.of(context).pop();
          CustomToast.show(
            context,
            'Sale recorded: ₹${totalAmount.toStringAsFixed(0)} (Bill #$autoInvNo)',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to save sale: $e', isError: true);
      }
    }
  }

  void _editInForm() {
    if (_extractedData == null) return;
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    final data = _extractedData!;
    final entryType = data['entry_type']?.toString().toLowerCase() ?? 'expense';

    if (isBusiness && entryType == 'sale') {
      final double totalAmount = (data['total_amount'] is num)
          ? (data['total_amount'] as num).toDouble()
          : ((data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0);
      final double paidAmount = (data['paid_amount'] is num)
          ? (data['paid_amount'] as num).toDouble()
          : totalAmount;
      final String customerName = (data['customer_name'] != null && data['customer_name'].toString().trim().isNotEmpty)
          ? data['customer_name'].toString().trim()
          : 'Walk-in Customer';
      final String customerPhone = data['customer_phone']?.toString().trim() ?? '';
      final String paymentMode = data['payment_mode']?.toString() ?? 'Cash';
      final String paymentStatus = (totalAmount - paidAmount) <= 0 ? 'Paid' : (paidAmount > 0 ? 'Partial' : 'Unpaid');
      final String notes = data['notes']?.toString() ?? '';
      final rawItems = (data['items'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddBusinessSaleScreen(
            initialCustomerName: customerName,
            initialCustomerPhone: customerPhone.isNotEmpty ? customerPhone : null,
            initialPaidAmount: paidAmount,
            initialPaymentMode: paymentMode,
            initialPaymentStatus: paymentStatus,
            initialNotes: notes,
            initialItemData: rawItems,
          ),
        ),
      );
      return;
    }

    final double amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
    final String category = data['category']?.toString() ?? (isBusiness ? 'Stock / Inventory' : 'Miscellaneous');
    final String description = (data['description'] != null && data['description'].toString().trim().isNotEmpty)
        ? data['description'].toString().trim()
        : ((data['vendor'] != null && data['vendor'].toString().trim().isNotEmpty)
            ? data['vendor'].toString().trim()
            : '');
    final String currency = data['currency']?.toString() ?? 'INR';

    DateTime date = DateTime.now();
    if (data['transaction_date'] != null) {
      try {
        date = DateTime.parse(data['transaction_date'].toString());
      } catch (_) {}
    }

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(
          initialAmount: amount > 0 ? amount : null,
          initialCategory: category,
          initialDescription: description,
          initialDate: date,
          initialCurrency: currency,
          initialLedgerType: isBusiness ? 'business' : 'personal',
        ),
      ),
    );
  }

  void _openOcrScanner() {
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(
          openCameraScanner: true,
          initialLedgerType: isBusiness ? 'business' : 'personal',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isBusiness = Provider.of<UserProvider>(context).isBusinessMode;

    final headerTitle = isBusiness ? 'AI Voice Sale & Expense' : 'AI Voice Expense Logger';
    final headerSubtitle = isBusiness
        ? 'Speak customer sale, udhar or business expense'
        : 'Powered by AI Multilingual NLP';

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isBusiness ? const Color(0xFF2563EB) : primaryColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isBusiness ? Icons.storefront_rounded : Icons.mic_none_rounded,
                    color: isBusiness ? const Color(0xFF38BDF8) : primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        headerSubtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick Camera OCR button
                IconButton(
                  tooltip: 'Smart OCR Scanner',
                  onPressed: _openOcrScanner,
                  icon: const Icon(Icons.document_scanner_rounded, size: 20),
                  color: const Color(0xFF38BDF8),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Main Interactive Area
            if (_extractedData == null) ...[
              // Voice Speech Language Selector Bar
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _supportedLanguages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final lang = _supportedLanguages[index];
                    final isSelected = lang['code'] == _selectedLocale;
                    final activeColor = isBusiness ? const Color(0xFF38BDF8) : primaryColor;
                    return ChoiceChip(
                      label: Text('${lang['flag']} ${lang['native']} (${lang['name']})'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) _changeLocale(lang['code']!);
                      },
                      selectedColor: activeColor.withValues(alpha: 0.2),
                      backgroundColor: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? activeColor : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                      side: BorderSide(
                        color: isSelected ? activeColor : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Waveform / Pulsing Mic Area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B202B) : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isListening
                        ? (isBusiness ? const Color(0xFF38BDF8) : primaryColor).withValues(alpha: 0.5)
                        : isDark ? const Color(0xFF262E3D) : const Color(0xFFE5E9F0),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_isListening) {
                          _stopListeningAndProcess();
                        } else {
                          _startListening();
                        }
                      },
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _isListening
                                      ? [const Color(0xFF00D09C), const Color(0xFF00A37A)]
                                      : (isBusiness
                                          ? [const Color(0xFF2563EB), const Color(0xFF0284C7)]
                                          : [const Color(0xFF6C63FF), const Color(0xFF4B44C9)]),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isListening
                                            ? const Color(0xFF00D09C)
                                            : (isBusiness ? const Color(0xFF2563EB) : const Color(0xFF6C63FF)))
                                        .withValues(alpha: 0.35),
                                    blurRadius: _isListening ? 20 : 10,
                                    spreadRadius: _isListening ? 4 : 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isListening
                            ? (isBusiness ? const Color(0xFF38BDF8) : primaryColor)
                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isProcessing) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: isBusiness ? const Color(0xFF38BDF8) : primaryColor,
                        ),
                      ),
                    ],
                    if (_transcribedText.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF14171E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          '"$_transcribedText"',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (_isListening && _transcribedText.isNotEmpty && !_isProcessing) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _stopListeningAndProcess,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: (isBusiness ? const Color(0xFF38BDF8) : primaryColor).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: (isBusiness ? const Color(0xFF38BDF8) : primaryColor).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 16, color: isBusiness ? const Color(0xFF38BDF8) : primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                'Finish & Analyze Now ⚡',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isBusiness ? const Color(0xFF38BDF8) : primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Spoken Examples
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _getSpeakingPromptTitle(_selectedLocale),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: _getExamplesForLocale(_selectedLocale, isBusiness).map((ex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildExampleCard(ex, isDark, isBusiness),
                  );
                }).toList(),
              ),
            ] else ...[
              // Extracted Confirmation Card
              _buildExtractedConfirmationCard(isDark, primaryColor, isBusiness),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedConfirmationCard(bool isDark, Color primaryColor, bool isBusiness) {
    final data = _extractedData!;
    final entryType = data['entry_type']?.toString().toLowerCase() ?? 'expense';
    final isSale = isBusiness && entryType == 'sale';

    if (isSale) {
      final double totalAmount = (data['total_amount'] is num)
          ? (data['total_amount'] as num).toDouble()
          : ((data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0);
      final double paidAmount = (data['paid_amount'] is num)
          ? (data['paid_amount'] as num).toDouble()
          : totalAmount;
      final double dueAmount = (totalAmount - paidAmount).clamp(0.0, totalAmount);
      final customerName = (data['customer_name'] != null && data['customer_name'].toString().trim().isNotEmpty)
          ? data['customer_name'].toString().trim()
          : 'Walk-in Customer';
      final rawItems = data['items'] as List<dynamic>? ?? [];

      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B202B) : const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00D09C).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🛒 Customer Sale Bill',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00D09C),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (dueAmount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF00D09C)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dueAmount > 0 ? 'Udhar: ₹${dueAmount.toStringAsFixed(0)}' : 'Fully Paid',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: dueAmount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF00D09C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Customer: $customerName',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                if (rawItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    'Items Detected (${rawItems.length}):',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  ...rawItems.take(4).map((it) {
                    final m = it as Map<String, dynamic>;
                    final n = m['item_name'] ?? m['name'] ?? 'Item';
                    final q = m['quantity'] ?? 1;
                    final u = m['unit'] ?? 'pcs';
                    final p = m['unit_price'] ?? m['price'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• $n ($q $u)', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.black87)),
                          Text('₹$p', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF00D09C))),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _editInForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Open in Invoice',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveExpenseDirectly,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D09C),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Bill ⚡',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Standard Expense Confirmation Card
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B202B) : const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data['category'] ?? (isBusiness ? 'Stock / Inventory' : 'Miscellaneous'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data['payment_method'] ?? 'UPI',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[400],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '₹${(data['amount'] ?? 0.0).toString()}',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data['description'] ?? (isBusiness ? 'Business Expense' : 'Voice Expense'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              if (data['vendor'] != null && data['vendor'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Payee: ${data['vendor']}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _editInForm,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Edit in Form',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveExpenseDirectly,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Quick Save ⚡',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getSpeakingPromptTitle(String code) {
    switch (code) {
      case 'bn_IN':
        return 'বাংলায় বলুন (Try speaking in Bengali):';
      case 'hi_IN':
        return 'हिंदी में बोलिए (Try speaking in Hindi):';
      case 'gu_IN':
        return 'ગુજરાતીમાં બોલો (Try speaking in Gujarati):';
      case 'mr_IN':
        return 'मराठीत बोला (Try speaking in Marathi):';
      case 'ta_IN':
        return 'தமிழில் பேசுங்கள் (Try speaking in Tamil):';
      case 'te_IN':
        return 'తెలుగులో మాట్లాడండి (Try speaking in Telugu):';
      case 'kn_IN':
        return 'ಕನ್ನಡದಲ್ಲಿ ಮಾತನಾಡಿ (Try speaking in Kannada):';
      case 'pa_IN':
        return 'ਪੰਜਾਬੀ ਵਿੱਚ ਬੋਲੋ (Try speaking in Punjabi):';
      case 'ur_IN':
        return 'اردو میں بولیں (Try speaking in Urdu):';
      case 'en_IN':
      default:
        return 'Try speaking in English / Hinglish:';
    }
  }

  List<Map<String, dynamic>> _getExamplesForLocale(String locale, bool isBusiness) {
    if (isBusiness) {
      if (locale.startsWith('bn')) {
        return [
          {
            'tag': '🛒 কাস্টমার সেল ও খাতা বাকি বিল',
            'text': '“রতন বাবুকে ২৫ কেজি চাল ৫০০ টাকা আর ২ কেজি চিনি ৯০ টাকায় বিক্রি করলাম, ৫০০ টাকা ক্যাশ দিল আর ৯০ টাকা খাতা বাকি রইল”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 পাইকারি স্টক মাল ও ইউপিআই পেমেন্ট',
            'text': '“শ্যাম ট্রেডার্স থেকে ১২০০০ টাকার নতুন স্টক মাল কিনলাম আর গুগলপে ইউপিআই দিয়ে পেমেন্ট করলাম”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('hi')) {
        return [
          {
            'tag': '🛒 कस्टमर सेल व खाता बाकी बिल',
            'text': '“राजू भाई को 25 किलो चावल 500 रुपये और 2 किलो चीनी 90 रुपये में बेची, 500 ऑनलाइन मिला और 90 रुपये खाता बाकी रहा”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 सप्लायर से नया स्टॉक व UPI भुगतान',
            'text': '“श्याम ट्रेडर्स से 12000 रुपये का दुकान का नया स्टॉक माल खरीदा और बैंक UPI से पेमेंट किया”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('gu')) {
        return [
          {
            'tag': '🛒 ગ્રાહક વેચાણ અને ખાતા બાકી બિલ',
            'text': '“રમેશભાઈને ૨૫ કિલો ચોખા ૫૦૦ અને ૨ કિલો ખાંડ ૯૦ માં વેચી, ૫૦૦ રોકડા મળ્યા અને ૯૦ રૂપિયા ખાતા બાકી રાખ્યા”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 સપ્લાયર સ્ટોક ખરીદી અને UPI પેમેન્ટ',
            'text': '“શ્યામ ટ્રેડર્સ પાસેથી ૧૨૦૦૦ રૂપિયાનો દુકાનનો સ્ટોક ખરીદ્યો અને યુપીઆઈ દ્વારા ચૂકવણી કરી”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('mr')) {
        return [
          {
            'tag': '🛒 ग्राहक विक्री आणि उधारी बिल',
            'text': '“सुरेश भाऊंना २५ किलो तांदूळ ५०० आणि २ किलो साखर ९० रुपयांत विकली, ५०० रोख दिले आणि ९० रुपये उधारी बाकी ठेवली”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 सप्लायर स्टॉक खरेदी आणि ऑनलाइन पेमेंट',
            'text': '“श्याम ट्रेडर्स कडून १२,००० रुपयांचा नवीन माल खरेदी केला आणि गुगलपे UPI ने पेमेंट केले”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('ta')) {
        return [
          {
            'tag': '🛒 வாடிக்கையாளர் விற்பனை & கடன் பில்',
            'text': '“ரமேஷுக்கு 25 கிலோ அரிசி 500 மற்றும் 2 கிலோ சர்க்கரை 90 ரூபாய்க்கு விற்றேன், 500 ரொக்கம் கொடுத்தார் 90 ரூபாய் கடன் பாக்கி”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 சப்ளையர் சரக்கு கொள்முதல் & UPI',
            'text': '“சியாம் டிரேடர்ஸிடம் இருந்து 12000 ரூபாய்க்கு சரக்கு வாங்கி கூகுள்பே UPI மூலம் செலுத்தினேன்”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('te')) {
        return [
          {
            'tag': '🛒 కస్టమర్ సేల్ & ఖాతా బాకీ బిల్లు',
            'text': '“రాజుకి 25 కేజీల బియ్యం 500 మరియు 2 కేజీల చక్కెర 90 కి అమ్మాను, 500 ఆన్‌లైన్ ఇచ్చారు 90 రూపాయలు ఖాతా బాకీ పెట్టారు”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 సప్లయర్ స్టాక్ కొనుగోలు & UPI',
            'text': '“శ్యామ్ ట్రేడర్స్ నుండి 12000 రూపాయల కొత్త స్టాక్ కొని బ్యాంక్ యూపీఐ ద్వారా చెల్లించాను”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('kn')) {
        return [
          {
            'tag': '🛒 ಗ್ರಾಹಕರ ಮಾರಾಟ & ಖಾತಾ ಬಾಕಿ ಬಿಲ್',
            'text': '“ರಮೇಶ್‌ಗೆ 25 ಕೆಜಿ ಅಕ್ಕಿ 500 ಮತ್ತು 2 ಕೆಜಿ ಸಕ್ಕರೆ 90 ಕ್ಕೆ ಮಾರಾಟ ಮಾಡಿದೆ, 500 ನಗದು ಕೊಟ್ಟರು 90 ರೂಪಾಯಿ ಖಾತಾ ಬಾಕಿ ಉಳಿದಿದೆ”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 ಪೂರೈಕೆದಾರರ ಸ್ಟಾಕ್ ಖರೀದಿ & UPI',
            'text': '“ಶ್ಯಾಮ್ ಟ್ರೇಡರ್ಸ್‌ನಿಂದ 12000 ರೂಪಾಯಿ ಹೊಸ ಸ್ಟಾಕ್ ಖರೀದಿಸಿ ಗೂಗಲ್‌ಪೇ ಯುಪಿಐ ಮೂಲಕ ಪಾವತಿಸಿದೆ”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('pa')) {
        return [
          {
            'tag': '🛒 ਗਾਹਕ ਵਿਕਰੀ ਤੇ ਖਾਤਾ ਬਾਕੀ ਬਿੱਲ',
            'text': '“ਰਾਜੂ ਨੂੰ 25 ਕਿੱਲੋ ਚੌਲ 500 ਅਤੇ 2 ਕਿੱਲੋ ਖੰਡ 90 ਰੁਪਏ ਵਿੱਚ ਵੇਚੀ, 500 ਨਕਦ ਦਿੱਤਾ ਤੇ 90 ਰੁਪਏ ਖਾਤਾ ਬਾਕੀ ਰਿਹਾ”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 ਸਪਲਾਇਰ ਸਟਾਕ ਖਰੀਦ ਤੇ UPI ਭੁਗਤਾਨ',
            'text': '“ਸ਼ਾਮ ਟਰੇਡਰਜ਼ ਤੋਂ 12000 ਦਾ ਨਵਾਂ ਸਟਾਕ ਖਰੀਦਿਆ ਅਤੇ ਬੈਂਕ ਯੂਪੀਆਈ ਰਾਹੀਂ ਪੇਮੈਂਟ ਕੀਤੀ”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else if (locale.startsWith('ur')) {
        return [
          {
            'tag': '🛒 گاہک فروخت اور کھاتہ باقی بل',
            'text': '“راجو بھائی کو 25 کلو چاول 500 اور 2 کلو چینی 90 روپے میں بیچی، 500 آن لائن ملا اور 90 روپے کھاتہ باقی رہا”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 سپلائر نیا مال اور یو پی آئی ادائیگی',
            'text': '“شیام ٹریڈرز سے 12000 روپے کا نیا اسٹاک خریدا اور بینک یو پی آئی سے ادائیگی کی”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      } else {
        return [
          {
            'tag': '🛒 Customer Multi-item Sale & Khata Due',
            'text': '“Sold 25kg rice for 500 and 2kg sugar for 90 to Rajesh, received 500 by UPI and 90 remaining as khata balance”',
            'icon': Icons.point_of_sale_rounded,
          },
          {
            'tag': '📦 Supplier Inventory Purchase with Bank UPI',
            'text': '“Purchased 12000 rupees stock inventory from Shyam Traders and paid via Bank UPI”',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      }
    }

    // Personal Mode
    if (locale.startsWith('bn')) {
      return [
        {
          'tag': '🍔 বাজার ও কেনাকাটা (Food & Groceries)',
          'text': '“বাজার থেকে ২৫০ টাকার মাছ আর ৮০ টাকার দুধ ও ডিম কিনলাম এবং গুগলপে দিয়ে পেমেন্ট করলাম”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 যাতায়াত ও দৈনন্দিন খরচ (Travel & Bills)',
          'text': '“অফিস যাওয়ার জন্য অটো ভাড়া দিলাম ৫০ টাকা আর পেট্রোল পাম্পে ৫০০ টাকার তেল ভরলাম”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('hi')) {
      return [
        {
          'tag': '🍔 राशन व घरेलू खरीदारी (Food & Groceries)',
          'text': '“बाजार से 250 रुपये की सब्जी और 80 रुपये का दूध ब्रेड खरीदा और गूगलपे से पेमेंट किया”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 पेट्रोल व यात्रा खर्च (Travel & Fuel)',
          'text': '“इंडियन ऑयल पेट्रोल पंप पर ₹500 का पेट्रोल भरवाया और ऑटो वाले को ₹60 नकद दिया”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('gu')) {
      return [
        {
          'tag': '🍔 કરિયાણું અને શાકભાજી (Food & Groceries)',
          'text': '“દૂધ, બ્રેડ અને શાકભાજી ૨૫૦ રૂપિયામાં ખરીદ્યા અને પેટીએમ દ્વારા ચૂકવ્યા”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 પેટ્રોલ અને પરિવહન (Travel & Fuel)',
          'text': '“ગાડીમાં ૫૦૦ રૂપિયાનું પેટ્રોલ પુરાવ્યું અને રિક્ષાવાળાને ૬૦ રૂપિયા રોકડા આપ્યા”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('mr')) {
      return [
        {
          'tag': '🍔 भाजीपाला व किराणा (Food & Groceries)',
          'text': '“बाजारातून २५০ रुपयांची भाजी आणि ८० रुपयांचे दूध आणले व गुगलपेने दिले”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 प्रवास आणि इंधन खर्च (Travel & Fuel)',
          'text': '“गाडीत ५०० रुपयांचे पेट्रोल भरले आणि रिक्षाचे ६० रुपये रोख दिले”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('ta')) {
      return [
        {
          'tag': '🍔 உணவு மற்றும் மளிகை (Food & Groceries)',
          'text': '“காய்கறி மற்றும் பால் 250 ரூபாய்க்கு வாங்கி கூகுள்பே மூலம் செலுத்தினேன்”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 பெட்ரோல் மற்றும் பயணம் (Travel & Fuel)',
          'text': '“பைக் பெட்ரோல் 500 ரூபாய்க்கு போட்டேன் மற்றும் ஆட்டோவுக்கு 60 ரூபாய் கொடுத்தேன்”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('te')) {
      return [
        {
          'tag': '🍔 కిరాణా మరియు కూరగాయలు (Food & Groceries)',
          'text': '“కూరగాయలు మరియు పాలు 250 రూపాయలకు కొని గూగల్‌పే ద్వారా చెల్లించాను”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 పెట్రోల్ మరియు ప్రయాణం (Travel & Fuel)',
          'text': '“బండిలో 500 రూపాయల పెట్రోల్ కొట్టించాను మరియు ఆటోకి 60 రూపాయలు ఇచ్చాను”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('kn')) {
      return [
        {
          'tag': '🍔 ಆಹಾರ ಮತ್ತು ದಿನಸಿ (Food & Groceries)',
          'text': '“ತರಕಾರಿ ಮತ್ತು ಹಾಲು 250 ರೂಪಾಯಿಗೆ ಖರೀದಿಸಿ ಗೂಗಲ್‌ಪೇ ಮೂಲಕ ಪಾವತಿಸಿದೆ”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 ಪೆಟ್ರೋಲ್ ಮತ್ತು ಪ್ರಯಾಣ (Travel & Fuel)',
          'text': '“500 ರೂಪಾಯಿ ಪೆಟ್ರೋಲ್ ಹಾಕಿಸಿದೆ ಮತ್ತು ಆಟೋಗೆ 60 ರೂಪಾಯಿ ನಗದು ಕೊಟ್ಟೆ”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('pa')) {
      return [
        {
          'tag': '🍔 ਰਾਸ਼ਨ ਤੇ ਘਰੇਲੂ ਖਰਚ (Food & Groceries)',
          'text': '“ਬਾਜ਼ਾਰ ਤੋਂ 250 ਰੁਪਏ ਦੀ ਸਬਜ਼ੀ ਅਤੇ 80 ਰੁਪਏ ਦਾ ਦੁੱਧ ਖਰੀਦਿਆ ਅਤੇ ਯੂਪੀਆਈ ਨਾਲ ਦਿੱਤਾ”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 ਪੈਟਰੋਲ ਤੇ ਸਫ਼ਰ (Travel & Fuel)',
          'text': '“ਪੈਟਰੋਲ ਪੰਪ ਤੇ 500 ਰੁਪਏ ਦਾ ਪੈਟਰੋਲ ਪਵਾਇਆ ਅਤੇ ਆਟੋ ਵਾਲੇ ਨੂੰ 60 ਰੁਪਏ ਦਿੱਤੇ”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else if (locale.startsWith('ur')) {
      return [
        {
          'tag': '🍔 راشن اور گھریلو سامان (Food & Groceries)',
          'text': '“بازار سے 250 روپے کی سبزی اور 80 روپے کا دودھ خریدا اور آن لائن ادائیگی کی”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 پیٹرول اور کرایہ (Travel & Fuel)',
          'text': '“گاڑی میں 500 روپے کا پیٹرول ڈلوایا اور آٹو والے کو 60 روپے نقد دیے”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    } else {
      return [
        {
          'tag': '🍔 Food & Grocery Shopping with UPI',
          'text': '“Spent 250 on grocery and 80 on dairy milk, paid via Google Pay UPI”',
          'icon': Icons.shopping_bag_outlined,
        },
        {
          'tag': '🚗 Fuel & Travel Daily Expense',
          'text': '“Filled 500 rupees petrol at Indian Oil and paid 60 cash for auto ride”',
          'icon': Icons.local_gas_station_rounded,
        },
      ];
    }
  }

  Widget _buildExampleCard(Map<String, dynamic> item, bool isDark, bool isBusiness) {
    final text = item['text'] as String;
    final tag = item['tag'] as String;
    final icon = item['icon'] as IconData? ?? Icons.record_voice_over_rounded;
    final activeColor = isBusiness ? const Color(0xFF38BDF8) : const Color(0xFF6C63FF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final clean = text.replaceAll('“', '').replaceAll('”', '');
          _processVoiceInput(clean);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B202B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: activeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tag,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 11, color: activeColor),
                        const SizedBox(width: 2),
                        Text(
                          'Try',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                text,
                softWrap: true,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[200] : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
