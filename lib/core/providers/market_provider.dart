import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Market enum for Angola and Portugal
enum Market {
  angola('AO', 'Angola', '+244', 'AOA', 'Kz', 'pt_AO'),
  portugal('PT', 'Portugal', '+351', 'EUR', '€', 'pt_PT');

  final String code;
  final String name;
  final String phonePrefix;
  final String currencyCode;
  final String currencySymbol;
  final String locale;

  const Market(
    this.code,
    this.name,
    this.phonePrefix,
    this.currencyCode,
    this.currencySymbol,
    this.locale,
  );
}

/// Market state notifier
class MarketNotifier extends StateNotifier<Market> {
  static const String _marketKey = 'selected_market';

  MarketNotifier() : super(Market.angola) {
    _loadMarket();
  }

  /// Load saved market preference
  Future<void> _loadMarket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final marketCode = prefs.getString(_marketKey);
      if (marketCode != null) {
        state = Market.values.firstWhere(
          (m) => m.code == marketCode,
          orElse: () => Market.angola,
        );
      }
    } catch (e) {
      // Default to Angola
      state = Market.angola;
    }
  }

  /// Set market preference
  Future<void> setMarket(Market market) async {
    state = market;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_marketKey, market.code);
    } catch (e) {
      // Ignore persistence errors
    }
  }

  /// Detect market from device locale
  Future<void> detectFromLocale(Locale locale) async {
    if (locale.countryCode == 'PT') {
      await setMarket(Market.portugal);
    } else if (locale.countryCode == 'AO') {
      await setMarket(Market.angola);
    }
    // Default stays as Angola
  }
}

/// Market provider
final marketProvider = StateNotifierProvider<MarketNotifier, Market>((ref) {
  return MarketNotifier();
});

/// Market service for utility functions
class MarketService {
  /// Format currency based on market
  static String formatCurrency(double amount, Market market) {
    final formatter = NumberFormat.currency(
      locale: market.locale,
      symbol: market.currencySymbol,
      decimalDigits: market == Market.angola ? 0 : 2,
    );
    return formatter.format(amount);
  }

  /// Format currency with code (e.g., "100,000 AOA")
  static String formatCurrencyWithCode(double amount, Market market) {
    final formatter = NumberFormat.decimalPattern(market.locale);
    final formatted = formatter.format(amount);
    return '$formatted ${market.currencyCode}';
  }

  /// Format price for display (compact for large numbers)
  static String formatPriceCompact(double amount, Market market) {
    if (market == Market.angola && amount >= 1000000) {
      // Show as millions for Angola (e.g., "1.5M Kz")
      return '${(amount / 1000000).toStringAsFixed(1)}M ${market.currencySymbol}';
    } else if (amount >= 1000) {
      // Show as thousands (e.g., "500K Kz" or "€1.5K")
      return '${(amount / 1000).toStringAsFixed(1)}K ${market.currencySymbol}';
    }
    return formatCurrency(amount, market);
  }

