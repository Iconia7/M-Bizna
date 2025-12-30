class Customer {
  final int? id;
  final String name;
  final String phone;
  double currentDebt;
  final double creditLimit;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.currentDebt = 0.0,
    this.creditLimit = 2000.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'current_debt': currentDebt,
      'credit_limit': creditLimit,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      currentDebt: map['current_debt'] ?? 0.0,
      creditLimit: map['credit_limit'] ?? 2000.0,
    );
  }
}