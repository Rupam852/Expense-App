import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_config_service.dart';
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
    _addInitialWelcomeMessage();
  }

  void _addInitialWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text: 'Namaste! 👋 Main aapka **GrowwAI Financial Advisor** hoon.\n\nMai aapke live expense ledger aur budgets ko analyze karke accurate answers aur smart money-saving tips de sakta hoon.\n\nNeeche diye gaye suggestions par tap karein ya mic/text se sawaal poochein!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
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

    setState(() {
      _messages.add(
        ChatMessage(
          text: question,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

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

    setState(() {
      _isLoading = false;
      if (result['success'] == true && result['reply'] != null) {
        _messages.add(
          ChatMessage(
            text: result['reply'],
            isUser: false,
            timestamp: DateTime.now(),
            modelUsed: result['modelUsed'],
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            text: '⚠️ ${result['error'] ?? 'Failed to get response from AI. Please check your API key in Settings.'}',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
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
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  'Live Expense Intelligence',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiConfigScreen()),
              );
            },
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Engine Settings',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _addInitialWelcomeMessage();
              });
              CustomToast.show(context, 'Chat reset');
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear Chat',
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
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
              height: 42,
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

          // Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Mic Button
                IconButton(
                  onPressed: _toggleVoiceInput,
                  icon: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening ? Colors.redAccent : primaryColor,
                  ),
                  tooltip: 'Voice Input',
                ),

                // Text Input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242936) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : 'Ask anything about your expenses...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _sendMessage(_textController.text),
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor.withValues(alpha: 0.15),
              child: Icon(Icons.psychology_alt_rounded, color: primaryColor, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? primaryColor
                    : (isDark ? const Color(0xFF1B202B) : const Color(0xFFF7F9FC)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: msg.isUser
                      ? Colors.transparent
                      : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE5E9F0)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.45,
                      color: msg.isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 4),
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
}
