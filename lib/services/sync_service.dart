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

  // 2. SYNC PRODUCTS (New)
  Future<void> syncProducts() async {
    final db = await DatabaseHelper.instance.database;
    final products = await db.query('products'); // Sync ALL products to ensure updates

    final batch = _firestore.batch();
    
    for (var row in products) {
      // Use barcode as ID so we don't duplicate
      final docRef = _firestore.collection('products').doc(row['barcode'].toString());
      batch.set(docRef, row); // Overwrite cloud with local
    }

    await batch.commit();
  }

  // 3. SYNC CUSTOMERS (New)
  Future<void> syncCustomers() async {
    final db = await DatabaseHelper.instance.database;
    final customers = await db.query('customers');

    final batch = _firestore.batch();
    
    for (var row in customers) {
      final docRef = _firestore.collection('customers').doc(row['phone'].toString());
      batch.set(docRef, row);
    }

    await batch.commit();
  }

  // 🚀 MASTER SYNC COMMAND
  Future<void> syncAll(String shopId) async {
    await syncSales(shopId);
    await syncProducts();
    await syncCustomers();
    debugPrint("✅ Full Cloud Sync Complete");
  }
}