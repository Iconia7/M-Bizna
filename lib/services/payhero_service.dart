import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PayHeroService {
  /// Normalizes Kenyan phone numbers to 07XXXXXXXX or 01XXXXXXXX format
  static String formatPhone(String rawPhone) {
    String phone = rawPhone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
    if (phone.startsWith('254') && phone.length == 12) {
      return '0${phone.substring(3)}';
    } else if ((phone.startsWith('7') || phone.startsWith('1')) && phone.length == 9) {
      return '0$phone';
    }
    return phone;
  }

  /// Initiates M-Pesa STK Push via secure Firebase Cloud Function.
  /// Master credentials are kept exclusively on the server to protect against APK decompilation.
  /// [externalReference] should be pre-formatted as "TYPE|SHOPID|TIMESTAMP"
  Future<String?> initiateSTKPush({
    required String phoneNumber,
    required double amount,
    required String externalReference,
    String? basicAuth,
    String? channelId,
  }) async {
    final cleanPhone = formatPhone(phoneNumber);
    if (cleanPhone.isEmpty || amount <= 0 || externalReference.isEmpty) {
      debugPrint("❌ ERROR: Invalid STK Push parameters (Phone: $cleanPhone, Amount: $amount, Ref: $externalReference)");
      return null;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('initiateStkPush');
      final Map<String, dynamic> params = {
        'phone_number': cleanPhone,
        'amount': amount,
        'external_reference': externalReference,
      };

      if (channelId != null && channelId.trim().isNotEmpty) {
        params['channel_id'] = channelId.trim();
      }
      if (basicAuth != null && basicAuth.trim().isNotEmpty) {
        params['custom_basic_auth'] = basicAuth.trim();
      }

      debugPrint("🚀 Calling initiateStkPush Cloud Function with ref: $externalReference");
      final response = await callable.call(params);

      final data = response.data;
      if (data != null && data['success'] == true) {
        debugPrint("✅ STK Push Queued via Cloud Function: ${data['external_reference'] ?? externalReference}");
        return externalReference;
      }

      debugPrint("⚠️ Cloud Function returned unsuccessful response: $data");
      return null;
    } on FirebaseFunctionsException catch (fe) {
      debugPrint("❌ FirebaseFunctionsException initiateStkPush [${fe.code}]: ${fe.message}");
      return null;
    } catch (e) {
      debugPrint("❌ PayHeroService initiateSTKPush Error: $e");
      return null;
    }
  }
}