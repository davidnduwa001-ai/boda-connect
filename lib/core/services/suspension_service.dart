import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing account suspensions and violations
class SuspensionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rating thresholds
  static const double suspensionThreshold = 2.5; // Suspended below this
  static const double warningThreshold = 3.5;    // Warning below this
  static const double initialRating = 5.0;       // All accounts start here

  // Violation weights (impact on rating)
  static const double contactSharingWeight = 0.5;  // -0.5 per violation
  static const double spamWeight = 0.3;            // -0.3 per violation
  static const double inappropriateWeight = 0.4;   // -0.4 per violation
  static const double noShowWeight = 0.2;          // -0.2 per violation

  /// Checks if a user should be suspended based on their rating
  Future<bool> shouldSuspendUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final rating = (userDoc.data()?['rating'] as num?)?.toDouble() ?? initialRating;

      return rating < suspensionThreshold;
    } catch (e) {
      debugPrint('❌ Error checking suspension status: $e');
      return false;
    }
  }

  /// Suspends a user account
  Future<bool> suspendUser(String userId, SuspensionReason reason, {String? details}) async {
    try {
      final suspension = AccountSuspension(
        userId: userId,
        reason: reason,
        details: details,
        suspendedAt: DateTime.now(),
        canAppeal: true,
      );

      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'suspension': suspension.toMap(),
        'suspendedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🚫 User $userId suspended: ${reason.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error suspending user: $e');
      return false;
    }
  }

  /// Reactivates a suspended account
  Future<bool> reactivateUser(String userId, String adminId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': true,
        'suspension': null,
        'suspendedAt': null,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': adminId,
        'reactivationReason': reason,
      });

      debugPrint('✅ User $userId reactivated by $adminId');
      return true;
    } catch (e) {
      debugPrint('❌ Error reactivating user: $e');
      return false;
    }
  }

  /// Records a policy violation
  Future<void> recordViolation(String userId, PolicyViolation violation) async {
    try {
      // Add violation to subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('violations')
          .add(violation.toMap());

      // Update user's violation count
      await _firestore.collection('users').doc(userId).update({
        'violationCount': FieldValue.increment(1),
        'lastViolation': FieldValue.serverTimestamp(),
      });

      // Apply rating penalty
      await _applyRatingPenalty(userId, violation.type);

      // Check if suspension is needed
      final shouldSuspend = await shouldSuspendUser(userId);
      if (shouldSuspend) {
        await suspendUser(
          userId,
          SuspensionReason.lowRating,
          details: 'Rating fell below ${suspensionThreshold} due to policy violations',
        );
      }

      debugPrint('📝 Violation recorded for user $userId: ${violation.type.name}');
    } catch (e) {
      debugPrint('❌ Error recording violation: $e');
    }
  }

  /// Applies rating penalty based on violation type
  Future<void> _applyRatingPenalty(String userId, ViolationType type) async {
    double penalty = 0.0;

    switch (type) {
      case ViolationType.contactSharing:
        penalty = contactSharingWeight;
        break;
      case ViolationType.spam:
        penalty = spamWeight;
        break;
      case ViolationType.inappropriate:
        penalty = inappropriateWeight;
        break;
      case ViolationType.noShow:
        penalty = noShowWeight;
        break;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentRating = (userDoc.data()?['rating'] as num?)?.toDouble() ?? initialRating;
      final newRating = (currentRating - penalty).clamp(0.0, 5.0);

      await _firestore.collection('users').doc(userId).update({
        'rating': newRating,
      });

      debugPrint('⚠️ Rating penalty applied: $currentRating → $newRating (-$penalty)');
    } catch (e) {
      debugPrint('❌ Error applying rating penalty: $e');
    }
  }

  /// Gets user's violation history
  Future<List<PolicyViolation>> getUserViolations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('violations')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PolicyViolation.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching violations: $e');
      return [];
    }
  }

  /// Determines warning level based on violation count and rating
  Future<WarningLevel> getWarningLevel(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final rating = (userDoc.data()?['rating'] as num?)?.toDouble() ?? initialRating;
      final violationCount = (userDoc.data()?['violationCount'] as num?)?.toInt() ?? 0;

      if (rating < suspensionThreshold) {
        return WarningLevel.critical;
      } else if (rating < warningThreshold || violationCount >= 5) {
        return WarningLevel.high;
      } else if (violationCount >= 3) {
        return WarningLevel.medium;
      } else if (violationCount >= 1) {
        return WarningLevel.low;
      }

      return WarningLevel.none;
    } catch (e) {
      debugPrint('❌ Error getting warning level: $e');
      return WarningLevel.none;
    }
  }

  /// Gets a user-friendly warning message
  String getWarningMessage(WarningLevel level) {
    switch (level) {
      case WarningLevel.critical:
        return '🚨 ATENÇÃO CRÍTICA: Sua conta está em risco de suspensão devido à classificação baixa. '
            'Por favor, melhore seu comportamento imediatamente ou sua conta será suspensa.';
      case WarningLevel.high:
        return '⚠️ AVISO FINAL: Você recebeu múltiplas violações. Mais uma violação pode resultar em suspensão da conta.';
      case WarningLevel.medium:
        return '⚠️ AVISO: Você tem violações recentes. Continue violando as políticas e sua conta será suspensa.';
      case WarningLevel.low:
        return 'ℹ️ LEMBRETE: Por favor, siga as nossas políticas de uso para evitar problemas futuros.';
      case WarningLevel.none:
        return '';
    }
  }

  /// Checks if user can submit an appeal
  Future<bool> canAppeal(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final suspension = userDoc.data()?['suspension'] as Map<String, dynamic>?;

      if (suspension == null) return false;

      final canAppeal = suspension['canAppeal'] as bool? ?? false;
      final hasAppealed = suspension['appealedAt'] != null;

      return canAppeal && !hasAppealed;
    } catch (e) {
      debugPrint('❌ Error checking appeal status: $e');
      return false;
    }
  }

  /// Submits an appeal for suspended account
  Future<bool> submitAppeal(String userId, String message) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'suspension.appealedAt': FieldValue.serverTimestamp(),
        'suspension.appealMessage': message,
        'suspension.appealStatus': 'pending',
      });

      // Create appeal document for admin review
      await _firestore.collection('appeals').add({
        'userId': userId,
        'message': message,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      debugPrint('📬 Appeal submitted for user $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting appeal: $e');
      return false;
    }
  }
}

