import 'dart:convert';

class Budget {
  final String id;
  final String category;
  final double amountLimit;
  final String monthYear; // Format: YYYY-MM
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.category,
    required this.amountLimit,
    required this.monthYear,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Budget copyWith({
    String? id,
    String? category,
    double? amountLimit,
    String? monthYear,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      amountLimit: amountLimit ?? this.amountLimit,
      monthYear: monthYear ?? this.monthYear,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount_limit': amountLimit,
      'month_year': monthYear,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'] ?? 'Others',
      amountLimit: double.tryParse(map['amount_limit'].toString()) ?? 0.0,
      monthYear: map['month_year'] ?? '',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Budget.fromJson(String source) => Budget.fromMap(json.decode(source));
}
