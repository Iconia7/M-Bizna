class CustomerLedgerEntry {
  final int? id;
  final int customerId;
  final String type; // 'CREDIT_SALE', 'PAYMENT'
  final double amount;
  final double balanceAfter;
  final String? note;
  final DateTime dateTime;

  CustomerLedgerEntry({
    this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.note,
    required this.dateTime,
  });

  factory CustomerLedgerEntry.fromMap(Map<String, dynamic> map) {
    return CustomerLedgerEntry(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      note: map['note'] as String?,
      dateTime: DateTime.parse(map['date_time'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'type': type,
      'amount': amount,
      'balance_after': balanceAfter,
      'note': note,
      'date_time': dateTime.toIso8601String(),
    };
  }
}
