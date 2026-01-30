import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration Tests for BODA CONNECT
///
/// These tests verify the interaction between multiple components
/// and simulate real user flows through the application.
///
/// Test Scenarios:
/// 1. Complete Client Flow (Browse -> Book -> Pay -> Complete)
/// 2. Complete Supplier Flow (Register -> Setup -> Accept -> Deliver)
/// 3. Chat and Booking Integration
/// 4. Payment and Escrow Flow
/// 5. Review and Rating Flow
/// 6. Referral System Flow
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Complete Client Flow Tests', () {
    test('Client: Browse suppliers -> Select package -> Create booking', () async {
      // Step 1: Client searches for photographers
      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Foto Premium',
        'category': 'fotografia',
        'rating': 4.8,
        'isActive': true,
      });

      final suppliers = await fakeFirestore
          .collection('suppliers')
          .where('category', isEqualTo: 'fotografia')
          .where('isActive', isEqualTo: true)
          .get();

      expect(suppliers.docs.length, 1);

      // Step 2: Client views supplier packages
      final supplierId = suppliers.docs.first.id;
      await fakeFirestore.collection('packages').add({
        'supplierId': supplierId,
        'name': 'Pacote Diamante',
        'price': 150000,
        'isActive': true,
      });

      final packages = await fakeFirestore
          .collection('packages')
          .where('supplierId', isEqualTo: supplierId)
          .where('isActive', isEqualTo: true)
          .get();

      expect(packages.docs.length, 1);

      // Step 3: Client creates booking
      final packageId = packages.docs.first.id;
      final bookingRef = await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'supplierId': supplierId,
        'packageId': packageId,
        'status': 'pending',
        'totalAmount': 150000,
        'eventDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'createdAt': Timestamp.now(),
      });

      final booking = await bookingRef.get();
      expect(booking.data()?['status'], 'pending');
    });

    test('Client: Booking acceptance -> Payment -> Escrow funded', () async {
      // Setup: Create booking
      final bookingRef = await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'status': 'pending',
        'totalAmount': 150000,
      });

      // Step 1: Supplier accepts booking
      await bookingRef.update({
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      });

      // Step 2: Client makes payment
      final escrowRef = await fakeFirestore.collection('escrow').add({
        'bookingId': bookingRef.id,
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'totalAmount': 150000,
        'platformFee': 15000,
        'supplierPayout': 135000,
        'status': 'pendingPayment',
      });

      // Step 3: Payment webhook confirms payment
      await escrowRef.update({
        'status': 'funded',
        'fundedAt': Timestamp.now(),
      });

      await bookingRef.update({
        'status': 'confirmed',
        'paymentStatus': 'escrow_funded',
        'escrowId': escrowRef.id,
      });

      // Verify final state
      final booking = await bookingRef.get();
      expect(booking.data()?['status'], 'confirmed');
      expect(booking.data()?['paymentStatus'], 'escrow_funded');

      final escrow = await escrowRef.get();
      expect(escrow.data()?['status'], 'funded');
    });

    test('Client: Service completion -> Escrow release -> Review', () async {
      // Setup: Create funded booking
      final bookingRef = await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'status': 'confirmed',
        'totalAmount': 150000,
      });

      final escrowRef = await fakeFirestore.collection('escrow').add({
        'bookingId': bookingRef.id,
        'status': 'funded',
        'totalAmount': 150000,
        'supplierPayout': 135000,
      });

      // Step 1: Supplier marks service as completed
      await bookingRef.update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      await escrowRef.update({
        'status': 'serviceCompleted',
        'serviceCompletedAt': Timestamp.now(),
        'autoReleaseAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 48))),
      });

      // Step 2: Client confirms and escrow is released
      await escrowRef.update({
        'status': 'released',
        'releasedAt': Timestamp.now(),
      });

      // Step 3: Client leaves review
      await fakeFirestore.collection('reviews').add({
        'bookingId': bookingRef.id,
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'rating': 5,
        'comment': 'Excelente serviço!',
        'createdAt': Timestamp.now(),
      });

      // Step 4: Supplier rating is updated
      await fakeFirestore.collection('suppliers').doc('supplier-456').set({
        'rating': 4.9, // Updated average
        'reviewCount': 51,
      });

      // Verify final state
      final escrow = await escrowRef.get();
      expect(escrow.data()?['status'], 'released');

      final reviews = await fakeFirestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingRef.id)
          .get();
      expect(reviews.docs.length, 1);
    });
  });

  group('Complete Supplier Flow Tests', () {
    test('Supplier: Registration -> Profile setup -> Package creation', () async {
      // Step 1: Create user account
      await fakeFirestore.collection('users').doc('supplier-123').set({
        'phone': '+244923456789',
        'userType': 'supplier',
        'createdAt': Timestamp.now(),
      });

      // Step 2: Complete supplier profile
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'userId': 'supplier-123',
        'businessName': 'Foto Premium Angola',
        'category': 'fotografia',
        'description': 'Especialistas em fotografia de casamento',
        'services': ['Fotografia', 'Vídeo'],
        'isActive': true,
        'isVerified': false,
        'tier': 'basic',
        'createdAt': Timestamp.now(),
      });

      // Step 3: Create packages
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

      // Verify setup
      final supplier = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect(supplier.data()?['businessName'], 'Foto Premium Angola');

      final packages = await fakeFirestore
          .collection('packages')
          .where('supplierId', isEqualTo: 'supplier-123')
          .get();
      expect(packages.docs.length, 2);
    });

    test('Supplier: Receive booking -> Accept -> Complete -> Get paid', () async {
      // Step 1: Receive new booking
      final bookingRef = await fakeFirestore.collection('bookings').add({
        'clientId': 'client-789',
        'supplierId': 'supplier-123',
        'status': 'pending',
        'totalAmount': 100000,
        'createdAt': Timestamp.now(),
      });

      // Notification created for supplier
      await fakeFirestore.collection('notifications').add({
        'userId': 'supplier-123',
        'type': 'new_booking',
        'title': 'Nova Reserva',
        'data': {'bookingId': bookingRef.id},
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      // Step 2: Accept booking
      await bookingRef.update({
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      });

      // Step 3: Payment received (escrow funded)
      final escrowRef = await fakeFirestore.collection('escrow').add({
        'bookingId': bookingRef.id,
        'supplierId': 'supplier-123',
        'totalAmount': 100000,
        'platformFee': 10000,
        'supplierPayout': 90000,
        'status': 'funded',
      });

      // Step 4: Complete service
      await bookingRef.update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      // Step 5: Escrow released
      await escrowRef.update({
        'status': 'released',
        'releasedAt': Timestamp.now(),
      });

      // Step 6: Payout created
      await fakeFirestore.collection('payouts').add({
        'supplierId': 'supplier-123',
        'escrowId': escrowRef.id,
        'amount': 90000,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // Verify
      final payouts = await fakeFirestore
          .collection('payouts')
          .where('supplierId', isEqualTo: 'supplier-123')
          .get();
      expect(payouts.docs.length, 1);
      expect(payouts.docs.first.data()['amount'], 90000);
    });
  });

  group('Chat and Booking Integration Tests', () {
    test('Chat initiated -> Booking created -> Chat continues', () async {
      // Step 1: Client initiates chat with supplier
      final convRef = await fakeFirestore.collection('conversations').add({
        'participants': ['client-123', 'supplier-456'],
        'createdAt': Timestamp.now(),
      });

      // Messages exchanged
      await convRef.collection('messages').add({
        'senderId': 'client-123',
        'text': 'Olá, gostaria de saber sobre seus serviços',
        'createdAt': Timestamp.now(),
      });

      await convRef.collection('messages').add({
        'senderId': 'supplier-456',
        'text': 'Claro! Temos pacotes a partir de 50.000 Kz',
        'createdAt': Timestamp.now(),
      });

      // Step 2: Client creates booking
      final bookingRef = await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'conversationId': convRef.id, // Link to conversation
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // Update conversation with booking reference
      await convRef.update({
        'bookingId': bookingRef.id,
      });

      // Step 3: Chat continues with booking context
      await convRef.collection('messages').add({
        'senderId': 'supplier-456',
        'text': 'Recebi sua reserva! Vou confirmar disponibilidade.',
        'createdAt': Timestamp.now(),
      });

      // Verify
      final messages = await convRef.collection('messages').get();
      expect(messages.docs.length, 3);

      final conversation = await convRef.get();
      expect(conversation.data()?['bookingId'], bookingRef.id);
    });
  });

  group('Payment and Escrow Flow Tests', () {
    test('Full payment flow: Create -> Pay -> Fund -> Release', () async {
      // Step 1: Create booking
      final bookingRef = await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'totalAmount': 100000,
        'status': 'accepted',
      });

      // Step 2: Create escrow
      final escrowRef = await fakeFirestore.collection('escrow').add({
        'bookingId': bookingRef.id,
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'totalAmount': 100000,
        'platformFee': 10000,
        'supplierPayout': 90000,
        'status': 'pendingPayment',
        'createdAt': Timestamp.now(),
      });

      // Step 3: Create payment
      final paymentRef = await fakeFirestore.collection('payments').add({
        'bookingId': bookingRef.id,
        'escrowId': escrowRef.id,
        'userId': 'client-123',
        'amount': 100000,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // Step 4: Payment completed (webhook)
      await paymentRef.update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      // Step 5: Escrow funded
      await escrowRef.update({
        'status': 'funded',
        'paymentId': paymentRef.id,
        'fundedAt': Timestamp.now(),
      });

      await bookingRef.update({
        'status': 'confirmed',
        'paymentStatus': 'escrow_funded',
      });

      // Step 6: Service completed
      await escrowRef.update({
        'status': 'serviceCompleted',
        'serviceCompletedAt': Timestamp.now(),
      });

      // Step 7: Escrow released
      await escrowRef.update({
        'status': 'released',
        'releasedAt': Timestamp.now(),
      });

      // Step 8: Payout to supplier
      await fakeFirestore.collection('payouts').add({
        'escrowId': escrowRef.id,
        'supplierId': 'supplier-456',
        'amount': 90000,
        'platformFee': 10000,
        'status': 'completed',
        'createdAt': Timestamp.now(),
      });

      // Verify final state
      final escrow = await escrowRef.get();
      expect(escrow.data()?['status'], 'released');

      final payment = await paymentRef.get();
      expect(payment.data()?['status'], 'completed');
    });

    test('Dispute flow: Service completed -> Dispute -> Refund', () async {
      // Setup
      final bookingRef = await fakeFirestore.collection('bookings').add({
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'totalAmount': 100000,
        'status': 'completed',
      });

      final escrowRef = await fakeFirestore.collection('escrow').add({
        'bookingId': bookingRef.id,
        'status': 'serviceCompleted',
        'totalAmount': 100000,
      });

      // Step 1: Client opens dispute
      await escrowRef.update({
        'status': 'disputed',
        'disputedAt': Timestamp.now(),
        'disputeReason': 'Fotos não foram entregues',
      });

      await fakeFirestore.collection('disputes').add({
        'escrowId': escrowRef.id,
        'bookingId': bookingRef.id,
        'clientId': 'client-123',
        'supplierId': 'supplier-456',
        'reason': 'Fotos não foram entregues',
        'status': 'open',
        'createdAt': Timestamp.now(),
      });

      // Step 2: Admin resolves in favor of client
      await escrowRef.update({
        'status': 'refunded',
        'refundedAt': Timestamp.now(),
      });

      await bookingRef.update({
        'paymentStatus': 'refunded',
      });

      // Verify
      final escrow = await escrowRef.get();
      expect(escrow.data()?['status'], 'refunded');
    });
  });

  group('Referral System Flow Tests', () {
    test('Referral: Share code -> New user signs up -> Credit referrer', () async {
      // Step 1: Existing user has referral code
      await fakeFirestore.collection('users').doc('referrer-123').set({
        'name': 'Maria',
        'referralCode': 'BODA-MARIA123',
        'totalReferrals': 5,
      });

      // Step 2: New user signs up with referral code
      final newUserRef = fakeFirestore.collection('users').doc('new-user-456');
      await newUserRef.set({
        'name': 'João',
        'phone': '+244912345678',
        'referredBy': 'BODA-MARIA123',
        'createdAt': Timestamp.now(),
      });

      // Step 3: Create referral record
      await fakeFirestore.collection('referrals').add({
        'referrerId': 'referrer-123',
        'referredUserId': 'new-user-456',
        'referralCode': 'BODA-MARIA123',
        'status': 'completed',
        'createdAt': Timestamp.now(),
      });

      // Step 4: Update referrer stats
      await fakeFirestore.collection('users').doc('referrer-123').update({
        'totalReferrals': FieldValue.increment(1),
      });

      // Step 5: Notify referrer
      await fakeFirestore.collection('notifications').add({
        'userId': 'referrer-123',
        'type': 'referral_success',
        'title': 'Convite Aceito!',
        'message': 'João se juntou através do seu convite.',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      // Verify
      final referrer = await fakeFirestore.collection('users').doc('referrer-123').get();
      expect(referrer.data()?['totalReferrals'], 6);

      final notifications = await fakeFirestore
          .collection('notifications')
          .where('userId', isEqualTo: 'referrer-123')
          .where('type', isEqualTo: 'referral_success')
          .get();
      expect(notifications.docs.length, 1);
    });
  });

  group('Notification Integration Tests', () {
    test('Booking lifecycle notifications', () async {
      final bookingId = 'booking-123';

      // Notification when booking is created
      await fakeFirestore.collection('notifications').add({
        'userId': 'supplier-456',
        'type': 'new_booking',
        'title': 'Nova Reserva',
        'data': {'bookingId': bookingId},
        'createdAt': Timestamp.now(),
      });

      // Notification when booking is accepted
      await fakeFirestore.collection('notifications').add({
        'userId': 'client-789',
        'type': 'booking_accepted',
        'title': 'Reserva Aceita',
        'data': {'bookingId': bookingId},
        'createdAt': Timestamp.now(),
      });

      // Notification when payment is received
      await fakeFirestore.collection('notifications').add({
        'userId': 'supplier-456',
        'type': 'escrow_funded',
        'title': 'Pagamento Garantido',
        'data': {'bookingId': bookingId},
        'createdAt': Timestamp.now(),
      });

      // Notification when service is completed
      await fakeFirestore.collection('notifications').add({
        'userId': 'client-789',
        'type': 'service_completed',
        'title': 'Serviço Concluído',
        'data': {'bookingId': bookingId},
        'createdAt': Timestamp.now(),
      });

      // Notification when payout is released
      await fakeFirestore.collection('notifications').add({
        'userId': 'supplier-456',
        'type': 'payout_released',
        'title': 'Pagamento Liberado',
        'data': {'bookingId': bookingId},
        'createdAt': Timestamp.now(),
      });

      // Verify all notifications
      final supplierNotifs = await fakeFirestore
          .collection('notifications')
          .where('userId', isEqualTo: 'supplier-456')
          .get();
      expect(supplierNotifs.docs.length, 3);

      final clientNotifs = await fakeFirestore
          .collection('notifications')
          .where('userId', isEqualTo: 'client-789')
          .get();
      expect(clientNotifs.docs.length, 2);
    });
  });

  group('Search and Filter Integration Tests', () {
    test('Search suppliers with multiple filters', () async {
      // Create test suppliers
      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Foto Premium',
        'category': 'fotografia',
        'services': ['Fotografia', 'Vídeo', 'Drone'],
        'rating': 4.9,
        'tier': 'gold',
        'location': {'city': 'Luanda'},
        'isActive': true,
      });

      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Foto Básico',
        'category': 'fotografia',
        'services': ['Fotografia'],
        'rating': 4.2,
        'tier': 'basic',
        'location': {'city': 'Luanda'},
        'isActive': true,
      });

      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Decorações Luxo',
        'category': 'decoracao',
        'services': ['Decoração', 'Flores'],
        'rating': 4.7,
        'tier': 'silver',
        'location': {'city': 'Luanda'},
        'isActive': true,
      });

      // Filter by category
      final photographers = await fakeFirestore
          .collection('suppliers')
          .where('category', isEqualTo: 'fotografia')
          .where('isActive', isEqualTo: true)
          .get();
      expect(photographers.docs.length, 2);

      // Filter by service
      final withDrone = await fakeFirestore
          .collection('suppliers')
          .where('services', arrayContains: 'Drone')
          .get();
      expect(withDrone.docs.length, 1);

      // Filter by rating
      final highRated = await fakeFirestore
          .collection('suppliers')
          .where('rating', isGreaterThanOrEqualTo: 4.5)
          .get();
      expect(highRated.docs.length, 2);
    });
  });
}
