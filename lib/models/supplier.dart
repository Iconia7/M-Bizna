class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String? company;
  final String? paymentDetails;
  final String? notes;

  Supplier({
    this.id,
    required this.name,
    required this.phone,
    this.company,
    this.paymentDetails,
    this.notes,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      company: map['company'] as String?,
      paymentDetails: map['payment_details'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'company': company,
      'payment_details': paymentDetails,
      'notes': notes,
    };
  }
}
