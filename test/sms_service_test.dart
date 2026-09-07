import 'package:flutter_test/flutter_test.dart';
import 'package:duka_manager/services/sms_service.dart';

void main() {
  group('Kenyan Phone Normalization & Validation', () {
    test('Valid Kenyan Mobile Formats', () {
      expect(SmsService.normalizePhone('0712345678'), '+254712345678');
      expect(SmsService.normalizePhone('0117814250'), '+254117814250');
      expect(SmsService.normalizePhone('712345678'), '+254712345678');
      expect(SmsService.normalizePhone('117814250'), '+254117814250');
      expect(SmsService.normalizePhone('254712345678'), '+254712345678');
      expect(SmsService.normalizePhone('+254712345678'), '+254712345678');
      expect(SmsService.normalizePhone('+254 712 345 678'), '+254712345678');
      expect(SmsService.normalizePhone(' +254-712-345-678 '), '+254712345678');
    });

    test('Foreign & Toll Fraud Numbers are Rejected', () {
      // Bangladesh attack numbers from Africa's Talking incident
      expect(SmsService.normalizePhone('+8801760793732'), isNull);
      expect(SmsService.normalizePhone('+8801883877780'), isNull);
      expect(SmsService.normalizePhone('+12025550123'), isNull);
      expect(SmsService.normalizePhone('+447911123456'), isNull);
    });

    test('Invalid Lengths and Landlines are Rejected', () {
      expect(SmsService.normalizePhone('0201234567'), isNull); // Landline
      expect(SmsService.normalizePhone('0812345678'), isNull); // Invalid prefix
      expect(SmsService.normalizePhone('07123'), isNull); // Too short
      expect(SmsService.normalizePhone('071234567890'), isNull); // Too long
    });

    test('Play Store Reviewer Test Bypass', () {
      expect(SmsService.normalizePhone('+16505551234'), '+16505551234');
    });
  });
}
