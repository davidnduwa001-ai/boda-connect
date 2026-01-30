import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Performance monitoring service for tracking app performance
/// Optimized for Angola/Portugal market with network awareness
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Performance thresholds
  static const Duration slowRequestThreshold = Duration(seconds: 3);
  static const Duration criticalRequestThreshold = Duration(seconds: 10);
  static const Duration slowScreenLoadThreshold = Duration(milliseconds: 1500);

  // Tracking maps
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<int>> _operationDurations = {};

  // ==================== MEMORY CACHE ====================
  final Map<String, _CacheEntry> _memoryCache = {};
  static const int _maxCacheSize = 100;
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  // ==================== DEBOUNCE/THROTTLE ====================
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, DateTime> _throttleTimestamps = {};

  // ==================== FRAME MONITORING ====================
  int _droppedFrames = 0;
  int _totalFrames = 0;
  bool _isMonitoringFrames = false;

  /// Start tracking an operation
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
  }

  /// End tracking and log the operation duration
  Future<Duration?> endOperation(String operationName, {
    Map<String, dynamic>? metadata,
  }) async {
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);

    // Store duration for averaging
    _operationDurations.putIfAbsent(operationName, () => []);
    _operationDurations[operationName]!.add(duration.inMilliseconds);

    // Keep only last 100 measurements
    if (_operationDurations[operationName]!.length > 100) {
      _operationDurations[operationName]!.removeAt(0);
    }

    // Log slow operations
    if (duration > slowRequestThreshold) {
      await _logSlowOperation(operationName, duration, metadata);
    }

    debugPrint('⏱️ $operationName: ${duration.inMilliseconds}ms');

    return duration;
  }

  /// Track a future operation automatically
  Future<T> trackOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? metadata,
  }) async {
    startOperation(operationName);
    try {
      final result = await operation();
      await endOperation(operationName, metadata: metadata);
      return result;
    } catch (e) {
      await endOperation(operationName, metadata: {
        ...?metadata,
        'error': e.toString(),
      });
      rethrow;
    }
  }

  /// Log slow operations to analytics
  Future<void> _logSlowOperation(
    String operationName,
    Duration duration,
    Map<String, dynamic>? metadata,
  ) async {
    final severity = duration > criticalRequestThreshold ? 'critical' : 'slow';

    await _analytics.logEvent(
      name: 'slow_operation',
      parameters: {
        'operation_name': operationName,
        'duration_ms': duration.inMilliseconds,
        'severity': severity,
        ...?metadata?.map((k, v) => MapEntry(k, v.toString())),
      },
    );

    debugPrint('⚠️ Slow operation detected: $operationName (${duration.inMilliseconds}ms)');
  }

  /// Track screen load time
  Future<void> trackScreenLoad(
    String screenName,
    Duration loadTime,
  ) async {
    await _analytics.logEvent(
      name: 'screen_load',
      parameters: {
        'screen_name': screenName,
        'load_time_ms': loadTime.inMilliseconds,
        'is_slow': loadTime > slowScreenLoadThreshold,
      },
    );

    if (loadTime > slowScreenLoadThreshold) {
      debugPrint('⚠️ Slow screen load: $screenName (${loadTime.inMilliseconds}ms)');
    }
  }

  /// Track API request performance
  Future<void> trackApiRequest({
    required String endpoint,
    required String method,
    required int statusCode,
    required Duration duration,
    int? responseSize,
  }) async {
    await _analytics.logEvent(
      name: 'api_request',
      parameters: {
        'endpoint': endpoint,
        'method': method,
        'status_code': statusCode,
        'duration_ms': duration.inMilliseconds,
        'response_size': responseSize ?? 0,
        'is_slow': duration > slowRequestThreshold,
        'is_error': statusCode >= 400,
      },
    );
  }

  /// Track image load performance
  Future<void> trackImageLoad({
    required String imageUrl,
    required Duration loadTime,
    required bool fromCache,
    int? imageSize,
  }) async {
    await _analytics.logEvent(
      name: 'image_load',
      parameters: {
        'image_url': _sanitizeUrl(imageUrl),
        'load_time_ms': loadTime.inMilliseconds,
        'from_cache': fromCache,
        'image_size': imageSize ?? 0,
      },
    );
  }

  /// Track payment operation
  Future<void> trackPaymentOperation({
    required String paymentMethod,
    required String status,
    required Duration duration,
    double? amount,
    String? currency,
  }) async {
    await _analytics.logEvent(
      name: 'payment_operation',
      parameters: {
        'payment_method': paymentMethod,
        'status': status,
        'duration_ms': duration.inMilliseconds,
        'amount': amount ?? 0,
        'currency': currency ?? 'AOA',
      },
    );
  }

  /// Track search performance
  Future<void> trackSearch({
    required String query,
    required int resultsCount,
    required Duration duration,
    String? category,
  }) async {
    await _analytics.logEvent(
      name: 'search_performance',
      parameters: {
        'query_length': query.length,
        'results_count': resultsCount,
        'duration_ms': duration.inMilliseconds,
        'category': category ?? 'all',
      },
    );
  }

  /// Track offline sync performance
  Future<void> trackSyncOperation({
    required int operationsCount,
    required int successCount,
    required int failedCount,
    required Duration duration,
  }) async {
    await _analytics.logEvent(
      name: 'sync_operation',
      parameters: {
        'operations_count': operationsCount,
        'success_count': successCount,
        'failed_count': failedCount,
        'duration_ms': duration.inMilliseconds,
        'success_rate': operationsCount > 0
            ? (successCount / operationsCount * 100).round()
            : 100,
      },
    );
  }

  /// Track booking flow completion
  Future<void> trackBookingFlow({
    required String stage,
    required Duration totalDuration,
    bool completed = false,
    String? abandonReason,
  }) async {
    await _analytics.logEvent(
      name: 'booking_flow',
      parameters: {
        'stage': stage,
        'total_duration_ms': totalDuration.inMilliseconds,
        'completed': completed,
        'abandon_reason': abandonReason ?? '',
      },
    );
  }

  /// Get average duration for an operation
  double? getAverageDuration(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) return null;

    final sum = durations.reduce((a, b) => a + b);
    return sum / durations.length;
  }

  /// Get performance summary for an operation
  PerformanceSummary? getPerformanceSummary(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) return null;

    final sorted = List<int>.from(durations)..sort();
    final sum = sorted.reduce((a, b) => a + b);

    return PerformanceSummary(
      operationName: operationName,
      sampleCount: sorted.length,
      averageMs: sum / sorted.length,
      minMs: sorted.first.toDouble(),
      maxMs: sorted.last.toDouble(),
      p50Ms: sorted[sorted.length ~/ 2].toDouble(),
      p95Ms: sorted[(sorted.length * 0.95).floor()].toDouble(),
    );
  }

  /// Log a custom performance metric
  Future<void> logCustomMetric({
    required String metricName,
    required double value,
    String? unit,
    Map<String, dynamic>? dimensions,
  }) async {
    await _analytics.logEvent(
      name: 'custom_metric',
      parameters: {
        'metric_name': metricName,
        'value': value,
        'unit': unit ?? '',
        ...?dimensions?.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  /// Track network quality impact on operations
  Future<void> trackNetworkImpact({
    required String operationName,
    required String connectionType,
    required Duration duration,
    bool succeeded = true,
  }) async {
    await _analytics.logEvent(
      name: 'network_impact',
      parameters: {
        'operation_name': operationName,
        'connection_type': connectionType,
        'duration_ms': duration.inMilliseconds,
        'succeeded': succeeded,
      },
    );
  }

  /// Sanitize URL for logging (remove sensitive params)
  String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Only keep host and path, remove query params
      return '${uri.host}${uri.path}';
    } catch (e) {
      return 'invalid_url';
    }
  }

  // ==================== CACHING METHODS ====================

  /// Get cached data or fetch from source
  Future<T?> getCachedOrFetch<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? cacheDuration,
  }) async {
    final cached = _getFromCache<T>(key);
    if (cached != null) {
      debugPrint('📦 Cache HIT: $key');
      return cached;
    }

    debugPrint('📦 Cache MISS: $key');
    try {
      final data = await fetcher();
      _addToCache(key, data, cacheDuration ?? _defaultCacheDuration);
      return data;
    } catch (e) {
      debugPrint('❌ Error fetching for cache: $e');
      return null;
    }
  }

  T? _getFromCache<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  void _addToCache(String key, dynamic data, Duration duration) {
    if (_memoryCache.length >= _maxCacheSize) {
      _evictOldestEntry();
    }
    _memoryCache[key] = _CacheEntry(
      data: data,
      expiresAt: DateTime.now().add(duration),
      createdAt: DateTime.now(),
    );
  }

  void _evictOldestEntry() {
    if (_memoryCache.isEmpty) return;
    String? oldestKey;
    DateTime? oldestTime;
    for (final entry in _memoryCache.entries) {
      if (oldestTime == null || entry.value.createdAt.isBefore(oldestTime)) {
        oldestTime = entry.value.createdAt;
        oldestKey = entry.key;
      }
    }
    if (oldestKey != null) _memoryCache.remove(oldestKey);
  }

  /// Invalidate specific cache entry
  void invalidateCache(String key) => _memoryCache.remove(key);

  /// Invalidate cache entries matching a pattern
  void invalidateCachePattern(String pattern) {
    _memoryCache.removeWhere((key, _) => key.contains(pattern));
  }

  /// Clear all cache
  void clearCache() => _memoryCache.clear();

  // ==================== DEBOUNCE/THROTTLE ====================

  /// Debounce a function call
  void debounce(
    String key,
    VoidCallback action, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(duration, () {
      action();
      _debounceTimers.remove(key);
    });
  }

  /// Throttle a function call - returns true if allowed
  bool throttle(String key, {Duration duration = const Duration(milliseconds: 500)}) {
    final lastCall = _throttleTimestamps[key];
    final now = DateTime.now();
    if (lastCall == null || now.difference(lastCall) >= duration) {
      _throttleTimestamps[key] = now;
      return true;
    }
    return false;
  }

  /// Cancel debounce timer
  void cancelDebounce(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
  }

  // ==================== FRAME MONITORING ====================

  /// Start monitoring frame performance
  void startFrameMonitoring() {
    if (_isMonitoringFrames) return;
    _isMonitoringFrames = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  /// Stop monitoring frame performance
  void stopFrameMonitoring() {
    if (!_isMonitoringFrames) return;
    _isMonitoringFrames = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _totalFrames++;
      final totalDuration = timing.buildDuration.inMicroseconds + timing.rasterDuration.inMicroseconds;
      if (totalDuration > 16667) _droppedFrames++; // > 16.67ms = dropped frame
    }
  }

  /// Get frame performance stats
  FramePerformanceStats getFrameStats() {
    final fps = _totalFrames > 0 ? (_totalFrames - _droppedFrames) / _totalFrames * 60 : 60.0;
    return FramePerformanceStats(
      totalFrames: _totalFrames,
      droppedFrames: _droppedFrames,
      averageFps: fps,
      dropRate: _totalFrames > 0 ? _droppedFrames / _totalFrames : 0,
    );
  }

  /// Reset frame statistics
  void resetFrameStats() {
    _totalFrames = 0;
    _droppedFrames = 0;
  }

  /// Clear all tracked data
  void clearData() {
    _operationStartTimes.clear();
    _operationDurations.clear();
    _memoryCache.clear();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _throttleTimestamps.clear();
  }
}

