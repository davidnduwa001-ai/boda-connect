import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Enterprise-grade audit logging service for SOC 2 compliance
/// Tracks all security-relevant events for compliance and forensics
class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Audit log collection
  CollectionReference get _auditLogs => _firestore.collection('audit_logs');

  /// Log authentication events
  Future<void> logAuthEvent({
    required String userId,
    required AuthEventType eventType,
    required String method,
    String? ipAddress,
    String? userAgent,
    String? deviceId,
    Map<String, dynamic>? metadata,
    bool success = true,
    String? failureReason,
  }) async {
    try {
      await _auditLogs.add({
        'category': 'authentication',
        'eventType': eventType.name,
        'userId': userId,
        'method': method,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'deviceId': deviceId,
        'success': success,
        'failureReason': failureReason,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'severity': success ? 'info' : 'warning',
      });
    } catch (e) {
      debugPrint('❌ Failed to log auth event: $e');
    }
  }

  /// Log data access events (for sensitive data)
  Future<void> logDataAccess({
    required String userId,
    required String resourceType,
    required String resourceId,
    required DataAccessType accessType,
    List<String>? fieldsAccessed,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _auditLogs.add({
        'category': 'data_access',
        'eventType': accessType.name,
        'userId': userId,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'fieldsAccessed': fieldsAccessed ?? [],
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'info',
      });
    } catch (e) {
      debugPrint('❌ Failed to log data access: $e');
    }
  }

  /// Log admin actions (critical for compliance)
  Future<void> logAdminAction({
    required String adminId,
    required AdminActionType actionType,
    required String targetType,
    required String targetId,
    String? reason,
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _auditLogs.add({
        'category': 'admin_action',
        'eventType': actionType.name,
        'adminId': adminId,
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'beforeState': beforeState,
        'afterState': afterState,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'critical',
      });
    } catch (e) {
      debugPrint('❌ Failed to log admin action: $e');
    }
  }

  /// Log security events (suspicious activity)
  Future<void> logSecurityEvent({
    required String userId,
    required SecurityEventType eventType,
    required String description,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
    SecuritySeverity severity = SecuritySeverity.warning,
  }) async {
    try {
      await _auditLogs.add({
        'category': 'security',
        'eventType': eventType.name,
        'userId': userId,
        'description': description,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'severity': severity.name,
      });

      // Alert on critical security events
      if (severity == SecuritySeverity.critical) {
        await _createSecurityAlert(userId, eventType, description);
      }
    } catch (e) {
      debugPrint('❌ Failed to log security event: $e');
    }
  }

  /// Log payment/financial events
  Future<void> logPaymentEvent({
    required String userId,
    required PaymentEventType eventType,
    required String transactionId,
    required double amount,
    required String currency,
    String? paymentMethod,
    bool success = true,
    String? failureReason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _auditLogs.add({
        'category': 'payment',
        'eventType': eventType.name,
        'userId': userId,
        'transactionId': transactionId,
        'amount': amount,
        'currency': currency,
        'paymentMethod': paymentMethod,
        'success': success,
        'failureReason': failureReason,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'severity': success ? 'info' : 'warning',
      });
    } catch (e) {
      debugPrint('❌ Failed to log payment event: $e');
    }
  }

  /// Log data modification events
  Future<void> logDataModification({
    required String userId,
    required String resourceType,
    required String resourceId,
    required DataModificationType modificationType,
    Map<String, dynamic>? changedFields,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _auditLogs.add({
        'category': 'data_modification',
        'eventType': modificationType.name,
        'userId': userId,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'changedFields': changedFields ?? {},
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'info',
      });
    } catch (e) {
      debugPrint('❌ Failed to log data modification: $e');
    }
  }

  /// Create security alert for critical events
  Future<void> _createSecurityAlert(
    String userId,
    SecurityEventType eventType,
    String description,
  ) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': 'security_alert',
        'userId': userId,
        'eventType': eventType.name,
        'description': description,
        'isRead': false,
        'priority': 'high',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Failed to create security alert: $e');
    }
  }

  /// Get audit logs for a user (admin function)
  Future<List<Map<String, dynamic>>> getUserAuditLogs(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    int limit = 100,
  }) async {
    try {
      Query query = _auditLogs.where('userId', isEqualTo: userId);

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get user audit logs: $e');
      return [];
    }
  }

  /// Get security events (admin function)
  Future<List<Map<String, dynamic>>> getSecurityEvents({
    DateTime? startDate,
    DateTime? endDate,
    SecuritySeverity? minSeverity,
    int limit = 100,
  }) async {
    try {
      Query query = _auditLogs.where('category', isEqualTo: 'security');

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get security events: $e');
      return [];
    }
  }

  /// Generate compliance report
  Future<Map<String, dynamic>> generateComplianceReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);

      // Count events by category
      final authEvents = await _auditLogs
          .where('category', isEqualTo: 'authentication')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .count()
          .get();

      final securityEvents = await _auditLogs
          .where('category', isEqualTo: 'security')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .count()
          .get();

      final adminActions = await _auditLogs
          .where('category', isEqualTo: 'admin_action')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .count()
          .get();

      final dataAccess = await _auditLogs
          .where('category', isEqualTo: 'data_access')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .count()
          .get();

      final failedLogins = await _auditLogs
          .where('category', isEqualTo: 'authentication')
          .where('success', isEqualTo: false)
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .count()
          .get();

      return {
        'reportPeriod': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'generatedAt': DateTime.now().toIso8601String(),
        'summary': {
          'totalAuthEvents': authEvents.count ?? 0,
          'totalSecurityEvents': securityEvents.count ?? 0,
          'totalAdminActions': adminActions.count ?? 0,
          'totalDataAccessEvents': dataAccess.count ?? 0,
          'failedLoginAttempts': failedLogins.count ?? 0,
        },
        'complianceStatus': 'audit_logging_enabled',
      };
    } catch (e) {
      debugPrint('❌ Failed to generate compliance report: $e');
      return {'error': 'Failed to generate report'};
    }
  }
}

