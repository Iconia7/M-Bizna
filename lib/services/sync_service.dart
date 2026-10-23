import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duka_manager/db/database_helper.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. SYNC SALES (Already implemented)
// lib/services/sync_service.dart

Future<void> syncSales(String shopId) async {
  if (shopId.isEmpty) return; // Prevent sync if shopId is missing

  final db = await DatabaseHelper.instance.database;
  
  // 1. Fetch only unsynced items
  final unsynced = await db.query('sales', where: 'synced = ?', whereArgs: [0]);
  
  if (unsynced.isEmpty) return;

  final batch = _firestore.batch();
  
  for (var row in unsynced) {
    // 🚀 ALIGNED PATH: Nested under the specific shop
    final docRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('sales')
        .doc(row['id'].toString());

    batch.set(docRef, {
      ...row, // Upload all columns
      'shopId': shopId, // Added for easier cloud filtering
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // Use merge to prevent overwriting existing data
  }

  // 2. Commit to Cloud
  await batch.commit();
  
  // 3. Mark as local synced in SQLite
  for (var row in unsynced) {
    await db.update(
      'sales', 
      {'synced': 1}, 
      where: 'id = ?', 
      whereArgs: [row['id']]
    );
  }
}

  Future<void> syncLocalToCloud(String shopId) async {
    await syncSales(shopId); 
    // We intentionally don't sync full inventory here to keep checkout fast.
    // Full sync happens via Settings -> Cloud Backup.
  }

  // 2. SYNC PRODUCTS
  Future<void> syncProducts(String shopId) async {
    if (shopId.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final products = await db.query('products');

    if (products.isEmpty) return;
    final batch = _firestore.batch();
    
    for (var row in products) {
      final docRef = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(row['barcode'].toString());
      batch.set(docRef, {
        ...row,
        'shopId': shopId,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // 3. SYNC CUSTOMERS
  Future<void> syncCustomers(String shopId) async {
    if (shopId.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final customers = await db.query('customers');

    if (customers.isEmpty) return;
    final batch = _firestore.batch();
    
    for (var row in customers) {
      final docId = (row['phone'] != null && row['phone'].toString().trim().isNotEmpty)
          ? row['phone'].toString().trim()
          : row['id'].toString();
      final docRef = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .doc(docId);
      batch.set(docRef, {
        ...row,
        'shopId': shopId,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // 🚀 MASTER SYNC COMMAND
  Future<void> syncAll(String shopId) async {
    if (shopId.isEmpty) return;
    await syncSales(shopId);
    await syncProducts(shopId);
    await syncCustomers(shopId);
    debugPrint("✅ Full Cloud Sync Complete for shop $shopId");
  }
}