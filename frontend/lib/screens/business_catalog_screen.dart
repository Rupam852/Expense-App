import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/business_item.dart';
import '../services/expense_provider.dart';
import '../widgets/custom_toast.dart';

class BusinessCatalogScreen extends StatefulWidget {
  const BusinessCatalogScreen({super.key});

  @override
  State<BusinessCatalogScreen> createState() => _BusinessCatalogScreenState();
}

class _BusinessCatalogScreenState extends State<BusinessCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

    final filteredItems = allItems.where((it) {
      if (_searchQuery.isEmpty) return true;
      return it.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (it.category?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  hintText: 'Search items by name or category...',
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
              noItemsAtAll ? 'No Catalog Items Yet' : 'No matching items found',
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
                  : 'Try searching with a different keyword.',
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
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
                  color: _businessBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2, color: _businessBlue, size: 20),
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
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.white60 : Colors.black54, size: 20),
                onSelected: (val) {
                  if (val == 'edit') {
                    _showItemEditorSheet(context, existingItem: item);
                  } else if (val == 'delete') {
                    _confirmDeleteItem(context, item);
                  }
                },
                itemBuilder: (ctx) => [
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

          const SizedBox(height: 12),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedUnit,
                                      isExpanded: true,
                                      dropdownColor: isDark ? _darkCard : Colors.white,
                                      items: _unitOptions.map((u) {
                                        return DropdownMenuItem(
                                          value: u,
                                          child: Text(u.toUpperCase(), style: GoogleFonts.inter(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setModalState(() => selectedUnit = val);
                                      },
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<double>(
                                      value: selectedTax,
                                      isExpanded: true,
                                      dropdownColor: isDark ? _darkCard : Colors.white,
                                      items: _taxSlabs.map((t) {
                                        return DropdownMenuItem(
                                          value: t,
                                          child: Text(t == 0.0 ? '0% (Exempt)' : '${t.toStringAsFixed(0)}% GST',
                                              style: GoogleFonts.inter(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setModalState(() => selectedTax = val);
                                      },
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

                      // 4. Category / Group
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

                            final provider = Provider.of<ExpenseProvider>(context, listen: false);

                            if (isEditing) {
                              final updated = existingItem.copyWith(
                                name: name,
                                sellingPrice: sellPrice,
                                purchasePrice: buyPrice,
                                unit: selectedUnit,
                                taxRate: selectedTax,
                                category: category.isNotEmpty ? category : null,
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