/// Cache entry model
class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  final DateTime createdAt;

  _CacheEntry({required this.data, required this.expiresAt, required this.createdAt});
}

/// Frame performance statistics
class FramePerformanceStats {
  final int totalFrames;
  final int droppedFrames;
  final double averageFps;
  final double dropRate;

  FramePerformanceStats({
    required this.totalFrames,
    required this.droppedFrames,
    required this.averageFps,
    required this.dropRate,
  });

  bool get isHealthy => dropRate < 0.05; // Less than 5% dropped

  @override
  String toString() => 'FrameStats(fps: ${averageFps.toStringAsFixed(1)}, dropped: $droppedFrames/$totalFrames)';
}

/// Performance summary model
class PerformanceSummary {
  final String operationName;
  final int sampleCount;
  final double averageMs;
  final double minMs;
  final double maxMs;
  final double p50Ms;
  final double p95Ms;

  PerformanceSummary({
    required this.operationName,
    required this.sampleCount,
    required this.averageMs,
    required this.minMs,
    required this.maxMs,
    required this.p50Ms,
    required this.p95Ms,
  });

  @override
  String toString() {
    return 'PerformanceSummary($operationName): '
        'avg=${averageMs.toStringAsFixed(1)}ms, '
        'p50=${p50Ms.toStringAsFixed(1)}ms, '
        'p95=${p95Ms.toStringAsFixed(1)}ms, '
        'samples=$sampleCount';
  }
}

/// Mixin for screen performance tracking
mixin ScreenPerformanceTracker<T> {
  final Stopwatch _loadStopwatch = Stopwatch();
  String get screenName;

  void startScreenLoad() {
    _loadStopwatch.reset();
    _loadStopwatch.start();
  }

  void endScreenLoad() {
    _loadStopwatch.stop();
    PerformanceService().trackScreenLoad(
      screenName,
      _loadStopwatch.elapsed,
    );
  }
}
