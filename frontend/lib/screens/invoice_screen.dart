import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../services/expense_provider.dart';
import '../models/expense.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final List<String> _selectedExpenseIds = [];

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedExpenseIds.contains(id)) {
        _selectedExpenseIds.remove(id);
      } else {
        _selectedExpenseIds.add(id);
      }
    });
  }

  void _selectAll(List<Expense> expenses) {
    setState(() {
      if (_selectedExpenseIds.length == expenses.length) {
        _selectedExpenseIds.clear();
      } else {
        _selectedExpenseIds.clear();
        _selectedExpenseIds.addAll(expenses.map((e) => e.id));
      }
    });
  }

  void _generateInvoice() async {
    if (_selectedExpenseIds.isEmpty) return;

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

    double progress = 0.0;
    String statusText = 'Compiling selected transactions...';
    bool apiFinished = false;
    String? localPath;

    // Start API request in parallel
    expenseProvider.downloadInvoice(_selectedExpenseIds).then((path) {
      localPath = path;
      apiFinished = true;
    });

    // Show custom progress dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Set up a delayed check to animate progress smoothly
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!context.mounted) return;
              if (progress < 0.9) {
                setDialogState(() {
                  progress += 0.08;
                  if (progress > 0.4 && progress < 0.7) {
                    statusText = 'Generating PDF layout...';
                  } else if (progress >= 0.7) {
                    statusText = 'Compiling total expenses...';
                  }
                });
              } else if (apiFinished) {
                setDialogState(() {
                  progress = 1.0;
                  statusText = 'Compilation complete!';
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close progress dialog
                  }
                });
              }
            });

            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Theme.of(context).primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Generating Statement',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
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

    // After progress dialog closes, show either success modal or error SnackBar
    if (!mounted) return;

    if (localPath != null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Invoice Generated!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Text(
              'Your PDF invoice has been compiled containing ${_selectedExpenseIds.length} transactions.\n\nTotal expenses calculation has been automatically computed.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Share.shareXFiles([XFile(localPath!)], text: 'Expense statement reimbursement claim');
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share PDF'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final result = await OpenFile.open(localPath!);
                  if (result.type != ResultType.done && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cannot open PDF: ${result.message}')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View Statement'),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate PDF. Make sure you are online and try again.'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter out deleted items and only show selected month's expenses
    final selectedMonthStr = DateFormat('yyyy-MM').format(expenseProvider.selectedMonthYear);
    final activeExpenses = expenseProvider.expenses.where((e) =>
      !e.isDeleted && DateFormat('yyyy-MM').format(e.transactionDate) == selectedMonthStr
    ).toList();

    final double selectedTotal = activeExpenses
        .where((e) => _selectedExpenseIds.contains(e.id))
        .fold<double>(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Invoicing'),
        actions: [
          if (activeExpenses.isNotEmpty)
            TextButton(
              onPressed: () => _selectAll(activeExpenses),
              child: Text(
                _selectedExpenseIds.length == activeExpenses.length 
                    ? 'Deselect All' 
                    : 'Select All',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Descriptive Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REIMBURSEMENT GENERATOR',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select multiple transactions from the list to compile a clean PDF invoice for clients or corporate reimbursements.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Transaction checklist items
          Expanded(
            child: activeExpenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions to select.',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add expenses first on the dashboard.',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: activeExpenses.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemBuilder: (context, index) {
                      final exp = activeExpenses[index];
                      final isSelected = _selectedExpenseIds.contains(exp.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF181B22) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).primaryColor
                                : isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(exp.id),
                          activeColor: Theme.of(context).primaryColor,
                          checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          title: Text(
                            exp.description.isNotEmpty ? exp.description : exp.category,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${exp.category} • ${DateFormat('dd MMM yyyy').format(exp.transactionDate)}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                          ),
                          secondary: Text(
                            '₹${exp.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.red[400],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 3. Float summary total & Compile PDF button
          if (_selectedExpenseIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181B22) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedExpenseIds.length} ITEMS SELECTED',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${selectedTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: expenseProvider.isSyncing ? null : _generateInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: expenseProvider.isSyncing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Generate PDF',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
