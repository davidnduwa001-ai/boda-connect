import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling biometric authentication (fingerprint/face ID)
class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Check if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if device supports biometrics
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics || canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if biometric auth is enabled for user
  Future<bool> isBiometricEnabled(String userId) async {
    try {
      // Check local storage first (for offline access)
      final prefs = await SharedPreferences.getInstance();
      final localEnabled = prefs.getBool('${_biometricEnabledKey}_$userId');

      if (localEnabled != null) {
        return localEnabled;
      }

      // Check Firestore
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final securitySettings = doc.data()?['securitySettings'] as Map<String, dynamic>?;
        return securitySettings?['biometricEnabled'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking biometric status: $e');
      return false;
    }
  }

  /// Enable or disable biometric authentication
  Future<bool> setBiometricEnabled(String userId, bool enabled) async {
    try {
      // If enabling, verify biometrics first
      if (enabled) {
        final isAvailable = await isBiometricAvailable();
        if (!isAvailable) {
          throw Exception('Biometrics not available on this device');
        }

        // Authenticate to confirm
        final authenticated = await authenticate(
          reason: 'Autentique para ativar a autenticação biométrica',
        );
        if (!authenticated) {
          return false;
        }
      }

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_biometricEnabledKey}_$userId', enabled);

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set({
        'securitySettings': {
          'biometricEnabled': enabled,
          'biometricUpdatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Error setting biometric status: $e');
      rethrow;
    }
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({
    String reason = 'Autentique para continuar',
    bool biometricOnly = false,
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  /// Get biometric type display name
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Impressão Digital';
    } else if (types.contains(BiometricType.iris)) {
      return 'Íris';
    } else if (types.contains(BiometricType.strong)) {
      return 'Biometria';
    } else if (types.contains(BiometricType.weak)) {
      return 'Biometria';
    }
    return 'Biometria';
  }
}
