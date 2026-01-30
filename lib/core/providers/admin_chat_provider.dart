import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/services/admin_chat_service.dart';

/// Provider for AdminChatService
final adminChatServiceProvider = Provider<AdminChatService>((ref) {
  return AdminChatService();
});

/// Provider for support conversations stream (admin dashboard)
final supportConversationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(adminChatServiceProvider);
  return service.getSupportConversations();
});

/// Provider for unread support count (admin dashboard)
final unreadSupportCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(adminChatServiceProvider);
  return service.getUnreadSupportCount();
});

/// Provider for active broadcasts for a user
final activeBroadcastsProvider = FutureProvider.family<List<Map<String, dynamic>>, UserBroadcastParams>((ref, params) async {
  final service = ref.watch(adminChatServiceProvider);
  return service.getActiveBroadcasts(
    userId: params.userId,
    userRole: params.userRole,
  );
});

/// Parameters for getting user broadcasts
class UserBroadcastParams {
  final String userId;
  final String userRole;

  const UserBroadcastParams({
    required this.userId,
    required this.userRole,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserBroadcastParams &&
        other.userId == userId &&
        other.userRole == userRole;
  }

  @override
  int get hashCode => userId.hashCode ^ userRole.hashCode;
}

/// Notifier for admin chat actions
class AdminChatNotifier extends StateNotifier<AsyncValue<void>> {
  final AdminChatService _service;

  AdminChatNotifier(this._service) : super(const AsyncValue.data(null));

  /// Create or get support conversation
  Future<String?> getOrCreateSupportConversation({
    required String userId,
    required String userName,
    String? userPhoto,
    required String userRole,
  }) async {
    state = const AsyncValue.loading();
    try {
      final conversationId = await _service.getOrCreateSupportConversation(
        userId: userId,
        userName: userName,
        userPhoto: userPhoto,
        userRole: userRole,
      );
      state = const AsyncValue.data(null);
      return conversationId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Send broadcast message
  Future<String?> sendBroadcast({
    required String title,
    required String message,
    required String senderId,
    required String senderName,
    List<String>? targetUserIds,
    String? targetRole,
    BroadcastPriority priority = BroadcastPriority.normal,
    String? actionUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final broadcastId = await _service.sendBroadcastMessage(
        title: title,
        message: message,
        senderId: senderId,
        senderName: senderName,
        targetUserIds: targetUserIds,
        targetRole: targetRole,
        priority: priority,
        actionUrl: actionUrl,
      );
      state = const AsyncValue.data(null);
      return broadcastId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Mark broadcast as read
  Future<void> markBroadcastAsRead(String broadcastId, String userId) async {
    await _service.markBroadcastAsRead(broadcastId, userId);
  }

  /// Dismiss broadcast
  Future<void> dismissBroadcast(String broadcastId, String userId) async {
    await _service.dismissBroadcast(broadcastId, userId);
  }
}

/// Provider for admin chat notifier
final adminChatNotifierProvider = StateNotifierProvider<AdminChatNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(adminChatServiceProvider);
  return AdminChatNotifier(service);
});
