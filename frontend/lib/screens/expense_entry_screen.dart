import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/expense_provider.dart';
import '../models/expense.dart';

class ExpenseEntryScreen extends StatefulWidget {
  final bool openCameraScanner;
  final Expense? editExpense; // If passed, we are in Edit Mode

  const ExpenseEntryScreen({
    super.key,
    this.openCameraScanner = false,
    this.editExpense,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'Food';
  String _selectedCurrency = 'INR';
  DateTime _selectedDate = DateTime.now();
  
  bool _isRecurring = false;
  String _recurrencePeriod = 'monthly';
  String? _receiptLocalPath;

  bool _isLocalLoading = false;

  final List<String> _categories = [
    'Food', 'Travel', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Investment', 'Others'
  ];

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD'];
  final List<String> _periods = ['daily', 'weekly', 'monthly', 'yearly'];

  @override
  void initState() {
    super.initState();
    
    // Check if we are in edit mode
    if (widget.editExpense != null) {
      final exp = widget.editExpense!;
      _amountController.text = exp.amount.toString();
      _descriptionController.text = exp.description;
      _selectedCategory = exp.category;
      _selectedCurrency = exp.currency;
      _selectedDate = exp.transactionDate;
      _isRecurring = exp.isRecurring;
      _recurrencePeriod = exp.recurrencePeriod == 'none' ? 'monthly' : exp.recurrencePeriod;
      _receiptLocalPath = exp.receiptUrl;
    }

    // Auto-trigger camera scan if passed from FAB/Dashboard action
    if (widget.openCameraScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerScanner(ImageSource.camera);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Trigger camera or gallery scanner
  void _triggerScanner(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 70, // Compress for rapid backend uploads
    );

    if (image == null) return;

    setState(() {
      _receiptLocalPath = image.path;
      _isLocalLoading = true;
    });

    if (!mounted) return;
    
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 16),
            Text('Gemini OCR analyzing receipt / transaction image...'),
          ],
        ),
        duration: Duration(seconds: 15),
      ),
    );

    final extracted = await expenseProvider.scanReceiptOCR(image.path);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    setState(() {
      _isLocalLoading = false;
    });

    if (extracted != null) {
      // Prefill fields dynamically!
      setState(() {
        if (extracted['amount'] != null) {
          _amountController.text = extracted['amount'].toString();
        }
        if (extracted['category'] != null) {
          final cat = extracted['category'].toString();
          // Match category case-insensitively or set default
          final matched = _categories.firstWhere(
            (c) => c.toLowerCase() == cat.toLowerCase(),
            orElse: () => 'Others',
          );
          _selectedCategory = matched;
        }
        if (extracted['currency'] != null) {
          final curr = extracted['currency'].toString().toUpperCase();
          if (_currencies.contains(curr)) {
            _selectedCurrency = curr;
          }
        }
        if (extracted['description'] != null || extracted['vendor'] != null) {
          final vendor = extracted['vendor'] ?? '';
          final desc = extracted['description'] ?? '';
          _descriptionController.text = vendor.isNotEmpty 
              ? '$vendor: $desc' 
              : desc;
        }
        if (extracted['transaction_date'] != null) {
          try {
            _selectedDate = DateTime.parse(extracted['transaction_date']);
          } catch (_) {}
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt scan successful! Fields autofilled.'),
          backgroundColor: Color(0xFF00D09C),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expenseProvider.syncErrorMessage ?? 'Receipt extraction failed. Entering manually.'),
          backgroundColor: Colors.amber[800],
        ),
      );
    }
  }

  void _presentDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Theme.of(context).primaryColor,
              primary: Theme.of(context).primaryColor,
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
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense amount greater than 0.')),
      );
      return;
    }

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    if (widget.editExpense != null) {
      final updated = widget.editExpense!.copyWith(
        amount: amount,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        transactionDate: _selectedDate,
        currency: _selectedCurrency,
        isRecurring: _isRecurring,
        recurrencePeriod: _isRecurring ? _recurrencePeriod : 'none',
        receiptUrl: _receiptLocalPath,
        updatedAt: DateTime.now(),
      );
      await expenseProvider.editExpense(updated);
    } else {
      await expenseProvider.addExpense(
        amount: amount,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        currency: _selectedCurrency,
        isRecurring: _isRecurring,
        recurrencePeriod: _isRecurring ? _recurrencePeriod : 'none',
        receiptUrl: _receiptLocalPath,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editExpense != null ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: _isLocalLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reading receipt fields... Please wait.'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Receipt Scan Rounded Widget
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
                              Icon(Icons.camera_alt_outlined, color: Theme.of(context).primaryColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart Scan Receipt',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Take receipt snap or UPI transaction screenshot to autofill',
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
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    foregroundColor: Theme.of(context).primaryColor,
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
                                    side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                                    foregroundColor: Theme.of(context).primaryColor,
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
                              backgroundColor: const Color(0xFF00D09C),
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
                    const SizedBox(height: 24),

                    // Amount Row + Currency Dropdown
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              labelText: 'Transaction Amount',
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

                    // Category Selector
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description text input
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Spent on lunch with friends, rent, utilities...',
                        labelText: 'Description / Vendor Details',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a brief description.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date Selection Picker Box
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
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recurring Toggle & Section
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
                            activeColor: Theme.of(context).primaryColor,
                            title: const Text('Recurring Transaction'),
                            subtitle: const Text('Automatically log this bill regularly'),
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
                    const SizedBox(height: 32),

                    // Save Action Button
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.editExpense != null ? 'Update Expense' : 'Save Expense',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
