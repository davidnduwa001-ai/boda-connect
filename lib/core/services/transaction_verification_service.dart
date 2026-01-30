import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'audit_service.dart';
import 'sms_auth_service.dart';

/// Transaction verification service for high-value operations
/// Implements step-up authentication via SMS for critical actions
class TransactionVerificationService {
  static final TransactionVerificationService _instance =
      TransactionVerificationService._internal();
  factory TransactionVerificationService() => _instance;
  TransactionVerificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditService _auditService = AuditService();
  final SmsAuthService _smsAuthService = SmsAuthService();

  // Thresholds for requiring additional verification
  static const double highValueTransactionThresholdAOA = 100000; // 100,000 AOA
  static const double criticalTransactionThresholdAOA = 500000; // 500,000 AOA

  // Verification code validity
  static const int verificationCodeValidityMinutes = 5;

  // Pending verifications cache
  final Map<String, PendingVerification> _pendingVerifications = {};

  // Store verification IDs for SMS verification
  final Map<String, String> _smsVerificationIds = {};

  /// Check if transaction requires verification
  TransactionVerificationRequirement checkVerificationRequirement({
    required TransactionType transactionType,
    required double amount,
    required String currency,
  }) {
    // Convert to AOA for threshold comparison
    double amountInAOA = amount;
    if (currency == 'EUR') {
      amountInAOA = amount * 1000; // Approximate conversion
    } else if (currency == 'USD') {
      amountInAOA = amount * 900; // Approximate conversion
    }

    // Check thresholds based on transaction type
    switch (transactionType) {
      case TransactionType.payment:
        if (amountInAOA >= criticalTransactionThresholdAOA) {
          return TransactionVerificationRequirement.smsRequired;
        } else if (amountInAOA >= highValueTransactionThresholdAOA) {
          return TransactionVerificationRequirement.confirmationRequired;
        }
        return TransactionVerificationRequirement.none;

      case TransactionType.withdrawal:
        // All withdrawals require SMS verification
        if (amountInAOA >= highValueTransactionThresholdAOA) {
          return TransactionVerificationRequirement.smsRequired;
        }
        return TransactionVerificationRequirement.confirmationRequired;

      case TransactionType.refund:
        if (amountInAOA >= highValueTransactionThresholdAOA) {
          return TransactionVerificationRequirement.smsRequired;
        }
        return TransactionVerificationRequirement.confirmationRequired;

      case TransactionType.accountChange:
        // Password changes, payment method changes always require SMS
        return TransactionVerificationRequirement.smsRequired;

      case TransactionType.dataExport:
        // GDPR data export requires SMS
        return TransactionVerificationRequirement.smsRequired;

      case TransactionType.accountDeletion:
        // Account deletion requires SMS
        return TransactionVerificationRequirement.smsRequired;
    }
  }

  /// Initiate SMS verification for a transaction
  Future<VerificationInitResult> initiateVerification({
    required String userId,
    required String phoneNumber,
    required TransactionType transactionType,
    required double amount,
    required String currency,
    String? description,
  }) async {
    try {
      // Generate verification ID
      final verificationId =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Use Completer to handle callback-based API
      final completer = Completer<VerificationInitResult>();

      // Send OTP via SMS using callback-based API
      await _smsAuthService.sendOTP(
        phone: phoneNumber,
        onCodeSent: (smsVerificationId, resendToken) async {
          // Store SMS verification ID for later use
          _smsVerificationIds[verificationId] = smsVerificationId;

          // Store pending verification
          final pending = PendingVerification(
            verificationId: verificationId,
            userId: userId,
            phoneNumber: phoneNumber,
            transactionType: transactionType,
            amount: amount,
            currency: currency,
            description: description,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(
              Duration(minutes: verificationCodeValidityMinutes),
            ),
          );

          _pendingVerifications[verificationId] = pending;

          // Store in Firestore for persistence
          await _firestore
              .collection('pending_verifications')
              .doc(verificationId)
              .set({
            ...pending.toMap(),
            'smsVerificationId': smsVerificationId,
          });

          // Log the verification initiation
          await _auditService.logPaymentEvent(
            userId: userId,
            eventType: PaymentEventType.paymentInitiated,
            transactionId: verificationId,
            amount: amount,
            currency: currency,
            metadata: {
              'transactionType': transactionType.name,
              'verificationRequired': true,
              'phoneLastFour': phoneNumber.length >= 4
                  ? phoneNumber.substring(phoneNumber.length - 4)
                  : '****',
            },
          );

          debugPrint('✅ Verification initiated: $verificationId');

          if (!completer.isCompleted) {
            completer.complete(VerificationInitResult(
              success: true,
              verificationId: verificationId,
              expiresAt: pending.expiresAt,
              message:
                  'Código de verificação enviado para ${_maskPhone(phoneNumber)}',
            ));
          }
        },
        onVerificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed (Android only)
          debugPrint('✅ Auto-verification completed for transaction');
        },
        onVerificationFailed: (FirebaseAuthException error) {
          debugPrint('❌ SMS verification failed: ${error.message}');
          if (!completer.isCompleted) {
            completer.complete(VerificationInitResult(
              success: false,
              message: 'Erro ao enviar código: ${error.message}',
              error: error.code,
            ));
          }
        },
      );

      // Wait for either success or failure callback
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => VerificationInitResult(
          success: false,
          message: 'Tempo esgotado ao enviar código',
          error: 'timeout',
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to initiate verification: $e');
      return VerificationInitResult(
        success: false,
        message: 'Erro ao enviar código de verificação',
        error: e.toString(),
      );
    }
  }

