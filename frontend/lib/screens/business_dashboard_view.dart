import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/business_sale.dart';
import '../models/business_profile.dart';
import '../services/database_helper.dart';
import '../services/user_provider.dart';
import '../widgets/custom_toast.dart';
import 'add_business_sale_screen.dart';
import 'expense_entry_screen.dart';
import 'khata_screen.dart';
import 'invoice_screen.dart';
import 'calculator_hub_screen.dart';

class BusinessDashboardView extends StatefulWidget {
  const BusinessDashboardView({super.key});

  @override
  State<BusinessDashboardView> createState() => _BusinessDashboardViewState();
}

class _BusinessDashboardViewState extends State<BusinessDashboardView> {
  bool _isLoading = true;
  BusinessProfile _businessProfile = BusinessProfile(id: 'default', businessName: 'My Business');
  List<BusinessSale> _sales = [];
  Map<String, double> _metrics = {};
  double _todayExpenses = 0.0;
  double _totalLenaHai = 0.0;
  double _totalDenaHai = 0.0;

  String _filterPeriod = 'Today'; // Today, This Week, This Month, All Time

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final prof = await DatabaseHelper.instance.getBusinessProfile();
      final sales = await DatabaseHelper.instance.getBusinessSales(limit: 50);

      final now = DateTime.now();
      DateTime start;
      DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      if (_filterPeriod == 'Today') {
        start = DateTime(now.year, now.month, now.day);
      } else if (_filterPeriod == 'This Week') {
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
      } else if (_filterPeriod == 'This Month') {
        start = DateTime(now.year, now.month, 1);
      } else {
        start = DateTime(2020, 1, 1);
      }

      final metrics = await DatabaseHelper.instance.getBusinessMetrics(start: start, end: end);

      // Fetch Business Operating Expenses (only business ledger)
      final expRows = await DatabaseHelper.instance.getExpenses(ledgerType: 'business');
      double bExp = 0.0;
      for (var e in expRows) {
        if (e.transactionDate.isAfter(start) && e.transactionDate.isBefore(end)) {
          bExp += e.amount;
        }
      }

      // Fetch Khata Dues
      final khataEntries = await DatabaseHelper.instance.getKhataEntries();
      double lenaHai = 0.0;
      double denaHai = 0.0;
      for (var k in khataEntries) {
        if (!k.isSettled) {
          if (k.type == 'lent') {
            lenaHai += k.amount;
          } else {
            denaHai += k.amount;
          }
        }
      }

