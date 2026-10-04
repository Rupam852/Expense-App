import 'dart:convert';

class BusinessItem {
  final String id;
  final String name;
  final double purchasePrice; // Confidential Cost/Buy Price
  final double sellingPrice;  // Default Selling Price
  final double taxRate;       // Default GST Rate % (0, 5, 12, 18, 28)
  final String unit;          // 'pcs', 'kg', 'ltr', 'box', 'service', etc.
  final String? category;
  final String? notes;
  final String? barcode;      // Barcode / SKU number
  final double stockQuantity; // Current available inventory stock
  final double lowStockLimit; // Threshold limit for low stock warning alert
  final bool trackStock;      // Whether inventory stock tracking is enabled
  final int syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessItem({
    required this.id,
    required this.name,
    this.purchasePrice = 0.0,
    this.sellingPrice = 0.0,
    this.taxRate = 0.0,
    this.unit = 'pcs',
    this.category,
    this.notes,
    this.barcode,
    this.stockQuantity = 0.0,
    this.lowStockLimit = 5.0,
    this.trackStock = true,
    this.syncStatus = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get profitMargin {
    if (purchasePrice <= 0) return 0.0;
    return sellingPrice - purchasePrice;
  }

  double get profitMarginPercent {
    if (purchasePrice <= 0) return 0.0;
    return ((sellingPrice - purchasePrice) / purchasePrice) * 100.0;
  }

  bool get isOutOfStock => trackStock && stockQuantity <= 0;
  bool get isLowStock => trackStock && stockQuantity > 0 && stockQuantity <= lowStockLimit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'tax_rate': taxRate,
      'unit': unit,
      'category': category,
      'notes': notes,
      'barcode': barcode ?? '',
      'stock_quantity': stockQuantity,
      'low_stock_limit': lowStockLimit,
      'track_stock': trackStock ? 1 : 0,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BusinessItem.fromMap(Map<String, dynamic> map) {
    return BusinessItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit']?.toString() ?? 'pcs',
      category: map['category']?.toString(),
      notes: map['notes']?.toString(),
      barcode: map['barcode']?.toString(),
      stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      lowStockLimit: (map['low_stock_limit'] as num?)?.toDouble() ?? 5.0,
      trackStock: map['track_stock'] == 1 || map['track_stock'] == true || map['track_stock'] == '1' || map['track_stock'] == null,
      syncStatus: (map['sync_status'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  BusinessItem copyWith({
    String? id,
    String? name,
    double? purchasePrice,
    double? sellingPrice,
    double? taxRate,
    String? unit,
    String? category,
    String? notes,
    String? barcode,
    double? stockQuantity,
    double? lowStockLimit,
    bool? trackStock,
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessItem(
      id: id ?? this.id,
      name: name ?? this.name,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      taxRate: taxRate ?? this.taxRate,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      barcode: barcode ?? this.barcode,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockLimit: lowStockLimit ?? this.lowStockLimit,
      trackStock: trackStock ?? this.trackStock,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String toJson() => json.encode(toMap());
  factory BusinessItem.fromJson(String source) => BusinessItem.fromMap(json.decode(source));
}