  /// Verify SMS code and complete transaction authorization
  Future<VerificationResult> verifyTransaction({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      // Get pending verification
      PendingVerification? pending = _pendingVerifications[verificationId];
      String? smsVerificationId = _smsVerificationIds[verificationId];

      if (pending == null) {
        // Try to load from Firestore
        final doc = await _firestore
            .collection('pending_verifications')
            .doc(verificationId)
            .get();

        if (!doc.exists) {
          return VerificationResult(
            success: false,
            reason: 'Verificação não encontrada ou expirada',
          );
        }

        final data = doc.data()!;
        pending = PendingVerification.fromMap(data);
        smsVerificationId = data['smsVerificationId'] as String?;
      }

      // Check expiration
      if (DateTime.now().isAfter(pending.expiresAt)) {
        await _cleanupVerification(verificationId);
        return VerificationResult(
          success: false,
          reason: 'Código de verificação expirado',
        );
      }

      // Verify the SMS code using the stored SMS verification ID
      final verifyResult = await _smsAuthService.verifyOTP(
        otp: smsCode,
        verificationId: smsVerificationId,
      );

      if (!verifyResult.success) {
        // Log failed verification attempt
        await _auditService.logSecurityEvent(
          userId: pending.userId,
          eventType: SecurityEventType.unauthorizedAccess,
          description:
              'Failed transaction verification attempt for ${pending.transactionType.name}',
          metadata: {
            'verificationId': verificationId,
            'amount': pending.amount,
          },
          severity: SecuritySeverity.warning,
        );

        return VerificationResult(
          success: false,
          reason: verifyResult.message,
        );
      }

      // Verification successful
      await _firestore
          .collection('pending_verifications')
          .doc(verificationId)
          .update({
        'verifiedAt': FieldValue.serverTimestamp(),
        'status': 'verified',
      });

      // Log successful verification
      await _auditService.logPaymentEvent(
        userId: pending.userId,
        eventType: PaymentEventType.paymentCompleted,
        transactionId: verificationId,
        amount: pending.amount,
        currency: pending.currency,
        metadata: {
          'transactionType': pending.transactionType.name,
          'verificationMethod': 'sms',
        },
      );

      await _cleanupVerification(verificationId);

      debugPrint('✅ Transaction verified: $verificationId');

      return VerificationResult(
        success: true,
        verificationId: verificationId,
        authorizedTransaction: AuthorizedTransaction(
          userId: pending.userId,
          transactionType: pending.transactionType,
          amount: pending.amount,
          currency: pending.currency,
          authorizedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to verify transaction: $e');
      return VerificationResult(
        success: false,
        reason: 'Erro ao verificar transação',
        error: e.toString(),
      );
    }
  }

  /// Resend verification SMS
  Future<bool> resendVerificationCode(String verificationId) async {
    try {
      final pending = _pendingVerifications[verificationId];
      if (pending == null) return false;

      final completer = Completer<bool>();

      await _smsAuthService.resendOTP(
        phone: pending.phoneNumber,
        onCodeSent: (smsVerificationId, resendToken) {
          // Update SMS verification ID
          _smsVerificationIds[verificationId] = smsVerificationId;

          // Update expiration
          _pendingVerifications[verificationId] = PendingVerification(
            verificationId: pending.verificationId,
            userId: pending.userId,
            phoneNumber: pending.phoneNumber,
            transactionType: pending.transactionType,
            amount: pending.amount,
            currency: pending.currency,
            description: pending.description,
            createdAt: pending.createdAt,
            expiresAt: DateTime.now().add(
              Duration(minutes: verificationCodeValidityMinutes),
            ),
          );

          // Update Firestore
          _firestore
              .collection('pending_verifications')
              .doc(verificationId)
              .update({
            'smsVerificationId': smsVerificationId,
            'expiresAt': Timestamp.fromDate(
              DateTime.now()
                  .add(Duration(minutes: verificationCodeValidityMinutes)),
            ),
          });

          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onVerificationCompleted: (credential) {
          // Auto-verification (Android)
        },
        onVerificationFailed: (error) {
          debugPrint('❌ Failed to resend code: ${error.message}');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('❌ Failed to resend verification code: $e');
      return false;
    }
  }

  /// Cancel pending verification
  Future<void> cancelVerification(String verificationId) async {
    await _cleanupVerification(verificationId);
  }

  /// Check if user has valid authorization for transaction type
  Future<bool> hasValidAuthorization({
    required String userId,
    required TransactionType transactionType,
  }) async {
    try {
      final recent = await _firestore
          .collection('pending_verifications')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'verified')
          .where('transactionType', isEqualTo: transactionType.name)
          .orderBy('verifiedAt', descending: true)
          .limit(1)
          .get();

      if (recent.docs.isEmpty) return false;

      final data = recent.docs.first.data();
      final verifiedAt = (data['verifiedAt'] as Timestamp?)?.toDate();

      if (verifiedAt == null) return false;

      // Authorization valid for 15 minutes
      return DateTime.now().difference(verifiedAt).inMinutes < 15;
    } catch (e) {
      debugPrint('❌ Failed to check authorization: $e');
      return false;
    }
  }

  /// Clean up pending verification
  Future<void> _cleanupVerification(String verificationId) async {
    _pendingVerifications.remove(verificationId);
    _smsVerificationIds.remove(verificationId);
    try {
      await _firestore
          .collection('pending_verifications')
          .doc(verificationId)
          .delete();
    } catch (e) {
      debugPrint('❌ Failed to cleanup verification: $e');
    }
  }

  /// Mask phone number for display
  String _maskPhone(String phone) {
    if (phone.length < 4) return '****';
    return '****${phone.substring(phone.length - 4)}';
  }
}

/// Types of transactions that may require verification
enum TransactionType {
  payment,
  withdrawal,
  refund,
  accountChange,
  dataExport,
  accountDeletion,
}

/// Verification requirement levels
enum TransactionVerificationRequirement {
  none,
  confirmationRequired,
  smsRequired,
}

/// Pending verification record
class PendingVerification {
  final String verificationId;
  final String userId;
  final String phoneNumber;
  final TransactionType transactionType;
  final double amount;
  final String currency;
  final String? description;
  final DateTime createdAt;
  final DateTime expiresAt;

  PendingVerification({
    required this.verificationId,
    required this.userId,
    required this.phoneNumber,
    required this.transactionType,
    required this.amount,
    required this.currency,
    this.description,
    required this.createdAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toMap() => {
        'verificationId': verificationId,
        'userId': userId,
        'phoneNumber': phoneNumber,
        'transactionType': transactionType.name,
        'amount': amount,
        'currency': currency,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'status': 'pending',
      };

  factory PendingVerification.fromMap(Map<String, dynamic> map) =>
      PendingVerification(
        verificationId: map['verificationId'] as String,
        userId: map['userId'] as String,
        phoneNumber: map['phoneNumber'] as String,
        transactionType: TransactionType.values.firstWhere(
          (e) => e.name == map['transactionType'],
          orElse: () => TransactionType.payment,
        ),
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String,
        description: map['description'] as String?,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      );
}

/// Result of verification initiation
class VerificationInitResult {
  final bool success;
  final String? verificationId;
  final DateTime? expiresAt;
  final String? message;
  final String? error;

  VerificationInitResult({
    required this.success,
    this.verificationId,
    this.expiresAt,
    this.message,
    this.error,
  });
}

/// Result of verification attempt
class VerificationResult {
  final bool success;
  final String? verificationId;
  final String? reason;
  final String? error;
  final AuthorizedTransaction? authorizedTransaction;

  VerificationResult({
    required this.success,
    this.verificationId,
    this.reason,
    this.error,
    this.authorizedTransaction,
  });
}

/// Authorized transaction after successful verification
class AuthorizedTransaction {
  final String userId;
  final TransactionType transactionType;
  final double amount;
  final String currency;
  final DateTime authorizedAt;
  final DateTime expiresAt;

  AuthorizedTransaction({
    required this.userId,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.authorizedAt,
    required this.expiresAt,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
