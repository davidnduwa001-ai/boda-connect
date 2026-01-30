import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: deprecated_member_use
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../routing/route_names.dart';

/// Deep Link Service for handling app links and Firebase Dynamic Links
///
/// ⚠️ DEPRECATION WARNING ⚠️
/// Firebase Dynamic Links is DEPRECATED and will SHUT DOWN on August 25, 2025.
/// This service MUST be migrated before that date or deep linking will break.
///
/// MIGRATION REQUIRED:
/// 1. Replace firebase_dynamic_links with app_links package
/// 2. Configure Android App Links and iOS Universal Links directly
/// 3. Set up server-side link handling at your domain
///
/// See migration guide: https://firebase.google.com/support/dynamic-links-faq
///
/// Supports:
/// - Firebase Dynamic Links (bodaconnect.page.link) - DEPRECATED
/// - Custom scheme links (bodaconnect://)
/// - Universal links (https://bodaconnect.ao)
@Deprecated('Firebase Dynamic Links shuts down Aug 25, 2025. Migrate to app_links package.')
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  final FirebaseDynamicLinks _dynamicLinks = FirebaseDynamicLinks.instance;
  GoRouter? _router;
  bool _isInitialized = false;

  /// Initialize deep link handling
  /// Call this in app.dart after the router is created
  Future<void> initialize(GoRouter router) async {
    if (_isInitialized) return;

    _router = router;
    _isInitialized = true;

    // Skip on web (Firebase Dynamic Links not supported)
    if (kIsWeb) {
      debugPrint('⚠️ Deep links not supported on web');
      return;
    }

    try {
      // Handle link that opened the app (cold start)
      final initialLink = await _dynamicLinks.getInitialLink();
      if (initialLink != null) {
        debugPrint('📲 App opened via deep link: ${initialLink.link}');
        _handleDynamicLink(initialLink);
      }

      // Handle links while app is running (warm start)
      _dynamicLinks.onLink.listen(
        _handleDynamicLink,
        onError: (error) {
          debugPrint('❌ Deep link error: $error');
        },
      );

      debugPrint('✅ Deep Link Service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize deep links: $e');
    }
  }

  /// Handle incoming dynamic link
  void _handleDynamicLink(PendingDynamicLinkData data) {
    final Uri deepLink = data.link;
    debugPrint('🔗 Handling deep link: $deepLink');

    final path = deepLink.path;
    final params = deepLink.queryParameters;

    // Route based on path
    switch (path) {
      // Payment callbacks from Multicaixa
      case '/payment/success':
        final reference = params['ref'];
        final bookingId = params['bookingId'];
        _router?.go(Routes.paymentSuccess, extra: {
          'reference': reference,
          'bookingId': bookingId,
        });
        break;

      case '/payment/cancel':
      case '/payment/failed':
        final reference = params['ref'];
        final bookingId = params['bookingId'];
        _router?.go(Routes.paymentFailed, extra: {
          'bookingId': bookingId,
          'reference': reference,
          'errorMessage': 'Pagamento cancelado',
        });
        break;

      // Booking deep link
      case '/booking':
        final bookingId = params['id'];
        if (bookingId != null) {
          // Navigate to booking detail
          _router?.go('${Routes.clientBookings}?bookingId=$bookingId');
        }
        break;

      // Supplier profile deep link
      case '/supplier':
        final supplierId = params['id'];
        if (supplierId != null) {
          _router?.go('${Routes.clientSupplierDetail}?id=$supplierId');
        }
        break;

      // Category deep link
      case '/category':
        final categoryId = params['id'];
        if (categoryId != null) {
          _router?.go('${Routes.clientCategories}?category=$categoryId');
        }
        break;

      // Invite/referral link
      case '/invite':
        final referralCode = params['code'];
        // Store referral code and navigate to signup
        if (referralCode != null) {
          debugPrint('📨 Referral code: $referralCode');
          _storeReferralCode(referralCode);
          _router?.go(Routes.welcome);
        }
        break;

      // Default: go to home
      default:
        debugPrint('⚠️ Unknown deep link path: $path');
        _router?.go(Routes.splash);
    }
  }

  /// Create a dynamic link for sharing
  Future<Uri> createDynamicLink({
    required String path,
    Map<String, String>? queryParams,
    String? title,
    String? description,
    String? imageUrl,
  }) async {
    final queryString = queryParams?.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&') ??
        '';

    final link = Uri.parse(
      'https://${AppConfig.appDomain}$path${queryString.isNotEmpty ? '?$queryString' : ''}',
    );

    final parameters = DynamicLinkParameters(
      uriPrefix: 'https://${AppConfig.dynamicLinkDomain}',
      link: link,
      androidParameters: AndroidParameters(
        packageName: AppConfig.playStoreId,
        minimumVersion: 1,
      ),
      iosParameters: IOSParameters(
        bundleId: AppConfig.playStoreId, // Use same ID format
        appStoreId: AppConfig.appStoreId,
        minimumVersion: '1.0.0',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: title ?? AppConfig.appName,
        description: description ?? 'Serviços de casamento em Angola',
        imageUrl: imageUrl != null ? Uri.parse(imageUrl) : null,
      ),
    );

    final shortLink = await _dynamicLinks.buildShortLink(parameters);
    return shortLink.shortUrl;
  }

  /// Create a supplier share link
  Future<Uri> createSupplierLink({
    required String supplierId,
    required String supplierName,
    String? imageUrl,
  }) async {
    return createDynamicLink(
      path: '/supplier',
      queryParams: {'id': supplierId},
      title: supplierName,
      description: 'Veja $supplierName no BODA CONNECT',
      imageUrl: imageUrl,
    );
  }

  /// Create a booking share link
  Future<Uri> createBookingLink({
    required String bookingId,
  }) async {
    return createDynamicLink(
      path: '/booking',
      queryParams: {'id': bookingId},
      title: 'Reserva BODA CONNECT',
      description: 'Detalhes da sua reserva',
    );
  }

  /// Create a category browse link
  Future<Uri> createCategoryLink({
    required String categoryId,
    required String categoryName,
  }) async {
    return createDynamicLink(
      path: '/category',
      queryParams: {'id': categoryId},
      title: categoryName,
      description: 'Explore $categoryName no BODA CONNECT',
    );
  }

  /// Create a referral/invite link
  Future<Uri> createInviteLink({
    required String referralCode,
    String? userName,
  }) async {
    return createDynamicLink(
      path: '/invite',
      queryParams: {'code': referralCode},
      title: 'Junte-se ao BODA CONNECT',
      description: userName != null
          ? '$userName convida você para o BODA CONNECT'
          : 'Descubra os melhores serviços de casamento',
    );
  }

  /// Get payment return URL for Multicaixa
  String getPaymentReturnUrl(String reference) {
    return '${AppConfig.deepLinkScheme}://${AppConfig.paymentSuccessPath}?ref=$reference';
  }

  /// Get payment cancel URL for Multicaixa
  String getPaymentCancelUrl(String reference) {
    return '${AppConfig.deepLinkScheme}://${AppConfig.paymentCancelPath}?ref=$reference';
  }

  // ==================== REFERRAL CODE MANAGEMENT ====================

  static const String _referralCodeKey = 'pending_referral_code';
  static const String _referralTimestampKey = 'referral_code_timestamp';
  static const Duration _referralCodeExpiry = Duration(days: 30);

  /// Store referral code in SharedPreferences
  Future<void> _storeReferralCode(String referralCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_referralCodeKey, referralCode);
      await prefs.setInt(_referralTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('✅ Referral code stored: $referralCode');
    } catch (e) {
      debugPrint('❌ Error storing referral code: $e');
    }
  }

  /// Get stored referral code (if not expired)
  Future<String?> getStoredReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_referralCodeKey);
      final timestamp = prefs.getInt(_referralTimestampKey);

      if (code == null || timestamp == null) return null;

      // Check if expired
      final storedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(storedTime) > _referralCodeExpiry) {
        await clearReferralCode();
        return null;
      }

      return code;
    } catch (e) {
      debugPrint('❌ Error getting referral code: $e');
      return null;
    }
  }

  /// Clear stored referral code (call after successful registration)
  Future<void> clearReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_referralCodeKey);
      await prefs.remove(_referralTimestampKey);
      debugPrint('✅ Referral code cleared');
    } catch (e) {
      debugPrint('❌ Error clearing referral code: $e');
    }
  }

  /// Apply referral code for a new user registration
  /// Call this after successful registration to credit the referrer
  Future<bool> applyReferralCode({
    required String newUserId,
    required String newUserName,
  }) async {
    try {
      final referralCode = await getStoredReferralCode();
      if (referralCode == null) return false;

      final firestore = FirebaseFirestore.instance;

      // Find the referrer by their referral code
      final referrerQuery = await firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) {
        debugPrint('⚠️ Referrer not found for code: $referralCode');
        await clearReferralCode();
        return false;
      }

      final referrerDoc = referrerQuery.docs.first;
      final referrerId = referrerDoc.id;
      final referrerData = referrerDoc.data();
      final referrerName = referrerData['name'] as String? ?? 'Usuário';

      // Create referral record
      await firestore.collection('referrals').add({
        'referrerId': referrerId,
        'referrerName': referrerName,
        'referredUserId': newUserId,
        'referredUserName': newUserName,
        'referralCode': referralCode,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update referrer's stats
      await firestore.collection('users').doc(referrerId).update({
        'totalReferrals': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for referrer
      await firestore.collection('notifications').add({
        'userId': referrerId,
        'type': 'referral_success',
        'title': 'Convite Aceito!',
        'message': '$newUserName se juntou ao BODA CONNECT através do seu convite.',
        'data': {
          'referredUserId': newUserId,
          'referredUserName': newUserName,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear the referral code after successful application
      await clearReferralCode();

      debugPrint('✅ Referral applied: $referralCode -> $newUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Error applying referral code: $e');
      return false;
    }
  }

  /// Generate a unique referral code for a user
  static String generateReferralCode(String userId) {
    // Use first 4 chars of userId + random suffix
    final prefix = userId.substring(0, 4).toUpperCase();
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return 'BODA$prefix$suffix';
  }
}
