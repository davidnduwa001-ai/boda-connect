import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Rate Limit Metrics - READ-ONLY Admin Service
///
/// Fetches aggregated rate limit metrics from the backend.
/// This service NEVER writes data.
class RateLimitMetricsService {
  static final RateLimitMetricsService _instance = RateLimitMetricsService._internal();
  factory RateLimitMetricsService() => _instance;
  RateLimitMetricsService._internal();

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // Cache
  RateLimitMetrics? _cachedMetrics;
  DateTime? _lastFetchTime;
  static const _cacheTtl = Duration(minutes: 2);

  // Stream for auto-refresh
  final _metricsController = StreamController<RateLimitMetrics>.broadcast();
  Stream<RateLimitMetrics> get metricsStream => _metricsController.stream;

  Timer? _refreshTimer;
  bool _isRefreshing = false;

  /// Get metrics (with caching)
  Future<RateLimitMetrics> getMetrics({int hoursBack = 24}) async {
    // Check cache
    if (_cachedMetrics != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTtl) {
      return _cachedMetrics!;
    }

    return await _fetchMetrics(hoursBack: hoursBack);
  }

  /// Force refresh metrics
  Future<RateLimitMetrics> refreshMetrics({int hoursBack = 24}) async {
    return await _fetchMetrics(hoursBack: hoursBack);
  }

  /// Fetch metrics from Cloud Function
  Future<RateLimitMetrics> _fetchMetrics({int hoursBack = 24}) async {
    if (_isRefreshing) {
      // Return cached if available while refresh is in progress
      if (_cachedMetrics != null) return _cachedMetrics!;
    }

    _isRefreshing = true;

    try {
      final callable = _functions.httpsCallable(
        'exportRateLimitMetrics',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'hoursBack': hoursBack,
      });

      final data = result.data;
      final metrics = RateLimitMetrics.fromJson(data);

      // Update cache
      _cachedMetrics = metrics;
      _lastFetchTime = DateTime.now();

      // Notify listeners
      _metricsController.add(metrics);

      return metrics;
    } catch (e) {
      debugPrint('RateLimitMetricsService error: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Start auto-refresh (every 2 minutes)
  void startAutoRefresh({int hoursBack = 24}) {
    stopAutoRefresh();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _fetchMetrics(hoursBack: hoursBack);
    });
  }

  /// Stop auto-refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Clear cache
  void clearCache() {
    _cachedMetrics = null;
    _lastFetchTime = null;
  }

  /// Dispose
  void dispose() {
    stopAutoRefresh();
    _metricsController.close();
  }
}

/// Aggregated rate limit metrics
class RateLimitMetrics {
  final String generatedAt;
  final int hoursBack;
  final RateLimitTotals totals;
  final List<ActionBreakdown> actionBreakdown;
  final List<TopOffender> topOffenders;
  final List<HourlyTrend> hourlyTrend;
  final List<ConfiguredLimit> configuredLimits;

  RateLimitMetrics({
    required this.generatedAt,
    required this.hoursBack,
    required this.totals,
    required this.actionBreakdown,
    required this.topOffenders,
    required this.hourlyTrend,
    required this.configuredLimits,
  });

  factory RateLimitMetrics.fromJson(Map<String, dynamic> json) {
    return RateLimitMetrics(
      generatedAt: json['generatedAt'] ?? '',
      hoursBack: json['hoursBack'] ?? 24,
      totals: RateLimitTotals.fromJson(json['totals'] ?? {}),
      actionBreakdown: (json['actionBreakdown'] as List? ?? [])
          .map((e) => ActionBreakdown.fromJson(e))
          .toList(),
      topOffenders: (json['topOffenders'] as List? ?? [])
          .map((e) => TopOffender.fromJson(e))
          .toList(),
      hourlyTrend: (json['hourlyTrend'] as List? ?? [])
          .map((e) => HourlyTrend.fromJson(e))
          .toList(),
      configuredLimits: (json['configuredLimits'] as List? ?? [])
          .map((e) => ConfiguredLimit.fromJson(e))
          .toList(),
    );
  }

  /// Check if there are any rate limit violations
  bool get hasViolations => totals.activeRateLimits > 0;

  /// Get severity level based on violations
  String get severityLevel {
    if (totals.activeRateLimits == 0) return 'normal';
    if (totals.activeRateLimits <= 5) return 'low';
    if (totals.activeRateLimits <= 20) return 'medium';
    return 'high';
  }
}

