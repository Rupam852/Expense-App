import 'dart:convert';

class PaymentDetail {
  final String id;
  final String upiId;
  final String? qrCodeUrl; // Web URL or local storage image path
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentDetail({
    required this.id,
    required this.upiId,
    this.qrCodeUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PaymentDetail copyWith({
    String? id,
    String? upiId,
    String? qrCodeUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentDetail(
      id: id ?? this.id,
      upiId: upiId ?? this.upiId,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'upi_id': upiId,
      'qr_code_url': qrCodeUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PaymentDetail.fromMap(Map<String, dynamic> map) {
    return PaymentDetail(
      id: map['id'],
      upiId: map['upi_id'] ?? '',
      qrCodeUrl: map['qr_code_url'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PaymentDetail.fromJson(String source) => PaymentDetail.fromMap(json.decode(source));
}
