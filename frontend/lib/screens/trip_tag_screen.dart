import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import '../services/expense_provider.dart';
import 'expense_entry_screen.dart';

class TripTagSummary {
  final String tag;
  final List<Expense> expenses;
  final double totalAmount;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, double> categoryBreakdown;

  TripTagSummary({
    required this.tag,
    required this.expenses,
    required this.totalAmount,
    this.startDate,
    this.endDate,
    required this.categoryBreakdown,
  });

  factory TripTagSummary.fromExpenses(String tag, List<Expense> allExpenses) {
    final matched = allExpenses.where((e) => !e.isDeleted && e.hasTag(tag)).toList();
    matched.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    double total = 0;
    final Map<String, double> breakdown = {};
    for (final exp in matched) {
      total += exp.amount;
      breakdown[exp.category] = (breakdown[exp.category] ?? 0) + exp.amount;
    }

    DateTime? start;
    DateTime? end;
    if (matched.isNotEmpty) {
      end = matched.first.transactionDate;
      start = matched.last.transactionDate;
    }

    return TripTagSummary(
      tag: tag,
      expenses: matched,
      totalAmount: total,
      startDate: start,
      endDate: end,
      categoryBreakdown: breakdown,
    );
  }
}

class TripTagScreen extends StatefulWidget {
  final String? initialSelectedTag;

  const TripTagScreen({super.key, this.initialSelectedTag});

  @override
  State<TripTagScreen> createState() => _TripTagScreenState();
}

