import 'package:duka_manager/db/database_helper.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class HeldSale {
  final String id;
  final Map<String, CartItem> cart;
  final double totalAmount;
  final DateTime heldAt;
  final String? note;

  HeldSale({
    required this.id,
    required this.cart,
    required this.totalAmount,
    required this.heldAt,
    this.note,
  });

  int get itemCount => cart.values.fold(0, (sum, item) => sum + item.quantity.toInt());
}

class SalesProvider with ChangeNotifier {
  final Map<String, CartItem> _cart = {};
  final List<HeldSale> _heldSales = [];

  Map<String, CartItem> get cart => _cart;
  List<HeldSale> get heldSales => [..._heldSales];
  int get heldSalesCount => _heldSales.length;

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
    } else {
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

  // --- HELD SALES (PARK & RESUME CARTS) ---
  bool holdCurrentCart({String? note}) {
    if (_cart.isEmpty) return false;

    final held = HeldSale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cart: Map.from(_cart),
      totalAmount: totalAmount,
      heldAt: DateTime.now(),
      note: note,
    );

    _heldSales.insert(0, held);
    clearCart();
    return true;
  }

  bool resumeHeldSale(String id) {
    final index = _heldSales.indexWhere((h) => h.id == id);
    if (index == -1) return false;

    final held = _heldSales.removeAt(index);
    _cart.clear();
    _cart.addAll(held.cart);
    notifyListeners();
    return true;
  }

  void deleteHeldSale(String id) {
    _heldSales.removeWhere((h) => h.id == id);
    notifyListeners();
  }

  // --- TRANSACTION SUBMIT ---
  Future<void> submitOrder() async {
    final db = await DatabaseHelper.instance.database;
    final timestamp = DateTime.now().toIso8601String();

    // Use a Transaction (txn) to ensure data integrity
    await db.transaction((txn) async {
      for (var cartItem in _cart.values) {
        int? resolvedProductId = cartItem.product.id;
        if (resolvedProductId == null) {
          final res = await txn.query('products', where: 'barcode = ?', whereArgs: [cartItem.product.barcode]);
          if (res.isNotEmpty) {
            resolvedProductId = res.first['id'] as int?;
          }
        }
        if (resolvedProductId == null) continue;

        final profit = (cartItem.product.sellPrice - cartItem.product.buyPrice) * cartItem.quantity;
        
        // 1. Record the Sale
        await txn.insert('sales', {
          'product_id': resolvedProductId,
          'quantity': cartItem.quantity,
          'total_price': cartItem.total,
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
          whereArgs: [resolvedProductId],
        );

        // 3. Log Stock Movement Audit Trail
        await txn.insert('stock_movements', {
          'product_id': resolvedProductId,
          'change_qty': -cartItem.quantity,
          'previous_qty': cartItem.product.stockQty,
          'new_qty': newStock,
          'type': 'SALE',
          'reason': 'POS Sale Checkout',
          'date_time': timestamp,
        });
      }
    });

    clearCart();
  }

  // --- RETURN & REFUND PROCESSING ---
  Future<bool> processReturn({
    required int saleId,
    required int productId,
    required double returnQty,
    required double refundAmount,
    required String reason,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final timestamp = DateTime.now().toIso8601String();

    try {
      await db.transaction((txn) async {
        // 1. Record in returns table
        await txn.insert('returns', {
          'sale_id': saleId,
          'product_id': productId,
          'quantity': returnQty,
          'refund_amount': refundAmount,
          'reason': reason,
          'date_time': timestamp,
        });

        // 2. Fetch current stock and restock
        final productRows = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        if (productRows.isNotEmpty) {
          final currentStock = (productRows.first['stock_qty'] as num).toDouble();
          final newStock = currentStock + returnQty;

          await txn.update(
            'products',
            {'stock_qty': newStock},
            where: 'id = ?',
            whereArgs: [productId],
          );

          // 3. Log Stock Movement Audit Trail
          await txn.insert('stock_movements', {
            'product_id': productId,
            'change_qty': returnQty,
            'previous_qty': currentStock,
            'new_qty': newStock,
            'type': 'ADJUSTMENT',
            'reason': 'Customer Return: $reason',
            'date_time': timestamp,
          });
        }
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error processing return: $e");
      return false;
    }
  }
}