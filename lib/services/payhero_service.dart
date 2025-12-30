import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PayHeroService {
  final String _callbackUrl = dotenv.env['FIREBASE_CALLBACK_URL'] ?? "";
  final String _url = "https://backend.payhero.co.ke/api/v2/payments";

  /// Initiates M-Pesa STK Push
  /// [externalReference] should be pre-formatted as "TYPE|SHOPID|TIMESTAMP"
  Future<String?> initiateSTKPush({
    required String phoneNumber,
    required double amount,
    required String externalReference, // 👈 Unified parameter
    required String basicAuth,  // 👈 Pass dynamically
    required String channelId, // 👈 Pass dynamically
  }) async {
    if (basicAuth.isEmpty || channelId == 0) {
      print("❌ ERROR: Missing PayHero Credentials in .env file");
      return null;
    }

    try {
      final payload = {
        "amount": amount.ceil(), // PayHero requires Integers
        "phone_number": phoneNumber,
        "channel_id": channelId,
        "provider": "m-pesa",
        "external_reference": externalReference, // 👈 Passed directly
        "callback_url": _callbackUrl
      };

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Basic $basicAuth"
        },
        body: jsonEncode(payload),
      );

      print("PayHero Request: $payload");
      print("PayHero Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Success condition: success is true and status is QUEUED
        if (data['success'] == true && data['status'] == "QUEUED") {
          return externalReference; // ✅ Return the reference for the Firestore listener
        }
      }
      return null;
      
    } catch (e) {
      print("PayHero Error: $e");
      return null;
    }
  }
}