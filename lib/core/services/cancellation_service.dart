import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Cancellation policy tiers
enum CancellationTier {
  /// More than 30 days before event - 100% refund
  fullRefund,

  /// 14-30 days before event - 75% refund
  majorRefund,

  /// 7-14 days before event - 50% refund
  partialRefund,

  /// 72 hours to 7 days before event - 25% refund
  minimalRefund,

  /// Less than 72 hours - No refund
  noRefund,
}

/// Result of a cancellation calculation
class CancellationResult {
  final bool canCancel;
  final CancellationTier tier;
  final double refundPercentage;
  final double refundAmount;
  final double supplierPayout;
  final double platformFee;
  final String message;
  final Duration timeUntilEvent;
  final bool isWithinFreeCancellation;

  const CancellationResult({
    required this.canCancel,
    required this.tier,
    required this.refundPercentage,
    required this.refundAmount,
    required this.supplierPayout,
    required this.platformFee,
    required this.message,
    required this.timeUntilEvent,
    required this.isWithinFreeCancellation,
  });
}

/// Service for handling booking cancellations with 72-hour policy
class CancellationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Policy constants
  static const Duration freeCancellationWindow = Duration(hours: 72);
  static const double platformFeePercent = 0.10; // 10% platform fee

  /// Calculate refund percentage based on time before event
  static double getRefundPercentage(Duration timeBeforeEvent) {
    if (timeBeforeEvent.inDays > 30) {
      return 100.0;
    } else if (timeBeforeEvent.inDays > 14) {
      return 75.0;
    } else if (timeBeforeEvent.inDays > 7) {
      return 50.0;
    } else if (timeBeforeEvent > freeCancellationWindow) {
      return 25.0;
    } else {
      return 0.0; // No refund within 72 hours
    }
  }

  /// Get the cancellation tier for display
  static CancellationTier getTier(Duration timeBeforeEvent) {
    if (timeBeforeEvent.inDays > 30) {
      return CancellationTier.fullRefund;
    } else if (timeBeforeEvent.inDays > 14) {
      return CancellationTier.majorRefund;
    } else if (timeBeforeEvent.inDays > 7) {
      return CancellationTier.partialRefund;
    } else if (timeBeforeEvent > freeCancellationWindow) {
      return CancellationTier.minimalRefund;
    } else {
      return CancellationTier.noRefund;
    }
  }

  /// Get tier description in Portuguese
  static String getTierDescription(CancellationTier tier) {
    switch (tier) {
      case CancellationTier.fullRefund:
        return 'Reembolso total (100%)';
      case CancellationTier.majorRefund:
        return 'Reembolso de 75%';
      case CancellationTier.partialRefund:
        return 'Reembolso de 50%';
      case CancellationTier.minimalRefund:
        return 'Reembolso de 25%';
      case CancellationTier.noRefund:
        return 'Sem reembolso';
    }
  }

  /// Calculate cancellation details for a booking
  CancellationResult calculateCancellation({
    required DateTime eventDate,
    required double totalAmount,
    required bool isClientCancelling,
  }) {
    final now = DateTime.now();
    final timeUntilEvent = eventDate.difference(now);

    // Can't cancel past events
    if (timeUntilEvent.isNegative) {
      return CancellationResult(
        canCancel: false,
        tier: CancellationTier.noRefund,
        refundPercentage: 0,
        refundAmount: 0,
        supplierPayout: totalAmount,
        platformFee: 0,
        message: 'Não é possível cancelar um evento que já ocorreu.',
        timeUntilEvent: timeUntilEvent,
        isWithinFreeCancellation: false,
      );
    }

    final refundPercentage = getRefundPercentage(timeUntilEvent);
    final tier = getTier(timeUntilEvent);
    final isWithinFree = timeUntilEvent <= freeCancellationWindow;

    // Calculate amounts
    final refundAmount = totalAmount * (refundPercentage / 100);
    final nonRefundableAmount = totalAmount - refundAmount;

    // Platform fee from non-refunded amount
    final platformFee = nonRefundableAmount * platformFeePercent;
    final supplierPayout = nonRefundableAmount - platformFee;

    // Generate message
    String message;
    if (isWithinFree) {
      message = 'Atenção: O cancelamento está dentro do período de 72 horas '
          'antes do evento. Nenhum reembolso será processado.';
    } else if (refundPercentage == 100) {
      message = 'Cancelamento com reembolso total. O valor integral '
          'será devolvido em até 7 dias úteis.';
    } else {
      final daysUntil = timeUntilEvent.inDays;
      message = 'Cancelamento $daysUntil dias antes do evento. '
          '${refundPercentage.toInt()}% do valor será reembolsado.';
    }

    return CancellationResult(
      canCancel: true,
      tier: tier,
      refundPercentage: refundPercentage,
      refundAmount: refundAmount,
      supplierPayout: supplierPayout,
      platformFee: platformFee,
      message: message,
      timeUntilEvent: timeUntilEvent,
      isWithinFreeCancellation: isWithinFree,
    );
  }

  /// Process a booking cancellation
  Future<bool> processBookingCancellation({
    required String bookingId,
    required String cancelledBy, // userId
    required String cancelledByRole, // 'client' or 'supplier'
    required String reason,
    bool forceNoRefund = false, // For policy violations
  }) async {
    try {
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      final bookingDoc = await bookingRef.get();

      if (!bookingDoc.exists) {
        throw Exception('Reserva não encontrada');
      }

      final bookingData = bookingDoc.data()!;
      final currentStatus = bookingData['status'] as String;

      // Validate cancellation is allowed
      final allowedStatuses = ['pending', 'accepted', 'confirmed', 'paid'];
      if (!allowedStatuses.contains(currentStatus)) {
        throw Exception('Esta reserva não pode ser cancelada no status atual');
      }

      final eventDate = (bookingData['eventDate'] as Timestamp).toDate();
      final totalAmount = (bookingData['totalAmount'] as num).toDouble();

      // Calculate refund
      final result = calculateCancellation(
        eventDate: eventDate,
        totalAmount: totalAmount,
        isClientCancelling: cancelledByRole == 'client',
      );

      // Special handling for supplier cancellation (may penalize supplier)
      double finalRefundAmount = result.refundAmount;
      double supplierPenalty = 0;

      if (cancelledByRole == 'supplier') {
        // Supplier cancellation - client gets full refund, supplier may be penalized
        finalRefundAmount = totalAmount;
        supplierPenalty = totalAmount * 0.10; // 10% penalty to supplier
      }

      if (forceNoRefund) {
        finalRefundAmount = 0;
      }

      // Create cancellation record
      await _firestore.collection('cancellations').add({
        'bookingId': bookingId,
        'clientId': bookingData['clientId'],
        'supplierId': bookingData['supplierId'],
        'cancelledBy': cancelledBy,
        'cancelledByRole': cancelledByRole,
        'reason': reason,
        'eventDate': bookingData['eventDate'],
        'totalAmount': totalAmount,
        'refundAmount': finalRefundAmount,
        'supplierPayout': cancelledByRole == 'supplier' ? 0 : result.supplierPayout,
        'supplierPenalty': supplierPenalty,
        'platformFee': result.platformFee,
        'refundPercentage': cancelledByRole == 'supplier' ? 100 : result.refundPercentage,
        'tier': result.tier.name,
        'daysBeforeEvent': result.timeUntilEvent.inDays,
        'hoursBeforeEvent': result.timeUntilEvent.inHours,
        'wasWithin72Hours': result.isWithinFreeCancellation,
        'forceNoRefund': forceNoRefund,
        'createdAt': Timestamp.now(),
      });

      // Update booking status
      await bookingRef.update({
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
        'cancelledBy': cancelledBy,
        'cancelledByRole': cancelledByRole,
        'cancellationReason': reason,
        'refundAmount': finalRefundAmount,
        'refundStatus': finalRefundAmount > 0 ? 'pending' : 'not_applicable',
        'updatedAt': Timestamp.now(),
      });

      // Add to booking status history
      await bookingRef.collection('status_history').add({
        'status': 'cancelled',
        'changedBy': cancelledBy,
        'changedByRole': cancelledByRole,
        'reason': reason,
        'refundAmount': finalRefundAmount,
        'createdAt': Timestamp.now(),
      });

      // Process refund if applicable
      if (finalRefundAmount > 0) {
        await _processRefund(
          bookingId: bookingId,
          paymentId: bookingData['paymentId'] as String?,
          escrowId: bookingData['escrowId'] as String?,
          refundAmount: finalRefundAmount,
          clientId: bookingData['clientId'] as String,
        );
      }

      // Update supplier stats if cancellation affects confirmed booking
      if (currentStatus == 'confirmed' || currentStatus == 'paid') {
        final supplierId = bookingData['supplierId'] as String;
        await _firestore.collection('suppliers').doc(supplierId).update({
          'confirmedBookings': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        });
      }

      debugPrint('Booking $bookingId cancelled. Refund: $finalRefundAmount');
      return true;
    } catch (e) {
      debugPrint('Error processing cancellation: $e');
      rethrow;
    }
  }

  /// Get cancellation preview without actually cancelling
  Future<CancellationResult> previewCancellation({
    required String bookingId,
    required String requestedByRole,
  }) async {
    try {
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        throw Exception('Reserva não encontrada');
      }

      final bookingData = bookingDoc.data()!;
      final eventDate = (bookingData['eventDate'] as Timestamp).toDate();
      final totalAmount = (bookingData['totalAmount'] as num).toDouble();

      return calculateCancellation(
        eventDate: eventDate,
        totalAmount: totalAmount,
        isClientCancelling: requestedByRole == 'client',
      );
    } catch (e) {
      debugPrint('Error previewing cancellation: $e');
      rethrow;
    }
  }

  /// Get cancellation history for a user
  Future<List<Map<String, dynamic>>> getCancellationHistory({
    required String userId,
    required String role, // 'client' or 'supplier'
  }) async {
    try {
      final field = role == 'client' ? 'clientId' : 'supplierId';

      final snapshot = await _firestore
          .collection('cancellations')
          .where(field, isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting cancellation history: $e');
      return [];
    }
  }

  /// Get cancellation statistics (admin)
  Future<Map<String, dynamic>> getCancellationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('cancellations');

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();

      int totalCancellations = snapshot.docs.length;
      int clientCancellations = 0;
      int supplierCancellations = 0;
      int within72Hours = 0;
      double totalRefunded = 0;
      double totalLost = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['cancelledByRole'] == 'client') {
          clientCancellations++;
        } else {
          supplierCancellations++;
        }

        if (data['wasWithin72Hours'] == true) {
          within72Hours++;
        }

        totalRefunded += (data['refundAmount'] as num?)?.toDouble() ?? 0;
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        final refund = (data['refundAmount'] as num?)?.toDouble() ?? 0;
        totalLost += (total - refund);
      }

      return {
        'totalCancellations': totalCancellations,
        'clientCancellations': clientCancellations,
        'supplierCancellations': supplierCancellations,
        'within72Hours': within72Hours,
        'totalRefunded': totalRefunded,
        'totalLost': totalLost,
        'cancellationRate': totalCancellations > 0
            ? (supplierCancellations / totalCancellations * 100)
            : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting cancellation stats: $e');
      return {
        'totalCancellations': 0,
        'clientCancellations': 0,
        'supplierCancellations': 0,
        'within72Hours': 0,
        'totalRefunded': 0.0,
        'totalLost': 0.0,
        'cancellationRate': 0.0,
      };
    }
  }

  /// Process refund through payment service
  Future<void> _processRefund({
    required String bookingId,
    required String? paymentId,
    required String? escrowId,
    required double refundAmount,
    required String clientId,
  }) async {
    try {
      debugPrint('💰 Processing refund of $refundAmount for booking $bookingId');

      // Create refund record
      final refundDoc = await _firestore.collection('refunds').add({
        'bookingId': bookingId,
        'paymentId': paymentId,
        'escrowId': escrowId,
        'clientId': clientId,
        'amount': refundAmount,
        'currency': 'AOA',
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // If there's an escrow, process refund through escrow
      if (escrowId != null) {
        await _firestore.collection('escrow').doc(escrowId).update({
          'status': 'refunded',
          'refundedAt': Timestamp.now(),
          'refundAmount': refundAmount,
          'refundId': refundDoc.id,
          'updatedAt': Timestamp.now(),
        });
      }

      // If there's a direct payment, mark it for refund
      if (paymentId != null) {
        await _firestore.collection('payments').doc(paymentId).update({
          'refundStatus': 'pending',
          'refundAmount': refundAmount,
          'refundRequestedAt': Timestamp.now(),
          'refundId': refundDoc.id,
          'updatedAt': Timestamp.now(),
        });
      }

      // Update booking with refund info
      await _firestore.collection('bookings').doc(bookingId).update({
        'refundStatus': 'processing',
        'refundId': refundDoc.id,
        'updatedAt': Timestamp.now(),
      });

      // Create notification for client about refund
      await _firestore.collection('notifications').add({
        'userId': clientId,
        'type': 'refund_initiated',
        'title': 'Reembolso Iniciado',
        'message': 'O seu reembolso de ${_formatPrice(refundAmount.toInt())} Kz está sendo processado. '
            'O valor será creditado em até 7 dias úteis.',
        'data': {
          'bookingId': bookingId,
          'refundId': refundDoc.id,
          'amount': refundAmount,
        },
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      // Update refund status to processing (in production, this would trigger actual payment provider refund)
      await refundDoc.update({
        'status': 'processing',
        'updatedAt': Timestamp.now(),
      });

      debugPrint('✅ Refund initiated: ${refundDoc.id}');
    } catch (e) {
      debugPrint('❌ Error processing refund: $e');
      // Don't rethrow - refund failure shouldn't block cancellation
      // Create a failed refund record for manual processing
      await _firestore.collection('refunds').add({
        'bookingId': bookingId,
        'paymentId': paymentId,
        'escrowId': escrowId,
        'clientId': clientId,
        'amount': refundAmount,
        'currency': 'AOA',
        'status': 'failed',
        'error': e.toString(),
        'requiresManualProcessing': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }
  }

  /// Format price for display
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  /// Get policy explanation text
  static String getPolicyExplanation() {
    return '''
Política de Cancelamento - Boda Connect

CANCELAMENTO PELO CLIENTE:
• Mais de 30 dias antes: Reembolso de 100%
• 14-30 dias antes: Reembolso de 75%
• 7-14 dias antes: Reembolso de 50%
• 72 horas a 7 dias antes: Reembolso de 25%
• Menos de 72 horas: Sem reembolso

CANCELAMENTO PELO FORNECEDOR:
• O cliente recebe reembolso total em qualquer situação
• O fornecedor pode receber penalidade de 10%
• Cancelamentos frequentes podem resultar em suspensão

EMERGÊNCIAS:
• Casos de força maior serão analisados individualmente
• Documentação comprobatória será necessária
• Abra um ticket de suporte para análise

O reembolso será processado em até 7 dias úteis através do método de pagamento original.
''';
  }
}
