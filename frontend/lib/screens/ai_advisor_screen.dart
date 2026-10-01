import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_config_service.dart';
import '../services/database_helper.dart';
import '../services/expense_provider.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../widgets/ai_config_required_dialog.dart';
import '../widgets/custom_toast.dart';
import 'ai_config_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? modelUsed;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.modelUsed,
  });
}

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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

  final List<String> _suggestedPrompts = [
    '🍕 Food & Dining pe kitna kharcha hua?',
    '💡 Main har mahine ₹3,000 kaise bachaun?',
    '📊 Mera sabse bada kharcha kaunsa hai?',
    '⚠️ Kaunse category me overspend ho raha hai?',
    '📈 Summarize my spending habits this month',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
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
              ChatMessage(
                text: row['text']?.toString() ?? '',
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
    } catch (e) {
      debugPrint('[AiAdvisorScreen] Error loading chat history: $e');
      _addInitialWelcomeMessage();
    }
  }

  void _addInitialWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'Namaste! 👋 Main aapka **GrowwAI Financial Advisor** hoon.\n\nMai aapke live expense ledger aur budgets ko analyze karke accurate answers aur smart money-saving tips de sakta hoon.\n\nNeeche diye gaye suggestions par tap karein ya mic/text se sawaal poochein!',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
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
    if (result['success'] == true && result['reply'] != null) {
      aiMsg = ChatMessage(
        text: result['reply'],
        isUser: false,
        timestamp: DateTime.now(),
        modelUsed: result['modelUsed'],
      );
    } else {
      final errorMsg = result['error']?.toString() ?? 'Failed to get response from AI. Please check your AI Configuration in Settings.';
      aiMsg = ChatMessage(
        text: '⚠️ $errorMsg',
        isUser: false,
        timestamp: DateTime.now(),
      );
      if (aiService.isServerBusyError(errorMsg)) {
        showAiServerBusyDialog(context, onRetry: () => _sendMessage(userQuestion: question));
      }
    }

    setState(() {
      _isLoading = false;
      _messages.add(aiMsg);
    });

    // Persist AI response in SQLite
    await DatabaseHelper.instance.insertAiChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ai',
      text: aiMsg.text,
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text('Clear Chat History?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'All your saved conversation messages will be deleted from your phone. This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Clear History', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
        CustomToast.show(context, 'Chat history cleared successfully');
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
                    InkWell(
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
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      ),
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

          // Suggested Prompts Horizontal Bar (shown when less than 3 messages)
          if (_messages.length <= 2 && !_isLoading)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestedPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _suggestedPrompts[index];
                  return InkWell(
                    onTap: () => _sendMessage(prompt),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF181B22) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                        ),
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
                  else
                    _buildAiFormattedContent(msg.text, isDark, primaryColor),
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

  // Formatted RichText & Markdown renderer removing raw * and **
  Widget _buildAiFormattedContent(String text, bool isDark, Color primaryColor) {
    final lines = text.split('\n');
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
