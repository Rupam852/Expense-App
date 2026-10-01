import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
import '../widgets/app_logo.dart';
import '../widgets/custom_toast.dart';

class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _upiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _cachedQrPath;
  bool _isEditing = false;
  bool _isUploadingQr = false;

  @override
  void initState() {
    super.initState();
    // Prefill controllers if data is already cached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      if (expenseProvider.paymentDetails.isNotEmpty) {
        final profile = expenseProvider.paymentDetails.first;
        _upiController.text = profile.upiId;
        setState(() {
          _cachedQrPath = profile.qrCodeUrl;
        });
      }
    });
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  // Pick custom payment QR image from Gallery, decode QR data, and auto-fill UPI ID
  void _pickCustomQr() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      String savedPath = image.path;
      setState(() {
        _isUploadingQr = true;
      });

      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'payment_qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(image.path).copy('${appDir.path}/$fileName');
        savedPath = savedFile.path;

        // Upload to Supabase Storage if user is logged in for cloud permanence
        final supabase = SupabaseService.instance;
        if (supabase.currentUser != null) {
          final imageBytes = await savedFile.readAsBytes();
          final cloudUrl = await supabase.uploadQrCode(imageBytes, fileName);
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            savedPath = cloudUrl;
          }
        }
      } catch (e) {
        print('[PaymentDetails] QR save/upload warning: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingQr = false;
            _cachedQrPath = savedPath;
          });
        }
      }

      // Attempt to decode QR data from image and auto-fill UPI ID
      try {
        final Uint8List imageBytes = await File(image.path).readAsBytes();
        final decoder = QrCodeDartDecoder();
        final result = await decoder.decodeFile(imageBytes);
        final qrData = result?.text;

        if (qrData != null && qrData.isNotEmpty) {
          String? extractedUpiId;

          // Parse UPI deep-link format: upi://pay?pa=upiid@bank&pn=Name&...
          if (qrData.toLowerCase().startsWith('upi://')) {
            final uri = Uri.tryParse(qrData);
            extractedUpiId = uri?.queryParameters['pa'];
          } else if (qrData.contains('@')) {
            // Sometimes QR directly contains just the UPI ID
            extractedUpiId = qrData.trim();
          }

          if (extractedUpiId != null && extractedUpiId.isNotEmpty) {
            _upiController.text = extractedUpiId;
            if (mounted) {
              CustomToast.show(context, '✅ QR scanned! UPI ID auto-filled.');
            }
          } else {
            if (mounted) {
              CustomToast.show(context, 'QR saved. Please enter UPI ID manually.');
            }
          }
        } else {
          if (mounted) {
            CustomToast.show(context, 'QR saved. Please enter UPI ID manually.');
          }
        }
      } catch (e) {
        // Decoding failed (e.g., non-QR image or unreadable QR)
        if (mounted) {
          CustomToast.show(context, 'QR saved. Please verify or enter UPI ID.');
        }
      }
    }
  }

  void _confirmRemoveCustomQr(BuildContext context, PaymentDetail details) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E232E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Custom QR Code?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Aapka uploaded QR code image remove ho jayega aur app automatically standard dynamic UPI QR code par switch kar dega.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
              await expenseProvider.savePaymentDetails(
                upiId: details.upiId,
                qrCodeUrl: null,
              );
              setState(() {
                _cachedQrPath = null;
              });
              if (context.mounted) {
                CustomToast.show(context, '🗑️ Custom QR removed! Switched to dynamic UPI QR.');
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    
    await expenseProvider.savePaymentDetails(
      upiId: _upiController.text.trim(),
      qrCodeUrl: _cachedQrPath,
    );

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      CustomToast.show(context, 'Payment profile saved and synced to cloud!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasDetails = expenseProvider.paymentDetails.isNotEmpty;
    final details = hasDetails ? expenseProvider.paymentDetails.first : null;

    final userName = userProvider.userProfile?['name'] ?? 'User';

    // Get the active QR path
    final activeQrPath = _isEditing ? _cachedQrPath : (details?.qrCodeUrl ?? _cachedQrPath);
    final isNetworkQr = activeQrPath != null && (activeQrPath.startsWith('http://') || activeQrPath.startsWith('https://'));
    final hasLocalQrFile = activeQrPath != null && !isNetworkQr && File(activeQrPath).existsSync();
    final hasCustomQr = isNetworkQr || hasLocalQrFile;

    // Standardized UPI link for native QR codes scanning
    // Format: upi://pay?pa=upi_address&pn=Display_Name
    final upiString = hasDetails 
        ? 'upi://pay?pa=${details!.upiId}&pn=${Uri.encodeComponent(userName)}' 
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repayments Setup'),
        actions: [
          if (hasDetails && !_isEditing)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _upiController.text = details!.upiId;
                  _cachedQrPath = details.qrCodeUrl;
                });
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Instructions Header
              Text(
                'COLLECT REIMBURSEMENTS',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Text(
                'Input your default payment ID to append scan-to-pay codes instantly to your generated PDF statements.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),

              // 2. Setup Form (Shows if no profile set or during editing)
              if (!hasDetails || _isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181B22) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Setup Payment Profile',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // UPI Input Field
                      TextFormField(
                        controller: _upiController,
                        decoration: const InputDecoration(
                          hintText: 'example@paytm or upi-id@bank',
                          labelText: 'Your UPI ID',
                          prefixIcon: Icon(Icons.alternate_email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'UPI ID is required.';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid UPI address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Custom QR File attachment
                      Text(
                        'CUSTOM APP QR CODE (OPTIONAL)',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingQr ? null : _pickCustomQr,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Theme.of(context).primaryColor),
                                foregroundColor: Theme.of(context).primaryColor,
                              ),
                              icon: _isUploadingQr
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: Text(_isUploadingQr ? 'Processing QR...' : 'Upload QR from Gallery'),
                            ),
                          ),
                        ],
                      ),
                      if (_cachedQrPath != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF252A36) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00D09C).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF00D09C), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Custom QR attached',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _cachedQrPath = null;
                                  });
                                  CustomToast.show(context, 'Custom QR detached');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('Remove', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Submit Details
                      ElevatedButton(
                        onPressed: _saveDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Save Setup', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      
                      if (hasDetails) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                            });
                          },
                          child: const Text('Cancel Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // 3. Render Profile (Live standard QR + Custom image)
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181B22) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Active UPI Title Card
                      Text(
                        userName.toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details!.upiId,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                      ),
                      const SizedBox(height: 32),

                      // Render QR Code: Custom image (Cloud or Local) or Live Standard UPI QR
                      if (hasCustomQr) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: isNetworkQr
                                ? Image.network(
                                    activeQrPath!,
                                    height: 220,
                                    width: 220,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return SizedBox(
                                        height: 220,
                                        width: 220,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => QrImageView(
                                      data: upiString,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                      gapless: false,
                                      foregroundColor: const Color(0xFF1E2229),
                                    ),
                                  )
                                : Image.file(
                                    File(activeQrPath!),
                                    height: 220,
                                    width: 220,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => QrImageView(
                                      data: upiString,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                      gapless: false,
                                      foregroundColor: const Color(0xFF1E2229),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Custom uploaded QR code',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        // Direct Remove Custom QR button in View Mode
                        OutlinedButton.icon(
                          onPressed: () => _confirmRemoveCustomQr(context, details),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[400],
                            side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: Text(
                            'Remove Custom QR',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ] else ...[
                        // Standard Live QR generated by qr_flutter!
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: upiString,
                            version: QrVersions.auto,
                            size: 200.0,
                            gapless: false,
                            foregroundColor: const Color(0xFF1E2229),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan to Pay standard UPI',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        if (activeQrPath != null && !hasCustomQr) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Custom QR file missing on this device. Showing dynamic QR.',
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.amber[800], fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Supports BHIM, GPay, PhonePe, Paytm, and all banking apps.',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE5E9F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF00D09C),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How to avoid "UPI Not Verified" warning',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'If you only type your UPI ID, payment apps (GPay, PhonePe, Paytm) may display a "UPI Not Verified" warning during scans because it lacks official merchant cryptographic signatures.\n\n'
                            'To display a fully verified original profile, please screenshot your official merchant QR code from your business dashboard (e.g. PhonePe/Paytm Business) and upload it here instead. We display it in its original format so customers scan and pay securely without warnings.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
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
