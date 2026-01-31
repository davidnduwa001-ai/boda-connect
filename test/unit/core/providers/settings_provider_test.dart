import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/providers/settings_provider.dart';

/// SettingsProvider Tests
/// Tests for AppSettingsState and enums
void main() {
  group('FontSizeOption Tests', () {
    test('should have correct labels and scales', () {
      expect(FontSizeOption.small.label, 'Pequeno');
      expect(FontSizeOption.small.scale, 0.85);

      expect(FontSizeOption.medium.label, 'Médio');
      expect(FontSizeOption.medium.scale, 1.0);

      expect(FontSizeOption.large.label, 'Grande');
      expect(FontSizeOption.large.scale, 1.15);

      expect(FontSizeOption.extraLarge.label, 'Muito Grande');
      expect(FontSizeOption.extraLarge.scale, 1.3);
    });

    test('fromLabel should return correct option', () {
      expect(FontSizeOption.fromLabel('Pequeno'), FontSizeOption.small);
      expect(FontSizeOption.fromLabel('Médio'), FontSizeOption.medium);
      expect(FontSizeOption.fromLabel('Grande'), FontSizeOption.large);
      expect(FontSizeOption.fromLabel('Muito Grande'), FontSizeOption.extraLarge);
    });

    test('fromLabel should return medium for unknown label', () {
      expect(FontSizeOption.fromLabel('Unknown'), FontSizeOption.medium);
      expect(FontSizeOption.fromLabel(''), FontSizeOption.medium);
    });
  });

  group('ThemeModeOption Tests', () {
    test('should have correct labels and modes', () {
      expect(ThemeModeOption.light.label, 'Claro');
      expect(ThemeModeOption.light.mode, ThemeMode.light);

      expect(ThemeModeOption.dark.label, 'Escuro');
      expect(ThemeModeOption.dark.mode, ThemeMode.dark);

      expect(ThemeModeOption.system.label, 'Automático');
      expect(ThemeModeOption.system.mode, ThemeMode.system);
    });

    test('fromLabel should return correct option', () {
      expect(ThemeModeOption.fromLabel('Claro'), ThemeModeOption.light);
      expect(ThemeModeOption.fromLabel('Escuro'), ThemeModeOption.dark);
      expect(ThemeModeOption.fromLabel('Automático'), ThemeModeOption.system);
    });

    test('fromLabel should return light for unknown label', () {
      expect(ThemeModeOption.fromLabel('Unknown'), ThemeModeOption.light);
    });
  });

  group('AppSettingsState Tests', () {
    test('should create with default values', () {
      const settings = AppSettingsState();

      expect(settings.fontSize, FontSizeOption.medium);
      expect(settings.themeMode, ThemeModeOption.light);
      expect(settings.language, 'Português');
      expect(settings.region, 'Luanda');
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.pushNotifications, isTrue);
      expect(settings.emailNotifications, isTrue);
      expect(settings.smsNotifications, isFalse);
      expect(settings.marketingEmails, isFalse);
      expect(settings.autoPlayVideos, isTrue);
      expect(settings.dataSaver, isFalse);
    });

    test('should create with custom values', () {
      const settings = AppSettingsState(
        fontSize: FontSizeOption.large,
        themeMode: ThemeModeOption.dark,
        language: 'English',
        region: 'Benguela',
        notificationsEnabled: false,
        pushNotifications: false,
        dataSaver: true,
      );

      expect(settings.fontSize, FontSizeOption.large);
      expect(settings.themeMode, ThemeModeOption.dark);
      expect(settings.language, 'English');
      expect(settings.region, 'Benguela');
      expect(settings.notificationsEnabled, isFalse);
      expect(settings.pushNotifications, isFalse);
      expect(settings.dataSaver, isTrue);
    });

    test('copyWith should preserve values when not specified', () {
      const settings = AppSettingsState(
        language: 'English',
        region: 'Huambo',
        notificationsEnabled: false,
      );

      final updated = settings.copyWith(dataSaver: true);

      expect(updated.language, 'English');
      expect(updated.region, 'Huambo');
      expect(updated.notificationsEnabled, isFalse);
      expect(updated.dataSaver, isTrue);
    });

    test('copyWith should update specified values', () {
      const settings = AppSettingsState();

      final updated = settings.copyWith(
        language: 'English',
        region: 'Cabinda',
        fontSize: FontSizeOption.large,
      );

      expect(updated.language, 'English');
      expect(updated.region, 'Cabinda');
      expect(updated.fontSize, FontSizeOption.large);
      expect(updated.notificationsEnabled, isTrue); // Default preserved
    });
  });

  group('Language Settings Tests', () {
    test('should support Portuguese', () {
      const settings = AppSettingsState(language: 'Português');
      expect(settings.language, 'Português');
    });

    test('should support English', () {
      const settings = AppSettingsState(language: 'English');
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
        final settings = AppSettingsState(region: region);
        expect(settings.region, region);
      }
    });
  });

  group('Notification Settings Tests', () {
    test('notifications enabled by default', () {
      const settings = AppSettingsState();
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.pushNotifications, isTrue);
      expect(settings.emailNotifications, isTrue);
    });

    test('should toggle notifications', () {
      const settings = AppSettingsState(notificationsEnabled: true);
      final disabled = settings.copyWith(notificationsEnabled: false);

      expect(disabled.notificationsEnabled, isFalse);
    });
  });

  group('Data Saver Tests', () {
    test('data saver disabled by default', () {
      const settings = AppSettingsState();
      expect(settings.dataSaver, isFalse);
    });

    test('should toggle data saver', () {
      const settings = AppSettingsState(dataSaver: false);
      final enabled = settings.copyWith(dataSaver: true);

      expect(enabled.dataSaver, isTrue);
    });
  });
}
