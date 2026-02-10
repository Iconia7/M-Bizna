import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? _user;
  String? _verificationCode;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Start Phone Verification
  Future<void> verifyPhoneNumber(String phoneNumber, {
    required Function(String code) onCodeSent,
    required Function(String error) onError,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (not common on all devices)
          await _auth.signInWithCredential(credential);
          _isLoading = false;
          notifyListeners();
        },
        verificationFailed: (FirebaseAuthException e) {
          _isLoading = false;
          _errorMessage = e.message;
          onError(e.message ?? "Verification failed");
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationCode = verificationId;
          _isLoading = false;
          onCodeSent(verificationId);
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationCode = verificationId;
        },
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      onError(e.toString());
      notifyListeners();
    }
  }

  /// Sign In with OTP
  Future<bool> signInWithOTP(String smsCode) async {
    if (_verificationCode == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationCode!,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
