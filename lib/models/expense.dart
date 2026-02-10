class Expense {
  final int? id;
  final String description;
  final double amount;
  final String category;
  final DateTime dateTime;

  Expense({
    this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'date_time': dateTime.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      description: map['description'],
      amount: map['amount'],
      category: map['category'],
      dateTime: DateTime.parse(map['date_time']),
    );
  }
}
