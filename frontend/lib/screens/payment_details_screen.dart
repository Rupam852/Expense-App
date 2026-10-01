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
  bool _showPreview = false;

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
            _showPreview = true;
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
            extractedUpiId = qrData.trim();
          }

          if (extractedUpiId != null && extractedUpiId.isNotEmpty) {
            _upiController.text = extractedUpiId;
            if (mounted) {
              CustomToast.show(context, '✅ QR scanned & UPI ID auto-filled!');
            }
          } else {
            if (mounted) {
              CustomToast.show(context, 'QR attached. Please enter or verify UPI ID.');
            }
          }
        } else {
          if (mounted) {
            CustomToast.show(context, 'QR attached. Please enter or verify UPI ID.');
          }
        }
      } catch (e) {
        if (mounted) {
          CustomToast.show(context, 'QR attached. Please enter UPI ID.');
        }
      }
    }
  }

  // Generate / Re-generate Dynamic Standard QR from typed UPI ID
  void _generateDynamicQr() {
    final upi = _upiController.text.trim();
    if (upi.isEmpty) {
      CustomToast.show(context, '⚠️ Pehle UPI ID type ya paste karein');
      return;
    }
    if (!upi.contains('@')) {
      CustomToast.show(context, '⚠️ Sahi UPI ID dalein (e.g. yourname@bank)');
      return;
    }

    setState(() {
      _cachedQrPath = null; // Clears custom photo to use dynamic QR
      _showPreview = true;
    });

    CustomToast.show(context, '⚡ Dynamic Standard QR code generated!');
  }

  // Dialog to confirm removing custom attached QR photo (fallback to dynamic QR)
  void _confirmRemoveCustomQr(BuildContext context, PaymentDetail details) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E232E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Custom QR Photo?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Aapka uploaded QR image remove ho jayega aur app automatically standard dynamic UPI QR code par switch kar dega.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[800],
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
                CustomToast.show(context, '🔄 Custom QR removed! Switched to dynamic QR.');
              }
            },
            child: const Text('Switch to Dynamic QR'),
          ),
        ],
      ),
    );
  }

  // Dialog to confirm deleting entire payment setup (UPI ID + QR code)
  void _confirmDeleteEntireProfile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E232E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete Payment Setup?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Aapka UPI ID aur QR code dono permanently delete ho jayenge. Iske baad aapke statements me koi payment QR attach nahi hoga jab tak aap naya setup nahi karte.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
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
              await expenseProvider.deletePaymentDetails();
              setState(() {
                _upiController.clear();
                _cachedQrPath = null;
                _isEditing = false;
                _showPreview = false;
              });
              if (context.mounted) {
                CustomToast.show(context, '🗑️ Payment profile completely removed!');
              }
            },
            child: const Text('Delete Setup'),
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
      _showPreview = false;
    });

    if (mounted) {
      CustomToast.show(context, '✅ Payment setup saved & synced to cloud!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);

    final hasDetails = expenseProvider.paymentDetails.isNotEmpty;
    final details = hasDetails ? expenseProvider.paymentDetails.first : null;
    final userName = userProvider.userProfile?['name'] ?? 'User';

    // Active QR path & resolution
    final activeQrPath = _isEditing ? _cachedQrPath : (details?.qrCodeUrl ?? _cachedQrPath);
    final isNetworkQr = activeQrPath != null && (activeQrPath.startsWith('http://') || activeQrPath.startsWith('https://'));
    final hasLocalQrFile = activeQrPath != null && !isNetworkQr && File(activeQrPath).existsSync();
    final hasCustomQr = isNetworkQr || hasLocalQrFile;

    // Standardized UPI link for dynamic QR generation
    final currentUpi = _isEditing ? _upiController.text.trim() : (details?.upiId ?? _upiController.text.trim());
    final dynamicUpiString = currentUpi.isNotEmpty
        ? 'upi://pay?pa=$currentUpi&pn=${Uri.encodeComponent(userName)}'
        : '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12141A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        elevation: 0,
        title: Text(
          'Repayments Setup',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (hasDetails && !_isEditing) ...[
            IconButton(
              tooltip: 'Edit Setup',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _upiController.text = details!.upiId;
                  _cachedQrPath = details.qrCodeUrl;
                  _showPreview = true;
                });
              },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete Setup',
              onPressed: () => _confirmDeleteEntireProfile(context),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Instructions Header
              Text(
                'COLLECT REIMBURSEMENTS & SPLITS',
                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Text(
                'Add your UPI ID or QR code. It will be used for Split Bills, Khata settlements, and PDF statements.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),

              // 2. Setup / Edit Form
              if (!hasDetails || _isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E232E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.qr_code_2_rounded, color: primaryColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEditing ? 'Edit Payment Setup' : 'Setup UPI & QR Code',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Enter UPI ID to auto-generate QR, or upload an image',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // UPI Input Field
                      TextFormField(
                        controller: _upiController,
                        onChanged: (val) {
                          if (_showPreview && _cachedQrPath == null) {
                            setState(() {}); // Rebuild dynamic preview live
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. rahul@oksbi or 9876543210@paytm',
                          labelText: 'Your UPI ID',
                          prefixIcon: const Icon(Icons.alternate_email_outlined),
                          suffixIcon: _upiController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _upiController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'UPI ID daalna zaroori hai.';
                          }
                          if (!value.contains('@')) {
                            return 'Valid UPI address dalein (jaise user@bank).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2 Method Buttons (Generate QR vs Upload Image)
                      Row(
                        children: [
                          // Button 1: Generate / Re-generate Dynamic QR
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _generateDynamicQr,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                foregroundColor: primaryColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                                ),
                              ),
                              icon: const Icon(Icons.bolt_rounded, size: 18),
                              label: Text(
                                _isEditing ? 'Re-generate QR' : 'Generate QR',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Button 2: Upload from Gallery
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingQr ? null : _pickCustomQr,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB)),
                                foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              ),
                              icon: _isUploadingQr
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.photo_library_outlined, size: 18),
                              label: Text(
                                _isUploadingQr ? 'Uploading...' : 'Upload Image',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Attached / Generated QR Status & Live Preview
                      if (_cachedQrPath != null || (_showPreview && _upiController.text.contains('@'))) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141820) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _cachedQrPath != null
                                  ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                                  : primaryColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _cachedQrPath != null ? Icons.image_rounded : Icons.verified_rounded,
                                    color: _cachedQrPath != null ? const Color(0xFF3B82F6) : primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _cachedQrPath != null
                                          ? 'Custom QR Image Attached'
                                          : 'Standard Dynamic NPCI QR',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (_cachedQrPath != null)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _cachedQrPath = null;
                                        });
                                        CustomToast.show(context, '🔄 Switched to auto-generated dynamic QR');
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      ),
                                      icon: const Icon(Icons.delete_outline, size: 15),
                                      label: const Text('Remove Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Live Box Preview
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _cachedQrPath != null
                                    ? (_cachedQrPath!.startsWith('http')
                                        ? Image.network(
                                            _cachedQrPath!,
                                            height: 140,
                                            width: 140,
                                            fit: BoxFit.contain,
                                          )
                                        : Image.file(
                                            File(_cachedQrPath!),
                                            height: 140,
                                            width: 140,
                                            fit: BoxFit.contain,
                                          ))
                                    : QrImageView(
                                        data: dynamicUpiString.isNotEmpty ? dynamicUpiString : 'upi://pay?pa=test@bank',
                                        version: QrVersions.auto,
                                        size: 140.0,
                                        gapless: false,
                                        foregroundColor: const Color(0xFF1E2229),
                                      ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _cachedQrPath != null ? 'Gallery Custom Image' : 'Auto-generated standard QR code',
                                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
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
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          _isEditing ? 'Update & Save Changes' : 'Save Payment Setup',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      
                      if (hasDetails) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                    _showPreview = false;
                                  });
                                },
                                child: const Text('Cancel Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _confirmDeleteEntireProfile(context),
                                icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                                label: const Text('Delete Setup', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // 3. Render Profile Card (Active standard QR or Custom image)
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E232E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Active UPI Title Card
                      Text(
                        userName.toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          details!.upiId,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Render QR Code: Custom image (Cloud or Local) or Live Standard UPI QR
                      if (hasCustomQr) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
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
                                    height: 200,
                                    width: 200,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return SizedBox(
                                        height: 200,
                                        width: 200,
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
                                      data: dynamicUpiString,
                                      version: QrVersions.auto,
                                      size: 190.0,
                                      gapless: false,
                                      foregroundColor: const Color(0xFF1E2229),
                                    ),
                                  )
                                : Image.file(
                                    File(activeQrPath!),
                                    height: 200,
                                    width: 200,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => QrImageView(
                                      data: dynamicUpiString,
                                      version: QrVersions.auto,
                                      size: 190.0,
                                      gapless: false,
                                      foregroundColor: const Color(0xFF1E2229),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Custom uploaded QR image active',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        // Quick switch back to dynamic standard QR
                        OutlinedButton.icon(
                          onPressed: () => _confirmRemoveCustomQr(context, details),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 16),
                          label: Text(
                            'Switch to Dynamic UPI QR',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
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
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: dynamicUpiString,
                            version: QrVersions.auto,
                            size: 200.0,
                            gapless: false,
                            foregroundColor: const Color(0xFF1E2229),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '⚡ Standard Auto-Generated Dynamic QR',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Supports BHIM, GPay, PhonePe, Paytm, and all banking apps.',
                        style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // Action Row in View Mode (Edit Setup + Delete Setup)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                  _upiController.text = details.upiId;
                                  _cachedQrPath = details.qrCodeUrl;
                                  _showPreview = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF2C3242) : const Color(0xFFF1F5F9),
                                foregroundColor: isDark ? Colors.white : Colors.black87,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(
                                'Edit UPI / QR',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmDeleteEntireProfile(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red[400],
                                side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.delete_forever_rounded, size: 16),
                              label: Text(
                                'Delete Setup',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 4. Help Info Card
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
