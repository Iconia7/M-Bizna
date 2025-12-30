import 'package:duka_manager/db/database_helper.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class SalesProvider with ChangeNotifier {
  final Map<String, CartItem> _cart = {};

  Map<String, CartItem> get cart => _cart;

  double get totalAmount {
    var total = 0.0;
    _cart.forEach((key, cartItem) {
      total += cartItem.product.sellPrice * cartItem.quantity;
    });
    return total;
  }

void addToCart(Product product, {double amount = 1.0}) {
    if (_cart.containsKey(product.barcode)) {
      _cart.update(
        product.barcode,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + amount,
        ),
      );
    }else {
      _cart.putIfAbsent(
        product.barcode,
        () => CartItem(product: product, quantity: amount),
      );
    }
    notifyListeners();
  }

  void updateQuantity(String barcode, double newQty) {
    if (_cart.containsKey(barcode)) {
      _cart.update(
        barcode,
        (existing) => CartItem(product: existing.product, quantity: newQty),
      );
      notifyListeners();
    }
  }

  void removeSingleItem(String barcode) {
    if (!_cart.containsKey(barcode)) return;
    if (_cart[barcode]!.quantity > 1.0) {
      _cart.update(
          barcode,
          (existing) => CartItem(
              product: existing.product,
              quantity: existing.quantity - 1.0));
    } else {
      _cart.remove(barcode);
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // 🚀 PROFESSIONAL UPGRADE: TRANSACTION SUPPORT
  Future<void> submitOrder() async {
    final db = await DatabaseHelper.instance.database;
    final timestamp = DateTime.now().toIso8601String();

    // Use a Transaction (txn) to ensure data integrity
    await db.transaction((txn) async {
      for (var cartItem in _cart.values) {
        final profit = (cartItem.product.sellPrice - cartItem.product.buyPrice) * cartItem.quantity;
        
        // 1. Record the Sale
        await txn.insert('sales', {
          'product_id': cartItem.product.id,
          'quantity': cartItem.quantity,
          'total_price': cartItem.total, // Uses getter from CartItem model
          'profit': profit,
          'date_time': timestamp,
          'synced': 0 
        });

        // 2. Deduct Stock
        final newStock = cartItem.product.stockQty - cartItem.quantity;
        
        await txn.update(
          'products',
          {'stock_qty': newStock},
          where: 'id = ?',
          whereArgs: [cartItem.product.id],
        );
      }
    });

    clearCart();
  }
}