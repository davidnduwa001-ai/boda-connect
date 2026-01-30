import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline Sync Service for Angola/Portugal market
/// Handles data synchronization in areas with poor network connectivity
///
/// Features:
/// - Queue operations when offline
/// - Automatic sync when connection restored
/// - Conflict resolution strategies
/// - Retry with exponential backoff
/// - Sync status tracking
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  // Hive boxes for offline storage
  static const String _queueBoxName = 'offline_queue';
  static const String _cacheBoxName = 'data_cache';

  Box<String>? _queueBox;
  Box<String>? _cacheBox;

  // Sync status stream
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  // Current sync status
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  // Connection status
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // Retry configuration
  static const int maxRetryAttempts = 5;
  static const Duration initialRetryDelay = Duration(seconds: 1);
  static const double retryBackoffMultiplier = 2.0;

  // Cache TTL configuration
  static const Duration defaultCacheTTL = Duration(hours: 1);
  static const Duration supplierCacheTTL = Duration(hours: 6);
  static const Duration userCacheTTL = Duration(minutes: 30);
  static const Duration bookingCacheTTL = Duration(minutes: 15);

  /// Initialize the offline sync service
  Future<void> initialize() async {
    try {
      // Open Hive boxes
      _queueBox = await Hive.openBox<String>(_queueBoxName);
      _cacheBox = await Hive.openBox<String>(_cacheBoxName);

      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen((result) {
        _handleConnectivityChange(result);
      });

      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;

      // Process any pending operations if online
      if (_isOnline && _queueBox!.isNotEmpty) {
        _processPendingOperations();
      }

      debugPrint('✅ OfflineSyncService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize OfflineSyncService: $e');
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    debugPrint('📶 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');

    // Sync pending operations when coming back online
    if (!wasOnline && _isOnline) {
      _processPendingOperations();
    }

    // Update sync status
    if (!_isOnline) {
      _updateStatus(SyncStatus.offline);
    }
  }

  /// Queue an operation for offline execution
  Future<String> queueOperation(OfflineOperation operation) async {
    try {
      final operationId = '${operation.type.name}_${DateTime.now().millisecondsSinceEpoch}';
      final operationData = operation.copyWith(id: operationId);

      await _queueBox?.put(operationId, jsonEncode(operationData.toMap()));

      debugPrint('📝 Queued operation: $operationId');

      // Try to execute immediately if online
      if (_isOnline) {
        _processPendingOperations();
      }

      return operationId;
    } catch (e) {
      debugPrint('❌ Failed to queue operation: $e');
      rethrow;
    }
  }

  /// Queue a booking creation
  Future<String> queueBookingCreation(Map<String, dynamic> bookingData) async {
    return queueOperation(OfflineOperation(
      type: OperationType.createBooking,
      collection: 'bookings',
      data: bookingData,
      createdAt: DateTime.now(),
    ));
  }

  /// Queue a message send
  Future<String> queueMessageSend(String conversationId, Map<String, dynamic> messageData) async {
    return queueOperation(OfflineOperation(
      type: OperationType.sendMessage,
      collection: 'conversations/$conversationId/messages',
      data: messageData,
      createdAt: DateTime.now(),
    ));
  }

  /// Queue a profile update
  Future<String> queueProfileUpdate(String userId, Map<String, dynamic> profileData) async {
    return queueOperation(OfflineOperation(
      type: OperationType.updateProfile,
      collection: 'users',
      documentId: userId,
      data: profileData,
      createdAt: DateTime.now(),
    ));
  }

  /// Queue a review submission
  Future<String> queueReviewSubmission(Map<String, dynamic> reviewData) async {
    return queueOperation(OfflineOperation(
      type: OperationType.submitReview,
      collection: 'reviews',
      data: reviewData,
      createdAt: DateTime.now(),
    ));
  }

  /// Process all pending operations
  Future<void> _processPendingOperations() async {
    if (_queueBox == null || _queueBox!.isEmpty) return;
    if (_currentStatus == SyncStatus.syncing) return;

    _updateStatus(SyncStatus.syncing);

    final keys = _queueBox!.keys.toList();
    int successCount = 0;
    int failCount = 0;

    for (final key in keys) {
      try {
        final operationJson = _queueBox!.get(key);
        if (operationJson == null) continue;

        final operation = OfflineOperation.fromMap(
          jsonDecode(operationJson) as Map<String, dynamic>,
        );

        final success = await _executeOperation(operation);

        if (success) {
          await _queueBox!.delete(key);
          successCount++;
          debugPrint('✅ Processed operation: ${operation.id}');
        } else {
          failCount++;
          debugPrint('❌ Failed operation: ${operation.id}');
        }
      } catch (e) {
        failCount++;
        debugPrint('❌ Error processing operation $key: $e');
      }
    }

    debugPrint('📊 Sync complete: $successCount success, $failCount failed');

    _updateStatus(
      _queueBox!.isEmpty ? SyncStatus.complete : SyncStatus.pendingRetry,
    );

    // Schedule retry for failed operations
    if (failCount > 0) {
      _scheduleRetry();
    }
  }

  /// Firebase Functions instance for Cloud Function calls
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Create booking via Cloud Function
  /// This ensures server-side validation and atomic conflict checking
  Future<void> _createBookingViaCloudFunction(Map<String, dynamic> data) async {
    final callable = _functions.httpsCallable('createBooking');

    final result = await callable.call<Map<String, dynamic>>({
      'supplierId': data['supplierId'],
      'packageId': data['packageId'],
      'eventDate': data['eventDate'],
      'startTime': data['eventTime'],
      'notes': data['notes'],
      'eventName': data['eventName'],
      'eventLocation': data['eventLocation'],
      'guestCount': data['guestCount'],
      'clientRequestId': data['id'],
    });

    final responseData = result.data;
    if (responseData['success'] != true) {
      throw Exception(responseData['error'] ?? 'Failed to create booking');
    }

    debugPrint('✅ Booking created via Cloud Function: ${responseData['bookingId']}');
  }

  /// Execute a single operation with retry logic
  Future<bool> _executeOperation(OfflineOperation operation) async {
    int attempts = 0;
    Duration delay = initialRetryDelay;

    while (attempts < maxRetryAttempts) {
      try {
        if (!_isOnline) return false;

        switch (operation.type) {
          case OperationType.createBooking:
            // Route booking creation through Cloud Function for server-side
            // validation and atomic conflict checking
            await _createBookingViaCloudFunction(operation.data);
            break;

          case OperationType.sendMessage:
            await _firestore.collection(operation.collection).add(operation.data);
            break;

          case OperationType.updateProfile:
            await _firestore
                .collection(operation.collection)
                .doc(operation.documentId)
                .update(operation.data);
            break;

          case OperationType.submitReview:
            await _firestore.collection(operation.collection).add(operation.data);
            break;

          case OperationType.cancelBooking:
            await _firestore
                .collection(operation.collection)
                .doc(operation.documentId)
                .update({'status': 'cancelled', ...operation.data});
            break;

          case OperationType.deleteDocument:
            await _firestore
                .collection(operation.collection)
                .doc(operation.documentId)
                .delete();
            break;

          case OperationType.updateDocument:
            await _firestore
                .collection(operation.collection)
                .doc(operation.documentId)
                .update(operation.data);
            break;
        }

        return true;
      } catch (e) {
        attempts++;
        debugPrint('⚠️ Operation attempt $attempts failed: $e');

        if (attempts < maxRetryAttempts) {
          await Future.delayed(delay);
          delay = Duration(
            milliseconds: (delay.inMilliseconds * retryBackoffMultiplier).round(),
          );
        }
      }
    }

    return false;
  }

  /// Schedule a retry for failed operations
  void _scheduleRetry() {
    Future.delayed(const Duration(minutes: 5), () {
      if (_isOnline && _queueBox!.isNotEmpty) {
        _processPendingOperations();
      }
    });
  }

  /// Cache data locally
  Future<void> cacheData({
    required String key,
    required Map<String, dynamic> data,
    Duration? ttl,
  }) async {
    try {
      final cacheEntry = CacheEntry(
        data: data,
        timestamp: DateTime.now(),
        ttl: ttl ?? defaultCacheTTL,
      );

      await _cacheBox?.put(key, jsonEncode(cacheEntry.toMap()));
    } catch (e) {
      debugPrint('❌ Failed to cache data: $e');
    }
  }

  /// Get cached data
  Future<Map<String, dynamic>?> getCachedData(String key) async {
    try {
      final entryJson = _cacheBox?.get(key);
      if (entryJson == null) return null;

      final entry = CacheEntry.fromMap(
        jsonDecode(entryJson) as Map<String, dynamic>,
      );

      // Check if cache is expired
      if (entry.isExpired) {
        await _cacheBox?.delete(key);
        return null;
      }

      return entry.data;
    } catch (e) {
      debugPrint('❌ Failed to get cached data: $e');
      return null;
    }
  }

  /// Get data with cache fallback
  Future<T?> getOrFetch<T>({
    required String cacheKey,
    required Future<T?> Function() fetcher,
    required T? Function(Map<String, dynamic>) fromMap,
    required Map<String, dynamic> Function(T) toMap,
    Duration? cacheTTL,
  }) async {
    // Try cache first
    final cached = await getCachedData(cacheKey);
    if (cached != null) {
      return fromMap(cached);
    }

    // Fetch fresh data if online
    if (_isOnline) {
      try {
        final fresh = await fetcher();
        if (fresh != null) {
          await cacheData(
            key: cacheKey,
            data: toMap(fresh),
            ttl: cacheTTL,
          );
        }
        return fresh;
      } catch (e) {
        debugPrint('❌ Failed to fetch data: $e');
        return null;
      }
    }

    return null;
  }

  /// Invalidate cache entries by pattern
  Future<void> invalidateCache(String pattern) async {
    try {
      final keys = _cacheBox?.keys.where((key) => key.toString().contains(pattern)).toList();
      for (final key in keys ?? []) {
        await _cacheBox?.delete(key);
      }
      debugPrint('🗑️ Invalidated cache for pattern: $pattern');
    } catch (e) {
      debugPrint('❌ Failed to invalidate cache: $e');
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await _cacheBox?.clear();
    debugPrint('🗑️ Cache cleared');
  }

  /// Get pending operations count
  int get pendingOperationsCount => _queueBox?.length ?? 0;

  /// Get pending operations
  List<OfflineOperation> getPendingOperations() {
    if (_queueBox == null) return [];

    return _queueBox!.values
        .map((json) => OfflineOperation.fromMap(
              jsonDecode(json) as Map<String, dynamic>,
            ))
        .toList();
  }

  /// Cancel a pending operation
  Future<void> cancelOperation(String operationId) async {
    await _queueBox?.delete(operationId);
    debugPrint('❌ Cancelled operation: $operationId');
  }

  /// Force sync now
  Future<void> syncNow() async {
    if (_isOnline) {
      await _processPendingOperations();
    }
  }

  /// Update sync status
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  /// Dispose resources
  void dispose() {
    _syncStatusController.close();
  }
}

/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  complete,
  pendingRetry,
  offline,
  error,
}

