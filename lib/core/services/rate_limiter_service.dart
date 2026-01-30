import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'audit_service.dart';

/// Rate limiting service to prevent brute force attacks and API abuse
/// Critical for SOC 2 compliance and enterprise security
class RateLimiterService {
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditService _auditService = AuditService();

  // In-memory cache for rate limiting (faster than Firestore)
  final Map<String, List<DateTime>> _localCache = {};

  // Rate limit configurations
  static const Map<RateLimitType, RateLimitConfig> _configs = {
    // Authentication limits
    RateLimitType.login: RateLimitConfig(
      maxAttempts: 5,
      windowSeconds: 300, // 5 minutes
      lockoutSeconds: 900, // 15 minutes
    ),
    RateLimitType.otpRequest: RateLimitConfig(
      maxAttempts: 3,
      windowSeconds: 60, // 1 minute
      lockoutSeconds: 300, // 5 minutes
    ),
    RateLimitType.otpVerify: RateLimitConfig(
      maxAttempts: 5,
      windowSeconds: 300, // 5 minutes
      lockoutSeconds: 1800, // 30 minutes
    ),
    RateLimitType.passwordReset: RateLimitConfig(
      maxAttempts: 3,
      windowSeconds: 3600, // 1 hour
      lockoutSeconds: 3600, // 1 hour
    ),

    // API limits
    RateLimitType.apiCall: RateLimitConfig(
      maxAttempts: 100,
      windowSeconds: 60, // 1 minute
      lockoutSeconds: 60, // 1 minute
    ),
    RateLimitType.search: RateLimitConfig(
      maxAttempts: 30,
      windowSeconds: 60, // 1 minute
      lockoutSeconds: 60, // 1 minute
    ),
    RateLimitType.messagesSend: RateLimitConfig(
      maxAttempts: 20,
      windowSeconds: 60, // 1 minute
      lockoutSeconds: 300, // 5 minutes
    ),

    // Booking limits
    RateLimitType.bookingCreate: RateLimitConfig(
      maxAttempts: 10,
      windowSeconds: 3600, // 1 hour
      lockoutSeconds: 3600, // 1 hour
    ),

    // Payment limits
    RateLimitType.paymentAttempt: RateLimitConfig(
      maxAttempts: 5,
      windowSeconds: 3600, // 1 hour
      lockoutSeconds: 3600, // 1 hour
    ),

    // Review limits
    RateLimitType.reviewSubmit: RateLimitConfig(
      maxAttempts: 5,
      windowSeconds: 86400, // 24 hours
      lockoutSeconds: 86400, // 24 hours
    ),
  };

  /// Check if action is allowed (not rate limited)
  Future<RateLimitResult> checkRateLimit({
    required String identifier, // userId, IP, or phone
    required RateLimitType type,
    bool recordAttempt = true,
  }) async {
    final config = _configs[type]!;
    final key = '${type.name}:$identifier';
    final now = DateTime.now();

    try {
      // Check local cache first (faster)
      if (_localCache.containsKey(key)) {
        final attempts = _localCache[key]!;
        final windowStart = now.subtract(Duration(seconds: config.windowSeconds));

        // Remove old attempts outside window
        attempts.removeWhere((t) => t.isBefore(windowStart));

        if (attempts.length >= config.maxAttempts) {
          final oldestAttempt = attempts.first;
          final unlockTime = oldestAttempt.add(Duration(seconds: config.lockoutSeconds));

          if (now.isBefore(unlockTime)) {
            final remainingSeconds = unlockTime.difference(now).inSeconds;

            // Log rate limit exceeded
            await _auditService.logSecurityEvent(
              userId: identifier,
              eventType: SecurityEventType.rateLimitExceeded,
              description: 'Rate limit exceeded for ${type.name}',
              metadata: {
                'type': type.name,
                'attempts': attempts.length,
                'remainingLockout': remainingSeconds,
              },
              severity: type == RateLimitType.login || type == RateLimitType.otpVerify
                  ? SecuritySeverity.warning
                  : SecuritySeverity.info,
            );

            return RateLimitResult(
              allowed: false,
              remainingAttempts: 0,
              retryAfterSeconds: remainingSeconds,
              reason: 'Rate limit exceeded. Try again in ${_formatDuration(remainingSeconds)}.',
            );
          }

          // Lockout expired, clear attempts
          attempts.clear();
        }

        if (recordAttempt) {
          attempts.add(now);
        }

        return RateLimitResult(
          allowed: true,
          remainingAttempts: config.maxAttempts - attempts.length,
          retryAfterSeconds: 0,
        );
      }

      // Initialize cache for this key
      if (recordAttempt) {
        _localCache[key] = [now];
      } else {
        _localCache[key] = [];
      }

      return RateLimitResult(
        allowed: true,
        remainingAttempts: config.maxAttempts - 1,
        retryAfterSeconds: 0,
      );
    } catch (e) {
      debugPrint('❌ Rate limit check failed: $e');
      // Fail open - allow the request if rate limiting fails
      return RateLimitResult(
        allowed: true,
        remainingAttempts: config.maxAttempts,
        retryAfterSeconds: 0,
      );
    }
  }

