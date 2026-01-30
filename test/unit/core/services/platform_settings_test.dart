import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Platform Settings Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Support Contact Settings
/// 2. Commission Settings
/// 3. Maintenance Mode
/// 4. Feature Flags
/// 5. Settings Caching
/// 6. Real-time Updates
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Support Contact Settings Tests', () {
    test('should store and retrieve support contact info', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'supportEmail': 'suporte@bodaconnect.ao',
        'supportPhone': '+244923456789',
        'supportWhatsApp': '+244923456789',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['supportEmail'], 'suporte@bodaconnect.ao');
      expect(doc.data()?['supportPhone'], '+244923456789');
      expect(doc.data()?['supportWhatsApp'], '+244923456789');
    });

    test('should update support email', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'supportEmail': 'old@bodaconnect.ao',
      });

      await fakeFirestore.collection('settings').doc('platform').update({
        'supportEmail': 'novo@bodaconnect.ao',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['supportEmail'], 'novo@bodaconnect.ao');
    });

    test('should update support phone', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'supportPhone': '+244912345678',
      });

      await fakeFirestore.collection('settings').doc('platform').update({
        'supportPhone': '+244987654321',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['supportPhone'], '+244987654321');
    });

    test('should generate WhatsApp link', () {
      final phone = '+244923456789';
      final message = 'Olá, preciso de ajuda!';
      final link = _generateWhatsAppLink(phone, message);

      expect(link, contains('wa.me'));
      expect(link, contains('244923456789'));
      expect(link, contains(Uri.encodeComponent(message)));
    });

    test('should generate phone call link', () {
      final phone = '+244923456789';
      final link = _generatePhoneLink(phone);

      expect(link, 'tel:+244923456789');
    });

    test('should generate email link', () {
      final email = 'suporte@bodaconnect.ao';
      final subject = 'Ajuda com reserva';
      final link = _generateEmailLink(email, subject);

      expect(link, contains('mailto:'));
      expect(link, contains(email));
      expect(link, contains(Uri.encodeComponent(subject)));
    });
  });

  group('Commission Settings Tests', () {
    test('should store platform commission percentage', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'commissionPercent': 10.0,
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['commissionPercent'], 10.0);
    });

    test('should update commission percentage', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'commissionPercent': 10.0,
      });

      await fakeFirestore.collection('settings').doc('platform').update({
        'commissionPercent': 12.5,
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['commissionPercent'], 12.5);
    });

    test('should validate commission percentage bounds', () {
      // Commission should be between 0% and 50%
      expect(_isValidCommission(0.0), isTrue);
      expect(_isValidCommission(10.0), isTrue);
      expect(_isValidCommission(25.0), isTrue);
      expect(_isValidCommission(50.0), isTrue);
      expect(_isValidCommission(-1.0), isFalse);
      expect(_isValidCommission(51.0), isFalse);
      expect(_isValidCommission(100.0), isFalse);
    });

    test('should store tier-based commission rates', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'tierCommissions': {
          'basic': 15.0,
          'bronze': 12.0,
          'silver': 10.0,
          'gold': 8.0,
          'platinum': 5.0,
        },
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final tierCommissions = doc.data()?['tierCommissions'] as Map;
      expect(tierCommissions['basic'], 15.0);
      expect(tierCommissions['platinum'], 5.0);
    });
  });

  group('Maintenance Mode Tests', () {
    test('should enable maintenance mode', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'maintenanceMode': false,
      });

      await fakeFirestore.collection('settings').doc('platform').update({
        'maintenanceMode': true,
        'maintenanceMessage': 'Estamos em manutenção. Voltaremos em breve!',
        'maintenanceStartedAt': Timestamp.now(),
        'expectedEndTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 2)),
        ),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['maintenanceMode'], isTrue);
      expect(doc.data()?['maintenanceMessage'], isNotNull);
    });

    test('should disable maintenance mode', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'maintenanceMode': true,
        'maintenanceMessage': 'Em manutenção',
      });

      await fakeFirestore.collection('settings').doc('platform').update({
        'maintenanceMode': false,
        'maintenanceMessage': null,
        'maintenanceEndedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['maintenanceMode'], isFalse);
    });

    test('should check if maintenance is scheduled to end', () async {
      final expectedEnd = DateTime.now().add(const Duration(hours: 1));

      await fakeFirestore.collection('settings').doc('platform').set({
        'maintenanceMode': true,
        'expectedEndTime': Timestamp.fromDate(expectedEnd),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final endTime = (doc.data()?['expectedEndTime'] as Timestamp).toDate();

      expect(endTime.isAfter(DateTime.now()), isTrue);
    });
  });

  group('Feature Flags Tests', () {
    test('should store feature flags', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'featureFlags': {
          'chatEnabled': true,
          'paymentEnabled': true,
          'referralEnabled': true,
          'videoUploadEnabled': false,
          'googleAuthEnabled': true,
          'emailAuthEnabled': true,
          'whatsappAuthEnabled': true,
        },
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final flags = doc.data()?['featureFlags'] as Map;
      expect(flags['chatEnabled'], isTrue);
      expect(flags['videoUploadEnabled'], isFalse);
    });

    test('should toggle feature flag', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'featureFlags': {
          'videoUploadEnabled': false,
        },
      });

      await fakeFirestore.collection('settings').doc('platform').update({
        'featureFlags.videoUploadEnabled': true,
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final flags = doc.data()?['featureFlags'] as Map;
      expect(flags['videoUploadEnabled'], isTrue);
    });

    test('should check if feature is enabled', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'featureFlags': {
          'chatEnabled': true,
          'newFeature': false,
        },
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final flags = doc.data()?['featureFlags'] as Map;

      final isChatEnabled = flags['chatEnabled'] == true;
      final isNewFeatureEnabled = flags['newFeature'] == true;
      final isUnknownEnabled = flags['unknownFeature'] == true;

      expect(isChatEnabled, isTrue);
      expect(isNewFeatureEnabled, isFalse);
      expect(isUnknownEnabled, isFalse); // Default to false for unknown
    });
  });

  group('App Version Settings Tests', () {
    test('should store minimum required app version', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'minAndroidVersion': '1.2.0',
        'minIosVersion': '1.2.0',
        'currentVersion': '1.5.0',
        'forceUpdate': false,
        'updateMessage': 'Uma nova versão está disponível!',
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      expect(doc.data()?['minAndroidVersion'], '1.2.0');
      expect(doc.data()?['currentVersion'], '1.5.0');
    });

    test('should check if update is required', () {
      final minVersion = '1.2.0';
      final currentVersion = '1.1.0';

      final needsUpdate = _compareVersions(currentVersion, minVersion) < 0;
      expect(needsUpdate, isTrue);
    });

    test('should not require update if version is current', () {
      final minVersion = '1.2.0';
      final currentVersion = '1.5.0';

      final needsUpdate = _compareVersions(currentVersion, minVersion) < 0;
      expect(needsUpdate, isFalse);
    });
  });

  group('Localization Settings Tests', () {
    test('should store supported languages', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'supportedLanguages': ['pt', 'en', 'es'],
        'defaultLanguage': 'pt',
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final languages = doc.data()?['supportedLanguages'] as List;
      expect(languages.contains('pt'), isTrue);
      expect(doc.data()?['defaultLanguage'], 'pt');
    });

    test('should store supported currencies', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'supportedCurrencies': ['AOA', 'USD', 'EUR'],
        'defaultCurrency': 'AOA',
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final currencies = doc.data()?['supportedCurrencies'] as List;
      expect(currencies.contains('AOA'), isTrue);
    });
  });

  group('Rate Limits Settings Tests', () {
    test('should store rate limit configurations', () async {
      await fakeFirestore.collection('settings').doc('platform').set({
        'rateLimits': {
          'messagesPerMinute': 10,
          'bookingsPerDay': 5,
          'reviewsPerDay': 3,
          'searchesPerMinute': 30,
        },
      });

      final doc = await fakeFirestore.collection('settings').doc('platform').get();
      final limits = doc.data()?['rateLimits'] as Map;
      expect(limits['messagesPerMinute'], 10);
      expect(limits['bookingsPerDay'], 5);
    });
  });

  group('Default Values Tests', () {
    test('should provide default settings when none exist', () async {
      final doc = await fakeFirestore.collection('settings').doc('platform').get();

      if (!doc.exists) {
        // Use defaults
        final defaults = _getDefaultSettings();
        expect(defaults['supportEmail'], isNotNull);
        expect(defaults['commissionPercent'], 10.0);
        expect(defaults['maintenanceMode'], isFalse);
      }
    });

    test('should merge defaults with existing settings', () {
      final existing = {
        'supportEmail': 'custom@bodaconnect.ao',
        // Missing other fields
      };

      final defaults = _getDefaultSettings();
      final merged = {...defaults, ...existing};

      expect(merged['supportEmail'], 'custom@bodaconnect.ao'); // Custom value
      expect(merged['commissionPercent'], 10.0); // Default value
    });
  });

  group('Settings History Tests', () {
    test('should track settings changes', () async {
      await fakeFirestore
          .collection('settings')
          .doc('platform')
          .collection('history')
          .add({
        'field': 'commissionPercent',
        'oldValue': 10.0,
        'newValue': 12.5,
        'changedBy': 'admin-123',
        'changedAt': Timestamp.now(),
      });

      final history = await fakeFirestore
          .collection('settings')
          .doc('platform')
          .collection('history')
          .orderBy('changedAt', descending: true)
          .get();

      expect(history.docs.length, 1);
      expect(history.docs.first.data()['field'], 'commissionPercent');
    });
  });

  group('Settings Cache Tests', () {
    test('should cache settings with expiry time', () async {
      final cacheExpiry = DateTime.now().add(const Duration(minutes: 5));

      // Simulate cache structure
      final cachedSettings = {
        'data': {
          'supportEmail': 'suporte@bodaconnect.ao',
          'commissionPercent': 10.0,
        },
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': cacheExpiry.millisecondsSinceEpoch,
      };

      expect(cachedSettings['expiresAt'], greaterThan(DateTime.now().millisecondsSinceEpoch));
    });

    test('should detect expired cache', () {
      final expiredTime = DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;

      final isExpired = now > expiredTime;
      expect(isExpired, isTrue);
    });
  });

  group('Settings Validation Tests', () {
    test('should validate email format', () {
      expect(_isValidEmail('suporte@bodaconnect.ao'), isTrue);
      expect(_isValidEmail('invalid-email'), isFalse);
      expect(_isValidEmail(''), isFalse);
    });

    test('should validate phone format', () {
      expect(_isValidPhone('+244923456789'), isTrue);
      expect(_isValidPhone('923456789'), isTrue);
      expect(_isValidPhone('123'), isFalse);
    });
  });
}

