import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/providers/settings_provider.dart';
import 'package:boda_connect/core/providers/market_provider.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/push_notification_provider.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/routing/app_router.dart';
import 'package:boda_connect/core/services/deep_link_service.dart';
import 'package:boda_connect/core/services/logger_service.dart';
import 'package:boda_connect/core/services/offline_sync_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BodaConnectApp extends ConsumerStatefulWidget {
  const BodaConnectApp({super.key});

  @override
  ConsumerState<BodaConnectApp> createState() => _BodaConnectAppState();
}

class _BodaConnectAppState extends ConsumerState<BodaConnectApp> {
  bool _servicesInitialized = false;
  String? _pushUserId;
  ProviderSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Defer ALL ref usage to after first frame renders
    // This is required because ref.listenManual cannot be called in initState
    // before the widget is mounted to ProviderScope
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAuthSubscription();
      if (!_servicesInitialized) {
        _initializeServicesDeferred();
      }
    });
  }

  /// Setup auth state subscription for push notifications
  /// Must be called after widget is mounted (not in initState directly)
  void _setupAuthSubscription() {
    _authSubscription = ref.listenManual<AuthState>(authProvider, (previous, next) {
      final notifier = ref.read(pushNotificationProvider.notifier);

      if (next.status == AuthStatus.authenticated &&
          next.firebaseUser != null) {
        final userId = next.firebaseUser!.uid;
        if (_pushUserId != userId) {
          _pushUserId = userId;
          notifier.initialize();
          if (next.userType == UserType.supplier) {
            notifier.subscribeForSupplier(userId);
          } else if (next.userType == UserType.client) {
            notifier.subscribeForClient(userId);
          }
        }
      }

      if (previous?.status == AuthStatus.authenticated &&
          next.status == AuthStatus.unauthenticated) {
        _pushUserId = null;
        notifier.onLogout();
      }
    });
  }

  // PERFORMANCE: 5 second timeout per service to prevent infinite hangs
  static const _serviceTimeout = Duration(seconds: 5);

  /// Initialize services after first frame to avoid jank
  /// PERFORMANCE: Uses timeouts to prevent any service from blocking others
  Future<void> _initializeServicesDeferred() async {
    if (_servicesInitialized) return;
    _servicesInitialized = true;

    // Run initializations in parallel with individual timeouts for fault tolerance
    await Future.wait([
      _initOfflineSync(),
      _initPushNotifications(),
      _initDeepLinks(),
      _initMarket(),
    ], eagerError: false); // Continue even if one fails
  }

  Future<void> _initOfflineSync() async {
    try {
      await OfflineSyncService().initialize().timeout(
        _serviceTimeout,
        onTimeout: () {
          Log.warn('Offline sync initialization timed out');
        },
      );
    } catch (e) {
      Log.warn('Failed to initialize offline sync: $e');
    }
  }

  Future<void> _initPushNotifications() async {
    try {
      final notifier = ref.read(pushNotificationProvider.notifier);
      notifier.setRouter(appRouter);
      await notifier.initialize().timeout(
        _serviceTimeout,
        onTimeout: () {
          Log.warn('Push notifications initialization timed out');
        },
      );
    } catch (e) {
      Log.warn('Failed to initialize notifications: $e');
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      await DeepLinkService().initialize(appRouter).timeout(
        _serviceTimeout,
        onTimeout: () {
          Log.warn('Deep links initialization timed out');
        },
      );
    } catch (e) {
      Log.warn('Failed to initialize deep links: $e');
    }
  }

  Future<void> _initMarket() async {
    try {
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      ref.read(marketProvider.notifier).detectFromLocale(locale);
    } catch (e) {
      Log.warn('Failed to detect market: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings for font size and theme changes
    final fontScale = ref.watch(fontScaleProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(fontScale),
      ),
      child: MaterialApp.router(
      title: 'BODA CONNECT',
      debugShowCheckedModeBanner: false,

      // Localization - uses device language automatically
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // Routing
      routerConfig: appRouter,
      
      // Theme
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        
        // Color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.peach,
          primary: AppColors.peach,
          secondary: AppColors.peachDark,
          surface: Colors.white,
          surfaceContainerHighest: AppColors.background,
          error: AppColors.error,
        ),
        
        // Scaffold
        scaffoldBackgroundColor: AppColors.background,
        
        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        
        // Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.peach,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.peach,
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Input decoration
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.peach, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        
        // Cards
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        
        // Bottom navigation
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.peach,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        
        // Tabs
        tabBarTheme: const TabBarTheme(
          labelColor: AppColors.peach,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.peach,
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // Dialogs
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        
        // Snackbar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.gray900,
          contentTextStyle: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        
        // Divider
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
        ),
        
        // Chip
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.gray100,
          selectedColor: AppColors.peachLight,
          labelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      
      // Dark theme (optional)
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.peach,
          brightness: Brightness.dark,
        ),
      ),
      
      // Use theme from settings
      themeMode: themeMode,
      ),
    );
  }
}
