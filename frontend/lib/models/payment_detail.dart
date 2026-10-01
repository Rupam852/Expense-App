import 'dart:convert';

class PaymentDetail {
  final String id;
  final String name; // e.g. "Personal GPay", "Shop PhonePe", "SBI Account"
  final String upiId;
  final String? qrCodeUrl; // Web URL or local storage image path
  final bool isPrimary; // true if this is the default/primary payment method
  final int sortOrder; // integer order for rearranging position
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentDetail({
    required this.id,
    this.name = 'Primary UPI',
    required this.upiId,
    this.qrCodeUrl,
    this.isPrimary = false,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PaymentDetail copyWith({
    String? id,
    String? name,
    String? upiId,
    String? qrCodeUrl,
    bool? isPrimary,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      isPrimary: isPrimary ?? this.isPrimary,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'upi_id': upiId,
      'qr_code_url': qrCodeUrl,
      'is_primary': isPrimary ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PaymentDetail.fromMap(Map<String, dynamic> map) {
    return PaymentDetail(
      id: map['id']?.toString() ?? '',
      name: (map['name'] != null && map['name'].toString().isNotEmpty)
          ? map['name'].toString()
          : 'Primary UPI',
      upiId: map['upi_id']?.toString() ?? '',
      qrCodeUrl: map['qr_code_url']?.toString(),
      isPrimary: map['is_primary'] == 1 || map['is_primary'] == true,
      sortOrder: map['sort_order'] is int
          ? map['sort_order'] as int
          : (int.tryParse(map['sort_order']?.toString() ?? '0') ?? 0),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PaymentDetail.fromJson(String source) => PaymentDetail.fromMap(json.decode(source));
}
