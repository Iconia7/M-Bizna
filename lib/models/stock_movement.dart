class StockMovement {
  final int? id;
  final int productId;
  final double changeQty;
  final double previousQty;
  final double newQty;
  final String type; // 'SALE', 'RESTOCK', 'ADJUSTMENT'
  final String? reason;
  final DateTime dateTime;

  StockMovement({
    this.id,
    required this.productId,
    required this.changeQty,
    required this.previousQty,
    required this.newQty,
    required this.type,
    this.reason,
    required this.dateTime,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      changeQty: (map['change_qty'] as num).toDouble(),
      previousQty: (map['previous_qty'] as num).toDouble(),
      newQty: (map['new_qty'] as num).toDouble(),
      type: map['type'] as String,
      reason: map['reason'] as String?,
      dateTime: DateTime.parse(map['date_time'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'change_qty': changeQty,
      'previous_qty': previousQty,
      'new_qty': newQty,
      'type': type,
      'reason': reason,
      'date_time': dateTime.toIso8601String(),
    };
  }
}
