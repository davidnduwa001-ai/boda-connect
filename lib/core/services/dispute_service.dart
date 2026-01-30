import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/report_model.dart';

/// Dispute outcome types
enum DisputeOutcome {
  /// Client receives full/partial refund
  clientFavored,

  /// Supplier keeps payment
  supplierFavored,

  /// Both parties reached agreement
  mutualAgreement,

  /// No action taken (insufficient evidence)
  noAction,

  /// Severe violation - account suspended
  accountSuspended,
}

/// Dispute resolution timeline
class DisputeTimeline {
  /// Initial response SLA
  static const Duration initialResponseSLA = Duration(hours: 24);

  /// Investigation period
  static const Duration investigationPeriod = Duration(hours: 72);

  /// Appeal window after resolution
  static const Duration appealWindow = Duration(days: 7);

  /// Maximum dispute duration
  static const Duration maxDuration = Duration(days: 14);
}

/// Admin note on a dispute
class DisputeNote {
  final String id;
  final String disputeId;
  final String adminId;
  final String adminName;
  final String content;
  final bool isInternal; // Not visible to parties
  final DateTime createdAt;

  const DisputeNote({
    required this.id,
    required this.disputeId,
    required this.adminId,
    required this.adminName,
    required this.content,
    this.isInternal = true,
    required this.createdAt,
  });

