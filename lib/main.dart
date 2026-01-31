import 'package:boda_connect/app.dart';
import 'package:boda_connect/core/services/logger_service.dart';
import 'package:boda_connect/core/services/messaging_service.dart';
import 'package:boda_connect/core/services/supplier_migration_service.dart';
import 'package:boda_connect/firebase_options.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ==================== APP CHECK ====================
  // App Check is DISABLED until debug tokens are registered in Firebase Console
  //
  // To enable App Check:
  // 1. Run app and look for debug token in logs: "App Check debug token: XXXX-XXXX-..."
  // 2. Go to Firebase Console > App Check > Apps > Your App > Manage debug tokens
  // 3. Add the debug token from step 1
  // 4. Uncomment the code below
  //
  // try {
  //   await FirebaseAppCheck.instance.activate(
  //     androidProvider: AndroidProvider.debug,
  //     appleProvider: AppleProvider.debug,
  //   );
  //   Log.success('App Check initialized');
  // } catch (e) {
  //   Log.warn('App Check initialization skipped: $e');
  // }
  Log.info('App Check disabled - enable after registering debug tokens in Firebase Console');

  // ==================== AFRICA NETWORK OPTIMIZATIONS ====================

  // Enable offline persistence (CRITICAL for African networks)
  // Note: Web uses IndexedDB for persistence automatically
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ==================== SUPPLIER DATA MIGRATION ====================
  // Run migration in background to fix suppliers with missing isActive field
  // This ensures approved suppliers (accountStatus: active) appear in search
  _runSupplierMigration();

  // ==================== CRASHLYTICS ====================

  // Crashlytics is not supported on web
  if (!kIsWeb) {
    // Pass all uncaught errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Disable Crashlytics in debug mode
    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }
  }

  // ==================== PUSH NOTIFICATIONS ====================

  // Background message handler is not supported on web
  if (!kIsWeb) {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ==================== LOCAL STORAGE ====================

  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Open cache boxes in parallel for faster startup
  await Future.wait([
    Hive.openBox('user_cache'),
    Hive.openBox('suppliers_cache'),
    Hive.openBox('settings'),
  ]);

  // ==================== LOCALIZATION ====================

  // Initialize localization
  await EasyLocalization.ensureInitialized();

  // ==================== SYSTEM UI ====================

  // System UI is not applicable on web
  if (!kIsWeb) {
    // Set preferred orientations (portrait only for mobile)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ==================== RUN APP ====================

  // Translation path differs by platform:
  // - Web: 'translations' (Flutter web auto-prepends 'assets/')
  // - Mobile: 'assets/translations' (direct path to assets folder)
  final translationsPath = kIsWeb ? 'translations' : 'assets/translations';

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('pt'), // Portuguese (primary)
        Locale('en'), // English (secondary)
      ],
      path: translationsPath,
      fallbackLocale: const Locale('pt'),
      child: const ProviderScope(
        child: BodaConnectApp(),
      ),
    ),
  );
}

/// Run supplier migration in background (non-blocking)
/// This fixes suppliers with accountStatus: active but missing isActive: true
void _runSupplierMigration() {
  Future.microtask(() async {
    try {
      final migrationService = SupplierMigrationService();
      final result = await migrationService.runMigration();
      if (result.fixed > 0) {
        Log.success('Supplier migration: fixed ${result.fixed} suppliers');
      }
    } catch (e) {
      Log.warn('Supplier migration error (non-critical): $e');
    }
  });
}