import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    if (!canAuthenticate) {
        // Device has no security at all (No PIN, No Fingerprint)
        // For a business app, we might allow entry but warn them, 
        // or just return true since we can't force a lock.
        return true; 
      }

    try {
      return await _auth.authenticate(
        localizedReason: 'Scan fingerprint to access confidential data',
        biometricOnly: false,
      );
    } on PlatformException {
      return false;
    }
  }
}
