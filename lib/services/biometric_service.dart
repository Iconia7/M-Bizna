import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      if (!canAuthenticate) {
        // Device has no security at all (No PIN, No Fingerprint)
        return true; 
      }

      return await _auth.authenticate(
        localizedReason: 'Scan fingerprint or enter device PIN to continue',
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint("BiometricService.authenticate error: $e");
      return false;
    }
  }
}