      if (mounted) {
        setState(() {
          _businessProfile = prof;
          _sales = sales;
          _metrics = metrics;
          _todayExpenses = bExp;
          _totalLenaHai = lenaHai;
          _totalDenaHai = denaHai;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[BusinessDashboard] Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditBusinessProfileDialog() {
    final nameCtrl = TextEditingController(text: _businessProfile.businessName);
    final phoneCtrl = TextEditingController(text: _businessProfile.phone ?? '');
    final gstinCtrl = TextEditingController(text: _businessProfile.gstin ?? '');
    final addrCtrl = TextEditingController(text: _businessProfile.address ?? '');
    final upiCtrl = TextEditingController(text: _businessProfile.upiId ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('🏢 Edit Business Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Business / Shop Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Business Phone Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gstinCtrl,
                decoration: const InputDecoration(labelText: 'GSTIN (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Shop / Office Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: upiCtrl,
                decoration: const InputDecoration(labelText: 'Business UPI ID (for QR Code)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim().isEmpty ? 'My Business' : nameCtrl.text.trim();
              final updated = BusinessProfile(
                id: _businessProfile.id,
                businessName: newName,
                phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                gstin: gstinCtrl.text.trim().isNotEmpty ? gstinCtrl.text.trim() : null,
                address: addrCtrl.text.trim().isNotEmpty ? addrCtrl.text.trim() : null,
                upiId: upiCtrl.text.trim().isNotEmpty ? upiCtrl.text.trim() : null,
              );
              await DatabaseHelper.instance.saveBusinessProfile(updated);
              if (mounted) {
                setState(() => _businessProfile = updated);
                Navigator.of(ctx).pop();
                CustomToast.show(context, '✅ Business details saved!');
              }
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF3B82F6); // Sapphire Blue for Business

    final totalSales = _metrics['totalSales'] ?? 0.0;
    final netProfit = totalSales - _todayExpenses;
    final marginPercent = totalSales > 0 ? ((netProfit / totalSales) * 100) : 0.0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── TOP BUSINESS HEADER & MODE SWITCHER ───────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showEditBusinessProfileDialog,
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.storefront_rounded, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _businessProfile.businessName,
                                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 14, color: Colors.grey),
                                ],
                              ),
                              Text(
                                '🏢 Business Mode Active',
                                style: GoogleFonts.inter(fontSize: 11.5, color: primaryColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mode Toggle Pill
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await userProvider.toggleAppMode(false); // Switch to Personal Mode
                    CustomToast.show(context, 'Switched to 🟢 Personal Mode');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D09C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00D09C).withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00D09C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Switch to Personal',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── PERIOD SELECTOR CHIPS ─────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Today', 'This Week', 'This Month', 'All Time'].map((p) {
                  final isSelected = _filterPeriod == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: primaryColor.withOpacity(0.2),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _filterPeriod = p);
                          _loadDashboardData();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ── HERO METRICS CARDS ─────────────────────────────
            Row(
              children: [
                // Sales (Cash-in)
                Expanded(
                  child: _buildMetricCard(
                    isDark: isDark,
                    title: 'Sales ($_filterPeriod)',
                    amount: '₹${totalSales.toStringAsFixed(0)}',
                    subtitle: '${_metrics['saleCount']?.toInt() ?? 0} bills generated',
                    icon: Icons.trending_up_rounded,
                    iconColor: Colors.greenAccent.shade700,
                    accentColor: Colors.greenAccent.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                // Expenses (Cash-out)
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExpenseEntryScreen(initialLedgerType: 'business'),
                        ),
                      );
                      _loadDashboardData();
                    },
                    child: _buildMetricCard(
                      isDark: isDark,
                      title: 'Business Expense',
                      amount: '₹${_todayExpenses.toStringAsFixed(0)}',
                      subtitle: 'Tap to log (+)',
                      icon: Icons.trending_down_rounded,
                      iconColor: Colors.orangeAccent,
                      accentColor: Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Net Profit & Margin Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: netProfit >= 0
                      ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                      : [const Color(0xFF7F1D1D), const Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: netProfit >= 0 ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NET PROFIT & MARGIN',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${netProfit.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: netProfit >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${marginPercent.toStringAsFixed(1)}% Margin',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: netProfit >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── KHATA DUES (LENA HAI / DENA HAI) ───────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('To Receive (Lena Hai)', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_totalLenaHai.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text('To Pay (Dena Hai)', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_totalDenaHai.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── QUICK ACTIONS GRID ─────────────────────────────
            Text('Business Quick Actions', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildActionButton(
                  label: '➕ New Sale',
                  icon: Icons.point_of_sale_rounded,
                  color: primaryColor,
                  onTap: () async {
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddBusinessSaleScreen()),
                    );
                    if (res == true) _loadDashboardData();
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: '🧾 Invoices',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InvoiceScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: '📖 Khata Book',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KhataScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: '🛒 Mandi Calc',
                  icon: Icons.calculate_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalculatorHubScreen(initialTabIndex: 1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── RECENT SALES & INVOICES LIST ───────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Sales & Invoices', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_sales.isNotEmpty)
                  Text('${_sales.length} records', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),

            if (_sales.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text('No Sales Recorded Yet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Tap "+ New Sale" above to record your first customer bill!', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ..._sales.map((sale) => _buildSaleTile(sale: sale, isDark: isDark, primaryColor: primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color accentColor,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(amount, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor)),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaleTile({
    required BusinessSale sale,
    required bool isDark,
    required Color primaryColor,
  }) {
    final dateStr = DateFormat('dd MMM, hh:mm a').format(sale.saleDate);
    final isPaid = sale.balanceDue <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: (isPaid ? Colors.green : Colors.redAccent).withOpacity(0.15),
            child: Icon(
              isPaid ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
              color: isPaid ? Colors.green : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sale.customerName,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '₹${sale.finalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${sale.invoiceNo} • $dateStr',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      isPaid ? 'PAID' : 'Due: ₹${sale.balanceDue.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPaid ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