/// Summary totals for rate limits
class RateLimitTotals {
  final int uniqueUsersLimited;
  final int totalHits;
  final int activeRateLimits;

  RateLimitTotals({
    required this.uniqueUsersLimited,
    required this.totalHits,
    required this.activeRateLimits,
  });

  factory RateLimitTotals.fromJson(Map<String, dynamic> json) {
    return RateLimitTotals(
      uniqueUsersLimited: json['uniqueUsersLimited'] ?? 0,
      totalHits: json['totalHits'] ?? 0,
      activeRateLimits: json['activeRateLimits'] ?? 0,
    );
  }
}

/// Breakdown by action type
class ActionBreakdown {
  final String action;
  final int hitCount;
  final int uniqueUsers;
  final int configuredLimit;
  final int windowSeconds;

  ActionBreakdown({
    required this.action,
    required this.hitCount,
    required this.uniqueUsers,
    required this.configuredLimit,
    required this.windowSeconds,
  });

  factory ActionBreakdown.fromJson(Map<String, dynamic> json) {
    return ActionBreakdown(
      action: json['action'] ?? '',
      hitCount: json['hitCount'] ?? 0,
      uniqueUsers: json['uniqueUsers'] ?? 0,
      configuredLimit: json['configuredLimit'] ?? 0,
      windowSeconds: json['windowSeconds'] ?? 0,
    );
  }

  /// Get human-readable action name
  String get displayName {
    switch (action) {
      case 'createBooking':
        return 'Criar Reserva';
      case 'createPaymentIntent':
        return 'Iniciar Pagamento';
      case 'confirmPayment':
        return 'Confirmar Pagamento';
      case 'createReview':
        return 'Criar Avaliacao';
      case 'sendMessage':
        return 'Enviar Mensagem';
      case 'createSupportTicket':
        return 'Criar Ticket';
      case 'adminBroadcast':
        return 'Admin Broadcast';
      default:
        return action;
    }
  }

  /// Get window description
  String get windowDescription {
    if (windowSeconds < 60) return '$windowSeconds segundos';
    if (windowSeconds < 3600) return '${windowSeconds ~/ 60} minutos';
    if (windowSeconds < 86400) return '${windowSeconds ~/ 3600} hora(s)';
    return '${windowSeconds ~/ 86400} dia(s)';
  }
}

/// Top offending users
class TopOffender {
  final String userId;
  final int totalHits;
  final List<String> actions;
  final String lastHit;

  TopOffender({
    required this.userId,
    required this.totalHits,
    required this.actions,
    required this.lastHit,
  });

  factory TopOffender.fromJson(Map<String, dynamic> json) {
    return TopOffender(
      userId: json['userId'] ?? '',
      totalHits: json['totalHits'] ?? 0,
      actions: (json['actions'] as List? ?? []).cast<String>(),
      lastHit: json['lastHit'] ?? '',
    );
  }

  /// Get truncated user ID for display
  String get displayUserId {
    if (userId.length <= 12) return userId;
    return '${userId.substring(0, 6)}...${userId.substring(userId.length - 4)}';
  }
}

/// Hourly trend data
class HourlyTrend {
  final String hour;
  final int hitCount;

  HourlyTrend({
    required this.hour,
    required this.hitCount,
  });

  factory HourlyTrend.fromJson(Map<String, dynamic> json) {
    return HourlyTrend(
      hour: json['hour'] ?? '',
      hitCount: json['hitCount'] ?? 0,
    );
  }

  /// Get display hour (HH:00)
  String get displayHour {
    try {
      final dt = DateTime.parse(hour);
      return '${dt.hour.toString().padLeft(2, '0')}:00';
    } catch (_) {
      return hour;
    }
  }
}

/// Configured rate limit for reference
class ConfiguredLimit {
  final String action;
  final int limit;
  final int windowSeconds;
  final String windowDescription;

  ConfiguredLimit({
    required this.action,
    required this.limit,
    required this.windowSeconds,
    required this.windowDescription,
  });

  factory ConfiguredLimit.fromJson(Map<String, dynamic> json) {
    return ConfiguredLimit(
      action: json['action'] ?? '',
      limit: json['limit'] ?? 0,
      windowSeconds: json['windowSeconds'] ?? 0,
      windowDescription: json['windowDescription'] ?? '',
    );
  }
}
