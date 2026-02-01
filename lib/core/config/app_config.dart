import 'package:flutter/foundation.dart';

/// App configuration for BODA CONNECT
///
/// IMPORTANT: Before launching to production, update the credentials below
class AppConfig {
  // Private constructor
  AppConfig._();

  // ==================== APP INFO ====================

  static const String appName = 'BODA CONNECT';
  static const double baselineWidth = 390;
  static const double baselineHeight = 844;

  static const String appScheme = 'bodaconnect'; // For deep links
  static const String appDomain = 'bodaconnect.ao'; // Your domain
  static const String appStoreId = 'YOUR_APP_STORE_ID'; // iOS App Store ID
  static const String playStoreId = 'ao.bodaconnect.app'; // Android package name

  // ==================== ENVIRONMENT CHECK ====================

  static bool get isDevelopment => kDebugMode;
  static bool get isProduction => !kDebugMode;

  // ==================== PROXYPAY / MULTICAIXA EXPRESS ====================
  //
  // ProxyPay is the official gateway for Multicaixa Express integration.
  // Documentation: https://developer.proxypay.co.ao/
  //
  // 📋 HOW TO GET CREDENTIALS:
  // 1. Contact ProxyPay/TimeBoxed: https://proxypay.co.ao
  // 2. Sign merchant agreement with an Angolan bank
  // 3. Complete business verification (NIF, business documents)
  // 4. Receive API credentials for sandbox and production
  //
  // 📞 ProxyPay Support: Contact via proxypay.co.ao
  //
  // TWO PAYMENT METHODS AVAILABLE:
  // - OPG (Online Payment Gateway): Customer pays via Multicaixa Express app
  // - RPS (Reference Payment System): Customer pays at ATM or home banking

  /// ProxyPay Sandbox Configuration (for testing)
  static const String proxyPaySandboxApiKey = 'YOUR_SANDBOX_API_KEY';
  static const String proxyPaySandboxUrl = 'https://api.sandbox.proxypay.co.ao';

  /// ProxyPay Production Configuration
  /// ⚠️ CRITICAL: Replace with your actual production credentials before launch!
  static const String proxyPayProdApiKey = 'YOUR_PRODUCTION_API_KEY';
  static const String proxyPayProdUrl = 'https://api.proxypay.co.ao';

  /// Get the appropriate ProxyPay configuration based on environment
  static String get proxyPayApiKey =>
      isProduction ? proxyPayProdApiKey : proxyPaySandboxApiKey;

  static String get proxyPayBaseUrl =>
      isProduction ? proxyPayProdUrl : proxyPaySandboxUrl;

  static bool get proxyPayUseSandbox => !isProduction;

  /// ProxyPay Entity ID (assigned by ProxyPay after merchant registration)
  /// This is used for RPS (Reference Payment System) - ATM/home banking payments
  static const String proxyPayEntityId = 'YOUR_ENTITY_ID'; // e.g., "12345"

  /// Payment expiration time in minutes (for OPG mobile payments)
  static const int paymentExpirationMinutes = 30;

  // ==================== WEBHOOK URLS ====================
  //
  // These URLs receive payment notifications from Multicaixa.
  // Deploy these as Firebase Cloud Functions or your backend server.
  //
  // Example Firebase Cloud Function structure:
  // exports.multicaixaWebhook = functions.https.onRequest(async (req, res) => {
  //   const data = req.body;
  //   // Update payment status in Firestore
  //   await db.collection('payments').doc(data.reference).update({
  //     status: data.status,
  //     updatedAt: admin.firestore.FieldValue.serverTimestamp()
  //   });
  //   res.status(200).send('OK');
  // });

  static const String firebaseProjectId = 'boda-connect-49eb9'; // Firebase project ID
  static String get webhookBaseUrl =>
      'https://us-central1-$firebaseProjectId.cloudfunctions.net';

  /// App URL for payment redirects (Stripe checkout)
  static const String appUrl = 'https://boda-connect-49eb9.web.app';

  /// Webhook URL for ProxyPay payment notifications
  /// Deploy this as a Firebase Cloud Function
  static String get proxyPayWebhookUrl => '$webhookBaseUrl/proxyPayWebhook';

  // ==================== DEEP LINKS ====================

  /// App scheme for deep links (bodaconnect://)
  static const String deepLinkScheme = appScheme;

  /// Web domain for universal links
  static const String deepLinkDomain = appDomain;

  /// Firebase Dynamic Links domain
  /// Create this in Firebase Console > Dynamic Links
  static const String dynamicLinkDomain = 'bodaconnect.page.link';

  /// Deep link paths
  static const String paymentSuccessPath = '/payment/success';
  static const String paymentCancelPath = '/payment/cancel';
  static const String bookingPath = '/booking';
  static const String supplierPath = '/supplier';
  static const String categoryPath = '/category';

  // ==================== GOOGLE MAPS ====================

  /// Google Maps API Key - Get from: https://console.cloud.google.com/apis/credentials
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // ==================== ALGOLIA SEARCH ====================

  /// Algolia configuration for search - Get from: https://www.algolia.com/dashboard
  static const String algoliaAppId = 'YOUR_ALGOLIA_APP_ID';
  static const String algoliaSearchApiKey = 'YOUR_ALGOLIA_SEARCH_API_KEY';

  // ==================== PLATFORM DEFAULTS ====================

  /// Default platform fee percentage (can be changed in admin dashboard)
  static const double defaultPlatformFeePercent = 10.0;

  /// Escrow auto-release hours after service completion
  static const int escrowAutoReleaseHours = 48;

  /// Minimum booking amount in AOA
  static const int minimumBookingAmount = 5000;

  // ==================== SUPPORT ====================

  static const String supportEmail = 'support@bodaconnect.ao';
  static const String supportPhone = '+244 XXX XXX XXX';
  static const String supportWhatsApp = '+244XXXXXXXXX';

  // ==================== LEGAL ====================

  static const String privacyPolicyUrl = 'https://bodaconnect.ao/privacy';
  static const String termsOfServiceUrl = 'https://bodaconnect.ao/terms';
}
