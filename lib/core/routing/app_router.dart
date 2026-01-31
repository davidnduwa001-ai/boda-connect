import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/models/package_model.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/features/auth/presentation/screens/account_type_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/client_register_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/login_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/phone_number_input_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/splash_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/supplier_register_screen.dart';
import 'package:boda_connect/features/auth/presentation/screens/welcome_screen.dart';
import 'package:boda_connect/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:boda_connect/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_bookings_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_categories_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_details_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_favorites_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_history_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_home_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_package_detail_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_payment_methods_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_preferences_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_profile_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_profile_edit_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_search_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_supplier_detail_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/cart_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/payment_success_screen.dart';
import 'package:boda_connect/features/payments/presentation/screens/checkout_screen.dart';
import 'package:boda_connect/features/payments/presentation/screens/payment_confirm_screen.dart';
import 'package:boda_connect/features/payments/presentation/screens/payment_failed_screen.dart';
import 'package:boda_connect/features/payments/presentation/screens/stripe_success_screen.dart';
import 'package:boda_connect/features/payments/presentation/screens/stripe_cancel_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_availability_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_basic_data_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_document_verification_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_create_service_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_dashboard_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_orders_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_order_detail_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_packages_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/notifications_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/payment_methods_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/reviews_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_pricing_availability_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/help_center_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/security_privacy_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/settings_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/suspended_account_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/terms_privacy_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/violations_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/submit_report_screen.dart';
import 'package:boda_connect/features/common/presentation/screens/safety_history_screen.dart';
import 'package:boda_connect/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:boda_connect/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:boda_connect/features/admin/presentation/screens/admin_onboarding_queue_screen.dart';
import 'package:boda_connect/features/admin/presentation/screens/admin_reports_dashboard.dart';
import 'package:boda_connect/features/admin/presentation/screens/admin_broadcast_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_verification_pending_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_profile_edit_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_profile_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_public_profile_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_registration_success_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_revenue_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_service_description_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_service_type_screen.dart';
import 'package:boda_connect/features/supplier/presentation/screens/supplier_upload_content_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Routes that don't require authentication
const _publicRoutes = [
  Routes.splash,
  Routes.welcome,
  Routes.login,
  Routes.accountType,
  Routes.registerClient,
  Routes.registerSupplier,
  Routes.inputPhone,
  Routes.inputWhatsapp,
  Routes.inputEmail,
  Routes.otpVerification,
  Routes.terms,
  Routes.adminLogin,
  // Stripe Checkout return URLs (allow access after payment redirect)
  Routes.stripeSuccess,
  Routes.stripeCancel,
];

