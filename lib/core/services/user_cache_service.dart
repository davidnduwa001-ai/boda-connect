import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/user_type.dart';

/// Service for caching user data locally using Hive
/// Ensures user profile persists across app restarts and offline scenarios
class UserCacheService {
  static final UserCacheService _instance = UserCacheService._internal();
  factory UserCacheService() => _instance;
  UserCacheService._internal();

  static const String _boxName = 'user_cache';
  static const String _userKey = 'current_user';
  static const String _userTypeKey = 'user_type';
  static const String _lastSyncKey = 'last_sync';
  static const String _preferencesKey = 'preferences';

  Box? _box;

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      _box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      debugPrint('✅ UserCacheService initialized');
    } catch (e) {
      debugPrint('❌ UserCacheService initialization error: $e');
    }
  }

  /// Ensure box is open
  Future<Box> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      await initialize();
    }
    return _box!;
  }

  // ==================== USER DATA ====================

  /// Cache user data locally
  Future<void> cacheUser(UserModel user) async {
    try {
      final box = await _ensureBox();
      final userData = _userToMap(user);
      await box.put(_userKey, jsonEncode(userData));
      await box.put(_userTypeKey, user.userType.name);
      await box.put(_lastSyncKey, DateTime.now().toIso8601String());
      debugPrint('✅ User cached: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error caching user: $e');
    }
  }

  /// Get cached user data
  Future<UserModel?> getCachedUser() async {
    try {
      final box = await _ensureBox();
      final userJson = box.get(_userKey) as String?;
      if (userJson == null) return null;

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      return _userFromMap(userData);
    } catch (e) {
      debugPrint('❌ Error getting cached user: $e');
      return null;
    }
  }

  /// Get cached user type
  Future<UserType?> getCachedUserType() async {
    try {
      final box = await _ensureBox();
      final typeStr = box.get(_userTypeKey) as String?;
      if (typeStr == null) return null;

      return UserType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => UserType.client,
      );
    } catch (e) {
      debugPrint('❌ Error getting cached user type: $e');
      return null;
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    try {
      final box = await _ensureBox();
      final syncStr = box.get(_lastSyncKey) as String?;
      if (syncStr == null) return null;
      return DateTime.parse(syncStr);
    } catch (e) {
      return null;
    }
  }

  /// Check if cache is stale (older than given duration)
  Future<bool> isCacheStale({Duration maxAge = const Duration(hours: 1)}) async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
  }

  /// Clear user cache
  Future<void> clearUserCache() async {
    try {
      final box = await _ensureBox();
      await box.delete(_userKey);
      await box.delete(_userTypeKey);
      await box.delete(_lastSyncKey);
      debugPrint('✅ User cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing user cache: $e');
    }
  }

  // ==================== USER PREFERENCES ====================

  /// Save user preferences
  Future<void> savePreferences(Map<String, dynamic> preferences) async {
    try {
      final box = await _ensureBox();
      await box.put(_preferencesKey, jsonEncode(preferences));
      debugPrint('✅ Preferences saved');
    } catch (e) {
      debugPrint('❌ Error saving preferences: $e');
    }
  }

  /// Get user preferences
  Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final box = await _ensureBox();
      final prefsJson = box.get(_preferencesKey) as String?;
      if (prefsJson == null) return null;
      return jsonDecode(prefsJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error getting preferences: $e');
      return null;
    }
  }

  /// Update a single preference
  Future<void> updatePreference(String key, dynamic value) async {
    final prefs = await getPreferences() ?? {};
    prefs[key] = value;
    await savePreferences(prefs);
  }

  /// Get a single preference
  Future<T?> getPreference<T>(String key) async {
    final prefs = await getPreferences();
    return prefs?[key] as T?;
  }

  // ==================== CLEAR ALL ====================

  /// Clear all cached data (on logout)
  Future<void> clearAll() async {
    try {
      final box = await _ensureBox();
      await box.clear();
      debugPrint('✅ All user cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing all cache: $e');
    }
  }

  // ==================== SERIALIZATION HELPERS ====================

  /// Convert UserModel to Map for storage
  Map<String, dynamic> _userToMap(UserModel user) {
    return {
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'photoUrl': user.photoUrl,
      'description': user.description,
      'userType': user.userType.name,
      'isActive': user.isActive,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
      'fcmToken': user.fcmToken,
      'rating': user.rating,
      'isOnline': user.isOnline,
      'lastSeen': user.lastSeen?.toIso8601String(),
      'violationsCount': user.violationsCount,
      'lastViolationAt': user.lastViolationAt?.toIso8601String(),
      // Note: location and preferences are not cached to keep storage simple
      // They are fetched fresh from Firestore when needed
    };
  }

  /// Convert Map to UserModel
  UserModel _userFromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      name: map['name'] as String?,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      description: map['description'] as String?,
      userType: UserType.values.firstWhere(
        (t) => t.name == map['userType'],
        orElse: () => UserType.client,
      ),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
      fcmToken: map['fcmToken'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.parse(map['lastSeen'] as String)
          : null,
      violationsCount: (map['violationsCount'] as num?)?.toInt() ?? 0,
      lastViolationAt: map['lastViolationAt'] != null
          ? DateTime.parse(map['lastViolationAt'] as String)
          : null,
    );
  }
}