/// Reason for account suspension
enum SuspensionReason {
  lowRating,
  contactSharing,
  spam,
  inappropriate,
  fraud,
  other,
}

/// Type of policy violation
enum ViolationType {
  contactSharing,
  spam,
  inappropriate,
  noShow,
}

/// Warning level based on violations and rating
enum WarningLevel {
  none,
  low,
  medium,
  high,
  critical,
}

/// Account suspension data
class AccountSuspension {
  final String userId;
  final SuspensionReason reason;
  final String? details;
  final DateTime suspendedAt;
  final bool canAppeal;

  AccountSuspension({
    required this.userId,
    required this.reason,
    this.details,
    required this.suspendedAt,
    required this.canAppeal,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reason': reason.name,
      'details': details,
      'suspendedAt': Timestamp.fromDate(suspendedAt),
      'canAppeal': canAppeal,
    };
  }

  factory AccountSuspension.fromMap(Map<String, dynamic> map) {
    return AccountSuspension(
      userId: map['userId'] as String,
      reason: SuspensionReason.values.firstWhere(
        (e) => e.name == map['reason'],
        orElse: () => SuspensionReason.other,
      ),
      details: map['details'] as String?,
      suspendedAt: (map['suspendedAt'] as Timestamp).toDate(),
      canAppeal: map['canAppeal'] as bool? ?? false,
    );
  }
}

/// Policy violation record
class PolicyViolation {
  final ViolationType type;
  final String description;
  final DateTime timestamp;
  final String? relatedMessageId;
  final String? reportedBy;

  PolicyViolation({
    required this.type,
    required this.description,
    required this.timestamp,
    this.relatedMessageId,
    this.reportedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'relatedMessageId': relatedMessageId,
      'reportedBy': reportedBy,
    };
  }

  factory PolicyViolation.fromMap(Map<String, dynamic> map) {
    return PolicyViolation(
      type: ViolationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ViolationType.inappropriate,
      ),
      description: map['description'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      relatedMessageId: map['relatedMessageId'] as String?,
      reportedBy: map['reportedBy'] as String?,
    );
  }
}
