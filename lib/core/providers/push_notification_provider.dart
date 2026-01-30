import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/push_notification.dart';
import '../routing/route_names.dart';

// ==================== PUSH NOTIFICATION SERVICE PROVIDER ====================

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

// ==================== NOTIFICATION STATE ====================

class NotificationState {
  final bool isInitialized;
  final bool permissionGranted;
  final String? fcmToken;
  final List<String> subscribedTopics;
  final PendingNavigation? pendingNavigation;

  const NotificationState({
    this.isInitialized = false,
    this.permissionGranted = false,
    this.fcmToken,
    this.subscribedTopics = const [],
    this.pendingNavigation,
  });

  NotificationState copyWith({
    bool? isInitialized,
    bool? permissionGranted,
    String? fcmToken,
    List<String>? subscribedTopics,
    PendingNavigation? pendingNavigation,
    bool clearPendingNavigation = false,
  }) {
    return NotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      fcmToken: fcmToken ?? this.fcmToken,
      subscribedTopics: subscribedTopics ?? this.subscribedTopics,
      pendingNavigation: clearPendingNavigation ? null : (pendingNavigation ?? this.pendingNavigation),
    );
  }
}

/// Pending navigation from notification tap
class PendingNavigation {
  final String route;
  final Map<String, dynamic>? extra;
  final DateTime timestamp;

  const PendingNavigation({
    required this.route,
    this.extra,
    required this.timestamp,
  });
}

// ==================== NOTIFICATION NOTIFIER ====================

class PushNotificationNotifier extends StateNotifier<NotificationState> {
  final PushNotificationService _notificationService;
  GoRouter? _router;

  PushNotificationNotifier(this._notificationService)
      : super(const NotificationState());

  /// Set the router for navigation
  void setRouter(GoRouter router) {
    _router = router;
    // Process any pending navigation
    _processPendingNavigation();
  }

