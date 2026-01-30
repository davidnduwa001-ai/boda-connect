import 'package:boda_connect/core/services/file_upload/file_upload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report_model.dart';

class ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== SUBMIT REPORTS ====================

  /// Submit a new report
  Future<String?> submitReport({
    required String reporterId,
    required String reporterType,
    required String reportedId,
    required String reportedType,
    String? bookingId,
    String? reviewId,
    String? chatId,
    required ReportCategory category,
    required String reason,
    List<XFile>? evidenceFiles,
  }) async {
    try {
      // Upload evidence if provided
      List<String> evidenceUrls = [];
      if (evidenceFiles != null && evidenceFiles.isNotEmpty) {
        evidenceUrls = await _uploadEvidence(reportedId, evidenceFiles);
      }

      // Auto-determine severity based on category
      final severity = ReportCategoryInfo.getSuggestedSeverity(category);

      final now = DateTime.now();
      final report = ReportModel(
        id: '', // Firestore will generate
        reporterId: reporterId,
        reporterType: reporterType,
        reportedId: reportedId,
        reportedType: reportedType,
        bookingId: bookingId,
        reviewId: reviewId,
        chatId: chatId,
        category: category,
        severity: severity,
        reason: reason,
        evidence: evidenceUrls,
        status: ReportStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('reports')
          .add(report.toFirestore());

      // If critical severity, trigger immediate notification
      if (severity == ReportSeverity.critical) {
        await _handleCriticalReport(docRef.id, report);
      }

      debugPrint('✅ Report submitted: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error submitting report: $e');
      return null;
    }
  }

  /// Upload evidence files to Firebase Storage
  Future<List<String>> _uploadEvidence(String reportedId, List<XFile> files) async {
    final urls = <String>[];

    for (int i = 0; i < files.length; i++) {
      try {
        final fileName = 'evidence_${reportedId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = _storage.ref().child('reports/$reportedId/$fileName');

        final bytes = await fileUploadHelper.readAsBytes(files[i]);
        await ref.putData(bytes);
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        debugPrint('❌ Error uploading evidence: $e');
      }
    }

    return urls;
  }

  /// Handle critical reports with immediate actions
  Future<void> _handleCriticalReport(String reportId, ReportModel report) async {
    try {
      debugPrint('🚨 Critical report received: $reportId');

      // 1. Auto-suspend reported user pending investigation
      await _autoSuspendUser(
        userId: report.reportedId,
        userType: report.reportedType,
        reportId: reportId,
        reason: 'Suspensão automática devido a denúncia crítica: ${report.category.name}',
      );

      // 2. Send notification to admins
      await _notifyAdmins(reportId, report);

      // 3. Send notification to reported user
      await _notifyReportedUser(report.reportedId, reportId);

      // 4. Create incident record
      await _firestore.collection('incidents').add({
        'reportId': reportId,
        'reportedId': report.reportedId,
        'reportedType': report.reportedType,
        'category': report.category.name,
        'severity': report.severity.name,
        'autoSuspended': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Critical report handled: User suspended, admins notified');
    } catch (e) {
      debugPrint('❌ Error handling critical report: $e');
    }
  }

  /// Auto-suspend a user due to critical report
  Future<void> _autoSuspendUser({
    required String userId,
    required String userType,
    required String reportId,
    required String reason,
  }) async {
    try {
      final suspensionData = {
        'isActive': false,
        'isSuspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspensionReason': reason,
        'suspensionType': 'auto_critical_report',
        'suspensionReportId': reportId,
        'suspensionExpiresAt': null, // Indefinite until reviewed
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update user document
      await _firestore.collection('users').doc(userId).update(suspensionData);

      // If supplier, also update supplier document
      if (userType == 'supplier') {
        final supplierQuery = await _firestore
            .collection('suppliers')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();

        if (supplierQuery.docs.isNotEmpty) {
          await supplierQuery.docs.first.reference.update({
            'isActive': false,
            'isSuspended': true,
            'suspendedAt': FieldValue.serverTimestamp(),
            'suspensionReason': reason,
          });
        }
      }

      // Create suspension record
      await _firestore.collection('suspensions').add({
        'userId': userId,
        'userType': userType,
        'reportId': reportId,
        'reason': reason,
        'type': 'auto_critical_report',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
      });

      debugPrint('✅ User auto-suspended: $userId');
    } catch (e) {
      debugPrint('❌ Error auto-suspending user: $e');
    }
  }

  /// Notify admins about critical report
  Future<void> _notifyAdmins(String reportId, ReportModel report) async {
    try {
      // Get all admin users
      final adminsQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminsQuery.docs) {
        await _firestore.collection('notifications').add({
          'userId': adminDoc.id,
          'type': 'critical_report',
          'title': '🚨 Denúncia Crítica',
          'body': 'Nova denúncia crítica requer atenção imediata. '
              'Categoria: ${_getCategoryLabel(report.category)}',
          'data': {
            'reportId': reportId,
            'reportedId': report.reportedId,
            'category': report.category.name,
          },
          'isRead': false,
          'priority': 'high',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ Admins notified about critical report');
    } catch (e) {
      debugPrint('❌ Error notifying admins: $e');
    }
  }

  /// Notify reported user about suspension
  Future<void> _notifyReportedUser(String userId, String reportId) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'account_suspended',
        'title': 'Conta Suspensa',
        'body': 'Sua conta foi temporariamente suspensa devido a uma denúncia. '
            'Entre em contato com o suporte para mais informações.',
        'data': {
          'reportId': reportId,
          'action': 'view_suspension',
        },
        'isRead': false,
        'priority': 'high',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User notified about suspension: $userId');
    } catch (e) {
      debugPrint('❌ Error notifying user: $e');
    }
  }

  /// Get category label in Portuguese
  String _getCategoryLabel(ReportCategory category) {
    switch (category) {
      case ReportCategory.harassment:
        return 'Assédio';
      case ReportCategory.discrimination:
        return 'Discriminação';
      case ReportCategory.unprofessional:
        return 'Comportamento Não Profissional';
      case ReportCategory.threatening:
        return 'Ameaça';
      case ReportCategory.noShow:
        return 'Não Compareceu';
      case ReportCategory.poorQuality:
        return 'Baixa Qualidade';
      case ReportCategory.overcharging:
        return 'Cobrança Excessiva';
      case ReportCategory.underdelivery:
        return 'Entrega Incompleta';
      case ReportCategory.spam:
        return 'Spam';
      case ReportCategory.fraud:
        return 'Fraude';
      case ReportCategory.fakeProfile:
        return 'Perfil Falso';
      case ReportCategory.scam:
        return 'Golpe';
      case ReportCategory.safetyThreat:
        return 'Ameaça à Segurança';
      case ReportCategory.violence:
        return 'Violência';
      case ReportCategory.inappropriate:
        return 'Conteúdo Inapropriado';
      case ReportCategory.other:
        return 'Outro';
    }
  }

  // ==================== QUERY REPORTS ====================

  /// Get reports submitted by a user
  Future<List<ReportModel>> getReportsByUser({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching reports by user: $e');
      return [];
    }
  }

  /// Get reports against a user
  Future<List<ReportModel>> getReportsAgainstUser({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reportedId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching reports against user: $e');
      return [];
    }
  }

  /// Get reports for a specific booking
  Future<List<ReportModel>> getReportsForBooking(String bookingId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('bookingId', isEqualTo: bookingId)
          .get();

      return snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching booking reports: $e');
      return [];
    }
  }

  /// Get pending reports (admin view)
  Future<List<ReportModel>> getPendingReports({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: ReportStatus.pending.name)
          .orderBy('severity', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching pending reports: $e');
      return [];
    }
  }

  /// Get reports by status
  Future<List<ReportModel>> getReportsByStatus({
    required ReportStatus status,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching reports by status: $e');
      return [];
    }
  }

  /// Get a specific report
  Future<ReportModel?> getReport(String reportId) async {
    try {
      final doc = await _firestore.collection('reports').doc(reportId).get();
      if (doc.exists) {
        return ReportModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching report: $e');
      return null;
    }
  }

  // ==================== UPDATE REPORTS ====================

  /// Update report status (admin action)
  Future<bool> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    String? resolution,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (resolution != null) {
        updates['resolution'] = resolution;
      }

      if (status == ReportStatus.resolved || status == ReportStatus.dismissed) {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('reports').doc(reportId).update(updates);

      debugPrint('✅ Report status updated: $reportId -> ${status.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating report status: $e');
      return false;
    }
  }

  /// Assign report to admin/moderator
  Future<bool> assignReport({
    required String reportId,
    required String adminId,
  }) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'assignedTo': adminId,
        'status': ReportStatus.investigating.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Report assigned: $reportId -> $adminId');
      return true;
    } catch (e) {
      debugPrint('❌ Error assigning report: $e');
      return false;
    }
  }

  /// Add action taken on a report
  Future<bool> addActionTaken({
    required String reportId,
    required String action,
  }) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'actionsTaken': FieldValue.arrayUnion([action]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Action added to report: $reportId -> $action');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding action: $e');
      return false;
    }
  }

  /// Escalate report to higher authority
  Future<bool> escalateReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': ReportStatus.escalated.name,
        'severity': ReportSeverity.critical.name, // Upgrade severity
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Report escalated: $reportId');
      return true;
    } catch (e) {
      debugPrint('❌ Error escalating report: $e');
      return false;
    }
  }

  // ==================== STATISTICS ====================

  /// Get report statistics for a user
  Future<ReportStats> getUserReportStats(String userId) async {
    try {
      final reports = await getReportsAgainstUser(userId: userId, limit: 1000);

      final totalReports = reports.length;
      final pendingCount = reports.where((r) => r.status == ReportStatus.pending).length;
      final resolvedCount = reports.where((r) => r.status == ReportStatus.resolved).length;
      final dismissedCount = reports.where((r) => r.status == ReportStatus.dismissed).length;

      // Count by severity
      final criticalCount = reports.where((r) => r.severity == ReportSeverity.critical).length;
      final highCount = reports.where((r) => r.severity == ReportSeverity.high).length;
      final mediumCount = reports.where((r) => r.severity == ReportSeverity.medium).length;
      final lowCount = reports.where((r) => r.severity == ReportSeverity.low).length;

      // Count by category
      final categoryBreakdown = <ReportCategory, int>{};
      for (final report in reports) {
        categoryBreakdown[report.category] = (categoryBreakdown[report.category] ?? 0) + 1;
      }

      return ReportStats(
        totalReports: totalReports,
        pendingCount: pendingCount,
        resolvedCount: resolvedCount,
        dismissedCount: dismissedCount,
        criticalCount: criticalCount,
        highCount: highCount,
        mediumCount: mediumCount,
        lowCount: lowCount,
        categoryBreakdown: categoryBreakdown,
      );
    } catch (e) {
      debugPrint('❌ Error calculating report stats: $e');
      return const ReportStats(
        totalReports: 0,
        pendingCount: 0,
        resolvedCount: 0,
        dismissedCount: 0,
        criticalCount: 0,
        highCount: 0,
        mediumCount: 0,
        lowCount: 0,
        categoryBreakdown: {},
      );
    }
  }

  /// Check if user has active (unresolved) reports
  Future<bool> hasActiveReports(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reportedId', isEqualTo: userId)
          .where('status', whereIn: [
            ReportStatus.pending.name,
            ReportStatus.investigating.name,
            ReportStatus.escalated.name,
          ])
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking active reports: $e');
      return false;
    }
  }

  /// Get count of critical reports for a user
  Future<int> getCriticalReportCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reportedId', isEqualTo: userId)
          .where('severity', isEqualTo: ReportSeverity.critical.name)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error counting critical reports: $e');
      return 0;
    }
  }
}

// ==================== REPORT STATS CLASS ====================

class ReportStats {
  final int totalReports;
  final int pendingCount;
  final int resolvedCount;
  final int dismissedCount;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final Map<ReportCategory, int> categoryBreakdown;

  const ReportStats({
    required this.totalReports,
    required this.pendingCount,
    required this.resolvedCount,
    required this.dismissedCount,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.categoryBreakdown,
  });

  /// Get percentage of reports that are critical/high severity
  double get highSeverityPercentage {
    if (totalReports == 0) return 0.0;
    return (criticalCount + highCount) / totalReports;
  }

  /// Get most common report category
  ReportCategory? get mostCommonCategory {
    if (categoryBreakdown.isEmpty) return null;
    return categoryBreakdown.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}
