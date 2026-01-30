import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'audit_service.dart';
import 'rate_limiter_service.dart';

/// Comprehensive security service for enterprise-grade protection
/// Implements SOC 2 controls and security best practices
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final AuditService _auditService = AuditService();
  final RateLimiterService _rateLimiter = RateLimiterService();

  // Session configuration
  static const int sessionTimeoutMinutes = 30; // 30 minutes idle timeout
  static const int maxConcurrentSessions = 3;
  static const int tokenRefreshIntervalMinutes = 15;

  DateTime? _lastActivity;
  String? _currentSessionId;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Initialize security service
  Future<void> initialize() async {
    _lastActivity = DateTime.now();
    debugPrint('✅ Security service initialized');
  }

  /// Record user activity (for session timeout)
  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  /// Check if session has timed out
  bool isSessionTimedOut() {
    if (_lastActivity == null) return true;
    final elapsed = DateTime.now().difference(_lastActivity!);
    return elapsed.inMinutes >= sessionTimeoutMinutes;
  }

  /// Create a new session
  Future<String> createSession({
    required String userId,
    required String deviceId,
    String? deviceName,
    String? platform,
    String? ipAddress,
  }) async {
    try {
      // Check concurrent sessions
      final existingSessions = await _firestore
          .collection('user_sessions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      // If too many sessions, invalidate the oldest one
      if (existingSessions.docs.length >= maxConcurrentSessions) {
        final oldestSession = existingSessions.docs.reduce((a, b) {
          final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return aTime.isBefore(bTime) ? a : b;
        });

        await oldestSession.reference.update({
          'isActive': false,
          'terminatedAt': FieldValue.serverTimestamp(),
          'terminationReason': 'new_session_limit',
        });

        await _auditService.logSecurityEvent(
          userId: userId,
          eventType: SecurityEventType.multipleDeviceLogin,
          description: 'Oldest session terminated due to concurrent session limit',
          metadata: {'terminatedSessionId': oldestSession.id},
        );
      }

      // Create new session
      final sessionDoc = await _firestore.collection('user_sessions').add({
        'userId': userId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'ipAddress': ipAddress,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      _currentSessionId = sessionDoc.id;
      _lastActivity = DateTime.now();

      // Store session ID securely
      await _secureStorage.write(
        key: 'current_session_id',
        value: sessionDoc.id,
      );

      await _auditService.logAuthEvent(
        userId: userId,
        eventType: AuthEventType.login,
        method: 'session_created',
        deviceId: deviceId,
        ipAddress: ipAddress,
        metadata: {'sessionId': sessionDoc.id},
      );

      return sessionDoc.id;
    } catch (e) {
      debugPrint('❌ Failed to create session: $e');
      rethrow;
    }
  }

  /// Update session activity
  Future<void> updateSessionActivity(String sessionId) async {
    try {
      await _firestore.collection('user_sessions').doc(sessionId).update({
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
      _lastActivity = DateTime.now();
    } catch (e) {
      debugPrint('❌ Failed to update session activity: $e');
    }
  }

  /// Terminate a session
  Future<void> terminateSession({
    required String sessionId,
    String reason = 'user_logout',
  }) async {
    try {
      final sessionDoc = await _firestore
          .collection('user_sessions')
          .doc(sessionId)
          .get();

      if (sessionDoc.exists) {
        await sessionDoc.reference.update({
          'isActive': false,
          'terminatedAt': FieldValue.serverTimestamp(),
          'terminationReason': reason,
        });

        final userId = sessionDoc.data()?['userId'] as String?;
        if (userId != null) {
          await _auditService.logAuthEvent(
            userId: userId,
            eventType: AuthEventType.logout,
            method: reason,
            metadata: {'sessionId': sessionId},
          );
        }
      }

      await _secureStorage.delete(key: 'current_session_id');
      _currentSessionId = null;
    } catch (e) {
      debugPrint('❌ Failed to terminate session: $e');
    }
  }

  /// Terminate all sessions for a user (security measure)
  Future<void> terminateAllSessions({
    required String userId,
    String reason = 'security_logout',
    String? exceptSessionId,
  }) async {
    try {
      final sessions = await _firestore
          .collection('user_sessions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final session in sessions.docs) {
        if (exceptSessionId != null && session.id == exceptSessionId) continue;

        batch.update(session.reference, {
          'isActive': false,
          'terminatedAt': FieldValue.serverTimestamp(),
          'terminationReason': reason,
        });
      }

      await batch.commit();

      await _auditService.logSecurityEvent(
        userId: userId,
        eventType: SecurityEventType.accountTakeover,
        description: 'All sessions terminated: $reason',
        severity: SecuritySeverity.warning,
      );
    } catch (e) {
      debugPrint('❌ Failed to terminate all sessions: $e');
    }
  }

  /// Get active sessions for a user
  Future<List<Map<String, dynamic>>> getActiveSessions(String userId) async {
    try {
      final sessions = await _firestore
          .collection('user_sessions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('lastActivityAt', descending: true)
          .get();

      return sessions.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to get active sessions: $e');
      return [];
    }
  }

  /// Validate input for security (XSS, SQL injection prevention)
  String sanitizeInput(String input) {
    // Remove potentially dangerous characters
    String sanitized = input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .trim();

    // Limit length
    if (sanitized.length > 10000) {
      sanitized = sanitized.substring(0, 10000);
    }

    return sanitized;
  }

  /// Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate phone number format (Angola/Portugal)
  bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return RegExp(r'^\+?(244|351)?\d{9}$').hasMatch(cleaned);
  }

  /// Check password strength
  PasswordStrength checkPasswordStrength(String password) {
    if (password.length < 8) {
      return PasswordStrength.weak;
    }

    int score = 0;

    // Length bonus
    if (password.length >= 12) score += 2;
    else if (password.length >= 10) score += 1;

    // Character variety
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    // Common patterns (negative)
    if (RegExp(r'(123|abc|qwerty|password)', caseSensitive: false).hasMatch(password)) {
      score -= 2;
    }

    if (score >= 5) return PasswordStrength.strong;
    if (score >= 3) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  /// Check for suspicious login attempt
  Future<bool> isSuspiciousLogin({
    required String userId,
    String? ipAddress,
    String? deviceId,
    String? location,
  }) async {
    try {
      // Get user's recent login history
      final recentLogins = await _firestore
          .collection('audit_logs')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'authentication')
          .where('eventType', isEqualTo: 'login')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (recentLogins.docs.isEmpty) return false;

      // Check for new device
      final knownDevices = recentLogins.docs
          .map((doc) => doc.data()['deviceId'] as String?)
          .where((d) => d != null)
          .toSet();

      if (deviceId != null && !knownDevices.contains(deviceId)) {
        // New device - flag as suspicious
        await _auditService.logSecurityEvent(
          userId: userId,
          eventType: SecurityEventType.suspiciousLogin,
          description: 'Login from new device',
          metadata: {'deviceId': deviceId, 'ipAddress': ipAddress},
          severity: SecuritySeverity.warning,
        );
        return true;
      }

      // Check for rapid location change (impossible travel)
      // This would require geolocation data - simplified here

      return false;
    } catch (e) {
      debugPrint('❌ Failed to check suspicious login: $e');
      return false;
    }
  }

  /// Lock account after too many failed attempts
  Future<void> lockAccount({
    required String userId,
    required String reason,
    int? lockDurationMinutes,
  }) async {
    try {
      final lockUntil = lockDurationMinutes != null
          ? DateTime.now().add(Duration(minutes: lockDurationMinutes))
          : null;

      await _firestore.collection('users').doc(userId).update({
        'isLocked': true,
        'lockedAt': FieldValue.serverTimestamp(),
        'lockReason': reason,
        'lockUntil': lockUntil != null ? Timestamp.fromDate(lockUntil) : null,
      });

      await _auditService.logAuthEvent(
        userId: userId,
        eventType: AuthEventType.accountLocked,
        method: 'security_lock',
        metadata: {'reason': reason, 'lockDurationMinutes': lockDurationMinutes},
        success: true,
      );

      // Terminate all active sessions
      await terminateAllSessions(userId: userId, reason: 'account_locked');
    } catch (e) {
      debugPrint('❌ Failed to lock account: $e');
    }
  }

  /// Unlock account
  Future<void> unlockAccount({
    required String userId,
    required String adminId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isLocked': false,
        'lockedAt': null,
        'lockReason': null,
        'lockUntil': null,
        'unlockedAt': FieldValue.serverTimestamp(),
        'unlockedBy': adminId,
      });

      await _auditService.logAdminAction(
        adminId: adminId,
        actionType: AdminActionType.userReactivated,
        targetType: 'user',
        targetId: userId,
        reason: reason,
      );

      // Clear rate limits
      _rateLimiter.clearRateLimit(
        identifier: userId,
        type: RateLimitType.login,
      );
    } catch (e) {
      debugPrint('❌ Failed to unlock account: $e');
    }
  }

  /// Check if account is locked
  Future<bool> isAccountLocked(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data()!;
      final isLocked = data['isLocked'] as bool? ?? false;

      if (!isLocked) return false;

      // Check if lock has expired
      final lockUntil = data['lockUntil'] as Timestamp?;
      if (lockUntil != null && lockUntil.toDate().isBefore(DateTime.now())) {
        // Lock expired, unlock automatically
        await _firestore.collection('users').doc(userId).update({
          'isLocked': false,
          'lockedAt': null,
          'lockReason': null,
          'lockUntil': null,
        });
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to check account lock status: $e');
      return false;
    }
  }

  /// Generate security report for admin
  Future<Map<String, dynamic>> generateSecurityReport() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      final last7Days = now.subtract(const Duration(days: 7));

      // Failed logins in last 24 hours
      final failedLogins24h = await _firestore
          .collection('audit_logs')
          .where('category', isEqualTo: 'authentication')
          .where('success', isEqualTo: false)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last24Hours))
          .count()
          .get();

      // Security events in last 7 days
      final securityEvents7d = await _firestore
          .collection('audit_logs')
          .where('category', isEqualTo: 'security')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last7Days))
          .count()
          .get();

      // Locked accounts
      final lockedAccounts = await _firestore
          .collection('users')
          .where('isLocked', isEqualTo: true)
          .count()
          .get();

      // Active sessions
      final activeSessions = await _firestore
          .collection('user_sessions')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      return {
        'generatedAt': now.toIso8601String(),
        'metrics': {
          'failedLoginsLast24h': failedLogins24h.count ?? 0,
          'securityEventsLast7d': securityEvents7d.count ?? 0,
          'lockedAccounts': lockedAccounts.count ?? 0,
          'activeSessions': activeSessions.count ?? 0,
        },
        'status': 'operational',
      };
    } catch (e) {
      debugPrint('❌ Failed to generate security report: $e');
      return {'error': 'Failed to generate report'};
    }
  }
}

/// Password strength levels
enum PasswordStrength {
  weak,
  medium,
  strong,
}
