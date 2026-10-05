import 'dart:convert';

class BusinessSaleItem {
  final String id;
  final String saleId;
  final String itemName;
  final double quantity;
  final String unit;
  final double unitPrice; // Selling Rate (Printed on Invoice)
  final double? purchasePrice; // Purchase / Cost Price (Confidential, never on Invoice)
  final double taxRate; // e.g. 0, 5, 12, 18, 28
  final double totalPrice;

  BusinessSaleItem({
    required this.id,
    required this.saleId,
    required this.itemName,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    this.purchasePrice,
    this.taxRate = 0.0,
    required this.totalPrice,
  });

  double get itemCost => quantity * (purchasePrice ?? 0.0);
  double get itemGrossProfit => purchasePrice != null && purchasePrice! > 0
      ? (quantity * unitPrice) - itemCost
      : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'purchase_price': purchasePrice,
      'tax_rate': taxRate,
      'total_price': totalPrice,
    };
  }

  factory BusinessSaleItem.fromMap(Map<String, dynamic> map) {
    return BusinessSaleItem(
      id: map['id']?.toString() ?? '',
      saleId: map['sale_id']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit']?.toString() ?? 'pcs',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BusinessSale {
  final String id;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerGstin;
  final double totalAmount;
  final double taxAmount;
  final double discountAmount;
  final double finalAmount;
  final double paidAmount;
  final double balanceDue;
  final String paymentMode; // cash, upi, bank, credit
  final String paymentStatus; // paid, partial, unpaid
  final DateTime saleDate;
  final String invoiceNo;
  final String? notes;
  final List<BusinessSaleItem> items;
  final int syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessSale({
    required this.id,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerGstin,
    required this.totalAmount,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    required this.finalAmount,
    this.paidAmount = 0.0,
    this.balanceDue = 0.0,
    this.paymentMode = 'cash',
    this.paymentStatus = 'paid',
    required this.saleDate,
    required this.invoiceNo,
    this.notes,
    this.items = const [],
    this.syncStatus = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get totalPurchaseCost => items.fold(0.0, (acc, item) => acc + item.itemCost);
  double get grossProfit => totalPurchaseCost > 0 ? (finalAmount - totalPurchaseCost) : finalAmount;
  double get grandTotal => finalAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'customer_gstin': customerGstin,
      'total_amount': totalAmount,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'paid_amount': paidAmount,
      'balance_due': balanceDue,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'sale_date': (saleDate.isUtc ? saleDate : saleDate.toUtc()).toIso8601String(),
      'invoice_no': invoiceNo,
      'notes': notes,
      'items_json': json.encode(items.map((i) => i.toMap()).toList()),
      'sync_status': syncStatus,
      'created_at': (createdAt.isUtc ? createdAt : createdAt.toUtc()).toIso8601String(),
      'updated_at': (updatedAt.isUtc ? updatedAt : updatedAt.toUtc()).toIso8601String(),
    };
  }

  factory BusinessSale.fromMap(Map<String, dynamic> map) {
    List<BusinessSaleItem> parsedItems = [];
    if (map['items_json'] != null && map['items_json'].toString().isNotEmpty) {
      try {
        final decoded = json.decode(map['items_json'].toString());
        if (decoded is List) {
          parsedItems = decoded.map((i) => BusinessSaleItem.fromMap(Map<String, dynamic>.from(i))).toList();
        }
      } catch (_) {}
    }

    DateTime parseDate(dynamic raw) {
      if (raw == null) return DateTime.now();
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return DateTime.now();
      return dt.isUtc ? dt.toLocal() : dt;
    }

    return BusinessSale(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString(),
      customerName: map['customer_name']?.toString() ?? 'Walk-in Customer',
      customerPhone: map['customer_phone']?.toString(),
      customerAddress: map['customer_address']?.toString(),
      customerGstin: map['customer_gstin']?.toString(),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      finalAmount: (map['final_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceDue: (map['balance_due'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['payment_mode']?.toString() ?? map['payment_method']?.toString() ?? 'cash',
      paymentStatus: map['payment_status']?.toString() ?? 'paid',
      saleDate: parseDate(map['sale_date']),
      invoiceNo: map['invoice_no']?.toString() ?? '',
      notes: map['notes']?.toString(),
      items: parsedItems,
      syncStatus: (map['sync_status'] as num?)?.toInt() ?? (map['is_synced'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
