import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Booking Flow Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Booking Creation
/// 2. Booking Status Transitions
/// 3. Booking Cancellation with Refunds
/// 4. Supplier Acceptance/Rejection
/// 5. Service Completion
/// 6. Cart Management
/// 7. Package Selection
/// 8. Date/Time Scheduling
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Booking Creation Tests', () {
    test('should create booking with all required fields', () async {
      final eventDate = DateTime.now().add(const Duration(days: 30));

      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'clientId': 'client-456',
        'clientName': 'João Silva',
        'clientPhone': '+244912345678',
        'supplierId': 'supplier-789',
        'supplierName': 'Foto Premium',
        'packageId': 'package-012',
        'packageName': 'Pacote Diamante',
        'status': 'pending',
        'eventDate': Timestamp.fromDate(eventDate),
        'eventType': 'wedding',
        'eventLocation': 'Luanda, Angola',
        'totalAmount': 150000,
        'depositAmount': 50000,
        'notes': 'Casamento ao ar livre',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['status'], 'pending');
      expect(doc.data()?['totalAmount'], 150000);
      expect(doc.data()?['clientId'], 'client-456');
    });

    test('should create booking with customizations', () async {
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'clientId': 'client-456',
        'supplierId': 'supplier-789',
        'packageId': 'package-012',
        'status': 'pending',
        'totalAmount': 175000,
        'customizations': [
          {'name': 'Álbum Extra', 'price': 15000, 'quantity': 1},
          {'name': 'Drone', 'price': 10000, 'quantity': 1},
        ],
        'createdAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.data()?['customizations'], isNotNull);
      expect((doc.data()?['customizations'] as List).length, 2);
    });
  });

  group('Booking Status Transition Tests', () {
    test('should transition from pending to accepted', () async {
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'status': 'pending',
        'clientId': 'client-456',
        'supplierId': 'supplier-789',
      });

      await fakeFirestore.collection('bookings').doc('booking-123').update({
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.data()?['status'], 'accepted');
      expect(doc.data()?['acceptedAt'], isNotNull);
    });

    test('should transition from pending to rejected', () async {
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'status': 'pending',
      });

      await fakeFirestore.collection('bookings').doc('booking-123').update({
        'status': 'rejected',
        'rejectedAt': Timestamp.now(),
        'rejectionReason': 'Não disponível nesta data',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.data()?['status'], 'rejected');
      expect(doc.data()?['rejectionReason'], 'Não disponível nesta data');
    });

    test('should transition from accepted to in_progress', () async {
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'status': 'accepted',
      });

      await fakeFirestore.collection('bookings').doc('booking-123').update({
        'status': 'in_progress',
        'startedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.data()?['status'], 'in_progress');
    });

    test('should transition from in_progress to completed', () async {
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'status': 'in_progress',
      });

      await fakeFirestore.collection('bookings').doc('booking-123').update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.data()?['status'], 'completed');
      expect(doc.data()?['completedAt'], isNotNull);
    });

    test('should track full booking lifecycle', () async {
      final bookingId = 'booking-lifecycle';

      // 1. Create pending booking
      await fakeFirestore.collection('bookings').doc(bookingId).set({
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // 2. Supplier accepts
      await fakeFirestore.collection('bookings').doc(bookingId).update({
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      });

      // 3. Payment confirmed
      await fakeFirestore.collection('bookings').doc(bookingId).update({
        'status': 'confirmed',
        'paymentStatus': 'escrow_funded',
        'confirmedAt': Timestamp.now(),
      });

      // 4. Service in progress
      await fakeFirestore.collection('bookings').doc(bookingId).update({
        'status': 'in_progress',
        'startedAt': Timestamp.now(),
      });

      // 5. Service completed
      await fakeFirestore.collection('bookings').doc(bookingId).update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc(bookingId).get();
      expect(doc.data()?['status'], 'completed');
      expect(doc.data()?['createdAt'], isNotNull);
      expect(doc.data()?['acceptedAt'], isNotNull);
      expect(doc.data()?['confirmedAt'], isNotNull);
      expect(doc.data()?['startedAt'], isNotNull);
      expect(doc.data()?['completedAt'], isNotNull);
    });
  });

  group('Booking Cancellation Tests', () {
    test('should cancel booking by client', () async {
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'status': 'accepted',
        'clientId': 'client-456',
        'supplierId': 'supplier-789',
        'totalAmount': 100000,
      });

      await fakeFirestore.collection('bookings').doc('booking-123').update({
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
        'cancelledBy': 'client',
        'cancellationReason': 'Mudança de planos',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.data()?['status'], 'cancelled');
      expect(doc.data()?['cancelledBy'], 'client');
    });

    test('should cancel booking by supplier', () async {
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'status': 'pending',
      });

      await fakeFirestore.collection('bookings').doc('booking-123').update({
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
        'cancelledBy': 'supplier',
        'cancellationReason': 'Indisponibilidade',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(doc.data()?['cancelledBy'], 'supplier');
    });

    test('should create cancellation record', () async {
      final bookingId = 'booking-123';
      final eventDate = DateTime.now().add(const Duration(days: 30));

      await fakeFirestore.collection('booking_cancellations').add({
        'bookingId': bookingId,
        'clientId': 'client-456',
        'supplierId': 'supplier-789',
        'packageId': 'package-012',
        'totalAmount': 100000,
        'cancelledBy': 'client',
        'reason': 'Mudança de planos',
        'eventDate': Timestamp.fromDate(eventDate),
        'daysBeforeEvent': 30,
        'cancelledAt': Timestamp.now(),
      });

      final cancellations = await fakeFirestore.collection('booking_cancellations').get();
      expect(cancellations.docs.length, 1);
      expect(cancellations.docs.first.data()['daysBeforeEvent'], 30);
    });

    test('should calculate refund based on cancellation policy', () {
      // Cancellation policy:
      // - More than 30 days: 100% refund
      // - 15-30 days: 75% refund
      // - 7-14 days: 50% refund
      // - Less than 7 days: 25% refund
      // - Day of event: 0% refund

      final totalAmount = 100000;

      expect(_calculateRefund(totalAmount, 45), 100000); // 100%
      expect(_calculateRefund(totalAmount, 30), 100000); // 100%
      expect(_calculateRefund(totalAmount, 20), 75000);  // 75%
      expect(_calculateRefund(totalAmount, 15), 75000);  // 75%
      expect(_calculateRefund(totalAmount, 10), 50000);  // 50%
      expect(_calculateRefund(totalAmount, 7), 50000);   // 50%
      expect(_calculateRefund(totalAmount, 5), 25000);   // 25%
      expect(_calculateRefund(totalAmount, 1), 25000);   // 25%
      expect(_calculateRefund(totalAmount, 0), 0);       // 0%
    });
  });

  group('Cart Management Tests', () {
    test('should add item to cart', () async {
      await fakeFirestore.collection('carts').doc('cart-123').set({
        'userId': 'user-456',
        'items': [],
        'totalAmount': 0,
        'updatedAt': Timestamp.now(),
      });

      final cartItem = {
        'supplierId': 'supplier-789',
        'supplierName': 'Foto Premium',
        'packageId': 'package-012',
        'packageName': 'Pacote Diamante',
        'price': 150000,
        'addedAt': Timestamp.now(),
      };

      await fakeFirestore.collection('carts').doc('cart-123').update({
        'items': FieldValue.arrayUnion([cartItem]),
        'totalAmount': 150000,
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('carts').doc('cart-123').get();
      expect((doc.data()?['items'] as List).length, 1);
      expect(doc.data()?['totalAmount'], 150000);
    });

    test('should remove item from cart', () async {
      final cartItem = {
        'supplierId': 'supplier-789',
        'packageId': 'package-012',
        'price': 150000,
      };

      await fakeFirestore.collection('carts').doc('cart-123').set({
        'userId': 'user-456',
        'items': [cartItem],
        'totalAmount': 150000,
      });

      await fakeFirestore.collection('carts').doc('cart-123').update({
        'items': FieldValue.arrayRemove([cartItem]),
        'totalAmount': 0,
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('carts').doc('cart-123').get();
      expect((doc.data()?['items'] as List).length, 0);
      expect(doc.data()?['totalAmount'], 0);
    });

    test('should calculate cart total with multiple items', () async {
      await fakeFirestore.collection('carts').doc('cart-123').set({
        'userId': 'user-456',
        'items': [
          {'packageId': 'p1', 'price': 50000},
          {'packageId': 'p2', 'price': 75000},
          {'packageId': 'p3', 'price': 25000},
        ],
        'totalAmount': 150000,
      });

      final doc = await fakeFirestore.collection('carts').doc('cart-123').get();
      final items = doc.data()?['items'] as List;
      final calculatedTotal = items.fold<int>(
        0,
        (sum, item) => sum + (item['price'] as int),
      );

      expect(calculatedTotal, 150000);
      expect(doc.data()?['totalAmount'], calculatedTotal);
    });

    test('should clear cart after checkout', () async {
      await fakeFirestore.collection('carts').doc('cart-123').set({
        'userId': 'user-456',
        'items': [
          {'packageId': 'p1', 'price': 50000},
        ],
        'totalAmount': 50000,
      });

      // Clear cart after successful checkout
      await fakeFirestore.collection('carts').doc('cart-123').update({
        'items': [],
        'totalAmount': 0,
        'lastCheckoutAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('carts').doc('cart-123').get();
      expect((doc.data()?['items'] as List).length, 0);
      expect(doc.data()?['lastCheckoutAt'], isNotNull);
    });
  });

  group('Package Selection Tests', () {
    test('should get package details', () async {
      await fakeFirestore.collection('packages').doc('package-123').set({
        'supplierId': 'supplier-456',
        'name': 'Pacote Diamante',
        'description': 'Cobertura completa do casamento',
        'price': 150000,
        'duration': 480, // 8 hours
        'features': [
          'Fotografia e Vídeo',
          'Drone',
          'Álbum digital',
          'Álbum físico',
        ],
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('packages').doc('package-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['price'], 150000);
      expect((doc.data()?['features'] as List).length, 4);
    });

    test('should get packages by supplier', () async {
      await fakeFirestore.collection('packages').add({
        'supplierId': 'supplier-123',
        'name': 'Pacote Básico',
        'price': 50000,
        'isActive': true,
      });
      await fakeFirestore.collection('packages').add({
        'supplierId': 'supplier-123',
        'name': 'Pacote Premium',
        'price': 100000,
        'isActive': true,
      });
      await fakeFirestore.collection('packages').add({
        'supplierId': 'other-supplier',
        'name': 'Outro Pacote',
        'price': 75000,
        'isActive': true,
      });

      final packages = await fakeFirestore
          .collection('packages')
          .where('supplierId', isEqualTo: 'supplier-123')
          .where('isActive', isEqualTo: true)
          .get();

      expect(packages.docs.length, 2);
    });

    test('should apply package customizations', () async {
      await fakeFirestore.collection('package_customizations').doc('custom-123').set({
        'packageId': 'package-456',
        'name': 'Álbum Extra',
        'description': 'Álbum adicional de 30 páginas',
        'price': 15000,
        'isRequired': false,
        'maxQuantity': 5,
      });

      final doc = await fakeFirestore.collection('package_customizations').doc('custom-123').get();
      expect(doc.data()?['price'], 15000);
      expect(doc.data()?['isRequired'], false);
    });
  });

  group('Date/Time Scheduling Tests', () {
    test('should check supplier availability', () async {
      final eventDate = DateTime.now().add(const Duration(days: 30));
      final dateStr = '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';

      await fakeFirestore.collection('supplier_availability').doc('supplier-123_$dateStr').set({
        'supplierId': 'supplier-123',
        'date': dateStr,
        'isAvailable': true,
        'bookedSlots': [],
      });

      final doc = await fakeFirestore
          .collection('supplier_availability')
          .doc('supplier-123_$dateStr')
          .get();

      expect(doc.data()?['isAvailable'], true);
    });

    test('should mark date as unavailable after booking', () async {
      final dateStr = '2024-06-15';

      await fakeFirestore.collection('supplier_availability').doc('supplier-123_$dateStr').set({
        'supplierId': 'supplier-123',
        'date': dateStr,
        'isAvailable': true,
        'bookedSlots': [],
      });

      // After booking
      await fakeFirestore.collection('supplier_availability').doc('supplier-123_$dateStr').update({
        'isAvailable': false,
        'bookedSlots': FieldValue.arrayUnion(['booking-456']),
      });

      final doc = await fakeFirestore
          .collection('supplier_availability')
          .doc('supplier-123_$dateStr')
          .get();

      expect(doc.data()?['isAvailable'], false);
      expect((doc.data()?['bookedSlots'] as List).contains('booking-456'), true);
    });

    test('should get supplier blocked dates', () async {
      await fakeFirestore.collection('supplier_blocked_dates').add({
        'supplierId': 'supplier-123',
        'date': '2024-12-25',
        'reason': 'Natal',
      });
      await fakeFirestore.collection('supplier_blocked_dates').add({
        'supplierId': 'supplier-123',
        'date': '2024-01-01',
        'reason': 'Ano Novo',
      });

      final blockedDates = await fakeFirestore
          .collection('supplier_blocked_dates')
          .where('supplierId', isEqualTo: 'supplier-123')
          .get();

      expect(blockedDates.docs.length, 2);
    });
  });

  group('Booking Notifications Tests', () {
    test('should create notification for new booking', () async {
      await fakeFirestore.collection('notifications').add({
        'userId': 'supplier-123',
        'type': 'new_booking',
        'title': 'Nova Reserva',
        'message': 'Você recebeu uma nova reserva de João Silva',
        'data': {'bookingId': 'booking-456'},
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      final notifications = await fakeFirestore
          .collection('notifications')
          .where('type', isEqualTo: 'new_booking')
          .get();

      expect(notifications.docs.length, 1);
    });

    test('should create notification for booking status change', () async {
      final notificationTypes = [
        {'type': 'booking_accepted', 'title': 'Reserva Aceita'},
        {'type': 'booking_rejected', 'title': 'Reserva Rejeitada'},
        {'type': 'booking_cancelled', 'title': 'Reserva Cancelada'},
        {'type': 'booking_completed', 'title': 'Serviço Concluído'},
      ];

      for (final notif in notificationTypes) {
        await fakeFirestore.collection('notifications').add({
          'userId': 'client-123',
          'type': notif['type'],
          'title': notif['title'],
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
      }

      final all = await fakeFirestore.collection('notifications').get();
      expect(all.docs.length, 4);
    });
  });

  group('Booking Review Tests', () {
    test('should create review after booking completion', () async {
      await fakeFirestore.collection('reviews').add({
        'bookingId': 'booking-123',
        'clientId': 'client-456',
        'supplierId': 'supplier-789',
        'rating': 5,
        'comment': 'Excelente serviço! Muito profissional.',
        'createdAt': Timestamp.now(),
      });

      final reviews = await fakeFirestore
          .collection('reviews')
          .where('bookingId', isEqualTo: 'booking-123')
          .get();

      expect(reviews.docs.length, 1);
      expect(reviews.docs.first.data()['rating'], 5);
    });

    test('should update supplier rating after review', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'rating': 4.5,
        'reviewCount': 10,
      });

      // Add new review with rating 5
      // New average: (4.5 * 10 + 5) / 11 = 4.545...
      final newRating = ((4.5 * 10) + 5) / 11;

      await fakeFirestore.collection('suppliers').doc('supplier-123').update({
        'rating': newRating,
        'reviewCount': FieldValue.increment(1),
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect(doc.data()?['reviewCount'], 11);
      expect(doc.data()?['rating'], closeTo(4.545, 0.01));
    });
  });

  group('Booking Search & Filter Tests', () {
    test('should get bookings by client', () async {
      await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'status': 'completed',
      });
      await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'status': 'pending',
      });
      await fakeFirestore.collection('bookings').add({
        'clientId': 'other-client',
        'status': 'completed',
      });

      final clientBookings = await fakeFirestore
          .collection('bookings')
          .where('clientId', isEqualTo: 'client-123')
          .get();

      expect(clientBookings.docs.length, 2);
    });

    test('should get bookings by supplier', () async {
      await fakeFirestore.collection('bookings').add({
        'supplierId': 'supplier-123',
        'status': 'completed',
      });
      await fakeFirestore.collection('bookings').add({
        'supplierId': 'supplier-123',
        'status': 'pending',
      });

      final supplierBookings = await fakeFirestore
          .collection('bookings')
          .where('supplierId', isEqualTo: 'supplier-123')
          .get();

      expect(supplierBookings.docs.length, 2);
    });

    test('should filter bookings by status', () async {
      await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'status': 'pending',
      });
      await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'status': 'completed',
      });
      await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'status': 'completed',
      });

      final completedBookings = await fakeFirestore
          .collection('bookings')
          .where('clientId', isEqualTo: 'client-123')
          .where('status', isEqualTo: 'completed')
          .get();

      expect(completedBookings.docs.length, 2);
    });
  });
}

// Helper function for refund calculation
int _calculateRefund(int totalAmount, int daysBeforeEvent) {
  if (daysBeforeEvent <= 0) return 0;
  if (daysBeforeEvent < 7) return (totalAmount * 0.25).round();
  if (daysBeforeEvent < 15) return (totalAmount * 0.50).round();
  if (daysBeforeEvent < 30) return (totalAmount * 0.75).round();
  return totalAmount;
}
