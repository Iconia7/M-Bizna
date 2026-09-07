class SaleReturn {
  final int? id;
  final int saleId;
  final int productId;
  final double quantity;
  final double refundAmount;
  final String reason;
  final DateTime dateTime;

  SaleReturn({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.refundAmount,
    required this.reason,
    required this.dateTime,
  });

  factory SaleReturn.fromMap(Map<String, dynamic> map) {
    return SaleReturn(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      refundAmount: (map['refund_amount'] as num).toDouble(),
      reason: map['reason'] as String,
      dateTime: DateTime.parse(map['date_time'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'refund_amount': refundAmount,
      'reason': reason,
      'date_time': dateTime.toIso8601String(),
    };
  }
}
