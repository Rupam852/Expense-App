import 'dart:convert';

class BarcodeLabelBatch {
  final String id;
  final String? userId;
  final String? itemId;
  final String productName;
  final String barcodeData;
  final String barcodeType; // 'barcode' or 'qr'
  final double price;
  final int quantity;
  final int columnsCount; // 3 or 4
  final String? shopName;
  final int syncStatus;
  final DateTime createdAt;

  BarcodeLabelBatch({
    required this.id,
    this.userId,
    this.itemId,
    required this.productName,
    required this.barcodeData,
    this.barcodeType = 'barcode',
    this.price = 0.0,
    this.quantity = 24,
    this.columnsCount = 3,
    this.shopName,
    this.syncStatus = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'item_id': itemId,
      'product_name': productName,
      'barcode_data': barcodeData,
      'barcode_type': barcodeType,
      'price': price,
      'quantity': quantity,
      'columns_count': columnsCount,
      'shop_name': shopName,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BarcodeLabelBatch.fromMap(Map<String, dynamic> map) {
    return BarcodeLabelBatch(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      itemId: map['item_id']?.toString(),
      productName: map['product_name']?.toString() ?? 'Product',
      barcodeData: map['barcode_data']?.toString() ?? '',
      barcodeType: map['barcode_type']?.toString() ?? 'barcode',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toInt() : int.tryParse(map['quantity']?.toString() ?? '24') ?? 24,
      columnsCount: (map['columns_count'] is num) ? (map['columns_count'] as num).toInt() : int.tryParse(map['columns_count']?.toString() ?? '3') ?? 3,
      shopName: map['shop_name']?.toString(),
      syncStatus: (map['sync_status'] is num) ? (map['sync_status'] as num).toInt() : 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BarcodeLabelBatch.fromJson(String source) => BarcodeLabelBatch.fromMap(json.decode(source));
}
