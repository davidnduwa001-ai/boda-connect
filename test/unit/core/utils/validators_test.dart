import 'package:boda_connect/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    group('isValidPhone', () {
      test('should return true for valid Angola phone number', () {
        expect(Validators.isValidPhone('912345678'), isTrue);
      });

      test('should return true for valid phone with spaces', () {
        expect(Validators.isValidPhone('912 345 678'), isTrue);
      });

      test('should return true for international format', () {
        expect(Validators.isValidPhone('+244912345678'), isTrue);
      });

      test('should return false for phone number too short', () {
        expect(Validators.isValidPhone('12345'), isFalse);
      });

      test('should return false for empty string', () {
        expect(Validators.isValidPhone(''), isFalse);
      });

      test('should handle phone with country code', () {
        expect(Validators.isValidPhone('244912345678'), isTrue);
      });
    });
  });
}
