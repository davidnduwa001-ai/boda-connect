import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:base32/base32.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for handling TOTP-based Two-Factor Authentication
/// Compatible with Google Authenticator, Authy, Microsoft Authenticator, etc.
class TotpService {
  static final TotpService _instance = TotpService._internal();
  factory TotpService() => _instance;
  TotpService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _totpSecretKey = 'totp_secret';
  static const String _appName = 'BODA CONNECT';
  static const int _digits = 6;
  static const int _period = 30; // 30 seconds

  /// Generate a new TOTP secret
  String generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(20, (_) => random.nextInt(256));
    return base32.encode(Uint8List.fromList(bytes));
  }

  /// Generate TOTP code from secret
  String generateCode(String secret, {DateTime? timestamp}) {
    final time = timestamp ?? DateTime.now();
    final counter = time.millisecondsSinceEpoch ~/ 1000 ~/ _period;
    return _generateHOTP(secret, counter);
  }

  /// Verify a TOTP code (allows for time drift of 1 period)
  bool verifyCode(String secret, String code, {int allowedDrift = 1}) {
    final now = DateTime.now();

    // Check current and adjacent time periods for clock drift
    for (int i = -allowedDrift; i <= allowedDrift; i++) {
      final time = now.add(Duration(seconds: i * _period));
      final expectedCode = generateCode(secret, timestamp: time);
      if (code == expectedCode) {
        return true;
      }
    }
    return false;
  }

  /// Generate HOTP (HMAC-based One-Time Password)
  String _generateHOTP(String secret, int counter) {
    // Decode the base32 secret
    final key = base32.decode(secret);

    // Convert counter to 8 bytes (big-endian)
    final counterBytes = Uint8List(8);
    var tempCounter = counter;
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = tempCounter & 0xff;
      tempCounter >>= 8;
    }

    // Calculate HMAC-SHA1
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(counterBytes);
    final hash = digest.bytes;

    // Dynamic truncation
    final offset = hash[hash.length - 1] & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);

    // Generate OTP
    final otp = binary % pow(10, _digits).toInt();
    return otp.toString().padLeft(_digits, '0');
  }

  /// Generate otpauth:// URI for QR code scanning
  String generateOtpAuthUri(String secret, String userEmail) {
    final encodedEmail = Uri.encodeComponent(userEmail);
    final encodedApp = Uri.encodeComponent(_appName);
    return 'otpauth://totp/$encodedApp:$encodedEmail?secret=$secret&issuer=$encodedApp&digits=$_digits&period=$_period';
  }

  /// Check if 2FA is enabled for user
  Future<bool> is2FAEnabled(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final securitySettings = doc.data()?['securitySettings'] as Map<String, dynamic>?;
        return securitySettings?['twoFactorEnabled'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking 2FA status: $e');
      return false;
    }
  }

  /// Setup 2FA for user - generates secret and returns setup data
  Future<Map<String, String>> setup2FA(String userId, String userEmail) async {
    try {
      final secret = generateSecret();
      final otpAuthUri = generateOtpAuthUri(secret, userEmail);

      // Store secret securely (not in Firestore - only locally until verified)
      await _secureStorage.write(key: '${_totpSecretKey}_$userId', value: secret);

      return {
        'secret': secret,
        'otpAuthUri': otpAuthUri,
        'manualEntry': secret,
      };
    } catch (e) {
      debugPrint('Error setting up 2FA: $e');
      rethrow;
    }
  }

  /// Verify and enable 2FA after user enters code from authenticator app
  Future<bool> verify2FASetup(String userId, String code) async {
    try {
      // Get the temporary secret
      final secret = await _secureStorage.read(key: '${_totpSecretKey}_$userId');
      if (secret == null) {
        throw Exception('2FA setup not found. Please restart setup.');
      }

      // Verify the code
      if (!verifyCode(secret, code)) {
        return false;
      }

      // Store encrypted secret in Firestore and enable 2FA
      // In production, you'd want to encrypt this before storing
      final encryptedSecret = base64Encode(utf8.encode(secret));

      await _firestore.collection('users').doc(userId).set({
        'securitySettings': {
          'twoFactorEnabled': true,
          'twoFactorSecret': encryptedSecret,
          'twoFactorSetupAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Error verifying 2FA setup: $e');
      rethrow;
    }
  }

  /// Verify 2FA code during login
  Future<bool> verify2FACode(String userId, String code) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final securitySettings = doc.data()?['securitySettings'] as Map<String, dynamic>?;
      final encryptedSecret = securitySettings?['twoFactorSecret'] as String?;

      if (encryptedSecret == null) return false;

      // Decrypt secret
      final secret = utf8.decode(base64Decode(encryptedSecret));

      return verifyCode(secret, code);
    } catch (e) {
      debugPrint('Error verifying 2FA code: $e');
      return false;
    }
  }

  /// Disable 2FA for user
  Future<bool> disable2FA(String userId, String code) async {
    try {
      // Verify code before disabling
      final isValid = await verify2FACode(userId, code);
      if (!isValid) {
        return false;
      }

      // Remove 2FA settings
      await _firestore.collection('users').doc(userId).set({
        'securitySettings': {
          'twoFactorEnabled': false,
          'twoFactorSecret': FieldValue.delete(),
          'twoFactorDisabledAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      // Clear local storage
      await _secureStorage.delete(key: '${_totpSecretKey}_$userId');

      return true;
    } catch (e) {
      debugPrint('Error disabling 2FA: $e');
      rethrow;
    }
  }

  /// Generate backup codes for 2FA recovery
  Future<List<String>> generateBackupCodes(String userId) async {
    try {
      final random = Random.secure();
      final codes = List.generate(10, (_) {
        return List.generate(8, (_) => random.nextInt(10)).join();
      });

      // Hash the codes before storing
      final hashedCodes = codes.map((code) {
        return sha256.convert(utf8.encode(code)).toString();
      }).toList();

      await _firestore.collection('users').doc(userId).set({
        'securitySettings': {
          'backupCodes': hashedCodes,
          'backupCodesGeneratedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      return codes;
    } catch (e) {
      debugPrint('Error generating backup codes: $e');
      rethrow;
    }
  }

  /// Verify a backup code (one-time use)
  Future<bool> verifyBackupCode(String userId, String code) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final securitySettings = doc.data()?['securitySettings'] as Map<String, dynamic>?;
      final backupCodes = (securitySettings?['backupCodes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList();

      if (backupCodes == null || backupCodes.isEmpty) return false;

      final hashedCode = sha256.convert(utf8.encode(code)).toString();

      if (backupCodes.contains(hashedCode)) {
        // Remove used code
        backupCodes.remove(hashedCode);
        await _firestore.collection('users').doc(userId).set({
          'securitySettings': {
            'backupCodes': backupCodes,
          },
        }, SetOptions(merge: true));
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error verifying backup code: $e');
      return false;
    }
  }
}
