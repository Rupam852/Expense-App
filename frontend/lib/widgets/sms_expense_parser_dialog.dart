import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/sms_parser_service.dart';
import '../services/expense_provider.dart';
import 'custom_toast.dart';

class SmsExpenseParserDialog extends StatefulWidget {
  const SmsExpenseParserDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmsExpenseParserDialog(),
    );
  }

  @override
  State<SmsExpenseParserDialog> createState() => _SmsExpenseParserDialogState();
}

class _SmsExpenseParserDialogState extends State<SmsExpenseParserDialog> {
  final TextEditingController _smsController = TextEditingController();
  ParsedBankSms? _parsed;
  String _selectedCategory = 'Food & dining';
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static const List<String> _categories = [
    'Shopping',
    'Groceries',
    'Food & dining',
    'Transport',
    'Bills & recharges',
    'Transfers',
    'Medical',
    'Travel',
    'Repayments',
    'Personal',
    'Services',
    'Insurance',
    'Entertainment',
    'Gaming',
    'Small shops',
    'Rent',
    'Subscription',
    'Investment',
    'Fitness',
    'Miscellaneous',
  ];

  final List<String> _sampleSmsList = [
    'Dear SBI User, A/c **4589 debited by Rs 340.00 on 14-Oct-26 by transfer to SWIGGY UPI ref 4289102.',
    'HDFC Bank: Rs 1,850.00 debited from a/c **9812 on 15-Oct-26 to ZARA INDIA. Avl bal: Rs 34,200.',
    'Acct XX345 debited with INR 899.00 on 16-Oct-26. Info: BIL*NETFLIX*MUMBAI. Avail Bal: Rs 14,000.',
  ];

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _onSmsChanged(String text) {
    final res = SmsParserService.parse(text);
    setState(() {
      _parsed = res;
      if (res != null) {
        _selectedCategory = res.category;
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      _smsController.text = data.text!;
      _onSmsChanged(data.text!);
    } else {
      if (mounted) {
        CustomToast.show(context, 'Clipboard is empty');
      }
    }
  }

  Future<void> _saveExpense() async {
    if (_parsed == null) return;

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    await provider.addExpense(
      amount: _parsed!.amount,
      category: _selectedCategory,
      description: '${_parsed!.payee} (${_parsed!.bankName})',
      date: _parsed!.transactionDate,
      currency: 'INR',
    );

    if (mounted) {
      Navigator.of(context).pop();
      CustomToast.show(
        context,
        '⚡ Expense of ${_currencyFormat.format(_parsed!.amount)} logged from Bank SMS!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D09C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sms_outlined, color: Color(0xFF00D09C), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Bank SMS Parser',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // SMS Input with Paste button
            TextField(
              controller: _smsController,
              maxLines: 4,
              onChanged: _onSmsChanged,
              decoration: InputDecoration(
                hintText: 'Paste bank transaction SMS here (SBI, HDFC, ICICI, Axis, Paytm)...',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E222D) : const Color(0xFFF4F6F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Paste button & Quick samples
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00D09C)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.content_paste_rounded, size: 14, color: Color(0xFF00D09C)),
                  label: Text(
                    'Paste SMS',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _sampleSmsList.map((sample) {
                        final label = sample.startsWith('Dear SBI')
                            ? 'SBI Sample'
                            : sample.startsWith('HDFC')
                                ? 'HDFC Sample'
                                : 'Netflix SMS';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ActionChip(
                            label: Text(label, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              _smsController.text = sample;
                              _onSmsChanged(sample);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Parsed Result Card
            if (_parsed != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00D09C).withOpacity(0.4),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D09C).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PARSED SUCCESSFULLY',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00D09C),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _parsed!.bankName + (_parsed!.accountLast4 != null ? ' (**${_parsed!.accountLast4})' : ''),
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currencyFormat.format(_parsed!.amount),
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00D09C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merchant / Payee',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _parsed!.payee,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _categories.contains(_selectedCategory) ? _selectedCategory : _categories.first,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Save Button
              ElevatedButton.icon(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D09C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(
                  'Log Expense (${_currencyFormat.format(_parsed!.amount)})',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ] else if (_smsController.text.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '⚠️ Could not detect a valid debit amount from this SMS. Please check the text or try one of the samples.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.amber[800]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
