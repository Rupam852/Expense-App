import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/khata_entry.dart';
import '../services/expense_provider.dart';
import '../widgets/custom_toast.dart';
import '../widgets/payment_reminder_modal.dart';
import 'payment_details_screen.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> with SingleTickerProviderStateMixin {
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

  void _openKhataSheet({KhataEntry? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _KhataEntrySheet(
        existingEntry: existing,
        onSave: (entry) async {
          final provider = Provider.of<ExpenseProvider>(context, listen: false);
          if (existing == null) {
            await provider.addKhataEntry(
              personName: entry.personName,
              phoneNumber: entry.phoneNumber,
              amount: entry.amount,
              type: entry.type,
              entryDate: entry.entryDate,
              dueDate: entry.dueDate,
              note: entry.note,
            );
            if (mounted) {
              CustomToast.show(context, '📒 Khata entry added for ${entry.personName}');
            }
          } else {
            await provider.updateKhataEntry(entry);
            if (mounted) {
              CustomToast.show(context, '✅ Khata entry updated');
            }
          }
        },
      ),
    );
  }

  void _openReminderModal(KhataEntry entry) {
    PaymentReminderModal.show(
      context: context,
      personName: entry.personName,
      amount: entry.amount,
      titleOrNote: entry.note,
      phoneNumber: entry.phoneNumber,
      date: entry.entryDate,
      isKhata: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Khata Book',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Add Entry',
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF00D09C)),
            onPressed: () => _openKhataSheet(),
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          final entries = provider.khataEntries.where((k) => !k.isDeleted).toList();

          final filtered = entries.where((e) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesName = e.personName.toLowerCase().contains(query);
              final matchesNote = e.note?.toLowerCase().contains(query) ?? false;
              if (!matchesName && !matchesNote) return false;
            }
            return true;
          }).toList();

          final lentList = filtered.where((e) => !e.isSettled && e.isLent).toList();
          final borrowedList = filtered.where((e) => !e.isSettled && e.isBorrowed).toList();
          final settledList = filtered.where((e) => e.isSettled).toList();

          final userUpi = provider.paymentDetails.isNotEmpty ? provider.paymentDetails.first.upiId : null;

          return Column(
            children: [
              // 1. Top Summary Banner
              _buildSummaryHeader(
                isDark: isDark,
                totalGet: provider.totalYouWillGet,
                totalGive: provider.totalYouWillGive,
                netBalance: provider.netKhataBalance,
              ),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by person name or note...',
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

              // 3. Tab Bar (Scrollable to prevent label truncation)
              Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
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
                  unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(text: 'All (${filtered.length})'),
                    Tab(text: 'You\'ll Get (${lentList.length})'),
                    Tab(text: 'You\'ll Give (${borrowedList.length})'),
                    Tab(text: 'Settled (${settledList.length})'),
                  ],
                ),
              ),

              // 4. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEntryList(filtered, isDark, userUpi),
                    _buildEntryList(lentList, isDark, userUpi),
                    _buildEntryList(borrowedList, isDark, userUpi),
                    _buildEntryList(settledList, isDark, userUpi),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openKhataSheet(),
        backgroundColor: const Color(0xFF00D09C),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Khata',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader({
    required bool isDark,
    required double totalGet,
    required double totalGive,
    required double netBalance,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          // You will get (Lent)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                      'YOU WILL GET',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _currencyFormat.format(totalGet),
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
          // You will give (Borrowed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEB5757),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'YOU WILL GIVE',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currencyFormat.format(totalGive),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEB5757),
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

  Widget _buildEntryList(List<KhataEntry> list, bool isDark, String? userUpiId) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 54, color: Colors.grey[400]),
            const SizedBox(height: 14),
            Text(
              'No khata entries found',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "+ Add Khata" to log money given or taken',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entry = list[index];
        return _buildKhataCard(entry, isDark, userUpiId);
      },
    );
  }

  Widget _buildKhataCard(KhataEntry entry, bool isDark, String? userUpiId) {
    final isLent = entry.isLent;
    final color = isLent ? const Color(0xFF00D09C) : const Color(0xFFEB5757);
    final formattedDate = DateFormat('dd MMM yyyy').format(entry.entryDate);
    final hasDueDate = entry.dueDate != null;
    final formattedDueDate = hasDueDate ? DateFormat('dd MMM yyyy').format(entry.dueDate!) : null;

    final initial = entry.personName.trim().isNotEmpty ? entry.personName.trim()[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isOverdue
              ? const Color(0xFFEB5757).withValues(alpha: 0.6)
              : isDark
                  ? const Color(0xFF2B313F)
                  : const Color(0xFFE5E9F0),
          width: entry.isOverdue ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.personName,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration: entry.isSettled ? TextDecoration.lineThrough : null,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            (isLent ? '+ ' : '- ') + _currencyFormat.format(entry.amount),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: entry.isSettled ? Colors.grey : color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            isLent ? 'Gave on $formattedDate' : 'Took on $formattedDate',
                            style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                          ),
                          if (entry.isSettled) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SETTLED',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ] else if (entry.isOverdue) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEB5757).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'OVERDUE',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEB5757),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (entry.note != null && entry.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: ${entry.note}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (hasDueDate && !entry.isSettled) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: entry.isOverdue ? const Color(0xFFEB5757) : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Due: $formattedDueDate',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: entry.isOverdue ? const Color(0xFFEB5757) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Card Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Settle / Reopen Toggle
                TextButton.icon(
                  onPressed: () {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    provider.toggleSettleKhata(entry.id, !entry.isSettled);
                    CustomToast.show(
                      context,
                      entry.isSettled ? 'Entry marked as active' : '🎉 Entry marked as Settled!',
                    );
                  },
                  icon: Icon(
                    entry.isSettled ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: entry.isSettled ? Colors.grey : const Color(0xFF00D09C),
                  ),
                  label: Text(
                    entry.isSettled ? 'Mark Active' : 'Settle',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: entry.isSettled ? Colors.grey : const Color(0xFF00D09C),
                    ),
                  ),
                ),

                Row(
                  children: [
                    // WhatsApp / UPI Payment Reminder (only for lent & unsettled)
                    if (isLent && !entry.isSettled) ...[
                      OutlinedButton.icon(
                        onPressed: () => _openReminderModal(entry),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF25D366)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 13, color: Color(0xFF25D366)),
                        label: Text(
                          'Remind',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF25D366),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // More actions (Edit / Delete)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        final provider = Provider.of<ExpenseProvider>(context, listen: false);
                        if (val == 'edit') {
                          _openKhataSheet(existing: entry);
                        } else if (val == 'delete') {
                          provider.deleteKhataEntry(entry.id);
                          CustomToast.show(context, 'Entry deleted');
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

class _KhataEntrySheet extends StatefulWidget {
  final KhataEntry? existingEntry;
  final ValueChanged<KhataEntry> onSave;

  const _KhataEntrySheet({this.existingEntry, required this.onSave});

  @override
  State<_KhataEntrySheet> createState() => _KhataEntrySheetState();
}

class _KhataEntrySheetState extends State<_KhataEntrySheet> {
  late String _type;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _entryDate;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    _type = existing?.type ?? 'lent';
    _nameController = TextEditingController(text: existing?.personName ?? '');
    _phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    _amountController = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _entryDate = existing?.entryDate ?? DateTime.now();
    _dueDate = existing?.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim();

    if (name.isEmpty) {
      CustomToast.show(context, 'Please enter person name', isError: true);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      CustomToast.show(context, 'Please enter a valid amount', isError: true);
      return;
    }

    final entry = KhataEntry(
      id: widget.existingEntry?.id ?? '',
      personName: name,
      phoneNumber: _phoneController.text.trim(),
      amount: amount,
      type: _type,
      entryDate: _entryDate,
      dueDate: _dueDate,
      note: _noteController.text.trim(),
      isSettled: widget.existingEntry?.isSettled ?? false,
      settledAt: widget.existingEntry?.settledAt,
    );

    widget.onSave(entry);
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
                  widget.existingEntry == null ? 'Add Khata Entry' : 'Edit Khata Entry',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented Type Selector
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'lent'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'lent'
                            ? const Color(0xFF00D09C).withValues(alpha: 0.15)
                            : isDark
                                ? const Color(0xFF1E222D)
                                : const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _type == 'lent' ? const Color(0xFF00D09C) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            color: _type == 'lent' ? const Color(0xFF00D09C) : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You Lent\n(You\'ll Get)',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _type == 'lent' ? const Color(0xFF00D09C) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'borrowed'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'borrowed'
                            ? const Color(0xFFEB5757).withValues(alpha: 0.15)
                            : isDark
                                ? const Color(0xFF1E222D)
                                : const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _type == 'borrowed' ? const Color(0xFFEB5757) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: _type == 'borrowed' ? const Color(0xFFEB5757) : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You Borrowed\n(You\'ll Give)',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _type == 'borrowed' ? const Color(0xFFEB5757) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Person Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Person Name *',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (₹) *',
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Phone (Optional)
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'WhatsApp Phone Number (Optional)',
                hintText: '+91 9876543210',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Date Pickers Row (Entry Date & Due Date)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _entryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _entryDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date Given/Taken',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_entryDate),
                        style: GoogleFonts.inter(fontSize: 12.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Due Date (Optional)',
                        suffixIcon: _dueDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() => _dueDate = null),
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _dueDate != null ? DateFormat('dd MMM yyyy').format(_dueDate!) : 'Not set',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: _dueDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note / Reason (Optional)',
                hintText: 'e.g. Goa trip advance, Lunch bill',
                prefixIcon: const Icon(Icons.notes_rounded),
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
                widget.existingEntry == null ? 'Save Entry' : 'Update Entry',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
