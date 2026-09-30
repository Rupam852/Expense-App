import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/spending_prediction.dart';
import '../screens/budget_screen.dart';

class SpendingPredictionCard extends StatefulWidget {
  final List<SpendingPrediction> predictions;
  final VoidCallback? onAdjustBudgetTap;

  const SpendingPredictionCard({
    super.key,
    required this.predictions,
    this.onAdjustBudgetTap,
  });

  @override
  State<SpendingPredictionCard> createState() => _SpendingPredictionCardState();
}

class _SpendingPredictionCardState extends State<SpendingPredictionCard> {
  int _currentIndex = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (widget.predictions.isEmpty) return const SizedBox.shrink();

    // Filter out purely safe ones if there are warnings, unless all are safe
    final actionable = widget.predictions.where((p) => p.riskLevel != PredictionRiskLevel.safe).toList();
    final displayList = actionable.isNotEmpty ? actionable : widget.predictions;

    if (_currentIndex >= displayList.length) {
      _currentIndex = 0;
    }

    final current = displayList[_currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color themeColor;
    final Color badgeBg;
    final IconData riskIcon;
    final String badgeText;

    switch (current.riskLevel) {
      case PredictionRiskLevel.critical:
        themeColor = const Color(0xFFEB5757);
        badgeBg = const Color(0xFFEB5757).withValues(alpha: 0.15);
        riskIcon = Icons.warning_amber_rounded;
        badgeText = 'CRITICAL OVERSPEND';
        break;
      case PredictionRiskLevel.high:
        themeColor = const Color(0xFFFF8A00);
        badgeBg = const Color(0xFFFF8A00).withValues(alpha: 0.15);
        riskIcon = Icons.speed_rounded;
        badgeText = 'HIGH VELOCITY';
        break;
      case PredictionRiskLevel.moderate:
        themeColor = const Color(0xFFFBBF24);
        badgeBg = const Color(0xFFFBBF24).withValues(alpha: 0.15);
        riskIcon = Icons.info_outline;
        badgeText = 'NEAR LIMIT';
        break;
      case PredictionRiskLevel.safe:
        themeColor = const Color(0xFF00D09C);
        badgeBg = const Color(0xFF00D09C).withValues(alpha: 0.15);
        riskIcon = Icons.verified_outlined;
        badgeText = 'ON TRACK';
        break;
    }

    final double monthProgress = (current.daysElapsed / current.daysInMonth).clamp(0.0, 1.0);
    final double budgetProgress = (current.percentageSpent / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: themeColor.withValues(alpha: isDark ? 0.35 : 0.4),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Gradient Bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withValues(alpha: 0.3)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Badge + Multi-indicator pagination
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(riskIcon, size: 14, color: themeColor),
                            const SizedBox(width: 5),
                            Text(
                              badgeText,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (displayList.length > 1) ...[
                        Text(
                          '${_currentIndex + 1}/${displayList.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _currentIndex = (_currentIndex + 1) % displayList.length;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Headline
                  Text(
                    current.alertHeadline,
                    style: GoogleFonts.outfit(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    current.alertDescription,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Velocity & Forecast metrics grid
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131722) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricColumn(
                          isDark: isDark,
                          label: 'Daily Burn Rate',
                          value: '${_currencyFormat.format(current.burnRatePerDay)}/d',
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        _buildMetricColumn(
                          isDark: isDark,
                          label: 'Month-End Forecast',
                          value: _currencyFormat.format(current.projectedMonthEnd),
                          valueColor: current.projectedMonthEnd > current.budgetLimit ? themeColor : null,
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        _buildMetricColumn(
                          isDark: isDark,
                          label: 'Exhaustion Date',
                          value: current.predictedExhaustionDay != null
                              ? 'Day ${current.predictedExhaustionDay}'
                              : 'Safe',
                          valueColor: current.predictedExhaustionDay != null &&
                                  current.predictedExhaustionDay! <= current.daysInMonth
                              ? themeColor
                              : const Color(0xFF00D09C),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Month timeline vs Budget timeline progress bars
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Month Passed (${(monthProgress * 100).toStringAsFixed(0)}%)',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                                ),
                                Text(
                                  'Budget Used (${current.percentageSpent.toStringAsFixed(0)}%)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: themeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Stack(
                              children: [
                                // Month timeline
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                // Spent progress
                                FractionallySizedBox(
                                  widthFactor: budgetProgress,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: themeColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Smart Recommendation Bar & Action Button
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 16, color: themeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            current.recommendation,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer Actions
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onAdjustBudgetTap ??
                            () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const BudgetScreen()),
                              );
                            },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF00D09C)),
                        label: Text(
                          'Adjust Limits',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00D09C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn({
    required bool isDark,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
}
