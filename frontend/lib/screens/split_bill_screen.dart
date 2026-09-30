import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/split_bill.dart';
import '../services/expense_provider.dart';
import '../widgets/custom_toast.dart';

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddSplitSheet({SplitBill? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddSplitBillSheet(
        existingBill: existing,
        onSave: (bill) async {
          final provider = Provider.of<ExpenseProvider>(context, listen: false);
          if (existing == null) {
            await provider.addSplitBill(
              title: bill.title,
              totalAmount: bill.totalAmount,
              paidBy: bill.paidBy,
              payerUpiId: bill.payerUpiId,
              billDate: bill.billDate,
              splitType: bill.splitType,
              participants: bill.participants,
              note: bill.note,
            );
            if (mounted) {
              CustomToast.show(context, '👥 Split bill "${bill.title}" created!');
            }
          } else {
            await provider.updateSplitBill(bill);
            if (mounted) {
              CustomToast.show(context, '✅ Split bill updated');
            }
          }
        },
      ),
    );
  }

  void _showUpiQrDialog({
    required String upiId,
    required String payeeName,
    required double amount,
    required String billTitle,
  }) {
    final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent(billTitle)}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00D09C)),
            const SizedBox(width: 10),
            Text(
              'Instant UPI Settlement',
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan with GPay, PhonePe, Paytm or BHIM',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: QrImageView(
                data: upiUri,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _currencyFormat.format(amount),
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00D09C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pay to: $upiId',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSplitOnWhatsApp({
    required SplitBill bill,
    required SplitParticipant participant,
  }) async {
    final shareAmt = _currencyFormat.format(participant.shareAmount);
    final upiInfo = bill.payerUpiId != null && bill.payerUpiId!.isNotEmpty
        ? '\n\n📱 Pay via UPI ID: ${bill.payerUpiId}'
        : '';

    final message = 'Hey ${participant.name}! 👋\n\n'
        'Your share for "${bill.title}" is $shareAmt (Total bill: ${_currencyFormat.format(bill.totalAmount)}).'
        '$upiInfo\n\nPlease settle whenever possible. Thanks! 🙏';

    if (participant.phoneNumber != null && participant.phoneNumber!.trim().isNotEmpty) {
      String cleanPhone = participant.phoneNumber!.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      } else if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone'; // Default Indian country code
      }
      final whatsappUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
      try {
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    // Fallback share sheet
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'Bill Split Share for ${bill.title}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Split Bills with Friends',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Add Split Bill',
            icon: const Icon(Icons.group_add_rounded, color: Color(0xFF00D09C)),
            onPressed: () => _openAddSplitSheet(),
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          final bills = provider.splitBills.where((b) => !b.isDeleted).toList();

          final filtered = bills.where((b) {
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchesTitle = b.title.toLowerCase().contains(q);
              final matchesPart = b.participants.any((p) => p.name.toLowerCase().contains(q));
              if (!matchesTitle && !matchesPart) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // 1. Summary Header
              _buildSummaryHeader(
                isDark: isDark,
                toCollect: provider.totalSplitReceivable,
                toPay: provider.totalSplitPayable,
                activeCount: bills.where((b) => !b.isFullySettled).length,
              ),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by bill name or friend name...',
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

              // 3. Bill Cards List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call_split_rounded, size: 54, color: Colors.grey[400]),
                            const SizedBox(height: 14),
                            Text(
                              'No split bills found',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "+ Split New Bill" to split dinner, trips or group expenses',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final bill = filtered[index];
                          return _buildSplitBillCard(bill, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSplitSheet(),
        backgroundColor: const Color(0xFF00D09C),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Split New Bill',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader({
    required bool isDark,
    required double toCollect,
    required double toPay,
    required int activeCount,
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
          // To Collect
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
                      'TO COLLECT',
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
                  _currencyFormat.format(toCollect),
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
          // You Owe
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
                        'YOU OWE',
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
                    _currencyFormat.format(toPay),
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

  Widget _buildSplitBillCard(SplitBill bill, bool isDark) {
    final formattedDate = DateFormat('dd MMM yyyy').format(bill.billDate);
    final totalParts = bill.participants.length;
    final settledParts = bill.settledCount;
    final isFullyDone = bill.isFullySettled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullyDone
              ? const Color(0xFF00D09C).withValues(alpha: 0.3)
              : isDark
                  ? const Color(0xFF2B313F)
                  : const Color(0xFFE5E9F0),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: CircleAvatar(
          backgroundColor: isFullyDone
              ? const Color(0xFF00D09C).withValues(alpha: 0.15)
              : const Color(0xFF6C63FF).withValues(alpha: 0.15),
          child: Icon(
            isFullyDone ? Icons.done_all_rounded : Icons.call_split_rounded,
            color: isFullyDone ? const Color(0xFF00D09C) : const Color(0xFF6C63FF),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                bill.title,
                style: GoogleFonts.outfit(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Text(
              _currencyFormat.format(bill.totalAmount),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Paid by ${bill.paidBy} • $formattedDate',
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isFullyDone ? const Color(0xFF00D09C) : const Color(0xFFFF8A00)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFullyDone ? 'SETTLED' : '$settledParts/$totalParts PAID',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isFullyDone ? const Color(0xFF00D09C) : const Color(0xFFFF8A00),
                      ),
                    ),
                  ),
                ],
              ),
              if (bill.note != null && bill.note!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  bill.note!,
                  style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Participants Breakdown
          ...bill.participants.map((p) {
            final isPayer = p.name.trim().toLowerCase() == bill.paidBy.trim().toLowerCase();
            final isSettled = p.isSettled || isPayer;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              p.name + (isPayer ? ' (Payer)' : ''),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: isSettled && !isPayer ? TextDecoration.lineThrough : null,
                                color: isSettled ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _currencyFormat.format(p.shareAmount),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSettled ? Colors.grey : const Color(0xFF00D09C),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions for participant
                  if (!isPayer) ...[
                    // Toggle Settled Checkbox
                    IconButton(
                      tooltip: isSettled ? 'Mark Unsettled' : 'Mark Settled',
                      icon: Icon(
                        isSettled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSettled ? const Color(0xFF00D09C) : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () {
                        final provider = Provider.of<ExpenseProvider>(context, listen: false);
                        provider.toggleParticipantSettled(bill.id, p.name, !isSettled);
                      },
                    ),

                    // WhatsApp Reminder
                    if (!isSettled)
                      IconButton(
                        tooltip: 'Share on WhatsApp',
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 18),
                        onPressed: () => _shareSplitOnWhatsApp(bill: bill, participant: p),
                      ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          // Footer: UPI QR button & Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (bill.payerUpiId != null && bill.payerUpiId!.isNotEmpty && !isFullyDone)
                TextButton.icon(
                  onPressed: () {
                    _showUpiQrDialog(
                      upiId: bill.payerUpiId!,
                      payeeName: bill.paidBy,
                      amount: bill.pendingCollection > 0 ? bill.pendingCollection : bill.totalAmount,
                      billTitle: bill.title,
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF00D09C)),
                  label: Text(
                    'Show UPI QR',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                  ),
                )
              else
                const SizedBox.shrink(),

              IconButton(
                tooltip: 'Delete Split Bill',
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEB5757)),
                onPressed: () {
                  final provider = Provider.of<ExpenseProvider>(context, listen: false);
                  provider.deleteSplitBill(bill.id);
                  CustomToast.show(context, 'Split bill deleted');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddSplitBillSheet extends StatefulWidget {
  final SplitBill? existingBill;
  final ValueChanged<SplitBill> onSave;

  const _AddSplitBillSheet({this.existingBill, required this.onSave});

  @override
  State<_AddSplitBillSheet> createState() => _AddSplitBillSheetState();
}

class _AddSplitBillSheetState extends State<_AddSplitBillSheet> {
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _noteController = TextEditingController();
  final _upiController = TextEditingController();
  final _payerController = TextEditingController(text: 'You');

  final List<TextEditingController> _friendControllers = [];
  final List<TextEditingController> _customAmountControllers = [];
  String _splitType = 'equal'; // 'equal' or 'custom'
  DateTime _billDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final userUpi = provider.paymentDetails.isNotEmpty ? provider.paymentDetails.first.upiId : '';
    _upiController.text = userUpi;

    if (widget.existingBill != null) {
      final b = widget.existingBill!;
      _titleController.text = b.title;
      _totalController.text = b.totalAmount.toStringAsFixed(0);
      _noteController.text = b.note ?? '';
      _payerController.text = b.paidBy;
      _upiController.text = b.payerUpiId ?? userUpi;
      _billDate = b.billDate;
      _splitType = b.splitType;

      for (var p in b.participants) {
        if (p.name.trim().toLowerCase() != 'you') {
          _friendControllers.add(TextEditingController(text: p.name));
          _customAmountControllers.add(TextEditingController(text: p.shareAmount.toStringAsFixed(0)));
        }
      }
    } else {
      // Default: add 2 empty friend fields
      _friendControllers.add(TextEditingController(text: ''));
      _customAmountControllers.add(TextEditingController(text: '0'));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _noteController.dispose();
    _upiController.dispose();
    _payerController.dispose();
    for (var c in _friendControllers) {
      c.dispose();
    }
    for (var c in _customAmountControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addFriendField() {
    setState(() {
      _friendControllers.add(TextEditingController(text: ''));
      _customAmountControllers.add(TextEditingController(text: '0'));
    });
  }

  void _removeFriendField(int index) {
    setState(() {
      _friendControllers[index].dispose();
      _customAmountControllers[index].dispose();
      _friendControllers.removeAt(index);
      _customAmountControllers.removeAt(index);
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    final total = double.tryParse(_totalController.text.trim()) ?? 0.0;

    if (title.isEmpty) {
      CustomToast.show(context, 'Please enter a bill title', isError: true);
      return;
    }
    if (total <= 0) {
      CustomToast.show(context, 'Please enter a valid total amount', isError: true);
      return;
    }

    final friendNames = _friendControllers
        .map((c) => c.text.trim())
        .where((name) => name.isNotEmpty && name.toLowerCase() != 'you')
        .toList();

    if (friendNames.isEmpty) {
      CustomToast.show(context, 'Please add at least one friend to split with', isError: true);
      return;
    }

    // Participants list (including 'You')
    final List<SplitParticipant> participants = [];
    final totalPeople = friendNames.length + 1;

    if (_splitType == 'equal') {
      final equalShare = total / totalPeople;
      participants.add(SplitParticipant(name: 'You', shareAmount: equalShare));
      for (var f in friendNames) {
        participants.add(SplitParticipant(name: f, shareAmount: equalShare));
      }
    } else {
      // Custom split
      double friendsTotal = 0.0;
      for (int i = 0; i < friendNames.length; i++) {
        final amt = double.tryParse(_customAmountControllers[i].text.trim()) ?? 0.0;
        friendsTotal += amt;
        participants.add(SplitParticipant(name: friendNames[i], shareAmount: amt));
      }
      final myShare = (total - friendsTotal).clamp(0.0, total);
      participants.insert(0, SplitParticipant(name: 'You', shareAmount: myShare));
    }

    final bill = SplitBill(
      id: widget.existingBill?.id ?? '',
      title: title,
      totalAmount: total,
      paidBy: _payerController.text.trim().isEmpty ? 'You' : _payerController.text.trim(),
      payerUpiId: _upiController.text.trim().isEmpty ? null : _upiController.text.trim(),
      billDate: _billDate,
      splitType: _splitType,
      participants: participants,
      note: _noteController.text.trim(),
    );

    widget.onSave(bill);
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
                  widget.existingBill == null ? 'Split New Bill' : 'Edit Split Bill',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Bill Title *',
                hintText: 'e.g. Goa Resort Dinner, Swiggy Party',
                prefixIcon: const Icon(Icons.receipt_long_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Total Amount
            TextField(
              controller: _totalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Total Bill Amount (₹) *',
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Who Paid & UPI ID
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _payerController,
                    decoration: InputDecoration(
                      labelText: 'Paid By',
                      hintText: 'You or Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _upiController,
                    decoration: InputDecoration(
                      labelText: 'Payer UPI ID (For QR)',
                      hintText: 'name@upi',
                      prefixIcon: const Icon(Icons.qr_code_2_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Split Mode Toggle
            Row(
              children: [
                Text(
                  'Split Mode:',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Equally'),
                  selected: _splitType == 'equal',
                  onSelected: (val) => setState(() => _splitType = 'equal'),
                  selectedColor: const Color(0xFF00D09C).withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Custom Amounts'),
                  selected: _splitType == 'custom',
                  onSelected: (val) => setState(() => _splitType = 'custom'),
                  selectedColor: const Color(0xFF00D09C).withValues(alpha: 0.2),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Friends / Participants List
            Text(
              'SPLIT WITH (YOU + FRIENDS)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            ...List.generate(_friendControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _friendControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Friend Name ${index + 1}',
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (_splitType == 'custom') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _customAmountControllers[index],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '₹ Share',
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                    if (_friendControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _removeFriendField(index),
                      ),
                  ],
                ),
              );
            }),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addFriendField,
                icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF00D09C)),
                label: Text(
                  '+ Add Another Friend',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Note (Optional)
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'e.g. Drinks paid separately',
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
                widget.existingBill == null ? 'Save & Create Split' : 'Update Split Bill',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
