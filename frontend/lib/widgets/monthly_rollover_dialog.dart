import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_profile.dart';
import '../models/business_sale.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';
import '../services/expense_provider.dart';
import '../utils/business_export_helper.dart';
import 'custom_toast.dart';

class MonthlyRolloverDialog {
  /// Checks whether a new calendar month has started since last known month,
  /// and if so, shows the smart dual-mode (Personal + Business) rollover dialog.
  static Future<bool> checkAndShowRollover(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastKnown = prefs.getString('last_known_month_year');
    final now = DateTime.now();
    final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    if (lastKnown == null) {
      // First boot: set it to current month and initialize
      await prefs.setString('last_known_month_year', currentMonthStr);
      return false;
    }

    if (lastKnown == currentMonthStr) {
      // Already on current month
      return false;
    }

    // Month rolled over! Let's calculate previous month's dates
    final parts = lastKnown.split('-');
    int prevYear = now.year;
    int prevMonth = now.month - 1;
    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear = now.year - 1;
    }
    if (parts.length == 2) {
      try {
        prevYear = int.parse(parts[0]);
        prevMonth = int.parse(parts[1]);
      } catch (_) {}
    }

    final prevMonthStart = DateTime(prevYear, prevMonth, 1);
    final prevMonthEnd = DateTime(prevYear, prevMonth + 1, 0, 23, 59, 59);
    final prevMonthLabel = DateFormat('MMMM yyyy').format(prevMonthStart);
    final newMonthLabel = DateFormat('MMMM yyyy').format(now);

    // Fetch previous month's personal expenses
    final db = DatabaseHelper.instance;
    final allPersonalExpenses = await db.getExpenses(ledgerType: 'personal');
    final prevPersonalExpenses = allPersonalExpenses.where((e) =>
      !e.isDeleted &&
      e.transactionDate.isAfter(prevMonthStart.subtract(const Duration(seconds: 1))) &&
      e.transactionDate.isBefore(prevMonthEnd.add(const Duration(seconds: 1)))
    ).toList();
    final double prevPersonalTotal = prevPersonalExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    // Fetch previous month's business sales & expenses
    final allSales = await db.getBusinessSales();
    final prevSales = allSales.where((s) =>
      s.saleDate.isAfter(prevMonthStart.subtract(const Duration(seconds: 1))) &&
      s.saleDate.isBefore(prevMonthEnd.add(const Duration(seconds: 1)))
    ).toList();
    final double prevBusinessSalesTotal = prevSales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
    final double prevBusinessGstTotal = prevSales.fold<double>(0.0, (sum, s) => sum + s.taxAmount);

    final allBusinessExpenses = await db.getExpenses(ledgerType: 'business');
    final prevBusinessExpenses = allBusinessExpenses.where((e) =>
      !e.isDeleted &&
      e.transactionDate.isAfter(prevMonthStart.subtract(const Duration(seconds: 1))) &&
      e.transactionDate.isBefore(prevMonthEnd.add(const Duration(seconds: 1)))
    ).toList();
    final double prevBusinessExpenseTotal = prevBusinessExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final double prevBusinessNetProfit = prevBusinessSalesTotal - prevBusinessExpenseTotal;

    final businessProfile = await db.getBusinessProfile();

    if (!context.mounted) return false;

    // Show the Smart Unified Rollover Modal
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _MonthlyRolloverModal(
        oldMonthLabel: prevMonthLabel,
        newMonthLabel: newMonthLabel,
        currentMonthStr: currentMonthStr,
        prevMonthStart: prevMonthStart,
        prevMonthEnd: prevMonthEnd,
        // Personal data
        prevPersonalExpenses: prevPersonalExpenses,
        prevPersonalTotal: prevPersonalTotal,
        // Business data
        prevSales: prevSales,
        prevBusinessSalesTotal: prevBusinessSalesTotal,
        prevBusinessGstTotal: prevBusinessGstTotal,
        prevBusinessExpenses: prevBusinessExpenses,
        prevBusinessExpenseTotal: prevBusinessExpenseTotal,
        prevBusinessNetProfit: prevBusinessNetProfit,
        businessProfile: businessProfile,
      ),
    );

    return true;
  }
}

class _MonthlyRolloverModal extends StatefulWidget {
  final String oldMonthLabel;
  final String newMonthLabel;
  final String currentMonthStr;
  final DateTime prevMonthStart;
  final DateTime prevMonthEnd;

  final List<Expense> prevPersonalExpenses;
  final double prevPersonalTotal;

  final List<BusinessSale> prevSales;
  final double prevBusinessSalesTotal;
  final double prevBusinessGstTotal;
  final List<Expense> prevBusinessExpenses;
  final double prevBusinessExpenseTotal;
  final double prevBusinessNetProfit;
  final BusinessProfile? businessProfile;

