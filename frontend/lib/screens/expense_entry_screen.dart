import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import '../models/expense.dart';

class ExpenseEntryScreen extends StatefulWidget {
  final bool openCameraScanner;
  final bool openGalleryScanner;
  final Expense? editExpense; // If passed, we are in Edit Mode

  const ExpenseEntryScreen({
    super.key,
    this.openCameraScanner = false,
    this.openGalleryScanner = false,
    this.editExpense,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'Food & Drinks';
  String _selectedCurrency = 'INR';
  DateTime _selectedDate = DateTime.now();
  
  bool _isRecurring = false;
  String _recurrencePeriod = 'monthly';
  String? _receiptLocalPath;

  bool _isLocalLoading = false;
  bool _isSaving = false;

  final List<String> _categories = [
    'Food & Drinks', 'Shopping', 'Recharges & Bills', 'Travel & Fuel', 'Medical & Health', 'Entertainment', 'Money Transfers', 'Investments & Fees', 'Others'
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
    super.dispose();
  }

  void _showGeminiKeyDialog(BuildContext context, UserProvider userProvider) {
    final keyController = TextEditingController(text: userProvider.userGeminiApiKey ?? '');
    final secondaryKeyController = TextEditingController(text: userProvider.userGeminiApiKeySecondary ?? '');
    bool isObscured = true;
    bool isSecondaryObscured = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final hasKeys = (userProvider.userGeminiApiKey != null && userProvider.userGeminiApiKey!.isNotEmpty) ||
                (userProvider.userGeminiApiKeySecondary != null && userProvider.userGeminiApiKeySecondary!.isNotEmpty);
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
                  Icon(Icons.psychology_outlined, color: Theme.of(context).primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI API Key Settings',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apna Google AI Studio (Gemini) API keys enter karein. Agar primary key fail hoti hai to optional backup key automatically use hogi.',
                      style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🔵 Google Gemini  (AIzaSy...)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('   aistudio.google.com — free, fast', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Primary Key Field
                    TextFormField(
                      controller: keyController,
                      obscureText: isObscured,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Primary API Key',
                        labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                        hintText: 'AIzaSy...',
                        filled: true,
                        fillColor: Theme.of(context).primaryColor.withOpacity(0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => isObscured = !isObscured),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Secondary Key Field
                    TextFormField(
                      controller: secondaryKeyController,
                      obscureText: isSecondaryObscured,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Secondary API Key (Optional)',
                        labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                        hintText: 'AIzaSy... (Backup key)',
                        filled: true,
                        fillColor: Theme.of(context).primaryColor.withOpacity(0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isSecondaryObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => isSecondaryObscured = !isSecondaryObscured),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'Free keys generate karein:\naistudio.google.com',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                if (hasKeys)
                  TextButton(
                    onPressed: () async {
                      await userProvider.saveUserGeminiApiKeys(primary: null, secondary: null);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Custom API Keys cleared successfully!')),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(
                      'Clear Keys',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final keyVal = keyController.text.trim();
                    final secondaryVal = secondaryKeyController.text.trim();
                    await userProvider.saveUserGeminiApiKeys(
                      primary: keyVal.isEmpty ? null : keyVal,
                      secondary: secondaryVal.isEmpty ? null : secondaryVal,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            (keyVal.isEmpty && secondaryVal.isEmpty)
                                ? 'Switched back to shared server key!'
                                : 'API Keys saved successfully!',
                          ),
                        ),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Save Keys',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showApiErrorDialog(BuildContext context, String actualError, UserProvider userProvider) {
    final hasSecondary = userProvider.userGeminiApiKeySecondary != null &&
        userProvider.userGeminiApiKeySecondary!.isNotEmpty;
    final displayMessage = hasSecondary
        ? actualError
        : 'Your API fail';

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
                  'API Processing Error',
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
              if (!hasSecondary) ...[
                const SizedBox(height: 16),
                Text(
                  'Tip: You can add an optional backup secondary API key in settings. If the primary key fails, the backup key will automatically keep the AI features working.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
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
            if (!hasSecondary)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showGeminiKeyDialog(context, userProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Add Backup Key',
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
    if (_isSaving) return; // Prevent double taps
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense amount greater than 0.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editExpense != null ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: SingleChildScrollView(
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
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
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
    final primaryColor = const Color(0xFF00D09C);
    
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
