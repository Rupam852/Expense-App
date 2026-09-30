import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/subscription_item.dart';
import '../services/expense_provider.dart';
import '../widgets/custom_toast.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openAddSubscriptionSheet({SubscriptionItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubscriptionEntrySheet(
        existingItem: existing,
        onSave: (item) async {
          final provider = Provider.of<ExpenseProvider>(context, listen: false);
          if (existing == null) {
            await provider.addSubscription(
              name: item.name,
              amount: item.amount,
              billingCycle: item.billingCycle,
              nextRenewalDate: item.nextRenewalDate,
              category: item.category,
              autoRenewal: item.autoRenewal,
              reminderDaysBefore: item.reminderDaysBefore,
              paymentMethod: item.paymentMethod,
              note: item.note,
            );
            if (mounted) {
              CustomToast.show(context, '🔁 Subscription "${item.name}" added!');
            }
          } else {
            await provider.updateSubscription(item);
            if (mounted) {
              CustomToast.show(context, '✅ Subscription updated');
            }
          }
        },
      ),
    );
  }

  Future<void> _shareSubscriptionDetails(SubscriptionItem item) async {
    final formattedAmt = _currencyFormat.format(item.amount);
    final formattedDate = DateFormat('dd MMM yyyy').format(item.nextRenewalDate);
    final msg = '🔔 Subscription Alert: ${item.name}\n'
        '• Amount: $formattedAmt / ${item.billingCycle}\n'
        '• Next Renewal: $formattedDate\n'
        '• Category: ${item.category}\n'
        '• Status: ${item.isActive ? "Active" : "Paused"}\n'
        'Managed on Groww Expense App 🚀';

    await SharePlus.instance.share(
      ShareParams(
        text: msg,
        subject: '${item.name} Renewal Details',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Subscriptions & Bills',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Add Subscription',
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00D09C)),
            onPressed: () => _openAddSubscriptionSheet(),
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          final allSubs = provider.subscriptions.where((s) => !s.isDeleted).toList();

          final filtered = allSubs.where((s) {
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchesName = s.name.toLowerCase().contains(q);
              final matchesCat = s.category.toLowerCase().contains(q);
              if (!matchesName && !matchesCat) return false;
            }
            return true;
          }).toList();

          final dueSoonList = filtered.where((s) => s.isDueSoon).toList();
          final activeList = filtered.where((s) => s.isActive).toList();
          final pausedList = filtered.where((s) => !s.isActive).toList();

          return Column(
            children: [
              // 1. Summary Header Card
              _buildSummaryHeader(
                isDark: isDark,
                monthlyCost: provider.totalMonthlySubscriptionCost,
                annualCost: provider.totalAnnualSubscriptionCost,
                dueSoonCount: provider.subscriptionsDueThisWeekCount,
              ),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search subscriptions (e.g. Netflix, Wifi)...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF181B22) : const Color(0xFFF4F6F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 3. Tab Bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                indicatorColor: const Color(0xFF00D09C),
                indicatorWeight: 3,
                labelColor: const Color(0xFF00D09C),
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'All (${filtered.length})'),
                  Tab(text: 'Due Soon (${dueSoonList.length})'),
                  Tab(text: 'Active (${activeList.length})'),
                  Tab(text: 'Paused (${pausedList.length})'),
                ],
              ),

              // 4. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSubscriptionList(filtered, isDark),
                    _buildSubscriptionList(dueSoonList, isDark),
                    _buildSubscriptionList(activeList, isDark),
                    _buildSubscriptionList(pausedList, isDark),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSubscriptionSheet(),
        backgroundColor: const Color(0xFF00D09C),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Subscription',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader({
    required bool isDark,
    required double monthlyCost,
    required double annualCost,
    required int dueSoonCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2B313F) : const Color(0xFFE5E9F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Monthly Normalized
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONTHLY SPEND',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_currencyFormat.format(monthlyCost)}/mo',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D09C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          // Annual Total & Due Soon Badge
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ANNUAL COST',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (dueSoonCount > 0) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8A00).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$dueSoonCount DUE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF8A00),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_currencyFormat.format(annualCost)}/yr',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionList(List<SubscriptionItem> list, bool isDark) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subscriptions_outlined, size: 54, color: Colors.grey[400]),
            const SizedBox(height: 14),
            Text(
              'No subscriptions found',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "+ Add Subscription" to track recurring bills & renewals',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildSubscriptionCard(item, isDark);
      },
    );
  }

  Widget _buildSubscriptionCard(SubscriptionItem item, bool isDark) {
    final formattedRenewal = DateFormat('dd MMM yyyy').format(item.nextRenewalDate);
    final days = item.daysUntilRenewal;

    Color badgeColor;
    String badgeText;

    if (!item.isActive) {
      badgeColor = Colors.grey;
      badgeText = 'PAUSED';
    } else if (item.isOverdue) {
      badgeColor = const Color(0xFFEB5757);
      badgeText = 'OVERDUE';
    } else if (days == 0) {
      badgeColor = const Color(0xFFEB5757);
      badgeText = 'RENEW TODAY';
    } else if (days <= 3) {
      badgeColor = const Color(0xFFFF8A00);
      badgeText = 'IN $days DAYS';
    } else {
      badgeColor = const Color(0xFF00D09C);
      badgeText = 'IN $days DAYS';
    }

    final initial = item.name.trim().isNotEmpty ? item.name.trim()[0].toUpperCase() : 'S';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isDueSoon || item.isOverdue
              ? badgeColor.withValues(alpha: 0.5)
              : isDark
                  ? const Color(0xFF2B313F)
                  : const Color(0xFFE5E9F0),
          width: item.isDueSoon || item.isOverdue ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            _currencyFormat.format(item.amount),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Renews on $formattedRenewal',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${item.billingCycle.toUpperCase()} • ${item.category}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
                          ),
                          if (item.paymentMethod != null && item.paymentMethod!.isNotEmpty) ...[
                            Text(' • ${item.paymentMethod}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1-Tap Mark Renewed
                ElevatedButton.icon(
                  onPressed: () {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    provider.markSubscriptionRenewed(item.id, logExpenseRecord: true);
                    CustomToast.show(context, '🎉 ${item.name} renewed & expense logged!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D09C).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF00D09C),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.autorenew_rounded, size: 15),
                  label: Text(
                    'Mark Renewed',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),

                Row(
                  children: [
                    // Pause / Resume Switch
                    IconButton(
                      tooltip: item.isActive ? 'Pause' : 'Resume',
                      icon: Icon(
                        item.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                        color: item.isActive ? Colors.amber[700] : const Color(0xFF00D09C),
                        size: 20,
                      ),
                      onPressed: () {
                        final provider = Provider.of<ExpenseProvider>(context, listen: false);
                        provider.toggleSubscriptionActive(item.id, !item.isActive);
                        CustomToast.show(context, item.isActive ? 'Subscription paused' : 'Subscription resumed');
                      },
                    ),

                    // Share
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                      onPressed: () => _shareSubscriptionDetails(item),
                    ),

                    // More Popup Menu (Edit/Delete)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        final provider = Provider.of<ExpenseProvider>(context, listen: false);
                        if (val == 'edit') {
                          _openAddSubscriptionSheet(existing: item);
                        } else if (val == 'delete') {
                          provider.deleteSubscription(item.id);
                          CustomToast.show(context, 'Subscription deleted');
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Color(0xFFEB5757)),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Color(0xFFEB5757))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionEntrySheet extends StatefulWidget {
  final SubscriptionItem? existingItem;
  final ValueChanged<SubscriptionItem> onSave;

  const _SubscriptionEntrySheet({this.existingItem, required this.onSave});

  @override
  State<_SubscriptionEntrySheet> createState() => _SubscriptionEntrySheetState();
}

class _SubscriptionEntrySheetState extends State<_SubscriptionEntrySheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _noteController = TextEditingController();

  String _billingCycle = 'monthly';
  DateTime _nextRenewalDate = DateTime.now().add(const Duration(days: 30));
  String _category = 'Subscription';
  int _reminderDays = 2;

  final List<Map<String, dynamic>> _presets = [
    {'name': 'Netflix', 'amt': '649', 'cycle': 'monthly', 'cat': 'Subscription'},
    {'name': 'Spotify', 'amt': '119', 'cycle': 'monthly', 'cat': 'Subscription'},
    {'name': 'Prime Video', 'amt': '1499', 'cycle': 'yearly', 'cat': 'Subscription'},
    {'name': 'YouTube Premium', 'amt': '149', 'cycle': 'monthly', 'cat': 'Subscription'},
    {'name': 'Disney+ Hotstar', 'amt': '899', 'cycle': 'yearly', 'cat': 'Subscription'},
    {'name': 'Airtel / Jio WiFi', 'amt': '999', 'cycle': 'monthly', 'cat': 'Bills & recharges'},
    {'name': 'House Rent', 'amt': '12000', 'cycle': 'monthly', 'cat': 'Rent'},
    {'name': 'Gym / Cult.fit', 'amt': '1500', 'cycle': 'monthly', 'cat': 'Fitness'},
    {'name': 'ChatGPT Plus', 'amt': '1999', 'cycle': 'monthly', 'cat': 'Subscription'},
    {'name': 'SIP Investment', 'amt': '5000', 'cycle': 'monthly', 'cat': 'Investment'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameController.text = item.name;
      _amountController.text = item.amount.toStringAsFixed(0);
      _billingCycle = item.billingCycle;
      _nextRenewalDate = item.nextRenewalDate;
      _category = item.category;
      _reminderDays = item.reminderDaysBefore;
      _paymentMethodController.text = item.paymentMethod ?? '';
      _noteController.text = item.note ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _paymentMethodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _nameController.text = preset['name'];
      _amountController.text = preset['amt'];
      _billingCycle = preset['cycle'];
      _category = preset['cat'];
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (name.isEmpty) {
      CustomToast.show(context, 'Please enter subscription name', isError: true);
      return;
    }
    if (amount <= 0) {
      CustomToast.show(context, 'Please enter a valid amount', isError: true);
      return;
    }

    final item = SubscriptionItem(
      id: widget.existingItem?.id ?? '',
      name: name,
      amount: amount,
      billingCycle: _billingCycle,
      nextRenewalDate: _nextRenewalDate,
      category: _category,
      reminderDaysBefore: _reminderDays,
      paymentMethod: _paymentMethodController.text.trim(),
      note: _noteController.text.trim(),
      isActive: widget.existingItem?.isActive ?? true,
    );

    widget.onSave(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingItem == null ? 'Add Subscription / Recurring Bill' : 'Edit Subscription',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Preset Chips (Only when adding)
            if (widget.existingItem == null) ...[
              Text(
                'QUICK PRESETS',
                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _presets.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        label: Text(p['name']),
                        onPressed: () => _applyPreset(p),
                        backgroundColor: isDark ? const Color(0xFF1E222D) : const Color(0xFFF4F6F9),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Subscription / Bill Name *',
                hintText: 'e.g. Netflix, Wifi, Cult.fit, House Rent',
                prefixIcon: const Icon(Icons.subscriptions_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Amount & Billing Cycle
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹) *',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _billingCycle,
                    decoration: InputDecoration(
                      labelText: 'Cycle',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                      DropdownMenuItem(value: 'half_yearly', child: Text('Half-Yearly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _billingCycle = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Next Renewal Date Picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextRenewalDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setState(() => _nextRenewalDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Next Renewal Date',
                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  DateFormat('dd MMMM yyyy').format(_nextRenewalDate),
                  style: GoogleFonts.inter(fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Payment Method
            TextField(
              controller: _paymentMethodController,
              decoration: InputDecoration(
                labelText: 'Payment Method (Optional)',
                hintText: 'e.g. HDFC Credit Card, Auto-Debit UPI',
                prefixIcon: const Icon(Icons.credit_card_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'e.g. Shared with Priya and Rohit',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D09C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.existingItem == null ? 'Save Subscription' : 'Update Subscription',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