  /// Get phone number mask based on market
  static String getPhoneMask(Market market) {
    switch (market) {
      case Market.angola:
        return '${market.phonePrefix} 9XX XXX XXX';
      case Market.portugal:
        return '${market.phonePrefix} 9XX XXX XXX';
    }
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone, Market market) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    switch (market) {
      case Market.angola:
        // Angola: 9 digits starting with 9
        return digits.length == 9 && digits.startsWith('9');
      case Market.portugal:
        // Portugal: 9 digits starting with 9
        return digits.length == 9 && digits.startsWith('9');
    }
  }

  /// Format phone number for display
  static String formatPhoneNumber(String phone, Market market) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) return phone;

    // Format as XXX XXX XXX
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
  }

  /// Get full phone number with country code
  static String getFullPhoneNumber(String phone, Market market) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return '${market.phonePrefix}$digits';
  }

  /// Format date based on market locale
  static String formatDate(DateTime date, Market market) {
    final formatter = DateFormat.yMMMMd(market.locale);
    return formatter.format(date);
  }

  /// Format date short (e.g., "15 Jan 2024")
  static String formatDateShort(DateTime date, Market market) {
    final formatter = DateFormat.yMMMd(market.locale);
    return formatter.format(date);
  }

  /// Format time based on market
  static String formatTime(DateTime time, Market market) {
    final formatter = DateFormat.Hm(market.locale);
    return formatter.format(time);
  }

  /// Format date and time
  static String formatDateTime(DateTime dateTime, Market market) {
    final dateFormatter = DateFormat.yMMMd(market.locale);
    final timeFormatter = DateFormat.Hm(market.locale);
    return '${dateFormatter.format(dateTime)} ${timeFormatter.format(dateTime)}';
  }

  /// Get wedding service categories for market
  static List<String> getServiceCategories(Market market) {
    // Base categories available in both markets
    final baseCategories = [
      'venue',
      'catering',
      'photography',
      'videography',
      'music',
      'decoration',
      'flowers',
      'cake',
      'dress',
      'makeup',
      'hair',
      'transport',
      'invitation',
    ];

    // Market-specific additions
    switch (market) {
      case Market.angola:
        return [
          ...baseCategories,
          'tradicional_attire', // Traditional Angolan attire
          'alembamento', // Traditional engagement ceremony
          'live_band', // Live music is popular
        ];
      case Market.portugal:
        return [
          ...baseCategories,
          'wedding_planner',
          'honeymoon',
          'jewelry',
        ];
    }
  }

  /// Get support contact based on market
  static String getSupportEmail(Market market) {
    switch (market) {
      case Market.angola:
        return 'suporte@bodaconnect.ao';
      case Market.portugal:
        return 'suporte@bodaconnect.pt';
    }
  }

  /// Get support phone based on market
  static String getSupportPhone(Market market) {
    switch (market) {
      case Market.angola:
        return '+244 923 000 000';
      case Market.portugal:
        return '+351 910 000 000';
    }
  }

  /// Get WhatsApp support number
  static String getWhatsAppSupport(Market market) {
    switch (market) {
      case Market.angola:
        return '+244923000000';
      case Market.portugal:
        return '+351910000000';
    }
  }

  /// Get minimum booking amount
  static double getMinimumBookingAmount(Market market) {
    switch (market) {
      case Market.angola:
        return 50000; // 50,000 AOA
      case Market.portugal:
        return 100; // 100 EUR
    }
  }

  /// Get platform fee percentage
  static double getPlatformFeePercentage(Market market) {
    // Same fee for both markets
    return 0.05; // 5%
  }

  /// Get payment methods available for market
  static List<PaymentMethodType> getPaymentMethods(Market market) {
    switch (market) {
      case Market.angola:
        return [
          PaymentMethodType.multicaixaExpress,
          PaymentMethodType.bankTransfer,
          PaymentMethodType.atmReference,
        ];
      case Market.portugal:
        return [
          PaymentMethodType.creditCard,
          PaymentMethodType.mbWay,
          PaymentMethodType.bankTransfer,
          PaymentMethodType.multibanco,
        ];
    }
  }

  /// Check if market uses mobile money primarily
  static bool usesMobileMoney(Market market) {
    return market == Market.angola;
  }

  /// Get tax ID label (NIF for both, but different validation)
  static String getTaxIdLabel(Market market) {
    return 'NIF'; // Both use NIF
  }

  /// Validate NIF based on market
  static bool isValidNIF(String nif, Market market) {
    final digits = nif.replaceAll(RegExp(r'\D'), '');

    switch (market) {
      case Market.angola:
        // Angola NIF: 10 digits
        return digits.length == 10;
      case Market.portugal:
        // Portugal NIF: 9 digits with check digit
        if (digits.length != 9) return false;
        return _validatePortugueseNIF(digits);
    }
  }

  /// Validate Portuguese NIF using check digit algorithm
  static bool _validatePortugueseNIF(String nif) {
    if (nif.length != 9) return false;

    // Valid first digits for Portuguese NIF
    final validFirstDigits = ['1', '2', '3', '5', '6', '7', '8', '9'];
    if (!validFirstDigits.contains(nif[0])) return false;

    // Check digit calculation
    int sum = 0;
    for (int i = 0; i < 8; i++) {
      sum += int.parse(nif[i]) * (9 - i);
    }

    int checkDigit = 11 - (sum % 11);
    if (checkDigit >= 10) checkDigit = 0;

    return int.parse(nif[8]) == checkDigit;
  }
}

/// Payment method types
enum PaymentMethodType {
  creditCard,
  multicaixaExpress,
  bankTransfer,
  atmReference,
  mbWay,
  multibanco,
  cash,
}

/// Extension for PaymentMethodType display
extension PaymentMethodTypeExtension on PaymentMethodType {
  String get displayName {
    switch (this) {
      case PaymentMethodType.creditCard:
        return 'Cartão de Crédito/Débito';
      case PaymentMethodType.multicaixaExpress:
        return 'Multicaixa Express';
      case PaymentMethodType.bankTransfer:
        return 'Transferência Bancária';
      case PaymentMethodType.atmReference:
        return 'Referência ATM';
      case PaymentMethodType.mbWay:
        return 'MB WAY';
      case PaymentMethodType.multibanco:
        return 'Multibanco';
      case PaymentMethodType.cash:
        return 'Dinheiro';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethodType.creditCard:
        return Icons.credit_card;
      case PaymentMethodType.multicaixaExpress:
        return Icons.phone_android;
      case PaymentMethodType.bankTransfer:
        return Icons.account_balance;
      case PaymentMethodType.atmReference:
        return Icons.pin;
      case PaymentMethodType.mbWay:
        return Icons.phone_iphone;
      case PaymentMethodType.multibanco:
        return Icons.atm;
      case PaymentMethodType.cash:
        return Icons.money;
    }
  }
}
