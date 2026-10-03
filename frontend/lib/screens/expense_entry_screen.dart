import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import '../models/expense.dart';
import '../widgets/custom_toast.dart';
import 'ai_config_screen.dart';
import '../services/ai_config_service.dart';
import '../widgets/ai_config_required_dialog.dart';
import '../widgets/voice_expense_dialog.dart';
import '../widgets/sms_expense_parser_dialog.dart';

class ExpenseEntryScreen extends StatefulWidget {
  final bool openCameraScanner;
  final bool openGalleryScanner;
  final Expense? editExpense; // If passed and valid ID, we are in Edit Mode
  final String? initialDescription;
  final String? initialCategory;
  final double? initialAmount;
  final DateTime? initialDate;
  final String? initialCurrency;
  final String? initialLedgerType;

  const ExpenseEntryScreen({
    super.key,
    this.openCameraScanner = false,
    this.openGalleryScanner = false,
    this.editExpense,
    this.initialDescription,
    this.initialCategory,
    this.initialAmount,
    this.initialDate,
    this.initialCurrency,
    this.initialLedgerType,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late String _ledgerType;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Dedicated Business Fields
  final _vendorController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  String _paymentMode = 'Cash'; // Cash, UPI, Bank Transfer, Cheque, Card, Udhar
  
  String? _selectedCategory;
  String _selectedCurrency = 'INR';
  DateTime _selectedDate = DateTime.now();
  
  bool _isRecurring = false;
  String _recurrencePeriod = 'monthly';
  String? _receiptLocalPath;

  bool _isSaving = false;

  bool get _isRealEdit =>
      widget.editExpense != null &&
      widget.editExpense!.id.isNotEmpty &&
      widget.editExpense!.id != 'temp-voice-draft' &&
      widget.editExpense!.id != 'draft';

  static const List<String> _personalCategories = [
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
    'Logistics',
    'Subscription',
    'Investment',
    'Fitness',
    'Pet',
    'Miscellaneous',
  ];

  static const List<String> _businessCategories = [
    'Shop Rent',
    'Staff Salary & Wages',
    'Inventory & Stock Purchase',
    'Electricity & Utilities',
    'Transport & Logistics',
    'Repairs & Maintenance',
    'Packaging & Supplies',
    'Marketing & Advertising',
    'Taxes & CA / Legal Fees',
    'Tea & Refreshments',
    'Machinery & Equipment',
    'Internet & Telecom',
    'Loan EMI & Interest',
    'Business Insurance',
    'Miscellaneous Business Expense',
  ];

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD'];
  final List<String> _periods = ['daily', 'weekly', 'monthly', 'yearly'];
  final List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Credit Card',
    'Due / Udhar',
  ];

  List<String> get _activeCategories {
    final base = _ledgerType == 'business' ? _businessCategories : _personalCategories;
    final list = List<String>.from(base);
    if (_selectedCategory != null &&
        _selectedCategory!.isNotEmpty &&
        !list.contains(_selectedCategory)) {
      list.add(_selectedCategory!);
    }
    return list;
  }

  void _parseExistingDescription(String desc) {
    if (desc.startsWith('[') && desc.contains(']')) {
      final closeIdx = desc.indexOf(']');
      final meta = desc.substring(1, closeIdx);
      final remaining = desc.substring(closeIdx + 1).trim();

      final parts = meta.split('|');
      for (var part in parts) {
        final pair = part.split(':');
        if (pair.length >= 2) {
          final key = pair[0].trim().toLowerCase();
          final val = pair.sublist(1).join(':').trim();
          if (key == 'vendor') {
            _vendorController.text = val;
          } else if (key == 'mode') {
            if (_paymentModes.contains(val)) {
              _paymentMode = val;
            } else {
              _paymentMode = 'Cash';
            }
          } else if (key == 'bill' || key == 'inv' || key == 'invoice') {
            _invoiceNoController.text = val;
          }
        }
      }
      _descriptionController.text = remaining;
    } else {
      _descriptionController.text = desc;
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Determine ledger type (personal vs business)
    if (_isRealEdit) {
      _ledgerType = widget.editExpense!.ledgerType;
    } else if (widget.initialLedgerType != null) {
      _ledgerType = widget.initialLedgerType!;
    } else {
      _ledgerType = Provider.of<UserProvider>(context, listen: false).isBusinessMode ? 'business' : 'personal';
    }

    // Check if we are in real edit mode or draft creation
    if (_isRealEdit) {
      final exp = widget.editExpense!;
      _amountController.text = exp.amount > 0
          ? (exp.amount == exp.amount.roundToDouble() ? exp.amount.toInt().toString() : exp.amount.toString())
          : '';
      _parseExistingDescription(exp.description);
      _selectedCategory = exp.category;
      _selectedCurrency = exp.currency;
      _selectedDate = exp.transactionDate;
      _isRecurring = exp.isRecurring;
      _recurrencePeriod = exp.recurrencePeriod == 'none' ? 'monthly' : exp.recurrencePeriod;
      _receiptLocalPath = exp.receiptUrl;
    } else {
      // Prefill from initial parameters or draft Expense
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        final amt = widget.initialAmount!;
        _amountController.text = amt == amt.roundToDouble() ? amt.toInt().toString() : amt.toString();
      } else if (widget.editExpense != null && widget.editExpense!.amount > 0) {
        final amt = widget.editExpense!.amount;
        _amountController.text = amt == amt.roundToDouble() ? amt.toInt().toString() : amt.toString();
      }

      if (widget.initialDescription != null) {
        _parseExistingDescription(widget.initialDescription!);
      } else if (widget.editExpense != null && widget.editExpense!.description.isNotEmpty) {
        _parseExistingDescription(widget.editExpense!.description);
      }

      if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
        _selectedCategory = widget.initialCategory;
      } else if (widget.editExpense != null && widget.editExpense!.category.isNotEmpty) {
        _selectedCategory = widget.editExpense!.category;
      }

      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
      } else if (widget.editExpense != null) {
        _selectedDate = widget.editExpense!.transactionDate;
      }

      if (widget.initialCurrency != null && widget.initialCurrency!.isNotEmpty) {
        _selectedCurrency = widget.initialCurrency!;
      } else if (widget.editExpense != null && widget.editExpense!.currency.isNotEmpty) {
        _selectedCurrency = widget.editExpense!.currency;
      }
    }

