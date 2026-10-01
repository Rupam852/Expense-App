import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/split_bill.dart';
import '../services/expense_provider.dart';
import '../widgets/custom_toast.dart';
import '../widgets/payment_reminder_modal.dart';
import 'payment_details_screen.dart';

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

                    // Share / Payment Reminder modal
                    if (!isSettled)
                      IconButton(
                        tooltip: 'Share Payment Reminder',
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 18),
                        onPressed: () {
                          PaymentReminderModal.show(
                            context: context,
                            personName: p.name,
                            amount: p.shareAmount,
                            titleOrNote: bill.title,
                            phoneNumber: p.phoneNumber,
                            date: bill.billDate,
                            isKhata: false,
                            customPayerUpiId: bill.payerUpiId,
                          );
                        },
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
              if (!isFullyDone)
                TextButton.icon(
                  onPressed: () {
                    PaymentReminderModal.show(
                      context: context,
                      personName: bill.isPaidByMe
                          ? 'Participants (${totalParts - settledParts} Pending)'
                          : bill.paidBy,
                      amount: bill.isPaidByMe
                          ? (bill.pendingCollection > 0 ? bill.pendingCollection : bill.totalAmount)
                          : (bill.myPendingToPay > 0 ? bill.myPendingToPay : bill.myShare),
                      titleOrNote: bill.title,
                      date: bill.billDate,
                      isKhata: false,
                      customPayerUpiId: bill.payerUpiId,
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF00D09C)),
                  label: Text(
                    bill.isPaidByMe ? 'Collect Payment / QR' : 'Pay Payer (${bill.paidBy}) / QR',
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
  
  // Paid By Mode: true = 'You', false = 'Other'
  bool _isPaidByMe = true;
  String? _selectedPaymentDetailId;
  
  // For Other Payer
  final _otherPayerNameController = TextEditingController();
  final _otherPayerUpiController = TextEditingController();

  // For User's Own Share when Someone Else paid
  final _myShareController = TextEditingController(text: '0');

  final List<TextEditingController> _friendControllers = [];
  final List<TextEditingController> _customAmountControllers = [];
  String _splitType = 'equal'; // 'equal' or 'custom'
  DateTime _billDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (provider.paymentDetails.isNotEmpty) {
      _selectedPaymentDetailId = provider.primaryPaymentDetail?.id ?? provider.paymentDetails.first.id;
    }

    if (widget.existingBill != null) {
      final b = widget.existingBill!;
      _titleController.text = b.title;
      _totalController.text = b.totalAmount.toStringAsFixed(0);
      _noteController.text = b.note ?? '';
      _billDate = b.billDate;
      _splitType = b.splitType;

      if (b.isPaidByMe) {
        _isPaidByMe = true;
        final matched = provider.paymentDetails.where((p) => p.upiId == b.payerUpiId).firstOrNull;
        if (matched != null) {
          _selectedPaymentDetailId = matched.id;
        }

        for (var p in b.participants) {
          if (p.name.trim().toLowerCase() != 'you') {
            _friendControllers.add(TextEditingController(text: p.name));
            _customAmountControllers.add(TextEditingController(text: p.shareAmount.toStringAsFixed(0)));
          }
        }
      } else {
        _isPaidByMe = false;
        _otherPayerNameController.text = b.paidBy;
        _otherPayerUpiController.text = b.payerUpiId ?? '';

        final youParticipant = b.participants.where((p) => p.name.trim().toLowerCase() == 'you').firstOrNull;
        if (youParticipant != null) {
          _myShareController.text = youParticipant.shareAmount.toStringAsFixed(0);
        }

        for (var p in b.participants) {
          if (p.name.trim().toLowerCase() != 'you' &&
              p.name.trim().toLowerCase() != b.paidBy.trim().toLowerCase()) {
            _friendControllers.add(TextEditingController(text: p.name));
            _customAmountControllers.add(TextEditingController(text: p.shareAmount.toStringAsFixed(0)));
          }
        }
      }
    } else {
      // Default: 1 empty friend field
      _friendControllers.add(TextEditingController(text: ''));
      _customAmountControllers.add(TextEditingController(text: '0'));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _noteController.dispose();
    _otherPayerNameController.dispose();
    _otherPayerUpiController.dispose();
    _myShareController.dispose();
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
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    if (title.isEmpty) {
      CustomToast.show(context, 'Please enter a bill title', isError: true);
      return;
    }
    if (total <= 0) {
      CustomToast.show(context, 'Please enter a valid total amount', isError: true);
      return;
    }

    if (_isPaidByMe) {
      // Paid By You
      final friendNames = _friendControllers
          .map((c) => c.text.trim())
          .where((name) => name.isNotEmpty && name.toLowerCase() != 'you')
          .toList();

      if (friendNames.isEmpty) {
        CustomToast.show(context, 'Please add at least one friend to split with', isError: true);
        return;
      }

      final List<SplitParticipant> participants = [];
      final totalPeople = friendNames.length + 1;

      if (_splitType == 'equal') {
        final equalShare = total / totalPeople;
        participants.add(SplitParticipant(name: 'You', shareAmount: equalShare, isSettled: true));
        for (var f in friendNames) {
          participants.add(SplitParticipant(name: f, shareAmount: equalShare, isSettled: false));
        }
      } else {
        double friendsTotal = 0.0;
        for (int i = 0; i < friendNames.length; i++) {
          final amt = double.tryParse(_customAmountControllers[i].text.trim()) ?? 0.0;
          friendsTotal += amt;
          participants.add(SplitParticipant(name: friendNames[i], shareAmount: amt, isSettled: false));
        }
        final myShare = (total - friendsTotal).clamp(0.0, total);
        participants.insert(0, SplitParticipant(name: 'You', shareAmount: myShare, isSettled: true));
      }

      final selectedPayment = provider.paymentDetails.where((p) => p.id == _selectedPaymentDetailId).firstOrNull;
      final payerUpi = selectedPayment?.upiId.isNotEmpty == true ? selectedPayment!.upiId : null;

      final bill = SplitBill(
        id: widget.existingBill?.id ?? '',
        title: title,
        totalAmount: total,
        paidBy: 'You',
        payerUpiId: payerUpi,
        billDate: _billDate,
        splitType: _splitType,
        participants: participants,
        note: _noteController.text.trim(),
      );

      widget.onSave(bill);
      Navigator.of(context).pop();
    } else {
      // Paid By Friend / Other
      final payerName = _otherPayerNameController.text.trim();
      if (payerName.isEmpty) {
        CustomToast.show(context, 'Please enter payer name (who paid the bill)', isError: true);
        return;
      }

      final payerUpi = _otherPayerUpiController.text.trim().isEmpty ? null : _otherPayerUpiController.text.trim();

      final otherFriends = _friendControllers
          .map((c) => c.text.trim())
          .where((name) => name.isNotEmpty &&
              name.toLowerCase() != 'you' &&
              name.toLowerCase() != payerName.toLowerCase())
          .toList();

      final List<SplitParticipant> participants = [];
      // Total people = Payer + You + otherFriends
      final totalPeople = otherFriends.length + 2;

      if (_splitType == 'equal') {
        final equalShare = total / totalPeople;
        participants.add(SplitParticipant(name: payerName, shareAmount: equalShare, isSettled: true));
        participants.add(SplitParticipant(name: 'You', shareAmount: equalShare, isSettled: false));
        for (var f in otherFriends) {
          participants.add(SplitParticipant(name: f, shareAmount: equalShare, isSettled: false));
        }
      } else {
        final myShare = double.tryParse(_myShareController.text.trim()) ?? 0.0;
        double friendsTotal = 0.0;
        for (int i = 0; i < otherFriends.length; i++) {
          final amt = double.tryParse(_customAmountControllers[i].text.trim()) ?? 0.0;
          friendsTotal += amt;
          participants.add(SplitParticipant(name: otherFriends[i], shareAmount: amt, isSettled: false));
        }
        final payerShare = (total - myShare - friendsTotal).clamp(0.0, total);
        participants.insert(0, SplitParticipant(name: payerName, shareAmount: payerShare, isSettled: true));
        participants.insert(1, SplitParticipant(name: 'You', shareAmount: myShare, isSettled: false));
      }

      final bill = SplitBill(
        id: widget.existingBill?.id ?? '',
        title: title,
        totalAmount: total,
        paidBy: payerName,
        payerUpiId: payerUpi,
        billDate: _billDate,
        splitType: _splitType,
        participants: participants,
        note: _noteController.text.trim(),
      );

      widget.onSave(bill);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF1E232E) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0);

    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final paymentDetails = provider.paymentDetails;
        if (_selectedPaymentDetailId == null && paymentDetails.isNotEmpty) {
          _selectedPaymentDetailId = provider.primaryPaymentDetail?.id ?? paymentDetails.first.id;
        }

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

                // Bill Title
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Bill Title *',
                    hintText: 'e.g. Goa Dinner, Netflix Plan, Uber Ride',
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
                const SizedBox(height: 16),

                // ──────────────────────────────────────────────────────────
                // WHO PAID THE BILL? (YOU VS OTHER CHIP TOGGLE)
                // ──────────────────────────────────────────────────────────
                Text(
                  'WHO PAID THIS BILL?',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    // You Option
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isPaidByMe = true);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _isPaidByMe
                                ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.15)
                                : cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isPaidByMe ? primaryColor : borderColor,
                              width: _isPaidByMe ? 1.6 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: _isPaidByMe ? primaryColor : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Paid by You',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: _isPaidByMe ? FontWeight.bold : FontWeight.w500,
                                  color: _isPaidByMe
                                      ? primaryColor
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Someone Else Option
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isPaidByMe = false);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: !_isPaidByMe
                                ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.15)
                                : cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: !_isPaidByMe ? const Color(0xFF6366F1) : borderColor,
                              width: !_isPaidByMe ? 1.6 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_rounded,
                                size: 18,
                                color: !_isPaidByMe ? const Color(0xFF6366F1) : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Someone Else',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: !_isPaidByMe ? FontWeight.bold : FontWeight.w500,
                                  color: !_isPaidByMe
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ──────────────────────────────────────────────────────────
                // CASE 1: PAID BY YOU -> SELECT FROM USER'S SAVED PAYMENT CARDS
                // ──────────────────────────────────────────────────────────
                if (_isPaidByMe) ...[
                  if (paymentDetails.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF00D09C)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'RECEIVING PAYMENT ACCOUNT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
                                  );
                                },
                                child: Text(
                                  '+ Manage',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: paymentDetails.any((p) => p.id == _selectedPaymentDetailId)
                                ? _selectedPaymentDetailId
                                : paymentDetails.first.id,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: paymentDetails.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.id,
                                child: Row(
                                  children: [
                                    if (p.isPrimary)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6.0),
                                        child: Icon(Icons.star_rounded, size: 16, color: primaryColor),
                                      ),
                                    Expanded(
                                      child: Text(
                                        '${p.name} (${p.upiId.isNotEmpty ? p.upiId : "No UPI"})',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPaymentDetailId = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // No Payment Accounts Set Up Yet
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D09C).withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00D09C).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_card_rounded, color: Color(0xFF00D09C), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tap to add your UPI account for 1-tap QR collection',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF00D09C)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  // ──────────────────────────────────────────────────────────
                  // CASE 2: PAID BY FRIEND / OTHER
                  // ──────────────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_circle_rounded, size: 16, color: Color(0xFF6366F1)),
                            const SizedBox(width: 6),
                            Text(
                              'PAYER DETAILS (WHO PAID?)',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _otherPayerNameController,
                                decoration: InputDecoration(
                                  labelText: 'Payer Name *',
                                  hintText: 'e.g. Rahul',
                                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _otherPayerUpiController,
                                decoration: InputDecoration(
                                  labelText: 'Payer UPI ID',
                                  hintText: 'name@upi',
                                  prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '💡 QR will be generated for this payer so everyone can pay them directly.',
                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      selectedColor: primaryColor.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Custom Amounts'),
                      selected: _splitType == 'custom',
                      onSelected: (val) => setState(() => _splitType = 'custom'),
                      selectedColor: primaryColor.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Friends / Participants List Header
                Text(
                  _isPaidByMe
                      ? 'SPLIT WITH (YOU + FRIENDS)'
                      : 'PARTICIPANTS SPLITTING WITH (YOU + PAYER)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // If Someone Else paid, explicitly show 'You (Me)' as auto-included participant
                if (!_isPaidByMe) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'You (Me)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Auto-included (You owe payer)',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _splitType == 'equal'
                                    ? 'Splits equally with payer & friends'
                                    : 'Enter your share amount on right',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (_splitType == 'custom') ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _myShareController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'Your ₹',
                                prefixText: '₹',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

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
                              hintText: _isPaidByMe ? 'Friend Name ${index + 1}' : 'Extra Friend ${index + 1} (Optional)',
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
                        if ((_isPaidByMe && _friendControllers.length > 1) || (!_isPaidByMe && _friendControllers.isNotEmpty))
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
                    hintText: 'e.g. Dinner party, drinks included',
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
      },
    );
  }
}
