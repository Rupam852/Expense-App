import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/expense_provider.dart';
import 'dashboard_screen.dart';
import 'budget_screen.dart';
import 'analytics_screen.dart';
import 'invoice_screen.dart';
import 'payment_details_screen.dart';
import 'expense_entry_screen.dart';
import '../widgets/voice_expense_dialog.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isFabOpen = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Auto-sync in background when session resumes (covers reinstall + cold start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      expenseProvider.triggerQuietSync();
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _toggleFabMenu() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _closeFabMenu() {
    if (_isFabOpen) {
      HapticFeedback.lightImpact();
      setState(() {
        _isFabOpen = false;
        _fabAnimationController.reverse();
      });
    }
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const BudgetScreen(),
    const AnalyticsScreen(),
    const InvoiceScreen(),
    const PaymentDetailsScreen(),
  ];

  void _openQuickAddExpense() {
    _closeFabMenu();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExpenseEntryScreen(),
      ),
    );
  }

  void _openVoiceExpenseDialog() {
    _closeFabMenu();
    VoiceExpenseDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);

    return PopScope(
      canPop: _currentIndex == 0 && !_isFabOpen,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isFabOpen) {
          _closeFabMenu();
          return;
        }
        if (_currentIndex > 0) {
          setState(() {
            _currentIndex = 0; // Seamlessly go back to Home tab
          });
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),

            // ══════════════════════════════════════════════════════
            // BACKDROP OVERLAY (Dismisses FAB menu on tap anywhere)
            // ══════════════════════════════════════════════════════
            if (_isFabOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFabMenu,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, child) {
                      return Container(
                        color: Colors.black.withOpacity(0.55 * _expandAnimation.value),
                      );
                    },
                  ),
                ),
              ),

            // ══════════════════════════════════════════════════════
            // SPEED DIAL POPUP ITEMS (Voice + Manual Entry)
            // ══════════════════════════════════════════════════════
            if (_isFabOpen || _fabAnimationController.isAnimating)
              Positioned(
                right: 16,
                bottom: 84, // Placed right above the bottom FAB
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _expandAnimation.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _expandAnimation.value.clamp(0.0, 1.0),
                        alignment: Alignment.bottomRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. AI Voice Entry Action
                            _buildSpeedDialItem(
                              context: context,
                              isDark: isDark,
                              label: 'AI Voice Entry',
                              subtitle: 'Speak in Hindi / English',
                              icon: Icons.mic_rounded,
                              iconColor: Colors.white,
                              gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                              onTap: _openVoiceExpenseDialog,
                            ),
                            const SizedBox(height: 12),

                            // 2. Manual Typing Action
                            _buildSpeedDialItem(
                              context: context,
                              isDark: isDark,
                              label: 'Manual Entry',
                              subtitle: 'Type amount & category',
                              icon: Icons.edit_note_rounded,
                              iconColor: Colors.black,
                              gradientColors: const [Color(0xFF00D09C), Color(0xFF05B488)],
                              onTap: _openQuickAddExpense,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            _closeFabMenu();
            HapticFeedback.selectionClick();
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline_outlined),
              activeIcon: Icon(Icons.pie_chart),
              label: 'Budgets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Invoices',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance),
              label: 'Payments',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleFabMenu,
          tooltip: _isFabOpen ? 'Close Menu' : 'Add Expense',
          elevation: _isFabOpen ? 8 : 4,
          backgroundColor: _isFabOpen ? const Color(0xFFEF4444) : primaryColor,
          foregroundColor: _isFabOpen ? Colors.white : Colors.black,
          child: RotationTransition(
            turns: _rotateAnimation,
            child: Icon(
              _isFabOpen ? Icons.add : Icons.add,
              size: 28,
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      ),
    );
  }

  Widget _buildSpeedDialItem({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E232E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF2C3242) : const Color(0xFFE5E9F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action Round Floating Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ],
      ),
    );
  }
}