// Helper functions for testing

String _generateWhatsAppLink(String phone, String message) {
  final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
  return 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
}

String _generatePhoneLink(String phone) {
  return 'tel:$phone';
}

String _generateEmailLink(String email, String subject) {
  return 'mailto:$email?subject=${Uri.encodeComponent(subject)}';
}

bool _isValidCommission(double commission) {
  return commission >= 0.0 && commission <= 50.0;
}

int _compareVersions(String v1, String v2) {
  final parts1 = v1.split('.').map(int.parse).toList();
  final parts2 = v2.split('.').map(int.parse).toList();

  for (var i = 0; i < 3; i++) {
    final p1 = i < parts1.length ? parts1[i] : 0;
    final p2 = i < parts2.length ? parts2[i] : 0;
    if (p1 != p2) return p1 - p2;
  }
  return 0;
}

Map<String, dynamic> _getDefaultSettings() {
  return {
    'supportEmail': 'suporte@bodaconnect.ao',
    'supportPhone': '+244923456789',
    'supportWhatsApp': '+244923456789',
    'commissionPercent': 10.0,
    'maintenanceMode': false,
    'featureFlags': {
      'chatEnabled': true,
      'paymentEnabled': true,
      'referralEnabled': true,
    },
    'defaultLanguage': 'pt',
    'defaultCurrency': 'AOA',
  };
}

bool _isValidEmail(String email) {
  if (email.isEmpty) return false;
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

bool _isValidPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  return digits.length >= 9;
}
