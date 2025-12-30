import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duka_manager/db/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletProvider with ChangeNotifier {
  double _balance = 0.0;
  String? _currentShopId;
  List<Map<String, dynamic>> _history = [];

  double get balance => _balance;
  List<Map<String, dynamic>> get history => _history;
  bool canAfford(double cost) {
    return _balance >= cost;
  }

  // Costs
  static const double COST_MPESA_SALE = 2.0;
  static const double COST_CLOUD_SYNC = 2.0;
  static const double MIN_DEPOSIT = 50.0;

  WalletProvider() {
    _loadCachedBalance();
  }

  Future<void> _loadCachedBalance() async {
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getDouble('cached_wallet_balance') ?? 0.0;
    notifyListeners();
  }

  // lib/providers/wallet_provider.dart

Future<bool> paySubscriptionWithWallet(String shopId) async {
  const double subCost = 200.0;
  if (_balance < subCost) return false;

  try {
    // 1. Deduct locally
    _balance -= subCost;
    notifyListeners();

    // 2. Update Firestore (Transaction)
    final shopRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(shopRef);
      DateTime currentExpiry = DateTime.now();
      
      if (snapshot.exists && snapshot.data()!['pro_expiry'] != null) {
        DateTime existingDate = (snapshot.data()!['pro_expiry'] as Timestamp).toDate();
        if (existingDate.isAfter(currentExpiry)) currentExpiry = existingDate;
      }
      
      final newExpiry = currentExpiry.add(const Duration(days: 30));

      transaction.update(shopRef, {
        'wallet_balance': FieldValue.increment(-subCost),
        'pro_expiry': Timestamp.fromDate(newExpiry),
        'is_pro': true,
      });

      // 3. Add to History
      transaction.set(shopRef.collection('wallet_history').doc(), {
        'amount': -subCost,
        'type': 'SUBSCRIPTION',
        'status': 'PAID',
        'description': 'Monthly Pro Subscription (Wallet)',
        'date_time': FieldValue.serverTimestamp(),
      });
    });

    return true;
  } catch (e) {
    debugPrint("Sub Error: $e");
    return false;
  }
}

  // Deduct funds
  Future<bool> chargeWallet(double amount, String featureName) async {
    if (_balance < amount) return false;

    // 1. Local Update (State & SQLite)
    _balance -= amount;
    final db = await DatabaseHelper.instance.database;
    await db.update('wallet', {'balance': _balance}, where: 'id = 1');

    // 2. Cloud Update (Firestore) ☁️
    if (_currentShopId != null) {
      final shopRef = FirebaseFirestore.instance.collection('shops').doc(_currentShopId);
      
      // 🚀 FIX: Use .set with merge: true to avoid [not-found] errors
      await shopRef.set({
        'wallet_balance': FieldValue.increment(-amount), // Atomically deduct
        'last_charge_reason': featureName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Creates doc if it doesn't exist
    }

    // 3. Record Transaction
    await db.insert('wallet_transactions', {
      'amount': -amount,
      'type': 'CHARGE',
      'description': featureName,
      'date_time': DateTime.now().toIso8601String(),
    });

    notifyListeners();
    return true;
  }

  void startBalanceListener(String shopId) {
    if (shopId.isEmpty) return;
    _currentShopId = shopId;

    FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data()!.containsKey('wallet_balance')) {
        _balance = snapshot.data()!['wallet_balance'].toDouble();
        
        // 💾 CACHE: Save to local memory for the next app restart
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('cached_wallet_balance', _balance);
        
        notifyListeners();
      }
    });
  }

  void startHistoryListener(String shopId) {
    FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('wallet_history')
        .orderBy('date_time', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      _history = snapshot.docs.map((doc) => doc.data()).toList();
      notifyListeners();
    });
  }

  // Deposit funds (Called after they pay YOU)
  Future<void> deposit(double amount) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Local Add
    _balance += amount;
    await db.update('wallet', {'balance': _balance}, where: 'id = 1');

    // 2. Cloud Sync (Ensures UI and Cloud stay matched)
    if (_currentShopId != null) {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(_currentShopId)
          .set({
        'wallet_balance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Record Local History
    await db.insert('wallet_transactions', {
      'amount': amount,
      'type': 'DEPOSIT',
      'description': 'Wallet Top Up',
      'date_time': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }
}