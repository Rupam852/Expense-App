import 'dart:convert';

class KhataEntry {
  final String id;
  final String personName;
  final String? phoneNumber;
  final double amount;
  final String type; // 'lent' (You will get) or 'borrowed' (You will give)
  final DateTime entryDate;
  final DateTime? dueDate;
  final String? note;
  final bool isSettled;
  final DateTime? settledAt;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  KhataEntry({
    required this.id,
    required this.personName,
    this.phoneNumber,
    required this.amount,
    required this.type,
    required this.entryDate,
    this.dueDate,
    this.note,
    this.isSettled = false,
    this.settledAt,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLent => type.toLowerCase() == 'lent';
  bool get isBorrowed => type.toLowerCase() == 'borrowed';

  bool get isOverdue {
    if (isSettled || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  KhataEntry copyWith({
    String? id,
    String? personName,
    String? phoneNumber,
    double? amount,
    String? type,
    DateTime? entryDate,
    DateTime? dueDate,
    String? note,
    bool? isSettled,
    DateTime? settledAt,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KhataEntry(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      entryDate: entryDate ?? this.entryDate,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_name': personName,
      'phone_number': phoneNumber,
      'amount': amount,
      'type': type,
      'entry_date': entryDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'note': note,
      'is_settled': isSettled ? 1 : 0,
      'settled_at': settledAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory KhataEntry.fromMap(Map<String, dynamic> map) {
    return KhataEntry(
      id: map['id'] ?? '',
      personName: map['person_name'] ?? 'Unknown',
      phoneNumber: map['phone_number'],
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      type: map['type'] ?? 'lent',
      entryDate: map['entry_date'] != null ? DateTime.parse(map['entry_date']) : DateTime.now(),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      note: map['note'],
      isSettled: map['is_settled'] == 1 || map['is_settled'] == true,
      settledAt: map['settled_at'] != null ? DateTime.parse(map['settled_at']) : null,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory KhataEntry.fromJson(String source) => KhataEntry.fromMap(json.decode(source));
}
