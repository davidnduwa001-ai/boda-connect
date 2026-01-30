import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Admin Eligibility Metrics Service - READ-ONLY
///
/// Fetches supplier eligibility metrics from exportMigrationMetrics Cloud Function.
/// This service NEVER writes data or computes eligibility client-side.
class AdminEligibilityService {
  static final AdminEligibilityService _instance = AdminEligibilityService._();
  factory AdminEligibilityService() => _instance;
  AdminEligibilityService._();

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Deep convert a Map to Map<String, dynamic>
  /// Handles nested maps and lists from Cloud Function responses
  Map<String, dynamic> _deepConvertMap(Map map) {
    return map.map((key, value) {
      final String stringKey = key.toString();
      if (value is Map) {
        return MapEntry(stringKey, _deepConvertMap(value));
      } else if (value is List) {
        return MapEntry(stringKey, _deepConvertList(value));
      }
      return MapEntry(stringKey, value);
    });
  }

  /// Deep convert a List, handling nested maps
  List<dynamic> _deepConvertList(List list) {
    return list.map((item) {
      if (item is Map) {
        return _deepConvertMap(item);
      } else if (item is List) {
        return _deepConvertList(item);
      }
      return item;
    }).toList();
  }

  // Cache for metrics (1 minute TTL)
  EligibilityMetrics? _cachedMetrics;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 1);

  // Stream controller for auto-refresh
  final _metricsController = StreamController<EligibilityMetrics>.broadcast();
  Timer? _refreshTimer;

  /// Get current metrics (cached or fresh)
  Future<EligibilityMetrics> getMetrics({bool forceRefresh = false}) async {
    // Return cached if still valid
    if (!forceRefresh && _cachedMetrics != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) {
        return _cachedMetrics!;
      }
    }

    try {
      final callable = _functions.httpsCallable('exportMigrationMetrics');
      final response = await callable.call({
        'format': 'json',
        'includeDetails': false,
      });

      // Safely handle Cloud Function response (handles _Map<Object?, Object?>)
      final rawData = response.data;
      if (rawData == null) {
        throw Exception('Empty response from exportMigrationMetrics');
      }

      final Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is Map) {
        data = _deepConvertMap(rawData);
      } else {
        throw Exception('Invalid response type: ${rawData.runtimeType}');
      }

      final metrics = EligibilityMetrics.fromMap(data);

      // Update cache
      _cachedMetrics = metrics;
      _cacheTimestamp = DateTime.now();

      // Notify listeners
      _metricsController.add(metrics);

      return metrics;
    } catch (e) {
      debugPrint('Error fetching eligibility metrics: $e');
      // Return cached if available, even if stale
      if (_cachedMetrics != null) {
        return _cachedMetrics!;
      }
      rethrow;
    }
  }

  /// Stream of metrics with auto-refresh
  Stream<EligibilityMetrics> get metricsStream => _metricsController.stream;

  /// Start auto-refresh (every 60 seconds)
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      getMetrics(forceRefresh: true);
    });
    // Initial fetch
    getMetrics();
  }

  /// Stop auto-refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _metricsController.close();
  }
}

/// Eligibility metrics model from exportMigrationMetrics
class EligibilityMetrics {
  final String version;
  final MetricsTotals totals;
  final MissingFieldsBreakdown missingFields;
  final BlockingBreakdown blockingBreakdown;
  final Map<String, int> blockedReasonCounts;
  final SampleSuppliers sampleSuppliers;
  final List<String> notes;
  final String generatedAt;
  final int executionTimeMs;

  EligibilityMetrics({
    required this.version,
    required this.totals,
    required this.missingFields,
    required this.blockingBreakdown,
    required this.blockedReasonCounts,
    required this.sampleSuppliers,
    required this.notes,
    required this.generatedAt,
    required this.executionTimeMs,
  });

  factory EligibilityMetrics.fromMap(Map<String, dynamic> map) {
    return EligibilityMetrics(
      version: map['version'] as String? ?? 'unknown',
      totals: MetricsTotals.fromMap(map['totals'] as Map<String, dynamic>? ?? {}),
      missingFields: MissingFieldsBreakdown.fromMap(
        map['missingFieldsBreakdown'] as Map<String, dynamic>? ?? {},
      ),
      blockingBreakdown: BlockingBreakdown.fromMap(
        map['blockingBreakdown'] as Map<String, dynamic>? ?? {},
      ),
      blockedReasonCounts: Map<String, int>.from(
        map['blockedReasonCounts'] as Map<String, dynamic>? ?? {},
      ),
      sampleSuppliers: SampleSuppliers.fromMap(
        map['sampleSuppliers'] as Map<String, dynamic>? ?? {},
      ),
      notes: List<String>.from(map['notes'] ?? []),
      generatedAt: map['generatedAt'] as String? ?? '',
      executionTimeMs: map['executionTimeMs'] as int? ?? 0,
    );
  }