/// Authentication event types
enum AuthEventType {
  login,
  logout,
  loginFailed,
  passwordChanged,
  passwordResetRequested,
  mfaEnabled,
  mfaDisabled,
  sessionExpired,
  accountLocked,
  accountUnlocked,
  otpSent,
  otpVerified,
  otpFailed,
}

/// Data access types
enum DataAccessType {
  read,
  list,
  search,
  export,
}

/// Admin action types
enum AdminActionType {
  userSuspended,
  userReactivated,
  userDeleted,
  roleChanged,
  permissionGranted,
  permissionRevoked,
  documentApproved,
  documentRejected,
  supplierVerified,
  supplierSuspended,
  settingsChanged,
  disputeResolved,
  refundIssued,
}

/// Security event types
enum SecurityEventType {
  suspiciousLogin,
  bruteForceAttempt,
  unauthorizedAccess,
  dataExfiltration,
  privilegeEscalation,
  sessionHijacking,
  rateLimitExceeded,
  invalidToken,
  sqlInjectionAttempt,
  xssAttempt,
  csrfAttempt,
  accountTakeover,
  multipleDeviceLogin,
  // Admin 2FA events
  loginSuccess,
  loginFailure,
  sessionTerminated,
  twoFactorInitiated,
  twoFactorVerified,
  twoFactorFailed,
  deviceTrusted,
  deviceRemoved,
}

/// Security severity levels
enum SecuritySeverity {
  info,
  warning,
  critical,
}

/// Payment event types
enum PaymentEventType {
  paymentInitiated,
  paymentCompleted,
  paymentFailed,
  refundInitiated,
  refundCompleted,
  refundFailed,
  chargebackReceived,
  paymentMethodAdded,
  paymentMethodRemoved,
}

/// Data modification types
enum DataModificationType {
  create,
  update,
  delete,
  archive,
  restore,
}
