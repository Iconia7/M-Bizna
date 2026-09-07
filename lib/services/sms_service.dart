class SmsService {
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
}
