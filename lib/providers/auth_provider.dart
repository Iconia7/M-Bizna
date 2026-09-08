import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:duka_manager/services/sms_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  User? _user;
  String? _phoneNumber;
  String? _customUid;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  String? get phoneNumber => _phoneNumber;
  String get uid => _user?.uid ?? _customUid ?? (_phoneNumber != null ? 'user_${_phoneNumber!.replaceAll(RegExp(r"[^0-9]"), "")}' : 'guest_user');
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null || _customUid != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Start Phone Verification via Secure Firebase Cloud Functions
  Future<void> verifyPhoneNumber(String phoneNumber, {
    required Function(String code) onCodeSent,
    required Function(String error) onError,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final normalizedPhone = SmsService.normalizePhone(phoneNumber.trim());
    if (normalizedPhone == null) {
      _isLoading = false;
      _errorMessage = "Only Kenyan mobile phone numbers (e.g. 07XXXXXXXX or 01XXXXXXXX) are supported.";
      onError(_errorMessage!);
      notifyListeners();
      return;
    }

    _phoneNumber = normalizedPhone;
    notifyListeners();

    // 🛡️ Google Play Reviewer bypass (Works 100% reliably without Cloud Run / SMS network dependency)
    if (normalizedPhone == '+16505551234' || normalizedPhone == '+254117814250') {
      _isLoading = false;
      notifyListeners();
      onCodeSent("123456");
      return;
    }

    try {
      final callable = _functions.httpsCallable('sendPhoneOTP');
      final result = await callable.call({'phone_number': normalizedPhone});

      _isLoading = false;
      notifyListeners();
      onCodeSent(result.data['message'] ?? "");
    } on FirebaseFunctionsException catch (e) {
      _isLoading = false;
      String cleanError = e.message ?? "Failed to send verification code.";
      _errorMessage = cleanError;
      onError(cleanError);
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      String cleanError = e.toString()
          .replaceAll("Exception: ", "")
          .replaceAll(RegExp(r'\[.*?\]'), "")
          .trim();
      _errorMessage = cleanError;
      onError(cleanError);
      notifyListeners();
    }
  }

  /// Sign In with OTP via Secure Firebase Cloud Functions
  Future<bool> signInWithOTP(String smsCode) async {
    if (_phoneNumber == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final normalizedPhone = _phoneNumber!;

    // 🛡️ Google Play Reviewer bypass: Instant login with static test OTP 123456
    if ((normalizedPhone == '+16505551234' || normalizedPhone == '+254117814250') && smsCode.trim() == '123456') {
      try {
        if (_auth.currentUser == null) {
          final userCredential = await _auth.signInAnonymously();
          _user = userCredential.user;
        } else {
          _user = _auth.currentUser;
        }
      } catch (authError) {
        debugPrint("Reviewer auth note: $authError");
      }

      _customUid = 'reviewer_${normalizedPhone.replaceAll(RegExp(r"[^0-9]"), "")}';
      final effectiveUid = uid;

      try {
        await _firestore.collection('users').doc(effectiveUid).set({
          'phone_number': normalizedPhone,
          'last_login': FieldValue.serverTimestamp(),
          'is_reviewer': true,
        }, SetOptions(merge: true));
      } catch (firestoreError) {
        debugPrint("Reviewer user firestore note: $firestoreError");
      }

      _isLoading = false;
      notifyListeners();
      return true;
    }

    try {
      final callable = _functions.httpsCallable('verifyPhoneOTP');
      final result = await callable.call({
        'phone_number': normalizedPhone,
        'code': smsCode.trim(),
      });

      final customToken = result.data['custom_token'] as String?;
      if (customToken != null) {
        final userCredential = await _auth.signInWithCustomToken(customToken);
        _user = userCredential.user;
      } else {
        _customUid = result.data['uid'] as String? ?? 'user_${normalizedPhone.replaceAll(RegExp(r"[^0-9]"), "")}';
      }

      final effectiveUid = uid;

      // Save phone number reference to user document
      try {
        await _firestore.collection('users').doc(effectiveUid).set({
          'phone_number': normalizedPhone,
          'last_login': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (firestoreError) {
        debugPrint("⚠️ Note saving user document: $firestoreError");
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseFunctionsException catch (e) {
      _isLoading = false;
      String cleanError = e.message ?? "Invalid verification code.";
      _errorMessage = cleanError;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      String cleanError = e.toString()
          .replaceAll("Exception: ", "")
          .replaceAll(RegExp(r'\[.*?\]'), "")
          .trim();
      _errorMessage = cleanError;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
