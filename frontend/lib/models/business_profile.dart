class BusinessProfile {
  final String id;
  final String businessName;
  final String businessType;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstin;
  final String? upiId;
  final String? logoPath;
  final String? termsAndConditions;
  final DateTime updatedAt;

  BusinessProfile({
    required this.id,
    required this.businessName,
    this.businessType = 'Retail / Shop',
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.upiId,
    this.logoPath,
    this.termsAndConditions,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'business_type': businessType,
      'phone': phone,
      'email': email,
      'address': address,
      'gstin': gstin,
      'upi_id': upiId,
      'logo_path': logoPath,
      'terms_and_conditions': termsAndConditions,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id: map['id']?.toString() ?? 'default_business',
      businessName: map['business_name']?.toString() ?? 'My Business',
      businessType: map['business_type']?.toString() ?? 'Retail / Shop',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      gstin: map['gstin']?.toString(),
      upiId: map['upi_id']?.toString(),
      logoPath: map['logo_path']?.toString(),
      termsAndConditions: map['terms_and_conditions']?.toString(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
