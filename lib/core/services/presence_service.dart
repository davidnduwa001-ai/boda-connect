import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to track user online/offline presence
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _presenceTimer;
  String? _currentUserId;
  int _errorCount = 0;
  bool _isPaused = false;

  /// Start tracking presence for the current user
  void startTracking(String userId) {
    _currentUserId = userId;
    _errorCount = 0;
    _isPaused = false;
    _updatePresence(true);

    // Update presence every 30 seconds to keep online status alive
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isPaused) {
        _updatePresence(true);
      }
    });

    debugPrint('👤 Presence tracking started for user: $userId');
  }

  /// Stop tracking presence (user logged out or app closed)
  Future<void> stopTracking() async {
    _presenceTimer?.cancel();
    _presenceTimer = null;

    if (_currentUserId != null) {
      await _updatePresence(false);
      debugPrint('👤 Presence tracking stopped for user: $_currentUserId');
      _currentUserId = null;
    }
  }

  /// Update user's online status and last seen time
  Future<void> _updatePresence(bool isOnline) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      // Reset error count on success
      _errorCount = 0;
      _isPaused = false;
    } catch (e) {
      _errorCount++;
      // Only log first few errors to avoid console spam
      if (_errorCount <= 3) {
        debugPrint('❌ Failed to update presence: $e');
      }
      // Pause presence updates after repeated failures (permissions issue)
      if (_errorCount >= 3) {
        _isPaused = true;
        if (_errorCount == 3) {
          debugPrint('⏸️ Pausing presence updates due to repeated failures');
        }
      }
    }
  }

  /// Get a stream of another user's presence status
  Stream<UserPresence> getUserPresence(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        return UserPresence(isOnline: false, lastSeen: null);
      }

      final data = doc.data()!;
      final isOnline = data['isOnline'] as bool? ?? false;
      final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
      final lastSeen = lastSeenTimestamp?.toDate();

      // Consider user offline if last seen is more than 2 minutes ago
      final effectivelyOnline = isOnline &&
          lastSeen != null &&
          DateTime.now().difference(lastSeen).inMinutes < 2;

      return UserPresence(
        isOnline: effectivelyOnline,
        lastSeen: lastSeen,
      );
    });
  }

  /// Get presence status once (not real-time)
  Future<UserPresence> getUserPresenceOnce(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return UserPresence(isOnline: false, lastSeen: null);
      }

      final data = doc.data()!;
      final isOnline = data['isOnline'] as bool? ?? false;
      final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
      final lastSeen = lastSeenTimestamp?.toDate();

      // Consider user offline if last seen is more than 2 minutes ago
      final effectivelyOnline = isOnline &&
          lastSeen != null &&
          DateTime.now().difference(lastSeen).inMinutes < 2;

      return UserPresence(
        isOnline: effectivelyOnline,
        lastSeen: lastSeen,
      );
    } catch (e) {
      debugPrint('❌ Failed to get user presence: $e');
      return UserPresence(isOnline: false, lastSeen: null);
    }
  }
}

/// User presence data
class UserPresence {
  final bool isOnline;
  final DateTime? lastSeen;

  UserPresence({
    required this.isOnline,
    this.lastSeen,
  });

  /// Get formatted last seen string
  String getLastSeenText() {
    if (isOnline) return 'Online agora';
    if (lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inMinutes < 1) {
      return 'Visto agora';
    } else if (difference.inMinutes < 60) {
      return 'Visto há ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Visto há ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Visto ontem';
    } else if (difference.inDays < 7) {
      return 'Visto há ${difference.inDays} dias';
    } else {
      return 'Visto em ${lastSeen!.day}/${lastSeen!.month}/${lastSeen!.year}';
    }
  }
}
