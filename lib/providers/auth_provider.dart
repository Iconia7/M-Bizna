import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duka_manager/services/sms_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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

  /// Start Phone Verification via Africa's Talking REST API (Direct In-App)
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

    try {
      // 1. Google Play Reviewer / Testing bypass (Never hits Africa's Talking)
      if (normalizedPhone == '+254117814250' || normalizedPhone == '+16505551234') {
        await _firestore.collection('phone_verifications').doc(normalizedPhone).set({
          'code': '123456',
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
          'attempts': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _isLoading = false;
        notifyListeners();
        onCodeSent("123456");
        return;
      }

      // 2. Strict 24-Hour Rate Limiter & 60-second cooldown check
      final rateLimitRef = _firestore.collection('otp_rate_limits').doc(normalizedPhone);
      final rateLimitDoc = await rateLimitRef.get();
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(hours: 24));
      List<Timestamp> recentAttemptTimestamps = [];

      if (rateLimitDoc.exists) {
        final data = rateLimitDoc.data() ?? {};
        final Timestamp? lastAttemptTs = data['lastAttemptAt'];

        // Cooldown check: 60 seconds minimum between consecutive requests
        if (lastAttemptTs != null) {
          final diffSeconds = now.difference(lastAttemptTs.toDate()).inSeconds;
          if (diffSeconds < 60) {
            final waitSec = 60 - diffSeconds;
            throw Exception("Please wait $waitSec second${waitSec == 1 ? '' : 's'} before requesting another verification code.");
          }
        }

        // Rolling 24-hour window limit
        final List<dynamic> rawAttempts = data['attempts'] ?? [];
        recentAttemptTimestamps = rawAttempts
            .whereType<Timestamp>()
            .where((ts) => ts.toDate().isAfter(oneDayAgo))
            .toList();

        const int maxOtpPer24h = 3;
        if (recentAttemptTimestamps.length >= maxOtpPer24h) {
          recentAttemptTimestamps.sort((a, b) => a.compareTo(b));
          final oldest = recentAttemptTimestamps.first.toDate();
          final resetTime = oldest.add(const Duration(hours: 24));
          final hoursLeft = (resetTime.difference(now).inMinutes / 60.0).ceil();
          throw Exception("Daily limit reached: Maximum $maxOtpPer24h verification codes allowed per 24 hours. Please try again in ${hoursLeft <= 1 ? '1 hour' : '$hoursLeft hours'}.");
        }
      }

      // 3. Generate secure 6-digit OTP
      final otp = (Random().nextInt(900000) + 100000).toString();

      // 4. Save to Firestore (10 min expiry)
      await _firestore.collection('phone_verifications').doc(normalizedPhone).set({
        'code': otp,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
        'attempts': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Update rate limit record
      final nowTs = Timestamp.fromDate(now);
      recentAttemptTimestamps.add(nowTs);
      await rateLimitRef.set({
        'phoneNumber': normalizedPhone,
        'attempts': recentAttemptTimestamps,
        'lastAttemptAt': nowTs,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 6. Send SMS via Africa's Talking API
      await SmsService.sendOtp(phone: normalizedPhone, otp: otp);

      _isLoading = false;
      notifyListeners();
      onCodeSent(otp);
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

  /// Sign In with OTP
  Future<bool> signInWithOTP(String smsCode) async {
    if (_phoneNumber == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final normalizedPhone = _phoneNumber!;
      final docRef = _firestore.collection('phone_verifications').doc(normalizedPhone);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception("No verification code was requested for this number. Please request a new code.");
      }

      final data = doc.data()!;
      final Timestamp? expiresAt = data['expiresAt'];
      final int attempts = data['attempts'] ?? 0;
      final String? expectedCode = data['code'];

      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        await docRef.delete();
        throw Exception("Verification code has expired. Please request a new code.");
      }

      if (attempts >= 5) {
        await docRef.delete();
        throw Exception("Too many incorrect attempts. Please request a new code.");
      }

      if (expectedCode != smsCode.trim()) {
        await docRef.update({'attempts': FieldValue.increment(1)});
        throw Exception("Invalid verification code. Please check and try again.");
      }

      // Valid OTP: delete verification document
      await docRef.delete();

      // Ensure user UID exists for this session
      if (_auth.currentUser == null) {
        try {
          final userCredential = await _auth.signInAnonymously();
          _user = userCredential.user;
        } catch (authError) {
          debugPrint("⚠️ Firebase Auth anonymous sign-in skipped/disabled: $authError");
          // Fallback: Use deterministic phone UID so user is never blocked by disabled auth providers
          _customUid = 'user_${normalizedPhone.replaceAll(RegExp(r"[^0-9]"), "")}';
        }
      } else {
        _user = _auth.currentUser;
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
