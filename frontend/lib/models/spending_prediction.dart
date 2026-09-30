import 'package:intl/intl.dart';
import 'budget.dart';
import 'expense.dart';

enum PredictionRiskLevel { safe, moderate, high, critical }

class SpendingPrediction {
  final String category;
  final double budgetLimit;
  final double currentSpent;
  final double percentageSpent;
  final int daysElapsed;
  final int daysInMonth;
  final int daysRemaining;
  final double burnRatePerDay;
  final double projectedMonthEnd;
  final double projectedOverspend;
  final int? daysUntilExhaustion;
  final int? predictedExhaustionDay;
  final PredictionRiskLevel riskLevel;
  final String alertHeadline;
  final String alertDescription;
  final String recommendation;

  SpendingPrediction({
    required this.category,
    required this.budgetLimit,
    required this.currentSpent,
    required this.percentageSpent,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.daysRemaining,
    required this.burnRatePerDay,
    required this.projectedMonthEnd,
    required this.projectedOverspend,
    this.daysUntilExhaustion,
    this.predictedExhaustionDay,
    required this.riskLevel,
    required this.alertHeadline,
    required this.alertDescription,
    required this.recommendation,
  });

  static final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static List<SpendingPrediction> analyze({
    required List<Expense> expenses,
    required List<Budget> budgets,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final currentMonthYear = DateFormat('yyyy-MM').format(now);
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day.clamp(1, daysInMonth);
    final daysRemaining = (daysInMonth - daysElapsed).clamp(0, daysInMonth);

    // Current month active expenses
    final monthExpenses = expenses.where((e) {
      if (e.isDeleted) return false;
      return !e.transactionDate.isBefore(currentMonthStart) &&
          e.transactionDate.year == now.year &&
          e.transactionDate.month == now.month;
    }).toList();

    // Active budgets for current month
    final currentBudgets = budgets.where((b) {
      if (b.isDeleted) return false;
      return b.monthYear == currentMonthYear && b.amountLimit > 0;
    }).toList();

    if (currentBudgets.isEmpty) return [];

    final List<SpendingPrediction> predictions = [];

    for (final budget in currentBudgets) {
      final isTotal = budget.category.trim().toLowerCase() == 'total budget';

      final matchingExpenses = isTotal
          ? monthExpenses
          : monthExpenses.where((e) => e.category.trim().toLowerCase() == budget.category.trim().toLowerCase()).toList();

      final currentSpent = matchingExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final budgetLimit = budget.amountLimit;
      final percentageSpent = budgetLimit > 0 ? (currentSpent / budgetLimit) * 100 : 0.0;
      final burnRatePerDay = currentSpent / daysElapsed;
      final projectedMonthEnd = burnRatePerDay * daysInMonth;
      final projectedOverspend = (projectedMonthEnd - budgetLimit).clamp(0.0, double.infinity);
      final remainingBudget = budgetLimit - currentSpent;

      int? daysUntilExhaustion;
      int? predictedExhaustionDay;

      if (remainingBudget <= 0) {
        daysUntilExhaustion = 0;
        predictedExhaustionDay = daysElapsed;
      } else if (burnRatePerDay > 0) {
        final days = (remainingBudget / burnRatePerDay).ceil();
        daysUntilExhaustion = days;
        final targetDay = daysElapsed + days;
        if (targetDay <= daysInMonth) {
          predictedExhaustionDay = targetDay;
        }
      }

      // Determine Risk Level
      PredictionRiskLevel riskLevel;
      String headline;
      String description;
      String recommendation;

      final catName = isTotal ? 'Overall Monthly' : budget.category;
      final formattedSpent = _currencyFormat.format(currentSpent);
      final formattedLimit = _currencyFormat.format(budgetLimit);
      final formattedProjected = _currencyFormat.format(projectedMonthEnd);
      final formattedOverspend = _currencyFormat.format(projectedOverspend);

      if (remainingBudget <= 0) {
        riskLevel = PredictionRiskLevel.critical;
        headline = '🚨 $catName Budget Already Exceeded!';
        description = 'You have spent $formattedSpent against the $formattedLimit limit (${percentageSpent.toStringAsFixed(0)}%).';
        recommendation = 'Freeze non-essential spends in $catName for the remaining $daysRemaining days.';
      } else if (daysUntilExhaustion != null && daysUntilExhaustion <= 5 && daysRemaining > 5) {
        riskLevel = PredictionRiskLevel.critical;
        headline = '🔥 High Burn Rate: $catName exhausting in ~$daysUntilExhaustion days!';
        description = 'You spent $formattedSpent (${percentageSpent.toStringAsFixed(0)}%) in just $daysElapsed days. Projected: $formattedProjected.';
        final maxDaily = daysRemaining > 0 ? (remainingBudget / daysRemaining) : 0.0;
        recommendation = 'Limit daily spending to ${_currencyFormat.format(maxDaily)}/day to survive until month-end.';
      } else if (projectedMonthEnd > budgetLimit * 1.15 && daysElapsed >= 3) {
        riskLevel = PredictionRiskLevel.high;
        headline = '⚠️ $catName on track to overshoot by $formattedOverspend';
        description = 'Current velocity is ${_currencyFormat.format(burnRatePerDay)}/day. Month-end forecast: $formattedProjected.';
        final maxDaily = daysRemaining > 0 ? (remainingBudget / daysRemaining) : 0.0;
        recommendation = 'Cap spending at ${_currencyFormat.format(maxDaily)}/day to stay within $formattedLimit.';
      } else if (projectedMonthEnd > budgetLimit * 0.95) {
        riskLevel = PredictionRiskLevel.moderate;
        headline = '⚡ $catName spending is near the limit';
        description = 'Forecasted to reach $formattedProjected (${((projectedMonthEnd / budgetLimit) * 100).toStringAsFixed(0)}% of limit).';
        final maxDaily = daysRemaining > 0 ? (remainingBudget / daysRemaining) : 0.0;
        recommendation = 'Keep remaining daily expense under ${_currencyFormat.format(maxDaily)}/day.';
      } else {
        riskLevel = PredictionRiskLevel.safe;
        headline = '✅ $catName spending is healthy';
        description = 'Only $formattedSpent used (${percentageSpent.toStringAsFixed(0)}%). Projected to finish at $formattedProjected.';
        recommendation = 'You are on track to save ${_currencyFormat.format(budgetLimit - projectedMonthEnd)} this month!';
      }

      predictions.add(
        SpendingPrediction(
          category: budget.category,
          budgetLimit: budgetLimit,
          currentSpent: currentSpent,
          percentageSpent: percentageSpent,
          daysElapsed: daysElapsed,
          daysInMonth: daysInMonth,
          daysRemaining: daysRemaining,
          burnRatePerDay: burnRatePerDay,
          projectedMonthEnd: projectedMonthEnd,
          projectedOverspend: projectedOverspend,
          daysUntilExhaustion: daysUntilExhaustion,
          predictedExhaustionDay: predictedExhaustionDay,
          riskLevel: riskLevel,
          alertHeadline: headline,
          alertDescription: description,
          recommendation: recommendation,
        ),
      );
    }

    // Sort: critical first, then high, moderate, safe
    predictions.sort((a, b) {
      final rankA = _riskRank(a.riskLevel);
      final rankB = _riskRank(b.riskLevel);
      if (rankA != rankB) return rankB.compareTo(rankA);
      return b.percentageSpent.compareTo(a.percentageSpent);
    });

    return predictions;
  }

  static int _riskRank(PredictionRiskLevel level) {
    switch (level) {
      case PredictionRiskLevel.critical:
        return 4;
      case PredictionRiskLevel.high:
        return 3;
      case PredictionRiskLevel.moderate:
        return 2;
      case PredictionRiskLevel.safe:
        return 1;
    }
  }
}
