class Product {
  final int? id;
  final String name;
  final String barcode;
  final double buyPrice;
  final double sellPrice;
  double stockQty; // 🚀 CHANGE: Changed from int to double
  final String unit;
  final String? imagePath;

  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.buyPrice,
    required this.sellPrice,
    required this.stockQty,
    this.unit = 'Pcs',
    this.imagePath,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      // 🚀 SAFETY UPGRADE: Use .toDouble() to handle both int and double from DB
      buyPrice: (map['buy_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      stockQty: (map['stock_qty'] as num).toDouble(), // 👈 This fixes the crash
      unit: map['unit'] ?? 'Pcs',
      imagePath: map['image_path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'barcode': barcode,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'stock_qty': stockQty, // Saves double value (e.g., 1.5)
      'unit': unit,
      'image_path': imagePath,
    };
  }
}