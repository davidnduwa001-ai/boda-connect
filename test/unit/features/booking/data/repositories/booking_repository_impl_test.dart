import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/features/booking/data/datasources/booking_remote_datasource.dart';
import 'package:boda_connect/features/booking/data/models/booking_model.dart';
import 'package:boda_connect/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';

// Mock classes
class MockBookingRemoteDataSource extends Mock implements BookingRemoteDataSource {}

void main() {
  late BookingRepositoryImpl repository;
  late MockBookingRemoteDataSource mockDataSource;
  late DateTime testEventDate;
  late DateTime testCreatedAt;
  late DateTime testUpdatedAt;

  setUp(() {
    mockDataSource = MockBookingRemoteDataSource();
    repository = BookingRepositoryImpl(remoteDataSource: mockDataSource);
    testEventDate = DateTime(2025, 6, 15, 14, 0);
    testCreatedAt = DateTime(2025, 1, 10, 9, 30);
    testUpdatedAt = DateTime(2025, 1, 11, 10, 0);
  });

  // Helper to create test booking entity
  BookingEntity createTestBookingEntity({
    String id = 'booking-123',
    BookingStatus status = BookingStatus.pending,
    int paidAmount = 0,
  }) {
    return BookingEntity(
      id: id,
      clientId: 'client-123',
      supplierId: 'supplier-456',
      packageId: 'package-789',
      packageName: 'Premium Package',
      eventName: 'Wedding Celebration',
      eventType: 'wedding',
      eventDate: testEventDate,
      eventTime: '14:00',
      eventLocation: 'Luanda Beach Resort',
      status: status,
      totalAmount: 150000,
      paidAmount: paidAmount,
      currency: 'AOA',
      createdAt: testCreatedAt,
      updatedAt: testUpdatedAt,
    );
  }

  // Helper to create test booking model
  BookingModel createTestBookingModel({
    String id = 'booking-123',
    BookingStatus status = BookingStatus.pending,
    int paidAmount = 0,
  }) {
    return BookingModel(
      id: id,
      clientId: 'client-123',
      supplierId: 'supplier-456',
      packageId: 'package-789',
      packageName: 'Premium Package',
      eventName: 'Wedding Celebration',
      eventType: 'wedding',
      eventDate: testEventDate,
      eventTime: '14:00',
      eventLocation: 'Luanda Beach Resort',
      status: status,
      totalAmount: 150000,
      paidAmount: paidAmount,
      currency: 'AOA',
      createdAt: testCreatedAt,
      updatedAt: testUpdatedAt,
    );
  }

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(BookingModel(
      id: 'booking-123',
      clientId: 'client-123',
      supplierId: 'supplier-456',
      packageId: 'package-789',
      eventName: 'Test Event',
      eventDate: DateTime(2025, 6, 15),
      totalAmount: 100000,
      createdAt: DateTime(2025, 1, 10),
      updatedAt: DateTime(2025, 1, 10),
    ));
    registerFallbackValue(BookingPaymentEntity(
      id: 'payment-123',
      amount: 50000,
      method: 'transfer',
      paidAt: DateTime(2025, 1, 10),
    ));
  });

  group('BookingRepositoryImpl', () {
    group('createBooking', () {
      test('should return Right with BookingEntity when creation succeeds', () async {
        // Arrange
        final entity = createTestBookingEntity();
        final model = createTestBookingModel();

        when(() => mockDataSource.createBooking(any())).thenAnswer((_) async => model);

        // Act
        final result = await repository.createBooking(entity);

        // Assert
        expect(result, isA<Right<Failure, BookingEntity>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (booking) {
            expect(booking.id, entity.id);
            expect(booking.clientId, entity.clientId);
            expect(booking.supplierId, entity.supplierId);
            expect(booking.totalAmount, entity.totalAmount);
          },
        );
        verify(() => mockDataSource.createBooking(any())).called(1);
      });

      test('should convert entity to model before calling data source', () async {
        // Arrange
        final entity = createTestBookingEntity();
        final model = createTestBookingModel();

        when(() => mockDataSource.createBooking(any())).thenAnswer((_) async => model);

        // Act
        await repository.createBooking(entity);

        // Assert
        final captured = verify(() => mockDataSource.createBooking(captureAny())).captured;
        expect(captured.first, isA<BookingModel>());
        final capturedModel = captured.first as BookingModel;
        expect(capturedModel.id, entity.id);
        expect(capturedModel.clientId, entity.clientId);
      });

      test('should return Left with BookingFailure when FirebaseException occurs', () async {
        // Arrange
        final entity = createTestBookingEntity();

        when(() => mockDataSource.createBooking(any())).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'unavailable',
            message: 'Service unavailable',
          ),
        );

        // Act
        final result = await repository.createBooking(entity);

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<SupplierUnavailableFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });

      test('should return Left with BookingFailure when generic exception occurs', () async {
        // Arrange
        final entity = createTestBookingEntity();

        when(() => mockDataSource.createBooking(any())).thenThrow(
          Exception('Network error'),
        );

        // Act
        final result = await repository.createBooking(entity);

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingFailure>());
            expect(failure.message, contains('Network error'));
          },
          (booking) => fail('Should not return booking'),
        );
      });
    });

    group('getBookingById', () {
      test('should return Right with BookingEntity when booking is found', () async {
        // Arrange
        final model = createTestBookingModel();

        when(() => mockDataSource.getBookingById('booking-123'))
            .thenAnswer((_) async => model);

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        expect(result, isA<Right<Failure, BookingEntity>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (booking) {
            expect(booking.id, 'booking-123');
            expect(booking.clientId, 'client-123');
          },
        );
        verify(() => mockDataSource.getBookingById('booking-123')).called(1);
      });

      test('should return Left with BookingNotFoundFailure when booking not found', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('invalid-id'))
            .thenThrow(Exception('Booking not found'));

        // Act
        final result = await repository.getBookingById('invalid-id');

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingNotFoundFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });

      test('should return Left with appropriate Failure for FirebaseException', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('booking-123')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<PermissionFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });
    });

    group('getClientBookings', () {
      test('should return Right with list of BookingEntity when successful', () async {
        // Arrange
        final models = [
          createTestBookingModel(id: 'booking-1'),
          createTestBookingModel(id: 'booking-2'),
          createTestBookingModel(id: 'booking-3'),
        ];

        when(() => mockDataSource.getClientBookings('client-123', status: null))
            .thenAnswer((_) async => models);

        // Act
        final result = await repository.getClientBookings('client-123');

        // Assert
        expect(result, isA<Right<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (bookings) {
            expect(bookings.length, 3);
            expect(bookings[0].id, 'booking-1');
            expect(bookings[1].id, 'booking-2');
            expect(bookings[2].id, 'booking-3');
          },
        );
        verify(() => mockDataSource.getClientBookings('client-123', status: null)).called(1);
      });

      test('should filter by status when status parameter is provided', () async {
        // Arrange
        final models = [
          createTestBookingModel(id: 'booking-1', status: BookingStatus.confirmed),
          createTestBookingModel(id: 'booking-2', status: BookingStatus.confirmed),
        ];

        when(() => mockDataSource.getClientBookings('client-123', status: BookingStatus.confirmed))
            .thenAnswer((_) async => models);

        // Act
        final result = await repository.getClientBookings('client-123', status: BookingStatus.confirmed);

        // Assert
        expect(result, isA<Right<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (bookings) {
            expect(bookings.length, 2);
            expect(bookings.every((b) => b.status == BookingStatus.confirmed), true);
          },
        );
        verify(() => mockDataSource.getClientBookings('client-123', status: BookingStatus.confirmed)).called(1);
      });

      test('should return empty list when no bookings found', () async {
        // Arrange
        when(() => mockDataSource.getClientBookings('client-456', status: null))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.getClientBookings('client-456');

        // Assert
        expect(result, isA<Right<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (bookings) {
            expect(bookings, isEmpty);
          },
        );
      });

      test('should return Left with BookingFailure when FirebaseException occurs', () async {
        // Arrange
        when(() => mockDataSource.getClientBookings('client-123', status: null)).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'unavailable',
            message: 'Service unavailable',
          ),
        );

        // Act
        final result = await repository.getClientBookings('client-123');

        // Assert
        expect(result, isA<Left<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) {
            expect(failure, isA<SupplierUnavailableFailure>());
          },
          (bookings) => fail('Should not return bookings'),
        );
      });

      test('should return Left with BookingFailure when generic exception occurs', () async {
        // Arrange
        when(() => mockDataSource.getClientBookings('client-123', status: null))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await repository.getClientBookings('client-123');

        // Assert
        expect(result, isA<Left<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingFailure>());
          },
          (bookings) => fail('Should not return bookings'),
        );
      });
    });

    group('getSupplierBookings', () {
      test('should return Right with list of BookingEntity when successful', () async {
        // Arrange
        final models = [
          createTestBookingModel(id: 'booking-1'),
          createTestBookingModel(id: 'booking-2'),
        ];

        when(() => mockDataSource.getSupplierBookings('supplier-456', status: null))
            .thenAnswer((_) async => models);

        // Act
        final result = await repository.getSupplierBookings('supplier-456');

        // Assert
        expect(result, isA<Right<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (bookings) {
            expect(bookings.length, 2);
            expect(bookings[0].supplierId, 'supplier-456');
            expect(bookings[1].supplierId, 'supplier-456');
          },
        );
        verify(() => mockDataSource.getSupplierBookings('supplier-456', status: null)).called(1);
      });

      test('should filter by status when status parameter is provided', () async {
        // Arrange
        final models = [
          createTestBookingModel(id: 'booking-1', status: BookingStatus.pending),
        ];

        when(() => mockDataSource.getSupplierBookings('supplier-456', status: BookingStatus.pending))
            .thenAnswer((_) async => models);

        // Act
        final result = await repository.getSupplierBookings('supplier-456', status: BookingStatus.pending);

        // Assert
        expect(result, isA<Right<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (bookings) {
            expect(bookings.length, 1);
            expect(bookings[0].status, BookingStatus.pending);
          },
        );
      });

      test('should return Left with BookingFailure when exception occurs', () async {
        // Arrange
        when(() => mockDataSource.getSupplierBookings('supplier-456', status: null))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await repository.getSupplierBookings('supplier-456');

        // Assert
        expect(result, isA<Left<Failure, List<BookingEntity>>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingFailure>());
          },
          (bookings) => fail('Should not return bookings'),
        );
      });
    });

    group('updateBookingStatus', () {
      test('should return Right with updated BookingEntity when successful', () async {
        // Arrange
        final updatedModel = createTestBookingModel(
          status: BookingStatus.confirmed,
        );

        when(() => mockDataSource.updateBookingStatus(
              bookingId: 'booking-123',
              newStatus: BookingStatus.confirmed,
              userId: 'supplier-456',
            )).thenAnswer((_) async => updatedModel);

        // Act
        final result = await repository.updateBookingStatus(
          bookingId: 'booking-123',
          newStatus: BookingStatus.confirmed,
          userId: 'supplier-456',
        );

        // Assert
        expect(result, isA<Right<Failure, BookingEntity>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (booking) {
            expect(booking.status, BookingStatus.confirmed);
          },
        );
        verify(() => mockDataSource.updateBookingStatus(
              bookingId: 'booking-123',
              newStatus: BookingStatus.confirmed,
              userId: 'supplier-456',
            )).called(1);
      });

      test('should return Left with BookingNotFoundFailure when booking not found', () async {
        // Arrange
        when(() => mockDataSource.updateBookingStatus(
              bookingId: 'invalid-id',
              newStatus: BookingStatus.confirmed,
              userId: 'supplier-456',
            )).thenThrow(Exception('Booking not found'));

        // Act
        final result = await repository.updateBookingStatus(
          bookingId: 'invalid-id',
          newStatus: BookingStatus.confirmed,
          userId: 'supplier-456',
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingNotFoundFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });

      test('should return Left with appropriate Failure for FirebaseException', () async {
        // Arrange
        when(() => mockDataSource.updateBookingStatus(
              bookingId: 'booking-123',
              newStatus: BookingStatus.confirmed,
              userId: 'supplier-456',
            )).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // Act
        final result = await repository.updateBookingStatus(
          bookingId: 'booking-123',
          newStatus: BookingStatus.confirmed,
          userId: 'supplier-456',
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<PermissionFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });
    });

    group('cancelBooking', () {
      test('should return Right with cancelled BookingEntity when successful', () async {
        // Arrange
        final cancelledModel = createTestBookingModel(
          status: BookingStatus.cancelled,
        );

        when(() => mockDataSource.cancelBooking(
              bookingId: 'booking-123',
              cancelledBy: 'client-123',
              reason: 'Changed plans',
            )).thenAnswer((_) async => cancelledModel);

        // Act
        final result = await repository.cancelBooking(
          bookingId: 'booking-123',
          cancelledBy: 'client-123',
          reason: 'Changed plans',
        );

        // Assert
        expect(result, isA<Right<Failure, BookingEntity>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (booking) {
            expect(booking.status, BookingStatus.cancelled);
          },
        );
        verify(() => mockDataSource.cancelBooking(
              bookingId: 'booking-123',
              cancelledBy: 'client-123',
              reason: 'Changed plans',
            )).called(1);
      });

      test('should work without reason parameter', () async {
        // Arrange
        final cancelledModel = createTestBookingModel(
          status: BookingStatus.cancelled,
        );

        when(() => mockDataSource.cancelBooking(
              bookingId: 'booking-123',
              cancelledBy: 'client-123',
              reason: null,
            )).thenAnswer((_) async => cancelledModel);

        // Act
        final result = await repository.cancelBooking(
          bookingId: 'booking-123',
          cancelledBy: 'client-123',
        );

        // Assert
        expect(result, isA<Right<Failure, BookingEntity>>());
        verify(() => mockDataSource.cancelBooking(
              bookingId: 'booking-123',
              cancelledBy: 'client-123',
              reason: null,
            )).called(1);
      });

      test('should return Left with BookingNotFoundFailure when booking not found', () async {
        // Arrange
        when(() => mockDataSource.cancelBooking(
              bookingId: 'invalid-id',
              cancelledBy: 'client-123',
              reason: null,
            )).thenThrow(Exception('Booking not found'));

        // Act
        final result = await repository.cancelBooking(
          bookingId: 'invalid-id',
          cancelledBy: 'client-123',
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingNotFoundFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });

      test('should return Left with BookingFailure when FirebaseException occurs', () async {
        // Arrange
        when(() => mockDataSource.cancelBooking(
              bookingId: 'booking-123',
              cancelledBy: 'client-123',
              reason: null,
            )).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'unavailable',
            message: 'Service unavailable',
          ),
        );

        // Act
        final result = await repository.cancelBooking(
          bookingId: 'booking-123',
          cancelledBy: 'client-123',
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<SupplierUnavailableFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });
    });

    group('checkAvailability', () {
      test('should return Right with true when supplier is available', () async {
        // Arrange
        when(() => mockDataSource.checkAvailability(
              supplierId: 'supplier-456',
              date: testEventDate,
              excludeBookingId: null,
            )).thenAnswer((_) async => true);

        // Act
        final result = await repository.checkAvailability(
          supplierId: 'supplier-456',
          date: testEventDate,
        );

        // Assert
        expect(result, isA<Right<Failure, bool>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (isAvailable) {
            expect(isAvailable, true);
          },
        );
        verify(() => mockDataSource.checkAvailability(
              supplierId: 'supplier-456',
              date: testEventDate,
              excludeBookingId: null,
            )).called(1);
      });

      test('should return Right with false when supplier is not available', () async {
        // Arrange
        when(() => mockDataSource.checkAvailability(
              supplierId: 'supplier-456',
              date: testEventDate,
              excludeBookingId: null,
            )).thenAnswer((_) async => false);

        // Act
        final result = await repository.checkAvailability(
          supplierId: 'supplier-456',
          date: testEventDate,
        );

        // Assert
        expect(result, isA<Right<Failure, bool>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (isAvailable) {
            expect(isAvailable, false);
          },
        );
      });

      test('should exclude specified booking when checking availability', () async {
        // Arrange
        when(() => mockDataSource.checkAvailability(
              supplierId: 'supplier-456',
              date: testEventDate,
              excludeBookingId: 'booking-123',
            )).thenAnswer((_) async => true);

        // Act
        final result = await repository.checkAvailability(
          supplierId: 'supplier-456',
          date: testEventDate,
          excludeBookingId: 'booking-123',
        );

        // Assert
        expect(result, isA<Right<Failure, bool>>());
        verify(() => mockDataSource.checkAvailability(
              supplierId: 'supplier-456',
              date: testEventDate,
              excludeBookingId: 'booking-123',
            )).called(1);
      });

      test('should return Left with BookingFailure when exception occurs', () async {
        // Arrange
        when(() => mockDataSource.checkAvailability(
              supplierId: 'supplier-456',
              date: testEventDate,
              excludeBookingId: null,
            )).thenThrow(Exception('Database error'));

        // Act
        final result = await repository.checkAvailability(
          supplierId: 'supplier-456',
          date: testEventDate,
        );

        // Assert
        expect(result, isA<Left<Failure, bool>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingFailure>());
          },
          (isAvailable) => fail('Should not return availability'),
        );
      });
    });

    group('updateBooking', () {
      test('should return Right with updated BookingEntity when successful', () async {
        // Arrange
        final updates = {'eventTime': '15:00', 'guestCount': 120};
        final updatedModel = createTestBookingModel();

        when(() => mockDataSource.updateBooking(
              bookingId: 'booking-123',
              updates: updates,
            )).thenAnswer((_) async => updatedModel);

        // Act
        final result = await repository.updateBooking(
          bookingId: 'booking-123',
          updates: updates,
        );

        // Assert
        expect(result, isA<Right<Failure, BookingEntity>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (booking) {
            expect(booking.id, 'booking-123');
          },
        );
        verify(() => mockDataSource.updateBooking(
              bookingId: 'booking-123',
              updates: updates,
            )).called(1);
      });

      test('should return Left with BookingNotFoundFailure when booking not found', () async {
        // Arrange
        final updates = {'eventTime': '15:00'};

        when(() => mockDataSource.updateBooking(
              bookingId: 'invalid-id',
              updates: updates,
            )).thenThrow(Exception('Booking not found'));

        // Act
        final result = await repository.updateBooking(
          bookingId: 'invalid-id',
          updates: updates,
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingNotFoundFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });

      test('should return Left with appropriate Failure for FirebaseException', () async {
        // Arrange
        final updates = {'eventTime': '15:00'};

        when(() => mockDataSource.updateBooking(
              bookingId: 'booking-123',
              updates: updates,
            )).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'invalid-argument',
            message: 'Invalid argument',
          ),
        );

        // Act
        final result = await repository.updateBooking(
          bookingId: 'booking-123',
          updates: updates,
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });
    });

    group('addPayment', () {
      test('should return Right with updated BookingEntity when payment added', () async {
        // Arrange
        final payment = BookingPaymentEntity(
          id: 'payment-123',
          amount: 50000,
          method: 'transfer',
          reference: 'TRX123456',
          paidAt: DateTime.now(),
          notes: 'First payment',
        );

        final updatedModel = createTestBookingModel(paidAmount: 50000);

        when(() => mockDataSource.addPayment(
              bookingId: 'booking-123',
              payment: payment,
            )).thenAnswer((_) async => updatedModel);

        // Act
        final result = await repository.addPayment(
          bookingId: 'booking-123',
          payment: payment,
        );

        // Assert
        expect(result, isA<Right<Failure, BookingEntity>>());
        result.fold(
          (failure) => fail('Should not return failure'),
          (booking) {
            expect(booking.paidAmount, 50000);
          },
        );
        verify(() => mockDataSource.addPayment(
              bookingId: 'booking-123',
              payment: payment,
            )).called(1);
      });

      test('should return Left with BookingNotFoundFailure when booking not found', () async {
        // Arrange
        final payment = BookingPaymentEntity(
          id: 'payment-123',
          amount: 50000,
          method: 'transfer',
          paidAt: DateTime.now(),
        );

        when(() => mockDataSource.addPayment(
              bookingId: 'invalid-id',
              payment: payment,
            )).thenThrow(Exception('Booking not found'));

        // Act
        final result = await repository.addPayment(
          bookingId: 'invalid-id',
          payment: payment,
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingNotFoundFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });

      test('should return Left with BookingFailure when FirebaseException occurs', () async {
        // Arrange
        final payment = BookingPaymentEntity(
          id: 'payment-123',
          amount: 50000,
          method: 'transfer',
          paidAt: DateTime.now(),
        );

        when(() => mockDataSource.addPayment(
              bookingId: 'booking-123',
              payment: payment,
            )).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'aborted',
            message: 'Transaction aborted',
          ),
        );

        // Act
        final result = await repository.addPayment(
          bookingId: 'booking-123',
          payment: payment,
        );

        // Assert
        expect(result, isA<Left<Failure, BookingEntity>>());
        result.fold(
          (failure) {
            expect(failure, isA<BookingFailure>());
          },
          (booking) => fail('Should not return booking'),
        );
      });
    });

    group('streamClientBookings', () {
      test('should return stream of BookingEntity list when successful', () async {
        // Arrange
        final models = [
          createTestBookingModel(id: 'booking-1'),
          createTestBookingModel(id: 'booking-2'),
        ];

        when(() => mockDataSource.streamClientBookings('client-123'))
            .thenAnswer((_) => Stream.value(models));

        // Act
        final stream = repository.streamClientBookings('client-123');
        final bookings = await stream.first;

        // Assert
        expect(bookings, isA<List<BookingEntity>>());
        expect(bookings.length, 2);
        expect(bookings[0].id, 'booking-1');
        expect(bookings[1].id, 'booking-2');
        verify(() => mockDataSource.streamClientBookings('client-123')).called(1);
      });

      test('should convert models to entities in stream', () async {
        // Arrange
        final models = [createTestBookingModel(id: 'booking-123')];

        when(() => mockDataSource.streamClientBookings('client-123'))
            .thenAnswer((_) => Stream.value(models));

        // Act
        final stream = repository.streamClientBookings('client-123');
        final bookings = await stream.first;

        // Assert
        expect(bookings.first, isA<BookingEntity>());
        expect(bookings.first.id, 'booking-123');
      });

      test('should emit error when data source throws exception', () async {
        // Arrange
        when(() => mockDataSource.streamClientBookings('client-123'))
            .thenAnswer((_) => Stream.error(Exception('Stream error')));

        // Act
        final stream = repository.streamClientBookings('client-123');

        // Assert
        expect(stream, emitsError(isA<Exception>()));
      });

      test('should return stream error as BookingFailure when catch block triggers', () async {
        // Arrange - This simulates the catch block in the repository
        when(() => mockDataSource.streamClientBookings('client-123'))
            .thenThrow(Exception('Initialization error'));

        // Act
        final stream = repository.streamClientBookings('client-123');

        // Assert
        expect(stream, emitsError(isA<BookingFailure>()));
      });
    });

    group('streamSupplierBookings', () {
      test('should return stream of BookingEntity list when successful', () async {
        // Arrange
        final models = [
          createTestBookingModel(id: 'booking-1'),
          createTestBookingModel(id: 'booking-2'),
          createTestBookingModel(id: 'booking-3'),
        ];

        when(() => mockDataSource.streamSupplierBookings('supplier-456'))
            .thenAnswer((_) => Stream.value(models));

        // Act
        final stream = repository.streamSupplierBookings('supplier-456');
        final bookings = await stream.first;

        // Assert
        expect(bookings, isA<List<BookingEntity>>());
        expect(bookings.length, 3);
        expect(bookings[0].id, 'booking-1');
        verify(() => mockDataSource.streamSupplierBookings('supplier-456')).called(1);
      });

      test('should handle empty stream', () async {
        // Arrange
        when(() => mockDataSource.streamSupplierBookings('supplier-456'))
            .thenAnswer((_) => Stream.value([]));

        // Act
        final stream = repository.streamSupplierBookings('supplier-456');
        final bookings = await stream.first;

        // Assert
        expect(bookings, isEmpty);
      });

      test('should emit error when data source throws exception', () async {
        // Arrange
        when(() => mockDataSource.streamSupplierBookings('supplier-456'))
            .thenAnswer((_) => Stream.error(Exception('Stream error')));

        // Act
        final stream = repository.streamSupplierBookings('supplier-456');

        // Assert
        expect(stream, emitsError(isA<Exception>()));
      });

      test('should return stream error as BookingFailure when catch block triggers', () async {
        // Arrange
        when(() => mockDataSource.streamSupplierBookings('supplier-456'))
            .thenThrow(Exception('Initialization error'));

        // Act
        final stream = repository.streamSupplierBookings('supplier-456');

        // Assert
        expect(stream, emitsError(isA<BookingFailure>()));
      });
    });

    group('streamBooking', () {
      test('should return stream of BookingEntity when successful', () async {
        // Arrange
        final model = createTestBookingModel(id: 'booking-123');

        when(() => mockDataSource.streamBooking('booking-123'))
            .thenAnswer((_) => Stream.value(model));

        // Act
        final stream = repository.streamBooking('booking-123');
        final booking = await stream.first;

        // Assert
        expect(booking, isA<BookingEntity>());
        expect(booking?.id, 'booking-123');
        verify(() => mockDataSource.streamBooking('booking-123')).called(1);
      });

      test('should emit null when booking does not exist', () async {
        // Arrange
        when(() => mockDataSource.streamBooking('invalid-id'))
            .thenAnswer((_) => Stream.value(null));

        // Act
        final stream = repository.streamBooking('invalid-id');
        final booking = await stream.first;

        // Assert
        expect(booking, isNull);
      });

      test('should handle booking updates in stream', () async {
        // Arrange
        final model1 = createTestBookingModel(id: 'booking-123', status: BookingStatus.pending);
        final model2 = createTestBookingModel(id: 'booking-123', status: BookingStatus.confirmed);

        when(() => mockDataSource.streamBooking('booking-123'))
            .thenAnswer((_) => Stream.fromIterable([model1, model2]));

        // Act
        final stream = repository.streamBooking('booking-123');

        // Assert
        expect(
          stream,
          emitsInOrder([
            predicate<BookingEntity?>((b) => b?.status == BookingStatus.pending),
            predicate<BookingEntity?>((b) => b?.status == BookingStatus.confirmed),
          ]),
        );
      });

      test('should emit error when data source throws exception', () async {
        // Arrange
        when(() => mockDataSource.streamBooking('booking-123'))
            .thenAnswer((_) => Stream.error(Exception('Stream error')));

        // Act
        final stream = repository.streamBooking('booking-123');

        // Assert
        expect(stream, emitsError(isA<Exception>()));
      });

      test('should return stream error as BookingFailure when catch block triggers', () async {
        // Arrange
        when(() => mockDataSource.streamBooking('booking-123'))
            .thenThrow(Exception('Initialization error'));

        // Act
        final stream = repository.streamBooking('booking-123');

        // Assert
        expect(stream, emitsError(isA<BookingFailure>()));
      });
    });

    group('_handleFirebaseException', () {
      test('should return PermissionFailure for permission-denied code', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('booking-123')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'permission-denied',
          ),
        );

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<PermissionFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return BookingNotFoundFailure for not-found code', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('booking-123')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'not-found',
          ),
        );

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<BookingNotFoundFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return BookingConflictFailure for already-exists code', () async {
        // Arrange
        final entity = createTestBookingEntity();
        when(() => mockDataSource.createBooking(any())).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'already-exists',
          ),
        );

        // Act
        final result = await repository.createBooking(entity);

        // Assert
        result.fold(
          (failure) => expect(failure, isA<BookingConflictFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return UnauthenticatedFailure for unauthenticated code', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('booking-123')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'unauthenticated',
          ),
        );

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<UnauthenticatedFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return ServerFailure for internal code', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('booking-123')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'internal',
          ),
        );

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return ValidationFailure for invalid-argument code', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('booking-123')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'invalid-argument',
          ),
        );

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        result.fold(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should return failure'),
        );
      });

      test('should return BookingFailure for unknown code', () async {
        // Arrange
        when(() => mockDataSource.getBookingById('booking-123')).thenThrow(
          FirebaseException(
            plugin: 'firestore',
            code: 'unknown-code',
            message: 'Unknown error',
          ),
        );

        // Act
        final result = await repository.getBookingById('booking-123');

        // Assert
        result.fold(
          (failure) {
            expect(failure, isA<BookingFailure>());
            expect(failure.message, contains('Unknown error'));
          },
          (_) => fail('Should return failure'),
        );
      });
    });
  });
}