final GoRouter appRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
  // Redirect handler for web URL safety
  redirect: (context, state) {
    // Only apply redirect logic on web for direct URL access
    if (!kIsWeb) return null;

    final currentPath = state.matchedLocation;
    final isPublicRoute = _publicRoutes.contains(currentPath);
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;

    // Allow public routes
    if (isPublicRoute) return null;

    // Redirect unauthenticated users to splash (which handles auth state)
    if (!isAuthenticated) {
      debugPrint('🔒 Web redirect: unauthenticated access to $currentPath -> splash');
      return Routes.splash;
    }

    return null;
  },
  routes: [
    // ==================== AUTH & ONBOARDING ====================
    GoRoute(
      path: Routes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: Routes.accountType,
      builder: (context, state) => const AccountTypeScreen(),
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.registerClient,
      builder: (context, state) => const ClientRegisterScreen(),
    ),
    GoRoute(
      path: Routes.registerSupplier,
      builder: (context, state) => const SupplierRegisterScreen(),
    ),

    // Phone input routes
    GoRoute(
      path: Routes.inputPhone,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final isLogin = (extra?['isLogin'] as bool?) ?? false;
        final userType = extra?['userType'] as UserType?;
        return PhoneNumberInputScreen(
          type: PhoneInputType.phone,
          isLogin: isLogin,
          userType: userType,
        );
      },
    ),
    GoRoute(
      path: Routes.inputWhatsapp,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final isLogin = (extra?['isLogin'] as bool?) ?? false;
        final userType = extra?['userType'] as UserType?;
        return PhoneNumberInputScreen(
          type: PhoneInputType.whatsapp,
          isLogin: isLogin,
          userType: userType,
        );
      },
    ),

    // Email input route
    GoRoute(
      path: Routes.inputEmail,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final isLogin = (extra?['isLogin'] as bool?) ?? false;
        final userType = extra?['userType'] as UserType?;
        return EmailAuthScreen(
          isLogin: isLogin,
          userType: userType,
        );
      },
    ),

    // OTP Verification - handles both login and registration
    // Supports query params for web reload-safety
    GoRoute(
      path: Routes.otpVerification,
      redirect: (context, state) {
        // Check if we have the required phone number
        final extra = state.extra as Map<String, dynamic>?;
        final queryParams = state.uri.queryParameters;
        final phone = extra?['phone'] as String? ?? queryParams['phone'];

        // If phone is missing on web, redirect to login (can't continue OTP flow)
        if (phone == null || phone.isEmpty) {
          if (kIsWeb) {
            debugPrint('🔒 OTP redirect: missing phone on web -> login');
            return Routes.login;
          }
        }
        return null;
      },
      builder: (context, state) {
        debugPrint('🔗 OTP Route - state.extra type: ${state.extra.runtimeType}');

        final extra = state.extra as Map<String, dynamic>?;
        final queryParams = state.uri.queryParameters;

        // Support both extra (from navigation) and query params (from URL/reload)
        final isLogin = (extra?['isLogin'] as bool?) ??
            (queryParams['isLogin'] == 'true');
        final userTypeStr = extra?['userType'] as UserType? ??
            (queryParams['userType'] != null
                ? UserType.values.firstWhere(
                    (e) => e.name == queryParams['userType'],
                    orElse: () => UserType.client,
                  )
                : null);
        final phone = extra?['phone'] as String? ?? queryParams['phone'] ?? '';
        final countryCode = extra?['countryCode'] as String? ?? queryParams['countryCode'];
        final isWhatsApp = (extra?['isWhatsApp'] as bool?) ??
            (queryParams['isWhatsApp'] == 'true');
        final verificationId = extra?['verificationId'] as String? ??
            queryParams['verificationId'];

        debugPrint('🔗 OTP Route - phone: $phone, verificationId: $verificationId');

        return OTPVerificationScreen(
          isLogin: isLogin,
          userType: userTypeStr,
          phone: phone,
          countryCode: countryCode,
          isWhatsApp: isWhatsApp,
          verificationId: verificationId,
        );
      },
    ),

    // ==================== CLIENT REGISTRATION ====================
    GoRoute(
      path: Routes.clientDetails,
      builder: (context, state) => const ClientDetailsScreen(),
    ),
    GoRoute(
      path: Routes.clientPreferences,
      builder: (context, state) => const ClientPreferencesScreen(),
    ),

    // ==================== SUPPLIER REGISTRATION ====================
    GoRoute(
      path: Routes.supplierBasicData,
      builder: (context, state) => const SupplierBasicDataScreen(),
    ),
    GoRoute(
      path: Routes.supplierDocumentVerification,
      builder: (context, state) => const SupplierDocumentVerificationScreen(),
    ),
    GoRoute(
      path: Routes.supplierServiceType,
      builder: (context, state) => const SupplierServiceTypeScreen(),
    ),
    GoRoute(
      path: Routes.supplierDescription,
      builder: (context, state) => const SupplierServiceDescriptionScreen(),
    ),
    GoRoute(
      path: Routes.supplierUpload,
      builder: (context, state) => const SupplierUploadContentScreen(),
    ),
    GoRoute(
      path: Routes.supplierPricing,
      builder: (context, state) => const SupplierPricingAvailabilityScreen(),
    ),
    GoRoute(
      path: Routes.registerCompleted,
      builder: (context, state) => const SupplierRegistrationSuccessScreen(),
    ),

    // ==================== SUPPLIER APP ====================
    GoRoute(
      path: Routes.supplierDashboard,
      builder: (context, state) => const SupplierDashboardScreen(),
    ),
    GoRoute(
      path: Routes.supplierVerificationPending,
      builder: (context, state) => const SupplierVerificationPendingScreen(),
    ),
    GoRoute(
      path: Routes.supplierPackages,
      builder: (context, state) => const SupplierPackagesScreen(),
    ),
    GoRoute(
      path: Routes.supplierAvailability,
      builder: (context, state) => const SupplierAvailabilityScreen(),
    ),
    GoRoute(
      path: Routes.supplierRevenue,
      builder: (context, state) => const SupplierRevenueScreen(),
    ),
    GoRoute(
      path: Routes.supplierOrders,
      builder: (context, state) => const SupplierOrdersScreen(),
    ),
    GoRoute(
      path: Routes.supplierOrderDetail,
      builder: (context, state) {
        // Support both extra data (BookingModel) and query parameter (bookingId)
        final extra = state.extra;
        final bookingId = state.uri.queryParameters['bookingId'];

        if (extra is BookingModel) {
          return SupplierOrderDetailScreen(booking: extra);
        }

        return SupplierOrderDetailScreen(bookingId: bookingId);
      },
    ),
    GoRoute(
      path: Routes.supplierPublicProfile,
      builder: (context, state) => const SupplierPublicProfileScreen(),
    ),
    GoRoute(
      path: Routes.supplierProfile,
      builder: (context, state) => const SupplierProfileScreen(),
    ),
    GoRoute(
      path: Routes.supplierProfileEdit,
      builder: (context, state) => const SupplierProfileEditScreen(),
    ),
    GoRoute(
      path: Routes.supplierCreateService,
      builder: (context, state) {
        // Check if a package was passed for editing
        final packageToEdit = state.extra is PackageModel ? state.extra as PackageModel : null;
        return SupplierCreateServiceScreen(packageToEdit: packageToEdit);
      },
    ),
    GoRoute(
      path: Routes.supplierPaymentMethods,
      builder: (context, state) => const PaymentMethodsScreen(),
    ),
    GoRoute(
      path: Routes.supplierReviews,
      builder: (context, state) {
        final supplierId = state.uri.queryParameters['supplierId'];
        return ReviewsScreen(supplierId: supplierId);
      },
    ),

    // ==================== CLIENT APP ====================
    GoRoute(
      path: Routes.clientHome,
      builder: (context, state) => const ClientHomeScreen(),
    ),
    GoRoute(
      path: Routes.clientSearch,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ClientSearchScreen(
          initialCategory: extra?['category'] as String?,
          initialSubcategory: extra?['subcategory'] as String?,
        );
      },
    ),
    GoRoute(
      path: Routes.clientCategories,
      builder: (context, state) => const ClientCategoriesScreen(),
    ),
    GoRoute(
      path: Routes.clientCategoryDetail,
      builder: (context, state) => const ClientCategoriesScreen(),
    ),
    GoRoute(
      path: Routes.clientSupplierDetail,
      builder: (context, state) {
        // Support both extra (from push) and query parameter (from deep links)
        final supplierId = state.extra as String? ?? state.uri.queryParameters['id'];
        return ClientSupplierDetailScreen(supplierId: supplierId);
      },
    ),
    GoRoute(
      path: Routes.clientPackageDetail,
      builder: (context, state) {
        // Support both extra (from push) and query parameter (for web reload-safety)
        final packageId = state.uri.queryParameters['id'];
        return ClientPackageDetailScreen(
          packageModel: state.extra as PackageModel?,
          packageId: packageId, // Fallback for web reload
        );
      },
    ),
    GoRoute(
      path: Routes.clientFavorites,
      builder: (context, state) => const ClientFavoritesScreen(),
    ),
    GoRoute(
      path: Routes.clientBookings,
      builder: (context, state) => const ClientBookingsScreen(),
    ),
    GoRoute(
      path: Routes.clientHistory,
      builder: (context, state) => const ClientHistoryScreen(),
    ),
    GoRoute(
      path: Routes.clientProfile,
      builder: (context, state) => const ClientProfileScreen(),
    ),
    GoRoute(
      path: Routes.clientProfileEdit,
      builder: (context, state) => const ClientProfileEditScreen(),
    ),
    GoRoute(
      path: Routes.clientCart,
      builder: (context, state) => const CartScreen(),
    ),

    // ==================== CHAT ====================
    GoRoute(
      path: Routes.chatList,
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: Routes.chatDetail,
      builder: (context, state) {
        // Support both extra data and query parameters
        final queryParams = state.uri.queryParameters;
        // Note: GoRouter automatically decodes query parameters
        final userId = queryParams['userId'];
        final userName = queryParams['userName'];

        debugPrint('🔗 ChatDetail route - userId: $userId, userName: $userName');

        return ChatDetailScreen(
          chatPreview: state.extra,
          conversationId: queryParams['conversationId'],
          otherUserId: userId,
          otherUserName: userName,
        );
      },
    ),

    // ==================== CHECKOUT & PAYMENTS ====================
    // All payment routes support both state.extra and query parameters
    // for reload-safety on web
    GoRoute(
      path: Routes.checkout,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final queryParams = state.uri.queryParameters;
        // Prefer extra (from navigation), fallback to query params (from URL/reload)
        return CheckoutScreen(
          bookingId: extra?['bookingId'] ?? queryParams['bookingId'] ?? '',
          amount: extra?['amount'] ?? int.tryParse(queryParams['amount'] ?? '') ?? 0,
          description: extra?['description'] ?? queryParams['description'] ?? '',
          supplierName: extra?['supplierName'] ?? queryParams['supplierName'],
        );
      },
    ),
    GoRoute(
      path: Routes.paymentMethod,
      builder: (context, state) => const ClientPaymentMethodsScreen(),
    ),
    GoRoute(
      path: Routes.paymentSuccess,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final queryParams = state.uri.queryParameters;
        // Support both extra and query params for reload-safety
        // bookingId can come from extra, query param, or be derived from paymentId
        final bookingId = extra?['bookingId'] as String? ??
            queryParams['bookingId'] ??
            queryParams['paymentId'] ?? // Fallback: use paymentId as identifier
            '';
        return PaymentSuccessScreen(
          bookingId: bookingId,
          paymentMethod: extra?['paymentMethod'] as String? ??
              queryParams['method'] ??
              queryParams['paymentMethod'] ??
              '',
          totalAmount: extra?['totalAmount'] as int? ??
              int.tryParse(queryParams['amount'] ?? '') ??
              0,
        );
      },
    ),
    GoRoute(
      path: Routes.paymentConfirm,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final queryParams = state.uri.queryParameters;
        return PaymentConfirmScreen(
          bookingId: extra?['bookingId'] ?? queryParams['bookingId'] ?? '',
          amount: extra?['amount'] ?? int.tryParse(queryParams['amount'] ?? '') ?? 0,
          paymentMethod: extra?['paymentMethod'] ?? queryParams['paymentMethod'] ?? '',
          reference: extra?['reference'] ?? queryParams['reference'],
        );
      },
    ),
    GoRoute(
      path: Routes.paymentFailed,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final queryParams = state.uri.queryParameters;
        return PaymentFailedScreen(
          bookingId: extra?['bookingId'] ?? queryParams['bookingId'],
          errorMessage: extra?['errorMessage'] ?? queryParams['error'],
        );
      },
    ),

    // Stripe Checkout return routes
    GoRoute(
      path: Routes.stripeSuccess,
      builder: (context, state) {
        final bookingId = state.uri.queryParameters['bookingId'];
        return StripeSuccessScreen(bookingId: bookingId);
      },
    ),
    GoRoute(
      path: Routes.stripeCancel,
      builder: (context, state) {
        final bookingId = state.uri.queryParameters['bookingId'];
        return StripeCancelScreen(bookingId: bookingId);
      },
    ),

    // ==================== NOTIFICATIONS ====================
    GoRoute(
      path: Routes.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),

    // ==================== REPORTS & SAFETY ====================
    GoRoute(
      path: Routes.submitReport,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final reportedId =
            extra['reportedId'] as String? ?? state.uri.queryParameters['reportedId'];
        final reportedType =
            extra['reportedType'] as String? ?? state.uri.queryParameters['reportedType'];
        final reportedName =
            extra['reportedName'] as String? ?? state.uri.queryParameters['reportedName'] ?? 'User';
        final bookingId =
            extra['bookingId'] as String? ?? state.uri.queryParameters['bookingId'];
        final reviewId =
            extra['reviewId'] as String? ?? state.uri.queryParameters['reviewId'];
        final chatId =
            extra['chatId'] as String? ?? state.uri.queryParameters['chatId'];

        if (reportedId == null || reportedType == null) {
          return const Scaffold(
            body: Center(child: Text('Missing report details')),
          );
        }

        return SubmitReportScreen(
          reportedId: reportedId,
          reportedType: reportedType,
          reportedName: reportedName,
          bookingId: bookingId,
          reviewId: reviewId,
          chatId: chatId,
        );
      },
    ),
    GoRoute(
      path: Routes.safetyHistory,
      builder: (context, state) {
        final userId = state.extra as String? ??
            state.uri.queryParameters['userId'] ??
            FirebaseAuth.instance.currentUser?.uid;

        if (userId == null || userId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Missing user id')),
          );
        }

        return SafetyHistoryScreen(userId: userId);
      },
    ),

    // ==================== HELP & SUPPORT ====================
    GoRoute(
      path: Routes.helpCenter,
      builder: (context, state) => const HelpCenterScreen(),
    ),
    GoRoute(
      path: Routes.securityPrivacy,
      builder: (context, state) => const SecurityPrivacyScreen(),
    ),

    // ==================== SETTINGS ====================
    GoRoute(
      path: Routes.clientSettings,
      builder: (context, state) => const SettingsScreen(isSupplier: false),
    ),
    GoRoute(
      path: Routes.supplierSettings,
      builder: (context, state) => const SettingsScreen(isSupplier: true),
    ),
    GoRoute(
      path: Routes.terms,
      builder: (context, state) => const TermsPrivacyScreen(),
    ),

    // ==================== VIOLATIONS & SUSPENSION ====================
    GoRoute(
      path: Routes.violations,
      builder: (context, state) => const ViolationsScreen(),
    ),
    GoRoute(
      path: Routes.suspendedAccount,
      builder: (context, state) => const SuspendedAccountScreen(),
    ),

    // ==================== ADMIN ====================
    GoRoute(
      path: Routes.adminLogin,
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: Routes.adminDashboard,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: Routes.adminOnboardingQueue,
      builder: (context, state) => const AdminOnboardingQueueScreen(),
    ),
    GoRoute(
      path: Routes.adminReports,
      builder: (context, state) => const AdminReportsDashboard(),
    ),
    GoRoute(
      path: Routes.adminBroadcast,
      builder: (context, state) => const AdminBroadcastScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Página não encontrada',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            state.uri.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(Routes.welcome),
            child: const Text('Voltar ao início'),
          ),
        ],
      ),
    ),
  ),
);
