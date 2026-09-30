import 'dart:convert';

class SplitParticipant {
  final String name;
  final double shareAmount;
  final bool isSettled;
  final DateTime? settledAt;
  final String? phoneNumber;

  SplitParticipant({
    required this.name,
    required this.shareAmount,
    this.isSettled = false,
    this.settledAt,
    this.phoneNumber,
  });

  SplitParticipant copyWith({
    String? name,
    double? shareAmount,
    bool? isSettled,
    DateTime? settledAt,
    String? phoneNumber,
  }) {
    return SplitParticipant(
      name: name ?? this.name,
      shareAmount: shareAmount ?? this.shareAmount,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'share_amount': shareAmount,
      'is_settled': isSettled ? 1 : 0,
      'settled_at': settledAt?.toIso8601String(),
      'phone_number': phoneNumber,
    };
  }

  factory SplitParticipant.fromMap(Map<String, dynamic> map) {
    return SplitParticipant(
      name: map['name'] ?? 'Guest',
      shareAmount: double.tryParse(map['share_amount'].toString()) ?? 0.0,
      isSettled: map['is_settled'] == 1 || map['is_settled'] == true,
      settledAt: map['settled_at'] != null ? DateTime.parse(map['settled_at']) : null,
      phoneNumber: map['phone_number'],
    );
  }
}

class SplitBill {
  final String id;
  final String title;
  final double totalAmount;
  final String paidBy; // 'You' or Participant Name
  final String? payerUpiId;
  final DateTime billDate;
  final String splitType; // 'equal' or 'custom'
  final List<SplitParticipant> participants;
  final String? note;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  SplitBill({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.paidBy,
    this.payerUpiId,
    required this.billDate,
    this.splitType = 'equal',
    required this.participants,
    this.note,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isPaidByMe => paidBy.trim().toLowerCase() == 'you';

  double get myShare {
    final myPart = participants.where((p) => p.name.trim().toLowerCase() == 'you').toList();
    if (myPart.isNotEmpty) return myPart.first.shareAmount;
    return 0.0;
  }

  double get pendingCollection {
    if (!isPaidByMe) return 0.0;
    return participants
        .where((p) => p.name.trim().toLowerCase() != 'you' && !p.isSettled)
        .fold<double>(0.0, (sum, p) => sum + p.shareAmount);
  }

  double get myPendingToPay {
    if (isPaidByMe) return 0.0;
    final myPart = participants.where((p) => p.name.trim().toLowerCase() == 'you' && !p.isSettled).toList();
    if (myPart.isNotEmpty) return myPart.first.shareAmount;
    return 0.0;
  }

  bool get isFullySettled {
    return participants.every((p) => p.isSettled || p.name.trim().toLowerCase() == paidBy.trim().toLowerCase());
  }

  int get settledCount {
    return participants.where((p) => p.isSettled || p.name.trim().toLowerCase() == paidBy.trim().toLowerCase()).length;
  }

  SplitBill copyWith({
    String? id,
    String? title,
    double? totalAmount,
    String? paidBy,
    String? payerUpiId,
    DateTime? billDate,
    String? splitType,
    List<SplitParticipant>? participants,
    String? note,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SplitBill(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      paidBy: paidBy ?? this.paidBy,
      payerUpiId: payerUpiId ?? this.payerUpiId,
      billDate: billDate ?? this.billDate,
      splitType: splitType ?? this.splitType,
      participants: participants ?? this.participants,
      note: note ?? this.note,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'total_amount': totalAmount,
      'paid_by': paidBy,
      'payer_upi_id': payerUpiId,
      'bill_date': billDate.toIso8601String(),
      'split_type': splitType,
      'participants_json': json.encode(participants.map((p) => p.toMap()).toList()),
      'note': note,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SplitBill.fromMap(Map<String, dynamic> map) {
    List<SplitParticipant> parts = [];
    if (map['participants_json'] != null) {
      try {
        final decoded = json.decode(map['participants_json'].toString());
        if (decoded is List) {
          parts = decoded.map((item) => SplitParticipant.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      } catch (_) {}
    }

    return SplitBill(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Split Bill',
      totalAmount: double.tryParse(map['total_amount'].toString()) ?? 0.0,
      paidBy: map['paid_by'] ?? 'You',
      payerUpiId: map['payer_upi_id'],
      billDate: map['bill_date'] != null ? DateTime.parse(map['bill_date']) : DateTime.now(),
      splitType: map['split_type'] ?? 'equal',
      participants: parts,
      note: map['note'],
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory SplitBill.fromJson(String source) => SplitBill.fromMap(json.decode(source));
}
