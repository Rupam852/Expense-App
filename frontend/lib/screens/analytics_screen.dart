import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/expense_provider.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _serverSummary;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiService.instance.fetchAnalyticsSummary();
      if (res['success'] == true) {
        setState(() {
          _serverSummary = res['data'];
          _isOffline = false;
        });
      } else {
        setState(() {
          _isOffline = true;
        });
      }
    } catch (_) {
      setState(() {
        _isOffline = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper Category Color Mapper
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFFFF5A5F);
      case 'travel':
        return const Color(0xFF2F80ED);
      case 'shopping':
        return const Color(0xFFF2C94C);
      case 'bills':
        return const Color(0xFF9B51E0);
      case 'entertainment':
        return const Color(0xFF27AE60);
      case 'health':
        return const Color(0xFFEB5757);
      case 'investment':
        return const Color(0xFF00D09C);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- COMPUTING LOCAL FALLBACK STATS (For Offline Support) ---
    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final activeExpenses = expenseProvider.expenses.where((e) =>
      !e.isDeleted && DateFormat('yyyy-MM').format(e.transactionDate) == currentMonthStr
    ).toList();

    // Group local expenditures
    final Map<String, double> localCategorySums = {};
    double totalLocalSpent = 0.0;
    for (final exp in activeExpenses) {
      localCategorySums[exp.category] = (localCategorySums[exp.category] ?? 0.0) + exp.amount;
      totalLocalSpent += exp.amount;
    }

    final List<PieChartSectionData> pieSections = [];
    int colorIdx = 0;
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
        colorIdx++;
      }
    });

    // Handle empty state sections
    if (pieSections.isEmpty) {
      pieSections.add(PieChartSectionData(
        color: Colors.grey[400]!,
        value: 100,
        title: '0%',
        radius: 50,
      ));
    }

    // compile bar data from last 7 days local activity
    final List<BarChartGroupData> barGroups = [];
    final List<String> last7DaysStr = [];
    final Map<String, double> last7DaysSums = {};

    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('dd MMM').format(date);
      final queryStr = DateFormat('yyyy-MM-dd').format(date);
      
      last7DaysStr.add(dateStr);
      
      final dailySum = expenseProvider.expenses.where((e) =>
        !e.isDeleted && DateFormat('yyyy-MM-dd').format(e.transactionDate) == queryStr
      ).fold<double>(0.0, (sum, exp) => sum + exp.amount);
      
      last7DaysSums[dateStr] = dailySum;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        actions: [
          IconButton(
            onPressed: _fetchSummary,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Offline Sync Warning Card
                  if (_isOffline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 20.0),
                      decoration: BoxDecoration(
                        color: Colors.amber[800]!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber[800]!.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.offline_bolt, color: Colors.amber[800]),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Offline Mode: Displaying data computed locally. Sync with cloud to recover full summaries.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Total Spending summary
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
                          'TOTAL OUTFLOW THIS MONTH',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalLocalSpent.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aggregated from ${activeExpenses.length} local entries',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Pie Chart Section
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
                        
                        // Pie widget
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

                        // Legends lists
                        if (localCategorySums.isEmpty)
                          const Center(
                            child: Text('No categories logged this month.', style: TextStyle(color: Colors.grey)),
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

                  // 3. Weekly Trends Bar Chart
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
                        
                        // Bar graph
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
            ),
    );
  }
}