/// Operation types
enum OperationType {
  createBooking,
  sendMessage,
  updateProfile,
  submitReview,
  cancelBooking,
  deleteDocument,
  updateDocument,
}

/// Offline operation model
class OfflineOperation {
  final String? id;
  final OperationType type;
  final String collection;
  final String? documentId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  OfflineOperation({
    this.id,
    required this.type,
    required this.collection,
    this.documentId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  OfflineOperation copyWith({
    String? id,
    OperationType? type,
    String? collection,
    String? documentId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return OfflineOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      collection: collection ?? this.collection,
      documentId: documentId ?? this.documentId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'collection': collection,
        'documentId': documentId,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OfflineOperation.fromMap(Map<String, dynamic> map) => OfflineOperation(
        id: map['id'] as String?,
        type: OperationType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => OperationType.updateDocument,
        ),
        collection: map['collection'] as String,
        documentId: map['documentId'] as String?,
        data: Map<String, dynamic>.from(map['data'] as Map),
        createdAt: DateTime.parse(map['createdAt'] as String),
        retryCount: map['retryCount'] as int? ?? 0,
      );
}

/// Cache entry model
class CacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;

  Map<String, dynamic> toMap() => {
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'ttlMs': ttl.inMilliseconds,
      };

  factory CacheEntry.fromMap(Map<String, dynamic> map) => CacheEntry(
        data: Map<String, dynamic>.from(map['data'] as Map),
        timestamp: DateTime.parse(map['timestamp'] as String),
        ttl: Duration(milliseconds: map['ttlMs'] as int),
      );
}
