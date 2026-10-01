import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_code_dart_decoder/qr_code_dart_decoder.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import '../services/supabase_service.dart';
import '../models/payment_detail.dart';
import '../widgets/custom_toast.dart';

class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.90);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openAddEditSheet({PaymentDetail? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditPaymentSheet(
        existing: existing,
        onSave: (name, upiId, qrPath, isPrimary) async {
          final provider = Provider.of<ExpenseProvider>(context, listen: false);
          if (existing == null) {
            await provider.addPaymentDetail(
              name: name,
              upiId: upiId,
              qrCodeUrl: qrPath,
              isPrimary: isPrimary,
            );
            if (mounted) {
              CustomToast.show(context, '✅ Payment method "$name" added!');
            }
          } else {
            final updated = existing.copyWith(
              name: name,
              upiId: upiId,
              qrCodeUrl: qrPath,
              isPrimary: isPrimary,
              updatedAt: DateTime.now(),
            );
            await provider.updatePaymentDetail(updated);
            if (mounted) {
              CustomToast.show(context, '✅ Payment method updated!');
            }
          }
        },
      ),
    );
  }

  void _openManageReorderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ManagePaymentMethodsSheet(),
    );
  }

  void _showZoomQrDialog({
    required BuildContext context,
    required String title,
    required String upiId,
    required String? qrCodeUrl,
    required String payeeName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanUpi = upiId.trim();
    final upiUri = 'upi://pay?pa=$cleanUpi&pn=${Uri.encodeComponent(payeeName)}&cu=INR&tn=${Uri.encodeComponent(title)}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1E26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: qrCodeUrl != null && qrCodeUrl.isNotEmpty
                  ? (qrCodeUrl.startsWith('http')
                      ? Image.network(
                          qrCodeUrl,
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          File(qrCodeUrl),
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ))
                  : QrImageView(
                      data: upiUri,
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              upiId,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00D09C),
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12141A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Payment Methods & QR',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        actions: [
          // Clear + icon for adding new payment method (tune icon removed as requested)
          IconButton(
            tooltip: 'Add Payment Method',
            icon: const Icon(Icons.add_rounded, color: Color(0xFF00D09C), size: 26),
            onPressed: () => _openAddEditSheet(),
          ),
        ],
      ),
      body: Consumer2<ExpenseProvider, UserProvider>(
        builder: (context, provider, userProvider, _) {
          final items = provider.paymentDetails;
          final payeeName = userProvider.userProfile?['full_name']?.toString() ?? 'Grow Expense User';

          if (items.isEmpty) {
            return _buildEmptyState(isDark, primaryColor);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SAVED CARDS (${items.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      if (items.length > 1)
                        InkWell(
                          onTap: _openManageReorderSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_vert_rounded, size: 16, color: primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Arrange Order',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ──────────────────────────────────────────────────────────
                // CAROUSEL / SLIDER (SWIPE LEFT / RIGHT)
                // ──────────────────────────────────────────────────────────
                SizedBox(
                  height: 440,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: items.length,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildPaymentCard(
                        context: context,
                        item: item,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        payeeName: payeeName,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Pagination Dots & Counter
                if (items.length > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(items.length, (i) {
                      final isCurrent = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isCurrent ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isCurrent ? primaryColor : (isDark ? Colors.grey[700] : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Card ${_currentPage + 1} of ${items.length} (Swipe left/right)',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ──────────────────────────────────────────────────────────
                // REDESIGNED ACTION BUTTONS (CLEAN, COMPACT & PREMIUM)
                // ──────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Primary Button: Add New Card
                      Expanded(
                        child: InkWell(
                          onTap: () => _openAddEditSheet(),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D09C), Color(0xFF00B084)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Add New Card',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (items.length > 1) ...[
                        const SizedBox(width: 12),
                        // Secondary Button: Reorder & Manage
                        InkWell(
                          onTap: _openManageReorderSheet,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E232E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.swap_vert_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                                const SizedBox(width: 6),
                                Text(
                                  'Arrange',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primaryColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.qr_code_scanner_rounded, size: 64, color: primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              'No Payment Methods Added',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your UPI ID or QR code to easily collect payments in Khata Book, Split Bills, and Invoices.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openAddEditSheet(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                '+ Add First Payment Method',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard({
    required BuildContext context,
    required PaymentDetail item,
    required bool isDark,
    required Color primaryColor,
    required String payeeName,
  }) {
    final cleanUpi = item.upiId.trim();
    final upiUri = 'upi://pay?pa=$cleanUpi&pn=${Uri.encodeComponent(payeeName)}&cu=INR&tn=${Uri.encodeComponent(item.name)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: item.isPrimary
              ? primaryColor.withValues(alpha: isDark ? 0.6 : 0.8)
              : (isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0)),
          width: item.isPrimary ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (item.isPrimary ? primaryColor : Colors.black)
                .withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            // Card Header: Title & Primary Tag
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (item.isPrimary) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 12, color: primaryColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    'PRIMARY',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.isPrimary ? 'Default for all sharing & invoices' : 'Secondary payment option',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Quick Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) async {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    if (val == 'edit') {
                      _openAddEditSheet(existing: item);
                    } else if (val == 'primary') {
                      await provider.setPrimaryPaymentDetail(item.id);
                      if (context.mounted) {
                        CustomToast.show(context, '⭐ "${item.name}" set as Primary Payment Method');
                      }
                    } else if (val == 'delete') {
                      await provider.deletePaymentDetail(item.id);
                      if (context.mounted) {
                        CustomToast.show(context, 'Payment method deleted');
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!item.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline_rounded, size: 18, color: Color(0xFF00D09C)),
                            SizedBox(width: 10),
                            Text('Set as Primary'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          SizedBox(width: 10),
                          Text('Delete Method', style: TextStyle(color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // QR Code Box (Tap to Zoom)
            GestureDetector(
              onTap: () => _showZoomQrDialog(
                context: context,
                title: item.name,
                upiId: item.upiId,
                qrCodeUrl: item.qrCodeUrl,
                payeeName: payeeName,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: item.qrCodeUrl != null && item.qrCodeUrl!.isNotEmpty
                    ? (item.qrCodeUrl!.startsWith('http')
                        ? Image.network(
                            item.qrCodeUrl!,
                            width: 165,
                            height: 165,
                            fit: BoxFit.contain,
                          )
                        : Image.file(
                            File(item.qrCodeUrl!),
                            width: 165,
                            height: 165,
                            fit: BoxFit.contain,
                          ))
                    : QrImageView(
                        data: upiUri,
                        version: QrVersions.auto,
                        size: 165.0,
                        backgroundColor: Colors.white,
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // UPI ID Pill with Copy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161920) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.upiId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item.upiId));
                      CustomToast.show(context, '📋 UPI ID copied: ${item.upiId}');
                    },
                    child: Icon(Icons.copy_rounded, size: 16, color: primaryColor),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Card Bottom Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openAddEditSheet(existing: item),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 15),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!item.isPrimary) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final provider = Provider.of<ExpenseProvider>(context, listen: false);
                        await provider.setPrimaryPaymentDetail(item.id);
                        if (context.mounted) {
                          CustomToast.show(context, '⭐ Set as Primary!');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        foregroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.star_rounded, size: 15),
                      label: Text(
                        'Set Primary',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// ADD / EDIT PAYMENT METHOD MODAL SHEET
// ──────────────────────────────────────────────────────────
class _AddEditPaymentSheet extends StatefulWidget {
  final PaymentDetail? existing;
  final Function(String name, String upiId, String? qrPath, bool isPrimary) onSave;

  const _AddEditPaymentSheet({this.existing, required this.onSave});

  @override
  State<_AddEditPaymentSheet> createState() => _AddEditPaymentSheetState();
}

class _AddEditPaymentSheetState extends State<_AddEditPaymentSheet> {
  final _nameController = TextEditingController();
  final _upiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _qrMode = 'generate'; // 'generate' (App auto-generates QR) or 'upload' (User picks image)
  String? _qrPath;
  bool _isPrimary = false;
  bool _isUploadingQr = false;

  final List<String> _quickNameSuggestions = [
    'Personal GPay',
    'Shop PhonePe',
    'Business QR',
    'Paytm UPI',
    'HDFC Bank',
    'SBI Account',
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _upiController.text = widget.existing!.upiId;
      _qrPath = widget.existing!.qrCodeUrl;
      _isPrimary = widget.existing!.isPrimary;
      _qrMode = (_qrPath != null && _qrPath!.isNotEmpty) ? 'upload' : 'generate';
    } else {
      _nameController.text = 'Personal UPI';
      // ONLY set isPrimary to true if there are ZERO payment methods yet.
      // If one is already primary, default isPrimary to false (OFF) as requested!
      _isPrimary = provider.paymentDetails.isEmpty;
      _qrMode = 'generate';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _pickCustomQr() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingQr = true);
      String savedPath = image.path;

      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'payment_qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(image.path).copy('${appDir.path}/$fileName');
        savedPath = savedFile.path;

        // Upload to Supabase Storage if user is signed in
        final supabase = SupabaseService.instance;
        if (supabase.currentUser != null) {
          final imageBytes = await savedFile.readAsBytes();
          final cloudUrl = await supabase.uploadQrCode(imageBytes, fileName);
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            savedPath = cloudUrl;
          }
        }
      } catch (_) {}

      // Decode QR for UPI ID auto-fill
      try {
        final Uint8List imageBytes = await File(image.path).readAsBytes();
        final decoder = QrCodeDartDecoder();
        final result = await decoder.decodeFile(imageBytes);
        final qrData = result?.text;
        if (qrData != null && qrData.isNotEmpty) {
          String? extractedUpi;
          if (qrData.startsWith('upi://')) {
            final uri = Uri.parse(qrData);
            extractedUpi = uri.queryParameters['pa'];
          } else if (qrData.contains('@')) {
            final match = RegExp(r'[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}').firstMatch(qrData);
            if (match != null) extractedUpi = match.group(0);
          }
          if (extractedUpi != null && extractedUpi.isNotEmpty && _upiController.text.trim().isEmpty) {
            _upiController.text = extractedUpi;
          }
        }
      } catch (_) {}

      setState(() {
        _isUploadingQr = false;
        _qrPath = savedPath;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    // If auto-generate mode is selected, _qrPath is null (app auto-generates on the fly)
    final finalQrPath = (_qrMode == 'upload') ? _qrPath : null;

    widget.onSave(
      _nameController.text.trim(),
      _upiController.text.trim(),
      finalQrPath,
      _isPrimary,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF1E222D) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing == null ? 'Add Payment Method' : 'Edit Payment Method',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Account Name Input
              TextFormField(
                controller: _nameController,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name for this payment method' : null,
                decoration: InputDecoration(
                  labelText: 'Payment Method Name *',
                  hintText: 'e.g. Personal GPay, Shop PhonePe',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),

              // Quick Name Suggestion Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _quickNameSuggestions.map((name) {
                  return InkWell(
                    onTap: () => setState(() => _nameController.text = name),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262B36) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        name,
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 2. UPI ID Input
              TextFormField(
                controller: _upiController,
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter a valid UPI ID';
                  if (!val.contains('@')) return 'UPI ID must contain "@" (e.g. name@okaxis)';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'UPI ID *',
                  hintText: 'yourname@okhdfcbank',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),

              // 3. QR Code Source Option (Auto-Generate vs Custom Upload)
              Text(
                'QR CODE SOURCE',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  // Option A: Auto-Generate QR (App generates dynamically)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _qrMode = 'generate';
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _qrMode == 'generate'
                              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                              : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _qrMode == 'generate' ? primaryColor : borderColor,
                            width: _qrMode == 'generate' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              color: _qrMode == 'generate' ? primaryColor : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Auto-Generate QR',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _qrMode == 'generate' ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            Text(
                              '(Recommended)',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Option B: Upload Custom QR Image
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _qrMode = 'upload';
                        });
                        if (_qrPath == null) _pickCustomQr();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _qrMode == 'upload'
                              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                              : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _qrMode == 'upload' ? primaryColor : borderColor,
                            width: _qrMode == 'upload' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: _qrMode == 'upload' ? primaryColor : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload QR Image',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _qrMode == 'upload' ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            Text(
                              _qrPath != null ? '(Image Selected)' : '(From Gallery)',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Detail Section for the Selected Mode
              if (_qrMode == 'generate') ...[
                // Auto-generate notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A22) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'App will automatically generate a dynamic, high-resolution UPI QR code directly from your UPI ID.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Upload image controls
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      if (_qrPath != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _qrPath!.startsWith('http')
                              ? Image.network(_qrPath!, width: 44, height: 44, fit: BoxFit.cover)
                              : Image.file(File(_qrPath!), width: 44, height: 44, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _qrPath != null ? 'Custom Image Attached' : 'No image chosen yet',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _qrPath != null ? 'Will be displayed on this card' : 'Tap choose image from gallery',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isUploadingQr ? null : _pickCustomQr,
                        icon: const Icon(Icons.image_search_rounded, size: 16),
                        label: Text(_qrPath != null ? 'Change' : 'Choose'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 4. Primary Switch (Intelligently toggled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: _isPrimary ? primaryColor : Colors.grey, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set as Primary Method',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Used by default in Khata Book & Split Bills',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      activeColor: primaryColor,
                      value: _isPrimary,
                      onChanged: (v) => setState(() => _isPrimary = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  widget.existing == null ? 'Save Payment Method' : 'Update Payment Method',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// MANAGE & REORDER PAYMENT METHODS MODAL SHEET
// ──────────────────────────────────────────────────────────
class _ManagePaymentMethodsSheet extends StatefulWidget {
  const _ManagePaymentMethodsSheet();

  @override
  State<_ManagePaymentMethodsSheet> createState() => _ManagePaymentMethodsSheetState();
}

class _ManagePaymentMethodsSheetState extends State<_ManagePaymentMethodsSheet> {
  late List<PaymentDetail> _localList;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    _localList = List.from(provider.paymentDetails);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arrange Order & Sequence',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Drag items to change card order or tap star to set primary',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
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

          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: _localList.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _localList.removeAt(oldIndex);
                  _localList.insert(newIndex, item);
                });
                final provider = Provider.of<ExpenseProvider>(context, listen: false);
                provider.reorderPaymentDetails(_localList);
              },
              itemBuilder: (context, index) {
                final item = _localList[index];
                return Container(
                  key: ValueKey(item.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.isPrimary
                          ? primaryColor.withValues(alpha: 0.5)
                          : (isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: item.isPrimary ? 'Primary' : 'Make Primary',
                          icon: Icon(
                            item.isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: item.isPrimary ? primaryColor : Colors.grey,
                            size: 22,
                          ),
                          onPressed: () async {
                            final provider = Provider.of<ExpenseProvider>(context, listen: false);
                            await provider.setPrimaryPaymentDetail(item.id);
                            setState(() {
                              _localList = List.from(provider.paymentDetails);
                            });
                          },
                        ),
                      ],
                    ),
                    title: Text(
                      item.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      item.upiId,
                      style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                      onPressed: () async {
                        final provider = Provider.of<ExpenseProvider>(context, listen: false);
                        await provider.deletePaymentDetail(item.id);
                        setState(() {
                          _localList = List.from(provider.paymentDetails);
                        });
                        if (context.mounted) {
                          CustomToast.show(context, 'Payment method deleted');
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
