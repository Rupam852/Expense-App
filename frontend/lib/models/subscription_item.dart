import 'dart:convert';

class SubscriptionItem {
  final String id;
  final String name;
  final double amount;
  final String billingCycle; // 'monthly', 'quarterly', 'half_yearly', 'yearly'
  final DateTime nextRenewalDate;
  final String category;
  final bool autoRenewal;
  final int reminderDaysBefore;
  final String? paymentMethod;
  final bool isActive;
  final String? note;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionItem({
    required this.id,
    required this.name,
    required this.amount,
    this.billingCycle = 'monthly',
    required this.nextRenewalDate,
    this.category = 'Subscription',
    this.autoRenewal = true,
    this.reminderDaysBefore = 2,
    this.paymentMethod,
    this.isActive = true,
    this.note,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get monthlyEquivalent {
    switch (billingCycle.toLowerCase()) {
      case 'yearly':
      case 'annual':
        return amount / 12.0;
      case 'half_yearly':
        return amount / 6.0;
      case 'quarterly':
        return amount / 3.0;
      case 'weekly':
        return amount * 4.33;
      case 'monthly':
      default:
        return amount;
    }
  }

  double get yearlyEquivalent => monthlyEquivalent * 12.0;

  int get daysUntilRenewal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextRenewalDate.year, nextRenewalDate.month, nextRenewalDate.day);
    return due.difference(today).inDays;
  }

  bool get isDueSoon => isActive && daysUntilRenewal >= 0 && daysUntilRenewal <= 3;
  bool get isOverdue => isActive && daysUntilRenewal < 0;

  DateTime get nextCycleDate {
    switch (billingCycle.toLowerCase()) {
      case 'yearly':
      case 'annual':
        return DateTime(nextRenewalDate.year + 1, nextRenewalDate.month, nextRenewalDate.day);
      case 'half_yearly':
        return DateTime(nextRenewalDate.year, nextRenewalDate.month + 6, nextRenewalDate.day);
      case 'quarterly':
        return DateTime(nextRenewalDate.year, nextRenewalDate.month + 3, nextRenewalDate.day);
      case 'weekly':
        return nextRenewalDate.add(const Duration(days: 7));
      case 'monthly':
      default:
        return DateTime(nextRenewalDate.year, nextRenewalDate.month + 1, nextRenewalDate.day);
    }
  }

  SubscriptionItem copyWith({
    String? id,
    String? name,
    double? amount,
    String? billingCycle,
    DateTime? nextRenewalDate,
    String? category,
    bool? autoRenewal,
    int? reminderDaysBefore,
    String? paymentMethod,
    bool? isActive,
    String? note,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      billingCycle: billingCycle ?? this.billingCycle,
      nextRenewalDate: nextRenewalDate ?? this.nextRenewalDate,
      category: category ?? this.category,
      autoRenewal: autoRenewal ?? this.autoRenewal,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'billing_cycle': billingCycle,
      'next_renewal_date': nextRenewalDate.toIso8601String(),
      'category': category,
      'auto_renewal': autoRenewal ? 1 : 0,
      'reminder_days_before': reminderDaysBefore,
      'payment_method': paymentMethod,
      'is_active': isActive ? 1 : 0,
      'note': note,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SubscriptionItem.fromMap(Map<String, dynamic> map) {
    return SubscriptionItem(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Subscription',
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      billingCycle: map['billing_cycle'] ?? 'monthly',
      nextRenewalDate: map['next_renewal_date'] != null
          ? DateTime.parse(map['next_renewal_date'])
          : DateTime.now().add(const Duration(days: 30)),
      category: map['category'] ?? 'Subscription',
      autoRenewal: map['auto_renewal'] == 1 || map['auto_renewal'] == true,
      reminderDaysBefore: int.tryParse(map['reminder_days_before'].toString()) ?? 2,
      paymentMethod: map['payment_method'],
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      note: map['note'],
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory SubscriptionItem.fromJson(String source) => SubscriptionItem.fromMap(json.decode(source));
}
