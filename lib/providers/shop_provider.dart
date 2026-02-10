import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopProvider with ChangeNotifier {
  String _shopName = "My Shop";
  String _shopId = ""; 
  bool _isDarkMode = false;
  bool _enableSound = true;
  DateTime? _proExpiry;
  bool _autoRenew = false;
  String? _ownerUid;
  bool get autoRenewEnabled => _autoRenew;
  bool _isPro = false;
  String _userRole = 'Owner'; // 👈 NEW: 'Owner' or 'Attendant'

  // Getters
  String get userRole => _userRole;
  bool get isOwner => _userRole == 'Owner';
  bool get isAttendant => _userRole == 'Attendant';
  
  // Check if Pro features are currently active
  bool get isProActive {
    if (_proExpiry == null) return _isPro;
    return _proExpiry!.isAfter(DateTime.now());
  }

  // Getters
  String get shopName => _shopName;
  String get shopId => _shopId; 
  bool get isDarkMode => _isDarkMode;
  bool get enableSound => _enableSound;

  ShopProvider() {
    _loadSettings();
  }

  bool _isSecurityEnabled = true; // Default to ON
  bool get isSecurityEnabled => _isSecurityEnabled;

  // Initialize security setting from storage
  Future<void> loadSecuritySetting() async {
    final prefs = await SharedPreferences.getInstance();
    _isSecurityEnabled = prefs.getBool('security_enabled') ?? true;
    notifyListeners();
  }

Future<void> refreshProStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['pro_expiry'] != null) {
          _proExpiry = (data['pro_expiry'] as Timestamp).toDate();
        }
        _isPro = data['is_pro'] ?? false; // 👈 Now this works!
        _autoRenew = data['auto_renew'] ?? false;
        notifyListeners(); 
      }
    } catch (e) {
      debugPrint("Error refreshing pro status: $e");
    }
  }

  // Toggle and save
  Future<void> toggleSecurity(bool value) async {
    _isSecurityEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('security_enabled', value);
    notifyListeners();
  }

  int get daysRemaining {
  if (_proExpiry == null) return 0;
  final difference = _proExpiry!.difference(DateTime.now()).inDays;
  return difference > 0 ? difference : 0;
}


Future<void> toggleAutoRenew(bool value) async {
    _autoRenew = value;
    notifyListeners();
    
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'auto_renew': value
    });
  }

  // Update your loadSubscriptionStatus to also fetch 'auto_renew'
  Future<void> loadSubscriptionStatus(String? uid) async {
    if (shopId.isEmpty) return;
    
    final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
    if (doc.exists) {
      final data = doc.data()!;
      _proExpiry = (data['pro_expiry'] as Timestamp?)?.toDate();
      _autoRenew = data['auto_renew'] ?? false;
      _ownerUid = data['owner_uid'];
      
      // Safety link: If doc exists but no UID, link it now
      if (_ownerUid == null && uid != null) {
        await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
          'owner_uid': uid
        });
        _ownerUid = uid;
      }
      
      notifyListeners();
    }
  }

  /// RESTORE LOGIC: Find shop by Owner UID
  Future<String?> findShopByUid(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shops')
        .where('owner_uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      _shopId = doc.id;
      _shopName = doc.data()['shop_name'] ?? "My Shop";
      
      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_id', _shopId);
      await prefs.setString('shop_name', _shopName);
      
      notifyListeners();
      return _shopId;
    }
    return null;
  }


  // 🚀 NEW: Centralized Reference Generator
  // This creates the "TYPE|SHOPID|TIMESTAMP" string for PayHero
  String generatePayHeroRef(String type) {
    if (_shopId.isEmpty) return "PENDING_ID";
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "$type|$_shopId|$timestamp";
  }

  Future<void> toggleUserRole() async {
    _userRole = _userRole == 'Owner' ? 'Attendant' : 'Owner';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', _userRole);
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _shopName = prefs.getString('shop_name') ?? "My Shop";
    _userRole = prefs.getString('user_role') ?? 'Owner';
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    _enableSound = prefs.getBool('enable_sound') ?? true;

    // 🧠 UNIQUE ID LOGIC
    _shopId = prefs.getString('shop_id') ?? "";
    if (_shopId.isEmpty) {
      _shopId = "SHOP-${DateTime.now().millisecondsSinceEpoch}"; 
      await prefs.setString('shop_id', _shopId);
    }

    notifyListeners();
  }

  Future<void> updateShopName(String name) async {
    _shopName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', name);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  Future<void> toggleSound(bool value) async {
    _enableSound = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_sound', value);
    notifyListeners();
  }
}