import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../models/payment_detail.dart';
import '../services/database_helper.dart';
import '../services/expense_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_toast.dart';
import 'business_catalog_screen.dart';
import '../utils/app_strings.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.tr(context, 'biz_settings_title'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E3A8A).withValues(alpha: 0.4), const Color(0xFF172554).withValues(alpha: 0.3)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF3B82F6), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tr(context, 'biz_profile_title'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppStrings.tr(context, 'biz_profile_sub'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // SECTION 1: PROFILE DETAILS
            _buildSectionLabel('SHOP & INVOICE PROFILE', isDark),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.25),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: BusinessProfileSettingsCard(isDark: isDark),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // SECTION 2: SALES ITEMS & CATALOG
            _buildSectionLabel('PRODUCTS & INVENTORY', isDark),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: const Color(0xFF10B981).withValues(alpha: 0.25),
              children: [
                Consumer<ExpenseProvider>(
                  builder: (context, expProv, _) {
                    final itemCount = expProv.businessItems.length;
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BusinessCatalogScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Sales Items & Catalog',
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$itemCount items',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Add / Edit products, buy price & GST for fast billing',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF10B981),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class BusinessProfileSettingsCard extends StatefulWidget {
  final bool isDark;
  const BusinessProfileSettingsCard({super.key, required this.isDark});

  @override
  State<BusinessProfileSettingsCard> createState() => _BusinessProfileSettingsCardState();
}

class _BusinessProfileSettingsCardState extends State<BusinessProfileSettingsCard> {
  BusinessProfile _profile = BusinessProfile(
    id: 'default_business',
    businessName: 'My Business',
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prof = await DatabaseHelper.instance.getBusinessProfile();
      if (mounted) {
        setState(() {
          _profile = prof;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditDialog() async {
    final nameCtrl = TextEditingController(text: _profile.businessName);
    final phoneCtrl = TextEditingController(text: _profile.phone ?? '');
    final gstinCtrl = TextEditingController(text: _profile.gstin ?? '');
    final addrCtrl = TextEditingController(text: _profile.address ?? '');
    final upiCtrl = TextEditingController(text: _profile.upiId ?? '');

    List<PaymentDetail> savedPayments = Provider.of<ExpenseProvider>(context, listen: false).paymentDetails;
    if (savedPayments.isEmpty) {
      savedPayments = await DatabaseHelper.instance.getPaymentDetails();
    }
    final validPayments = savedPayments.where((p) => p.upiId.trim().isNotEmpty).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E232D) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Edit Business Profile',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'My Business / Shop Name *',
                      hintText: 'e.g. Ramesh General Store',
                      prefixIcon: Icon(Icons.business_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Business Phone Number',
                      hintText: 'e.g. +91 9876543210',
                      prefixIcon: Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gstinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN (Optional)',
                      hintText: 'e.g. 27AAAAA0000A1Z5',
                      prefixIcon: Icon(Icons.receipt_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Office Address',
                      hintText: 'e.g. Shop 12, Main Market, Mumbai',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: upiCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Business UPI ID (for QR Code)',
                      hintText: 'e.g. storename@okaxis',
                      prefixIcon: const Icon(Icons.qr_code_rounded),
                      suffixIcon: upiCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                upiCtrl.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  if (validPayments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Text(
                          'Select from saved app UPI IDs:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: validPayments.map((p) {
                        final isSelected = upiCtrl.text.trim().toLowerCase() == p.upiId.trim().toLowerCase();
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              upiCtrl.text = p.upiId.trim();
                              setDialogState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF3B82F6)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.account_balance_wallet_outlined,
                                    size: 13,
                                    color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.name.isNotEmpty ? p.name : 'UPI',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${p.upiId})',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: isSelected
                                          ? const Color(0xFF3B82F6).withValues(alpha: 0.85)
                                          : (isDark ? Colors.white38 : Colors.black45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newName = nameCtrl.text.trim().isEmpty ? 'My Business' : nameCtrl.text.trim();
                  final updated = BusinessProfile(
                    id: _profile.id,
                    businessName: newName,
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                    gstin: gstinCtrl.text.trim().isNotEmpty ? gstinCtrl.text.trim() : null,
                    address: addrCtrl.text.trim().isNotEmpty ? addrCtrl.text.trim() : null,
                    upiId: upiCtrl.text.trim().isNotEmpty ? upiCtrl.text.trim() : null,
                    updatedAt: DateTime.now(),
                  );

                  await DatabaseHelper.instance.saveBusinessProfile(updated);

                  try {
                    await SupabaseService.instance.upsertBusinessProfile(updated.toMap());
                  } catch (e) {
                    debugPrint('[BusinessProfile] Cloud sync failed: $e');
                  }

                  if (mounted) {
                    setState(() => _profile = updated);
                    Navigator.of(ctx).pop();
                    CustomToast.show(context, '✅ Business Profile saved: $newName');
                  }
                },
                child: Text('Save Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131720) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 6),
                  Text(
                    'BUSINESS / SHOP PROFILE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showEditDialog,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 13, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _profile.businessName.isNotEmpty ? _profile.businessName : 'My Business',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (_profile.phone != null && _profile.phone!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_rounded, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  _profile.phone!,
                  style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ],
            ),
          ],
          if (_profile.gstin != null && _profile.gstin!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.receipt_rounded, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'GSTIN: ${_profile.gstin!}',
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ],
          if (_profile.address != null && _profile.address!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _profile.address!,
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_profile.upiId != null && _profile.upiId!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.qr_code_rounded, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'UPI QR: ${_profile.upiId!}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
