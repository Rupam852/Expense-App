import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/payment_detail.dart';
import '../screens/payment_details_screen.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import 'custom_toast.dart';

class PaymentReminderModal extends StatefulWidget {
  final String personName;
  final double amount;
  final String? titleOrNote;
  final String? phoneNumber;
  final DateTime? date;
  final bool isKhata;
  final String? customPayerUpiId;

  const PaymentReminderModal({
    super.key,
    required this.personName,
    required this.amount,
    this.titleOrNote,
    this.phoneNumber,
    this.date,
    this.isKhata = true,
    this.customPayerUpiId,
  });

  static Future<void> show({
    required BuildContext context,
    required String personName,
    required double amount,
    String? titleOrNote,
    String? phoneNumber,
    DateTime? date,
    bool isKhata = true,
    String? customPayerUpiId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentReminderModal(
        personName: personName,
        amount: amount,
        titleOrNote: titleOrNote,
        phoneNumber: phoneNumber,
        date: date,
        isKhata: isKhata,
        customPayerUpiId: customPayerUpiId,
      ),
    );
  }

  @override
  State<PaymentReminderModal> createState() => _PaymentReminderModalState();
}

class _PaymentReminderModalState extends State<PaymentReminderModal> {
  String? _selectedPaymentId;

  String _buildShareMessage({
    required String? upiId,
    required String? payeeName,
    required String formattedAmt,
  }) {
    final notePart = (widget.titleOrNote != null && widget.titleOrNote!.trim().isNotEmpty)
        ? ' regarding "${widget.titleOrNote!.trim()}"'
        : '';

    if (upiId != null && upiId.trim().isNotEmpty) {
      final cleanUpi = upiId.trim();
      final nameParam = Uri.encodeComponent(payeeName ?? 'Payee');
      final noteParam = Uri.encodeComponent(widget.titleOrNote ?? (widget.isKhata ? 'Khata Settlement' : 'Split Bill Share'));
      final upiUri = 'upi://pay?pa=$cleanUpi&pn=$nameParam&am=${widget.amount.toStringAsFixed(2)}&cu=INR&tn=$noteParam';

      if (widget.isKhata) {
        return 'Hi ${widget.personName}! 👋\n\n'
            'This is a friendly reminder for $formattedAmt$notePart on Grow Expense App.\n\n'
            '📱 Pay directly via UPI:\n'
            '• UPI ID: $cleanUpi\n'
            '• Fast Pay Link: $upiUri\n\n'
            'Please settle whenever convenient. Thank you! 🙏';
      } else {
        return 'Hey ${widget.personName}! 👋\n\n'
            'Your split share is $formattedAmt$notePart on Grow Expense App.\n\n'
            '📱 Pay directly via UPI:\n'
            '• UPI ID: $cleanUpi\n'
            '• Fast Pay Link: $upiUri\n\n'
            'Please settle whenever possible. Thanks! 🙏';
      }
    }

    // Clean message without payment method (NOTE IS NOT INCLUDED IN SHARED TEXT)
    if (widget.isKhata) {
      return 'Hi ${widget.personName}! 👋\n\n'
          'This is a friendly reminder regarding $formattedAmt$notePart on Grow Expense App.\n\n'
          'Please settle whenever convenient. Thank you! 🙏';
    } else {
      return 'Hey ${widget.personName}! 👋\n\n'
          'Your split share is $formattedAmt$notePart on Grow Expense App.\n\n'
          'Please settle whenever possible. Thanks! 🙏';
    }
  }

