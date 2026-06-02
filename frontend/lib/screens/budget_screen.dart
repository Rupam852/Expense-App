import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/expense_provider.dart';
import '../models/budget.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _limitController = TextEditingController();
  String _selectedCategory = 'Total Budget';
  final _categories = ['Total Budget', 'Travel', 'Meals', 'Entertainment', 'Car / Mileage', 'Office Supplies', 'Software / Subscriptions', 'Fees', 'Utilities', 'UPI Transfers', 'Others'];

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _openSetBudgetSheet({Budget? existingBudget}) {
    if (existingBudget != null) {
      _selectedCategory = existingBudget.category;
      _limitController.text = existingBudget.amountLimit.toStringAsFixed(0);
    } else {
      _selectedCategory = 'Total Budget';
      _limitController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isEditing = existingBudget != null;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit Category Budget' : 'Set Category Budget',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isEditing
                    ? 'Update monthly budget constraints for this category'
                    : 'Plan monthly budget constraints to avoid overspending alerts',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Select Category'),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: isEditing ? null : (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Limit amount input
              TextFormField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  labelText: 'Monthly Spending Limit (INR)',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () async {
                  final limit = double.tryParse(_limitController.text) ?? 0.0;
                  if (limit <= 0) return;

                  final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
                  final currentMonthStr = DateFormat('yyyy-MM').format(expenseProvider.selectedMonthYear);

                  await expenseProvider.setBudget(
                    category: _selectedCategory,
                    amountLimit: limit,
                    monthYear: currentMonthStr,
                  );

                  _limitController.clear();
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isEditing ? 'Update Budget' : 'Save Budget', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
                    await expenseProvider.deleteBudget(existingBudget.id);
                    _limitController.clear();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEB5757)),
                  label: const Text('Delete Budget Limit', style: TextStyle(color: Color(0xFFEB5757), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFEB5757), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final currentMonthStr = DateFormat('yyyy-MM').format(expenseProvider.selectedMonthYear);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Load active budgets
    final activeBudgets = expenseProvider.budgets.where((b) => b.monthYear == currentMonthStr).toList();

    // Find active Total Budget if any
    Budget? totalBudgetRecord;
    try {
      totalBudgetRecord = activeBudgets.firstWhere((b) => b.category == 'Total Budget');
    } catch (_) {
      totalBudgetRecord = null;
    }

    // Filter out Total Budget from category lists
    final categoryBudgets = activeBudgets.where((b) => b.category != 'Total Budget').toList();

    // Map spending categories and compute total monthly spent
    final Map<String, double> spendingMap = {};
    double totalMonthlySpent = 0.0;
    expenseProvider.expenses.where((e) =>
      !e.isDeleted && DateFormat('yyyy-MM').format(e.transactionDate) == currentMonthStr
    ).forEach((e) {
      spendingMap[e.category] = (spendingMap[e.category] ?? 0.0) + e.amount;
      totalMonthlySpent += e.amount;
    });

    double totalCategoryBudgetSum = 0.0;
    double totalSpentOnCategoryBudgets = 0.0;

    final List<Map<String, dynamic>> budgetList = categoryBudgets.map((b) {
      final spent = spendingMap[b.category] ?? 0.0;
      totalCategoryBudgetSum += b.amountLimit;
      totalSpentOnCategoryBudgets += spent;

      double percent = 0.0;
      if (b.amountLimit > 0) {
        percent = spent / b.amountLimit;
      }

      return {
        'budget': b,
        'spent': spent,
        'percent': percent,
      };
    }).toList();

    // Overall metrics calculation (Fallback to category sum if explicit Total Budget is missing)
    final double overallBudgetLimit = totalBudgetRecord != null 
        ? totalBudgetRecord.amountLimit 
        : totalCategoryBudgetSum;

    final double overallSpent = totalBudgetRecord != null 
        ? totalMonthlySpent 
        : totalSpentOnCategoryBudgets;

    final overallPercent = overallBudgetLimit > 0 ? (overallSpent / overallBudgetLimit) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Planner'),
        actions: [
          IconButton(
            onPressed: _openSetBudgetSheet,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Overall Progress Gauge Card (Tapping configures/edits the Total Budget)
            GestureDetector(
              onTap: () => _openSetBudgetSheet(existingBudget: totalBudgetRecord),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181B22) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            totalBudgetRecord != null ? 'TOTAL MONTHLY BUDGET' : 'COMBINED CATEGORY LIMITS',
                            style: GoogleFonts.inter(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: Theme.of(context).primaryColor, 
                              letterSpacing: 0.8
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${overallSpent.toStringAsFixed(2)} spent',
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            overallBudgetLimit > 0
                                ? 'of ₹${overallBudgetLimit.toStringAsFixed(2)} limit (Tap to edit)'
                                : 'Tap card to set monthly Total Budget',
                            style: GoogleFonts.inter(
                              fontSize: 12, 
                              color: overallBudgetLimit > 0 ? Colors.grey : Theme.of(context).primaryColor.withOpacity(0.8),
                              fontWeight: overallBudgetLimit > 0 ? FontWeight.normal : FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Circular visual indicator
                    SizedBox(
                      height: 64,
                      width: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: overallPercent > 1.0 ? 1.0 : overallPercent,
                            strokeWidth: 8,
                            backgroundColor: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                            color: overallPercent >= 1.0
                                ? const Color(0xFFEB5757)
                                : overallPercent >= 0.8
                                    ? const Color(0xFFF2C94C)
                                    : const Color(0xFF00D09C),
                          ),
                          Text(
                            '${(overallPercent * 100).toInt()}%',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Budget limits lists
            Text(
              'BUDGETS CONSTRAINTS BY CATEGORY',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            if (budgetList.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181B22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No category budgets active.',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set limits on categories like Food or Travel to track warnings when approaching thresholds.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _openSetBudgetSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Set Budget Limit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: budgetList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = budgetList[index];
                  final Budget budget = item['budget'];
                  final double spent = item['spent'];
                  final double percent = item['percent'];

                  final bool overBudget = percent >= 1.0;
                  final bool warningBudget = percent >= 0.8 && percent < 1.0;

                  Color progressColor = const Color(0xFF00D09C); // Jade
                  if (overBudget) {
                    progressColor = const Color(0xFFEB5757); // Red
                  } else if (warningBudget) {
                    progressColor = const Color(0xFFF2C94C); // Orange
                  }

                  final double remaining = budget.amountLimit - spent;

                  return GestureDetector(
                    onTap: () => _openSetBudgetSheet(existingBudget: budget),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
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
                          // Category + Amounts
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    budget.category,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '₹${spent.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    ' / ₹${budget.amountLimit.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),

                        // Progress bar with visual alerts
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent > 1.0 ? 1.0 : percent,
                            minHeight: 8,
                            backgroundColor: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                            color: progressColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Warning Label Alert
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (overBudget)
                              Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFEB5757), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Limit exceeded!',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEB5757), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            else if (warningBudget)
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_outlined, color: Color(0xFFF2C94C), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Approaching monthly limit',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF2C94C), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),
                            
                            const Spacer(),

                            Text(
                              overBudget 
                                  ? 'Over limit by ₹${remaining.abs().toStringAsFixed(2)}'
                                  : '₹${remaining.toStringAsFixed(2)} remaining',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: overBudget 
                                    ? const Color(0xFFEB5757) 
                                    : remaining <= (budget.amountLimit * 0.2)
                                        ? const Color(0xFFF2C94C)
                                        : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
                },
              ),
          ],
        ),
      ),
    );
  }
}
