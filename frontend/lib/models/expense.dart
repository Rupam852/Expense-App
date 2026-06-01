import 'dart:convert';

class Expense {
  final String id;
  final double amount;
  final String currency;
  final String category;
  final String description;
  final DateTime transactionDate;
  final String? receiptUrl;
  final bool isRecurring;
  final String recurrencePeriod;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.amount,
    this.currency = 'INR',
    required this.category,
    this.description = '',
    required this.transactionDate,
    this.receiptUrl,
    this.isRecurring = false,
    this.recurrencePeriod = 'none',
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Create a copy of Expense with optional changed values
  Expense copyWith({
    String? id,
    double? amount,
    String? currency,
    String? category,
    String? description,
    DateTime? transactionDate,
    String? receiptUrl,
    bool? isRecurring,
    String? recurrencePeriod,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePeriod: recurrencePeriod ?? this.recurrencePeriod,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to Map for SQLite database
  Map<String, dynamic> toMap({bool includeSyncFlags = true}) {
    final map = {
      'id': id,
      'amount': amount,
      'currency': currency,
      'category': category,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'receipt_url': receiptUrl,
      'is_recurring': isRecurring ? 1 : 0,
      'recurrence_period': recurrencePeriod,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    return map;
  }

  // Create from Map from SQLite or Backend JSON
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      currency: map['currency'] ?? 'INR',
      category: map['category'] ?? 'Others',
      description: map['description'] ?? '',
      transactionDate: map['transaction_date'] != null
          ? DateTime.parse(map['transaction_date'])
          : DateTime.now(),
      receiptUrl: map['receipt_url'],
      isRecurring: map['is_recurring'] == 1 || map['is_recurring'] == true,
      recurrencePeriod: map['recurrence_period'] ?? 'none',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  // Serialize to JSON String
  String toJson() => json.encode(toMap());

  // Deserialize from JSON String
  factory Expense.fromJson(String source) => Expense.fromMap(json.decode(source));
}
