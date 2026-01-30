import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../errors/error_mapper.dart';

/// Payment Service
///
/// All payment operations go through Firebase Cloud Functions for security.
/// SECURITY: Payment provider selection is SERVER-SIDE ONLY.
/// The client specifies payment TYPE (mobile vs reference), not provider.
///
/// Payment types:
/// - Mobile: Customer receives notification on mobile wallet app
/// - Reference: Customer receives code to pay at ATM/bank
///
/// The server decides which provider to use based on configuration.
class PaymentService {
  static final PaymentService _instance = PaymentService._();
  factory PaymentService() => _instance;
  PaymentService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;

  /// Initialize payment service
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ Payment Service initialized');
  }

  // ==================== SECURITY NOTE ====================
  // Platform fee calculation is now SERVER-ONLY.
  // See: functions/src/finance/escrowService.ts
  // The client should NOT calculate fees - use read-only escrow data instead.
  // ======================================================

  /// Create a mobile payment via OPG (Online Payment Gateway)
  /// Customer receives push notification on Multicaixa Express app
  /// Payment is created via Cloud Function for security
  Future<PaymentResult> createPayment({
    required String bookingId,
    required int amount,
    required String description,
    required String customerPhone,
    String? customerEmail,
    String? customerName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createPaymentIntent');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'amount': amount,
        'paymentMethod': 'opg',
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'customerName': customerName,
        'description': description,
      });

      final data = result.data;

      if (data['success'] != true) {
        throw PaymentException(data['error'] ?? 'Erro ao criar pagamento');
      }

      return PaymentResult(
        paymentId: data['paymentId'] as String,
        reference: data['reference'] as String,
        paymentUrl: data['paymentUrl'] as String?,
        status: PaymentStatus.pending,
        amount: amount,
        currency: 'AOA',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Payment CF error: ${e.code} - ${e.message}');
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    } catch (e) {
      debugPrint('❌ Payment error: $e');
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    }
  }

  // REMOVED: createStripePayment()
  // SECURITY: Client cannot select payment provider.
  // Provider selection is SERVER-SIDE ONLY via configuration.

  /// Create a reference payment via RPS (Reference Payment System)
  /// Customer pays at ATM or home banking using Entity + Reference
  /// Payment is created via Cloud Function for security
  Future<ReferencePaymentResult> createReferencePayment({
    required String bookingId,
    required int amount,
    required String description,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createPaymentIntent');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'amount': amount,
        'paymentMethod': 'rps',
        'description': description,
      });

      final data = result.data;

      if (data['success'] != true) {
        throw PaymentException(data['error'] ?? 'Erro ao criar referência');
      }

      final expiresAtStr = data['expiresAt'] as String?;

      return ReferencePaymentResult(
        paymentId: data['paymentId'] as String,
        entityId: data['entityId'] as String? ?? AppConfig.proxyPayEntityId,
        reference: data['reference'] as String,
        amount: amount,
        currency: 'AOA',
        expiresAt: expiresAtStr != null
            ? DateTime.parse(expiresAtStr)
            : DateTime.now().add(const Duration(hours: 24)),
        status: PaymentStatus.pending,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ RPS Payment CF error: ${e.code} - ${e.message}');
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    } catch (e) {
      debugPrint('❌ RPS Payment error: $e');
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    }
  }

  /// Check payment status via Cloud Function
  /// This verifies with ProxyPay API and updates records
  Future<PaymentStatus> checkPaymentStatus(String paymentId) async {
    try {
      // First try to get fresh status via Cloud Function
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('confirmPayment');

      final result = await callable.call<Map<String, dynamic>>({
        'paymentId': paymentId,
      });

      final data = result.data;
      final statusStr = data['status'] as String? ?? 'pending';

      return PaymentStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => PaymentStatus.pending,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ CF status check failed: ${e.message}');
      // Fall back to cached status
      return _getCachedPaymentStatus(paymentId);
    } catch (e) {
      debugPrint('⚠️ Could not check payment status: $e');
      return _getCachedPaymentStatus(paymentId);
    }
  }

  /// Get cached payment status from Firestore
  Future<PaymentStatus> _getCachedPaymentStatus(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();

      if (!doc.exists) {
        throw PaymentException('Payment not found');
      }

      final data = doc.data()!;
      return PaymentStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PaymentStatus.pending,
      );
    } catch (e) {
      debugPrint('❌ Error getting cached status: $e');
      throw PaymentException('Failed to check payment status');
    }
  }

  // Note: Webhook processing is now handled by Cloud Functions (proxyPayWebhook)
  // The client no longer processes webhooks directly

  /// Acknowledge a received RPS payment (admin only)
  /// This is handled by Cloud Functions - client should not call directly
  @Deprecated('Use Cloud Function acknowledgeRPSPayment instead')
  Future<void> acknowledgeReferencePayment(String referenceId) async {
    debugPrint('⚠️ acknowledgeReferencePayment should be called via Cloud Functions');
    // This operation requires admin privileges and is handled by Cloud Functions
  }

  // Note: Payment status updates are now handled by Cloud Functions

  /// Get payment history for user
  Future<List<PaymentRecord>> getPaymentHistory({int limit = 20}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    final query = await _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) {
      final data = doc.data();
      return PaymentRecord(
        id: doc.id,
        bookingId: data['bookingId'] as String?,
        amount: data['amount'] as int? ?? 0,
        currency: data['currency'] as String? ?? 'AOA',
        status: PaymentStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => PaymentStatus.pending,
        ),
        description: data['description'] as String?,
        reference: data['reference'] as String?,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  /// Cancel a pending payment
  /// Only pending payments can be cancelled
  Future<bool> cancelPayment(String paymentId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('cancelPayment');

      final result = await callable.call<Map<String, dynamic>>({
        'paymentId': paymentId,
      });

      final data = result.data;
      return data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Cancel payment CF error: ${e.code} - ${e.message}');
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    } catch (e) {
      debugPrint('❌ Cancel payment error: $e');
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    }
  }

  /// Refund payment (requires admin privileges)
  /// Refunds must be processed through admin dashboard or support
  Future<bool> refundPayment({
    required String paymentId,
    int? amount,
    String? reason,
  }) async {
    // Refunds require admin access - contact support
    throw PaymentException(
      'Reembolsos devem ser solicitados através do suporte. Por favor, entre em contato.',
    );
  }

  // ==================== ESCROW SYSTEM (Server-Side Authority) ====================
  //
  // SECURITY: Escrow operations are now handled by Cloud Functions.
  // The client can only:
  // - Read escrow details (getEscrowDetails)
  // - Request escrow release via Cloud Function (releaseEscrow)
  // - Open disputes (disputeEscrow - creates dispute record for admin review)
  //
  // The client CANNOT:
  // - Create escrow records (done by createPaymentIntent CF)
  // - Fund escrow (done by confirmPayment CF / webhook)
  // - Mark service completed (done by updateBookingStatus CF)
  // - Process refunds (done by cancelBooking CF or admin)
  //
  // See: functions/src/finance/escrowService.ts for server-side implementation
  // ============================================================================

  /// Release escrow funds to supplier (via Cloud Function)
  /// Client can only release if they are confirming service completion
  Future<bool> releaseEscrow({
    required String escrowId,
    String? notes,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('releaseEscrow');

      final result = await callable.call<Map<String, dynamic>>({
        'escrowId': escrowId,
        'notes': notes,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw PaymentException(data['error'] ?? 'Erro ao liberar escrow');
      }

      debugPrint('✅ Escrow released via CF: $escrowId');
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Release escrow CF error: ${e.code} - ${e.message}');
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    } catch (e) {
      debugPrint('❌ Release escrow error: $e');
      if (e is PaymentException) rethrow;
      throw PaymentException(ErrorMapper.getContextualError('payment', e));
    }
  }

  /// Client disputes the escrow (freezes auto-release)
  /// This creates a dispute record for admin review
  Future<void> disputeEscrow({
    required String escrowId,
    required String reason,
    List<String>? evidenceUrls,
  }) async {
    try {
      // Get escrow data for creating dispute
      final escrowDoc = await _firestore.collection('escrow').doc(escrowId).get();
      if (!escrowDoc.exists) {
        throw PaymentException('Escrow not found');
      }

      final escrowData = escrowDoc.data()!;
      final userId = _auth.currentUser?.uid;

      // Verify caller is the client
      if (escrowData['clientId'] != userId) {
        throw PaymentException('Apenas o cliente pode abrir uma disputa');
      }

      // Create dispute record (admin will review)
      await _firestore.collection('disputes').add({
        'escrowId': escrowId,
        'bookingId': escrowData['bookingId'],
        'clientId': escrowData['clientId'],
        'supplierId': escrowData['supplierId'],
        'amount': escrowData['totalAmount'],
        'reason': reason,
        'evidence': evidenceUrls,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Note: Escrow status update and notifications are handled by admin
      // The dispute will be reviewed and resolved by support team

      debugPrint('✅ Dispute created for escrow: $escrowId');
    } catch (e) {
      debugPrint('❌ Error creating dispute: $e');
      if (e is PaymentException) rethrow;
      throw PaymentException('Erro ao abrir disputa. Tente novamente.');
    }
  }

  // REMOVED: createEscrowPayment - Now handled by createPaymentIntent CF
  // REMOVED: fundEscrow - Now handled by confirmPayment CF / webhook
  // REMOVED: markServiceCompleted - Now handled by updateBookingStatus CF
  // REMOVED: refundEscrow - Now handled by cancelBooking CF or admin

  /// Get escrow details
  Future<EscrowDetails?> getEscrowDetails(String escrowId) async {
    try {
      final doc = await _firestore.collection('escrow').doc(escrowId).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return EscrowDetails(
        id: doc.id,
        bookingId: data['bookingId'] as String?,
        clientId: data['clientId'] as String?,
        supplierId: data['supplierId'] as String?,
        totalAmount: data['totalAmount'] as int? ?? 0,
        platformFee: data['platformFee'] as int? ?? 0,
        supplierPayout: data['supplierPayout'] as int? ?? 0,
        status: EscrowStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => EscrowStatus.pendingPayment,
        ),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        fundedAt: (data['fundedAt'] as Timestamp?)?.toDate(),
        serviceCompletedAt: (data['serviceCompletedAt'] as Timestamp?)?.toDate(),
        releasedAt: (data['releasedAt'] as Timestamp?)?.toDate(),
        autoReleaseAt: (data['autoReleaseAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      debugPrint('❌ Error getting escrow details: $e');
      return null;
    }
  }
}

/// Escrow status enum
enum EscrowStatus {
  pendingPayment, // Waiting for client payment
  funded,         // Payment received, funds held
  serviceCompleted, // Service marked as done, waiting for confirmation
  released,       // Funds released to supplier
  disputed,       // Client opened dispute
  refunded,       // Funds returned to client
}

/// Payment status enum
enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  expired,
  refunded,
}

/// Payment result
class PaymentResult {
  final String paymentId;
  final String reference;
  final String? providerReference;
  final String? paymentUrl;
  final PaymentStatus status;
  final int amount;
  final String currency;

  const PaymentResult({
    required this.paymentId,
    required this.reference,
    this.providerReference,
    this.paymentUrl,
    required this.status,
    required this.amount,
    required this.currency,
  });
}

/// Payment record for history
class PaymentRecord {
  final String id;
  final String? bookingId;
  final int amount;
  final String currency;
  final PaymentStatus status;
  final String? description;
  final String? reference;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const PaymentRecord({
    required this.id,
    this.bookingId,
    required this.amount,
    required this.currency,
    required this.status,
    this.description,
    this.reference,
    this.createdAt,
    this.completedAt,
  });
}

/// Escrow result
class EscrowResult {
  final String escrowId;
  final String paymentId;
  final String reference;
  final String? paymentUrl;
  final EscrowStatus status;
  final int totalAmount;
  final int platformFee;
  final int supplierPayout;

  const EscrowResult({
    required this.escrowId,
    required this.paymentId,
    required this.reference,
    this.paymentUrl,
    required this.status,
    required this.totalAmount,
    required this.platformFee,
    required this.supplierPayout,
  });
}

/// Escrow details for display
class EscrowDetails {
  final String id;
  final String? bookingId;
  final String? clientId;
  final String? supplierId;
  final int totalAmount;
  final int platformFee;
  final int supplierPayout;
  final EscrowStatus status;
  final DateTime? createdAt;
  final DateTime? fundedAt;
  final DateTime? serviceCompletedAt;
  final DateTime? releasedAt;
  final DateTime? autoReleaseAt;

  const EscrowDetails({
    required this.id,
    this.bookingId,
    this.clientId,
    this.supplierId,
    required this.totalAmount,
    required this.platformFee,
    required this.supplierPayout,
    required this.status,
    this.createdAt,
    this.fundedAt,
    this.serviceCompletedAt,
    this.releasedAt,
    this.autoReleaseAt,
  });

  /// Check if escrow can be released
  bool get canRelease =>
      status == EscrowStatus.funded ||
      status == EscrowStatus.serviceCompleted;

  /// Check if auto-release is pending
  bool get isAutoReleasePending =>
      autoReleaseAt != null && DateTime.now().isBefore(autoReleaseAt!);

  /// Get time until auto-release
  Duration? get timeUntilAutoRelease =>
      autoReleaseAt != null ? autoReleaseAt!.difference(DateTime.now()) : null;
}

// REMOVED: StripePaymentResult class
// SECURITY: Client cannot select payment provider.

/// Reference payment result (for ATM/home banking payments)
class ReferencePaymentResult {
  final String paymentId;
  final String entityId;
  final String reference;
  final int amount;
  final String currency;
  final DateTime expiresAt;
  final PaymentStatus status;

  const ReferencePaymentResult({
    required this.paymentId,
    required this.entityId,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.expiresAt,
    required this.status,
  });

  /// Format for display: "Entidade: 12345 | Referência: 123456789"
  String get displayFormat => 'Entidade: $entityId | Referência: $reference';

  /// Format amount for display
  String get formattedAmount {
    final formatted = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$formatted Kz';
  }
}

/// Payment exception
class PaymentException implements Exception {
  final String message;

  const PaymentException(this.message);

  @override
  String toString() => message;
}