  const _MonthlyRolloverModal({
    required this.oldMonthLabel,
    required this.newMonthLabel,
    required this.currentMonthStr,
    required this.prevMonthStart,
    required this.prevMonthEnd,
    required this.prevPersonalExpenses,
    required this.prevPersonalTotal,
    required this.prevSales,
    required this.prevBusinessSalesTotal,
    required this.prevBusinessGstTotal,
    required this.prevBusinessExpenses,
    required this.prevBusinessExpenseTotal,
    required this.prevBusinessNetProfit,
    required this.businessProfile,
  });

  @override
  State<_MonthlyRolloverModal> createState() => _MonthlyRolloverModalState();
}

class _MonthlyRolloverModalState extends State<_MonthlyRolloverModal> {
  bool _isGeneratingPersonal = false;
  bool _isGeneratingBusiness = false;
  String? _personalPdfPath;
  String? _businessPdfPath;

  Future<void> _generatePersonalStatement() async {
    if (widget.prevPersonalExpenses.isEmpty) return;
    setState(() => _isGeneratingPersonal = true);
    HapticFeedback.lightImpact();

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final expenseIds = widget.prevPersonalExpenses.map((e) => e.id).toList();
      final monthYear = DateFormat('yyyy-MM').format(widget.prevMonthStart);

      final path = await expenseProvider.downloadInvoice(expenseIds, monthYear: monthYear);
      if (mounted) {
        setState(() {
          _personalPdfPath = path;
          _isGeneratingPersonal = false;
        });
        if (path != null) {
          CustomToast.show(context, '✅ Personal Statement saved for ${widget.oldMonthLabel}!');
          await OpenFile.open(path);
        } else {
          CustomToast.show(context, 'Failed to generate PDF', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPersonal = false);
        CustomToast.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _generateBusinessTaxReport() async {
    setState(() => _isGeneratingBusiness = true);
    HapticFeedback.lightImpact();

    try {
      final file = await BusinessExportHelper.generateTaxAndPnLReportPdf(
        sales: widget.prevSales,
        expenses: widget.prevBusinessExpenses,
        profile: widget.businessProfile,
        startDate: widget.prevMonthStart,
        endDate: widget.prevMonthEnd,
      );

      if (mounted) {
        setState(() {
          _businessPdfPath = file?.path;
          _isGeneratingBusiness = false;
        });
        if (file != null) {
          CustomToast.show(context, '✅ Business Tax Report saved for ${widget.oldMonthLabel}!');
          await OpenFile.open(file.path);
        } else {
          CustomToast.show(context, 'Failed to generate Tax Report PDF', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingBusiness = false);
        CustomToast.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _startNewMonth() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_month_year', widget.currentMonthStr);

    if (mounted) {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      expenseProvider.setSelectedMonthYear(DateTime.now());
      Navigator.of(context).pop();
      CustomToast.show(context, '🚀 Started fresh for ${widget.newMonthLabel}!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPersonalData = widget.prevPersonalExpenses.isNotEmpty;
    final hasBusinessData = widget.prevSales.isNotEmpty || widget.prevBusinessExpenses.isNotEmpty;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D09C), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Rollover 🗓️',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Summary for ${widget.oldMonthLabel}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'A new month (${widget.newMonthLabel}) has started. Review and download official statement invoices for ${widget.oldMonthLabel}:',
              style: GoogleFonts.inter(fontSize: 12.5, height: 1.4, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),

            // ── 1. PERSONAL MODE SUMMARY CARD ────────────────────────
            if (hasPersonalData) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E232E) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00D09C).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 16, color: Color(0xFF00D09C)),
                            const SizedBox(width: 6),
                            Text(
                              'PERSONAL EXPENSES',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                            ),
                          ],
                        ),
                        Text(
                          '₹${widget.prevPersonalTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.prevPersonalExpenses.length} transactions recorded',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingPersonal ? null : _generatePersonalStatement,
                        icon: _isGeneratingPersonal
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: Text(
                          _personalPdfPath != null ? 'View Personal PDF' : 'Download Personal Statement PDF',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D09C),
                          side: const BorderSide(color: Color(0xFF00D09C)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── 2. BUSINESS MODE SUMMARY CARD ────────────────────────
            if (hasBusinessData) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E232E) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 6),
                            Text(
                              'BUSINESS REVENUE & TAX',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                        Text(
                          '₹${widget.prevBusinessSalesTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Expenses: ₹${widget.prevBusinessExpenseTotal.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                        Text('GST Tax: ₹${widget.prevBusinessGstTotal.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.blueAccent)),
                        Text(
                          'Net: ₹${widget.prevBusinessNetProfit.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.prevBusinessNetProfit >= 0 ? Colors.green : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingBusiness ? null : _generateBusinessTaxReport,
                        icon: _isGeneratingBusiness
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.assessment_rounded, size: 16),
                        label: Text(
                          _businessPdfPath != null ? 'View Business Tax PDF' : 'Download Business Tax & P&L Report PDF',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!hasPersonalData && !hasBusinessData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No transactions recorded in ${widget.oldMonthLabel}. Your ledger is completely fresh at ₹0.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startNewMonth,
            icon: const Icon(Icons.rocket_launch_rounded, size: 18),
            label: Text(
              'Start Fresh for ${widget.newMonthLabel} 🚀',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
