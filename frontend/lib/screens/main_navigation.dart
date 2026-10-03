import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import 'dashboard_screen.dart';
import 'business_dashboard_view.dart';
import 'budget_screen.dart';
import 'analytics_screen.dart';
import 'invoice_screen.dart';
import 'khata_screen.dart';
import 'payment_details_screen.dart';
import 'expense_entry_screen.dart';
import 'add_business_sale_screen.dart';
import 'ai_advisor_screen.dart';
import '../widgets/voice_expense_dialog.dart';
import '../widgets/monthly_rollover_dialog.dart';

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
      duration: const Duration(milliseconds: 260),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      if (expenseProvider.expenses.isEmpty &&
          expenseProvider.budgets.isEmpty &&
          expenseProvider.khataEntries.isEmpty &&
          expenseProvider.splitBills.isEmpty &&
          expenseProvider.subscriptions.isEmpty) {
        await expenseProvider.restoreFromCloud();
      } else {
        await expenseProvider.triggerQuietSync();
      }

      // Check and trigger smart dual-mode Monthly Rollover if new month started
      if (mounted) {
        await MonthlyRolloverDialog.checkAndShowRollover(context);
      }
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

  List<Widget> _getScreens(bool isBusiness) {
    if (isBusiness) {
      return const [
        BusinessDashboardView(),
        InvoiceScreen(),
        KhataScreen(),
        AnalyticsScreen(),
        PaymentDetailsScreen(),
      ];
    }
    return const [
      DashboardScreen(),
      BudgetScreen(),
      AnalyticsScreen(),
      InvoiceScreen(),
      PaymentDetailsScreen(),
    ];
  }

  void _openQuickAddExpense() {
    _closeFabMenu();
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseEntryScreen(initialLedgerType: isBusiness ? 'business' : 'personal'),
      ),
    );
  }

  void _openNewBusinessSale() {
    _closeFabMenu();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddBusinessSaleScreen(),
      ),
    );
  }

  void _openOcrScanner() {
    _closeFabMenu();
    final isBusiness = Provider.of<UserProvider>(context, listen: false).isBusinessMode;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseEntryScreen(openCameraScanner: true, initialLedgerType: isBusiness ? 'business' : 'personal'),
      ),
    );
  }

  void _openVoiceExpenseDialog() {
    _closeFabMenu();
    VoiceExpenseDialog.show(context);
  }

  bool _isFabVisible = true;
  bool _isNavigating = false;

  void _openAiAdvisorChat() {
    if (_isNavigating) return;
    _isNavigating = true;
    _closeFabMenu();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AiAdvisorScreen(),
      ),
    ).then((_) {
      _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isBusiness = userProvider.isBusinessMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final currentScreens = _getScreens(isBusiness);

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
            _isFabVisible = true;
          });
        }
      },
      child: Scaffold(
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (_currentIndex == 0 && notification.metrics.axis == Axis.vertical) {
              if (notification.direction == ScrollDirection.reverse) {
                // User is scrolling DOWN -> smoothly hide floating buttons
                if (_isFabVisible && notification.metrics.pixels > 50) {
                  setState(() {
                    _isFabVisible = false;
                    _closeFabMenu();
                  });
                }
              } else if (notification.direction == ScrollDirection.forward || notification.metrics.pixels <= 20) {
                // User is scrolling UP or near top -> smoothly show floating buttons
                if (!_isFabVisible) {
                  setState(() {
                    _isFabVisible = true;
                  });
                }
              }
            }
            return false;
          },
          child: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: currentScreens,
              ),

            // ══════════════════════════════════════════════════════
            // BACKDROP OVERLAY (Dismisses FAB menu on tap anywhere)
            // ══════════════════════════════════════════════════════
            if (_currentIndex == 0 && _isFabOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFabMenu,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, child) {
                      return Container(
                        color: Colors.black.withValues(alpha: 0.55 * _expandAnimation.value),
                      );
                    },
                  ),
                ),
              ),

            // ══════════════════════════════════════════════════════
            // FLOATING GROW EXPENSE AI CHAT BUTTON (Auto-hides on scroll down, shows on scroll up)
            // ══════════════════════════════════════════════════════
            if (_currentIndex == 0)
              Positioned(
                right: 18,
                bottom: 84, // Directly above the + FAB button
                child: AnimatedScale(
                  scale: (_isFabVisible && !_isFabOpen) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: (_isFabVisible && !_isFabOpen) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (_isFabVisible && !_isFabOpen)
                            ? () {
                                HapticFeedback.lightImpact();
                                _openAiAdvisorChat();
                              }
                            : null,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isBusiness ? const Color(0xFF3B82F6) : const Color(0xFF00D09C)).withValues(alpha: 0.85),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isBusiness ? const Color(0xFF3B82F6) : const Color(0xFF00D09C)).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isBusiness ? Icons.insights_rounded : Icons.chat_bubble_rounded,
                              color: isBusiness ? const Color(0xFF3B82F6) : const Color(0xFF00D09C),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ══════════════════════════════════════════════════════
              // SPEED DIAL POPUP ITEMS (Mode-aware actions)
              // ══════════════════════════════════════════════════════
              if (_currentIndex == 0 && (_isFabOpen || _fabAnimationController.isAnimating))
                Positioned(
                  right: 16,
                  bottom: 84, // Replaces chat button position and stacks upwards
                  child: AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _expandAnimation.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: _expandAnimation.value.clamp(0.0, 1.0),
                          alignment: Alignment.bottomRight,
                          child: isBusiness
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. New Sale & GST Bill
                                    _buildSpeedDialItem(
                                      context: context,
                                      isDark: isDark,
                                      label: 'New Sale / GST Bill',
                                      subtitle: 'Cash / Udhar + Bill PDF',
                                      icon: Icons.add_shopping_cart_rounded,
                                      iconColor: Colors.black,
                                      gradientColors: const [Color(0xFF00D09C), Color(0xFF05B488)],
                                      onTap: _openNewBusinessSale,
                                    ),
                                    const SizedBox(height: 12),

                                    // 2. Business Expense
                                    _buildSpeedDialItem(
                                      context: context,
                                      isDark: isDark,
                                      label: 'Business Expense',
                                      subtitle: 'Stock, Rent, Bills, Salary',
                                      icon: Icons.receipt_rounded,
                                      iconColor: Colors.white,
                                      gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                                      onTap: _openQuickAddExpense,
                                    ),
                                    const SizedBox(height: 12),

                                    // 3. AI Voice / OCR Scan
                                    _buildSpeedDialItem(
                                      context: context,
                                      isDark: isDark,
                                      label: 'AI Voice & Scan',
                                      subtitle: 'Speak or scan expense',
                                      icon: Icons.mic_rounded,
                                      iconColor: Colors.white,
                                      gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                                      onTap: _openVoiceExpenseDialog,
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. AI Voice Entry Action
                                    _buildSpeedDialItem(
                                      context: context,
                                      isDark: isDark,
                                      label: 'AI Voice Entry',
                                      subtitle: 'Speak in any language',
                                      icon: Icons.mic_rounded,
                                      iconColor: Colors.white,
                                      gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                                      onTap: _openVoiceExpenseDialog,
                                    ),
                                    const SizedBox(height: 12),

                                    // 2. Smart OCR Receipt Scanner
                                    _buildSpeedDialItem(
                                      context: context,
                                      isDark: isDark,
                                      label: 'Smart OCR Scan',
                                      subtitle: 'Scan bills & receipts',
                                      icon: Icons.document_scanner_rounded,
                                      iconColor: Colors.white,
                                      gradientColors: const [Color(0xFF2563EB), Color(0xFF38BDF8)],
                                      onTap: _openOcrScanner,
                                    ),
                                    const SizedBox(height: 12),

                                    // 3. Manual Typing Action
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
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            _closeFabMenu();
            HapticFeedback.selectionClick();
            setState(() {
              _currentIndex = index;
              _isFabVisible = true;
            });
          },
          items: isBusiness
              ? const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.storefront_outlined),
                    activeIcon: Icon(Icons.storefront_rounded),
                    label: 'Business',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    activeIcon: Icon(Icons.receipt_long),
                    label: 'Invoices',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.menu_book_outlined),
                    activeIcon: Icon(Icons.menu_book_rounded),
                    label: 'Khata',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_outlined),
                    activeIcon: Icon(Icons.bar_chart),
                    label: 'Analytics',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_outlined),
                    activeIcon: Icon(Icons.account_balance),
                    label: 'Payments',
                  ),
                ]
              : const [
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
        floatingActionButton: _currentIndex == 0
            ? AnimatedScale(
                scale: _isFabVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _isFabVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: FloatingActionButton(
                    onPressed: _isFabVisible ? _toggleFabMenu : null,
                    tooltip: _isFabOpen ? 'Close Menu' : 'Add Expense',
                    elevation: _isFabOpen ? 8 : 4,
                    backgroundColor: _isFabOpen ? const Color(0xFFEF4444) : primaryColor,
                    foregroundColor: _isFabOpen ? Colors.white : Colors.black,
                    child: RotationTransition(
                      turns: _rotateAnimation,
                      child: const Icon(
                        Icons.add,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              )
            : null,
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
