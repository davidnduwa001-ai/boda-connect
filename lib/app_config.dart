/// Application configuration for BODA CONNECT
/// 
/// Region: Angola / Africa
/// Database: Firestore (africa-south1)
/// Storage: Firebase Storage (africa-south1)
class AppConfig {
  AppConfig._();

  // ==================== APP INFO ====================
  
  static const String appName = 'BODA CONNECT';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  
  // ==================== REGION CONFIGURATION ====================
  
  /// Firebase region (Johannesburg - closest to Angola)
  static const String firebaseRegion = 'africa-south1';
  
  /// Default country code for phone numbers
  static const String defaultCountryCode = '+244'; // Angola
  
  /// Supported country codes
  static const List<CountryCode> supportedCountryCodes = [
    CountryCode(code: '+244', name: 'Angola', flag: '🇦🇴'),
    CountryCode(code: '+351', name: 'Portugal', flag: '🇵🇹'),
    CountryCode(code: '+258', name: 'Moçambique', flag: '🇲🇿'),
    CountryCode(code: '+55', name: 'Brasil', flag: '🇧🇷'),
  ];
  
  /// Default timezone
  static const String defaultTimezone = 'Africa/Luanda';
  
  /// Default locale
  static const String defaultLocale = 'pt_AO';

  // ==================== CURRENCY ====================
  
  /// Default currency code
  static const String defaultCurrencyCode = 'AOA';
  
  /// Default currency symbol
  static const String defaultCurrencySymbol = 'Kz';
  
  /// Currency locale for formatting
  static const String currencyLocale = 'pt_AO';
  
  /// Supported currencies
  static const List<Currency> supportedCurrencies = [
    Currency(code: 'AOA', symbol: 'Kz', name: 'Kwanza'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro'),
    Currency(code: 'USD', symbol: '\$', name: 'Dólar'),
  ];

  // ==================== CONTACT INFO ====================
  
  static const String supportEmail = 'suporte@bodaconnect.ao';
  static const String supportPhone = '+244 923 000 000';
  static const String websiteUrl = 'https://bodaconnect.ao';
  
  // ==================== SOCIAL MEDIA ====================
  
  static const String facebookUrl = 'https://facebook.com/bodaconnect';
  static const String instagramUrl = 'https://instagram.com/bodaconnect';
  static const String whatsappNumber = '+244923000000';

  // ==================== LEGAL ====================
  
  static const String privacyPolicyUrl = 'https://bodaconnect.ao/privacidade';
  static const String termsOfServiceUrl = 'https://bodaconnect.ao/termos';
  
  // ==================== FEATURE FLAGS ====================
  
  /// Enable chat feature
  static const bool enableChat = true;
  
  /// Enable video uploads
  static const bool enableVideoUploads = true;
  
  /// Enable push notifications
  static const bool enablePushNotifications = true;
  
  /// Enable analytics
  static const bool enableAnalytics = true;
  
  /// Enable crashlytics
  static const bool enableCrashlytics = true;
  
  /// Enable offline mode
  static const bool enableOfflineMode = true;

  // ==================== LIMITS ====================
  
  /// Maximum supplier photos
  static const int maxSupplierPhotos = 20;
  
  /// Maximum supplier videos
  static const int maxSupplierVideos = 5;
  
  /// Maximum package photos
  static const int maxPackagePhotos = 10;
  
  /// Maximum bio length
  static const int maxBioLength = 500;
  
  /// Maximum review length
  static const int maxReviewLength = 1000;
  
  /// Minimum booking advance (hours)
  static const int minBookingAdvanceHours = 24;
  
  /// Maximum booking advance (days)
  static const int maxBookingAdvanceDays = 365;

  // ==================== COMMISSION ====================
  
  /// Platform commission percentage
  static const double platformCommissionPercent = 10.0;
  
  /// Minimum booking amount (AOA)
  static const int minBookingAmountAOA = 5000;

  // ==================== HELPERS ====================

  /// Format currency amount
  static String formatCurrency(
    num amount, {
    String? currencyCode,
    String? locale,
  }) {
    final code = currencyCode ?? defaultCurrencyCode;
    final symbol = supportedCurrencies
        .firstWhere(
          (c) => c.code == code,
          orElse: () => supportedCurrencies.first,
        )
        .symbol;
    
    // Simple formatting (use intl package for production)
    final formatted = amount.toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
    
    return '$formatted $symbol';
  }

  /// Get country by code
  static CountryCode? getCountryByCode(String code) {
    try {
      return supportedCountryCodes.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// Country code model
class CountryCode {
  final String code;
  final String name;
  final String flag;

  const CountryCode({
    required this.code,
    required this.name,
    required this.flag,
  });

  @override
  String toString() => '$flag $name ($code)';
}

/// Currency model
class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  @override
  String toString() => '$name ($symbol)';
}