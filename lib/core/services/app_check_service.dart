import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Firebase App Check service for protecting against abuse
/// Validates that requests come from legitimate app instances
///
/// This service implements:
/// - Token caching to reduce API calls
/// - Circuit breaker pattern to prevent "Too many attempts" errors
/// - Graceful degradation when App Check fails
///
/// SETUP REQUIRED:
/// 1. Enable App Check in Firebase Console
/// 2. Register your apps:
///    - Android: Use Play Integrity or SafetyNet (requires proper release signing)
///    - iOS: Use App Attest or DeviceCheck
///    - Web: Use reCAPTCHA Enterprise or reCAPTCHA v3
/// 3. Register debug tokens in Firebase Console for development
/// 4. Enforce App Check on Cloud Functions and Firestore (optional)
class AppCheckService {
  static final AppCheckService _instance = AppCheckService._internal();
  factory AppCheckService() => _instance;
  AppCheckService._internal();

  bool _isInitialized = false;

  // Circuit breaker state
  bool _circuitOpen = false;
  DateTime? _circuitOpenedAt;
  int _failureCount = 0;

  // Token cache
  String? _cachedToken;
  DateTime? _tokenExpiresAt;

  // Configuration
  static const int _maxFailures = 3;
  static const Duration _circuitResetDuration = Duration(minutes: 5);
  static const Duration _tokenCacheDuration = Duration(minutes: 50);

  /// Initialize Firebase App Check
  /// Call this after Firebase.initializeApp()
  /// Note: Initialization is now done in main.dart, this is for manual control
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // App Check is already activated in main.dart
      // This method is kept for backward compatibility
      _isInitialized = true;
      debugPrint('✅ App Check service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize App Check: $e');
      _recordFailure();
    }
  }

  /// Get App Check token with caching and circuit breaker
  /// Returns null if token cannot be obtained (fails gracefully)
  Future<String?> getToken({bool forceRefresh = false}) async {
    // Check circuit breaker
    if (_isCircuitOpen()) {
      debugPrint('⚠️ App Check circuit breaker is open, skipping token request');
      return _cachedToken; // Return stale token if available
    }

    // Return cached token if still valid
    if (!forceRefresh && _isTokenValid()) {
      return _cachedToken;
    }

    try {
      final tokenResult = await FirebaseAppCheck.instance.getToken(forceRefresh);
      if (tokenResult != null) {
        _cachedToken = tokenResult;
        _tokenExpiresAt = DateTime.now().add(_tokenCacheDuration);
        _resetFailures();
        return _cachedToken;
      }
      return null;
    } catch (e) {
      final errorString = e.toString().toLowerCase();

      // Check for rate limiting errors
      if (errorString.contains('too many attempts') ||
          errorString.contains('rate limit') ||
          errorString.contains('quota exceeded')) {
        debugPrint('⚠️ App Check rate limited: $e');
        _openCircuit();
      } else {
        debugPrint('❌ Failed to get App Check token: $e');
        _recordFailure();
      }

      // Return stale token if available, otherwise null
      return _cachedToken;
    }
  }

  /// Check if App Check is active and working
  bool get isActive => _isInitialized && !_circuitOpen;

  /// Check if circuit breaker is open
  bool _isCircuitOpen() {
    if (!_circuitOpen) return false;

    // Check if enough time has passed to reset the circuit
    if (_circuitOpenedAt != null) {
      final elapsed = DateTime.now().difference(_circuitOpenedAt!);
      if (elapsed >= _circuitResetDuration) {
        _closeCircuit();
        return false;
      }
    }

    return true;
  }

  /// Check if cached token is still valid
  bool _isTokenValid() {
    if (_cachedToken == null || _tokenExpiresAt == null) return false;
    return DateTime.now().isBefore(_tokenExpiresAt!);
  }

  /// Record a failure and potentially open the circuit
  void _recordFailure() {
    _failureCount++;
    if (_failureCount >= _maxFailures) {
      _openCircuit();
    }
  }

  /// Open the circuit breaker
  void _openCircuit() {
    _circuitOpen = true;
    _circuitOpenedAt = DateTime.now();
    debugPrint('🔴 App Check circuit breaker opened - will retry after $_circuitResetDuration');
  }

  /// Close the circuit breaker
  void _closeCircuit() {
    _circuitOpen = false;
    _circuitOpenedAt = null;
    _failureCount = 0;
    debugPrint('🟢 App Check circuit breaker closed');
  }

  /// Reset failure count
  void _resetFailures() {
    _failureCount = 0;
  }

  /// Manually reset the circuit breaker (for testing/debugging)
  void resetCircuitBreaker() {
    _closeCircuit();
    _cachedToken = null;
    _tokenExpiresAt = null;
  }
}

