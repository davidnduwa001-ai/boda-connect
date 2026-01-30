import 'package:boda_connect/core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthException', () {
    test('should create exception from Firebase with invalid phone', () {
      final firebaseException = FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'The phone number is invalid',
      );

      final authException = AuthException.fromFirebase(firebaseException);

      expect(authException.code, equals('invalid-phone-number'));
      expect(authException.message, equals('Número de telefone inválido'));
    });

    test('should create exception from Firebase with too many requests', () {
      final firebaseException = FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many attempts',
      );

      final authException = AuthException.fromFirebase(firebaseException);

      expect(authException.code, equals('too-many-requests'));
      expect(
        authException.message,
        equals('Muitas tentativas. Tente novamente mais tarde.'),
      );
    });

    test('should create exception from Firebase with invalid code', () {
      final firebaseException = FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'Invalid code',
      );

      final authException = AuthException.fromFirebase(firebaseException);

      expect(authException.code, equals('invalid-verification-code'));
      expect(authException.message, equals('Código de verificação inválido'));
    });

    test('should create exception for session expired', () {
      final firebaseException = FirebaseAuthException(
        code: 'session-expired',
        message: 'Session expired',
      );

      final authException = AuthException.fromFirebase(firebaseException);

      expect(authException.code, equals('session-expired'));
      expect(
        authException.message,
        equals('Sessão expirada. Solicite um novo código.'),
      );
    });

    test('should create exception for quota exceeded', () {
      final firebaseException = FirebaseAuthException(
        code: 'quota-exceeded',
        message: 'Quota exceeded',
      );

      final authException = AuthException.fromFirebase(firebaseException);

      expect(authException.code, equals('quota-exceeded'));
      expect(
        authException.message,
        equals('Limite de SMS excedido. Tente novamente mais tarde.'),
      );
    });

    test('should handle unknown error codes', () {
      final firebaseException = FirebaseAuthException(
        code: 'unknown-error',
        message: 'Some unknown error',
      );

      final authException = AuthException.fromFirebase(firebaseException);

      expect(authException.code, equals('unknown-error'));
      expect(authException.message, equals('Some unknown error'));
    });

    test('should handle null message from Firebase', () {
      final firebaseException = FirebaseAuthException(
        code: 'unknown-error',
      );

      final authException = AuthException.fromFirebase(firebaseException);

      expect(authException.code, equals('unknown-error'));
      expect(authException.message, equals('Erro de autenticação'));
    });

    test('toString should return message', () {
      final exception = AuthException('test-code', 'Test message');
      expect(exception.toString(), equals('Test message'));
    });

    test('should create exception with direct constructor', () {
      final exception = AuthException('custom-code', 'Custom message');
      expect(exception.code, equals('custom-code'));
      expect(exception.message, equals('Custom message'));
    });
  });
}
