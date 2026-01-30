import 'package:flutter/foundation.dart';

/// Firebase App Check service for protecting against abuse
/// Validates that requests come from legitimate app instances
///
/// SETUP REQUIRED:
/// 1. Enable App Check in Firebase Console
/// 2. Register your apps:
///    - Android: Use Play Integrity or SafetyNet
///    - iOS: Use App Attest or DeviceCheck
///    - Web: Use reCAPTCHA Enterprise or reCAPTCHA v3
/// 3. Enforce App Check on Cloud Functions and Firestore
class AppCheckService {
  static final AppCheckService _instance = AppCheckService._internal();
  factory AppCheckService() => _instance;
  AppCheckService._internal();

  bool _isInitialized = false;

  /// Initialize Firebase App Check
  /// Call this after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Note: firebase_app_check package needs to be added to pubspec.yaml
      // Uncomment below once package is added:

      // await FirebaseAppCheck.instance.activate(
      //   // Android: Use Play Integrity for production, debug provider for development
      //   androidProvider: kDebugMode
      //       ? AndroidProvider.debug
      //       : AndroidProvider.playIntegrity,
      //
      //   // iOS: Use App Attest for iOS 14+, Device Check for older
      //   appleProvider: kDebugMode
      //       ? AppleProvider.debug
      //       : AppleProvider.appAttest,
      //
      //   // Web: Use reCAPTCHA Enterprise
      //   webProvider: ReCaptchaEnterpriseProvider('YOUR_RECAPTCHA_SITE_KEY'),
      // );

      // For now, log that App Check setup is pending
      debugPrint('⚠️ Firebase App Check setup pending - add firebase_app_check package');

      _isInitialized = true;
      debugPrint('✅ App Check service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize App Check: $e');
    }
  }

  /// Get App Check token for manual validation
  Future<String?> getToken() async {
    try {
      // Uncomment once firebase_app_check is added:
      // final token = await FirebaseAppCheck.instance.getToken();
      // return token?.token;
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get App Check token: $e');
      return null;
    }
  }

  /// Check if App Check is active
  bool get isActive => _isInitialized;
}

/// Instructions for setting up Firebase App Check
///
/// ## Android Setup (Play Integrity)
/// 1. In Firebase Console > App Check > Apps > Android
/// 2. Register app with Play Integrity
/// 3. Add to android/app/build.gradle:
///    ```
///    dependencies {
///        implementation 'com.google.firebase:firebase-appcheck-playintegrity'
///    }
///    ```
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
/// ## Enforcement
/// 1. Firebase Console > App Check > APIs
/// 2. Enable enforcement for:
///    - Cloud Firestore
///    - Cloud Functions
///    - Cloud Storage
///    - Realtime Database (if used)
///
/// ## Debug Mode
/// For development, use debug providers:
/// - Generate debug token in app
/// - Add to Firebase Console > App Check > Debug tokens
class AppCheckSetupInstructions {
  static const String androidSetup = '''
# Android Setup (build.gradle)
dependencies {
    implementation 'com.google.firebase:firebase-appcheck-playintegrity'
}
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
  firebase_app_check: ^0.2.1+8
''';

  static const String flutterCode = '''
// main.dart - After Firebase.initializeApp()
await FirebaseAppCheck.instance.activate(
  androidProvider: kDebugMode
      ? AndroidProvider.debug
      : AndroidProvider.playIntegrity,
  appleProvider: kDebugMode
      ? AppleProvider.debug
      : AppleProvider.appAttest,
  webProvider: ReCaptchaEnterpriseProvider('YOUR_SITE_KEY'),
);
''';
}
