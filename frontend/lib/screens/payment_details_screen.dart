import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_code_tools/qr_code_tools.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
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

      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'payment_qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(image.path).copy('${appDir.path}/$fileName');
        savedPath = savedFile.path;
      } catch (_) {
        // Fallback to temp path if copy fails
      }

      setState(() {
        _cachedQrPath = savedPath;
      });

      // Attempt to decode QR data from image and auto-fill UPI ID
      try {
        final qrData = await QrCodeToolsPlugin.decodeFrom(savedPath);
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
      CustomToast.show(context, 'Payment profiles saved successfully!');
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

    // Check if custom QR image file exists locally
    final hasLocalQrFile = _cachedQrPath != null && File(_cachedQrPath!).existsSync();

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
                              onPressed: _pickCustomQr,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Theme.of(context).primaryColor),
                                foregroundColor: Theme.of(context).primaryColor,
                              ),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload QR from Gallery'),
                            ),
                          ),
                        ],
                      ),
                      if (_cachedQrPath != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF00D09C), size: 16),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Custom QR Code attached.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _cachedQrPath = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            ),
                          ],
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

                      // Standard Live QR generated by qr_flutter!
                      if (!hasLocalQrFile) ...[
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
                        if (_cachedQrPath != null) ...[
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
                                  'Custom QR file missing on this device.',
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.amber[800], fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        // Render the user's custom cached app QR image!
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
                            child: Image.file(
                              File(_cachedQrPath!),
                              height: 220,
                              width: 220,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan custom payment QR code',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
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
