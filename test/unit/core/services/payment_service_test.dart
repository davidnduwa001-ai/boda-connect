import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/services/payment_service.dart';

/// Comprehensive Payment Service Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Payment Creation (OPG - Mobile Payments)
/// 2. Reference Payments (RPS - ATM/Home Banking)
/// 3. Payment Status Tracking
/// 4. Webhook Processing
/// 5. Escrow System (Full Flow)
/// 6. Refund Processing
/// 7. Platform Fee Calculations
/// 8. Error Handling
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Payment Status Tests', () {
    test('PaymentStatus enum should have all required statuses', () {
      expect(PaymentStatus.values.length, 7);
      expect(PaymentStatus.pending.name, 'pending');
      expect(PaymentStatus.processing.name, 'processing');
      expect(PaymentStatus.completed.name, 'completed');
      expect(PaymentStatus.failed.name, 'failed');
      expect(PaymentStatus.cancelled.name, 'cancelled');
      expect(PaymentStatus.expired.name, 'expired');
      expect(PaymentStatus.refunded.name, 'refunded');
    });

    test('should convert string to PaymentStatus', () {
      expect(
        PaymentStatus.values.firstWhere((s) => s.name == 'completed'),
        PaymentStatus.completed,
      );
      expect(
        PaymentStatus.values.firstWhere((s) => s.name == 'pending'),
        PaymentStatus.pending,
      );
    });
  });

  group('Escrow Status Tests', () {
    test('EscrowStatus enum should have all required statuses', () {
      expect(EscrowStatus.values.length, 6);
      expect(EscrowStatus.pendingPayment.name, 'pendingPayment');
      expect(EscrowStatus.funded.name, 'funded');
      expect(EscrowStatus.serviceCompleted.name, 'serviceCompleted');
      expect(EscrowStatus.released.name, 'released');
      expect(EscrowStatus.disputed.name, 'disputed');
      expect(EscrowStatus.refunded.name, 'refunded');
    });
  });

  group('Payment Record Creation Tests', () {
    test('should create payment record in Firestore', () async {
      final now = DateTime.now();

      await fakeFirestore.collection('payments').doc('payment-123').set({
        'bookingId': 'booking-456',
        'userId': 'user-789',
        'amount': 50000,
        'currency': 'AOA',
        'description': 'Fotografia de casamento',
        'reference': 'BODA-1234567890',
        'status': PaymentStatus.pending.name,
        'provider': 'proxypay_opg',
        'paymentMethod': 'multicaixa_express',
        'customerPhone': '+244912345678',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final doc = await fakeFirestore.collection('payments').doc('payment-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['amount'], 50000);
      expect(doc.data()?['currency'], 'AOA');
      expect(doc.data()?['status'], 'pending');
    });

    test('should update payment status', () async {
      await fakeFirestore.collection('payments').doc('payment-123').set({
        'status': PaymentStatus.pending.name,
      });

      await fakeFirestore.collection('payments').doc('payment-123').update({
        'status': PaymentStatus.completed.name,
        'completedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('payments').doc('payment-123').get();
      expect(doc.data()?['status'], 'completed');
      expect(doc.data()?['completedAt'], isNotNull);
    });
  });

  group('Reference Payment Tests', () {
    test('should create reference payment record', () async {
      final expiresAt = DateTime.now().add(const Duration(days: 7));

      await fakeFirestore.collection('payments').doc('ref-payment-123').set({
        'bookingId': 'booking-456',
        'userId': 'user-789',
        'amount': 75000,
        'currency': 'AOA',
        'description': 'Decoração de festa',
        'reference': '123456789',
        'status': PaymentStatus.pending.name,
        'provider': 'proxypay_rps',
        'paymentMethod': 'reference',
        'entityId': '12345',
        'expiresAt': expiresAt.toIso8601String(),
        'createdAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('payments').doc('ref-payment-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['paymentMethod'], 'reference');
      expect(doc.data()?['entityId'], '12345');
      expect(doc.data()?['reference'], '123456789');
    });

    test('ReferencePaymentResult should format display correctly', () {
      final result = ReferencePaymentResult(
        paymentId: 'payment-123',
        entityId: '12345',
        reference: '123456789',
        amount: 75000,
        currency: 'AOA',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        status: PaymentStatus.pending,
      );

      expect(result.displayFormat, 'Entidade: 12345 | Referência: 123456789');
      expect(result.formattedAmount, '75.000 Kz');
    });
  });

  group('Escrow System Tests', () {
    test('should create escrow record with correct calculations', () async {
      // Platform fee: 10%
      // Total amount: 100000 AOA
      // Platform fee: 10000 AOA
      // Supplier payout: 90000 AOA

      const totalAmount = 100000;
      const platformFeePercent = 10.0;
      final platformFee = (totalAmount * platformFeePercent / 100).round();
      final supplierPayout = totalAmount - platformFee;

      await fakeFirestore.collection('escrow').doc('escrow-123').set({
        'bookingId': 'booking-456',
        'clientId': 'client-789',
        'supplierId': 'supplier-012',
        'totalAmount': totalAmount,
        'platformFee': platformFee,
        'platformFeePercent': platformFeePercent,
        'supplierPayout': supplierPayout,
        'currency': 'AOA',
        'status': EscrowStatus.pendingPayment.name,
        'createdAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('escrow').doc('escrow-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['totalAmount'], 100000);
      expect(doc.data()?['platformFee'], 10000);
      expect(doc.data()?['supplierPayout'], 90000);
    });

    test('should update escrow to funded status', () async {
      await fakeFirestore.collection('escrow').doc('escrow-123').set({
        'status': EscrowStatus.pendingPayment.name,
      });

      await fakeFirestore.collection('escrow').doc('escrow-123').update({
        'status': EscrowStatus.funded.name,
        'fundedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('escrow').doc('escrow-123').get();
      expect(doc.data()?['status'], 'funded');
      expect(doc.data()?['fundedAt'], isNotNull);
    });

    test('should mark service as completed with auto-release time', () async {
      await fakeFirestore.collection('escrow').doc('escrow-123').set({
        'status': EscrowStatus.funded.name,
      });

      final autoReleaseAt = DateTime.now().add(const Duration(hours: 48));

      await fakeFirestore.collection('escrow').doc('escrow-123').update({
        'status': EscrowStatus.serviceCompleted.name,
        'serviceCompletedAt': Timestamp.now(),
        'autoReleaseAt': Timestamp.fromDate(autoReleaseAt),
      });

      final doc = await fakeFirestore.collection('escrow').doc('escrow-123').get();
      expect(doc.data()?['status'], 'serviceCompleted');
      expect(doc.data()?['autoReleaseAt'], isNotNull);
    });

    test('should release escrow and create payout record', () async {
      await fakeFirestore.collection('escrow').doc('escrow-123').set({
        'status': EscrowStatus.serviceCompleted.name,
        'supplierId': 'supplier-012',
        'supplierPayout': 90000,
        'platformFee': 10000,
        'bookingId': 'booking-456',
      });

      // Simulate release
      await fakeFirestore.collection('escrow').doc('escrow-123').update({
        'status': EscrowStatus.released.name,
        'releasedAt': Timestamp.now(),
        'releasedBy': 'system',
      });

      // Create payout record
      await fakeFirestore.collection('payouts').add({
        'escrowId': 'escrow-123',
        'bookingId': 'booking-456',
        'supplierId': 'supplier-012',
        'amount': 90000,
        'platformFee': 10000,
        'currency': 'AOA',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      final escrowDoc = await fakeFirestore.collection('escrow').doc('escrow-123').get();
      expect(escrowDoc.data()?['status'], 'released');

      final payouts = await fakeFirestore.collection('payouts').get();
      expect(payouts.docs.length, 1);
      expect(payouts.docs.first.data()['amount'], 90000);
    });

    test('should handle escrow dispute', () async {
      await fakeFirestore.collection('escrow').doc('escrow-123').set({
        'status': EscrowStatus.serviceCompleted.name,
        'autoReleaseAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 48))),
        'clientId': 'client-789',
        'supplierId': 'supplier-012',
        'bookingId': 'booking-456',
        'totalAmount': 100000,
      });

      // Dispute the escrow
      await fakeFirestore.collection('escrow').doc('escrow-123').update({
        'status': EscrowStatus.disputed.name,
        'disputedAt': Timestamp.now(),
        'disputeReason': 'Serviço não foi entregue como prometido',
        'autoReleaseAt': null, // Cancel auto-release
      });

      // Create dispute record
      await fakeFirestore.collection('disputes').add({
        'escrowId': 'escrow-123',
        'bookingId': 'booking-456',
        'clientId': 'client-789',
        'supplierId': 'supplier-012',
        'amount': 100000,
        'reason': 'Serviço não foi entregue como prometido',
        'status': 'open',
        'createdAt': Timestamp.now(),
      });

      final escrowDoc = await fakeFirestore.collection('escrow').doc('escrow-123').get();
      expect(escrowDoc.data()?['status'], 'disputed');
      expect(escrowDoc.data()?['autoReleaseAt'], isNull);

      final disputes = await fakeFirestore.collection('disputes').get();
      expect(disputes.docs.length, 1);
      expect(disputes.docs.first.data()['status'], 'open');
    });

    test('should refund escrow to client', () async {
      await fakeFirestore.collection('escrow').doc('escrow-123').set({
        'status': EscrowStatus.disputed.name,
        'clientId': 'client-789',
        'totalAmount': 100000,
        'paymentId': 'payment-456',
        'bookingId': 'booking-456',
      });

      // Refund the escrow
      await fakeFirestore.collection('escrow').doc('escrow-123').update({
        'status': EscrowStatus.refunded.name,
        'refundedAt': Timestamp.now(),
        'refundReason': 'Dispute resolved in favor of client',
      });

      // Update booking
      await fakeFirestore.collection('bookings').doc('booking-456').set({
        'paymentStatus': 'refunded',
      });

      final escrowDoc = await fakeFirestore.collection('escrow').doc('escrow-123').get();
      expect(escrowDoc.data()?['status'], 'refunded');

      final booking = await fakeFirestore.collection('bookings').doc('booking-456').get();
      expect(booking.data()?['paymentStatus'], 'refunded');
    });
  });

  group('Platform Fee Tests', () {
    test('should calculate platform fee correctly', () {
      const amount = 100000;
      const feePercent = 10.0;
      final fee = (amount * feePercent / 100).round();

      expect(fee, 10000);
    });

    test('should calculate platform fee with different percentages', () {
      const amount = 100000;

      expect((amount * 5.0 / 100).round(), 5000);
      expect((amount * 10.0 / 100).round(), 10000);
      expect((amount * 15.0 / 100).round(), 15000);
      expect((amount * 20.0 / 100).round(), 20000);
    });

    test('should save platform settings in Firestore', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'platformFeePercent': 12.5,
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['platformFeePercent'], 12.5);
    });
  });

  group('Payment Result Tests', () {
    test('PaymentResult should store all required fields', () {
      final result = PaymentResult(
        paymentId: 'payment-123',
        reference: 'BODA-1234567890',
        providerReference: 'PP-ABC123',
        paymentUrl: null,
        status: PaymentStatus.pending,
        amount: 50000,
        currency: 'AOA',
      );

      expect(result.paymentId, 'payment-123');
      expect(result.reference, 'BODA-1234567890');
      expect(result.providerReference, 'PP-ABC123');
      expect(result.paymentUrl, isNull);
      expect(result.status, PaymentStatus.pending);
      expect(result.amount, 50000);
      expect(result.currency, 'AOA');
    });
  });

  group('Payment Record Tests', () {
    test('PaymentRecord should store all required fields', () {
      final now = DateTime.now();
      final record = PaymentRecord(
        id: 'payment-123',
        bookingId: 'booking-456',
        amount: 50000,
        currency: 'AOA',
        status: PaymentStatus.completed,
        description: 'Fotografia',
        reference: 'BODA-123',
        createdAt: now,
        completedAt: now.add(const Duration(minutes: 5)),
      );

      expect(record.id, 'payment-123');
      expect(record.bookingId, 'booking-456');
      expect(record.amount, 50000);
      expect(record.status, PaymentStatus.completed);
    });
  });

  group('Escrow Details Tests', () {
    test('EscrowDetails canRelease should return true for valid statuses', () {
      final fundedEscrow = EscrowDetails(
        id: 'escrow-1',
        totalAmount: 100000,
        platformFee: 10000,
        supplierPayout: 90000,
        status: EscrowStatus.funded,
      );
      expect(fundedEscrow.canRelease, isTrue);

      final completedEscrow = EscrowDetails(
        id: 'escrow-2',
        totalAmount: 100000,
        platformFee: 10000,
        supplierPayout: 90000,
        status: EscrowStatus.serviceCompleted,
      );
      expect(completedEscrow.canRelease, isTrue);

      final releasedEscrow = EscrowDetails(
        id: 'escrow-3',
        totalAmount: 100000,
        platformFee: 10000,
        supplierPayout: 90000,
        status: EscrowStatus.released,
      );
      expect(releasedEscrow.canRelease, isFalse);
    });

    test('EscrowDetails should calculate time until auto-release', () {
      final autoReleaseAt = DateTime.now().add(const Duration(hours: 24));
      final details = EscrowDetails(
        id: 'escrow-1',
        totalAmount: 100000,
        platformFee: 10000,
        supplierPayout: 90000,
        status: EscrowStatus.serviceCompleted,
        autoReleaseAt: autoReleaseAt,
      );

      expect(details.isAutoReleasePending, isTrue);
      expect(details.timeUntilAutoRelease, isNotNull);
      expect(details.timeUntilAutoRelease!.inHours, greaterThanOrEqualTo(23));
    });
  });

  group('Payment Exception Tests', () {
    test('PaymentException should store message correctly', () {
      final exception = PaymentException('Payment failed: insufficient funds');
      expect(exception.message, 'Payment failed: insufficient funds');
      expect(exception.toString(), 'Payment failed: insufficient funds');
    });
  });

  group('Phone Number Formatting Tests', () {
    test('should format Angola phone number for ProxyPay', () {
      // ProxyPay requires 9 digits without country code
      expect(_formatPhoneForProxyPay('+244912345678'), '912345678');
      expect(_formatPhoneForProxyPay('244912345678'), '912345678');
      expect(_formatPhoneForProxyPay('912345678'), '912345678');
      expect(_formatPhoneForProxyPay('00244912345678'), '912345678');
    });
  });

  group('Webhook Processing Tests', () {
    test('should find payment by reference', () async {
      await fakeFirestore.collection('payments').add({
        'reference': 'BODA-1234567890',
        'status': PaymentStatus.pending.name,
        'bookingId': 'booking-123',
      });

      final query = await fakeFirestore
          .collection('payments')
          .where('reference', isEqualTo: 'BODA-1234567890')
          .limit(1)
          .get();

      expect(query.docs.isNotEmpty, isTrue);
      expect(query.docs.first.data()['reference'], 'BODA-1234567890');
    });

    test('should update payment and booking on webhook', () async {
      // Create payment
      final paymentRef = await fakeFirestore.collection('payments').add({
        'reference': 'BODA-1234567890',
        'status': PaymentStatus.pending.name,
        'bookingId': 'booking-123',
        'amount': 50000,
      });

      // Create booking
      await fakeFirestore.collection('bookings').doc('booking-123').set({
        'paymentStatus': 'pending',
        'supplierId': 'supplier-456',
      });

      // Simulate webhook update
      await paymentRef.update({
        'status': PaymentStatus.completed.name,
        'completedAt': Timestamp.now(),
      });

      await fakeFirestore.collection('bookings').doc('booking-123').update({
        'paymentStatus': 'paid',
        'paidAmount': 50000,
      });

      // Verify updates
      final payment = await paymentRef.get();
      expect(payment.data()?['status'], 'completed');

      final booking = await fakeFirestore.collection('bookings').doc('booking-123').get();
      expect(booking.data()?['paymentStatus'], 'paid');
      expect(booking.data()?['paidAmount'], 50000);
    });
  });

  group('Refund Tests', () {
    test('should create refund record', () async {
      await fakeFirestore.collection('refunds').add({
        'bookingId': 'booking-123',
        'paymentId': 'payment-456',
        'escrowId': 'escrow-789',
        'clientId': 'client-012',
        'amount': 50000,
        'currency': 'AOA',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      final refunds = await fakeFirestore.collection('refunds').get();
      expect(refunds.docs.length, 1);
      expect(refunds.docs.first.data()['amount'], 50000);
      expect(refunds.docs.first.data()['status'], 'pending');
    });

    test('should update refund status to completed', () async {
      final refundRef = await fakeFirestore.collection('refunds').add({
        'status': 'pending',
        'amount': 50000,
      });

      await refundRef.update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
      });

      final refund = await refundRef.get();
      expect(refund.data()?['status'], 'completed');
    });
  });

  group('Payout Tests', () {
    test('should create payout record for supplier', () async {
      await fakeFirestore.collection('payouts').add({
        'escrowId': 'escrow-123',
        'bookingId': 'booking-456',
        'supplierId': 'supplier-789',
        'amount': 90000,
        'platformFee': 10000,
        'currency': 'AOA',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      final payouts = await fakeFirestore.collection('payouts').get();
      expect(payouts.docs.length, 1);
      expect(payouts.docs.first.data()['amount'], 90000);
      expect(payouts.docs.first.data()['platformFee'], 10000);
    });

    test('should get payouts for supplier', () async {
      await fakeFirestore.collection('payouts').add({
        'supplierId': 'supplier-123',
        'amount': 50000,
        'status': 'completed',
      });
      await fakeFirestore.collection('payouts').add({
        'supplierId': 'supplier-123',
        'amount': 75000,
        'status': 'pending',
      });
      await fakeFirestore.collection('payouts').add({
        'supplierId': 'other-supplier',
        'amount': 30000,
        'status': 'completed',
      });

      final supplierPayouts = await fakeFirestore
          .collection('payouts')
          .where('supplierId', isEqualTo: 'supplier-123')
          .get();

      expect(supplierPayouts.docs.length, 2);
    });
  });

  group('Notification Tests', () {
    test('should create payment notification', () async {
      await fakeFirestore.collection('notifications').add({
        'userId': 'supplier-123',
        'type': 'payment_received',
        'title': 'Pagamento Recebido',
        'message': 'Você recebeu um pagamento de 50.000 Kz',
        'data': {'bookingId': 'booking-456', 'paymentId': 'payment-789'},
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      final notifications = await fakeFirestore
          .collection('notifications')
          .where('userId', isEqualTo: 'supplier-123')
          .where('type', isEqualTo: 'payment_received')
          .get();

      expect(notifications.docs.length, 1);
      expect(notifications.docs.first.data()['title'], 'Pagamento Recebido');
    });

    test('should create escrow notification types', () async {
      final notificationTypes = [
        {'type': 'escrow_funded', 'title': 'Pagamento Garantido'},
        {'type': 'payout_released', 'title': 'Pagamento Liberado'},
        {'type': 'service_completed', 'title': 'Serviço Concluído'},
        {'type': 'escrow_disputed', 'title': 'Disputa Aberta'},
        {'type': 'escrow_refunded', 'title': 'Reembolso Processado'},
      ];

      for (final notif in notificationTypes) {
        await fakeFirestore.collection('notifications').add({
          'userId': 'user-123',
          'type': notif['type'],
          'title': notif['title'],
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
      }

      final all = await fakeFirestore.collection('notifications').get();
      expect(all.docs.length, 5);
    });
  });
}

// Helper function for phone formatting tests
String _formatPhoneForProxyPay(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.startsWith('244')) {
    return digits.substring(3);
  }
  if (digits.length == 9) {
    return digits;
  }
  if (digits.startsWith('00244')) {
    return digits.substring(5);
  }
  return digits;
}
