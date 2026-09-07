import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PayHeroService {
  final String _callbackUrl = "${dotenv.env['FIREBASE_CALLBACK_URL'] ?? ''}?api_key=${dotenv.env['CALLBACK_API_KEY'] ?? ''}";
  final String _url = "https://backend.payhero.co.ke/api/v2/payments";

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

  /// Initiates M-Pesa STK Push
  /// [externalReference] should be pre-formatted as "TYPE|SHOPID|TIMESTAMP"
  Future<String?> initiateSTKPush({
    required String phoneNumber,
    required double amount,
    required String externalReference,
    required String basicAuth,
    required String channelId,
  }) async {
    // 1. Resolve and normalize basic auth
    String effectiveAuth = basicAuth.trim();
    if (effectiveAuth.isEmpty) {
      effectiveAuth = dotenv.env['PAYHERO_BASIC_AUTH']?.trim() ?? "";
    }
    if (effectiveAuth.startsWith('Basic ')) {
      effectiveAuth = effectiveAuth.substring(6).trim();
    }

    // 2. Resolve and parse channel ID as integer (PayHero requires int)
    int? parsedChannelId = int.tryParse(channelId.trim());
    if (parsedChannelId == null || parsedChannelId == 0) {
      parsedChannelId = int.tryParse(dotenv.env['PAYHERO_CHANNEL_ID']?.trim() ?? "3145") ?? 3145;
    }

    // 3. Normalize phone number
    final cleanPhone = formatPhone(phoneNumber);

    if (effectiveAuth.isEmpty || parsedChannelId == 0) {
      print("❌ ERROR: Missing PayHero Credentials (Auth: $effectiveAuth, Channel: $parsedChannelId)");
      return null;
    }

    try {
      final payload = {
        "amount": amount.ceil(), // PayHero requires Integers
        "phone_number": cleanPhone,
        "channel_id": parsedChannelId, // Must be int
        "provider": "m-pesa",
        "external_reference": externalReference,
        "callback_url": _callbackUrl
      };

      print("PayHero Request: $payload");

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Basic $effectiveAuth"
        },
        body: jsonEncode(payload),
      );

      print("PayHero Response [${response.statusCode}]: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Success condition: success is true and status is QUEUED
        if (data['success'] == true && data['status'] == "QUEUED") {
          return externalReference; // Return the reference for the Firestore listener
        }
      }
      return null;
      
    } catch (e) {
      print("PayHero Error: $e");
      return null;
    }
  }
}