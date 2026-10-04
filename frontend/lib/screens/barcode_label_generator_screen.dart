import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/business_item.dart';
import '../models/barcode_label_batch.dart';
import '../models/business_profile.dart';
import '../services/database_helper.dart';
import '../services/expense_provider.dart';
import '../services/barcode_label_service.dart';
import '../widgets/custom_toast.dart';
import 'scan_receipt_screen.dart';

class BarcodeLabelGeneratorScreen extends StatefulWidget {
  final BusinessItem? initialItem;

  const BarcodeLabelGeneratorScreen({
    super.key,
    this.initialItem,
  });

  @override
  State<BarcodeLabelGeneratorScreen> createState() => _BarcodeLabelGeneratorScreenState();
}

class _BarcodeLabelGeneratorScreenState extends State<BarcodeLabelGeneratorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '24');
  final _shopNameController = TextEditingController();

  // Catalog Add-on fields
  bool _saveToCatalog = false;
  final _costPriceController = TextEditingController(text: '0');
  final _stockQuantityController = TextEditingController(text: '24');
  String _selectedCategory = 'General';

  String _barcodeType = 'barcode'; // 'barcode' or 'qr'
  int _columnsCount = 3; // 3 or 4
  bool _showShopName = true;
  bool _showPrice = true;
  bool _showBarcodeText = true;
  bool _showCutBorders = true;

  String? _selectedItemId;
  List<BarcodeLabelBatch> _savedBatches = [];
  bool _isLoadingBatches = true;
  bool _isGenerating = false;

  final List<int> _presetQuantities = [12, 24, 36, 48, 60, 96];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productNameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _shopNameController.dispose();
    _costPriceController.dispose();
    _stockQuantityController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // Load shop profile for default shop name
    final profile = await DatabaseHelper.instance.getBusinessProfile();
    if (profile != null && profile.businessName.isNotEmpty) {
      _shopNameController.text = profile.businessName;
    }

    // Populate initial item if passed
    if (widget.initialItem != null) {
      _fillFromItem(widget.initialItem!);
    }

    _loadHistoryBatches();
  }

  void _fillFromItem(BusinessItem item) {
    setState(() {
      _selectedItemId = item.id;
      _productNameController.text = item.name;
      _barcodeController.text = item.barcode ?? '';
      _priceController.text = item.sellingPrice > 0 ? item.sellingPrice.toStringAsFixed(0) : '';
      _saveToCatalog = false;
    });
  }

  Future<void> _loadHistoryBatches() async {
    setState(() => _isLoadingBatches = true);
    try {
      final batches = await DatabaseHelper.instance.getBarcodeLabelBatches();
      if (mounted) {
        setState(() {
          _savedBatches = batches;
          _isLoadingBatches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBatches = false);
    }
  }

  void _generateUniqueBarcode() {
    HapticFeedback.lightImpact();
    // Standard Indian prefix format (890 + 9 random digits)
    final random = Random();
    final randomDigits = List.generate(9, (_) => random.nextInt(10)).join();
    final code = '890$randomDigits';
    setState(() {
      _barcodeController.text = code;
    });
    CustomToast.show(context, '✨ Unique Barcode generated: $code');
  }

  Future<void> _scanBarcodeFromCamera() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScanReceiptScreen(isBarcodeMode: true),
      ),
    );

    if (scannedCode != null && scannedCode.trim().isNotEmpty) {
      setState(() {
        _barcodeController.text = scannedCode.trim();
      });
      CustomToast.show(context, 'Barcode scanned: $scannedCode');
    }
  }

  void _showCatalogPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final items = expenseProvider.businessItems;

    if (items.isEmpty) {
      CustomToast.show(context, 'No items in catalog yet. You can create one below!');
      return;
    }

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2433) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final filtered = items.where((it) {
              final q = searchQuery.toLowerCase();
              return it.name.toLowerCase().contains(q) ||
                  (it.barcode ?? '').toLowerCase().contains(q) ||
                  (it.category ?? '').toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Product from Catalog',
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by item name, barcode, category...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching products found',
                                  style: GoogleFonts.inter(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final it = filtered[idx];
                                  final hasBarcode = it.barcode != null && it.barcode!.isNotEmpty;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF1E88E5), size: 22),
                                    ),
                                    title: Text(
                                      it.name,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Text('₹${it.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00D09C))),
                                        const SizedBox(width: 8),
                                        if (hasBarcode)
                                          Text('• 📊 ${it.barcode}', style: const TextStyle(fontSize: 11, color: Colors.grey))
                                        else
                                          const Text('• ⚠️ No Barcode', style: TextStyle(fontSize: 11, color: Colors.amber)),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _fillFromItem(it);
                                      if (!hasBarcode) {
                                        _generateUniqueBarcode();
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleGenerateAndExport({bool previewOnly = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final productName = _productNameController.text.trim();
    final barcodeData = _barcodeController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 24;
    final shopName = _shopNameController.text.trim();

    if (barcodeData.isEmpty) {
      CustomToast.show(context, 'Please enter or generate a barcode number', isError: true);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 1. If user checked "Save to Catalog" and this item doesn't exist yet
      if (_saveToCatalog && _selectedItemId == null) {
        final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
        final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
        final stock = double.tryParse(_stockQuantityController.text.trim()) ?? quantity.toDouble();

        final newItem = BusinessItem(
          id: 'item_${DateTime.now().millisecondsSinceEpoch}',
          name: productName,
          purchasePrice: costPrice,
          sellingPrice: price,
          taxRate: 0.0,
          unit: 'pcs',
          category: _selectedCategory,
          barcode: barcodeData,
          stockQuantity: stock,
          trackStock: true,
        );

        await expenseProvider.addBusinessItem(newItem);
        _selectedItemId = newItem.id;
        CustomToast.show(context, '📦 "$productName" added to Catalog with barcode!');
      }

      // 2. Generate PDF bytes
      final pdfBytes = await BarcodeLabelService.instance.generateLabelsPdf(
        productName: productName,
        barcodeData: barcodeData,
        barcodeType: _barcodeType,
        price: price,
        quantity: quantity,
        columnsCount: _columnsCount,
        shopName: shopName,
        showShopName: _showShopName,
        showPrice: _showPrice,
        showBarcodeText: _showBarcodeText,
        showCutBorders: _showCutBorders,
      );

      final file = await BarcodeLabelService.instance.savePdfToFile(
        bytes: pdfBytes,
        fileName: 'Stickers_${productName}_$barcodeData',
      );

      // 3. Save to History Batches
      final batch = BarcodeLabelBatch(
        id: 'batch_${DateTime.now().millisecondsSinceEpoch}',
        itemId: _selectedItemId,
        productName: productName,
        barcodeData: barcodeData,
        barcodeType: _barcodeType,
        price: price,
        quantity: quantity,
        columnsCount: _columnsCount,
        shopName: shopName,
      );

      await DatabaseHelper.instance.insertBarcodeLabelBatch(batch);
      _loadHistoryBatches();

      if (mounted) {
        setState(() => _isGenerating = false);
        if (previewOnly) {
          await BarcodeLabelService.instance.openPdf(file);
        } else {
          _showPdfSuccessSheet(file, productName, quantity);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        CustomToast.show(context, 'Error generating stickers: $e', isError: true);
      }
    }
  }

  void _showPdfSuccessSheet(File file, String productName, int quantity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2433) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D09C).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00D09C), size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sticker Sheet Ready! 🎉',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity sticker labels generated for "$productName" in printable A4 format.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          BarcodeLabelService.instance.sharePdf(file, subject: '$productName Barcode Labels');
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text('Share PDF', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D09C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          BarcodeLabelService.instance.openPdf(file);
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text('Print / Open', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF00D09C);
    final cardBg = isDark ? const Color(0xFF181B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Barcode & QR Label Maker',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(icon: Icon(Icons.qr_code_2_rounded, size: 20), text: 'Create Labels'),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: 'History (${_savedBatches.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: GENERATE LABELS FORM
          _buildGeneratorTab(isDark, primaryColor, cardBg, borderColor),

          // TAB 2: SAVED BATCHES HISTORY
          _buildHistoryTab(isDark, primaryColor, cardBg, borderColor),
        ],
      ),
    );
  }

  Widget _buildGeneratorTab(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          // ── QUICK PICK BANNER ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF1E88E5), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick existing product from Catalog',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Auto-fills product name, price and barcode',
                        style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showCatalogPicker,
                  child: Text('Catalog', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 1. PRODUCT DETAILS CARD ───────────────────────────────
          _buildSectionCard(
            title: 'Product Information',
            icon: Icons.sell_outlined,
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              TextFormField(
                controller: _productNameController,
                decoration: InputDecoration(
                  labelText: 'Product / Item Name *',
                  hintText: 'e.g. Basmati Rice 1kg, Cotton Shirt',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Item name required' : null,
              ),
              const SizedBox(height: 14),

              // Barcode Input + Suffix Actions (Auto-Gen & Scan)
              TextFormField(
                controller: _barcodeController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Barcode / SKU Number *',
                  hintText: 'Enter code or click Auto-Gen',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Scan Barcode with Camera',
                        icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF10B981)),
                        onPressed: _scanBarcodeFromCamera,
                      ),
                      TextButton.icon(
                        onPressed: _generateUniqueBarcode,
                        icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF00D09C)),
                        label: Text('Auto-Gen', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00D09C))),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Barcode number required' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Selling Price (MRP ₹)',
                        hintText: 'e.g. 199',
                        prefixText: '₹ ',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _shopNameController,
                      decoration: InputDecoration(
                        labelText: 'Shop Name (Tag Header)',
                        hintText: 'My Store',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),

              // ── SAVE TO CATALOG CHECKBOX ──────────────────────────
              if (_selectedItemId == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _saveToCatalog
                        ? const Color(0xFF00D09C).withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF131722) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _saveToCatalog ? const Color(0xFF00D09C).withValues(alpha: 0.3) : borderColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Save this as new item in Product Catalog',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          'Enables instant camera billing for this barcode later',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                        activeColor: const Color(0xFF00D09C),
                        value: _saveToCatalog,
                        onChanged: (val) => setState(() => _saveToCatalog = val),
                      ),
                      if (_saveToCatalog) ...[
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _costPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Cost Price (₹)',
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _stockQuantityController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Initial Stock (pcs)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. STICKER LAYOUT & QUANTITY CARD ─────────────────────
          _buildSectionCard(
            title: 'Sticker Sheet & Layout Settings',
            icon: Icons.grid_on_rounded,
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              // Code Type: Barcode vs QR Code
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _barcodeType = 'barcode'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _barcodeType == 'barcode'
                              ? const Color(0xFF00D09C).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _barcodeType == 'barcode' ? const Color(0xFF00D09C) : borderColor,
                            width: _barcodeType == 'barcode' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.barcode_reader, size: 20, color: _barcodeType == 'barcode' ? const Color(0xFF00D09C) : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Barcode 📊', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _barcodeType = 'qr'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _barcodeType == 'qr'
                              ? const Color(0xFF00D09C).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _barcodeType == 'qr' ? const Color(0xFF00D09C) : borderColor,
                            width: _barcodeType == 'qr' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded, size: 20, color: _barcodeType == 'qr' ? const Color(0xFF00D09C) : Colors.grey),
                            const SizedBox(width: 8),
                            Text('QR Code 📱', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Columns Selector (3 Columns vs 4 Columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _columnsCount = 3),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _columnsCount == 3
                              ? const Color(0xFF1E88E5).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _columnsCount == 3 ? const Color(0xFF1E88E5) : borderColor,
                            width: _columnsCount == 3 ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('3 Columns', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (_columnsCount == 3)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF1E88E5), size: 16),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('65 x 35 mm • Standard (24/page)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _columnsCount = 4),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _columnsCount == 4
                              ? const Color(0xFF1E88E5).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _columnsCount == 4 ? const Color(0xFF1E88E5) : borderColor,
                            width: _columnsCount == 4 ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('4 Columns', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (_columnsCount == 4)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF1E88E5), size: 16),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('48 x 25 mm • Compact (40/page)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantity Selector
              Text('Total Number of Labels / Stickers:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._presetQuantities.map((q) {
                    final isSelected = _quantityController.text == q.toString();
                    return ChoiceChip(
                      label: Text('$q Labels'),
                      selected: isSelected,
                      selectedColor: const Color(0xFF00D09C).withValues(alpha: 0.2),
                      side: BorderSide(color: isSelected ? const Color(0xFF00D09C) : borderColor),
                      onSelected: (_) {
                        setState(() => _quantityController.text = q.toString());
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Custom Label Quantity',
                  hintText: 'e.g. 50, 100',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n <= 0) return 'Enter valid quantity';
                  if (n > 500) return 'Max 500 labels per batch';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Element Toggles
              const Divider(height: 1),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Show Shop Name on label', style: TextStyle(fontSize: 13)),
                value: _showShopName,
                activeColor: const Color(0xFF00D09C),
                onChanged: (val) => setState(() => _showShopName = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Show Selling Price (MRP: ₹XXX)', style: TextStyle(fontSize: 13)),
                value: _showPrice,
                activeColor: const Color(0xFF00D09C),
                onChanged: (val) => setState(() => _showPrice = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Show Barcode Number digits under code', style: TextStyle(fontSize: 13)),
                value: _showBarcodeText,
                activeColor: const Color(0xFF00D09C),
                onChanged: (val) => setState(() => _showBarcodeText = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Show Dashed Scissors Cutting Borders', style: TextStyle(fontSize: 13)),
                value: _showCutBorders,
                activeColor: const Color(0xFF00D09C),
                onChanged: (val) => setState(() => _showCutBorders = val),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 3. ACTION BUTTONS ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isGenerating ? null : () => _handleGenerateAndExport(previewOnly: true),
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  label: Text('Preview PDF', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D09C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _isGenerating ? null : () => _handleGenerateAndExport(previewOnly: false),
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.print_rounded, size: 20),
                  label: Text(
                    _isGenerating ? 'Generating...' : 'Print / Export A4 PDF',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark, Color primaryColor, Color cardBg, Color borderColor) {
    if (_isLoadingBatches) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00D09C)));
    }

    if (_savedBatches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D09C).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00D09C), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'No Sticker Batches Yet',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Generate your first barcode or QR sticker sheet to see it saved here for quick re-printing anytime!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D09C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create New Batch'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _savedBatches.length,
      itemBuilder: (context, idx) {
        final batch = _savedBatches[idx];
        final isQr = batch.barcodeType == 'qr';
        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(batch.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isQr
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                          : const Color(0xFF00D09C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isQr ? Icons.qr_code_2_rounded : Icons.barcode_reader,
                      color: isQr ? const Color(0xFF8B5CF6) : const Color(0xFF00D09C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.productName,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Code: ${batch.barcodeData}',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: batch.barcodeData));
                                CustomToast.show(context, 'Barcode copied to clipboard!');
                              },
                              child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF00D09C)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () async {
                      await DatabaseHelper.instance.deleteBarcodeLabelBatch(batch.id);
                      _loadHistoryBatches();
                      CustomToast.show(context, 'Batch deleted from history');
                    },
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildMiniBadge('${batch.quantity} Stickers', const Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      _buildMiniBadge('${batch.columnsCount} Columns', const Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      if (batch.price > 0)
                        _buildMiniBadge('₹${batch.price.toStringAsFixed(0)}', const Color(0xFF00D09C)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D09C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      CustomToast.show(context, 'Generating printable PDF...');
                      final pdfBytes = await BarcodeLabelService.instance.generateLabelsPdf(
                        productName: batch.productName,
                        barcodeData: batch.barcodeData,
                        barcodeType: batch.barcodeType,
                        price: batch.price,
                        quantity: batch.quantity,
                        columnsCount: batch.columnsCount,
                        shopName: batch.shopName,
                      );
                      final file = await BarcodeLabelService.instance.savePdfToFile(
                        bytes: pdfBytes,
                        fileName: 'Stickers_${batch.productName}_${batch.barcodeData}',
                      );
                      await BarcodeLabelService.instance.openPdf(file);
                    },
                    icon: const Icon(Icons.print_rounded, size: 15),
                    label: Text('Re-Print', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Created on $dateStr',
                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF00D09C)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
