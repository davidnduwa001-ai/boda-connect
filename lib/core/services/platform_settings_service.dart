import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Platform Settings Service
///
/// Manages dynamic platform settings that can be updated by admins
/// without requiring an app update.
class PlatformSettingsService {
  static final PlatformSettingsService _instance = PlatformSettingsService._();
  factory PlatformSettingsService() => _instance;
  PlatformSettingsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached settings
  PlatformSettings? _cachedSettings;
  DateTime? _lastFetch;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get current platform settings (with caching)
  Future<PlatformSettings> getSettings() async {
    // Return cached if still valid
    if (_cachedSettings != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheExpiry) {
      return _cachedSettings!;
    }

    try {
      final doc = await _firestore
          .collection('platform_settings')
          .doc('config')
          .get();

      if (doc.exists) {
        _cachedSettings = PlatformSettings.fromFirestore(doc.data()!);
      } else {
        // Use defaults if document doesn't exist (don't try to create - requires admin)
        _cachedSettings = PlatformSettings.defaults();
      }
      _lastFetch = DateTime.now();
      return _cachedSettings!;
    } catch (e) {
      // Permission denied is expected for non-admin users, use defaults silently
      if (e.toString().contains('permission-denied')) {
        _cachedSettings = PlatformSettings.defaults();
        _lastFetch = DateTime.now();
        return _cachedSettings!;
      }
      debugPrint('❌ Error fetching platform settings: $e');
      return _cachedSettings ?? PlatformSettings.defaults();
    }
  }

