import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopProvider with ChangeNotifier {
  String _shopName = "My Shop";
  String _shopId = ""; 
  ThemeMode _themeMode = ThemeMode.system;
  bool _isDarkMode = false;
  bool _enableSound = true;
  bool _enableNotifications = true;
  DateTime? _proExpiry;
  bool _autoRenew = false;
  String? _ownerUid;
  bool get autoRenewEnabled => _autoRenew;
  bool _isPro = false;
  String _payheroChannelId = ""; // 👈 NEW
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
  String get payheroChannelId => _payheroChannelId; // 👈 NEW
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }
  bool get enableSound => _enableSound;
  bool get enableNotifications => _enableNotifications;

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
        _isPro = data['is_pro'] ?? false;
        _payheroChannelId = data['payhero_channel_id'] ?? ""; // 👈 Sync ID
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

  /// RESTORE LOGIC: Find shop by Owner Phone or Owner UID
  Future<String?> findShopByPhoneOrUid({String? phone, required String uid}) async {
    QuerySnapshot<Map<String, dynamic>>? snapshot;

    // 1. Primary lookup by phone number (guarantees restore across different phones/devices)
    if (phone != null && phone.isNotEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('owner_phone', isEqualTo: phone)
          .limit(1)
          .get();
    }

    // 2. Fallback lookup by owner_uid if not found by phone
    if ((snapshot == null || snapshot.docs.isEmpty) && uid.isNotEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('owner_uid', isEqualTo: uid)
          .limit(1)
          .get();
    }

    if (snapshot != null && snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data();
      _shopId = doc.id;
      _shopName = data['shop_name'] ?? "My Shop";
      _isPro = data['is_pro'] ?? false;
      _autoRenew = data['auto_renew'] ?? false;
      if (data['pro_expiry'] != null) {
        _proExpiry = (data['pro_expiry'] as Timestamp).toDate();
      }
      _payheroChannelId = data['payhero_channel_id'] ?? "";

      // Re-link current device uid and ensure owner_phone is set
      await doc.reference.set({
        if (phone != null && phone.isNotEmpty) 'owner_phone': phone,
        'owner_uid': uid,
      }, SetOptions(merge: true));

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_id', _shopId);
      await prefs.setString('shop_name', _shopName);

      notifyListeners();
      return _shopId;
    }
    return null;
  }

  /// Backward-compatible wrapper
  Future<String?> findShopByUid(String uid) async {
    return findShopByPhoneOrUid(uid: uid);
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

    final themeString = prefs.getString('theme_mode');
    if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
      _isDarkMode = true;
    } else if (themeString == 'light') {
      _themeMode = ThemeMode.light;
      _isDarkMode = false;
    } else if (prefs.containsKey('is_dark_mode')) {
      final legacyDark = prefs.getBool('is_dark_mode') ?? false;
      _themeMode = legacyDark ? ThemeMode.dark : ThemeMode.light;
      _isDarkMode = legacyDark;
    } else {
      _themeMode = ThemeMode.system;
      _isDarkMode = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }

    _enableSound = prefs.getBool('enable_sound') ?? true;
    _enableNotifications = prefs.getBool('enable_notifications') ?? true;
    _isSecurityEnabled = prefs.getBool('security_enabled') ?? true;

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

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _isDarkMode = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

    final prefs = await SharedPreferences.getInstance();
    String modeString = 'system';
    if (mode == ThemeMode.dark) modeString = 'dark';
    if (mode == ThemeMode.light) modeString = 'light';

    await prefs.setString('theme_mode', modeString);
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    await setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggleSound(bool value) async {
    _enableSound = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_sound', value);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    _enableNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_notifications', value);
    notifyListeners();
  }
}