    // Auto-trigger camera scan if passed from FAB/Dashboard action
    if (widget.openCameraScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerScanner(ImageSource.camera);
      });
    } else if (widget.openGalleryScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerScanner(ImageSource.gallery);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _vendorController.dispose();
    _invoiceNoController.dispose();
    super.dispose();
  }

  void _showApiErrorDialog(BuildContext context, String actualError, UserProvider userProvider) {
    final aiService = AiConfigService.instance;
    if (aiService.isServerBusyError(actualError)) {
      showAiServerBusyDialog(context);
      return;
    }

    final displayMessage = 'The AI service encountered an issue while scanning your receipt.\n\nDetails: $actualError';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Processing Error',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayMessage,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: You can configure your own personal API key in AI Configuration for faster responses and dedicated rate limits.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiConfigScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'AI Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Trigger camera or gallery scanner
  void _triggerScanner(ImageSource source) async {
    if (!checkAndPromptAiConfig(context)) {
      return;
    }
    HapticFeedback.mediumImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 70, // Compress for rapid backend uploads
    );

    if (image == null) return;

    setState(() {
      _receiptLocalPath = image.path;
    });

    if (!mounted) return;
    
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    final extracted = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OcrProgressDialog(
        title: 'Analyzing Receipt / Screenshot',
        ocrTask: () => expenseProvider.scanReceiptOCR(image.path),
      ),
    );

    if (!mounted) return;

    if (extracted != null) {
      // Prefill fields dynamically!
      setState(() {
        if (extracted['amount'] != null) {
          _amountController.text = extracted['amount'].toString();
        }
        if (extracted['category'] != null) {
          final cat = extracted['category'].toString();
          final matched = _activeCategories.firstWhere(
            (c) => c.toLowerCase() == cat.toLowerCase() || c.toLowerCase().contains(cat.toLowerCase()),
            orElse: () => _ledgerType == 'business' ? 'Miscellaneous Business Expense' : 'Miscellaneous',
          );
          _selectedCategory = matched;
        }
        if (extracted['currency'] != null) {
          final curr = extracted['currency'].toString().toUpperCase();
          if (_currencies.contains(curr)) {
            _selectedCurrency = curr;
          }
        }
        if (extracted['vendor'] != null && extracted['vendor'].toString().isNotEmpty) {
          _vendorController.text = extracted['vendor'].toString();
        }
        if (extracted['description'] != null) {
          _descriptionController.text = extracted['description'].toString();
        }
        if (extracted['transaction_date'] != null) {
          try {
            final parsedDate = DateTime.parse(extracted['transaction_date']);
            final now = DateTime.now();
            final firstDay = DateTime(now.year, now.month, 1);
            final lastDay = DateTime(now.year, now.month + 1, 0);
            if (!parsedDate.isBefore(firstDay) && !parsedDate.isAfter(lastDay)) {
              _selectedDate = parsedDate;
            } else {
              _selectedDate = DateTime.now();
            }
          } catch (_) {}
        }
      });

      CustomToast.show(context, 'Receipt scan successful! Fields autofilled.');
    } else {
      final errorMsg = expenseProvider.syncErrorMessage ?? '';
      if (errorMsg.isNotEmpty && errorMsg != 'cancelled') {
        _showApiErrorDialog(context, errorMsg, userProvider);
      }
    }
  }

  void _presentDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _ledgerType == 'business' ? const Color(0xFF2563EB) : const Color(0xFF00D09C),
              primary: _ledgerType == 'business' ? const Color(0xFF2563EB) : const Color(0xFF00D09C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _save() async {
    if (_isSaving) return; // Prevent double taps
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      CustomToast.show(context, 'Please enter an expense amount greater than 0.', isError: true);
      return;
    }

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    if (_selectedDate.isBefore(firstDay) || _selectedDate.isAfter(lastDay)) {
      CustomToast.show(context, 'Please select a date within the current month.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    // Build structured description
    final String finalDescription;
    if (_ledgerType == 'business') {
      final parts = <String>[];
      if (_vendorController.text.trim().isNotEmpty) {
        parts.add('Vendor: ${_vendorController.text.trim()}');
      }
      if (_paymentMode.isNotEmpty && _paymentMode != 'Cash') {
        parts.add('Mode: $_paymentMode');
      }
      if (_invoiceNoController.text.trim().isNotEmpty) {
        parts.add('Bill: ${_invoiceNoController.text.trim()}');
      }
      final metaPrefix = parts.isNotEmpty ? '[${parts.join(' | ')}] ' : '';
      final note = _descriptionController.text.trim();
      finalDescription = '$metaPrefix$note'.trim();
    } else {
      finalDescription = _descriptionController.text.trim();
    }

    try {
      if (_isRealEdit) {
        final updated = widget.editExpense!.copyWith(
          amount: amount,
          category: _selectedCategory!,
          description: finalDescription,
          transactionDate: _selectedDate,
          currency: _selectedCurrency,
          isRecurring: _isRecurring,
          recurrencePeriod: _isRecurring ? _recurrencePeriod : 'none',
          ledgerType: _ledgerType,
          receiptUrl: _receiptLocalPath,
          updatedAt: DateTime.now(),
        );
        await expenseProvider.editExpense(updated);
        if (mounted) {
          CustomToast.show(context, _ledgerType == 'business' ? 'Business expense updated! 💼' : 'Expense updated successfully! ✨');
        }
      } else {
        await expenseProvider.addExpense(
          amount: amount,
          category: _selectedCategory!,
          description: finalDescription,
          date: _selectedDate,
          currency: _selectedCurrency,
          isRecurring: _isRecurring,
          recurrencePeriod: _isRecurring ? _recurrencePeriod : 'none',
          receiptUrl: _receiptLocalPath,
          ledgerType: _ledgerType,
        );
        if (mounted) {
          CustomToast.show(context, _ledgerType == 'business' ? 'Business expense saved! 💼' : 'Expense saved successfully! 🎉');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Error saving transaction: $e', isError: true);
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusiness = _ledgerType == 'business';
    final accentColor = isBusiness ? const Color(0xFF2563EB) : const Color(0xFF00D09C);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRealEdit 
            ? (isBusiness ? 'Edit Business Expense 💼' : 'Edit Transaction ✍️') 
            : (isBusiness ? '➕ Add Business Expense' : 'Add Transaction'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => SmsExpenseParserDialog.show(context),
            icon: Icon(Icons.sms_outlined, color: accentColor),
            tooltip: 'Bank SMS Parser',
          ),
          IconButton(
            onPressed: () => VoiceExpenseDialog.show(context),
            icon: Icon(Icons.mic_none_rounded, color: accentColor),
            tooltip: 'AI Voice Expense Logger',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Mode Indicator Banner ───
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isBusiness
                      ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                      : const Color(0xFF00D09C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isBusiness
                        ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                        : const Color(0xFF00D09C).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBusiness ? Icons.storefront_rounded : Icons.person_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBusiness ? 'Business Operating Expense' : 'Personal Daily Expense',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isBusiness ? const Color(0xFF3B82F6) : const Color(0xFF00D09C),
                            ),
                          ),
                          Text(
                            isBusiness
                                ? 'Recorded in Shop P&L, Net Profit & Tax calculation'
                                : 'Recorded in personal budget & daily spending',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Receipt Scan Rounded Widget ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181B22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.camera_alt_outlined, color: accentColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBusiness ? 'Scan Bill / Invoice / Slip' : 'Smart Scan Receipt',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                isBusiness 
                                    ? 'Upload vendor receipt or expense bill to autofill'
                                    : 'Take receipt snap or UPI screenshot to autofill',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _triggerScanner(ImageSource.camera),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor.withOpacity(0.1),
                              foregroundColor: accentColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _triggerScanner(ImageSource.gallery),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accentColor.withOpacity(0.5)),
                              foregroundColor: accentColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    if (_receiptLocalPath != null) ...[
                      const SizedBox(height: 12),
                      Chip(
                        label: const Text('Receipt Attached'),
                        avatar: const Icon(Icons.check, size: 14, color: Colors.white),
                        backgroundColor: accentColor,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                        onDeleted: () {
                          setState(() {
                            _receiptLocalPath = null;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── Amount Row + Currency Dropdown ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        labelText: isBusiness ? 'Expense Amount (₹)' : 'Transaction Amount',
                        prefixIcon: const Icon(Icons.currency_rupee),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: _currencies.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCurrency = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Category Selector ───
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: isBusiness ? 'Business Expense Category' : 'Category',
                  prefixIcon: Icon(
                    isBusiness ? Icons.category_rounded : Icons.label_outline,
                    color: accentColor,
                  ),
                ),
                hint: Text(isBusiness ? 'Select Business Category' : 'Select Category'),
                items: _activeCategories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: GoogleFonts.inter(fontSize: 13)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Business-Specific Fields (Vendor & Payment Mode) ───
              if (isBusiness) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Paid To / Vendor (Optional)',
                          hintText: 'e.g. Ramesh (Staff), Sharma Store',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _paymentMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode',
                          prefixIcon: Icon(Icons.payment_rounded),
                        ),
                        items: _paymentModes.map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, style: GoogleFonts.inter(fontSize: 13)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _paymentMode = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _invoiceNoController,
                        decoration: const InputDecoration(
                          labelText: 'Bill # (Optional)',
                          hintText: 'e.g. INV-102',
                          prefixIcon: Icon(Icons.receipt_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ─── Description / Notes text input ───
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: isBusiness 
                      ? 'Notes on expense (e.g. 50 boxes packaging, generator diesel)...' 
                      : 'Spent on lunch with friends, rent, utilities (optional)...',
                  labelText: isBusiness ? 'Expense Description / Notes (Optional)' : 'Description / Vendor Details (Optional)',
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 10),

              // ─── Quick Hashtag Chips ───
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (isBusiness
                    ? [
                        '#ShopRent',
                        '#StaffSalary',
                        '#StockPurchase',
                        '#UtilityBill',
                        '#Delivery',
                        '#Packaging',
                        '#TeaSnacks',
                        '#Maintenance',
                        '#VendorPayment',
                        '#TaxFee',
                      ]
                    : [
                        '#GoaTrip2026',
                        '#Diwali',
                        '#Party',
                        '#Office',
                        '#Wedding',
                        '#Medical',
                        '#Shopping',
                        '#Vacation',
                      ]).map((tag) {
                  final hasThisTag = _descriptionController.text.contains(tag);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (hasThisTag) {
                          _descriptionController.text = _descriptionController.text
                              .replaceAll(tag, '')
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim();
                        } else {
                          _descriptionController.text =
                              '${_descriptionController.text} $tag'
                                  .replaceAll(RegExp(r'\s+'), ' ')
                                  .trim();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasThisTag
                            ? accentColor.withOpacity(0.2)
                            : (isDark ? const Color(0xFF222836) : const Color(0xFFF0F4F8)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasThisTag ? accentColor : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: hasThisTag ? accentColor : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: hasThisTag ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ─── Date Selection Picker Box ───
              InkWell(
                onTap: _presentDatePicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181B22) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
                      Text(
                        'Change',
                        style: GoogleFonts.inter(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Recurring Toggle & Section ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181B22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: accentColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isBusiness ? 'Monthly Recurring Business Expense' : 'Recurring Transaction',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        isBusiness ? 'e.g. Monthly Shop Rent, Staff Salary' : 'Automatically log this bill regularly',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      value: _isRecurring,
                      onChanged: (val) {
                        setState(() {
                          _isRecurring = val;
                        });
                      },
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _recurrencePeriod,
                        decoration: const InputDecoration(labelText: 'Interval Frequency'),
                        items: _periods.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p[0].toUpperCase() + p.substring(1)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _recurrencePeriod = val;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ─── Save Action Button ───
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isRealEdit 
                            ? (isBusiness ? 'Update Business Expense 💼' : 'Update Expense ✨') 
                            : (isBusiness ? 'Save Business Expense 💼' : 'Save Expense 🎉'),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class OcrProgressDialog extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function() ocrTask;
  final String title;

  const OcrProgressDialog({
    super.key,
    required this.ocrTask,
    required this.title,
  });

  @override
  State<OcrProgressDialog> createState() => _OcrProgressDialogState();
}

class _OcrProgressDialogState extends State<OcrProgressDialog> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _statusText = 'Preparing image...';
  bool _isCompleted = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startSimulation();
    _executeTask();
  }

  void _startSimulation() async {
    // 0% -> 15% quickly
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _isCancelled) return;
    setState(() {
      _progress = 0.15;
      _statusText = 'Uploading image to Gemini...';
    });

    // 15% -> 45% over 3 seconds
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _isCompleted || _isCancelled) return;
      setState(() {
        _progress += 0.01;
      });
    }

    if (!mounted || _isCompleted || _isCancelled) return;
    setState(() {
      _statusText = 'Gemini OCR analyzing text & figures...';
    });

    // 45% -> 85% over 5 seconds
    for (int i = 0; i < 80; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted || _isCompleted || _isCancelled) return;
      setState(() {
        _progress += 0.005;
      });
    }

    if (!mounted || _isCompleted || _isCancelled) return;
    setState(() {
      _statusText = 'Extracting transaction fields...';
    });

    // 85% -> 95% very slowly
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _isCompleted || _isCancelled) return;
      setState(() {
        _progress += 0.002;
      });
    }
  }

  void _executeTask() async {
    final result = await widget.ocrTask();
    if (!mounted || _isCancelled) return;

    if (result != null) {
      setState(() {
        _isCompleted = true;
        _progress = 1.0;
        _statusText = 'Analysis complete!';
      });

      // Wait a brief moment for the user to see the 100% completion
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted && !_isCancelled) {
        Navigator.of(context).pop(result);
      }
    } else {
      if (mounted && !_isCancelled) {
        Navigator.of(context).pop(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 36, left: 24, right: 24, bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _isCompleted && _progress == 1.0
                              ? Icons.check_circle_outline
                              : Icons.psychology_outlined,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Secure Scan',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: ClipOval(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      onTap: () {
                        _isCancelled = true;
                        Navigator.of(context).pop(null);
                      },
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).iconTheme.color?.withOpacity(0.6) ?? Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