class _TripTagScreenState extends State<TripTagScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _activeTagFilter;

  final List<String> _popularTagSuggestions = [
    'GoaTrip2026',
    'DiwaliShopping',
    'HomeRenovation',
    'Wedding',
    'BirthdayParty',
    'OfficeLunch',
    'CarService',
    'CollegeFest',
    'ManaliTrip',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedTag != null) {
      _activeTagFilter = widget.initialSelectedTag!.replaceAll('#', '');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TripTagSummary> _extractAllTags(List<Expense> expenses) {
    final Set<String> tagSet = {};
    for (final exp in expenses) {
      if (!exp.isDeleted) {
        for (final t in exp.tags) {
          tagSet.add(t);
        }
      }
    }

    final query = _searchController.text.trim().toLowerCase().replaceAll('#', '');
    final list = tagSet
        .where((t) => query.isEmpty || t.toLowerCase().contains(query))
        .map((t) => TripTagSummary.fromExpenses(t, expenses))
        .where((summary) => summary.expenses.isNotEmpty)
        .toList();

    list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return list;
  }

  Future<void> _shareTripSummary(TripTagSummary trip) async {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateRange = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('dd MMM yyyy').format(trip.startDate!)} to ${DateFormat('dd MMM yyyy').format(trip.endDate!)}'
        : 'Recent';

    final buffer = StringBuffer();
    buffer.writeln('🏷️ *Expense Summary for #${trip.tag}*');
    buffer.writeln('📅 Dates: $dateRange');
    buffer.writeln('💰 Total Spend: ${currencyFormat.format(trip.totalAmount)}');
    buffer.writeln('📝 Total Entries: ${trip.expenses.length}');
    buffer.writeln('');
    buffer.writeln('📊 *Category Breakdown:*');
    trip.categoryBreakdown.forEach((cat, amt) {
      final pct = trip.totalAmount > 0 ? (amt / trip.totalAmount * 100).toStringAsFixed(0) : '0';
      buffer.writeln('• $cat: ${currencyFormat.format(amt)} ($pct%)');
    });
    buffer.writeln('');
    buffer.writeln('📌 *Top Expenses:*');
    for (final e in trip.expenses.take(5)) {
      buffer.writeln('• ${DateFormat('dd MMM').format(e.transactionDate)}: ${e.category} - ${currencyFormat.format(e.amount)} ${e.description.isNotEmpty ? "(${e.description})" : ""}');
    }
    buffer.writeln('');
    final textContent = buffer.toString();
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(textContent)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback: System share sheet (Telegram, SMS, Notes, etc.)
    await SharePlus.instance.share(
      ShareParams(
        text: textContent,
        subject: 'Expense Summary for #${trip.tag}',
      ),
    );
  }

  void _showNewTagDialog(BuildContext context) {
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.tag_rounded, color: Color(0xFF00D09C)),
            const SizedBox(width: 8),
            Text('Track New Trip / Event', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a hashtag like #GoaTrip2026 or #Diwali to group all related expenses.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tagCtrl,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '#',
                prefixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                hintText: 'GoaTrip2026',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Quick suggestions:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _popularTagSuggestions.take(6).map((s) {
                return InkWell(
                  onTap: () => tagCtrl.text = s,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D09C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('#$s', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF00D09C), fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final raw = tagCtrl.text.trim().replaceAll('#', '').replaceAll(' ', '');
              if (raw.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExpenseEntryScreen(
                      initialCategory: 'Others',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D09C),
              foregroundColor: Colors.black,
            ),
            child: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expProvider = Provider.of<ExpenseProvider>(context);
    final allExpenses = expProvider.expenses;
    final tagSummaries = _extractAllTags(allExpenses);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trips & Event Tags', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Group expenses with #hashtags', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showNewTagDialog(context),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00D09C)),
            tooltip: 'Add Trip / Event Tag',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search tags (e.g. Goa, Diwali, Vacation)...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF00D09C)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E232E) : const Color(0xFFF4F6F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tag summary list
          Expanded(
            child: tagSummaries.isEmpty
                ? _buildEmptyState(context, isDark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: tagSummaries.length,
                    itemBuilder: (context, index) {
                      final trip = tagSummaries[index];
                      return _buildTripTagCard(context, trip, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewTagDialog(context),
        backgroundColor: const Color(0xFF00D09C),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Trip / Tag', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00D09C).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tag_rounded, size: 48, color: Color(0xFF00D09C)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Tagged Expenses Found',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add hashtags like #GoaTrip2026 or #Diwali in expense notes/descriptions to automatically group and track holiday or project budgets!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              'Popular Tags to Start:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _popularTagSuggestions.map((tag) {
                return ActionChip(
                  avatar: const Icon(Icons.add, size: 14, color: Color(0xFF00D09C)),
                  label: Text('#$tag', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: isDark ? const Color(0xFF1E232E) : const Color(0xFFF4F6F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExpenseEntryScreen(
                          initialCategory: 'Others',
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTagCard(BuildContext context, TripTagSummary trip, bool isDark) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateRangeStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('dd MMM').format(trip.startDate!)} - ${DateFormat('dd MMM yyyy').format(trip.endDate!)}'
        : 'Recent';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTripDetailSheet(context, trip, isDark),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Tag & Total Spend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D09C).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tag_rounded, color: Color(0xFF00D09C), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${trip.tag}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateRangeStr,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(trip.totalAmount),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF00D09C)),
                        ),
                        Text(
                          '${trip.expenses.length} transaction${trip.expenses.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Category chips summary
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: trip.categoryBreakdown.entries.take(4).map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222836) : const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.key}: ${currencyFormat.format(entry.value)}',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),
                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _shareTripSummary(trip),
                      icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF25D366)),
                      label: Text('Share Summary', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF25D366), fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF00D09C))),
                        const Icon(Icons.chevron_right, size: 16, color: Color(0xFF00D09C)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTripDetailSheet(BuildContext context, TripTagSummary trip, bool isDark) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14171E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 4,
                width: 40,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),

              // Sheet header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${trip.tag}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
                          Text('${trip.expenses.length} Expenses • Total ${currencyFormat.format(trip.totalAmount)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Color(0xFF25D366)),
                      tooltip: 'Share on WhatsApp',
                      onPressed: () => _shareTripSummary(trip),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Expense list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: trip.expenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final exp = trip.expenses[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E232E) : const Color(0xFFF9FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2B3242) : const Color(0xFFECEFF3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D09C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF00D09C)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(exp.category, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (exp.description.isNotEmpty)
                                  Text(exp.description, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(DateFormat('dd MMM yyyy, hh:mm a').format(exp.transactionDate), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text(
                            currencyFormat.format(exp.amount),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF00D09C)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom add action
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExpenseEntryScreen(
                              initialCategory: 'Others',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D09C),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: Text('Add Expense to #${trip.tag}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
