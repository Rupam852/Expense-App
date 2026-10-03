import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import '../services/database_helper.dart';
import '../models/expense.dart';
import '../models/business_sale.dart';
import '../models/business_profile.dart';
import '../utils/business_export_helper.dart';
import '../widgets/custom_toast.dart';
import 'add_business_sale_screen.dart';
import 'expense_entry_screen.dart';

String getCurrencySymbol(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'USD': return r'$';
    case 'EUR': return '€';
    case 'GBP': return '£';
    case 'AUD': return r'A$';
    case 'CAD': return r'C$';
    case 'INR':
    default:
      return '₹';
  }
}

class InvoiceScreen extends StatefulWidget {
  final int initialTabIndex;

  const InvoiceScreen({super.key, this.initialTabIndex = 0});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> with SingleTickerProviderStateMixin {
  // ── PERSONAL MODE STATE ──────────────────────────────────────────
  final List<String> _selectedExpenseIds = [];
  DateTime _personalSelectedMonthYear = DateTime.now();
  bool _initializedPersonalMonth = false;

  // ── BUSINESS MODE STATE ──────────────────────────────────────────
  late TabController _tabController;
  bool _isLoadingBusinessData = false;
  List<BusinessSale> _businessSales = [];
  List<Expense> _businessExpenses = [];
  BusinessProfile _businessProfile = BusinessProfile(id: 'default', businessName: 'My Business');

  String _saleSearchQuery = '';
  String _saleStatusFilter = 'All'; // All, Paid, Partial, Unpaid
  String _expenseSearchQuery = '';

  // Tax & P&L Statement period
  String _reportPeriod = 'This Month'; // This Month, Last Month, This Quarter, This FY, All Time, Custom Range, or MMM yyyy
  DateTimeRange? _customReportRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadBusinessData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedPersonalMonth) {
      final expProv = Provider.of<ExpenseProvider>(context, listen: false);
      _personalSelectedMonthYear = expProv.selectedMonthYear;
      final pickedStr = DateFormat('yyyy-MM').format(_personalSelectedMonthYear);
      final monthExpenses = expProv.expenses.where((e) =>
        !e.isDeleted && e.ledgerType == 'personal' && DateFormat('yyyy-MM').format(e.transactionDate) == pickedStr
      ).toList();
      _selectedExpenseIds.clear();
      _selectedExpenseIds.addAll(monthExpenses.map((e) => e.id));
      _initializedPersonalMonth = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessData() async {
    setState(() => _isLoadingBusinessData = true);
    try {
      final prof = await DatabaseHelper.instance.getBusinessProfile();
      final sales = await DatabaseHelper.instance.getBusinessSales();
      final expenses = await DatabaseHelper.instance.getExpenses(ledgerType: 'business');

      if (mounted) {
        setState(() {
          _businessProfile = prof;
          _businessSales = sales;
          _businessExpenses = expenses;
          _isLoadingBusinessData = false;
        });
      }
    } catch (e) {
      debugPrint('[InvoiceScreen] Error loading business data: $e');
      if (mounted) setState(() => _isLoadingBusinessData = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // PERSONAL REIMBURSEMENT STATEMENT HELPERS
  // ══════════════════════════════════════════════════════════════════
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

  void _onSelectMonthYear(DateTime picked, List<Expense> allExpenses) {
    final pickedStr = DateFormat('yyyy-MM').format(picked);
    final monthExpenses = allExpenses.where((e) =>
      !e.isDeleted && e.ledgerType == 'personal' && DateFormat('yyyy-MM').format(e.transactionDate) == pickedStr
    ).toList();

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    expenseProvider.setSelectedMonthYear(picked);

    setState(() {
      _personalSelectedMonthYear = picked;
      _selectedExpenseIds.clear();
      if (monthExpenses.isEmpty) {
        CustomToast.show(context, '⚠️ No transactions found for ${DateFormat('MMMM yyyy').format(picked)}', isError: true);
      } else {
        _selectedExpenseIds.addAll(monthExpenses.map((e) => e.id));
        CustomToast.show(context, '✅ Auto-selected ${monthExpenses.length} transactions for ${DateFormat('MMMM yyyy').format(picked)}');
      }
    });
  }

  void _showPersonalMonthPickerModal(BuildContext context, ExpenseProvider expenseProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int displayYear = _personalSelectedMonthYear.year;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            final months = [
              {'name': 'Jan', 'month': 1, 'full': 'January'},
              {'name': 'Feb', 'month': 2, 'full': 'February'},
              {'name': 'Mar', 'month': 3, 'full': 'March'},
              {'name': 'Apr', 'month': 4, 'full': 'April'},
              {'name': 'May', 'month': 5, 'full': 'May'},
              {'name': 'Jun', 'month': 6, 'full': 'June'},
              {'name': 'Jul', 'month': 7, 'full': 'July'},
              {'name': 'Aug', 'month': 8, 'full': 'August'},
              {'name': 'Sep', 'month': 9, 'full': 'September'},
              {'name': 'Oct', 'month': 10, 'full': 'October'},
              {'name': 'Nov', 'month': 11, 'full': 'November'},
              {'name': 'Dec', 'month': 12, 'full': 'December'},
            ];

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181B22) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header with Year Navigator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Statement Month',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Compile invoices for any month',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF242936) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF333D4F) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: () {
                                setModalState(() => displayYear--);
                              },
                            ),
                            Text(
                              '$displayYear',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00D09C),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: () {
                                setModalState(() => displayYear++);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 12-Month Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final m = months[index];
                      final mNum = m['month'] as int;
                      final isSelected = _personalSelectedMonthYear.year == displayYear && _personalSelectedMonthYear.month == mNum;
                      final isCurrentMonth = now.year == displayYear && now.month == mNum;

                      // Count personal transactions for this month
                      final count = expenseProvider.expenses.where((e) {
                        return !e.isDeleted &&
                            e.ledgerType == 'personal' &&
                            e.transactionDate.year == displayYear &&
                            e.transactionDate.month == mNum;
                      }).length;

                      return InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _onSelectMonthYear(DateTime(displayYear, mNum), expenseProvider.expenses);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF00D09C), Color(0xFF05B488)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : (isDark ? const Color(0xFF202632) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00D09C)
                                  : (isCurrentMonth
                                      ? const Color(0xFF00D09C).withOpacity(0.5)
                                      : (isDark ? const Color(0xFF2C3545) : const Color(0xFFE2E8F0))),
                              width: isCurrentMonth ? 1.5 : 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    m['name'] as String,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: isSelected || isCurrentMonth ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  if (count > 0)
                                    Text(
                                      '$count txns',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.85)
                                            : const Color(0xFF00D09C),
                                      ),
                                    ),
                                ],
                              ),
                              if (isCurrentMonth && !isSelected)
                                Positioned(
                                  top: 4,
                                  right: 6,
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00D09C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Quick Action: Return to Current Month
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _onSelectMonthYear(DateTime.now(), expenseProvider.expenses);
                      },
                      icon: const Icon(Icons.today_rounded, size: 16),
                      label: Text(
                        'Jump to Current Month (${DateFormat('MMM yyyy').format(DateTime.now())})',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF242936) : const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF00D09C),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF333D4F) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _generatePersonalInvoice() async {
    if (_selectedExpenseIds.isEmpty) return;

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final selectedMonthStr = DateFormat('yyyy-MM').format(_personalSelectedMonthYear);

    double progress = 0.0;
    String statusText = 'Compiling selected transactions...';
    bool apiFinished = false;
    bool popped = false;
    bool isCancelled = false;
    String? localPath;

    expenseProvider.downloadInvoice(_selectedExpenseIds, monthYear: selectedMonthStr).then((path) {
      localPath = path;
      apiFinished = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!context.mounted || popped) return;
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
                popped = true;
                setDialogState(() {
                  progress = 1.0;
                  statusText = 'Compilation complete!';
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                });
              } else {
                if (progress < 0.98) {
                  setDialogState(() => progress += 0.01);
                } else {
                  setDialogState(() {});
                }
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
              titlePadding: EdgeInsets.zero,
              title: Stack(
                children: [
                  const SizedBox(height: 36, width: double.infinity),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        isCancelled = true;
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
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

    if (!mounted) return;

    if (!isCancelled && localPath != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogCtx) {
              return AlertDialog(
                backgroundColor: Theme.of(dialogCtx).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(dialogCtx).primaryColor.withOpacity(0.1),
                  ),
                ),
                titlePadding: EdgeInsets.zero,
                title: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, top: 20.0, right: 40.0),
                      child: Text(
                        'Invoice Generated!',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ),
                  ],
                ),
                content: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Your PDF invoice has been compiled containing ${_selectedExpenseIds.length} transactions.\n\nTotal expenses calculation has been automatically computed.',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.grey[400]),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(dialogCtx).pop();
                            Share.shareXFiles([XFile(localPath!)], text: 'Expense statement reimbursement claim');
                          },
                          icon: Icon(Icons.share_outlined, color: Theme.of(dialogCtx).primaryColor, size: 18),
                          label: Text(
                            'Share PDF',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(dialogCtx).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(dialogCtx).pop();
                            final result = await OpenFile.open(localPath!);
                            if (result.type != ResultType.done && dialogCtx.mounted) {
                              CustomToast.show(
                                dialogCtx,
                                'Cannot open PDF: ${result.message}',
                                isError: true,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(dialogCtx).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text(
                            'View Statement',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        }
      });
    } else if (!isCancelled) {
      CustomToast.show(
        context,
        'Failed to generate PDF. Make sure you are online and try again.',
        isError: true,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUSINESS ACTIONS (PDF, WhatsApp, Delete)
  // ══════════════════════════════════════════════════════════════════
  Future<void> _viewCustomerInvoicePdf(BusinessSale sale) async {
    CustomToast.show(context, 'Generating Tax Invoice PDF...');
    final file = await BusinessExportHelper.generateCustomerInvoicePdf(sale, _businessProfile);
    if (!mounted) return;
    if (file != null) {
      CustomToast.show(context, '📁 Saved to Downloads & Opening...');
      await OpenFile.open(file.path);
    } else {
      CustomToast.show(context, 'Failed to generate PDF', isError: true);
    }
  }

  Future<void> _shareCustomerInvoiceWhatsApp(BusinessSale sale) async {
    final cleanPhone = sale.customerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    final file = await BusinessExportHelper.generateCustomerInvoicePdf(sale, _businessProfile);

    final msg = Uri.encodeComponent(
      '🧾 *Invoice #${sale.invoiceNo}*\n'
      'From: *${_businessProfile.businessName}*\n\n'
      'Dear ${sale.customerName},\n'
      'Total Amount: *₹${sale.finalAmount.toStringAsFixed(2)}*\n'
      'Paid: ₹${sale.paidAmount.toStringAsFixed(2)}\n'
      '${sale.balanceDue > 0 ? "⚠️ Balance Due: *₹${sale.balanceDue.toStringAsFixed(2)}*\n" : "✅ Status: *Fully Paid*\n"}'
      '\nThank you for doing business with us! 🙏',
    );

    if (file != null) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice #${sale.invoiceNo} from ${_businessProfile.businessName} - Total: ₹${sale.finalAmount.toStringAsFixed(2)}',
      );
    } else if (formattedPhone.isNotEmpty) {
      final url = 'https://wa.me/$formattedPhone?text=$msg';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _deleteSale(BusinessSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Invoice #${sale.invoiceNo}?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this customer sale invoice for ₹${sale.finalAmount.toStringAsFixed(2)}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteBusinessSale(sale.id);
      CustomToast.show(context, 'Sale deleted');
      _loadBusinessData();
    }
  }

  Future<void> _viewExpenseVoucherPdf(Expense expense) async {
    CustomToast.show(context, 'Generating Payment Voucher PDF...');
    final file = await BusinessExportHelper.generateExpenseVoucherPdf(expense, _businessProfile);
    if (!mounted) return;
    if (file != null) {
      await OpenFile.open(file.path);
    } else {
      CustomToast.show(context, 'Failed to generate voucher PDF', isError: true);
    }
  }

  Future<void> _shareExpenseVoucher(Expense expense) async {
    final file = await BusinessExportHelper.generateExpenseVoucherPdf(expense, _businessProfile);
    if (!mounted) return;
    if (file != null) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payment Voucher - ${expense.category} (₹${expense.amount.toStringAsFixed(2)})',
      );
    }
  }

  DateTimeRange _getReportDateRange() {
    if (_customReportRange != null) {
      return _customReportRange!;
    }

    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_reportPeriod == 'This Month') {
      start = DateTime(now.year, now.month, 1);
    } else if (_reportPeriod == 'Last Month') {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      start = prevMonth;
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else if (_reportPeriod == 'This Quarter') {
      final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      start = DateTime(now.year, quarterMonth, 1);
    } else if (_reportPeriod == 'This FY') {
      // Indian Financial Year: April 1 to March 31
      final fyYear = now.month >= 4 ? now.year : now.year - 1;
      start = DateTime(fyYear, 4, 1);
    } else {
      start = DateTime(2020, 1, 1);
    }

    return DateTimeRange(start: start, end: end);
  }

  Future<void> _showMonthYearReportPicker() async {
    final now = DateTime.now();
    int selectedYear = _customReportRange != null ? _customReportRange!.start.year : now.year;
    int selectedMonth = _customReportRange != null ? _customReportRange!.start.month : now.month;

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Select Month & Year',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                    onPressed: () => setDlgState(() => selectedYear--),
                  ),
                  Text(
                    '$selectedYear',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    onPressed: () => setDlgState(() => selectedYear++),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (index) {
                  final mIndex = index + 1;
                  final isSel = selectedMonth == mIndex;
                  return ChoiceChip(
                    label: Text(months[index].substring(0, 3)),
                    selected: isSel,
                    selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setDlgState(() => selectedMonth = mIndex);
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                final start = DateTime(selectedYear, selectedMonth, 1);
                final end = DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);
                setState(() {
                  _customReportRange = DateTimeRange(start: start, end: end);
                  _reportPeriod = '${months[selectedMonth - 1]} $selectedYear';
                });
              },
              child: const Text('Apply Month'),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAX & P&L STATEMENT EXPORTS ────────────────────────────────────
  Future<void> _exportTaxReportPdf() async {
    final range = _getReportDateRange();
    CustomToast.show(context, 'Generating Tax Report PDF...');
    final file = await BusinessExportHelper.generateTaxAndPnLReportPdf(
      sales: _businessSales,
      expenses: _businessExpenses,
      profile: _businessProfile,
      startDate: range.start,
      endDate: range.end,
    );
    if (!mounted) return;
    if (file != null) {
      CustomToast.show(context, '📁 Saved to Downloads & Opening...');
      await OpenFile.open(file.path);
    } else {
      CustomToast.show(context, 'Failed to export Tax Report PDF', isError: true);
    }
  }

  Future<void> _exportTaxReportExcel() async {
    final range = _getReportDateRange();
    CustomToast.show(context, 'Generating Excel Spreadsheet (.xlsx)...');
    final file = await BusinessExportHelper.generateTaxAndPnLReportExcel(
      sales: _businessSales,
      expenses: _businessExpenses,
      profile: _businessProfile,
      startDate: range.start,
      endDate: range.end,
    );
    if (!mounted) return;
    if (file != null) {
      CustomToast.show(context, '📁 Saved to Downloads & Opening...');
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Business Tax & P&L Statement (${_reportPeriod})');
      }
    } else {
      CustomToast.show(context, 'Failed to generate Excel sheet', isError: true);
    }
  }

  // ── DETAILED SALES & MARGIN REPORT EXPORTS ─────────────────────────
  Future<void> _exportSalesReportPdf() async {
    final range = _getReportDateRange();
    CustomToast.show(context, 'Generating Sales Register PDF...');
    final file = await BusinessExportHelper.generateSalesReportPdf(
      sales: _businessSales,
      profile: _businessProfile,
      startDate: range.start,
      endDate: range.end,
    );
    if (!mounted) return;
    if (file != null) {
      CustomToast.show(context, '📁 Saved to Downloads & Opening...');
      await OpenFile.open(file.path);
    } else {
      CustomToast.show(context, 'Failed to export Sales PDF', isError: true);
    }
  }

  Future<void> _exportSalesReportExcel() async {
    final range = _getReportDateRange();
    CustomToast.show(context, 'Generating Sales Excel Sheet (.xlsx)...');
    final file = await BusinessExportHelper.generateSalesReportExcel(
      sales: _businessSales,
      profile: _businessProfile,
      startDate: range.start,
      endDate: range.end,
    );
    if (!mounted) return;
    if (file != null) {
      CustomToast.show(context, '📁 Saved to Downloads & Opening...');
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Business Sales Register (${_reportPeriod})');
      }
    } else {
      CustomToast.show(context, 'Failed to generate Sales Excel sheet', isError: true);
    }
  }

  // ── BUSINESS OPERATING EXPENSES REPORT EXPORTS ─────────────────────
  Future<void> _exportExpenseReportPdf() async {
    final range = _getReportDateRange();
    CustomToast.show(context, 'Generating Business Expenses PDF...');
    final file = await BusinessExportHelper.generateExpenseReportPdf(
      expenses: _businessExpenses,
      profile: _businessProfile,
      startDate: range.start,
      endDate: range.end,
    );
    if (!mounted) return;
    if (file != null) {
      CustomToast.show(context, '📁 Saved to Downloads & Opening...');
      await OpenFile.open(file.path);
    } else {
      CustomToast.show(context, 'Failed to export Expenses PDF', isError: true);
    }
  }

  Future<void> _exportExpenseReportExcel() async {
    final range = _getReportDateRange();
    CustomToast.show(context, 'Generating Expenses Excel Sheet (.xlsx)...');
    final file = await BusinessExportHelper.generateExpenseReportExcel(
      expenses: _businessExpenses,
      profile: _businessProfile,
      startDate: range.start,
      endDate: range.end,
    );
    if (!mounted) return;
    if (file != null) {
      CustomToast.show(context, '📁 Saved to Downloads & Opening...');
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Business Expenses Register (${_reportPeriod})');
      }
    } else {
      CustomToast.show(context, 'Failed to generate Expenses Excel sheet', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD METHOD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isBusiness = userProvider.isBusinessMode;

    if (isBusiness) {
      return _buildBusinessInvoiceHub(context);
    } else {
      return _buildPersonalInvoiceCompiler(context);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUSINESS MODE HUB (3 Tabs: Sales Invoices, Expense Vouchers, Tax & P&L)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildBusinessInvoiceHub(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF3B82F6); // Sapphire Blue for Business

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoices & Tax Reports', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 20), text: 'Sales Bills'),
            Tab(icon: Icon(Icons.payment_rounded, size: 20), text: 'Expense Vouchers'),
            Tab(icon: Icon(Icons.assessment_rounded, size: 20), text: 'Tax & P&L Report'),
          ],
        ),
      ),
      body: _isLoadingBusinessData
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSalesInvoicesTab(isDark, primaryColor),
                _buildExpenseVouchersTab(isDark, primaryColor),
                _buildTaxAndPnLTab(isDark, primaryColor),
              ],
            ),
    );
  }

  // ── TAB 1: SALES INVOICES ─────────────────────────────────────────
  Widget _buildSalesInvoicesTab(bool isDark, Color primaryColor) {
    final filtered = _businessSales.where((s) {
      final matchesQuery = _saleSearchQuery.isEmpty ||
          s.customerName.toLowerCase().contains(_saleSearchQuery.toLowerCase()) ||
          s.invoiceNo.toLowerCase().contains(_saleSearchQuery.toLowerCase()) ||
          (s.customerPhone != null && s.customerPhone!.contains(_saleSearchQuery));
      if (!matchesQuery) return false;

      if (_saleStatusFilter == 'Paid') return s.balanceDue <= 0;
      if (_saleStatusFilter == 'Unpaid') return s.paidAmount <= 0;
      if (_saleStatusFilter == 'Partial') return s.balanceDue > 0 && s.paidAmount > 0;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadBusinessData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top Action Card
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddBusinessSaleScreen()),
                    );
                    if (res == true) _loadBusinessData();
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('➕ New Customer Bill / Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search & Filters
          TextField(
            onChanged: (v) => setState(() => _saleSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by customer, invoice #, phone...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Paid', 'Partial', 'Unpaid'].map((status) {
                final isSelected = _saleStatusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: primaryColor.withOpacity(0.2),
                    onSelected: (_) => setState(() => _saleStatusFilter = status),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  Text('No Customer Invoices Found', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Create a customer bill with multiple items to generate separate invoices.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ...filtered.map((sale) => _buildSaleInvoiceCard(sale, isDark, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildSaleInvoiceCard(BusinessSale sale, bool isDark, Color primaryColor) {
    final isPaid = sale.balanceDue <= 0;
    final itemsCount = sale.items.length;
    final itemsSummary = sale.items.map((i) => '${i.itemName} (${i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 1)} ${i.unit})').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: (isPaid ? Colors.green : Colors.redAccent).withOpacity(0.15),
                    child: Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                      size: 18,
                      color: isPaid ? Colors.green : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sale.customerName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Bill #${sale.invoiceNo} • ${DateFormat('dd MMM yyyy').format(sale.saleDate)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${sale.finalAmount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                  Text(
                    isPaid ? 'PAID' : 'Due: ₹${sale.balanceDue.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.redAccent),
                  ),
                ],
              ),
            ],
          ),
          if (itemsSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '📦 $itemsCount items: $itemsSummary',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _viewCustomerInvoicePdf(sale),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.blueAccent),
                    label: const Text('View PDF', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _shareCustomerInvoiceWhatsApp(sale),
                    icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF25D366)),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 11, color: Color(0xFF25D366))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Bill',
                    onPressed: () async {
                      final res = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AddBusinessSaleScreen(existingSale: sale)),
                      );
                      if (res == true) _loadBusinessData();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    tooltip: 'Delete Bill',
                    onPressed: () => _deleteSale(sale),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TAB 2: EXPENSE VOUCHERS (PURCHASE BILLS) ──────────────────────
  Widget _buildExpenseVouchersTab(bool isDark, Color primaryColor) {
    final filtered = _businessExpenses.where((e) {
      if (_expenseSearchQuery.isEmpty) return true;
      final q = _expenseSearchQuery.toLowerCase();
      return e.category.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadBusinessData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top Action Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExpenseEntryScreen(initialLedgerType: 'business'),
                      ),
                    );
                    _loadBusinessData();
                  },
                  icon: const Icon(Icons.receipt_rounded, size: 18),
                  label: const Text('➕ Log Business Expense / Purchase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B), // Amber Accent
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Field
          TextField(
            onChanged: (v) => setState(() => _expenseSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search expense category, vendor, notes...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  Text('No Business Expenses Recorded', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Log shop rent, inventory purchases, electricity, salaries to generate official payment vouchers.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ...filtered.map((exp) => _buildExpenseVoucherCard(exp, isDark, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildExpenseVoucherCard(Expense exp, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exp.category, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(DateFormat('dd MMM yyyy, hh:mm a').format(exp.transactionDate), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              Text(
                '-₹${exp.amount.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orangeAccent.shade700),
              ),
            ],
          ),
          if (exp.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              exp.description,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _viewExpenseVoucherPdf(exp),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.orangeAccent),
                    label: const Text('Voucher PDF', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _shareExpenseVoucher(exp),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                tooltip: 'Delete Expense',
                onPressed: () async {
                  final conf = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Business Expense?'),
                      content: Text('Are you sure you want to delete ${exp.category} (₹${exp.amount.toStringAsFixed(2)})?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (conf == true) {
                    await DatabaseHelper.instance.deleteExpense(exp.id);
                    _loadBusinessData();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TAB 3: TAX & P&L REPORT & ACCOUNTS EXPORT ──────────────────────
  Widget _buildTaxAndPnLTab(bool isDark, Color primaryColor) {
    final range = _getReportDateRange();
    final filteredSales = _businessSales.where((s) => s.saleDate.isAfter(range.start.subtract(const Duration(seconds: 1))) && s.saleDate.isBefore(range.end.add(const Duration(days: 1)))).toList();
    final filteredExpenses = _businessExpenses.where((e) => e.transactionDate.isAfter(range.start.subtract(const Duration(seconds: 1))) && e.transactionDate.isBefore(range.end.add(const Duration(days: 1)))).toList();

    final totalSales = filteredSales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
    final totalGst = filteredSales.fold<double>(0.0, (sum, s) => sum + s.taxAmount);
    final totalExpenses = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final netProfit = totalSales - totalExpenses;

    // GST Slabs Breakup
    final Map<double, double> gstBreakup = {0.0: 0.0, 5.0: 0.0, 12.0: 0.0, 18.0: 0.0, 28.0: 0.0};
    for (var s in filteredSales) {
      for (var item in s.items) {
        final tRate = item.taxRate;
        final itemTax = (item.quantity * item.unitPrice) * (tRate / 100.0);
        gstBreakup[tRate] = (gstBreakup[tRate] ?? 0.0) + itemTax;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period Selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...['This Month', 'Last Month', 'This Quarter', 'This FY', 'All Time'].map((p) {
                final isSelected = _reportPeriod == p && _customReportRange == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: primaryColor.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _reportPeriod = p;
                          _customReportRange = null;
                        });
                      }
                    },
                  ),
                );
              }),

              // Month & Year Picker Chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF3B82F6)),
                  label: Text(
                    _reportPeriod.contains('202')
                        ? '🗓️ $_reportPeriod'
                        : 'Month & Year 🗓️',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _reportPeriod.contains('202') ? FontWeight.bold : FontWeight.normal,
                      color: _reportPeriod.contains('202') ? const Color(0xFF3B82F6) : null,
                    ),
                  ),
                  backgroundColor: _reportPeriod.contains('202')
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                      : null,
                  onPressed: _showMonthYearReportPicker,
                ),
              ),

              // Custom Date Range Picker Chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF3B82F6)),
                  label: Text(
                    _customReportRange != null && !_reportPeriod.contains('202')
                        ? '${DateFormat('dd MMM').format(_customReportRange!.start)} - ${DateFormat('dd MMM').format(_customReportRange!.end)}'
                        : 'Custom Range 📅',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _customReportRange != null && !_reportPeriod.contains('202') ? FontWeight.bold : FontWeight.normal,
                      color: _customReportRange != null && !_reportPeriod.contains('202') ? const Color(0xFF3B82F6) : null,
                    ),
                  ),
                  backgroundColor: _customReportRange != null && !_reportPeriod.contains('202')
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                      : null,
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020, 1, 1),
                      lastDate: DateTime(2100, 12, 31),
                      initialDateRange: _customReportRange ??
                          DateTimeRange(
                            start: DateTime(DateTime.now().year, DateTime.now().month, 1),
                            end: DateTime.now(),
                          ),
                    );
                    if (picked != null) {
                      setState(() {
                        _customReportRange = picked;
                        _reportPeriod = 'Custom Range';
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Financial Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildFinancialCard(
                title: 'Gross Sales Revenue',
                amount: '₹${totalSales.toStringAsFixed(2)}',
                subtitle: '${filteredSales.length} bills generated',
                color: Colors.greenAccent.shade700,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFinancialCard(
                title: 'Business Expenses',
                amount: '₹${totalExpenses.toStringAsFixed(2)}',
                subtitle: '${filteredExpenses.length} entries recorded',
                color: Colors.orangeAccent,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Net Profit & Loss
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netProfit >= 0
                  ? [const Color(0xFF065F46), const Color(0xFF064E3B)]
                  : [const Color(0xFF991B1B), const Color(0xFF7F1D1D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NET OPERATING PROFIT / (LOSS)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${netProfit.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  totalSales > 0 ? '${((netProfit / totalSales) * 100).toStringAsFixed(1)}% Margin' : '0% Margin',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // GST Tax Breakup Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GST Tax Collections Breakdown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Total: ₹${totalGst.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryColor)),
                ],
              ),
              const Divider(height: 16),
              ...gstBreakup.entries.where((e) => e.value > 0 || e.key == 0.0 || e.key == 18.0).map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${e.key.toStringAsFixed(0)}% GST Slab', style: GoogleFonts.inter(fontSize: 12)),
                      Text('₹${e.value.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ══════════════════════════════════════════════════════════════
        // SECTION 1: DOWNLOAD ACCOUNTS & TAX REPORTS
        // ══════════════════════════════════════════════════════════════
        _buildExportSectionCard(
          title: '1. Download Accounts & Tax Reports',
          subtitle: 'Complete P&L statement with GST tax liability summary',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFF047857),
          pdfButtonText: 'Tax Statement (PDF)',
          excelButtonText: 'Tax Statement (Excel)',
          pdfColor: const Color(0xFF047857),
          excelColor: const Color(0xFF1D6F42),
          onPdfPressed: _exportTaxReportPdf,
          onExcelPressed: _exportTaxReportExcel,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // ══════════════════════════════════════════════════════════════
        // SECTION 2: DOWNLOAD SALES & PROFIT REPORT
        // ══════════════════════════════════════════════════════════════
        _buildExportSectionCard(
          title: '2. Download Sales & Profit Register',
          subtitle: 'Item-wise bills, confidential Buy Cost 🔒, selling price & profit margin',
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF2563EB),
          pdfButtonText: 'Sales Register (PDF)',
          excelButtonText: 'Sales Register (Excel)',
          pdfColor: const Color(0xFF2563EB),
          excelColor: const Color(0xFF1E40AF),
          onPdfPressed: _exportSalesReportPdf,
          onExcelPressed: _exportSalesReportExcel,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // ══════════════════════════════════════════════════════════════
        // SECTION 3: DOWNLOAD BUSINESS EXPENSES REPORT
        // ══════════════════════════════════════════════════════════════
        _buildExportSectionCard(
          title: '3. Download Business Expenses Data',
          subtitle: 'Category-wise operating expense entries and vouchers record',
          icon: Icons.payments_rounded,
          iconColor: const Color(0xFFEA580C),
          pdfButtonText: 'Expense Register (PDF)',
          excelButtonText: 'Expense Register (Excel)',
          pdfColor: const Color(0xFFEA580C),
          excelColor: const Color(0xFFC2410C),
          onPdfPressed: _exportExpenseReportPdf,
          onExcelPressed: _exportExpenseReportExcel,
          isDark: isDark,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExportSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String pdfButtonText,
    required String excelButtonText,
    required Color pdfColor,
    required Color excelColor,
    required VoidCallback onPdfPressed,
    required VoidCallback onExcelPressed,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPdfPressed,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(pdfButtonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pdfColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onExcelPressed,
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                  label: Text(excelButtonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: excelColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(amount, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // PERSONAL REIMBURSEMENT COMPILER VIEW (Personal Mode)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildPersonalInvoiceCompiler(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedMonthStr = DateFormat('yyyy-MM').format(_personalSelectedMonthYear);
    final activeExpenses = expenseProvider.expenses.where((e) =>
      !e.isDeleted && e.ledgerType == 'personal' && DateFormat('yyyy-MM').format(e.transactionDate) == selectedMonthStr
    ).toList();

    final double selectedTotal = activeExpenses
        .where((e) => _selectedExpenseIds.contains(e.id))
        .fold<double>(0.0, (sum, item) => sum + expenseProvider.convertToINR(item.amount, item.currency));

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
          // Descriptive Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REIMBURSEMENT STATEMENT GENERATOR',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select personal transactions to compile a clean PDF expense statement for reimbursement claims.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── MONTH & YEAR SELECTOR BAR ────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF00D09C)),
                    const SizedBox(width: 8),
                    Text(
                      'Statement Month:',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showPersonalMonthPickerModal(context, expenseProvider),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00D09C).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_personalSelectedMonthYear),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00D09C),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF00D09C)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transaction checklist
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
                            '${getCurrencySymbol(exp.currency)}${exp.amount.toStringAsFixed(2)}',
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

          // Total & Compile PDF Button
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
                    onPressed: expenseProvider.isSyncing ? null : _generatePersonalInvoice,
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
