import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/config/app_config.dart';

/// AppConfig Tests
/// Tests for configuration validation and production readiness checks
void main() {
  group('AppConfig Credential Validation Tests', () {
    test('validateCredentials should return missing credentials list', () {
      // With placeholder values, should return list of missing credentials
      final missing = AppConfig.validateCredentials();

      // These are the placeholder credentials that should be detected
      expect(missing, isNotEmpty);
      expect(missing.contains('ProxyPay API Key'), isTrue);
      expect(missing.contains('ProxyPay Entity ID'), isTrue);
      expect(missing.contains('Google Maps API Key'), isTrue);
      expect(missing.contains('Algolia App ID'), isTrue);
      expect(missing.contains('Algolia Search API Key'), isTrue);
      expect(missing.contains('Support Phone Number'), isTrue);
    });

    test('isFullyConfigured should return false with placeholders', () {
      expect(AppConfig.isFullyConfigured, isFalse);
    });
  });

  group('AppConfig Constants Tests', () {
    test('should have correct app info', () {
      expect(AppConfig.appName, 'BODA CONNECT');
      expect(AppConfig.appScheme, 'bodaconnect');
      expect(AppConfig.appDomain, 'bodaconnect.ao');
    });

    test('should have valid baseline dimensions', () {
      expect(AppConfig.baselineWidth, 390);
      expect(AppConfig.baselineHeight, 844);
    });

    test('should have payment configuration', () {
      expect(AppConfig.paymentExpirationMinutes, 30);
      expect(AppConfig.minimumBookingAmount, 5000);
    });

    test('should have escrow configuration', () {
      expect(AppConfig.escrowAutoReleaseHours, 48);
      expect(AppConfig.defaultPlatformFeePercent, 10.0);
    });

    test('should have support contact info', () {
      expect(AppConfig.supportEmail, 'support@bodaconnect.ao');
      expect(AppConfig.supportPhone, isNotEmpty);
      expect(AppConfig.supportWhatsApp, isNotEmpty);
    });

    test('should have legal URLs', () {
      expect(AppConfig.privacyPolicyUrl, contains('bodaconnect.ao'));
      expect(AppConfig.termsOfServiceUrl, contains('bodaconnect.ao'));
    });
  });

  group('AppConfig Environment Tests', () {
    test('should detect development mode in tests', () {
      // In test environment, kDebugMode is typically true
      expect(AppConfig.isDevelopment, isTrue);
      expect(AppConfig.isProduction, isFalse);
    });

    test('proxyPayUseSandbox should match development mode', () {
      expect(AppConfig.proxyPayUseSandbox, AppConfig.isDevelopment);
    });
  });

  group('AppConfig Deep Link Tests', () {
    test('should have deep link configuration', () {
      expect(AppConfig.deepLinkScheme, AppConfig.appScheme);
      expect(AppConfig.deepLinkDomain, AppConfig.appDomain);
      expect(AppConfig.dynamicLinkDomain, isNotEmpty);
    });

    test('should have deep link paths', () {
      expect(AppConfig.paymentSuccessPath, '/payment/success');
      expect(AppConfig.paymentCancelPath, '/payment/cancel');
      expect(AppConfig.bookingPath, '/booking');
      expect(AppConfig.supplierPath, '/supplier');
      expect(AppConfig.categoryPath, '/category');
    });
  });

  group('AppConfig Webhook Tests', () {
    test('should have webhook base URL', () {
      expect(AppConfig.webhookBaseUrl, contains('cloudfunctions.net'));
    });

    test('should have ProxyPay webhook URL', () {
      expect(AppConfig.proxyPayWebhookUrl, contains('proxyPayWebhook'));
    });
  });

  group('AppConfig ProxyPay Tests', () {
    test('should have sandbox configuration', () {
      expect(AppConfig.proxyPaySandboxUrl, contains('sandbox'));
    });

    test('should have production configuration', () {
      expect(AppConfig.proxyPayProdUrl, isNot(contains('sandbox')));
    });

    test('proxyPayBaseUrl should return correct URL for environment', () {
      // In development, should use sandbox
      if (AppConfig.isDevelopment) {
        expect(AppConfig.proxyPayBaseUrl, AppConfig.proxyPaySandboxUrl);
      } else {
        expect(AppConfig.proxyPayBaseUrl, AppConfig.proxyPayProdUrl);
      }
    });
  });
}
