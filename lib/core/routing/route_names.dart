/// BODA CONNECT Route Names
class Routes {
  Routes._();

  // Auth & Onboarding
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String accountType = '/account-type';
  static const String login = '/login';

  // Phone/WhatsApp/Email Input
  static const String inputPhone = '/input-phone';
  static const String inputWhatsapp = '/input-whatsapp';
  static const String inputEmail = '/input-email';
  static const String otpVerification = '/otp-verification';

  // Client Registration
  static const String registerClient = '/register-client';
  static const String clientDetails = '/client-details';
  static const String clientPreferences = '/client-preferences';
  static const String clientSuccess = '/client-success';

  // Supplier Registration
  static const String registerSupplier = '/register-supplier';
  static const String supplierBasicData = '/supplier-basic-data';
  static const String supplierDocumentVerification = '/supplier-document-verification';
  static const String supplierServiceType = '/supplier-service-type';
  static const String supplierDescription = '/supplier-description';
  static const String supplierUpload = '/supplier-upload';
  static const String supplierPricing = '/supplier-pricing';
  static const String registerCompleted = '/register-completed';

  // Client App
  static const String clientHome = '/client-home';
  static const String clientSearch = '/client-search';
  static const String clientCategories = '/client-categories';
  static const String clientCategoryDetail = '/client-category-detail';
  static const String clientSupplierDetail = '/client-supplier-detail';
  static const String clientPackageDetail = '/client-package-detail';
  static const String clientFavorites = '/client-favorites';
  static const String clientBookings = '/client-bookings';
  static const String clientHistory = '/client-history';
  static const String clientProfile = '/client-profile';
  static const String clientProfileEdit = '/client-profile-edit';
  static const String clientSettings = '/client-settings';
  static const String clientCart = '/client-cart';

  // Supplier App
  static const String supplierDashboard = '/supplier-dashboard';
  static const String supplierVerificationPending = '/supplier-verification-pending';
  static const String supplierOrders = '/supplier-orders';
  static const String supplierOrderDetail = '/supplier-order-detail';
  static const String supplierCalendar = '/supplier-calendar';
  static const String supplierRevenue = '/supplier-revenue';
  static const String supplierPackages = '/supplier-packages';
  static const String supplierPackageCreate = '/supplier-package-create';
  static const String supplierProfile = '/supplier-profile';
  static const String supplierProfileEdit = '/supplier-profile-edit';
  static const String supplierSettings = '/supplier-settings';
  static const String supplierAvailability = '/supplier-availability';
  static const String supplierPublicProfile = '/supplier-public-profile';
  static const String supplierCreateService = '/supplier-create-service';
  static const String supplierPaymentMethods = '/supplier-payment-methods';
  static const String supplierReviews = '/supplier-reviews';

  // Chat
  static const String chatList = '/chat-list';
  static const String chatDetail = '/chat-detail';
  static const String chatProposal = '/chat-proposal';

  // Checkout & Payments
  static const String checkout = '/checkout';
  static const String paymentMethod = '/payment-method';
  static const String paymentConfirm = '/payment-confirm';
  static const String paymentSuccess = '/payment-success';
  static const String paymentFailed = '/payment-failed';

  // Stripe Checkout return URLs
  static const String stripeSuccess = '/payment/success';
  static const String stripeCancel = '/payment/cancel';

  // Notifications
  static const String notifications = '/notifications';

  // Reports & Safety
  static const String submitReport = '/submit-report';
  static const String safetyHistory = '/safety-history';

  // Help & Support
  static const String helpCenter = '/help-center';

  // Terms & Privacy
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String securityPrivacy = '/security-privacy';

  // Violations & Suspension
  static const String violations = '/violations';
  static const String suspendedAccount = '/suspended-account';

  // Admin
  static const String adminLogin = '/admin';
  static const String adminDashboard = '/admin-dashboard';
  static const String adminOnboardingQueue = '/admin-onboarding-queue';
  static const String adminReports = '/admin-reports';
  static const String adminSupportChats = '/admin-support-chats';
  static const String adminBroadcast = '/admin-broadcast';
}
