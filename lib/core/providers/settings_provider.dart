import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Font size options
enum FontSizeOption {
  small('Pequeno', 0.85),
  medium('Médio', 1.0),
  large('Grande', 1.15),
  extraLarge('Muito Grande', 1.3);

  const FontSizeOption(this.label, this.scale);
  final String label;
  final double scale;

  static FontSizeOption fromLabel(String label) {
    return FontSizeOption.values.firstWhere(
      (e) => e.label == label,
      orElse: () => FontSizeOption.medium,
    );
  }
}

/// Theme mode options
enum ThemeModeOption {
  light('Claro', ThemeMode.light),
  dark('Escuro', ThemeMode.dark),
  system('Automático', ThemeMode.system);

  const ThemeModeOption(this.label, this.mode);
  final String label;
  final ThemeMode mode;

  static ThemeModeOption fromLabel(String label) {
    return ThemeModeOption.values.firstWhere(
      (e) => e.label == label,
      orElse: () => ThemeModeOption.light,
    );
  }
}

/// App settings state
class AppSettingsState {
  final FontSizeOption fontSize;
  final ThemeModeOption themeMode;
  final String language;
  final String region;
  final bool notificationsEnabled;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool marketingEmails;
  final bool autoPlayVideos;
  final bool dataSaver;

  const AppSettingsState({
    this.fontSize = FontSizeOption.medium,
    this.themeMode = ThemeModeOption.light,
    this.language = 'Português',
    this.region = 'Luanda',
    this.notificationsEnabled = true,
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.marketingEmails = false,
    this.autoPlayVideos = true,
    this.dataSaver = false,
  });

  AppSettingsState copyWith({
    FontSizeOption? fontSize,
    ThemeModeOption? themeMode,
    String? language,
    String? region,
    bool? notificationsEnabled,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? marketingEmails,
    bool? autoPlayVideos,
    bool? dataSaver,
  }) {
    return AppSettingsState(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      region: region ?? this.region,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      autoPlayVideos: autoPlayVideos ?? this.autoPlayVideos,
      dataSaver: dataSaver ?? this.dataSaver,
    );
  }
}