/// Instructions for setting up Firebase App Check
///
/// ## Android Setup (Play Integrity)
/// 1. In Firebase Console > App Check > Apps > Android
/// 2. Register app with Play Integrity
/// 3. IMPORTANT: Play Integrity requires proper release signing
///    - Debug-signed builds will fail with "Too many attempts" errors
///    - For development, use Debug provider and register debug tokens
/// 4. Add to android/app/build.gradle:
///    ```
///    dependencies {
///        implementation 'com.google.firebase:firebase-appcheck-playintegrity'
///    }
///    ```
///
/// ## Debug Token Setup (REQUIRED for development)
/// 1. Run the app in debug mode
/// 2. Look for "App Check debug token" in logs
/// 3. Go to Firebase Console > App Check > Apps > Manage debug tokens
/// 4. Add the debug token from logs
///
/// ## iOS Setup (App Attest)
/// 1. In Firebase Console > App Check > Apps > iOS
/// 2. Register app with App Attest
/// 3. Enable App Attest capability in Xcode
/// 4. Add to ios/Podfile:
///    ```
///    pod 'FirebaseAppCheck'
///    ```
///
/// ## Web Setup (reCAPTCHA Enterprise)
/// 1. Go to Google Cloud Console > reCAPTCHA Enterprise
/// 2. Create a new key for your domain
/// 3. In Firebase Console > App Check > Apps > Web
/// 4. Register with reCAPTCHA Enterprise site key
///
/// ## Enforcement (Optional - enable after testing)
/// 1. Firebase Console > App Check > APIs
/// 2. Enable enforcement for:
///    - Cloud Firestore
///    - Cloud Functions
///    - Cloud Storage
///    - Realtime Database (if used)
///
/// ## Troubleshooting "Too many attempts" error
/// This error occurs when:
/// - Using Play Integrity with debug-signed builds
/// - App Check tokens are being requested too frequently
/// - Debug tokens are not registered in Firebase Console
///
/// Solutions:
/// 1. Use debug provider during development (current configuration)
/// 2. Register debug tokens in Firebase Console
/// 3. Use proper release signing for production builds
class AppCheckSetupInstructions {
  static const String androidSetup = '''
# Android Setup (build.gradle)
dependencies {
    implementation 'com.google.firebase:firebase-appcheck-playintegrity'
}

# IMPORTANT: For production, ensure proper release signing is configured
# Debug-signed builds will fail with Play Integrity
''';

  static const String iosSetup = '''
# iOS Setup (Podfile)
pod 'FirebaseAppCheck'

# Also enable App Attest in Xcode:
# Signing & Capabilities > + Capability > App Attest
''';

  static const String pubspecSetup = '''
# pubspec.yaml
dependencies:
  firebase_app_check: ^0.3.2+10
''';

  static const String flutterCode = '''
// main.dart - After Firebase.initializeApp()

// For development (debug provider - no special signing required):
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.debug,
  appleProvider: AppleProvider.debug,
);

// For production (requires proper signing):
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.appAttest,
  webProvider: ReCaptchaEnterpriseProvider('YOUR_SITE_KEY'),
);
''';

  static const String debugTokenSetup = '''
# Debug Token Setup (REQUIRED for development)

1. Run the app and look for this log message:
   "App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

2. Go to Firebase Console:
   - Select your project
   - Go to App Check > Apps
   - Select your app
   - Click "Manage debug tokens"
   - Add the token from step 1

3. The app will now work in debug mode without "Too many attempts" errors
''';
}