  /// Record a failed attempt (e.g., failed login)
  Future<void> recordFailedAttempt({
    required String identifier,
    required RateLimitType type,
  }) async {
    await checkRateLimit(
      identifier: identifier,
      type: type,
      recordAttempt: true,
    );
  }

  /// Clear rate limit for an identifier (e.g., after successful login)
  void clearRateLimit({
    required String identifier,
    required RateLimitType type,
  }) {
    final key = '${type.name}:$identifier';
    _localCache.remove(key);
  }

  /// Check if user is currently locked out
  Future<bool> isLockedOut({
    required String identifier,
    required RateLimitType type,
  }) async {
    final result = await checkRateLimit(
      identifier: identifier,
      type: type,
      recordAttempt: false,
    );
    return !result.allowed;
  }

  /// Get remaining attempts for an identifier
  Future<int> getRemainingAttempts({
    required String identifier,
    required RateLimitType type,
  }) async {
    final result = await checkRateLimit(
      identifier: identifier,
      type: type,
      recordAttempt: false,
    );
    return result.remainingAttempts;
  }

  /// Persist rate limit to Firestore (for distributed rate limiting)
  Future<void> persistRateLimit({
    required String identifier,
    required RateLimitType type,
  }) async {
    final key = '${type.name}:$identifier';
    final attempts = _localCache[key] ?? [];

    try {
      await _firestore.collection('rate_limits').doc(key).set({
        'identifier': identifier,
        'type': type.name,
        'attempts': attempts.map((t) => Timestamp.fromDate(t)).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Failed to persist rate limit: $e');
    }
  }

  /// Load rate limit from Firestore
  Future<void> loadRateLimit({
    required String identifier,
    required RateLimitType type,
  }) async {
    final key = '${type.name}:$identifier';

    try {
      final doc = await _firestore.collection('rate_limits').doc(key).get();
      if (doc.exists) {
        final data = doc.data()!;
        final attempts = (data['attempts'] as List<dynamic>?)
            ?.map((t) => (t as Timestamp).toDate())
            .toList() ?? [];
        _localCache[key] = attempts;
      }
    } catch (e) {
      debugPrint('❌ Failed to load rate limit: $e');
    }
  }

  /// Format duration for user-friendly message
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes minute${minutes > 1 ? 's' : ''}';
    } else {
      final hours = seconds ~/ 3600;
      return '$hours hour${hours > 1 ? 's' : ''}';
    }
  }

  /// Clear all cached rate limits (for testing)
  void clearAllCaches() {
    _localCache.clear();
  }
}

/// Rate limit types
enum RateLimitType {
  // Authentication
  login,
  otpRequest,
  otpVerify,
  passwordReset,

  // API
  apiCall,
  search,
  messagesSend,

  // Business operations
  bookingCreate,
  paymentAttempt,
  reviewSubmit,
}

/// Rate limit configuration
class RateLimitConfig {
  final int maxAttempts;
  final int windowSeconds;
  final int lockoutSeconds;

  const RateLimitConfig({
    required this.maxAttempts,
    required this.windowSeconds,
    required this.lockoutSeconds,
  });
}

/// Rate limit check result
class RateLimitResult {
  final bool allowed;
  final int remainingAttempts;
  final int retryAfterSeconds;
  final String? reason;

  RateLimitResult({
    required this.allowed,
    required this.remainingAttempts,
    required this.retryAfterSeconds,
    this.reason,
  });
}
