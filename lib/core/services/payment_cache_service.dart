import 'dart:async';
import 'package:hive/hive.dart';
import 'logger_service.dart';

/// Payment status enum for caching
enum CachedPaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  refunded,
  unknown,
}

/// Cached payment information
class CachedPayment {
  final String paymentId;
  final CachedPaymentStatus status;
  final DateTime cachedAt;
  final DateTime? expiresAt;
  final int? amount;
  final String? bookingId;
  final Map<String, dynamic>? metadata;

  CachedPayment({
    required this.paymentId,
    required this.status,
    required this.cachedAt,
    this.expiresAt,
    this.amount,
    this.bookingId,
    this.metadata,
  });

  /// Check if cache is expired (default 5 minutes for non-terminal statuses)
  bool get isExpired {
    if (expiresAt != null) {
      return DateTime.now().isAfter(expiresAt!);
    }
    // Terminal statuses never expire
    if (isTerminal) return false;
    // Non-terminal statuses expire after 5 minutes
    return DateTime.now().difference(cachedAt).inMinutes > 5;
  }

  /// Check if status is terminal (won't change)
  bool get isTerminal {
    switch (status) {
      case CachedPaymentStatus.completed:
      case CachedPaymentStatus.failed:
      case CachedPaymentStatus.cancelled:
      case CachedPaymentStatus.refunded:
        return true;
      default:
        return false;
    }
  }

  /// Check if status is stale (cached more than 30 seconds ago for non-terminal)
  bool get isStale {
    if (isTerminal) return false;
    return DateTime.now().difference(cachedAt).inSeconds > 30;
  }

  Map<String, dynamic> toJson() => {
        'paymentId': paymentId,
        'status': status.name,
        'cachedAt': cachedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'amount': amount,
        'bookingId': bookingId,
        'metadata': metadata,
      };

  factory CachedPayment.fromJson(Map<String, dynamic> json) {
    return CachedPayment(
      paymentId: json['paymentId'] as String,
      status: CachedPaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CachedPaymentStatus.unknown,
      ),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      amount: json['amount'] as int?,
      bookingId: json['bookingId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Service for caching payment statuses locally
///
/// Benefits:
/// - Reduces Cloud Function calls for status checks
/// - Provides instant feedback while actual status is loading
/// - Handles offline scenarios gracefully
class PaymentCacheService {
  static PaymentCacheService? _instance;
  static const String _boxName = 'payment_cache';

  Box<Map>? _box;
  final Map<String, CachedPayment> _memoryCache = {};
  bool _initialized = false;

  PaymentCacheService._();

  /// Get singleton instance
  static PaymentCacheService get instance {
    _instance ??= PaymentCacheService._();
    return _instance!;
  }

  /// Initialize the cache (call during app startup)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _box = await Hive.openBox<Map>(_boxName);
      _loadFromDisk();
      _initialized = true;
      Log.success('Payment cache initialized');
    } catch (e) {
      Log.warn('Payment cache initialization failed: $e');
      // Continue without persistent cache
      _initialized = true;
    }
  }

  /// Load cached payments from disk
  void _loadFromDisk() {
    if (_box == null) return;

    for (final key in _box!.keys) {
      try {
        final data = _box!.get(key);
        if (data != null) {
          final cached = CachedPayment.fromJson(Map<String, dynamic>.from(data));
          if (!cached.isExpired) {
            _memoryCache[key.toString()] = cached;
          }
        }
      } catch (e) {
        Log.warn('Failed to load cached payment $key: $e');
      }
    }

    Log.d('Loaded ${_memoryCache.length} payments from cache');
  }

  /// Get cached payment status
  CachedPayment? get(String paymentId) {
    final cached = _memoryCache[paymentId];
    if (cached == null) return null;
    if (cached.isExpired) {
      // Remove expired cache
      _memoryCache.remove(paymentId);
      _box?.delete(paymentId);
      return null;
    }
    return cached;
  }

  /// Cache a payment status
  Future<void> cache(CachedPayment payment) async {
    _memoryCache[payment.paymentId] = payment;

    try {
      await _box?.put(payment.paymentId, payment.toJson());
    } catch (e) {
      Log.warn('Failed to persist payment cache: $e');
    }
  }

  /// Update payment status (convenience method)
  Future<void> updateStatus(
    String paymentId,
    CachedPaymentStatus status, {
    int? amount,
    String? bookingId,
    Map<String, dynamic>? metadata,
  }) async {
    final existing = get(paymentId);

    await cache(CachedPayment(
      paymentId: paymentId,
      status: status,
      cachedAt: DateTime.now(),
      amount: amount ?? existing?.amount,
      bookingId: bookingId ?? existing?.bookingId,
      metadata: metadata ?? existing?.metadata,
    ));
  }

  /// Check if we should refetch from server
  bool shouldRefetch(String paymentId) {
    final cached = get(paymentId);
    if (cached == null) return true;
    if (cached.isExpired) return true;
    if (cached.isStale) return true;
    return false;
  }

  /// Clear all cached data
  Future<void> clear() async {
    _memoryCache.clear();
    await _box?.clear();
    Log.d('Payment cache cleared');
  }

  /// Clear expired entries
  Future<void> cleanUp() async {
    final expiredKeys = <String>[];

    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      await _box?.delete(key);
    }

    if (expiredKeys.isNotEmpty) {
      Log.d('Cleaned up ${expiredKeys.length} expired payment cache entries');
    }
  }

  /// Get all cached payments for a booking
  List<CachedPayment> getByBookingId(String bookingId) {
    return _memoryCache.values
        .where((p) => p.bookingId == bookingId && !p.isExpired)
        .toList();
  }
}
