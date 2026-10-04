import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/business_item.dart';
import '../services/expense_provider.dart';
import '../widgets/custom_toast.dart';
import '../widgets/barcode_scanner_modal.dart';

class BusinessCatalogScreen extends StatefulWidget {
  final bool initialFilterLowStock;

  const BusinessCatalogScreen({
    super.key,
    this.initialFilterLowStock = false,
  });

  @override
  State<BusinessCatalogScreen> createState() => _BusinessCatalogScreenState();
}

class _BusinessCatalogScreenState extends State<BusinessCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _filterOnlyLowStock = false;

  static const Color _businessBlue = Color(0xFF1E88E5);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkCard = Color(0xFF1E293B);

  static const List<String> _unitOptions = [
    'pcs',
    'kg',
    'g',
    'ltr',
    'ml',
    'box',
    'pkt',
    'm',
    'nos',
    'doz',
    'pair',
    'set',
    'quintal',
    'sq.ft',
    'service',
    'hour',
  ];

  static const List<double> _taxSlabs = [0.0, 5.0, 12.0, 18.0, 28.0];

  static const Map<String, List<Map<String, String>>> _unitCategories = {
    'Count & Pieces': [
      {'key': 'pcs', 'label': 'Pieces (pcs)', 'sub': 'Standard individual item count'},
      {'key': 'box', 'label': 'Box (box)', 'sub': 'Carton, pack or grouped box'},
      {'key': 'pkt', 'label': 'Packet (pkt)', 'sub': 'Pouches or sealed packets'},
      {'key': 'nos', 'label': 'Numbers (nos)', 'sub': 'Discrete quantified count'},
      {'key': 'doz', 'label': 'Dozen (doz)', 'sub': 'Set of 12 items'},
      {'key': 'pair', 'label': 'Pair (pair)', 'sub': 'Set of 2 matched items'},
      {'key': 'set', 'label': 'Set (set)', 'sub': 'Multi-piece bundled set'},
    ],
    'Weight & Mass': [
      {'key': 'kg', 'label': 'Kilogram (kg)', 'sub': 'Standard bulk metric weight'},
      {'key': 'g', 'label': 'Gram (g)', 'sub': 'Lightweight or spices / gold'},
      {'key': 'quintal', 'label': 'Quintal', 'sub': '100 kg agricultural wholesale'},
    ],
    'Liquid & Volume': [
      {'key': 'ltr', 'label': 'Litre (ltr)', 'sub': 'Standard liquids, oils, milk'},
      {'key': 'ml', 'label': 'Millilitre (ml)', 'sub': 'Small volume beverages & bottles'},
    ],
    'Length & Area': [
      {'key': 'm', 'label': 'Metre (m)', 'sub': 'Fabrics, cables, wires, pipes'},
      {'key': 'sq.ft', 'label': 'Square Feet (sq.ft)', 'sub': 'Flooring, tiles, real estate'},
    ],
    'Time & Service': [
      {'key': 'service', 'label': 'Service', 'sub': 'Labor, repair, consultancy job'},
      {'key': 'hour', 'label': 'Hour (hr)', 'sub': 'Hourly billable work or rental'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _filterOnlyLowStock = widget.initialFilterLowStock;
  }

  void _openUnitPickerSheet(BuildContext context, String currentUnit, ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E2430) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF212121);
        const primaryColor = Color(0xFF1E88E5);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.straighten_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Unit of Measurement',
                            style: GoogleFonts.outfit(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Tap to apply unit for this catalog item',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.8),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: _unitCategories.entries.map((entry) {
                    final categoryName = entry.key;
                    final units = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, top: 10, bottom: 6),
                          child: Text(
                            categoryName.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        ...units.map((u) {
                          final isSelected = currentUnit.toLowerCase() == u['key']!.toLowerCase();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.12)
                                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryColor : (isDark ? Colors.white12 : Colors.black12),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              leading: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? primaryColor : (isDark ? Colors.white10 : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  u['key']!.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ),
                              title: Text(
                                u['label']!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? primaryColor : textColor,
                                ),
                              ),
                              subtitle: Text(
                                u['sub']!,
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
                                  : null,
                              onTap: () {
                                onSelected(u['key']!);
                                Navigator.pop(sheetCtx);
                              },
                            ),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTaxPickerSheet(BuildContext context, double currentTax, ValueChanged<double> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E2430) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF212121);
        const primaryColor = Color(0xFF1E88E5);

        final slabDescriptions = {
          0.0: '0% (Exempt / No Tax) - Fresh produce, books, unbranded food',
          5.0: '5% GST - Essential groceries, apparel <= ₹1k, medicines',
          12.0: '12% GST - Processed foods, business services, mobile phones',
          18.0: '18% GST (Standard) - IT services, consumer goods, general services',
          28.0: '28% GST - Luxury items, automobiles, high-end electronics',
        };

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select GST Tax Slab',
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(height: 16),
              ..._taxSlabs.map((tax) {
                final isSelected = (currentTax - tax).abs() < 0.01;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.12)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryColor : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    onTap: () {
                      onSelected(tax);
                      Navigator.pop(sheetCtx);
                    },
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : (isDark ? Colors.white10 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tax == 0.0 ? '0%' : '${tax.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    title: Text(
                      tax == 0.0 ? '0% Exempt (No Tax)' : '${tax.toStringAsFixed(0)}% GST Slab',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? primaryColor : textColor,
                      ),
                    ),
                    subtitle: Text(
                      slabDescriptions[tax] ?? '',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: primaryColor)
                        : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 20),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expProvider = Provider.of<ExpenseProvider>(context);
    final allItems = expProvider.businessItems;
    final lowStockCount = expProvider.lowStockBusinessItems.length;

    final filteredItems = allItems.where((it) {
      if (_filterOnlyLowStock && !(it.isLowStock || it.isOutOfStock)) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchesName = it.name.toLowerCase().contains(q);
      final matchesCategory = it.category?.toLowerCase().contains(q) ?? false;
      final matchesBarcode = it.barcode?.toLowerCase().contains(q) ?? false;
      return matchesName || matchesCategory || matchesBarcode;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? _darkBg : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? _darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Items & Catalog',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              '${allItems.length} Saved Products / Services',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add New Item',
            icon: const Icon(Icons.add_circle_outline, color: _businessBlue, size: 26),
            onPressed: () => _showItemEditorSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _businessBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          'Add Item / Service',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        onPressed: () => _showItemEditorSheet(context),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? _darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search items, category or barcode...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.white60 : Colors.black45, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          ),

          // Filter Chips (All vs Low Stock)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('All (${allItems.length})'),
                  selected: !_filterOnlyLowStock,
                  onSelected: (val) {
                    if (val) setState(() => _filterOnlyLowStock = false);
                  },
                  selectedColor: _businessBlue.withValues(alpha: 0.18),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: !_filterOnlyLowStock ? FontWeight.bold : FontWeight.normal,
                    color: !_filterOnlyLowStock ? _businessBlue : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('Low Stock ($lowStockCount)'),
                    ],
                  ),
                  selected: _filterOnlyLowStock,
                  onSelected: (val) {
                    setState(() => _filterOnlyLowStock = val);
                  },
                  selectedColor: Colors.orange.withValues(alpha: 0.2),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: _filterOnlyLowStock ? FontWeight.bold : FontWeight.normal,
                    color: _filterOnlyLowStock ? Colors.orange : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          // Catalog List
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState(isDark, allItems.isEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildItemCard(context, item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool noItemsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _businessBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 48, color: _businessBlue),
            ),
            const SizedBox(height: 16),
            Text(
              noItemsAtAll ? 'No Catalog Items Yet' : (_filterOnlyLowStock ? 'No Low Stock Items 🎉' : 'No matching items found'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noItemsAtAll
                  ? 'Add your products, goods, or services here so you can quickly add them to bills without typing prices every time.'
                  : (_filterOnlyLowStock ? 'All your inventory stocks are healthy and above minimum thresholds.' : 'Try searching with a different keyword.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (noItemsAtAll) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _businessBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Create First Item', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                onPressed: () => _showItemEditorSheet(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, BusinessItem item, bool isDark) {
    final hasCost = item.purchasePrice > 0;
    final profit = item.profitMargin;
    final marginPct = item.profitMarginPercent;

    final hasBarcode = item.barcode != null && item.barcode!.trim().isNotEmpty;
    final stockFormatted = item.stockQuantity.toStringAsFixed(item.stockQuantity.truncateToDouble() == item.stockQuantity ? 0 : 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isOutOfStock
              ? Colors.red.withValues(alpha: 0.4)
              : (item.isLowStock
                  ? Colors.orange.withValues(alpha: 0.4)
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06))),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name, Unit badge, GST badge, and Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.isOutOfStock
                      ? Colors.red.withValues(alpha: 0.12)
                      : (item.isLowStock ? Colors.orange.withValues(alpha: 0.12) : _businessBlue.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isOutOfStock ? Icons.error_outline_rounded : (item.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2),
                  color: item.isOutOfStock ? Colors.redAccent : (item.isLowStock ? Colors.orange : _businessBlue),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Unit: ${item.unit.toUpperCase()}',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.taxRate > 0 ? Colors.purple.withValues(alpha: 0.15) : Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.taxRate > 0 ? 'GST ${item.taxRate.toStringAsFixed(0)}%' : 'Exempt (0% GST)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: item.taxRate > 0 ? Colors.purpleAccent : Colors.teal,
                            ),
                          ),
                        ),
                        if (item.category != null && item.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category!,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange),
                            ),
                          ),
                        if (hasBarcode)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_2, size: 11, color: Colors.indigoAccent),
                                const SizedBox(width: 3),
                                Text(
                                  item.barcode!,
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.indigoAccent),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.white60 : Colors.black54, size: 20),
                onSelected: (val) {
                  if (val == 'refill') {
                    _showRefillStockDialog(context, item);
                  } else if (val == 'edit') {
                    _showItemEditorSheet(context, existingItem: item);
                  } else if (val == 'delete') {
                    _confirmDeleteItem(context, item);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'refill',
                    child: Row(
                      children: [
                        Icon(Icons.add_shopping_cart, size: 18, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('Refill / Update Stock'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edit Item'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Delete Item', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Inventory Stock Row
          if (item.trackStock)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: item.isOutOfStock
                    ? Colors.red.withValues(alpha: 0.08)
                    : (item.isLowStock ? Colors.orange.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.isOutOfStock
                      ? Colors.red.withValues(alpha: 0.25)
                      : (item.isLowStock ? Colors.orange.withValues(alpha: 0.25) : Colors.green.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isOutOfStock ? Icons.cancel_outlined : (item.isLowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                    size: 14,
                    color: item.isOutOfStock ? Colors.redAccent : (item.isLowStock ? Colors.orange : Colors.green),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.isOutOfStock
                          ? 'Out of Stock (0 ${item.unit})'
                          : (item.isLowStock
                              ? 'Low Stock Alert: $stockFormatted ${item.unit} left (Limit: ${item.lowStockLimit.toStringAsFixed(0)})'
                              : 'In Stock: $stockFormatted ${item.unit} available'),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: item.isOutOfStock ? Colors.redAccent : (item.isLowStock ? Colors.orange : Colors.green),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showRefillStockDialog(context, item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _businessBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 12, color: _businessBlue),
                          const SizedBox(width: 2),
                          Text(
                            'Refill',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _businessBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Pricing Summary (Selling Price & Buy Price & Profit)
          Row(
            children: [
              // Selling Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELLING PRICE',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${item.sellingPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Buy / Cost Price (Confidential)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'BUY COST',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.lock, size: 10, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCost ? '₹${item.purchasePrice.toStringAsFixed(2)}' : 'Not set',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasCost ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Est. Profit per unit
              if (hasCost)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: profit >= 0 ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        profit >= 0 ? '+₹${profit.toStringAsFixed(2)}' : '-₹${(-profit).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: profit >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        '${marginPct.toStringAsFixed(0)}% margin',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: profit >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRefillStockDialog(BuildContext context, BusinessItem item) {
    final qtyCtrl = TextEditingController();
    bool isAdding = true; // true = Add to existing, false = Set exact stock
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? _darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: _businessBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Refill Stock: ${item.name}',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Stock: ${item.stockQuantity.toStringAsFixed(item.stockQuantity.truncateToDouble() == item.stockQuantity ? 0 : 2)} ${item.unit}',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('+ Add Quantity'),
                      selected: isAdding,
                      onSelected: (val) {
                        if (val) setDialogState(() => isAdding = true);
                      },
                      selectedColor: _businessBlue.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Set Total Count'),
                      selected: !isAdding,
                      onSelected: (val) {
                        if (val) setDialogState(() => isAdding = false);
                      },
                      selectedColor: _businessBlue.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isAdding ? 'Quantity to add (${item.unit})' : 'New total stock (${item.unit})',
                    hintText: isAdding ? 'e.g. 50' : 'e.g. 100',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _businessBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final entered = double.tryParse(qtyCtrl.text.trim());
                  if (entered == null || entered <= 0) {
                    CustomToast.show(context, 'Please enter a valid quantity', isError: true);
                    return;
                  }
                  final newStock = isAdding ? (item.stockQuantity + entered) : entered;
                  await Provider.of<ExpenseProvider>(context, listen: false).updateBusinessItemStock(item.id, newStock);
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    CustomToast.show(context, '📦 Stock updated: $newStock ${item.unit}');
                  }
                },
                child: const Text('Update Stock'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, BusinessItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Item?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${item.name}" from your catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Provider.of<ExpenseProvider>(context, listen: false).deleteBusinessItem(item.id);
              if (mounted) {
                CustomToast.show(context, '🗑️ Item "${item.name}" deleted');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showItemEditorSheet(BuildContext context, {BusinessItem? existingItem}) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final sellPriceCtrl = TextEditingController(
      text: (existingItem?.sellingPrice ?? 0.0) > 0 ? existingItem!.sellingPrice.toStringAsFixed(2) : '',
    );
    final buyPriceCtrl = TextEditingController(
      text: (existingItem?.purchasePrice ?? 0.0) > 0 ? existingItem!.purchasePrice.toStringAsFixed(2) : '',
    );
    final categoryCtrl = TextEditingController(text: existingItem?.category ?? '');
    final barcodeCtrl = TextEditingController(text: existingItem?.barcode ?? '');
    final stockQtyCtrl = TextEditingController(
      text: (existingItem?.stockQuantity ?? 0.0) > 0
          ? existingItem!.stockQuantity.toStringAsFixed(existingItem.stockQuantity.truncateToDouble() == existingItem.stockQuantity ? 0 : 2)
          : '0',
    );
    final lowStockLimitCtrl = TextEditingController(
      text: (existingItem?.lowStockLimit ?? 5.0).toStringAsFixed(0),
    );
    bool trackStock = existingItem?.trackStock ?? true;

    String selectedUnit = existingItem?.unit.toLowerCase() ?? 'pcs';
    if (!_unitOptions.contains(selectedUnit)) {
      selectedUnit = 'pcs';
    }
    double selectedTax = existingItem?.taxRate ?? 0.0;
    if (!_taxSlabs.contains(selectedTax)) {
      selectedTax = 0.0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? _darkCard : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _businessBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note : Icons.add_box_outlined,
                              color: _businessBlue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'Edit Catalog Item' : 'Add Item / Service',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 1. Item Name
                      Text(
                        'Item / Service Name *',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'e.g., Engine Oil 1L, Haircut, Sugar 1kg...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Barcode Scan / Enter Field
                      Text(
                        'Product Barcode (Optional for Fast Billing)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigoAccent),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: barcodeCtrl,
                        style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Scan packet barcode or enter code...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                          prefixIcon: const Icon(Icons.qr_code, size: 20, color: Colors.indigoAccent),
                          suffixIcon: IconButton(
                            tooltip: 'Open Camera Barcode Scanner',
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.indigoAccent),
                            onPressed: () async {
                              final scanned = await BarcodeScannerModal.scan(
                                context,
                                title: 'Scan Barcode for ${nameCtrl.text.isNotEmpty ? nameCtrl.text : "Item"}',
                              );
                              if (scanned != null && scanned.isNotEmpty) {
                                setModalState(() {
                                  barcodeCtrl.text = scanned;
                                });
                                if (context.mounted) {
                                  CustomToast.show(context, '📷 Barcode scanned: $scanned');
                                }
                              }
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Unit and GST Slab in 2 columns
                      Row(
                        children: [
                          // Unit
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unit',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    _openUnitPickerSheet(context, selectedUnit, (val) {
                                      setModalState(() => selectedUnit = val);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                                      border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          selectedUnit.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // GST %
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GST Slab %',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    _openTaxPickerSheet(context, selectedTax, (val) {
                                      setModalState(() => selectedTax = val);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                                      border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          selectedTax == 0.0 ? '0% (Exempt)' : '${selectedTax.toStringAsFixed(0)}% GST',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. Selling Price & Buy Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selling Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selling Price (₹/$selectedUnit) *',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: sellPriceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Buy / Cost Price (Confidential)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Buy Cost (₹/$selectedUnit)',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.lock, size: 12, color: Colors.amber),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: buyPriceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: 'Optional',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Live Profit Calculation Preview inside Catalog Editor
                      Builder(builder: (ctx) {
                        final sp = double.tryParse(sellPriceCtrl.text.trim()) ?? 0.0;
                        final bp = double.tryParse(buyPriceCtrl.text.trim()) ?? 0.0;
                        if (sp <= 0 && bp <= 0) return const SizedBox.shrink();
                        if (bp <= 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '💡 Standard Selling Rate: ₹${sp.toStringAsFixed(2)} per $selectedUnit',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            ),
                          );
                        }
                        final diff = sp - bp;
                        final isProfit = diff >= 0;
                        final marginPercent = bp > 0 ? (diff / bp) * 100 : 0.0;
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isProfit ? Colors.green : Colors.redAccent).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: (isProfit ? Colors.green : Colors.redAccent).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(isProfit ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                  size: 14, color: isProfit ? Colors.green : Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isProfit
                                      ? 'Profit Margin: +₹${diff.toStringAsFixed(2)} / $selectedUnit (${marginPercent.toStringAsFixed(0)}% margin)'
                                      : '⚠️ Buy Cost > Selling Price! Loss: -₹${(-diff).toStringAsFixed(2)} / $selectedUnit',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isProfit ? Colors.green : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 14),

                      // 4. Inventory & Stock Tracking Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 18, color: _businessBlue),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Track Inventory Stock',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Switch.adaptive(
                                  value: trackStock,
                                  activeColor: _businessBlue,
                                  onChanged: (val) {
                                    setModalState(() => trackStock = val);
                                  },
                                ),
                              ],
                            ),
                            if (trackStock) ...[
                              const Divider(height: 16),
                              Row(
                                children: [
                                  // Initial Stock Quantity
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Available Stock ($selectedUnit)',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: stockQtyCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                                          decoration: InputDecoration(
                                            hintText: '0',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Low Stock Limit Threshold
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Low Stock Alert Limit',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.orange),
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: lowStockLimitCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: GoogleFonts.inter(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                                          decoration: InputDecoration(
                                            hintText: '5',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. Category / Group
                      Text(
                        'Category / Group (Optional)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: categoryCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'e.g., Grocery, Hardware, Service, Auto Parts...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _businessBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              CustomToast.show(context, 'Please enter item name', isError: true);
                              return;
                            }
                            final sellPrice = double.tryParse(sellPriceCtrl.text.trim()) ?? 0.0;
                            final buyPrice = double.tryParse(buyPriceCtrl.text.trim()) ?? 0.0;
                            final category = categoryCtrl.text.trim();
                            final barcode = barcodeCtrl.text.trim();
                            final stockQty = double.tryParse(stockQtyCtrl.text.trim()) ?? 0.0;
                            final lowStockLimit = double.tryParse(lowStockLimitCtrl.text.trim()) ?? 5.0;

                            final provider = Provider.of<ExpenseProvider>(context, listen: false);

                            if (isEditing) {
                              final updated = existingItem.copyWith(
                                name: name,
                                sellingPrice: sellPrice,
                                purchasePrice: buyPrice,
                                unit: selectedUnit,
                                taxRate: selectedTax,
                                category: category.isNotEmpty ? category : null,
                                barcode: barcode.isNotEmpty ? barcode : null,
                                stockQuantity: stockQty,
                                lowStockLimit: lowStockLimit,
                                trackStock: trackStock,
                                updatedAt: DateTime.now(),
                              );
                              await provider.updateBusinessItem(updated);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                CustomToast.show(context, '✅ Item "$name" updated!');
                              }
                            } else {
                              final newItem = BusinessItem(
                                id: provider.cryptoUuid(),
                                name: name,
                                sellingPrice: sellPrice,
                                purchasePrice: buyPrice,
                                unit: selectedUnit,
                                taxRate: selectedTax,
                                category: category.isNotEmpty ? category : null,
                                barcode: barcode.isNotEmpty ? barcode : null,
                                stockQuantity: stockQty,
                                lowStockLimit: lowStockLimit,
                                trackStock: trackStock,
                              );
                              await provider.addBusinessItem(newItem);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                CustomToast.show(context, '✅ Item "$name" added to catalog!');
                              }
                            }
                          },
                          child: Text(
                            isEditing ? 'Save Changes' : 'Add to Catalog',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
