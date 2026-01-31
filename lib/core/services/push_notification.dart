import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routing/app_router.dart';
import '../routing/route_names.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background message: ${message.messageId}');
}

/// Push Notification Service
///
/// Handles FCM setup, token management, and local notifications
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'boda_connect_channel',
    'BODA CONNECT',
    description: 'Notificações do BODA CONNECT',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize push notifications
  ///
  /// POLICY: This method NEVER blocks app startup.
  /// On Web: Skip permission request entirely (browser handles this)
  /// On Mobile: Request permission once, gracefully handle denial
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Skip push notification setup on web - browser handles notifications differently
    // We don't want to show permission dialogs or log errors on web
    if (kIsWeb) {
      _isInitialized = true;
      debugPrint('📱 Push notifications: Web platform detected, skipping FCM setup');
      // On web, just set up message listeners without requesting permission
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      } catch (_) {
        // Silently ignore web FCM issues
      }
      return;
    }

    // MOBILE ONLY: Request permission and set up FCM
    try {
      // Request permission (only on mobile)
      final granted = await _requestPermission();

      if (!granted) {
        debugPrint('📱 Push notifications: Permission not granted');
        // Don't block - user can enable later
        _isInitialized = true;
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Create Android notification channel (mobile only)
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from terminated state)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Get and save FCM token
      await _saveFcmToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) {
        _updateFcmToken(token);
      });

      debugPrint('✅ Push notifications initialized');
    } catch (e) {
      // Never block app startup - log and continue
      debugPrint('📱 Push notifications: Setup failed (non-blocking): $e');
    }

    _isInitialized = true;
  }

  /// Request notification permission
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('📱 Notification permission: ${settings.authorizationStatus}');
    return granted;
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📩 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    final android = message.notification?.android;

    // Show local notification on Android (skip on web)
    if (notification != null && android != null && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle notification tap (from background)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.data}');
    _navigateFromNotification(message.data);
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromNotification(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    debugPrint('📍 Navigating from notification: type=$type');

    switch (type) {
      case 'new_booking':
      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'booking_update':
        final bookingId = data['bookingId'] as String?;
        if (bookingId != null) {
          appRouter.push('${Routes.supplierOrderDetail}?bookingId=$bookingId');
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
        final senderId = data['senderId'] as String?;
        final senderName = data['senderName'] as String? ?? 'Utilizador';
        if (senderId != null) {
          appRouter.push(
            '${Routes.chatDetail}?userId=$senderId&userName=${Uri.encodeComponent(senderName)}',
          );
        } else {
          appRouter.push(Routes.chatList);
        }
        break;

      case 'new_proposal':
      case 'proposal_accepted':
      case 'proposal_rejected':
        final senderId = data['senderId'] as String?;
        if (senderId != null) {
          appRouter.push('${Routes.chatDetail}?userId=$senderId');
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
      case 'badge_awarded':
        appRouter.push(Routes.notifications);
        break;

      default:
        appRouter.push(Routes.notifications);
        break;
    }
  }

  /// Get and save FCM token
  Future<void> _saveFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Update FCM token in Firestore (skipped on Web - different push mechanism)
  Future<void> _updateFcmToken(String token) async {
    // Skip FCM token storage on Web - Web uses different push notification flow
    if (kIsWeb) {
      debugPrint('📱 FCM token update skipped on Web');
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCM token updated');
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Subscribe to a topic (not supported on Web)
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) {
      debugPrint('📢 Topic subscription skipped on Web: $topic');
      return;
    }
    await _messaging.subscribeToTopic(topic);
    debugPrint('📢 Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic (not supported on Web)
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) {
      debugPrint('📢 Topic unsubscription skipped on Web: $topic');
      return;
    }
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('📢 Unsubscribed from topic: $topic');
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Clear FCM token (on logout)
  Future<void> clearToken() async {
    // Skip Firestore update on Web
    if (!kIsWeb) {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        try {
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': FieldValue.delete(),
          });
        } catch (e) {
          debugPrint('Error clearing FCM token: $e');
        }
      }
    }
    await _messaging.deleteToken();
    debugPrint('🗑️ FCM token cleared');
  }

  /// Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Get notification settings
  Future<NotificationSettings> getSettings() async {
    return await _messaging.getNotificationSettings();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await getSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
