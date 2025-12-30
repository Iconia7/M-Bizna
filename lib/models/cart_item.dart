import 'product.dart';

class CartItem {
  final Product product;
  final double quantity;

  CartItem({
    required this.product,
    this.quantity = 1.0,
  });

  // Getter for total price of this line item
  double get total {
    return product.sellPrice * quantity;
  }
}

