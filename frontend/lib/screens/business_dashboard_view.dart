import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/expense.dart';
import '../models/business_sale.dart';
import '../models/business_profile.dart';
import '../models/payment_detail.dart';
import '../services/database_helper.dart';
import '../services/user_provider.dart';
import '../services/expense_provider.dart';
import '../services/app_update_service.dart';
import '../services/supabase_service.dart';
import '../utils/business_export_helper.dart';
import '../widgets/custom_toast.dart';
import 'add_business_sale_screen.dart';
import 'expense_entry_screen.dart';
import 'khata_screen.dart';
import 'invoice_screen.dart';
import 'calculator_hub_screen.dart';
import 'settings_screen.dart';
import 'business_catalog_screen.dart';
import 'barcode_label_generator_screen.dart';
import '../utils/app_strings.dart';

class BusinessDashboardView extends StatefulWidget {
  const BusinessDashboardView({super.key});

  @override
  State<BusinessDashboardView> createState() => _BusinessDashboardViewState();
}

class _BusinessDashboardViewState extends State<BusinessDashboardView> {
  bool _isLoading = true;
  BusinessProfile _businessProfile = BusinessProfile(id: 'default', businessName: 'My Business');
  List<BusinessSale> _sales = [];
  List<Expense> _businessExpenses = [];
  Map<String, double> _metrics = {};
  double _periodExpensesTotal = 0.0;
  double _totalLenaHai = 0.0;
  double _totalDenaHai = 0.0;

