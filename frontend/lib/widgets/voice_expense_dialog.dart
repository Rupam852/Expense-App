import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/expense.dart';
import '../services/ai_config_service.dart';
import '../services/expense_provider.dart';
import '../screens/expense_entry_screen.dart';
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
  String? _statusMessage = 'Tap mic and speak your expense';
  Map<String, dynamic>? _extractedData;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() {
                _isListening = false;
              });
              if (_transcribedText.trim().isNotEmpty && _extractedData == null) {
                _processVoiceInput(_transcribedText);
              }
            }
          }
        },
        onError: (errorNotification) {
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
          _statusMessage = 'Listening... Speak naturally (Hindi/English)';
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
            }
          },
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_IN',
          listenOptions: stt.SpeechListenOptions(
            cancelOnError: true,
            partialResults: true,
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
    await _speech.stop();
    setState(() {
      _isListening = false;
    });

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

    setState(() {
      _isProcessing = true;
      _statusMessage = 'AI is analyzing your expense...';
    });

    final aiService = AiConfigService.instance;
    final result = await aiService.parseExpenseFromNaturalText(text);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      setState(() {
        _extractedData = data;
        _statusMessage = 'Expense parsed successfully!';
      });
      HapticFeedback.lightImpact();
    } else {
      setState(() {
        _statusMessage = result['error'] ?? 'Could not parse expense. Please try again.';
      });
      CustomToast.show(
        context,
        result['error'] ?? 'AI Parsing failed. Try speaking clearly.',
        isError: true,
      );
    }
  }

  void _saveExpenseDirectly() async {
    if (_extractedData == null) return;

    final data = _extractedData!;
    final double amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
    final String category = data['category']?.toString() ?? 'Miscellaneous';
    final String description = data['description']?.toString() ?? 'Voice Expense';
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
    );

    if (mounted) {
      Navigator.of(context).pop();
      CustomToast.show(
        context,
        'Saved ₹${amount.toStringAsFixed(2)} for $category ($paymentMethod)',
      );
    }
  }

  void _editInForm() {
    if (_extractedData == null) return;
    final data = _extractedData!;
    final double amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
    final String category = data['category']?.toString() ?? 'Miscellaneous';
    final String description = data['description']?.toString() ?? '';
    final String currency = data['currency']?.toString() ?? 'INR';

    DateTime date = DateTime.now();
    if (data['transaction_date'] != null) {
      try {
        date = DateTime.parse(data['transaction_date'].toString());
      } catch (_) {}
    }

    final draft = Expense(
      id: 'temp-voice-draft',
      amount: amount,
      category: category,
      description: description,
      currency: currency,
      transactionDate: date,
    );

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(editExpense: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

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
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.mic_none_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Voice Expense Logger',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Powered by AI Multilingual NLP',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Interactive Area
          if (_extractedData == null) ...[
            // Waveform / Pulsing Mic Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B202B) : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isListening
                      ? primaryColor.withValues(alpha: 0.5)
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
                                    : [const Color(0xFF6C63FF), const Color(0xFF4B44C9)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? const Color(0xFF00D09C) : const Color(0xFF6C63FF))
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
                      color: _isListening ? primaryColor : (isDark ? Colors.grey[300] : Colors.grey[700]),
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
                        color: primaryColor,
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Spoken Examples
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Try saying:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildExampleChip('“Paid ₹500 for groceries”', isDark),
                _buildExampleChip('“Auto fare 80 rupees yesterday”', isDark),
                _buildExampleChip('“Didi ko 300 diye snacks ke liye”', isDark),
                _buildExampleChip('“Petrol ₹1200 Indian Oil”', isDark),
              ],
            ),
          ] else ...[
            // Extracted Confirmation Card
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
                          _extractedData?['category'] ?? 'Miscellaneous',
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
                          _extractedData?['payment_method'] ?? 'UPI',
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
                    '₹${(_extractedData?['amount'] ?? 0.0).toString()}',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _extractedData?['description'] ?? 'Voice Expense',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  if (_extractedData?['vendor'] != null &&
                      _extractedData!['vendor'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Payee: ${_extractedData!['vendor']}',
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
        ],
      ),
    );
  }

  Widget _buildExampleChip(String text, bool isDark) {
    return InkWell(
      onTap: () {
        final clean = text.replaceAll('“', '').replaceAll('”', '');
        _processVoiceInput(clean);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B202B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