  /// Top blocking reason
  String? get topBlockingReason {
    if (blockedReasonCounts.isEmpty) return null;
    final sorted = blockedReasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// Top blocking reason count
  int get topBlockingReasonCount {
    if (blockedReasonCounts.isEmpty) return 0;
    return blockedReasonCounts.values.reduce((a, b) => a > b ? a : b);
  }

  /// Is legacy fallback still active?
  bool get legacyFallbackActive => totals.legacyOnly > 0;

  /// Migration completion percentage
  double get migrationProgress {
    if (totals.totalSuppliers == 0) return 100.0;
    return ((totals.fullyMigrated / totals.totalSuppliers) * 100);
  }
}

class MetricsTotals {
  final int totalSuppliers;
  final int legacyOnly;
  final int partiallyMigrated;
  final int fullyMigrated;
  final int eligible;
  final int blocked;

  MetricsTotals({
    required this.totalSuppliers,
    required this.legacyOnly,
    required this.partiallyMigrated,
    required this.fullyMigrated,
    required this.eligible,
    required this.blocked,
  });

  factory MetricsTotals.fromMap(Map<String, dynamic> map) {
    return MetricsTotals(
      totalSuppliers: map['total_suppliers'] as int? ?? 0,
      legacyOnly: map['legacy_only'] as int? ?? 0,
      partiallyMigrated: map['partially_migrated'] as int? ?? 0,
      fullyMigrated: map['fully_migrated'] as int? ?? 0,
      eligible: map['eligible'] as int? ?? 0,
      blocked: map['blocked'] as int? ?? 0,
    );
  }

  /// Percentage of suppliers that are eligible
  double get eligiblePercentage {
    if (totalSuppliers == 0) return 0.0;
    return (eligible / totalSuppliers) * 100;
  }
}

class MissingFieldsBreakdown {
  final int missingCompliance;
  final int missingVisibility;
  final int missingBlocks;
  final int missingRateLimit;

  MissingFieldsBreakdown({
    required this.missingCompliance,
    required this.missingVisibility,
    required this.missingBlocks,
    required this.missingRateLimit,
  });

  factory MissingFieldsBreakdown.fromMap(Map<String, dynamic> map) {
    return MissingFieldsBreakdown(
      missingCompliance: map['missing_compliance'] as int? ?? 0,
      missingVisibility: map['missing_visibility'] as int? ?? 0,
      missingBlocks: map['missing_blocks'] as int? ?? 0,
      missingRateLimit: map['missing_rate_limit'] as int? ?? 0,
    );
  }
}

class BlockingBreakdown {
  final int blockedByLifecycle;
  final int blockedByCompliance;
  final int blockedByVisibility;
  final int blockedByBlocks;
  final int blockedByRateLimit;

  BlockingBreakdown({
    required this.blockedByLifecycle,
    required this.blockedByCompliance,
    required this.blockedByVisibility,
    required this.blockedByBlocks,
    required this.blockedByRateLimit,
  });

  factory BlockingBreakdown.fromMap(Map<String, dynamic> map) {
    return BlockingBreakdown(
      blockedByLifecycle: map['blocked_by_lifecycle'] as int? ?? 0,
      blockedByCompliance: map['blocked_by_compliance'] as int? ?? 0,
      blockedByVisibility: map['blocked_by_visibility'] as int? ?? 0,
      blockedByBlocks: map['blocked_by_blocks'] as int? ?? 0,
      blockedByRateLimit: map['blocked_by_rate_limit'] as int? ?? 0,
    );
  }

  /// Get top blocking category
  String? get topCategory {
    final categories = {
      'Lifecycle': blockedByLifecycle,
      'Compliance': blockedByCompliance,
      'Visibility': blockedByVisibility,
      'Blocks': blockedByBlocks,
      'Rate Limit': blockedByRateLimit,
    };
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.first.value == 0) return null;
    return sorted.first.key;
  }
}

class SampleSuppliers {
  final List<String> legacy;
  final List<String> partial;
  final List<String> blocked;
  final List<String> eligible;

  SampleSuppliers({
    required this.legacy,
    required this.partial,
    required this.blocked,
    required this.eligible,
  });

  factory SampleSuppliers.fromMap(Map<String, dynamic> map) {
    return SampleSuppliers(
      legacy: List<String>.from(map['legacy'] ?? []),
      partial: List<String>.from(map['partial'] ?? []),
      blocked: List<String>.from(map['blocked'] ?? []),
      eligible: List<String>.from(map['eligible'] ?? []),
    );
  }
}