  factory DisputeNote.fromMap(Map<String, dynamic> data, String id) {
    return DisputeNote(
      id: id,
      disputeId: data['disputeId'] as String? ?? '',
      adminId: data['adminId'] as String? ?? '',
      adminName: data['adminName'] as String? ?? '',
      content: data['content'] as String? ?? '',
      isInternal: data['isInternal'] as bool? ?? true,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'disputeId': disputeId,
      'adminId': adminId,
      'adminName': adminName,
      'content': content,
      'isInternal': isInternal,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Service for managing dispute resolution
class DisputeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // FIXED: Use 'disputes' collection consistently across the app
  // Previously was 'reports' but admin dashboard and dialogs use 'disputes'
  CollectionReference get _disputesRef => _firestore.collection('disputes');
  CollectionReference get _bookingsRef => _firestore.collection('bookings');

  // ==================== CREATE DISPUTE ====================

  /// File a new dispute
  Future<String?> fileDispute({
    required String bookingId,
    required String reporterId,
    required String reporterType, // 'client' or 'supplier'
    required ReportCategory category,
    required String reason,
    List<String>? evidenceUrls,
    List<String>? messageIds, // Chat message IDs as evidence
    ReportSeverity severity = ReportSeverity.medium,
  }) async {
    try {
      // Get booking details
      final bookingDoc = await _bookingsRef.doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Reserva não encontrada');
      }

      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final clientId = bookingData['clientId'] as String;
      final supplierId = bookingData['supplierId'] as String;

      // Determine reported party
      final reportedId = reporterType == 'client' ? supplierId : clientId;
      final reportedType = reporterType == 'client' ? 'supplier' : 'client';

      // Check for existing open dispute on this booking
      final existingDispute = await _disputesRef
          .where('bookingId', isEqualTo: bookingId)
          .where('status', whereIn: [
            ReportStatus.pending.name,
            ReportStatus.investigating.name,
          ])
          .limit(1)
          .get();

      if (existingDispute.docs.isNotEmpty) {
        throw Exception('Já existe uma disputa aberta para esta reserva');
      }

      // Preserve chat messages as evidence
      if (messageIds != null && messageIds.isNotEmpty) {
        await _preserveMessageEvidence(bookingId, messageIds);
      }

      // Create dispute record
      final now = DateTime.now();
      final dispute = ReportModel(
        id: '',
        reporterId: reporterId,
        reporterType: reporterType,
        reportedId: reportedId,
        reportedType: reportedType,
        bookingId: bookingId,
        category: category,
        severity: severity,
        reason: reason,
        evidence: evidenceUrls ?? [],
        status: ReportStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _disputesRef.add(dispute.toFirestore());

      // Update booking status to disputed
      await _bookingsRef.doc(bookingId).update({
        'status': 'disputed',
        'disputeId': docRef.id,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Dispute filed: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error filing dispute: $e');
      rethrow;
    }
  }

  /// Preserve chat messages as evidence (copy to separate collection)
  Future<void> _preserveMessageEvidence(
    String bookingId,
    List<String> messageIds,
  ) async {
    try {
      // Find conversation for this booking
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (conversationsSnapshot.docs.isEmpty) return;

      final conversationId = conversationsSnapshot.docs.first.id;

      // Copy specified messages to evidence collection
      for (final messageId in messageIds) {
        final messageDoc = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          await _firestore
              .collection('dispute_evidence')
              .doc('${bookingId}_$messageId')
              .set({
            ...messageDoc.data()!,
            'bookingId': bookingId,
            'preservedAt': Timestamp.now(),
            'originalMessageId': messageId,
          });
        }
      }
    } catch (e) {
      debugPrint('Error preserving message evidence: $e');
    }
  }

  // ==================== GET DISPUTES ====================

  /// Get a single dispute
  Future<ReportModel?> getDispute(String disputeId) async {
    try {
      final doc = await _disputesRef.doc(disputeId).get();
      if (!doc.exists) return null;
      return ReportModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting dispute: $e');
      return null;
    }
  }

  /// Stream a single dispute
  Stream<ReportModel?> streamDispute(String disputeId) {
    return _disputesRef.doc(disputeId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ReportModel.fromFirestore(doc);
    });
  }

  /// Get disputes for a user
  Future<List<ReportModel>> getUserDisputes({
    required String userId,
    required String userType,
    bool asReporter = true,
  }) async {
    try {
      final field = asReporter ? 'reporterId' : 'reportedId';
      final typeField = asReporter ? 'reporterType' : 'reportedType';

      final snapshot = await _disputesRef
          .where(field, isEqualTo: userId)
          .where(typeField, isEqualTo: userType)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user disputes: $e');
      return [];
    }
  }

  /// Get dispute for a booking
  Future<ReportModel?> getBookingDispute(String bookingId) async {
    try {
      final snapshot = await _disputesRef
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ReportModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting booking dispute: $e');
      return null;
    }
  }

  // ==================== USER ACTIONS ====================

  /// Add evidence to an open dispute
  Future<bool> addEvidence({
    required String disputeId,
    required String userId,
    required List<String> evidenceUrls,
    String? description,
  }) async {
    try {
      final dispute = await getDispute(disputeId);
      if (dispute == null) throw Exception('Disputa não encontrada');

      // Only parties involved can add evidence
      if (dispute.reporterId != userId && dispute.reportedId != userId) {
        throw Exception('Você não está envolvido nesta disputa');
      }

      // Can only add evidence while dispute is open
      if (dispute.status != ReportStatus.pending &&
          dispute.status != ReportStatus.investigating) {
        throw Exception('Não é possível adicionar evidências a uma disputa fechada');
      }

      // Add to evidence sub-collection
      await _disputesRef.doc(disputeId).collection('additional_evidence').add({
        'submittedBy': userId,
        'evidenceUrls': evidenceUrls,
        'description': description,
        'createdAt': Timestamp.now(),
      });

      await _disputesRef.doc(disputeId).update({
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      debugPrint('Error adding evidence: $e');
      rethrow;
    }
  }

  /// Submit response to a dispute (reported party)
  Future<bool> submitResponse({
    required String disputeId,
    required String userId,
    required String response,
    List<String>? evidenceUrls,
  }) async {
    try {
      final dispute = await getDispute(disputeId);
      if (dispute == null) throw Exception('Disputa não encontrada');

      // Only reported party can respond
      if (dispute.reportedId != userId) {
        throw Exception('Apenas a parte acusada pode responder');
      }

      // Update dispute with response
      await _disputesRef.doc(disputeId).update({
        'responseFromReported': response,
        'responseEvidenceUrls': evidenceUrls ?? [],
        'respondedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      debugPrint('Error submitting response: $e');
      rethrow;
    }
  }

  // ==================== ADMIN ACTIONS ====================

  /// Assign dispute to admin
  Future<void> assignDispute({
    required String disputeId,
    required String adminId,
    required String adminName,
  }) async {
    try {
      await _disputesRef.doc(disputeId).update({
        'assignedTo': adminId,
        'assignedAdminName': adminName,
        'assignedAt': Timestamp.now(),
        'status': ReportStatus.investigating.name,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error assigning dispute: $e');
      rethrow;
    }
  }

  /// Add admin note to dispute
  Future<void> addAdminNote({
    required String disputeId,
    required String adminId,
    required String adminName,
    required String content,
    bool isInternal = true,
  }) async {
    try {
      await _disputesRef.doc(disputeId).collection('admin_notes').add({
        'disputeId': disputeId,
        'adminId': adminId,
        'adminName': adminName,
        'content': content,
        'isInternal': isInternal,
        'createdAt': Timestamp.now(),
      });

      await _disputesRef.doc(disputeId).update({
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error adding admin note: $e');
      rethrow;
    }
  }

  /// Get admin notes for a dispute
  Future<List<DisputeNote>> getAdminNotes(
    String disputeId, {
    bool includeInternal = true,
  }) async {
    try {
      Query query = _disputesRef
          .doc(disputeId)
          .collection('admin_notes')
          .orderBy('createdAt', descending: false);

      if (!includeInternal) {
        query = query.where('isInternal', isEqualTo: false);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => DisputeNote.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error getting admin notes: $e');
      return [];
    }
  }

  /// Resolve a dispute
  Future<void> resolveDispute({
    required String disputeId,
    required String adminId,
    required DisputeOutcome outcome,
    required String resolution,
    double? refundAmount,
    bool suspendReportedAccount = false,
  }) async {
    try {
      final dispute = await getDispute(disputeId);
      if (dispute == null) throw Exception('Disputa não encontrada');

      // Determine final status based on outcome
      ReportStatus finalStatus;
      switch (outcome) {
        case DisputeOutcome.clientFavored:
        case DisputeOutcome.supplierFavored:
        case DisputeOutcome.mutualAgreement:
          finalStatus = ReportStatus.resolved;
          break;
        case DisputeOutcome.noAction:
          finalStatus = ReportStatus.dismissed;
          break;
        case DisputeOutcome.accountSuspended:
          finalStatus = ReportStatus.resolved;
          break;
      }

      // Update dispute
      await _disputesRef.doc(disputeId).update({
        'status': finalStatus.name,
        'outcome': outcome.name,
        'resolution': resolution,
        'resolvedAt': Timestamp.now(),
        'resolvedBy': adminId,
        'refundAmount': refundAmount,
        'updatedAt': Timestamp.now(),
      });

      // Process based on outcome
      if (dispute.bookingId != null) {
        await _processDisputeOutcome(
          bookingId: dispute.bookingId!,
          outcome: outcome,
          refundAmount: refundAmount,
        );
      }

      // Suspend account if needed
      if (suspendReportedAccount) {
        await _suspendAccount(
          userId: dispute.reportedId,
          userType: dispute.reportedType,
          reason: 'Violação de políticas: $resolution',
          disputeId: disputeId,
        );
      }

      debugPrint('Dispute resolved: $disputeId with outcome ${outcome.name}');
    } catch (e) {
      debugPrint('Error resolving dispute: $e');
      rethrow;
    }
  }

  /// Process dispute outcome (refunds, booking status)
  Future<void> _processDisputeOutcome({
    required String bookingId,
    required DisputeOutcome outcome,
    double? refundAmount,
  }) async {
    try {
      String newBookingStatus;

      switch (outcome) {
        case DisputeOutcome.clientFavored:
          newBookingStatus = 'refunded';
          break;
        case DisputeOutcome.supplierFavored:
          newBookingStatus = 'completed';
          break;
        case DisputeOutcome.mutualAgreement:
          newBookingStatus = refundAmount != null && refundAmount > 0
              ? 'partially_refunded'
              : 'completed';
          break;
        case DisputeOutcome.noAction:
        case DisputeOutcome.accountSuspended:
          newBookingStatus = 'dispute_closed';
          break;
      }

      await _bookingsRef.doc(bookingId).update({
        'status': newBookingStatus,
        'disputeResolved': true,
        'refundAmount': refundAmount,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error processing dispute outcome: $e');
    }
  }

  /// Suspend an account
  Future<void> _suspendAccount({
    required String userId,
    required String userType,
    required String reason,
    required String disputeId,
  }) async {
    try {
      final collection = userType == 'supplier' ? 'suppliers' : 'users';

      await _firestore.collection(collection).doc(userId).update({
        'isSuspended': true,
        'suspendedAt': Timestamp.now(),
        'suspensionReason': reason,
        'suspensionDisputeId': disputeId,
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Account suspended: $userId ($userType)');
    } catch (e) {
      debugPrint('Error suspending account: $e');
    }
  }

  /// Escalate dispute to senior admin
  Future<void> escalateDispute({
    required String disputeId,
    required String adminId,
    required String reason,
  }) async {
    try {
      await _disputesRef.doc(disputeId).update({
        'isEscalated': true,
        'escalatedAt': Timestamp.now(),
        'escalatedBy': adminId,
        'escalationReason': reason,
        'severity': ReportSeverity.critical.name,
        'status': ReportStatus.escalated.name,
        'updatedAt': Timestamp.now(),
      });

      await addAdminNote(
        disputeId: disputeId,
        adminId: adminId,
        adminName: 'Sistema',
        content: 'Disputa escalada: $reason',
        isInternal: true,
      );
    } catch (e) {
      debugPrint('Error escalating dispute: $e');
      rethrow;
    }
  }

  // ==================== APPEAL ====================

  /// File an appeal for a resolved dispute
  Future<bool> fileAppeal({
    required String disputeId,
    required String userId,
    required String reason,
    List<String>? newEvidenceUrls,
  }) async {
    try {
      final dispute = await getDispute(disputeId);
      if (dispute == null) throw Exception('Disputa não encontrada');

      // Check if user is involved
      if (dispute.reporterId != userId && dispute.reportedId != userId) {
        throw Exception('Você não está envolvido nesta disputa');
      }

      // Check if dispute is resolved
      if (dispute.status != ReportStatus.resolved &&
          dispute.status != ReportStatus.dismissed) {
        throw Exception('Apenas disputas resolvidas podem ser apeladas');
      }

      // Check appeal window
      final resolvedAt = dispute.updatedAt;
      final daysSinceResolution =
          DateTime.now().difference(resolvedAt).inDays;

      if (daysSinceResolution > DisputeTimeline.appealWindow.inDays) {
        throw Exception(
            'O prazo para apelação expirou (${DisputeTimeline.appealWindow.inDays} dias)');
      }

      // Create appeal record
      await _disputesRef.doc(disputeId).collection('appeals').add({
        'appealedBy': userId,
        'reason': reason,
        'newEvidenceUrls': newEvidenceUrls ?? [],
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // Update dispute status
      await _disputesRef.doc(disputeId).update({
        'hasAppeal': true,
        'appealStatus': 'pending',
        'status': ReportStatus.investigating.name,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      debugPrint('Error filing appeal: $e');
      rethrow;
    }
  }

  // ==================== STATISTICS ====================

  /// Get dispute statistics (admin dashboard)
  Future<Map<String, dynamic>> getDisputeStats() async {
    try {
      final openCount = await _disputesRef
          .where('status', whereIn: [
            ReportStatus.pending.name,
            ReportStatus.investigating.name,
          ])
          .count()
          .get();

      final resolvedCount = await _disputesRef
          .where('status', isEqualTo: ReportStatus.resolved.name)
          .count()
          .get();

      final escalatedCount = await _disputesRef
          .where('status', isEqualTo: ReportStatus.escalated.name)
          .count()
          .get();

      // Get recent disputes for average resolution time
      final recentResolved = await _disputesRef
          .where('status', isEqualTo: ReportStatus.resolved.name)
          .orderBy('resolvedAt', descending: true)
          .limit(50)
          .get();

      double avgResolutionHours = 0;
      if (recentResolved.docs.isNotEmpty) {
        double totalHours = 0;
        int count = 0;

        for (final doc in recentResolved.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final resolvedAt = (data['resolvedAt'] as Timestamp?)?.toDate();

          if (createdAt != null && resolvedAt != null) {
            totalHours += resolvedAt.difference(createdAt).inHours;
            count++;
          }
        }

        if (count > 0) {
          avgResolutionHours = totalHours / count;
        }
      }

      return {
        'open': openCount.count ?? 0,
        'resolved': resolvedCount.count ?? 0,
        'escalated': escalatedCount.count ?? 0,
        'avgResolutionHours': avgResolutionHours,
      };
    } catch (e) {
      debugPrint('Error getting dispute stats: $e');
      return {
        'open': 0,
        'resolved': 0,
        'escalated': 0,
        'avgResolutionHours': 0.0,
      };
    }
  }

  /// Get all open disputes (admin)
  Future<List<ReportModel>> getOpenDisputes({int limit = 50}) async {
    try {
      final snapshot = await _disputesRef
          .where('status', whereIn: [
            ReportStatus.pending.name,
            ReportStatus.investigating.name,
          ])
          .orderBy('severity', descending: true)
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting open disputes: $e');
      return [];
    }
  }

  /// Get escalated disputes (admin)
  Future<List<ReportModel>> getEscalatedDisputes({int limit = 50}) async {
    try {
      final snapshot = await _disputesRef
          .where('status', isEqualTo: ReportStatus.escalated.name)
          .orderBy('escalatedAt', descending: false)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting escalated disputes: $e');
      return [];
    }
  }
}
