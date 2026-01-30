import 'package:dartz/dartz.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/data/datasources/booking_remote_datasource.dart';
import 'package:boda_connect/features/booking/data/models/booking_model.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// Implementation of BookingRepository using remote data source
class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl({required BookingRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final BookingRemoteDataSource _remoteDataSource;

  @override
  ResultFuture<BookingEntity> createBooking(BookingEntity booking) async {
    try {
      // Convert entity to model
      final bookingModel = BookingModel.fromEntity(booking);

      // Create booking in Firestore
      final result = await _remoteDataSource.createBooking(bookingModel);

      return Right(result.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<BookingEntity> getBookingById(String bookingId) async {
    try {
      final result = await _remoteDataSource.getBookingById(bookingId);
      return Right(result.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      // Check if the error message indicates booking not found
      if (e.toString().contains('not found')) {
        return const Left(BookingNotFoundFailure());
      }
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<List<BookingEntity>> getClientBookings(
    String clientId, {
    BookingStatus? status,
  }) async {
    try {
      final results = await _remoteDataSource.getClientBookings(
        clientId,
        status: status,
      );

      return Right(results.map((model) => model.toEntity()).toList());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<List<BookingEntity>> getSupplierBookings(
    String supplierId, {
    BookingStatus? status,
  }) async {
    try {
      final results = await _remoteDataSource.getSupplierBookings(
        supplierId,
        status: status,
      );

      return Right(results.map((model) => model.toEntity()).toList());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<BookingEntity> updateBookingStatus({
    required String bookingId,
    required BookingStatus newStatus,
    required String userId,
  }) async {
    try {
      final result = await _remoteDataSource.updateBookingStatus(
        bookingId: bookingId,
        newStatus: newStatus,
        userId: userId,
      );

      return Right(result.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(BookingNotFoundFailure());
      }
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<BookingEntity> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    String? reason,
  }) async {
    try {
      final result = await _remoteDataSource.cancelBooking(
        bookingId: bookingId,
        cancelledBy: cancelledBy,
        reason: reason,
      );

      return Right(result.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(BookingNotFoundFailure());
      }
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<bool> checkAvailability({
    required String supplierId,
    required DateTime date,
    String? excludeBookingId,
  }) async {
    try {
      final isAvailable = await _remoteDataSource.checkAvailability(
        supplierId: supplierId,
        date: date,
        excludeBookingId: excludeBookingId,
      );

      return Right(isAvailable);
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<BookingEntity> updateBooking({
    required String bookingId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final result = await _remoteDataSource.updateBooking(
        bookingId: bookingId,
        updates: updates,
      );

      return Right(result.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(BookingNotFoundFailure());
      }
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  ResultFuture<BookingEntity> addPayment({
    required String bookingId,
    required BookingPaymentEntity payment,
  }) async {
    try {
      final result = await _remoteDataSource.addPayment(
        bookingId: bookingId,
        payment: payment,
      );

      return Right(result.toEntity());
    } on FirebaseException catch (e) {
      return Left(_handleFirebaseException(e));
    } catch (e) {
      if (e.toString().contains('not found')) {
        return const Left(BookingNotFoundFailure());
      }
      return Left(BookingFailure(e.toString()));
    }
  }

  @override
  Stream<List<BookingEntity>> streamClientBookings(String clientId) {
    try {
      return _remoteDataSource.streamClientBookings(clientId).map(
            (models) => models.map((model) => model.toEntity()).toList(),
          );
    } catch (e) {
      return Stream.error(BookingFailure(e.toString()));
    }
  }

  @override
  Stream<List<BookingEntity>> streamSupplierBookings(String supplierId) {
    try {
      return _remoteDataSource.streamSupplierBookings(supplierId).map(
            (models) => models.map((model) => model.toEntity()).toList(),
          );
    } catch (e) {
      return Stream.error(BookingFailure(e.toString()));
    }
  }

  @override
  Stream<BookingEntity?> streamBooking(String bookingId) {
    try {
      return _remoteDataSource.streamBooking(bookingId).map(
            (model) => model?.toEntity(),
          );
    } catch (e) {
      return Stream.error(BookingFailure(e.toString()));
    }
  }

  /// Helper method to handle Firebase exceptions and convert them to appropriate Failures
  Failure _handleFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const PermissionFailure('Sem permissão para acessar esta reserva');
      case 'not-found':
        return const BookingNotFoundFailure();
      case 'already-exists':
        return const BookingConflictFailure('Esta reserva já existe');
      case 'unavailable':
        return const SupplierUnavailableFailure('Serviço temporariamente indisponível');
      case 'aborted':
        return const BookingFailure('Operação cancelada. Tente novamente');
      case 'deadline-exceeded':
        return const BookingFailure('Tempo limite excedido. Tente novamente');
      case 'resource-exhausted':
        return const BookingFailure('Limite de recursos excedido. Tente mais tarde');
      case 'unauthenticated':
        return const UnauthenticatedFailure();
      case 'cancelled':
        return const BookingFailure('Operação cancelada');
      case 'data-loss':
        return const BookingFailure('Perda de dados detectada');
      case 'failed-precondition':
        return const BookingFailure('Pré-condição da operação falhou');
      case 'internal':
        return const ServerFailure('Erro interno do servidor');
      case 'invalid-argument':
        return const ValidationFailure('Dados inválidos fornecidos');
      case 'out-of-range':
        return const ValidationFailure('Valor fora do intervalo permitido');
      case 'unimplemented':
        return const BookingFailure('Operação não implementada');
      default:
        return BookingFailure(e.message ?? 'Erro desconhecido ao processar reserva');
    }
  }
}