  /// Initialize push notifications
  /// Handles all errors gracefully - push notifications are optional and should never block app startup
  Future<void> initialize() async {
    if (state.isInitialized) return;

    try {
      await _notificationService.initialize();

      // These calls may also throw if permission is blocked, so wrap them
      bool permissionGranted = false;
      String? token;

      try {
        permissionGranted = await _notificationService.areNotificationsEnabled();
        if (permissionGranted) {
          token = await _notificationService.getToken();
        }
      } catch (_) {
        // Permission check failed - treat as not granted
        permissionGranted = false;
      }

      state = state.copyWith(
        isInitialized: true,
        permissionGranted: permissionGranted,
        fcmToken: token,
      );

      if (permissionGranted) {
        debugPrint('✅ Push notification provider initialized');
      } else {
        debugPrint('📱 Push notifications: Not enabled (user can enable in settings)');
      }
    } catch (e) {
      // Log gracefully without alarming error symbol
      // Permission-blocked errors are normal when user has disabled notifications
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || errorString.contains('blocked')) {
        debugPrint('📱 Push notifications: Permission not available');
      } else {
        debugPrint('📱 Push notifications: Setup skipped ($e)');
      }
      state = state.copyWith(isInitialized: true);
    }
  }

  /// Subscribe to topics based on user role
  Future<void> subscribeForSupplier(String supplierId) async {
    final topics = [
      'suppliers',
      'supplier_$supplierId',
      'promotions',
    ];

    for (final topic in topics) {
      await _notificationService.subscribeToTopic(topic);
    }

    state = state.copyWith(
      subscribedTopics: [...state.subscribedTopics, ...topics],
    );
  }

  /// Subscribe to topics based on user role
  Future<void> subscribeForClient(String clientId) async {
    final topics = [
      'clients',
      'client_$clientId',
      'promotions',
    ];

    for (final topic in topics) {
      await _notificationService.subscribeToTopic(topic);
    }

    state = state.copyWith(
      subscribedTopics: [...state.subscribedTopics, ...topics],
    );
  }

  /// Unsubscribe from all topics
  Future<void> unsubscribeAll() async {
    for (final topic in state.subscribedTopics) {
      await _notificationService.unsubscribeFromTopic(topic);
    }
    state = state.copyWith(subscribedTopics: []);
  }

  /// Handle notification tap and navigate
  void handleNotificationTap(Map<String, dynamic> data) {
    final route = _getRouteFromNotificationData(data);

    if (_router != null) {
      _navigateTo(route, data);
    } else {
      // Store pending navigation for when router is available
      state = state.copyWith(
        pendingNavigation: PendingNavigation(
          route: route,
          extra: data,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Get route from notification data
  String _getRouteFromNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'new_booking':
      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'booking_completed':
        return Routes.supplierOrders;

      case 'new_message':
        final chatId = data['chatId'] as String?;
        if (chatId != null) {
          return Routes.chatDetail;
        }
        return Routes.chatList;

      case 'new_review':
        return Routes.supplierReviews;

      case 'payment_received':
        return Routes.supplierRevenue;

      case 'supplier_verified':
        return Routes.supplierDashboard;

      case 'client_booking_update':
        return Routes.clientBookings;

      default:
        return Routes.notifications;
    }
  }

  /// Navigate to route
  void _navigateTo(String route, Map<String, dynamic>? data) {
    if (_router == null) return;

    try {
      // Handle routes that need extra data
      if (route == Routes.chatDetail && data?['chatId'] != null) {
        final chatId = data!['chatId'] as String;
        final senderId = data['senderId'] as String?;
        final senderName = data['senderName'] as String? ?? 'Usuário';
        final encodedName = Uri.encodeComponent(senderName);
        _router!.push('$route?conversationId=$chatId&userId=$senderId&userName=$encodedName');
      } else if (route == Routes.supplierOrderDetail && data?['bookingId'] != null) {
        _router!.push(route, extra: data!['bookingId']);
      } else {
        _router!.push(route);
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
    }
  }

  /// Process any pending navigation
  void _processPendingNavigation() {
    final pending = state.pendingNavigation;
    if (pending == null || _router == null) return;

    // Only process if notification is recent (within 5 minutes)
    final age = DateTime.now().difference(pending.timestamp);
    if (age.inMinutes < 5) {
      _navigateTo(pending.route, pending.extra);
    }

    state = state.copyWith(clearPendingNavigation: true);
  }

  /// Show local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _notificationService.showNotification(
      title: title,
      body: body,
      data: data,
    );
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  /// Logout cleanup
  Future<void> onLogout() async {
    await unsubscribeAll();
    await _notificationService.clearToken();
    await clearAllNotifications();
  }

  /// Request permission if not granted
  Future<bool> requestPermission() async {
    final granted = await _notificationService.areNotificationsEnabled();
    state = state.copyWith(permissionGranted: granted);
    return granted;
  }
}

// ==================== PROVIDER ====================

final pushNotificationProvider =
    StateNotifierProvider<PushNotificationNotifier, NotificationState>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);
  return PushNotificationNotifier(service);
});

// ==================== NOTIFICATION TOPICS ====================

/// Predefined notification topics
class NotificationTopics {
  static const String allUsers = 'all_users';
  static const String suppliers = 'suppliers';
  static const String clients = 'clients';
  static const String promotions = 'promotions';
  static const String updates = 'app_updates';

  /// User-specific topic
  static String userTopic(String userId) => 'user_$userId';

  /// Supplier-specific topic
  static String supplierTopic(String supplierId) => 'supplier_$supplierId';

  /// Client-specific topic
  static String clientTopic(String clientId) => 'client_$clientId';

  /// Category-specific topic
  static String categoryTopic(String category) => 'category_$category';
}

// ==================== NOTIFICATION TYPES ====================

/// Notification types for routing
class NotificationTypes {
  static const String newBooking = 'new_booking';
  static const String bookingConfirmed = 'booking_confirmed';
  static const String bookingCancelled = 'booking_cancelled';
  static const String bookingCompleted = 'booking_completed';
  static const String newMessage = 'new_message';
  static const String newReview = 'new_review';
  static const String paymentReceived = 'payment_received';
  static const String supplierVerified = 'supplier_verified';
  static const String clientBookingUpdate = 'client_booking_update';
  static const String promotion = 'promotion';
}
