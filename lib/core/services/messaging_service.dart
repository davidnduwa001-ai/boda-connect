import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../routing/app_router.dart';
import '../routing/route_names.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Handle background message here
}

/// Auth service interface for messaging
abstract class AuthServiceInterface {
  String? get currentUserId;
  Future<void> updateFcmToken(String userId, String token);
}

class MessagingService {
  MessagingService(this._authService);
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AuthServiceInterface _authService;

  // Notification channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'boda_connect_channel',
    'BODA CONNECT Notificações',
    description: 'Notificações do BODA CONNECT',
    importance: Importance.high,
    playSound: true,
  );

  // ==================== INITIALIZATION ====================

  /// Initialize messaging service
  Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Create Android notification channel
    await _createNotificationChannel();

    // Set up message handlers
    _setupMessageHandlers();

    // Get and save FCM token
    await _saveToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ==================== MESSAGE HANDLERS ====================

  /// Set up foreground and background message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle message tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  /// Handle message received while app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message received: ${message.messageId}');

    final notification = message.notification;

    // Show local notification
    if (notification != null) {
      await _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'BODA CONNECT',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle message tap when app was in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.messageId}');
    _navigateFromNotification(message.data);
  }

  /// Check if app was opened from a notification
  Future<void> _checkInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      print('Initial message: ${message.messageId}');
      _navigateFromNotification(message.data);
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromNotification(data);
    }
  }

  /// Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    print('Navigate from notification: type=$type, id=$id');

    // Navigate based on notification type using GoRouter
    switch (type) {
      case 'new_booking':
      case 'booking_update':
      case 'booking_confirmed':
      case 'booking_cancelled':
        if (id != null) {
          appRouter.push('${Routes.supplierOrderDetail}?bookingId=$id');
        } else {
          appRouter.push(Routes.supplierOrders);
        }
        break;

      case 'booking_rejected':
        // For clients: navigate to their bookings list
        appRouter.push(Routes.clientBookings);
        break;

      case 'new_message':
      case 'chat_message':
        final chatUserId = data['senderId'] as String?;
        final chatUserName = data['senderName'] as String? ?? 'Utilizador';
        if (chatUserId != null) {
          appRouter.push(
            '${Routes.chatDetail}?userId=$chatUserId&userName=${Uri.encodeComponent(chatUserName)}',
          );
        } else {
          appRouter.push(Routes.chatList);
        }
        break;

      case 'new_proposal':
      case 'proposal_update':
        final chatUserId = data['senderId'] as String?;
        if (chatUserId != null) {
          appRouter.push('${Routes.chatDetail}?userId=$chatUserId');
        } else {
          appRouter.push(Routes.chatList);
        }
        break;

      case 'new_review':
      case 'review_received':
        appRouter.push(Routes.supplierReviews);
        break;

      case 'payment_received':
      case 'payment_confirmed':
        appRouter.push(Routes.supplierRevenue);
        break;

      case 'safety_warning':
      case 'safety_probation':
      case 'safety_suspension':
        appRouter.push(Routes.notifications);
        break;

      case 'badge_awarded':
        appRouter.push(Routes.supplierProfile);
        break;

      default:
        // Default to notifications screen
        appRouter.push(Routes.notifications);
        break;
    }
  }

  // ==================== FCM TOKEN ====================

  /// Get FCM token
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Save FCM token to user profile
  Future<void> _saveToken() async {
    final token = await getToken();
    if (token != null && _authService.currentUserId != null) {
      await _authService.updateFcmToken(_authService.currentUserId!, token);
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    print('FCM Token refreshed: $token');
    if (_authService.currentUserId != null) {
      await _authService.updateFcmToken(_authService.currentUserId!, token);
    }
  }

  // ==================== LOCAL NOTIFICATIONS ====================

  /// Show local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show custom notification (for in-app use)
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  // ==================== TOPIC SUBSCRIPTIONS ====================

  /// Subscribe to topic (not supported on Web)
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) {
      print('Topic subscription skipped on Web: $topic');
      return;
    }
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic (not supported on Web)
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) {
      print('Topic unsubscription skipped on Web: $topic');
      return;
    }
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  /// Subscribe user to relevant topics
  Future<void> subscribeUserTopics(String userId, bool isSupplier) async {
    // Subscribe to user-specific topic
    await subscribeToTopic('user_$userId');

    // Subscribe to role-specific topic
    if (isSupplier) {
      await subscribeToTopic('suppliers');
    } else {
      await subscribeToTopic('clients');
    }

    // Subscribe to general announcements
    await subscribeToTopic('announcements');
  }

  /// Unsubscribe user from all topics
  Future<void> unsubscribeUserTopics(String userId, bool isSupplier) async {
    await unsubscribeFromTopic('user_$userId');
    await unsubscribeFromTopic(isSupplier ? 'suppliers' : 'clients');
    await unsubscribeFromTopic('announcements');
  }

  // ==================== BADGE ====================

  /// Clear notification badge (iOS)
  Future<void> clearBadge() async {
    // iOS specific
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(badge: true);
  }
}

// ==================== NOTIFICATION TYPES ====================

class NotificationPayload {
  NotificationPayload({
    required this.type,
    this.id,
    this.extra,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      type: map['type'] ?? '',
      id: map['id'],
      extra:
          map['extra'] != null ? Map<String, dynamic>.from(map['extra']) : null,
    );
  }
  
  final String type;
  final String? id;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'id': id,
      'extra': extra,
    };
  }
}