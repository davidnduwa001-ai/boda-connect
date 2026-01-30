import 'package:boda_connect/core/utils/phone_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneFormatter - Angola', () {
    test('should format Angola phone number correctly', () {
      expect(
        PhoneFormatter.formatPhoneNumberAO('912345678'),
        equals('+244912345678'),
      );
    });

    test('should format phone number starting with 244', () {
      expect(
        PhoneFormatter.formatPhoneNumberAO('244912345678'),
        equals('+244912345678'),
      );
    });

    test('should keep already formatted Angola number', () {
      expect(
        PhoneFormatter.formatPhoneNumberAO('+244912345678'),
        equals('+244912345678'),
      );
    });

    test('should handle phone number with spaces and dashes', () {
      expect(
        PhoneFormatter.formatPhoneNumberAO('912-345-678'),
        equals('+244912345678'),
      );
    });

    test('should handle phone number with parentheses', () {
      expect(
        PhoneFormatter.formatPhoneNumberAO('(912) 345 678'),
        equals('+244912345678'),
      );
    });
  });

  group('PhoneFormatter - Portugal', () {
    test('should format Portugal phone number correctly', () {
      expect(
        PhoneFormatter.formatPhoneNumberPT('912345678'),
        equals('+351912345678'),
      );
    });

    test('should format phone number starting with 351', () {
      expect(
        PhoneFormatter.formatPhoneNumberPT('351912345678'),
        equals('+351912345678'),
      );
    });

    test('should keep already formatted Portugal number', () {
      expect(
        PhoneFormatter.formatPhoneNumberPT('+351912345678'),
        equals('+351912345678'),
      );
    });

    test('should handle phone number with spaces and dashes', () {
      expect(
        PhoneFormatter.formatPhoneNumberPT('912-345-678'),
        equals('+351912345678'),
      );
    });

    test('should handle phone number with parentheses', () {
      expect(
        PhoneFormatter.formatPhoneNumberPT('(912) 345 678'),
        equals('+351912345678'),
      );
    });
  });
}