  /// Stream platform settings for real-time updates
  Stream<PlatformSettings> streamSettings() {
    return _firestore
        .collection('platform_settings')
        .doc('config')
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final settings = PlatformSettings.fromFirestore(doc.data()!);
        _cachedSettings = settings;
        _lastFetch = DateTime.now();
        return settings;
      }
      return PlatformSettings.defaults();
    });
  }

  /// Update support contact info (admin only)
  Future<bool> updateSupportContact({
    String? email,
    String? phone,
    String? whatsApp,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (email != null) updates['supportEmail'] = email;
      if (phone != null) updates['supportPhone'] = phone;
      if (whatsApp != null) updates['supportWhatsApp'] = whatsApp;

      await _firestore
          .collection('platform_settings')
          .doc('config')
          .set(updates, SetOptions(merge: true));

      // Invalidate cache
      _cachedSettings = null;
      _lastFetch = null;

      debugPrint('✅ Support contact updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating support contact: $e');
      return false;
    }
  }

  /// Update platform commission (admin only)
  Future<bool> updateCommission(double commissionPercent) async {
    if (commissionPercent < 0 || commissionPercent > 50) {
      debugPrint('❌ Invalid commission: must be between 0% and 50%');
      return false;
    }

    try {
      await _firestore
          .collection('platform_settings')
          .doc('config')
          .set({
        'platformCommission': commissionPercent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also sync to payment service settings
      await _firestore
          .collection('settings')
          .doc('platform')
          .set({
        'platformFeePercent': commissionPercent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Invalidate cache
      _cachedSettings = null;
      _lastFetch = null;

      debugPrint('✅ Platform commission updated to $commissionPercent%');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating commission: $e');
      return false;
    }
  }

  /// Update maintenance mode (admin only)
  Future<bool> updateMaintenanceMode(bool enabled) async {
    try {
      await _firestore
          .collection('platform_settings')
          .doc('config')
          .set({
        'maintenanceMode': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _cachedSettings = null;
      _lastFetch = null;

      debugPrint('✅ Maintenance mode: ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating maintenance mode: $e');
      return false;
    }
  }

  /// Update registration settings (admin only)
  Future<bool> updateRegistrationSettings({
    bool? allowNewRegistrations,
    bool? allowClientRegistrations,
    bool? allowSupplierRegistrations,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (allowNewRegistrations != null) {
        updates['allowNewRegistrations'] = allowNewRegistrations;
      }
      if (allowClientRegistrations != null) {
        updates['allowClientRegistrations'] = allowClientRegistrations;
      }
      if (allowSupplierRegistrations != null) {
        updates['allowSupplierRegistrations'] = allowSupplierRegistrations;
      }

      await _firestore
          .collection('platform_settings')
          .doc('config')
          .set(updates, SetOptions(merge: true));

      _cachedSettings = null;
      _lastFetch = null;

      debugPrint('✅ Registration settings updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating registration settings: $e');
      return false;
    }
  }

  /// Clear cache (useful after admin updates)
  void clearCache() {
    _cachedSettings = null;
    _lastFetch = null;
  }
}

/// Platform settings model
class PlatformSettings {
  final String supportEmail;
  final String supportPhone;
  final String supportWhatsApp;
  final double platformCommission;
  final bool maintenanceMode;
  final bool allowNewRegistrations;
  final bool allowClientRegistrations;
  final bool allowSupplierRegistrations;
  final int minimumBookingAmount;
  final int escrowAutoReleaseHours;
  final String privacyPolicyUrl;
  final String termsOfServiceUrl;
  final DateTime? updatedAt;

  const PlatformSettings({
    required this.supportEmail,
    required this.supportPhone,
    required this.supportWhatsApp,
    required this.platformCommission,
    required this.maintenanceMode,
    required this.allowNewRegistrations,
    required this.allowClientRegistrations,
    required this.allowSupplierRegistrations,
    required this.minimumBookingAmount,
    required this.escrowAutoReleaseHours,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    this.updatedAt,
  });

  /// Default settings
  factory PlatformSettings.defaults() {
    return const PlatformSettings(
      supportEmail: 'support@bodaconnect.ao',
      supportPhone: '+244 923 456 789',
      supportWhatsApp: '+244923456789',
      platformCommission: 10.0,
      maintenanceMode: false,
      allowNewRegistrations: true,
      allowClientRegistrations: true,
      allowSupplierRegistrations: true,
      minimumBookingAmount: 5000,
      escrowAutoReleaseHours: 48,
      privacyPolicyUrl: 'https://bodaconnect.ao/privacy',
      termsOfServiceUrl: 'https://bodaconnect.ao/terms',
    );
  }

  /// Create from Firestore document
  factory PlatformSettings.fromFirestore(Map<String, dynamic> data) {
    return PlatformSettings(
      supportEmail: data['supportEmail'] as String? ?? 'support@bodaconnect.ao',
      supportPhone: data['supportPhone'] as String? ?? '+244 923 456 789',
      supportWhatsApp: data['supportWhatsApp'] as String? ?? '+244923456789',
      platformCommission: (data['platformCommission'] as num?)?.toDouble() ?? 10.0,
      maintenanceMode: data['maintenanceMode'] as bool? ?? false,
      allowNewRegistrations: data['allowNewRegistrations'] as bool? ?? true,
      allowClientRegistrations: data['allowClientRegistrations'] as bool? ?? true,
      allowSupplierRegistrations: data['allowSupplierRegistrations'] as bool? ?? true,
      minimumBookingAmount: data['minimumBookingAmount'] as int? ?? 5000,
      escrowAutoReleaseHours: data['escrowAutoReleaseHours'] as int? ?? 48,
      privacyPolicyUrl: data['privacyPolicyUrl'] as String? ?? 'https://bodaconnect.ao/privacy',
      termsOfServiceUrl: data['termsOfServiceUrl'] as String? ?? 'https://bodaconnect.ao/terms',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'supportEmail': supportEmail,
      'supportPhone': supportPhone,
      'supportWhatsApp': supportWhatsApp,
      'platformCommission': platformCommission,
      'maintenanceMode': maintenanceMode,
      'allowNewRegistrations': allowNewRegistrations,
      'allowClientRegistrations': allowClientRegistrations,
      'allowSupplierRegistrations': allowSupplierRegistrations,
      'minimumBookingAmount': minimumBookingAmount,
      'escrowAutoReleaseHours': escrowAutoReleaseHours,
      'privacyPolicyUrl': privacyPolicyUrl,
      'termsOfServiceUrl': termsOfServiceUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Copy with new values
  PlatformSettings copyWith({
    String? supportEmail,
    String? supportPhone,
    String? supportWhatsApp,
    double? platformCommission,
    bool? maintenanceMode,
    bool? allowNewRegistrations,
    bool? allowClientRegistrations,
    bool? allowSupplierRegistrations,
    int? minimumBookingAmount,
    int? escrowAutoReleaseHours,
    String? privacyPolicyUrl,
    String? termsOfServiceUrl,
  }) {
    return PlatformSettings(
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      supportWhatsApp: supportWhatsApp ?? this.supportWhatsApp,
      platformCommission: platformCommission ?? this.platformCommission,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      allowNewRegistrations: allowNewRegistrations ?? this.allowNewRegistrations,
      allowClientRegistrations: allowClientRegistrations ?? this.allowClientRegistrations,
      allowSupplierRegistrations: allowSupplierRegistrations ?? this.allowSupplierRegistrations,
      minimumBookingAmount: minimumBookingAmount ?? this.minimumBookingAmount,
      escrowAutoReleaseHours: escrowAutoReleaseHours ?? this.escrowAutoReleaseHours,
      privacyPolicyUrl: privacyPolicyUrl ?? this.privacyPolicyUrl,
      termsOfServiceUrl: termsOfServiceUrl ?? this.termsOfServiceUrl,
      updatedAt: updatedAt,
    );
  }

  /// Get formatted WhatsApp link
  String get whatsAppLink => 'https://wa.me/${supportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '')}';

  /// Get formatted phone link
  String get phoneLink => 'tel:$supportPhone';

  /// Get formatted email link
  String get emailLink => 'mailto:$supportEmail';
}