  String _filterPeriod = 'This Month'; // Today, This Week, This Month, Last Month, This Quarter, This FY, All Time, Custom Range
  DateTimeRange? _customSelectedRange;
  String _recentTab = 'sales'; // 'sales' or 'expenses'
  int _lastKnownBusinessVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final expProv = Provider.of<ExpenseProvider>(context);
    if (_lastKnownBusinessVersion != expProv.businessDataVersion) {
      _lastKnownBusinessVersion = expProv.businessDataVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDashboardData(isQuiet: true);
      });
    }
  }

  Future<void> _loadDashboardData({bool isQuiet = false}) async {
    if (!isQuiet) {
      setState(() => _isLoading = true);
    }
    try {
      final prof = await DatabaseHelper.instance.getBusinessProfile();
      final allSales = await DatabaseHelper.instance.getBusinessSales();

      final now = DateTime.now();
      DateTime start;
      DateTime end;

      if (_filterPeriod == 'Today') {
        start = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      } else if (_filterPeriod == 'This Week') {
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0, 0);
        final sunday = monday.add(const Duration(days: 6));
        end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
      } else if (_filterPeriod == 'This Month') {
        start = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999);
      } else if (_filterPeriod == 'Last Month') {
        final prevMonthLastDay = DateTime(now.year, now.month, 0);
        start = DateTime(prevMonthLastDay.year, prevMonthLastDay.month, 1, 0, 0, 0, 0);
        end = DateTime(prevMonthLastDay.year, prevMonthLastDay.month, prevMonthLastDay.day, 23, 59, 59, 999);
      } else if (_filterPeriod == 'This Quarter') {
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(now.year, quarterMonth, 1, 0, 0, 0, 0);
        final qEnd = DateTime(now.year, quarterMonth + 3, 0);
        end = DateTime(qEnd.year, qEnd.month, qEnd.day, 23, 59, 59, 999);
      } else if (_filterPeriod == 'This FY') {
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        start = DateTime(fyStartYear, 4, 1, 0, 0, 0, 0);
        end = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59, 999);
      } else if (_customSelectedRange != null) {
        start = DateTime(_customSelectedRange!.start.year, _customSelectedRange!.start.month, _customSelectedRange!.start.day, 0, 0, 0, 0);
        end = DateTime(_customSelectedRange!.end.year, _customSelectedRange!.end.month, _customSelectedRange!.end.day, 23, 59, 59, 999);
      } else {
        // All Time
        start = DateTime(2000, 1, 1, 0, 0, 0, 0);
        end = DateTime(2099, 12, 31, 23, 59, 59, 999);
      }

      bool isWithinRange(DateTime dt) {
        final local = dt.isUtc ? dt.toLocal() : dt;
        if (_filterPeriod == 'Today') {
          return local.year == now.year && local.month == now.month && local.day == now.day;
        }
        final localMs = local.millisecondsSinceEpoch;
        return localMs >= start.millisecondsSinceEpoch && localMs <= end.millisecondsSinceEpoch;
      }

      final periodSales = allSales.where((s) => isWithinRange(s.saleDate)).toList();

      final metrics = await DatabaseHelper.instance.getBusinessMetrics(start: start, end: end);

      // Fetch Business Operating Expenses (only business ledger)
      final expRows = await DatabaseHelper.instance.getExpenses(ledgerType: 'business');
      final List<Expense> periodExpenses = [];
      double bExp = 0.0;
      for (var e in expRows) {
        if (!e.isDeleted && isWithinRange(e.transactionDate)) {
          bExp += e.amount;
          periodExpenses.add(e);
        }
      }
      periodExpenses.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

      // Fetch Khata Dues (Strictly Business Ledger)
      final khataEntries = await DatabaseHelper.instance.getKhataEntries(ledgerType: 'business');
      double lenaHai = 0.0;
      double denaHai = 0.0;
      for (var k in khataEntries) {
        if (!k.isSettled && k.ledgerType == 'business') {
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
          _sales = periodSales;
          _businessExpenses = periodExpenses;
          _metrics = metrics;
          _periodExpensesTotal = bExp;
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

  Widget _buildAvatarFallback(UserProvider userProvider) {
    final name = userProvider.userProfile?['name']?.toString() ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFF1E293B),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          color: const Color(0xFFFFD700),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  void _showEditBusinessProfileDialog() async {
    final nameCtrl = TextEditingController(text: _businessProfile.businessName);
    final phoneCtrl = TextEditingController(text: _businessProfile.phone ?? '');
    final gstinCtrl = TextEditingController(text: _businessProfile.gstin ?? '');
    final addrCtrl = TextEditingController(text: _businessProfile.address ?? '');
    final upiCtrl = TextEditingController(text: _businessProfile.upiId ?? '');

    List<PaymentDetail> savedPayments = Provider.of<ExpenseProvider>(context, listen: false).paymentDetails;
    if (savedPayments.isEmpty) {
      savedPayments = await DatabaseHelper.instance.getPaymentDetails();
    }
    final validPayments = savedPayments.where((p) => p.upiId.trim().isNotEmpty).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E232D) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Edit Business Profile',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'My Business / Shop Name *',
                      hintText: 'e.g. Ramesh General Store',
                      prefixIcon: Icon(Icons.business_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Business Phone Number',
                      hintText: 'e.g. +91 9876543210',
                      prefixIcon: Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gstinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN (Optional)',
                      hintText: 'e.g. 27AAAAA0000A1Z5',
                      prefixIcon: Icon(Icons.receipt_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Office Address',
                      hintText: 'e.g. Shop 12, Main Market, Mumbai',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: upiCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Business UPI ID (for QR Code)',
                      hintText: 'e.g. storename@okaxis',
                      prefixIcon: const Icon(Icons.qr_code_rounded),
                      suffixIcon: upiCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                upiCtrl.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  if (validPayments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Text(
                          'Select from saved app UPI IDs:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: validPayments.map((p) {
                        final isSelected = upiCtrl.text.trim().toLowerCase() == p.upiId.trim().toLowerCase();
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              upiCtrl.text = p.upiId.trim();
                              setDialogState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF3B82F6)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.account_balance_wallet_outlined,
                                    size: 13,
                                    color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.name.isNotEmpty ? p.name : 'UPI',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${p.upiId})',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: isSelected
                                          ? const Color(0xFF3B82F6).withValues(alpha: 0.85)
                                          : (isDark ? Colors.white38 : Colors.black45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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

                  // Cloud Sync to Supabase business_profiles
                  try {
                    await SupabaseService.instance.upsertBusinessProfile(updated.toMap());
                  } catch (e) {
                    debugPrint('[BusinessDashboard] Cloud upsert profile note: $e');
                  }

                  if (mounted) {
                    setState(() => _businessProfile = updated);
                    Navigator.of(ctx).pop();
                    CustomToast.show(context, '✅ Business profile saved & synced! ☁️');
                  }
                },
                child: Text('Save Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMonthYearPicker() async {
    final now = DateTime.now();
    int selectedYear = _customSelectedRange != null ? _customSelectedRange!.start.year : now.year;
    int selectedMonth = _customSelectedRange != null ? _customSelectedRange!.start.month : now.month;

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
                  _customSelectedRange = DateTimeRange(start: start, end: end);
                  _filterPeriod = '${months[selectedMonth - 1]} $selectedYear';
                });
                _loadDashboardData(isQuiet: true);
              },
              child: const Text('Apply Month'),
            ),
          ],
        ),
      ),
    );
  }

  String _getActivePeriodSubtitle() {
    final now = DateTime.now();
    if (_filterPeriod == 'Today') {
      return 'Showing today (${DateFormat('dd MMM yyyy').format(now)})';
    } else if (_filterPeriod == 'This Week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return 'This Week (${DateFormat('dd MMM').format(monday)} - ${DateFormat('dd MMM yyyy').format(sunday)})';
    } else if (_filterPeriod == 'This Month') {
      return 'This Month (${DateFormat('MMMM yyyy').format(now)})';
    } else if (_filterPeriod == 'Last Month') {
      final prevMonthLastDay = DateTime(now.year, now.month, 0);
      return 'Last Month (${DateFormat('MMMM yyyy').format(prevMonthLastDay)})';
    } else if (_filterPeriod == 'This Quarter') {
      final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      final qNum = ((now.month - 1) ~/ 3) + 1;
      final qStart = DateTime(now.year, quarterMonth, 1);
      final qEnd = DateTime(now.year, quarterMonth + 3, 0);
      return 'Q$qNum (${DateFormat('MMM').format(qStart)} - ${DateFormat('MMM yyyy').format(qEnd)})';
    } else if (_filterPeriod == 'This FY') {
      final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
      return 'FY $fyStartYear-${(fyStartYear + 1).toString().substring(2)} (1 Apr $fyStartYear - 31 Mar ${fyStartYear + 1})';
    } else if (_customSelectedRange != null) {
      return '${DateFormat('dd MMM yyyy').format(_customSelectedRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customSelectedRange!.end)}';
    } else if (_filterPeriod.contains('202')) {
      return _filterPeriod;
    } else {
      return 'All time historical business records';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF3B82F6); // Sapphire Blue for Business

    double totalSales = 0.0;
    double totalGoodsCost = 0.0;
    for (var s in _sales) {
      totalSales += s.finalAmount;
      totalGoodsCost += s.totalPurchaseCost;
    }
    final netProfit = totalGoodsCost > 0
        ? (totalSales - totalGoodsCost - _periodExpensesTotal)
        : (totalSales - _periodExpensesTotal);
    final marginPercent = totalSales > 0 ? ((netProfit / totalSales) * 100) : 0.0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardData(isQuiet: true);
          await expenseProvider.triggerManualSync();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── TOP BUSINESS HEADER ───────────────────────────
            Row(
              children: [
                // User Avatar with Golden Ring
                GestureDetector(
                  onTap: _showEditBusinessProfileDialog,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700), // Vibrant Golden Ring
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                              blurRadius: 7,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: userProvider.userProfile?['photo_url'] != null &&
                                  userProvider.userProfile!['photo_url'].toString().isNotEmpty
                              ? Image.network(
                                  userProvider.userProfile!['photo_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarFallback(userProvider),
                                )
                              : _buildAvatarFallback(userProvider),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // User Name & Shop / Business Name with Pencil Edit
                Expanded(
                  child: InkWell(
                    onTap: _showEditBusinessProfileDialog,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userProvider.userProfile?['name']?.toString() ?? 'Business Owner',
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 13, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _businessProfile.businessName.isNotEmpty ? _businessProfile.businessName : 'My Business',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 12, color: Color(0xFF3B82F6)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Actions: Cloud Sync, Khata, Settings
                IconButton(
                  tooltip: 'Sync with Cloud',
                  onPressed: expenseProvider.isSyncing
                      ? null
                      : () async {
                          if (userProvider.userProfile?['id'] == 'guest-user-uuid') {
                            CustomToast.show(
                              context,
                              'Cloud Sync is only available for registered accounts. Please log in.',
                              isError: true,
                            );
                          } else {
                            CustomToast.show(context, 'Syncing business ledger with cloud...');
                            final success = await expenseProvider.triggerManualSync();
                            if (context.mounted) {
                              if (success) {
                                CustomToast.show(context, '☁️ Business sync completed!');
                                _loadDashboardData(isQuiet: true);
                              } else {
                                CustomToast.show(
                                  context,
                                  expenseProvider.syncErrorMessage ?? 'Sync failed. Operating offline.',
                                  isError: true,
                                );
                              }
                            }
                          }
                        },
                  icon: expenseProvider.isSyncing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                        )
                      : Icon(
                          expenseProvider.syncErrorMessage != null
                              ? Icons.cloud_off_outlined
                              : Icons.cloud_queue_outlined,
                          color: expenseProvider.syncErrorMessage != null
                              ? Colors.amber[800]
                              : const Color(0xFF3B82F6),
                          size: 22,
                        ),
                ),
                IconButton(
                  tooltip: 'Business Khata Ledger',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KhataScreen()),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF3B82F6), size: 22),
                ),
                IconButton(
                  tooltip: 'Export Tax & Sales Statements',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InvoiceScreen(initialTabIndex: 2)),
                  ),
                  icon: const Icon(Icons.file_download_outlined, color: Color(0xFF3B82F6), size: 22),
                ),
                ListenableBuilder(
                  listenable: AppUpdateService.instance,
                  builder: (context, _) {
                    final hasUpdate = AppUpdateService.instance.latestUpdateInfo?.hasUpdate ?? false;
                    return IconButton(
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      icon: Badge(
                        isLabelVisible: hasUpdate,
                        backgroundColor: const Color(0xFFEF4444),
                        smallSize: 8,
                        child: const Icon(Icons.settings_outlined, size: 22),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── PERIOD SELECTOR CHIPS ─────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...['Today', 'This Week', 'This Month', 'Last Month', 'This Quarter', 'This FY', 'All Time'].map((p) {
                    final isSelected = _filterPeriod == p && _customSelectedRange == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: primaryColor.withValues(alpha: 0.2),
                        onSelected: (val) {
                          setState(() {
                            _filterPeriod = p;
                            _customSelectedRange = null;
                          });
                          _loadDashboardData(isQuiet: true);
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
                        _filterPeriod.contains('202') // If month year formatted like "October 2026"
                            ? '🗓️ $_filterPeriod'
                            : 'Month & Year 🗓️',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _filterPeriod.contains('202') ? FontWeight.bold : FontWeight.normal,
                          color: _filterPeriod.contains('202') ? const Color(0xFF3B82F6) : null,
                        ),
                      ),
                      backgroundColor: _filterPeriod.contains('202')
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                          : null,
                      onPressed: _showMonthYearPicker,
                    ),
                  ),

                  // Custom Range Picker Chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF3B82F6)),
                      label: Text(
                        _customSelectedRange != null && !_filterPeriod.contains('202')
                            ? '${DateFormat('dd MMM').format(_customSelectedRange!.start)} - ${DateFormat('dd MMM').format(_customSelectedRange!.end)}'
                            : 'Custom Range 📅',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _customSelectedRange != null && !_filterPeriod.contains('202') ? FontWeight.bold : FontWeight.normal,
                          color: _customSelectedRange != null && !_filterPeriod.contains('202') ? const Color(0xFF3B82F6) : null,
                        ),
                      ),
                      backgroundColor: _customSelectedRange != null && !_filterPeriod.contains('202')
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                          : null,
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(2100, 12, 31),
                          initialDateRange: _customSelectedRange ??
                              DateTimeRange(
                                start: DateTime(DateTime.now().year, DateTime.now().month, 1),
                                end: DateTime.now(),
                              ),
                        );
                        if (picked != null) {
                          setState(() {
                            _customSelectedRange = picked;
                            _filterPeriod = 'Custom Range';
                          });
                          _loadDashboardData(isQuiet: true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Active Period Date Range Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getActivePeriodSubtitle(),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── LOW STOCK ALERT BANNER ────────────────────────
            Consumer<ExpenseProvider>(
              builder: (context, expProv, _) {
                final lowItems = expProv.lowStockBusinessItems;
                if (lowItems.isEmpty) return const SizedBox.shrink();

                final outOfStockCount = lowItems.where((it) => it.isOutOfStock).length;
                final lowStockCount = lowItems.where((it) => it.isLowStock).length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: outOfStockCount > 0 ? Colors.red.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: outOfStockCount > 0 ? Colors.red.withValues(alpha: 0.35) : Colors.orange.withValues(alpha: 0.35),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BusinessCatalogScreen(initialFilterLowStock: true),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: outOfStockCount > 0 ? Colors.red.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              outOfStockCount > 0 ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                              color: outOfStockCount > 0 ? Colors.redAccent : Colors.orange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  outOfStockCount > 0
                                      ? '⚠️ $outOfStockCount Out of Stock, $lowStockCount Low Stock'
                                      : '⚠️ $lowStockCount Items Running Low on Stock',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: outOfStockCount > 0 ? Colors.redAccent : Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to view and refill catalog inventory before it runs out.',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── HERO METRICS CARDS ─────────────────────────────
            Row(
              children: [
                // Sales (Cash-in)
                Expanded(
                  child: _buildMetricCard(
                    isDark: isDark,
                    title: '${AppStrings.tr(context, 'sales')} ($_filterPeriod)',
                    amount: '₹${totalSales.toStringAsFixed(0)}',
                    subtitle: '${_sales.length} bills generated',
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
                      title: '${AppStrings.tr(context, 'expenses')} ($_filterPeriod)',
                      amount: '₹${_periodExpensesTotal.toStringAsFixed(0)}',
                      subtitle: '${_businessExpenses.length} entries • Tap (+)',
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
                  color: netProfit >= 0 ? Colors.blue.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr(context, 'net_profit').toUpperCase(),
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
                      if (totalGoodsCost > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Includes ₹${totalGoodsCost.toStringAsFixed(0)} item cost',
                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white54),
                        ),
                      ],
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
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AppStrings.tr(context, 'to_receive'),
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AppStrings.tr(context, 'to_pay'),
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
            Text(AppStrings.tr(context, 'quick_actions'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildActionButton(
                  label: AppStrings.tr(context, 'biz_add_entry'),
                  subtitle: AppStrings.tr(context, 'biz_entry_sub'),
                  icon: Icons.add_circle_outline_rounded,
                  color: primaryColor,
                  onTap: _showAddEntryBottomSheet,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: AppStrings.tr(context, 'biz_invoices'),
                  subtitle: AppStrings.tr(context, 'biz_invoices_sub'),
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InvoiceScreen()),
                    );
                    _loadDashboardData(isQuiet: true);
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: AppStrings.tr(context, 'biz_khata_book'),
                  subtitle: AppStrings.tr(context, 'biz_khata_sub'),
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KhataScreen()),
                    );
                    _loadDashboardData(isQuiet: true);
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: AppStrings.tr(context, 'biz_more_tools'),
                  subtitle: AppStrings.tr(context, 'biz_tools_sub'),
                  icon: Icons.grid_view_rounded,
                  color: const Color(0xFF10B981),
                  onTap: _showMoreBusinessToolsModal,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── RECENT TRANSACTIONS (SALES & EXPENSES TOGGLE) ───────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.tr(context, 'recent_transactions'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(AppStrings.tr(context, 'biz_cash_flow_activity'), style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _recentTab = 'sales');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _recentTab == 'sales'
                              ? (isDark ? const Color(0xFF3B82F6) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _recentTab == 'sales' && !isDark
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.point_of_sale_rounded, size: 16, color: _recentTab == 'sales' ? (_recentTab == 'sales' && isDark ? Colors.white : const Color(0xFF3B82F6)) : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Sales (${_sales.length})',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _recentTab == 'sales' ? (_recentTab == 'sales' && isDark ? Colors.white : const Color(0xFF3B82F6)) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _recentTab = 'expenses');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _recentTab == 'expenses'
                              ? (isDark ? const Color(0xFFF59E0B) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _recentTab == 'expenses' && !isDark
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_rounded, size: 16, color: _recentTab == 'expenses' ? (_recentTab == 'expenses' && isDark ? Colors.white : const Color(0xFFD97706)) : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Expenses (${_businessExpenses.length})',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _recentTab == 'expenses' ? (_recentTab == 'expenses' && isDark ? Colors.white : const Color(0xFFD97706)) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── TAB CONTENT ──────────────────────────────────
            if (_recentTab == 'sales') ...[
              if (_sales.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('No Sales in $_filterPeriod', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Tap "+ New Sale" above to record your first customer bill!', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                )
              else
                ..._sales.map((sale) => _buildSaleTile(sale: sale, isDark: isDark, primaryColor: primaryColor)),
            ] else ...[
              if (_businessExpenses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('No Business Expenses in $_filterPeriod', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Tap "+ Business Expense" above to log stock, rent, salary or bills!', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                )
              else
                ..._businessExpenses.map((exp) => _buildExpenseTile(expense: exp, isDark: isDark)),
            ],
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

  void _showAddEntryBottomSheet() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Header Title
            Text(
              'Add New Entry',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'Select what you would like to record for your business',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Option 1: New Sale / Tax Invoice
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddBusinessSaleScreen()),
                );
                _loadDashboardData(isQuiet: true);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Sale / Tax Invoice',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Record customer sale, create GST tax invoice & bill',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Business Expense
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ExpenseEntryScreen(initialLedgerType: 'business'),
                  ),
                );
                _loadDashboardData(isQuiet: true);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Expense',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Log shop expenses, stock purchase, rent, utility bills',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFF59E0B)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreBusinessToolsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Header Title
            Text(
              'Business Tools & Features',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'Product barcodes, stickers, inventory catalog & agricultural rates',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Option 1: Barcode & QR Label Maker (NEW)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BarcodeLabelGeneratorScreen()),
                );
                _loadDashboardData(isQuiet: true);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D09C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00D09C).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D09C), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Barcode & QR Label Maker',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('NEW', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Generate printable A4 sticker sheets for items with price & SKU',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF00D09C)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Product Catalog & Stock
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BusinessCatalogScreen()),
                );
                _loadDashboardData(isQuiet: true);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product Catalog & Inventory',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage items, buy/sell prices, stock levels & low stock alerts',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 3: Mandi & Crop Calculator
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalculatorHubScreen(initialTabIndex: 1)),
                );
                _loadDashboardData(isQuiet: true);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mandi Price & Crop Calculator',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mandi unit rate conversion & AI voice market price analyzer',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFF59E0B)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    String? subtitle,
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.28), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: color.withValues(alpha: 0.82),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewCustomerInvoicePdf(BusinessSale sale) async {
    CustomToast.show(context, 'Generating Tax Invoice PDF...');
    final file = await BusinessExportHelper.generateCustomerInvoicePdf(sale, _businessProfile);
    if (!mounted) return;
    if (file != null) {
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

  Future<void> _editSale(BusinessSale sale) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBusinessSaleScreen(existingSale: sale),
      ),
    );
    if (res == true) {
      _loadDashboardData();
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
      if (mounted) {
        Provider.of<ExpenseProvider>(context, listen: false).notifyBusinessDataChanged();
        CustomToast.show(context, 'Sale deleted');
        _loadDashboardData(isQuiet: true);
      }
    }
  }

  void _showSaleOptionsBottomSheet(BusinessSale sale) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${sale.customerName} • #${sale.invoiceNo}',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${sale.finalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF3B82F6)),
                title: const Text('View & Download Tax Invoice PDF'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _viewCustomerInvoicePdf(sale);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.green),
                title: const Text('Share Invoice on WhatsApp'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareCustomerInvoiceWhatsApp(sale);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.amber),
                title: const Text('Edit Sale / Bill Details'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _editSale(sale);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Invoice', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteSale(sale);
                },
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
    final localDate = sale.saleDate.isUtc ? sale.saleDate.toLocal() : sale.saleDate;
    final dateStr = DateFormat('dd MMM, hh:mm a').format(localDate);
    final isPaid = sale.balanceDue <= 0;

    return Dismissible(
      key: ValueKey(sale.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete Invoice #${sale.invoiceNo}?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Text('Are you sure you want to delete this sale of ₹${sale.finalAmount.toStringAsFixed(2)} for ${sale.customerName}?'),
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
      },
      onDismissed: (direction) async {
        await DatabaseHelper.instance.deleteBusinessSale(sale.id);
        if (mounted) {
          Provider.of<ExpenseProvider>(context, listen: false).notifyBusinessDataChanged();
          CustomToast.show(context, '🗑️ Invoice #${sale.invoiceNo} deleted');
          _loadDashboardData(isQuiet: true);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('Swipe to Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 8),
            Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: InkWell(
        onTap: () => _showSaleOptionsBottomSheet(sale),
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
                backgroundColor: (isPaid ? Colors.green : Colors.redAccent).withValues(alpha: 0.15),
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
                        Row(
                          children: [
                            Text(
                              isPaid ? 'PAID' : 'Due: ₹${sale.balanceDue.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? Colors.green : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _editSale(sale),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewExpenseVoucherPdf(Expense expense) async {
    CustomToast.show(context, 'Generating Payment Voucher PDF...');
    final file = await BusinessExportHelper.generateExpenseVoucherPdf(expense, _businessProfile);
    if (!mounted) return;
    if (file != null) {
      await OpenFile.open(file.path);
    } else {
      CustomToast.show(context, 'Failed to generate PDF', isError: true);
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(editExpense: expense, initialLedgerType: 'business'),
      ),
    );
    if (res == true) {
      _loadDashboardData();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Business Expense?'),
        content: Text('Are you sure you want to delete "${expense.category}" expense of ₹${expense.amount.toStringAsFixed(2)}?'),
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
      await DatabaseHelper.instance.deleteExpense(expense.id);
      if (mounted) {
        Provider.of<ExpenseProvider>(context, listen: false).notifyBusinessDataChanged();
        CustomToast.show(context, 'Expense deleted');
        _loadDashboardData(isQuiet: true);
      }
    }
  }

  void _showExpenseOptionsBottomSheet(Expense expense) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      expense.category,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${expense.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFFF59E0B)),
                title: const Text('View & Download Payment Voucher PDF'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _viewExpenseVoucherPdf(expense);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                title: const Text('Edit Business Expense'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _editExpense(expense);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Expense', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteExpense(expense);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile({
    required Expense expense,
    required bool isDark,
  }) {
    final localDate = expense.transactionDate.isUtc ? expense.transactionDate.toLocal() : expense.transactionDate;
    final dateStr = DateFormat('dd MMM, hh:mm a').format(localDate);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense?'),
            content: Text('Are you sure you want to delete "${expense.category}" expense of ₹${expense.amount.toStringAsFixed(2)}?'),
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
      },
      onDismissed: (direction) async {
        await DatabaseHelper.instance.deleteExpense(expense.id);
        if (mounted) {
          Provider.of<ExpenseProvider>(context, listen: false).notifyBusinessDataChanged();
          CustomToast.show(context, '🗑️ Expense deleted');
          _loadDashboardData(isQuiet: true);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('Swipe to Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 8),
            Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: InkWell(
        onTap: () => _showExpenseOptionsBottomSheet(expense),
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                child: const Icon(
                  Icons.receipt_rounded,
                  color: Color(0xFFF59E0B),
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
                          expense.category,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '₹${expense.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            expense.description.isNotEmpty ? '${expense.description} • $dateStr' : dateStr,
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _editExpense(expense),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
