import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import '../services/database_helper.dart';
import '../models/business_sale.dart';
import '../models/expense.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = false;

  // Unified Period Filter: 'Today', 'This Week', 'This Month', 'Last Month', 'Custom', 'All Time'
  String _selectedPeriod = 'This Month';
  DateTimeRange? _customDateRange;

  // Business Analytics state
  List<BusinessSale> _allBusinessSales = [];
  List<BusinessSale> _businessSales = [];
  List<Expense> _businessExpenses = [];

  final List<String> _periodOptions = [
    'Today',
    'This Week',
    'This Month',
    'Last Month',
    'Custom',
    'All Time',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  DateTimeRange _getDateRange(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    if (period == 'Today') {
      start = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    } else if (period == 'This Week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0, 0);
      final sunday = monday.add(const Duration(days: 6));
      end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
    } else if (period == 'This Month') {
      start = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    } else if (period == 'Last Month') {
      start = DateTime(now.year, now.month - 1, 1, 0, 0, 0, 0);
      end = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
    } else if (period == 'Custom' && _customDateRange != null) {
      start = DateTime(
        _customDateRange!.start.year,
        _customDateRange!.start.month,
        _customDateRange!.start.day,
        0, 0, 0, 0,
      );
      end = DateTime(
        _customDateRange!.end.year,
        _customDateRange!.end.month,
        _customDateRange!.end.day,
        23, 59, 59, 999,
      );
    } else {
      // All Time
      start = DateTime(2000, 1, 1, 0, 0, 0, 0);
      end = DateTime(2099, 12, 31, 23, 59, 59, 999);
    }

    return DateTimeRange(start: start, end: end);
  }

  bool _isWithin(DateTime dt, DateTimeRange range) {
    final local = dt.toLocal();
    final ms = local.millisecondsSinceEpoch;
    return ms >= range.start.millisecondsSinceEpoch && ms <= range.end.millisecondsSinceEpoch;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isBusinessMode) {
      await _loadBusinessAnalytics();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadBusinessAnalytics() async {
    try {
      final range = _getDateRange(_selectedPeriod);
      final allSales = await DatabaseHelper.instance.getBusinessSales(limit: 1000);
      final periodSales = allSales.where((s) => _isWithin(s.saleDate, range)).toList();

      final expRows = await DatabaseHelper.instance.getExpenses(ledgerType: 'business');
      final periodExpenses = expRows.where((e) => !e.isDeleted && _isWithin(e.transactionDate, range)).toList();

      if (mounted) {
        setState(() {
          _allBusinessSales = allSales;
          _businessSales = periodSales;
          _businessExpenses = periodExpenses;
        });
      }
    } catch (e) {
      debugPrint('[AnalyticsScreen] Error loading business data: $e');
    }
  }

  Future<void> _pickCustomDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF00D09C),
                    onPrimary: Colors.black,
                    surface: Color(0xFF181B22),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF00D09C),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = 'Custom';
      });
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isBusinessMode) {
        _loadBusinessAnalytics();
      }
    }
  }

  String _getPeriodSubtitle(DateTimeRange range) {
    if (_selectedPeriod == 'Today') {
      return 'Today • ${DateFormat('dd MMMM yyyy').format(range.start)}';
    } else if (_selectedPeriod == 'This Week') {
      return 'This Week • ${DateFormat('dd MMM').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}';
    } else if (_selectedPeriod == 'This Month') {
      return 'This Month • ${DateFormat('MMMM yyyy').format(range.start)}';
    } else if (_selectedPeriod == 'Last Month') {
      return 'Last Month • ${DateFormat('MMMM yyyy').format(range.start)}';
    } else if (_selectedPeriod == 'Custom' && _customDateRange != null) {
      return 'Custom Range • ${DateFormat('dd MMM yyyy').format(range.start)} to ${DateFormat('dd MMM yyyy').format(range.end)}';
    } else {
      return 'All Time • Lifetime Data';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'shopping':
        return const Color(0xFFEC407A);
      case 'groceries':
        return const Color(0xFF66BB6A);
      case 'food & dining':
      case 'food & drinks':
        return const Color(0xFFFF7043);
      case 'transport':
        return const Color(0xFF42A5F5);
      case 'bills & recharges':
      case 'recharges & bills':
        return const Color(0xFF26A69A);
      case 'transfers':
      case 'money transfers':
        return const Color(0xFF78909C);
      case 'medical':
      case 'medical & health':
        return const Color(0xFFEF5350);
      case 'travel':
      case 'travel & fuel':
        return const Color(0xFF29B6F6);
      case 'repayments':
        return const Color(0xFFAB47BC);
      case 'personal':
        return const Color(0xFFFFCA28);
      case 'services':
        return const Color(0xFF5C6BC0);
      case 'insurance':
        return const Color(0xFF8D6E63);
      case 'entertainment':
        return const Color(0xFFFF5252);
      case 'gaming':
        return const Color(0xFF7E57C2);
      case 'small shops':
      case 'inventory':
      case 'raw materials':
        return const Color(0xFF26C6DA);
      case 'rent':
        return const Color(0xFF9CCC65);
      case 'salary':
      case 'wages':
        return const Color(0xFFFFA726);
      case 'subscription':
        return const Color(0xFFE57373);
      case 'investment':
      case 'investments & fees':
        return const Color(0xFF26A69A);
      case 'fitness':
        return const Color(0xFF81C784);
      case 'pet':
        return const Color(0xFFA1887F);
      default:
        return const Color(0xFF90A4AE);
    }
  }

  Color _getPaymentModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return const Color(0xFF10B981);
      case 'upi':
        return const Color(0xFF3B82F6);
      case 'bank transfer':
        return const Color(0xFF8B5CF6);
      case 'credit':
      case 'credit / udhar':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusiness = userProvider.isBusinessMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12141A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        elevation: 0,
        title: Text(
          isBusiness ? '🏢 Business Analytics & P&L' : '📊 Spending Analytics',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (isBusiness) {
                _loadBusinessAnalytics();
              } else {
                setState(() {});
              }
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D09C)))
          : isBusiness
              ? _buildBusinessAnalytics(isDark)
              : _buildPersonalAnalytics(context, expenseProvider, isDark),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 🔘 UNIFIED TIME FILTER BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _buildTimeFilterBar(bool isDark, Color cardBg, Color borderColor, Color activeColor) {
    final range = _getDateRange(_selectedPeriod);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontal Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _periodOptions.map((opt) {
              final isSel = _selectedPeriod == opt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (opt == 'Custom') ...[
                        Icon(
                          Icons.date_range_rounded,
                          size: 14,
                          color: isSel ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(opt),
                    ],
                  ),
                  selected: isSel,
                  selectedColor: activeColor,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                    color: isSel ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF334155)),
                  ),
                  backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
                  side: BorderSide(
                    color: isSel ? activeColor : borderColor,
                    width: isSel ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    if (opt == 'Custom') {
                      _pickCustomDateRange();
                    } else {
                      setState(() => _selectedPeriod = opt);
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      if (userProvider.isBusinessMode) {
                        _loadBusinessAnalytics();
                      }
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Active Date Range Badge Subtitle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: activeColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: activeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getPeriodSubtitle(range),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (_selectedPeriod == 'Custom')
                InkWell(
                  onTap: _pickCustomDateRange,
                  child: Text(
                    'Edit Range',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 🏢 BUSINESS MODE P&L ANALYTICS VIEW
  // ══════════════════════════════════════════════════════════════════
  Widget _buildBusinessAnalytics(bool isDark) {
    final range = _getDateRange(_selectedPeriod);
    final cardBg = isDark ? const Color(0xFF181B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0);
    const businessAccent = Color(0xFF3B82F6);

    // Aggregate Sales & P&L in the active period
    double totalSales = 0.0;
    double totalGoodsCost = 0.0;
    double totalDue = 0.0;
    final Map<String, double> paymentModeSums = {};

    for (var sale in _businessSales) {
      totalSales += sale.finalAmount;
      totalGoodsCost += sale.totalPurchaseCost;
      totalDue += sale.balanceDue;

      final mode = sale.paymentMode.isNotEmpty ? sale.paymentMode : 'Cash';
      paymentModeSums[mode] = (paymentModeSums[mode] ?? 0.0) + sale.paidAmount;
    }

    double totalExpenses = 0.0;
    for (var exp in _businessExpenses) {
      totalExpenses += exp.amount;
    }

    final netProfit = totalSales - totalGoodsCost - totalExpenses;
    final profitMargin = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

    // Payment Mode Pie Sections
    final List<PieChartSectionData> paymentSections = [];
    final double totalPaid = paymentModeSums.values.fold(0.0, (a, b) => a + b);
    paymentModeSums.forEach((mode, amount) {
      if (amount > 0 && totalPaid > 0) {
        final pct = (amount / totalPaid) * 100;
        paymentSections.add(
          PieChartSectionData(
            color: _getPaymentModeColor(mode),
            value: amount,
            title: '${pct.toInt()}%',
            radius: 46,
            titleStyle: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    if (paymentSections.isEmpty) {
      paymentSections.add(PieChartSectionData(
        color: Colors.grey[400]!,
        value: 100,
        title: '0%',
        radius: 46,
      ));
    }

    // Dynamic Business Trend Bar Groups
    final trendData = _computeBusinessTrend(range);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Bar
          _buildTimeFilterBar(isDark, cardBg, borderColor, businessAccent),
          const SizedBox(height: 16),

          // 1. P&L Net Profit Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NET PROFIT & MARGIN',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (netProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Margin: ${profitMargin.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: netProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${netProfit.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: netProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Revenue', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            '₹${totalSales.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    ),
                    if (totalGoodsCost > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Goods Cost', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalGoodsCost.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expenses', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            '₹${totalExpenses.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Udhar Due', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            '₹${totalDue.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Sales by Payment Mode (Pie Chart)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SALES BY PAYMENT MODE',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sections: paymentSections,
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (paymentModeSums.isEmpty)
                  const Center(child: Text('No sales recorded in this period', style: TextStyle(color: Colors.grey)))
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: paymentModeSums.keys.map((mode) {
                      final sum = paymentModeSums[mode] ?? 0.0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: _getPaymentModeColor(mode),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$mode (₹${sum.toStringAsFixed(0)})',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Dynamic Sales Activity Trend (Bar Chart)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  trendData.title.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: trendData.barGroups,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < trendData.labels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    trendData.labels[idx],
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 👤 PERSONAL MODE SPENDING ANALYTICS VIEW
  // ══════════════════════════════════════════════════════════════════
  Widget _buildPersonalAnalytics(BuildContext context, ExpenseProvider expenseProvider, bool isDark) {
    final range = _getDateRange(_selectedPeriod);
    final cardBg = isDark ? const Color(0xFF181B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0);
    const personalAccent = Color(0xFF00D09C);

    // Filter personal expenses for active range
    final activeExpenses = expenseProvider.expenses.where((e) =>
      !e.isDeleted &&
      (e.ledgerType == null || e.ledgerType != 'business') &&
      _isWithin(e.transactionDate, range)
    ).toList();

    // Group expenditures by category
    final Map<String, double> localCategorySums = {};
    double totalLocalSpent = 0.0;
    for (final exp in activeExpenses) {
      final amtInINR = expenseProvider.convertToINR(exp.amount, exp.currency);
      localCategorySums[exp.category] = (localCategorySums[exp.category] ?? 0.0) + amtInINR;
      totalLocalSpent += amtInINR;
    }

    final List<PieChartSectionData> pieSections = [];
    localCategorySums.forEach((category, sum) {
      if (sum > 0 && totalLocalSpent > 0) {
        final percentage = (sum / totalLocalSpent) * 100;
        pieSections.add(
          PieChartSectionData(
            color: _getCategoryColor(category),
            value: sum,
            title: '${percentage.toInt()}%',
            radius: 50,
            titleStyle: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    if (pieSections.isEmpty) {
      pieSections.add(PieChartSectionData(
        color: Colors.grey[400]!,
        value: 100,
        title: '0%',
        radius: 50,
      ));
    }

    // Dynamic Personal Trend Bar Data
    final trendData = _computePersonalTrend(expenseProvider, range);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Bar
          _buildTimeFilterBar(isDark, cardBg, borderColor, personalAccent),
          const SizedBox(height: 16),

          // Total Spending Summary Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'TOTAL PERSONAL SPENT',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${totalLocalSpent.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aggregated from ${activeExpenses.length} personal entries in this period',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pie Chart Section
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CATEGORY ALLOCATION',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      sections: pieSections,
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (localCategorySums.isEmpty)
                  const Center(
                    child: Text('No personal categories logged in this period.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: localCategorySums.keys.map((cat) {
                      final sum = localCategorySums[cat] ?? 0.0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(cat),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$cat (₹${sum.toStringAsFixed(0)})',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Spending Trend Bar Chart
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  trendData.title.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      barGroups: trendData.barGroups,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < trendData.labels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    trendData.labels[idx],
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 📈 DYNAMIC TREND COMPUTATION HELPERS
  // ══════════════════════════════════════════════════════════════════
  _TrendResult _computePersonalTrend(ExpenseProvider expenseProvider, DateTimeRange range) {
    final List<BarChartGroupData> barGroups = [];
    final List<String> labels = [];
    String title = 'Activity Trend';

    if (_selectedPeriod == 'Today') {
      title = 'Today Hourly Activity';
      final now = DateTime.now();
      final slots = [
        {'name': 'Morn\n6-12', 'startH': 6, 'endH': 12},
        {'name': 'Aft\n12-17', 'startH': 12, 'endH': 17},
        {'name': 'Eve\n17-21', 'startH': 17, 'endH': 21},
        {'name': 'Night\n21-6', 'startH': 21, 'endH': 24},
      ];

      for (int i = 0; i < slots.length; i++) {
        final slot = slots[i];
        labels.add(slot['name'] as String);
        final startH = slot['startH'] as int;
        final endH = slot['endH'] as int;

        final slotSum = expenseProvider.expenses.where((e) {
          if (e.isDeleted || (e.ledgerType != null && e.ledgerType == 'business')) return false;
          final d = e.transactionDate.toLocal();
          return d.year == now.year && d.month == now.month && d.day == now.day && d.hour >= startH && d.hour < endH;
        }).fold<double>(0.0, (sum, exp) => sum + expenseProvider.convertToINR(exp.amount, exp.currency));

        barGroups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: slotSum,
              color: const Color(0xFF00D09C),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ],
        ));
      }
    } else if (_selectedPeriod == 'This Week') {
      title = 'This Week Daily Trend (Mon - Sun)';
      final monday = range.start;
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      for (int i = 0; i < 7; i++) {
        final targetDate = monday.add(Duration(days: i));
        labels.add('${dayNames[i]}\n${targetDate.day}');

        final daySum = expenseProvider.expenses.where((e) {
          if (e.isDeleted || (e.ledgerType != null && e.ledgerType == 'business')) return false;
          final d = e.transactionDate.toLocal();
          return d.year == targetDate.year && d.month == targetDate.month && d.day == targetDate.day;
        }).fold<double>(0.0, (sum, exp) => sum + expenseProvider.convertToINR(exp.amount, exp.currency));

        barGroups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: daySum,
              color: const Color(0xFF00D09C),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ));
      }
    } else if (_selectedPeriod == 'This Month' || _selectedPeriod == 'Last Month' || _selectedPeriod == 'Custom') {
      title = '${_selectedPeriod == "Custom" ? "Selected Range" : _selectedPeriod} Trend';
      final totalDays = range.end.difference(range.start).inDays + 1;
      final int step = totalDays > 12 ? (totalDays / 6).ceil() : 1;

      int slotIdx = 0;
      for (int dayOffset = 0; dayOffset < totalDays; dayOffset += step) {
        final chunkStart = range.start.add(Duration(days: dayOffset));
        final chunkEnd = chunkStart.add(Duration(days: step - 1));
        final actualEnd = chunkEnd.isAfter(range.end) ? range.end : chunkEnd;

        if (step > 1) {
          labels.add('${chunkStart.day}-${actualEnd.day}');
        } else {
          labels.add('${chunkStart.day} ${DateFormat('MMM').format(chunkStart)}');
        }

        final chunkSum = expenseProvider.expenses.where((e) {
          if (e.isDeleted || (e.ledgerType != null && e.ledgerType == 'business')) return false;
          final d = e.transactionDate.toLocal();
          final ms = d.millisecondsSinceEpoch;
          return ms >= chunkStart.millisecondsSinceEpoch && ms <= actualEnd.millisecondsSinceEpoch;
        }).fold<double>(0.0, (sum, exp) => sum + expenseProvider.convertToINR(exp.amount, exp.currency));

        barGroups.add(BarChartGroupData(
          x: slotIdx++,
          barRods: [
            BarChartRodData(
              toY: chunkSum,
              color: const Color(0xFF00D09C),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ));
      }
    } else {
      // All Time: Past 6 Months
      title = 'Past 6 Months Overview';
      final now = DateTime.now();
      for (int i = 5; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);
        labels.add(DateFormat('MMM yy').format(monthDate));

        final monthSum = expenseProvider.expenses.where((e) {
          if (e.isDeleted || (e.ledgerType != null && e.ledgerType == 'business')) return false;
          final d = e.transactionDate.toLocal();
          final ms = d.millisecondsSinceEpoch;
          return ms >= monthDate.millisecondsSinceEpoch && ms <= monthEnd.millisecondsSinceEpoch;
        }).fold<double>(0.0, (sum, exp) => sum + expenseProvider.convertToINR(exp.amount, exp.currency));

        barGroups.add(BarChartGroupData(
          x: 5 - i,
          barRods: [
            BarChartRodData(
              toY: monthSum,
              color: const Color(0xFF00D09C),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ));
      }
    }

    return _TrendResult(barGroups: barGroups, labels: labels, title: title);
  }

  _TrendResult _computeBusinessTrend(DateTimeRange range) {
    final List<BarChartGroupData> barGroups = [];
    final List<String> labels = [];
    String title = 'Revenue Trend';

    if (_selectedPeriod == 'Today') {
      title = 'Today Sales Distribution';
      final now = DateTime.now();
      final slots = [
        {'name': 'Morn\n6-12', 'startH': 6, 'endH': 12},
        {'name': 'Aft\n12-17', 'startH': 12, 'endH': 17},
        {'name': 'Eve\n17-21', 'startH': 17, 'endH': 21},
        {'name': 'Night\n21-6', 'startH': 21, 'endH': 24},
      ];

      for (int i = 0; i < slots.length; i++) {
        final slot = slots[i];
        labels.add(slot['name'] as String);
        final startH = slot['startH'] as int;
        final endH = slot['endH'] as int;

        final slotSum = _businessSales.where((s) {
          final d = s.saleDate.toLocal();
          return d.year == now.year && d.month == now.month && d.day == now.day && d.hour >= startH && d.hour < endH;
        }).fold<double>(0.0, (sum, s) => sum + s.finalAmount);

        barGroups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: slotSum,
              color: const Color(0xFF3B82F6),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ],
        ));
      }
    } else if (_selectedPeriod == 'This Week') {
      title = 'This Week Sales (Mon - Sun)';
      final monday = range.start;
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      for (int i = 0; i < 7; i++) {
        final targetDate = monday.add(Duration(days: i));
        labels.add('${dayNames[i]}\n${targetDate.day}');

        final daySum = _businessSales.where((s) {
          final d = s.saleDate.toLocal();
          return d.year == targetDate.year && d.month == targetDate.month && d.day == targetDate.day;
        }).fold<double>(0.0, (sum, s) => sum + s.finalAmount);

        barGroups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: daySum,
              color: const Color(0xFF3B82F6),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ));
      }
    } else if (_selectedPeriod == 'This Month' || _selectedPeriod == 'Last Month' || _selectedPeriod == 'Custom') {
      title = '${_selectedPeriod == "Custom" ? "Selected Period" : _selectedPeriod} Daily Sales';
      final totalDays = range.end.difference(range.start).inDays + 1;
      final int step = totalDays > 12 ? (totalDays / 6).ceil() : 1;

      int slotIdx = 0;
      for (int dayOffset = 0; dayOffset < totalDays; dayOffset += step) {
        final chunkStart = range.start.add(Duration(days: dayOffset));
        final chunkEnd = chunkStart.add(Duration(days: step - 1));
        final actualEnd = chunkEnd.isAfter(range.end) ? range.end : chunkEnd;

        if (step > 1) {
          labels.add('${chunkStart.day}-${actualEnd.day}');
        } else {
          labels.add('${chunkStart.day} ${DateFormat('MMM').format(chunkStart)}');
        }

        final chunkSum = _allBusinessSales.where((s) {
          final d = s.saleDate.toLocal();
          final ms = d.millisecondsSinceEpoch;
          return ms >= chunkStart.millisecondsSinceEpoch && ms <= actualEnd.millisecondsSinceEpoch;
        }).fold<double>(0.0, (sum, s) => sum + s.finalAmount);

        barGroups.add(BarChartGroupData(
          x: slotIdx++,
          barRods: [
            BarChartRodData(
              toY: chunkSum,
              color: const Color(0xFF3B82F6),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ));
      }
    } else {
      // All Time: Past 6 Months
      title = 'Past 6 Months Sales Overview';
      final now = DateTime.now();
      for (int i = 5; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);
        labels.add(DateFormat('MMM yy').format(monthDate));

        final monthSum = _allBusinessSales.where((s) {
          final d = s.saleDate.toLocal();
          final ms = d.millisecondsSinceEpoch;
          return ms >= monthDate.millisecondsSinceEpoch && ms <= monthEnd.millisecondsSinceEpoch;
        }).fold<double>(0.0, (sum, s) => sum + s.finalAmount);

        barGroups.add(BarChartGroupData(
          x: 5 - i,
          barRods: [
            BarChartRodData(
              toY: monthSum,
              color: const Color(0xFF3B82F6),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ));
      }
    }

    return _TrendResult(barGroups: barGroups, labels: labels, title: title);
  }
}

class _TrendResult {
  final List<BarChartGroupData> barGroups;
  final List<String> labels;
  final String title;

  _TrendResult({
    required this.barGroups,
    required this.labels,
    required this.title,
  });
}
