import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for admin-user chat and broadcast functionality
class AdminChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Admin support account ID (created in Firestore)
  static const String adminSupportId = 'admin_support';
  static const String adminSupportName = 'Suporte Boda Connect';
  static const String adminSupportPhoto = '';

  // ==================== SUPPORT CHAT ====================

  /// Get or create a support conversation for a user
  Future<String> getOrCreateSupportConversation({
    required String userId,
    required String userName,
    String? userPhoto,
    required String userRole, // 'client' or 'supplier'
  }) async {
    try {
      // Check if support conversation already exists
      final existingConversation = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .where('isSupport', isEqualTo: true)
          .limit(1)
          .get();

      if (existingConversation.docs.isNotEmpty) {
        return existingConversation.docs.first.id;
      }

      // Create new support conversation
      final conversationData = {
        'participants': [userId, adminSupportId],
        'participantNames': {
          userId: userName,
          adminSupportId: adminSupportName,
        },
        'participantPhotos': {
          userId: userPhoto ?? '',
          adminSupportId: adminSupportPhoto,
        },
        'participantRoles': {
          userId: userRole,
          adminSupportId: 'admin',
        },
        'isSupport': true,
        'lastMessage': 'Olá! Como podemos ajudar?',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': adminSupportId,
        'unreadCount': {userId: 1, adminSupportId: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('conversations').add(conversationData);

      // Add welcome message
      await _firestore
          .collection('conversations')
          .doc(docRef.id)
          .collection('messages')
          .add({
        'senderId': adminSupportId,
        'senderName': adminSupportName,
        'text': 'Olá! Bem-vindo ao suporte Boda Connect. Como podemos ajudar você hoje?',
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [adminSupportId],
      });

      debugPrint('Created support conversation: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating support conversation: $e');
      rethrow;
    }
  }

  /// Get all support conversations (for admin dashboard)
  Stream<List<Map<String, dynamic>>> getSupportConversations() {
    return _firestore
        .collection('conversations')
        .where('isSupport', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  /// Get unread support conversation count (for admin)
  Stream<int> getUnreadSupportCount() {
    return _firestore
        .collection('conversations')
        .where('isSupport', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        if (unreadCount != null) {
          count += (unreadCount[adminSupportId] as int?) ?? 0;
        }
      }
      return count;
    });
  }

  // ==================== BROADCAST MESSAGES ====================

  /// Send a broadcast message to all users or a specific group
  Future<String?> sendBroadcastMessage({
    required String title,
    required String message,
    required String senderId,
    required String senderName,
    List<String>? targetUserIds, // null = all users
    String? targetRole, // 'client', 'supplier', or null for all
    BroadcastPriority priority = BroadcastPriority.normal,
    String? actionUrl, // Optional deep link
  }) async {
    try {
      final broadcastData = {
        'title': title,
        'message': message,
        'senderId': senderId,
        'senderName': senderName,
        'targetUserIds': targetUserIds,
        'targetRole': targetRole,
        'priority': priority.name,
        'actionUrl': actionUrl,
        'readBy': [],
        'dismissedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': targetUserIds == null
            ? Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)))
            : null,
      };

      final docRef = await _firestore.collection('broadcasts').add(broadcastData);

      // Create notifications for all target users
      if (targetUserIds != null && targetUserIds.isNotEmpty) {
        // Send to specific users
        final batch = _firestore.batch();
        for (final userId in targetUserIds) {
          final notifRef = _firestore.collection('notifications').doc();
          batch.set(notifRef, {
            'userId': userId,
            'type': 'broadcast',
            'title': title,
            'body': message,
            'data': {
              'broadcastId': docRef.id,
              'actionUrl': actionUrl,
            },
            'priority': priority.name,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } else {
        // For all users or role-based, create a single notification marker
        // Users will query for broadcasts targeting their role
        await _firestore.collection('broadcast_markers').doc(docRef.id).set({
          'broadcastId': docRef.id,
          'targetRole': targetRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Broadcast sent: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
      return null;
    }
  }

  /// Get active broadcasts for a user
  Future<List<Map<String, dynamic>>> getActiveBroadcasts({
    required String userId,
    required String userRole,
  }) async {
    try {
      final now = DateTime.now();

      // Get broadcasts that:
      // 1. Target this specific user, OR
      // 2. Target this user's role, OR
      // 3. Target all users (no specific target)
      // AND are not expired AND not dismissed by this user

      final broadcastsQuery = await _firestore
          .collection('broadcasts')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final broadcasts = <Map<String, dynamic>>[];

      for (final doc in broadcastsQuery.docs) {
        final data = doc.data();
        final targetUserIds = data['targetUserIds'] as List<dynamic>?;
        final targetRole = data['targetRole'] as String?;
        final dismissedBy = data['dismissedBy'] as List<dynamic>? ?? [];

        // Skip if user dismissed this broadcast
        if (dismissedBy.contains(userId)) continue;

        // Check if this broadcast targets the user
        bool isTarget = false;

        if (targetUserIds != null && targetUserIds.contains(userId)) {
          isTarget = true;
        } else if (targetRole != null && targetRole == userRole) {
          isTarget = true;
        } else if (targetUserIds == null && targetRole == null) {
          // Broadcast to all users
          isTarget = true;
        }

        if (isTarget) {
          broadcasts.add({
            'id': doc.id,
            ...data,
            'isRead': (data['readBy'] as List<dynamic>? ?? []).contains(userId),
          });
        }
      }

      return broadcasts;
    } catch (e) {
      debugPrint('Error getting broadcasts: $e');
      return [];
    }
  }

  /// Mark broadcast as read
  Future<void> markBroadcastAsRead(String broadcastId, String userId) async {
    try {
      await _firestore.collection('broadcasts').doc(broadcastId).update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      debugPrint('Error marking broadcast as read: $e');
    }
  }

  /// Dismiss broadcast for user
  Future<void> dismissBroadcast(String broadcastId, String userId) async {
    try {
      await _firestore.collection('broadcasts').doc(broadcastId).update({
        'dismissedBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      debugPrint('Error dismissing broadcast: $e');
    }
  }

  /// Get broadcast statistics (admin)
  Future<Map<String, dynamic>> getBroadcastStats(String broadcastId) async {
    try {
      final doc = await _firestore.collection('broadcasts').doc(broadcastId).get();
      if (!doc.exists) return {};

      final data = doc.data()!;
      final readBy = data['readBy'] as List<dynamic>? ?? [];
      final dismissedBy = data['dismissedBy'] as List<dynamic>? ?? [];
      final targetUserIds = data['targetUserIds'] as List<dynamic>?;

      int totalTargets = 0;
      if (targetUserIds != null) {
        totalTargets = targetUserIds.length;
      } else {
        // Count all users of target role or all users
        final targetRole = data['targetRole'] as String?;
        if (targetRole != null) {
          final usersCount = await _firestore
              .collection('users')
              .where('role', isEqualTo: targetRole)
              .count()
              .get();
          totalTargets = usersCount.count ?? 0;
        } else {
          final usersCount = await _firestore.collection('users').count().get();
          totalTargets = usersCount.count ?? 0;
        }
      }

      return {
        'totalTargets': totalTargets,
        'readCount': readBy.length,
        'dismissedCount': dismissedBy.length,
        'readRate': totalTargets > 0 ? (readBy.length / totalTargets * 100) : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting broadcast stats: $e');
      return {};
    }
  }

  /// Get all broadcasts (admin)
  Future<List<Map<String, dynamic>>> getAllBroadcasts({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('broadcasts')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting all broadcasts: $e');
      return [];
    }
  }

  /// Delete a broadcast
  Future<void> deleteBroadcast(String broadcastId) async {
    try {
      await _firestore.collection('broadcasts').doc(broadcastId).delete();
      await _firestore.collection('broadcast_markers').doc(broadcastId).delete();
    } catch (e) {
      debugPrint('Error deleting broadcast: $e');
      rethrow;
    }
  }
}

/// Broadcast message priority levels
enum BroadcastPriority {
  low,
  normal,
  high,
  urgent,
}