  Future<void> _shareOnWhatsApp(BuildContext context, String message) async {
    if (widget.phoneNumber != null && widget.phoneNumber!.trim().isNotEmpty) {
      String cleanPhone = widget.phoneNumber!.replaceAll(RegExp(r'[^0-9+]'), '');
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

    // Fallback: general share sheet
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'Payment Reminder for ${widget.personName}',
      ),
    );
  }

  void _showQrCodeDialog({
    required BuildContext context,
    required String upiId,
    required String? qrCodeUrl,
    required String payeeName,
    required String title,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final noteParam = Uri.encodeComponent(widget.titleOrNote ?? (widget.isKhata ? 'Khata Settlement' : 'Split Bill Share'));
    final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=${widget.amount.toStringAsFixed(2)}&cu=INR&tn=$noteParam';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00D09C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan with GPay, PhonePe, Paytm or any UPI app',
              textAlign: TextAlign.center,
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
              child: qrCodeUrl != null && qrCodeUrl.isNotEmpty
                  ? (qrCodeUrl.startsWith('http')
                      ? Image.network(qrCodeUrl, width: 200, height: 200, fit: BoxFit.contain)
                      : Image.file(File(qrCodeUrl), width: 200, height: 200, fit: BoxFit.contain))
                  : QrImageView(
                      data: upiUri,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              currencyFormat.format(widget.amount),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final formattedAmt = currencyFormat.format(widget.amount);

    return Consumer2<ExpenseProvider, UserProvider>(
      builder: (context, provider, userProvider, _) {
        final paymentDetails = provider.paymentDetails;
        
        // Find selected payment method or fallback to primary/first
        PaymentDetail? activePayment;
        if (_selectedPaymentId != null) {
          activePayment = paymentDetails.where((p) => p.id == _selectedPaymentId).firstOrNull;
        }
        activePayment ??= provider.primaryPaymentDetail;

        final effectiveUpiId = widget.customPayerUpiId != null && widget.customPayerUpiId!.isNotEmpty
            ? widget.customPayerUpiId
            : (activePayment?.upiId.isNotEmpty == true ? activePayment!.upiId : null);

        final payeeName = userProvider.userProfile?['full_name']?.toString() ?? 'Grow Expense User';
        final hasPaymentMethod = effectiveUpiId != null && effectiveUpiId.trim().isNotEmpty;
        final shareMessage = _buildShareMessage(
          upiId: effectiveUpiId,
          payeeName: payeeName,
          formattedAmt: formattedAmt,
        );

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161920) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Handle Bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.isKhata ? Icons.menu_book_rounded : Icons.call_split_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isKhata ? 'Khata Payment Reminder' : 'Split Bill Share Reminder',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Remind ${widget.personName} to settle $formattedAmt',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount Due Pill Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AMOUNT TO COLLECT',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.personName,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (widget.titleOrNote != null && widget.titleOrNote!.isNotEmpty)
                            Text(
                              'Note: ${widget.titleOrNote}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        formattedAmt,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ──────────────────────────────────────────────────────────
                // MULTI-ACCOUNT CHIP SELECTOR (IF MULTIPLE METHODS EXIST)
                // ──────────────────────────────────────────────────────────
                if (paymentDetails.length > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT PAYMENT ACCOUNT',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${paymentDetails.length} available',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: paymentDetails.map((p) {
                        final isSelected = (activePayment?.id == p.id);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPaymentId = p.id),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.15)
                                  : (isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryColor : borderColor,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (p.isPrimary)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(Icons.star_rounded, size: 14, color: primaryColor),
                                  ),
                                Text(
                                  p.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? primaryColor
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ──────────────────────────────────────────────────────────
                // ACTIVE PAYMENT METHOD CARD VS NOT CONFIGURED TIP
                // ──────────────────────────────────────────────────────────
                if (hasPaymentMethod) ...[
                  // ACTIVE PAYMENT METHOD CARD
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.qr_code_2_rounded, color: primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activePayment?.name ?? 'UPI Payment Linked',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                effectiveUpiId,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showQrCodeDialog(
                            context: context,
                            upiId: effectiveUpiId,
                            qrCodeUrl: activePayment?.qrCodeUrl,
                            payeeName: payeeName,
                            title: activePayment?.name ?? 'Payment QR',
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: primaryColor.withValues(alpha: 0.15),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.visibility_rounded, size: 14, color: Color(0xFF00D09C)),
                          label: Text(
                            'Show QR',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // NOT CONFIGURED TIP
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF262117) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF854D0E) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tip: Save your UPI ID for instant 1-tap payments',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Save your UPI ID & QR Code in Payment Details so friends can pay you directly with 1 tap. (This note won\'t be shared with them).',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey[300] : const Color(0xFF78350F),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PaymentDetailsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Setup Payment Method',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                ],

                const SizedBox(height: 16),

                // Message Preview Box
                Text(
                  'MESSAGE PREVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    shareMessage,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Action Buttons (WhatsApp, Other Apps, Copy)
                Row(
                  children: [
                    // WhatsApp Share Button
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _shareOnWhatsApp(context, shareMessage);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Share on WhatsApp',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Share Sheet
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await SharePlus.instance.share(
                            ShareParams(
                              text: shareMessage,
                              subject: 'Payment Reminder for $formattedAmt',
                            ),
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: Text(
                          'Other Apps',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy to Clipboard
                    IconButton(
                      tooltip: 'Copy Message',
                      style: IconButton.styleFrom(
                        backgroundColor: cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareMessage));
                        CustomToast.show(context, '📋 Reminder copied to clipboard!');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
