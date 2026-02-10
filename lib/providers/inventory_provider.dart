import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';

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
      
  // Update your local list with the cloud data
  _products = snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
  notifyListeners();
}

  // 2. ADD: Insert into SQLite
  Future<void> addProduct(Product product, {bool isPro = false}) async {
    final db = await DatabaseHelper.instance.database;
    
    // Check if barcode exists first to prevent duplicates (Optional safety)
    final existing = await db.query('products', where: 'barcode = ?', whereArgs: [product.barcode]);
    
    if (existing.isNotEmpty) {
      // If exists, update stock instead (Upsert logic)
      final existingProduct = Product.fromMap(existing.first);
      final newStock = existingProduct.stockQty + product.stockQty;
      
      await db.update(
        'products', 
        {'stock_qty': newStock}, // Only update stock
        where: 'id = ?', 
        whereArgs: [existingProduct.id]
      );
    } else {
      // Insert new
      await db.insert('products', product.toMap());
    }

    await loadProducts(isPro: true); // This will be handled by the caller
  }

  // 3. SEARCH: Find single item by barcode (For Scanner)
  Product? findByBarcode(String code) {
    try {
      return _products.firstWhere((p) => p.barcode == code);
    } catch (e) {
      return null;
    }
  }

  // 4. UPDATE: Modify an existing product
Future<void> updateProduct(Product product, {bool isPro = false}) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'products',
      product.toMap(), // Ensure this includes name, prices, etc.
      where: 'id = ?',
      whereArgs: [product.id],
    );
    await loadProducts(); // Refresh UI
  } 

  // 5. DELETE: Remove item
  Future<void> deleteProduct(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    await loadProducts();
  }
}