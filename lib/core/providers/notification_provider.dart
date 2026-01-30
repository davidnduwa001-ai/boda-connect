import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'auth_provider.dart';

// ==================== REPOSITORY PROVIDER ====================

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// ==================== NOTIFICATION STATE ====================

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// ==================== NOTIFICATION NOTIFIER ====================

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationNotifier(this._repository, this._ref)
      : super(const NotificationState());

  // Load notifications
  Future<void> loadNotifications() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final notifications = await _repository.getNotifications(userId);
      final unreadCount =
          notifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar notificações',
      );
    }
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    try {
      await _repository.markAllAsRead(userId);

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        return n.copyWith(isRead: true);
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);

      // Update local state
      final updatedNotifications = state.notifications
          .where((n) => n.id != notificationId)
          .toList();

      final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  // Delete all notifications
  Future<void> deleteAll() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    try {
      await _repository.deleteAllNotifications(userId);

      state = state.copyWith(
        notifications: [],
        unreadCount: 0,
      );
    } catch (e) {
      debugPrint('❌ Error deleting all notifications: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ==================== PROVIDERS ====================

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationNotifier(repository, ref);
});

/// Unread count provider
///
/// UI-FIRST: Prefers projection-based count, falls back to local state.
/// Import clientUnreadNotificationsProvider and supplierUnreadNotificationsProvider
/// from the respective view providers for accurate real-time counts.
final unreadNotificationCountProvider = Provider<int>((ref) {
  // This returns the locally calculated count from loaded notifications.
  // For real-time UI-First counts, use:
  // - clientUnreadNotificationsProvider (for clients)
  // - supplierUnreadNotificationsProvider (for suppliers)
  return ref.watch(notificationProvider).unreadCount;
});

// Notifications stream provider (for real-time updates)
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final userId = ref.watch(authProvider).firebaseUser?.uid;
  if (userId == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotificationsStream(userId);
});
