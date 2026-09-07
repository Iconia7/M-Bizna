import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SmsService {
  static const String _baseUrl = 'https://api.africastalking.com/version1/messaging';

  /// Normalizes phone number to E.164 (+254XXXXXXXXX)
  /// Returns null if the number is NOT a valid Kenyan mobile number (or reviewer test bypass).
  static String? normalizePhone(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');

    // Check test reviewer bypass number (+16505551234)
    if (cleaned == '16505551234') {
      return '+16505551234';
    }

    // Starts with 0 (e.g. 0712345678 or 0117814250 - 10 digits)
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      cleaned = '254${cleaned.substring(1)}';
    }
    // 9 digits starting with 7 or 1 (e.g. 712345678 or 117814250)
    else if (cleaned.length == 9 && (cleaned.startsWith('7') || cleaned.startsWith('1'))) {
      cleaned = '254$cleaned';
    }

    // Must start with 254 and have 12 digits, with mobile prefix 7 or 1
    if (cleaned.startsWith('254') && cleaned.length == 12) {
      final mobilePrefix = cleaned.substring(3, 4);
      if (mobilePrefix == '7' || mobilePrefix == '1') {
        return '+$cleaned';
      }
    }

    return null; // Reject all non-Kenyan and invalid formats
  }

  /// Checks whether a normalized phone string matches Kenyan mobile format (+254 7XX... or +254 1XX...)
  static bool isValidKenyanMobile(String? phone) {
    if (phone == null) return false;
    return RegExp(r'^\+254[17]\d{8}$').hasMatch(phone);
  }

  /// Sends OTP SMS via Africa's Talking REST API
  static Future<bool> sendOtp({
    required String phone,
    required String otp,
  }) async {
    final String? normalizedPhone = normalizePhone(phone);
    if (normalizedPhone == null || !isValidKenyanMobile(normalizedPhone)) {
      throw Exception("Only Kenyan mobile phone numbers (e.g. 07XXXXXXXX or 01XXXXXXXX) are supported.");
    }

    final String username = dotenv.env['AT_USERNAME']?.trim() ?? 'dita';
    final String senderId = dotenv.env['AT_SENDER_ID']?.trim() ?? 'NexoraKE';
    final String apiKey = dotenv.env['AT_API_KEY']?.trim() ?? '';

    if (apiKey.isEmpty || apiKey == 'YOUR_AFRICAS_TALKING_API_KEY_HERE') {
      debugPrint("❌ ERROR: AT_API_KEY is not configured in assets/.env");
      throw Exception("Africa's Talking API key is not configured in assets/.env.");
    }

    final String message = "Your M-Bizna verification code is $otp. Valid for 10 minutes.";

    debugPrint("📤 Sending SMS to $normalizedPhone via Africa's Talking (Sender: $senderId, User: $username)");

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'apiKey': apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'username': username,
        'to': normalizedPhone,
        'message': message,
        'from': senderId,
      },
    );

    debugPrint("📥 Africa's Talking Response: [${response.statusCode}] ${response.body}");

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final recipients = data['SMSMessageData']?['Recipients'];
      if (recipients is List && recipients.isNotEmpty) {
        final status = recipients[0]['status'];
        if (status == 'Success') {
          return true;
        } else {
          throw Exception("SMS sending status: $status");
        }
      }
      return true;
    } else {
      throw Exception("Failed to send SMS (Status ${response.statusCode}): ${response.body}");
    }
  }
}
