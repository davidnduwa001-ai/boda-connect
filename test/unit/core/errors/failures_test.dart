import 'package:boda_connect/core/errors/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure Classes', () {
    group('NetworkFailure', () {
      test('should create with default message', () {
        const failure = NetworkFailure();
        expect(failure.message, equals('Sem conexão com a internet'));
        expect(failure.code, isNull);
      });

      test('should create with custom message', () {
        const failure = NetworkFailure('Conexão perdida');
        expect(failure.message, equals('Conexão perdida'));
      });

      test('should create with custom message and code', () {
        const failure = NetworkFailure('Conexão perdida', 'NET-001');
        expect(failure.message, equals('Conexão perdida'));
        expect(failure.code, equals('NET-001'));
      });

      test('should be equal to another NetworkFailure with same values', () {
        const failure1 = NetworkFailure('Test', 'CODE-1');
        const failure2 = NetworkFailure('Test', 'CODE-1');
        expect(failure1, equals(failure2));
      });

      test('should not be equal to NetworkFailure with different values', () {
        const failure1 = NetworkFailure('Test1');
        const failure2 = NetworkFailure('Test2');
        expect(failure1, isNot(equals(failure2)));
      });
    });

    group('ServerFailure', () {
      test('should create with default message', () {
        const failure = ServerFailure();
        expect(failure.message, equals('Erro no servidor'));
      });

      test('should create with custom message and code', () {
        const failure = ServerFailure('Servidor indisponível', '500');
        expect(failure.message, equals('Servidor indisponível'));
        expect(failure.code, equals('500'));
      });
    });

    group('AuthFailure', () {
      test('should create with default message', () {
        const failure = AuthFailure();
        expect(failure.message, equals('Erro de autenticação'));
      });
    });

    group('UnauthenticatedFailure', () {
      test('should create with default message', () {
        const failure = UnauthenticatedFailure();
        expect(failure.message, equals('Usuário não autenticado'));
      });

      test('should be a subtype of AuthFailure', () {
        const failure = UnauthenticatedFailure();
        expect(failure, isA<AuthFailure>());
      });
    });

    group('InvalidCredentialsFailure', () {
      test('should create with default message', () {
        const failure = InvalidCredentialsFailure();
        expect(failure.message, equals('Credenciais inválidas'));
      });

      test('should be a subtype of AuthFailure', () {
        const failure = InvalidCredentialsFailure();
        expect(failure, isA<AuthFailure>());
      });
    });

    group('OTPVerificationFailure', () {
      test('should create with default message', () {
        const failure = OTPVerificationFailure();
        expect(failure.message, equals('Código de verificação inválido'));
      });

      test('should be a subtype of AuthFailure', () {
        const failure = OTPVerificationFailure();
        expect(failure, isA<AuthFailure>());
      });
    });

    group('SupplierFailure', () {
      test('should create with default message', () {
        const failure = SupplierFailure();
        expect(failure.message, equals('Erro ao processar fornecedor'));
      });
    });

    group('SupplierNotFoundFailure', () {
      test('should create with default message', () {
        const failure = SupplierNotFoundFailure();
        expect(failure.message, equals('Fornecedor não encontrado'));
      });

      test('should be a subtype of SupplierFailure', () {
        const failure = SupplierNotFoundFailure();
        expect(failure, isA<SupplierFailure>());
      });
    });

    group('BookingFailure', () {
      test('should create with default message', () {
        const failure = BookingFailure();
        expect(failure.message, equals('Erro ao processar reserva'));
      });
    });

    group('BookingConflictFailure', () {
      test('should create with default message', () {
        const failure = BookingConflictFailure();
        expect(failure.message, equals('Conflito de horário na reserva'));
      });

      test('should be a subtype of BookingFailure', () {
        const failure = BookingConflictFailure();
        expect(failure, isA<BookingFailure>());
      });
    });

    group('ChatFailure', () {
      test('should create with default message', () {
        const failure = ChatFailure();
        expect(failure.message, equals('Erro no chat'));
      });
    });

    group('MessageSendFailure', () {
      test('should create with default message', () {
        const failure = MessageSendFailure();
        expect(failure.message, equals('Erro ao enviar mensagem'));
      });

      test('should be a subtype of ChatFailure', () {
        const failure = MessageSendFailure();
        expect(failure, isA<ChatFailure>());
      });
    });

    group('PaymentFailure', () {
      test('should create with default message', () {
        const failure = PaymentFailure();
        expect(failure.message, equals('Erro no pagamento'));
      });
    });

    group('PaymentDeclinedFailure', () {
      test('should create with default message', () {
        const failure = PaymentDeclinedFailure();
        expect(failure.message, equals('Pagamento recusado'));
      });

      test('should be a subtype of PaymentFailure', () {
        const failure = PaymentDeclinedFailure();
        expect(failure, isA<PaymentFailure>());
      });
    });

    group('StorageFailure', () {
      test('should create with default message', () {
        const failure = StorageFailure();
        expect(failure.message, equals('Erro ao processar arquivo'));
      });
    });

    group('FileUploadFailure', () {
      test('should create with default message', () {
        const failure = FileUploadFailure();
        expect(failure.message, equals('Erro ao enviar arquivo'));
      });

      test('should be a subtype of StorageFailure', () {
        const failure = FileUploadFailure();
        expect(failure, isA<StorageFailure>());
      });
    });

    group('Failure Equality', () {
      test('should support equality comparison', () {
        const failure1 = NetworkFailure('Test', 'CODE');
        const failure2 = NetworkFailure('Test', 'CODE');
        const failure3 = NetworkFailure('Different', 'CODE');

        expect(failure1, equals(failure2));
        expect(failure1, isNot(equals(failure3)));
      });

      test('should support props getter', () {
        const failure = ServerFailure('Test message', 'TEST-001');
        expect(failure.props, equals(['Test message', 'TEST-001']));
      });
    });
  });
}