/// App settings notifier
class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(const AppSettingsState()) {
    _loadSettings();
  }

  // PERFORMANCE: Debounce timer for Firestore sync
  // Batches multiple rapid setting changes into single write (2 second delay)
  Timer? _syncDebounceTimer;
  static const _syncDebounceDelay = Duration(seconds: 2);

  static const _keyFontSize = 'font_size';
  static const _keyThemeMode = 'theme_mode';
  static const _keyLanguage = 'language';
  static const _keyRegion = 'region';
  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyPushNotifications = 'push_notifications';
  static const _keyEmailNotifications = 'email_notifications';
  static const _keySmsNotifications = 'sms_notifications';
  static const _keyMarketingEmails = 'marketing_emails';
  static const _keyAutoPlayVideos = 'auto_play_videos';
  static const _keyDataSaver = 'data_saver';

  @override
  void dispose() {
    _syncDebounceTimer?.cancel();
    super.dispose();
  }

  /// PERFORMANCE: Debounced Firestore sync - batches rapid changes
  void _scheduleSyncToFirestore() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounceDelay, () {
      _syncToFirestore();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // First load from local storage for immediate UI
      state = AppSettingsState(
        fontSize: FontSizeOption.fromLabel(
          prefs.getString(_keyFontSize) ?? 'Médio',
        ),
        themeMode: ThemeModeOption.fromLabel(
          prefs.getString(_keyThemeMode) ?? 'Claro',
        ),
        language: prefs.getString(_keyLanguage) ?? 'Português',
        region: prefs.getString(_keyRegion) ?? 'Luanda',
        notificationsEnabled: prefs.getBool(_keyNotificationsEnabled) ?? true,
        pushNotifications: prefs.getBool(_keyPushNotifications) ?? true,
        emailNotifications: prefs.getBool(_keyEmailNotifications) ?? true,
        smsNotifications: prefs.getBool(_keySmsNotifications) ?? false,
        marketingEmails: prefs.getBool(_keyMarketingEmails) ?? false,
        autoPlayVideos: prefs.getBool(_keyAutoPlayVideos) ?? true,
        dataSaver: prefs.getBool(_keyDataSaver) ?? false,
      );

      // Then sync from Firestore if user is logged in
      await _syncFromFirestore();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Sync settings from Firestore (cloud -> local)
  Future<void> _syncFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final settingsData = doc.data()?['appSettings'] as Map<String, dynamic>?;
      if (settingsData == null) return;

      // Update state with cloud settings
      state = AppSettingsState(
        fontSize: FontSizeOption.fromLabel(
          settingsData['fontSize'] as String? ?? state.fontSize.label,
        ),
        themeMode: ThemeModeOption.fromLabel(
          settingsData['themeMode'] as String? ?? state.themeMode.label,
        ),
        language: settingsData['language'] as String? ?? state.language,
        region: settingsData['region'] as String? ?? state.region,
        notificationsEnabled: settingsData['notificationsEnabled'] as bool? ?? state.notificationsEnabled,
        pushNotifications: settingsData['pushNotifications'] as bool? ?? state.pushNotifications,
        emailNotifications: settingsData['emailNotifications'] as bool? ?? state.emailNotifications,
        smsNotifications: settingsData['smsNotifications'] as bool? ?? state.smsNotifications,
        marketingEmails: settingsData['marketingEmails'] as bool? ?? state.marketingEmails,
        autoPlayVideos: settingsData['autoPlayVideos'] as bool? ?? state.autoPlayVideos,
        dataSaver: settingsData['dataSaver'] as bool? ?? state.dataSaver,
      );

      // Update local storage with cloud values
      await _saveAllToLocal();
    } catch (e) {
      debugPrint('Error syncing settings from Firestore: $e');
    }
  }

  /// Save all settings to local storage
  Future<void> _saveAllToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontSize, state.fontSize.label);
    await prefs.setString(_keyThemeMode, state.themeMode.label);
    await prefs.setString(_keyLanguage, state.language);
    await prefs.setString(_keyRegion, state.region);
    await prefs.setBool(_keyNotificationsEnabled, state.notificationsEnabled);
    await prefs.setBool(_keyPushNotifications, state.pushNotifications);
    await prefs.setBool(_keyEmailNotifications, state.emailNotifications);
    await prefs.setBool(_keySmsNotifications, state.smsNotifications);
    await prefs.setBool(_keyMarketingEmails, state.marketingEmails);
    await prefs.setBool(_keyAutoPlayVideos, state.autoPlayVideos);
    await prefs.setBool(_keyDataSaver, state.dataSaver);
  }

  /// Sync settings to Firestore (local -> cloud)
  Future<void> _syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'appSettings': {
          'fontSize': state.fontSize.label,
          'themeMode': state.themeMode.label,
          'language': state.language,
          'region': state.region,
          'notificationsEnabled': state.notificationsEnabled,
          'pushNotifications': state.pushNotifications,
          'emailNotifications': state.emailNotifications,
          'smsNotifications': state.smsNotifications,
          'marketingEmails': state.marketingEmails,
          'autoPlayVideos': state.autoPlayVideos,
          'dataSaver': state.dataSaver,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing settings to Firestore: $e');
    }
  }

  Future<void> setFontSize(FontSizeOption fontSize) async {
    state = state.copyWith(fontSize: fontSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontSize, fontSize.label);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setThemeMode(ThemeModeOption themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, themeMode.label);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setRegion(String region) async {
    state = state.copyWith(region: region);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegion, region);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(
      notificationsEnabled: enabled,
      pushNotifications: enabled ? state.pushNotifications : false,
      emailNotifications: enabled ? state.emailNotifications : false,
      smsNotifications: enabled ? state.smsNotifications : false,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
    if (!enabled) {
      await prefs.setBool(_keyPushNotifications, false);
      await prefs.setBool(_keyEmailNotifications, false);
      await prefs.setBool(_keySmsNotifications, false);
    }
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setPushNotifications(bool enabled) async {
    state = state.copyWith(pushNotifications: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushNotifications, enabled);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setEmailNotifications(bool enabled) async {
    state = state.copyWith(emailNotifications: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailNotifications, enabled);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setSmsNotifications(bool enabled) async {
    state = state.copyWith(smsNotifications: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySmsNotifications, enabled);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setMarketingEmails(bool enabled) async {
    state = state.copyWith(marketingEmails: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMarketingEmails, enabled);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setAutoPlayVideos(bool enabled) async {
    state = state.copyWith(autoPlayVideos: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPlayVideos, enabled);
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }

  Future<void> setDataSaver(bool enabled) async {
    state = state.copyWith(
      dataSaver: enabled,
      autoPlayVideos: enabled ? false : state.autoPlayVideos,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDataSaver, enabled);
    if (enabled) {
      await prefs.setBool(_keyAutoPlayVideos, false);
    }
    _scheduleSyncToFirestore(); // PERFORMANCE: Debounced
  }
}

/// Main settings provider
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});

/// Font scale provider - convenient accessor
final fontScaleProvider = Provider<double>((ref) {
  return ref.watch(appSettingsProvider).fontSize.scale;
});

/// Theme mode provider - convenient accessor
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(appSettingsProvider).themeMode.mode;
});
