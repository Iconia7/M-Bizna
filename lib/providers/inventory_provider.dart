import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class InventoryProvider with ChangeNotifier {
  List<Product> _products = [];

  List<Product> get products => [..._products];

  // 1. LOAD: Fetch all items from SQLite
  Future<void> loadProducts({bool isPro = false}) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('products', orderBy: 'id DESC');
    
    _products = result.map((json) => Product.fromMap(json)).toList();
    notifyListeners();
    
    if (isPro) {
      _checkLowStock();
    }
  }

  Future<void> _checkLowStock() async {
    for (var product in _products) {
      if (product.stockQty <= 5 && product.stockQty > 0) {
        await NotificationService.showLowStockAlert(product.name, product.stockQty.toInt());
      }
    }
  }

  Future<void> fetchFromCloud(String shopId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('products')
        .get();
        
    _products = snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
    notifyListeners();
  }

  // 2. ADD / RESTOCK: Insert into SQLite & Log Movement
  Future<int> addProduct(Product product, {bool isPro = false}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    int assignedId = 0;
    
    // Check if barcode exists first to prevent duplicates (Upsert logic)
    final existing = await db.query('products', where: 'barcode = ?', whereArgs: [product.barcode]);
    
    if (existing.isNotEmpty) {
      final existingProduct = Product.fromMap(existing.first);
      assignedId = existingProduct.id!;
      final prevStock = existingProduct.stockQty;
      final newStock = prevStock + product.stockQty;
      
      await db.update(
        'products', 
        {'stock_qty': newStock},
        where: 'id = ?', 
        whereArgs: [existingProduct.id]
      );

      // Log Restock Movement
      await db.insert('stock_movements', {
        'product_id': existingProduct.id,
        'change_qty': product.stockQty,
        'previous_qty': prevStock,
        'new_qty': newStock,
        'type': 'RESTOCK',
        'reason': 'Stock Added / Restocked',
        'date_time': now,
      });
    } else {
      // Insert new product
      final newId = await db.insert('products', product.toMap());
      assignedId = newId;
      
      // Log Initial Stock Movement
      await db.insert('stock_movements', {
        'product_id': newId,
        'change_qty': product.stockQty,
        'previous_qty': 0.0,
        'new_qty': product.stockQty,
        'type': 'RESTOCK',
        'reason': 'Initial Catalog Entry',
        'date_time': now,
      });
    }

    await loadProducts(isPro: true);
    return assignedId;
  }

  // 3. SEARCH: Find single item by barcode
  Product? findByBarcode(String code) {
    try {
      return _products.firstWhere((p) => p.barcode == code);
    } catch (e) {
      return null;
    }
  }

  // 4. UPDATE: Modify an existing product & Log Movement if quantity changed
  Future<void> updateProduct(Product product, {bool isPro = false}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query('products', where: 'id = ?', whereArgs: [product.id]);
    if (existing.isNotEmpty) {
      final existingProduct = Product.fromMap(existing.first);
      final prevStock = existingProduct.stockQty;
      
      if (prevStock != product.stockQty) {
        final diff = product.stockQty - prevStock;
        await db.insert('stock_movements', {
          'product_id': product.id,
          'change_qty': diff,
          'previous_qty': prevStock,
          'new_qty': product.stockQty,
          'type': 'ADJUSTMENT',
          'reason': diff > 0 ? 'Manual Stock Increase' : 'Manual Stock Deduction',
          'date_time': now,
        });
      }
    }

    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    await loadProducts();
  } 

  // 5. DELETE: Remove item
  Future<void> deleteProduct(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    await db.delete('stock_movements', where: 'product_id = ?', whereArgs: [id]);
    await loadProducts();
  }

  // 6. STOCK MOVEMENTS AUDIT TRAIL
  Future<List<StockMovement>> getStockMovements(int productId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'date_time DESC',
      limit: 50,
    );

    return result.map((json) => StockMovement.fromMap(json)).toList();
  }

  // 7. PRODUCT PROFITABILITY ANALYTICS
  Future<Map<String, dynamic>> getProductProfitability(Product product) async {
    final db = await DatabaseHelper.instance.database;
    final unitProfit = product.sellPrice - product.buyPrice;
    final marginPercent = product.sellPrice > 0 
        ? ((unitProfit / product.sellPrice) * 100).clamp(0.0, 100.0) 
        : 0.0;

    final now = DateTime.now();
    final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    double monthlySold = 0.0;
    double monthlyProfit = 0.0;

    try {
      final result = await db.rawQuery('''
        SELECT SUM(quantity) as units_sold, SUM(profit) as total_profit 
        FROM sales 
        WHERE product_id = ? AND date_time LIKE ?
      ''', [product.id, '$monthStr%']);

      if (result.isNotEmpty) {
        monthlySold = (result.first['units_sold'] as num?)?.toDouble() ?? 0.0;
        monthlyProfit = (result.first['total_profit'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      monthlySold = 0.0;
      monthlyProfit = 0.0;
    }

    String recommendation;
    if (marginPercent < 15) {
      recommendation = "Low margin ($marginPercent%). Consider adjusting sell price to protect profit.";
    } else if (marginPercent >= 35 && monthlySold > 20) {
      recommendation = "High-performing star product! Keep stock levels healthy.";
    } else if (monthlySold == 0) {
      recommendation = "Slow moving item this month. Consider a promotion or bundle.";
    } else {
      recommendation = "Healthy margin of ${marginPercent.toStringAsFixed(1)}%.";
    }

    return {
      'unit_profit': unitProfit,
      'margin_percent': marginPercent,
      'monthly_sold': monthlySold,
      'monthly_profit': monthlyProfit,
      'recommendation': recommendation,
    };
  }
}