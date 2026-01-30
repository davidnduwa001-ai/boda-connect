import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/features/booking/data/models/booking_model.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DateTime testEventDate;
  late DateTime testCreatedAt;
  late DateTime testUpdatedAt;
  late DateTime testConfirmedAt;
  late DateTime testCompletedAt;
  late DateTime testCancelledAt;
  late DateTime testPaymentDate;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    testEventDate = DateTime(2025, 6, 15, 14, 0);
    testCreatedAt = DateTime(2025, 1, 10, 9, 30);
    testUpdatedAt = DateTime(2025, 1, 11, 10, 0);
    testConfirmedAt = DateTime(2025, 1, 12, 11, 0);
    testCompletedAt = DateTime(2025, 6, 15, 20, 0);
    testCancelledAt = DateTime(2025, 1, 13, 12, 0);
    testPaymentDate = DateTime(2025, 1, 11, 15, 30);
  });

  group('BookingModel', () {
    group('fromFirestore', () {
      test('should correctly parse pending booking from DocumentSnapshot', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'packageName': 'Premium Photography Package',
          'eventName': 'Wedding Celebration',
          'eventType': 'wedding',
          'eventDate': Timestamp.fromDate(testEventDate),
          'eventTime': '14:00',
          'eventLocation': 'Luanda Beach Resort',
          'eventLatitude': -8.8383,
          'eventLongitude': 13.2344,
          'status': 'pending',
          'totalAmount': 150000,
          'paidAmount': 0,
          'currency': 'AOA',
          'payments': [],
          'notes': 'General notes',
          'clientNotes': 'Please arrive early',
          'supplierNotes': 'Check equipment',
          'selectedCustomizations': ['custom-1', 'custom-2'],
          'guestCount': 100,
          'proposalId': 'proposal-123',
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
          'confirmedAt': null,
          'completedAt': null,
          'cancelledAt': null,
          'cancellationReason': null,
          'cancelledBy': null,
        };

        await fakeFirestore.collection('bookings').doc('booking-123').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.id, 'booking-123');
        expect(result.clientId, 'client-123');
        expect(result.supplierId, 'supplier-456');
        expect(result.packageId, 'package-789');
        expect(result.packageName, 'Premium Photography Package');
        expect(result.eventName, 'Wedding Celebration');
        expect(result.eventType, 'wedding');
        expect(result.eventDate, testEventDate);
        expect(result.eventTime, '14:00');
        expect(result.eventLocation, 'Luanda Beach Resort');
        expect(result.eventLatitude, -8.8383);
        expect(result.eventLongitude, 13.2344);
        expect(result.status, BookingStatus.pending);
        expect(result.totalAmount, 150000);
        expect(result.paidAmount, 0);
        expect(result.currency, 'AOA');
        expect(result.payments, isEmpty);
        expect(result.notes, 'General notes');
        expect(result.clientNotes, 'Please arrive early');
        expect(result.supplierNotes, 'Check equipment');
        expect(result.selectedCustomizations, ['custom-1', 'custom-2']);
        expect(result.guestCount, 100);
        expect(result.proposalId, 'proposal-123');
        expect(result.createdAt, testCreatedAt);
        expect(result.updatedAt, testUpdatedAt);
        expect(result.confirmedAt, isNull);
        expect(result.completedAt, isNull);
        expect(result.cancelledAt, isNull);
        expect(result.cancellationReason, isNull);
        expect(result.cancelledBy, isNull);
      });

      test('should correctly parse confirmed booking from DocumentSnapshot', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'packageName': 'Premium Package',
          'eventName': 'Birthday Party',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'confirmed',
          'totalAmount': 100000,
          'paidAmount': 50000,
          'currency': 'AOA',
          'payments': [],
          'selectedCustomizations': [],
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
          'confirmedAt': Timestamp.fromDate(testConfirmedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-456').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-456').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.id, 'booking-456');
        expect(result.status, BookingStatus.confirmed);
        expect(result.confirmedAt, testConfirmedAt);
      });

      test('should correctly parse inProgress booking from DocumentSnapshot', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'inProgress',
          'totalAmount': 100000,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-789').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-789').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.status, BookingStatus.inProgress);
      });

      test('should correctly parse completed booking from DocumentSnapshot', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'completed',
          'totalAmount': 100000,
          'paidAmount': 100000,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
          'completedAt': Timestamp.fromDate(testCompletedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-completed').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-completed').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.status, BookingStatus.completed);
        expect(result.completedAt, testCompletedAt);
      });

      test('should correctly parse cancelled booking from DocumentSnapshot', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'cancelled',
          'totalAmount': 100000,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
          'cancelledAt': Timestamp.fromDate(testCancelledAt),
          'cancellationReason': 'Client requested',
          'cancelledBy': 'client-123',
        };

        await fakeFirestore.collection('bookings').doc('booking-cancelled').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-cancelled').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.status, BookingStatus.cancelled);
        expect(result.cancelledAt, testCancelledAt);
        expect(result.cancellationReason, 'Client requested');
        expect(result.cancelledBy, 'client-123');
      });

      test('should correctly parse refunded booking from DocumentSnapshot', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'refunded',
          'totalAmount': 100000,
          'paidAmount': 0,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
          'cancelledAt': Timestamp.fromDate(testCancelledAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-refunded').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-refunded').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.status, BookingStatus.refunded);
      });

      test('should handle null status and default to pending', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': null,
          'totalAmount': 100000,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-null-status').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-null-status').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.status, BookingStatus.pending);
      });

      test('should handle invalid status string and default to pending', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'invalid_status',
          'totalAmount': 100000,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-invalid').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-invalid').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.status, BookingStatus.pending);
      });

      test('should handle null paidAmount and default to 0', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'pending',
          'totalAmount': 100000,
          'paidAmount': null,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-null-paid').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-null-paid').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.paidAmount, 0);
      });

      test('should handle null currency and default to AOA', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'pending',
          'totalAmount': 100000,
          'currency': null,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-null-currency').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-null-currency').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.currency, 'AOA');
      });

      test('should handle null payments list and default to empty list', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'pending',
          'totalAmount': 100000,
          'payments': null,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-null-payments').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-null-payments').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.payments, isEmpty);
      });

      test('should handle null selectedCustomizations and default to empty list', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'pending',
          'totalAmount': 100000,
          'selectedCustomizations': null,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-null-custom').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-null-custom').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.selectedCustomizations, isEmpty);
      });

      test('should correctly parse booking with payments', () async {
        // Arrange
        final bookingData = {
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'confirmed',
          'totalAmount': 100000,
          'paidAmount': 50000,
          'payments': [
            {
              'id': 'payment-1',
              'amount': 30000,
              'method': 'transfer',
              'reference': 'TRX123456',
              'paidAt': Timestamp.fromDate(testPaymentDate),
              'notes': 'Initial payment',
            },
            {
              'id': 'payment-2',
              'amount': 20000,
              'method': 'cash',
              'reference': null,
              'paidAt': Timestamp.fromDate(testPaymentDate.add(Duration(days: 1))),
              'notes': null,
            },
          ],
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        await fakeFirestore.collection('bookings').doc('booking-with-payments').set(bookingData);
        final doc = await fakeFirestore.collection('bookings').doc('booking-with-payments').get();

        // Act
        final result = BookingModel.fromFirestore(doc);

        // Assert
        expect(result.payments.length, 2);
        expect(result.payments[0].id, 'payment-1');
        expect(result.payments[0].amount, 30000);
        expect(result.payments[0].method, 'transfer');
        expect(result.payments[0].reference, 'TRX123456');
        expect(result.payments[0].paidAt, testPaymentDate);
        expect(result.payments[0].notes, 'Initial payment');
        expect(result.payments[1].id, 'payment-2');
        expect(result.payments[1].amount, 20000);
        expect(result.payments[1].method, 'cash');
        expect(result.payments[1].reference, isNull);
        expect(result.payments[1].notes, isNull);
      });
    });

    group('toFirestore', () {
      test('should correctly convert BookingModel to Firestore map', () {
        // Arrange
        final booking = BookingModel(
          id: 'booking-123',
          clientId: 'client-123',
          supplierId: 'supplier-456',
          packageId: 'package-789',
          packageName: 'Premium Package',
          eventName: 'Wedding',
          eventType: 'wedding',
          eventDate: testEventDate,
          eventTime: '14:00',
          eventLocation: 'Luanda Beach',
          eventLatitude: -8.8383,
          eventLongitude: 13.2344,
          status: BookingStatus.confirmed,
          totalAmount: 150000,
          paidAmount: 50000,
          currency: 'AOA',
          payments: const [],
          notes: 'Test notes',
          clientNotes: 'Client notes',
          supplierNotes: 'Supplier notes',
          selectedCustomizations: const ['custom-1'],
          guestCount: 100,
          proposalId: 'proposal-123',
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
          confirmedAt: testConfirmedAt,
          completedAt: null,
          cancelledAt: null,
          cancellationReason: null,
          cancelledBy: null,
        );

        // Act
        final result = booking.toFirestore();

        // Assert
        expect(result['id'], 'booking-123');
        expect(result['clientId'], 'client-123');
        expect(result['supplierId'], 'supplier-456');
        expect(result['packageId'], 'package-789');
        expect(result['packageName'], 'Premium Package');
        expect(result['eventName'], 'Wedding');
        expect(result['eventType'], 'wedding');
        expect(result['eventDate'], isA<Timestamp>());
        expect((result['eventDate'] as Timestamp).toDate(), testEventDate);
        expect(result['eventTime'], '14:00');
        expect(result['eventLocation'], 'Luanda Beach');
        expect(result['eventLatitude'], -8.8383);
        expect(result['eventLongitude'], 13.2344);
        expect(result['status'], 'confirmed');
        expect(result['totalAmount'], 150000);
        expect(result['paidAmount'], 50000);
        expect(result['currency'], 'AOA');
        expect(result['payments'], isA<List>());
        expect(result['notes'], 'Test notes');
        expect(result['clientNotes'], 'Client notes');
        expect(result['supplierNotes'], 'Supplier notes');
        expect(result['selectedCustomizations'], ['custom-1']);
        expect(result['guestCount'], 100);
        expect(result['proposalId'], 'proposal-123');
        expect(result['createdAt'], isA<Timestamp>());
        expect(result['updatedAt'], isA<Timestamp>());
        expect(result['confirmedAt'], isA<Timestamp>());
        expect(result['completedAt'], isNull);
        expect(result['cancelledAt'], isNull);
        expect(result['cancellationReason'], isNull);
        expect(result['cancelledBy'], isNull);
      });

      test('should correctly convert all BookingStatus values', () {
        final statuses = [
          BookingStatus.pending,
          BookingStatus.confirmed,
          BookingStatus.inProgress,
          BookingStatus.completed,
          BookingStatus.cancelled,
          BookingStatus.refunded,
        ];

        for (final status in statuses) {
          // Arrange
          final booking = BookingModel(
            id: 'booking-123',
            clientId: 'client-123',
            supplierId: 'supplier-456',
            packageId: 'package-789',
            eventName: 'Event',
            eventDate: testEventDate,
            status: status,
            totalAmount: 100000,
            createdAt: testCreatedAt,
            updatedAt: testUpdatedAt,
          );

          // Act
          final result = booking.toFirestore();

          // Assert
          expect(result['status'], status.name);
        }
      });

      test('should correctly convert booking with payments', () {
        // Arrange
        final payment1 = BookingPaymentEntity(
          id: 'payment-1',
          amount: 30000,
          method: 'transfer',
          reference: 'TRX123',
          paidAt: testPaymentDate,
          notes: 'First payment',
        );

        final payment2 = BookingPaymentEntity(
          id: 'payment-2',
          amount: 20000,
          method: 'cash',
          paidAt: testPaymentDate.add(Duration(days: 1)),
        );

        final booking = BookingModel(
          id: 'booking-123',
          clientId: 'client-123',
          supplierId: 'supplier-456',
          packageId: 'package-789',
          eventName: 'Event',
          eventDate: testEventDate,
          totalAmount: 100000,
          paidAmount: 50000,
          payments: [payment1, payment2],
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
        );

        // Act
        final result = booking.toFirestore();

        // Assert
        expect(result['payments'], isA<List>());
        final paymentsList = result['payments'] as List;
        expect(paymentsList.length, 2);
        expect(paymentsList[0]['id'], 'payment-1');
        expect(paymentsList[0]['amount'], 30000);
        expect(paymentsList[1]['id'], 'payment-2');
        expect(paymentsList[1]['amount'], 20000);
      });
    });

    group('toEntity', () {
      test('should correctly convert BookingModel to BookingEntity', () {
        // Arrange
        final model = BookingModel(
          id: 'booking-123',
          clientId: 'client-123',
          supplierId: 'supplier-456',
          packageId: 'package-789',
          packageName: 'Premium Package',
          eventName: 'Wedding',
          eventType: 'wedding',
          eventDate: testEventDate,
          eventTime: '14:00',
          eventLocation: 'Luanda Beach',
          eventLatitude: -8.8383,
          eventLongitude: 13.2344,
          status: BookingStatus.confirmed,
          totalAmount: 150000,
          paidAmount: 50000,
          currency: 'AOA',
          payments: const [],
          notes: 'Test notes',
          clientNotes: 'Client notes',
          supplierNotes: 'Supplier notes',
          selectedCustomizations: const ['custom-1'],
          guestCount: 100,
          proposalId: 'proposal-123',
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
          confirmedAt: testConfirmedAt,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<BookingEntity>());
        expect(entity.id, model.id);
        expect(entity.clientId, model.clientId);
        expect(entity.supplierId, model.supplierId);
        expect(entity.packageId, model.packageId);
        expect(entity.packageName, model.packageName);
        expect(entity.eventName, model.eventName);
        expect(entity.status, model.status);
        expect(entity.totalAmount, model.totalAmount);
        expect(entity.paidAmount, model.paidAmount);
      });

      test('should preserve all field values when converting to entity', () {
        // Arrange
        final model = BookingModel(
          id: 'booking-456',
          clientId: 'client-456',
          supplierId: 'supplier-789',
          packageId: 'package-123',
          eventName: 'Birthday',
          eventDate: testEventDate,
          status: BookingStatus.cancelled,
          totalAmount: 80000,
          paidAmount: 40000,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
          cancelledAt: testCancelledAt,
          cancellationReason: 'Weather concerns',
          cancelledBy: 'client-456',
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.cancelledAt, testCancelledAt);
        expect(entity.cancellationReason, 'Weather concerns');
        expect(entity.cancelledBy, 'client-456');
      });
    });

    group('fromEntity', () {
      test('should correctly convert BookingEntity to BookingModel', () {
        // Arrange
        final entity = BookingEntity(
          id: 'booking-123',
          clientId: 'client-123',
          supplierId: 'supplier-456',
          packageId: 'package-789',
          packageName: 'Premium Package',
          eventName: 'Wedding',
          eventType: 'wedding',
          eventDate: testEventDate,
          eventTime: '14:00',
          eventLocation: 'Luanda Beach',
          eventLatitude: -8.8383,
          eventLongitude: 13.2344,
          status: BookingStatus.confirmed,
          totalAmount: 150000,
          paidAmount: 50000,
          currency: 'AOA',
          payments: const [],
          notes: 'Test notes',
          clientNotes: 'Client notes',
          supplierNotes: 'Supplier notes',
          selectedCustomizations: const ['custom-1'],
          guestCount: 100,
          proposalId: 'proposal-123',
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
          confirmedAt: testConfirmedAt,
        );

        // Act
        final model = BookingModel.fromEntity(entity);

        // Assert
        expect(model, isA<BookingModel>());
        expect(model.id, entity.id);
        expect(model.clientId, entity.clientId);
        expect(model.supplierId, entity.supplierId);
        expect(model.packageId, entity.packageId);
        expect(model.packageName, entity.packageName);
        expect(model.eventName, entity.eventName);
        expect(model.status, entity.status);
        expect(model.totalAmount, entity.totalAmount);
        expect(model.paidAmount, entity.paidAmount);
        expect(model.confirmedAt, entity.confirmedAt);
      });

      test('should preserve all nullable fields when converting from entity', () {
        // Arrange
        final entity = BookingEntity(
          id: 'booking-789',
          clientId: 'client-789',
          supplierId: 'supplier-123',
          packageId: 'package-456',
          eventName: 'Corporate Event',
          eventDate: testEventDate,
          status: BookingStatus.completed,
          totalAmount: 200000,
          paidAmount: 200000,
          createdAt: testCreatedAt,
          updatedAt: testUpdatedAt,
          completedAt: testCompletedAt,
        );

        // Act
        final model = BookingModel.fromEntity(entity);

        // Assert
        expect(model.packageName, isNull);
        expect(model.eventType, isNull);
        expect(model.eventTime, isNull);
        expect(model.completedAt, testCompletedAt);
      });
    });

    group('fromMap', () {
      test('should correctly parse booking from map with explicit ID', () {
        // Arrange
        final map = <String, dynamic>{
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'pending',
          'totalAmount': 100000,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        // Act
        final result = BookingModel.fromMap(map, 'explicit-id');

        // Assert
        expect(result.id, 'explicit-id');
      });

      test('should use ID from map if not provided explicitly', () {
        // Arrange
        final map = <String, dynamic>{
          'id': 'map-id',
          'clientId': 'client-123',
          'supplierId': 'supplier-456',
          'packageId': 'package-789',
          'eventName': 'Event',
          'eventDate': Timestamp.fromDate(testEventDate),
          'status': 'pending',
          'totalAmount': 100000,
          'createdAt': Timestamp.fromDate(testCreatedAt),
          'updatedAt': Timestamp.fromDate(testUpdatedAt),
        };

        // Act
        final result = BookingModel.fromMap(map);

        // Assert
        expect(result.id, 'map-id');
      });
    });
  });

  group('BookingPaymentModel', () {
    group('fromMap', () {
      test('should correctly parse payment from map', () {
        // Arrange
        final map = <String, dynamic>{
          'id': 'payment-123',
          'amount': 50000,
          'method': 'transfer',
          'reference': 'TRX123456',
          'paidAt': Timestamp.fromDate(testPaymentDate),
          'notes': 'First payment',
        };

        // Act
        final result = BookingPaymentModel.fromMap(map);

        // Assert
        expect(result.id, 'payment-123');
        expect(result.amount, 50000);
        expect(result.method, 'transfer');
        expect(result.reference, 'TRX123456');
        expect(result.paidAt, testPaymentDate);
        expect(result.notes, 'First payment');
      });

      test('should handle null reference and notes', () {
        // Arrange
        final map = <String, dynamic>{
          'id': 'payment-456',
          'amount': 30000,
          'method': 'cash',
          'reference': null,
          'paidAt': Timestamp.fromDate(testPaymentDate),
          'notes': null,
        };

        // Act
        final result = BookingPaymentModel.fromMap(map);

        // Assert
        expect(result.reference, isNull);
        expect(result.notes, isNull);
      });
    });

    group('toMap', () {
      test('should correctly convert payment to map', () {
        // Arrange
        final payment = BookingPaymentModel(
          id: 'payment-123',
          amount: 50000,
          method: 'transfer',
          reference: 'TRX123456',
          paidAt: testPaymentDate,
          notes: 'First payment',
        );

        // Act
        final result = payment.toMap();

        // Assert
        expect(result['id'], 'payment-123');
        expect(result['amount'], 50000);
        expect(result['method'], 'transfer');
        expect(result['reference'], 'TRX123456');
        expect(result['paidAt'], isA<Timestamp>());
        expect((result['paidAt'] as Timestamp).toDate(), testPaymentDate);
        expect(result['notes'], 'First payment');
      });

      test('should handle null values in map conversion', () {
        // Arrange
        final payment = BookingPaymentModel(
          id: 'payment-456',
          amount: 30000,
          method: 'cash',
          paidAt: testPaymentDate,
        );

        // Act
        final result = payment.toMap();

        // Assert
        expect(result['reference'], isNull);
        expect(result['notes'], isNull);
      });
    });

    group('toEntity', () {
      test('should correctly convert BookingPaymentModel to entity', () {
        // Arrange
        final model = BookingPaymentModel(
          id: 'payment-123',
          amount: 50000,
          method: 'transfer',
          reference: 'TRX123456',
          paidAt: testPaymentDate,
          notes: 'Test payment',
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<BookingPaymentEntity>());
        expect(entity.id, model.id);
        expect(entity.amount, model.amount);
        expect(entity.method, model.method);
        expect(entity.reference, model.reference);
        expect(entity.paidAt, model.paidAt);
        expect(entity.notes, model.notes);
      });
    });

    group('fromEntity', () {
      test('should correctly convert BookingPaymentEntity to model', () {
        // Arrange
        final entity = BookingPaymentEntity(
          id: 'payment-456',
          amount: 30000,
          method: 'cash',
          reference: 'CASH789',
          paidAt: testPaymentDate,
          notes: 'Cash payment',
        );

        // Act
        final model = BookingPaymentModel.fromEntity(entity);

        // Assert
        expect(model, isA<BookingPaymentModel>());
        expect(model.id, entity.id);
        expect(model.amount, entity.amount);
        expect(model.method, entity.method);
        expect(model.reference, entity.reference);
        expect(model.paidAt, entity.paidAt);
        expect(model.notes, entity.notes);
      });
    });
  });
}
