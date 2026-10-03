import 'package:flutter/material.dart';
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
  
  // Business Analytics state
  List<BusinessSale> _businessSales = [];
  List<Expense> _businessExpenses = [];
  Map<String, dynamic> _businessMetrics = {};
  String _businessTimeFilter = 'This Month'; // 'Today', 'This Week', 'This Month', 'All Time'

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final now = DateTime.now();
      DateTime start;
      DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      if (_businessTimeFilter == 'Today') {
        start = DateTime(now.year, now.month, now.day);
      } else if (_businessTimeFilter == 'This Week') {
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
      } else if (_businessTimeFilter == 'This Month') {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else {
        start = DateTime(2020, 1, 1);
        end = DateTime(2099, 12, 31, 23, 59, 59);
      }

      final allSales = await DatabaseHelper.instance.getBusinessSales(limit: 500);
      final periodSales = allSales.where((s) =>
        s.saleDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
        s.saleDate.isBefore(end.add(const Duration(seconds: 1)))
      ).toList();

      final expRows = await DatabaseHelper.instance.getExpenses(ledgerType: 'business');
      final periodExpenses = expRows.where((e) =>
        !e.isDeleted &&
        e.transactionDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
        e.transactionDate.isBefore(end.add(const Duration(seconds: 1)))
      ).toList();

      final metrics = await DatabaseHelper.instance.getBusinessMetrics(start: start, end: end);

      if (mounted) {
        setState(() {
          _businessSales = periodSales;
          _businessExpenses = periodExpenses;
          _businessMetrics = metrics;
        });
      }
    } catch (e) {
      debugPrint('[AnalyticsScreen] Error loading business data: $e');
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
      case 'miscellaneous':
      case 'others':
      case 'business overhead':
        return const Color(0xFF90A4AE);
      default:
        return Colors.blueGrey;
    }
  }

  Color _getPaymentModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return const Color(0xFF10B981); // Emerald
      case 'upi':
        return const Color(0xFF3B82F6); // Blue
      case 'bank transfer':
        return const Color(0xFF8B5CF6); // Purple
      case 'credit':
      case 'credit / udhar':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFFF59E0B); // Amber
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
          ? const Center(child: CircularProgressIndicator())
          : isBusiness
              ? _buildBusinessAnalytics(isDark)
              : _buildPersonalAnalytics(context, expenseProvider, isDark),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 🏢 BUSINESS MODE ANALYTICS VIEW
  // ══════════════════════════════════════════════════════════════════
  Widget _buildBusinessAnalytics(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E232E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0);

    final totalSales = (_businessMetrics['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalCollected = (_businessMetrics['total_collected'] as num?)?.toDouble() ?? 0.0;
    final totalDue = (_businessMetrics['total_due'] as num?)?.toDouble() ?? 0.0;
    
    double totalExpenses = 0.0;
    for (var e in _businessExpenses) {
      totalExpenses += e.amount;
    }

    double totalGoodsCost = 0.0;
    for (var s in _businessSales) {
      totalGoodsCost += s.totalPurchaseCost;
    }

    final netProfit = totalGoodsCost > 0
        ? (totalSales - totalGoodsCost - totalExpenses)
        : (totalSales - totalExpenses);
    final profitMargin = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

    // Payment Mode Breakdown
    final Map<String, double> paymentModeSums = {};
    for (var s in _businessSales) {
      paymentModeSums[s.paymentMode] = (paymentModeSums[s.paymentMode] ?? 0.0) + s.grandTotal;
    }

    final List<PieChartSectionData> paymentSections = [];
    paymentModeSums.forEach((mode, sum) {
      if (sum > 0 && totalSales > 0) {
        final pct = (sum / totalSales) * 100;
        paymentSections.add(
          PieChartSectionData(
            color: _getPaymentModeColor(mode),
            value: sum,
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

    // 7-day Sales Revenue Trend
    final List<BarChartGroupData> barGroups = [];
    final List<String> last7DaysStr = [];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('dd MMM').format(date);
      final queryStr = DateFormat('yyyy-MM-dd').format(date);
      last7DaysStr.add(dateStr);

      final dayTotal = _businessSales.where((s) =>
        DateFormat('yyyy-MM-dd').format(s.saleDate) == queryStr
      ).fold<double>(0.0, (acc, s) => acc + s.grandTotal);

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: dayTotal,
              color: const Color(0xFF3B82F6),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: dayTotal == 0 ? 500 : dayTotal * 1.2,
                color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E232E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: ['Today', 'This Week', 'This Month', 'All Time'].map((filter) {
                final isSel = _businessTimeFilter == filter;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _businessTimeFilter = filter);
                      _loadBusinessAnalytics();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF3B82F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        filter,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
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
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (netProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent).withOpacity(0.15),
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
                          Text('Total Revenue', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text('₹${totalSales.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6))),
                        ],
                      ),
                    ),
                    if (totalGoodsCost > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Goods Cost 🔒', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text('₹${totalGoodsCost.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Operating Exp.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text('₹${totalExpenses.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Udhar Due', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text('₹${totalDue.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent)),
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

          // 3. Last 7 Days Daily Revenue Trend (Bar Chart)
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
                  'LAST 7 DAYS SALES TREND',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: barGroups,
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
                              if (idx >= 0 && idx < last7DaysStr.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    last7DaysStr[idx],
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
    final currentMonthStr = DateFormat('yyyy-MM').format(expenseProvider.selectedMonthYear);
    // Exclude business expenses from personal analytics
    final activeExpenses = expenseProvider.expenses.where((e) =>
      !e.isDeleted &&
      (e.ledgerType == null || e.ledgerType != 'business') &&
      DateFormat('yyyy-MM').format(e.transactionDate) == currentMonthStr
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

    // compile bar data from last 7 days local activity (personal only)
    final List<BarChartGroupData> barGroups = [];
    final List<String> last7DaysStr = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('dd MMM').format(date);
      final queryStr = DateFormat('yyyy-MM-dd').format(date);
      last7DaysStr.add(dateStr);

      final dailySum = expenseProvider.expenses.where((e) =>
        !e.isDeleted &&
        (e.ledgerType == null || e.ledgerType != 'business') &&
        DateFormat('yyyy-MM-dd').format(e.transactionDate) == queryStr
      ).fold<double>(0.0, (sum, exp) => sum + expenseProvider.convertToINR(exp.amount, exp.currency));

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: dailySum,
              color: const Color(0xFF00D09C),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: dailySum == 0 ? 100 : dailySum * 1.2,
                color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total Spending Summary Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'TOTAL PERSONAL SPENT THIS MONTH',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${totalLocalSpent.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aggregated from ${activeExpenses.length} personal entries',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pie Chart Section
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
              ),
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
                    child: Text('No personal categories logged this month.', style: TextStyle(color: Colors.grey)),
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
          const SizedBox(height: 24),

          // Weekly Trends Bar Chart
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'LAST 7 DAYS ACTIVITY TREND',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      barGroups: barGroups,
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
                              if (idx >= 0 && idx < last7DaysStr.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    last7DaysStr[idx],
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
}
