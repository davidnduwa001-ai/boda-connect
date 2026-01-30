import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/platform_settings_service.dart';

/// Provider for platform settings service
final platformSettingsServiceProvider = Provider<PlatformSettingsService>((ref) {
  return PlatformSettingsService();
});

/// Provider for current platform settings (async)
final platformSettingsProvider = FutureProvider<PlatformSettings>((ref) async {
  final service = ref.watch(platformSettingsServiceProvider);
  return await service.getSettings();
});

/// Stream provider for real-time platform settings
final platformSettingsStreamProvider = StreamProvider<PlatformSettings>((ref) {
  final service = ref.watch(platformSettingsServiceProvider);
  return service.streamSettings();
});

/// Provider for support contact info only
final supportContactProvider = FutureProvider<SupportContact>((ref) async {
  final settings = await ref.watch(platformSettingsProvider.future);
  return SupportContact(
    email: settings.supportEmail,
    phone: settings.supportPhone,
    whatsApp: settings.supportWhatsApp,
    whatsAppLink: settings.whatsAppLink,
    phoneLink: settings.phoneLink,
    emailLink: settings.emailLink,
  );
});

/// Simple support contact model
class SupportContact {
  final String email;
  final String phone;
  final String whatsApp;
  final String whatsAppLink;
  final String phoneLink;
  final String emailLink;

  const SupportContact({
    required this.email,
    required this.phone,
    required this.whatsApp,
    required this.whatsAppLink,
    required this.phoneLink,
    required this.emailLink,
  });
}
