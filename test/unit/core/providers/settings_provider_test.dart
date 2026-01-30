import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/providers/settings_provider.dart';

/// SettingsProvider Tests
/// Tests for AppSettings state and notifier
void main() {
  group('AppSettings Tests', () {
    test('should create with default values', () {
      const settings = AppSettings();

      expect(settings.language, 'Português');
      expect(settings.region, 'Luanda');
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.darkModeEnabled, isFalse);
      expect(settings.soundEnabled, isTrue);
      expect(settings.vibrationEnabled, isTrue);
    });

    test('should create with custom values', () {
      const settings = AppSettings(
        language: 'English',
        region: 'Benguela',
        notificationsEnabled: false,
        darkModeEnabled: true,
        soundEnabled: false,
        vibrationEnabled: false,
      );

      expect(settings.language, 'English');
      expect(settings.region, 'Benguela');
      expect(settings.notificationsEnabled, isFalse);
      expect(settings.darkModeEnabled, isTrue);
      expect(settings.soundEnabled, isFalse);
      expect(settings.vibrationEnabled, isFalse);
    });

    test('copyWith should preserve values when not specified', () {
      const settings = AppSettings(
        language: 'English',
        region: 'Huambo',
        notificationsEnabled: false,
      );

      final updated = settings.copyWith(darkModeEnabled: true);

      expect(updated.language, 'English');
      expect(updated.region, 'Huambo');
      expect(updated.notificationsEnabled, isFalse);
      expect(updated.darkModeEnabled, isTrue);
    });

    test('copyWith should update specified values', () {
      const settings = AppSettings();

      final updated = settings.copyWith(
        language: 'English',
        region: 'Cabinda',
      );

      expect(updated.language, 'English');
      expect(updated.region, 'Cabinda');
      expect(updated.notificationsEnabled, isTrue); // Default preserved
    });
  });

  group('AppSettings Equality Tests', () {
    test('settings with same values should be equal', () {
      const settings1 = AppSettings(
        language: 'Português',
        region: 'Luanda',
      );
      const settings2 = AppSettings(
        language: 'Português',
        region: 'Luanda',
      );

      // If Equatable is used
      expect(settings1.language, settings2.language);
      expect(settings1.region, settings2.region);
    });
  });

  group('Language Settings Tests', () {
    test('should support Portuguese', () {
      const settings = AppSettings(language: 'Português');
      expect(settings.language, 'Português');
    });

    test('should support English', () {
      const settings = AppSettings(language: 'English');
      expect(settings.language, 'English');
    });
  });

  group('Region Settings Tests', () {
    test('should support Angolan regions', () {
      final regions = [
        'Luanda',
        'Benguela',
        'Huambo',
        'Lobito',
        'Cabinda',
        'Huíla',
      ];

      for (final region in regions) {
        final settings = AppSettings(region: region);
        expect(settings.region, region);
      }
    });
  });

  group('Notification Settings Tests', () {
    test('notifications enabled by default', () {
      const settings = AppSettings();
      expect(settings.notificationsEnabled, isTrue);
    });

    test('should toggle notifications', () {
      const settings = AppSettings(notificationsEnabled: true);
      final disabled = settings.copyWith(notificationsEnabled: false);

      expect(disabled.notificationsEnabled, isFalse);
    });
  });

  group('Sound and Vibration Tests', () {
    test('sound enabled by default', () {
      const settings = AppSettings();
      expect(settings.soundEnabled, isTrue);
    });

    test('vibration enabled by default', () {
      const settings = AppSettings();
      expect(settings.vibrationEnabled, isTrue);
    });

    test('should toggle sound', () {
      const settings = AppSettings(soundEnabled: true);
      final disabled = settings.copyWith(soundEnabled: false);

      expect(disabled.soundEnabled, isFalse);
    });

    test('should toggle vibration', () {
      const settings = AppSettings(vibrationEnabled: true);
      final disabled = settings.copyWith(vibrationEnabled: false);

      expect(disabled.vibrationEnabled, isFalse);
    });
  });

  group('Dark Mode Tests', () {
    test('dark mode disabled by default', () {
      const settings = AppSettings();
      expect(settings.darkModeEnabled, isFalse);
    });

    test('should toggle dark mode', () {
      const settings = AppSettings(darkModeEnabled: false);
      final enabled = settings.copyWith(darkModeEnabled: true);

      expect(enabled.darkModeEnabled, isTrue);
    });
  });
}
