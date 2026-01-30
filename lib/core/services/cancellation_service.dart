import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  /// Process a booking cancellation using Cloud Function
  ///
  /// This method calls the cancelBooking Cloud Function which handles:
  /// - Authorization validation
  /// - State machine validation
  /// - Booking status update
  /// - Escrow refund processing
  /// - Audit logging
  /// - Notifications
  Future<bool> processBookingCancellation({
    required String bookingId,
    required String cancelledBy, // userId (unused - Cloud Function uses auth)
    required String cancelledByRole, // 'client' or 'supplier' (unused - Cloud Function determines role)
    required String reason,
    bool forceNoRefund = false, // For policy violations (not supported by Cloud Function yet)
  }) async {
    try {
      // Call the cancelBooking Cloud Function for secure server-side cancellation
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('cancelBooking');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'reason': reason,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Falha ao cancelar reserva');
      }

      debugPrint('Booking $bookingId cancelled via Cloud Function');
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Error processing cancellation (Cloud Function): ${e.code} - ${e.message}');
      // Translate common error codes to Portuguese
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Você precisa estar autenticado para cancelar');
        case 'permission-denied':
          throw Exception('Você não tem permissão para cancelar esta reserva');
        case 'not-found':
          throw Exception('Reserva não encontrada');
        case 'failed-precondition':
          throw Exception(e.message ?? 'Esta reserva não pode ser cancelada');
        default:
          throw Exception(e.message ?? 'Erro ao cancelar reserva');
      }
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
      // Support both totalPrice (new) and totalAmount (legacy) for backwards compatibility
      final totalAmount = (bookingData['totalPrice'] as num?)?.toDouble() ??
          (bookingData['totalAmount'] as num?)?.toDouble() ?? 0.0;

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
