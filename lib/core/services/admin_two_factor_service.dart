import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:base32/base32.dart';
import 'audit_service.dart';

/// Admin Two-Factor Authentication Service
/// Provides enhanced security for admin login with:
/// - SMS OTP verification
/// - Email OTP verification
/// - Time-based codes with expiry
/// - Rate limiting for verification attempts
/// - Trusted device management
/// - Audit logging for all 2FA events
class AdminTwoFactorService {
  static final AdminTwoFactorService _instance =
      AdminTwoFactorService._internal();
  factory AdminTwoFactorService() => _instance;
  AdminTwoFactorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuditService _auditService = AuditService();

  // 2FA Configuration
  static const int otpLength = 6;
  static const int otpValidityMinutes = 5;
  static const int maxVerificationAttempts = 5;
  static const int lockoutDurationMinutes = 30;
  static const int trustedDeviceValidityDays = 30;
  static const int totpTimeStep = 30; // TOTP time step in seconds
  static const String totpIssuer = 'BODA Connect Admin';

  // Pending verifications cache
  final Map<String, Admin2FASession> _pendingSessions = {};

  /// Check if admin requires 2FA verification
  Future<Admin2FARequirement> check2FARequirement({
    required String adminId,
    required String deviceId,
  }) async {
    try {
      // Get admin document
      final adminDoc =
          await _firestore.collection('users').doc(adminId).get();

      if (!adminDoc.exists) {
        return Admin2FARequirement(
          required: false,
          reason: 'Admin not found',
        );
      }

      final adminData = adminDoc.data()!;
      final role = adminData['role'] as String?;

      // Only require 2FA for admin roles
      if (role != 'admin' && role != 'app_admin') {
        return Admin2FARequirement(
          required: false,
          reason: 'Not an admin user',
        );
      }

      // Check if device is trusted
      final isTrusted = await _isDeviceTrusted(adminId, deviceId);
      if (isTrusted) {
        debugPrint('✅ Device is trusted, skipping 2FA');
        return Admin2FARequirement(
          required: false,
          reason: 'Trusted device',
          isTrustedDevice: true,
        );
      }

      // Check if 2FA is enabled for this admin (default: always required)
      final twoFactorEnabled = adminData['twoFactorEnabled'] ?? true;
      if (!twoFactorEnabled) {
        return Admin2FARequirement(
          required: false,
          reason: '2FA disabled for this admin',
        );
      }

      // Get admin's preferred 2FA method
      final preferredMethod =
          adminData['twoFactorMethod'] as String? ?? 'authenticator';
      final phoneNumber = adminData['phone'] as String?;
      final totpSecret = adminData['totpSecret'] as String?;
      final totpEnabled = adminData['totpEnabled'] as bool? ?? false;

      return Admin2FARequirement(
        required: true,
        preferredMethod: Admin2FAMethod.values.firstWhere(
          (m) => m.name == preferredMethod,
          orElse: () => Admin2FAMethod.authenticator,
        ),
        phoneNumber: phoneNumber,
        totpSecret: totpSecret,
        totpEnabled: totpEnabled,
      );
    } catch (e) {
      debugPrint('❌ Error checking 2FA requirement: $e');
      // Default to requiring 2FA on error for security
      return Admin2FARequirement(
        required: true,
        preferredMethod: Admin2FAMethod.authenticator,
      );
    }
  }

  /// Initiate 2FA verification
  Future<Admin2FAInitResult> initiate2FA({
    required String adminId,
    required Admin2FAMethod method,
    String? phoneNumber,
    String? totpSecret,
  }) async {
    try {
      // Check rate limiting
      final isLocked = await _isAdminLocked(adminId);
      if (isLocked) {
        await _auditService.logSecurityEvent(
          userId: adminId,
          eventType: SecurityEventType.rateLimitExceeded,
          description: 'Admin 2FA locked due to too many attempts',
          severity: SecuritySeverity.warning,
        );

        return Admin2FAInitResult(
          success: false,
          error: 'Conta bloqueada temporariamente. Tente novamente em $lockoutDurationMinutes minutos.',
        );
      }

      final sessionId = '${adminId}_${DateTime.now().millisecondsSinceEpoch}';
      final expiresAt =
          DateTime.now().add(Duration(minutes: otpValidityMinutes));

      String destination = '';
      String? hashedOtp;

      switch (method) {
        case Admin2FAMethod.sms:
          if (phoneNumber == null || phoneNumber.isEmpty) {
            return Admin2FAInitResult(
              success: false,
              error: 'Número de telefone não configurado',
            );
          }
          // Generate and send OTP for SMS
          final otp = _generateOTP();
          hashedOtp = _hashOTP(otp);
          final otpSent = await _sendSmsOTP(phoneNumber, otp);
          if (!otpSent) {
            return Admin2FAInitResult(
              success: false,
              error: 'Erro ao enviar código de verificação',
            );
          }
          destination = _maskPhone(phoneNumber);
          break;

        case Admin2FAMethod.authenticator:
          // For authenticator, we don't generate OTP - the app generates it
          // Just create a session to track verification attempts
          if (totpSecret == null || totpSecret.isEmpty) {
            // Admin hasn't set up authenticator yet - return setup required
            return Admin2FAInitResult(
              success: false,
              requiresSetup: true,
              error: 'Authenticator app não configurado',
            );
          }
          hashedOtp = ''; // No hashed OTP for TOTP - verified in real-time
          destination = 'Authenticator App';
          break;
      }

      // Create session
      final session = Admin2FASession(
        sessionId: sessionId,
        adminId: adminId,
        method: method,
        hashedOtp: hashedOtp ?? '',
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        attempts: 0,
      );

      // Store session
      _pendingSessions[sessionId] = session;
      await _firestore
          .collection('admin_2fa_sessions')
          .doc(sessionId)
          .set(session.toMap());

      // Log 2FA initiation
      await _auditService.logSecurityEvent(
        userId: adminId,
        eventType: SecurityEventType.loginSuccess,
        description: 'Admin 2FA initiated via ${method.name}',
        metadata: {
          'method': method.name,
          'destination': destination,
          'sessionId': sessionId,
        },
        severity: SecuritySeverity.info,
      );

      debugPrint('✅ Admin 2FA initiated: $sessionId via ${method.name}');

      return Admin2FAInitResult(
        success: true,
        sessionId: sessionId,
        expiresAt: expiresAt,
        destination: destination,
        method: method,
      );
    } catch (e) {
      debugPrint('❌ Error initiating 2FA: $e');
      return Admin2FAInitResult(
        success: false,
        error: 'Erro ao iniciar verificação: $e',
      );
    }
  }

  /// Verify 2FA code
  Future<Admin2FAVerifyResult> verify2FA({
    required String sessionId,
    required String code,
    required String deviceId,
    String? deviceName,
    bool trustDevice = false,
  }) async {
    try {
      // Get session
      Admin2FASession? session = _pendingSessions[sessionId];

      if (session == null) {
        // Try to load from Firestore
        final doc = await _firestore
            .collection('admin_2fa_sessions')
            .doc(sessionId)
            .get();

        if (!doc.exists) {
          return Admin2FAVerifyResult(
            success: false,
            error: 'Sessão de verificação não encontrada ou expirada',
          );
        }

        session = Admin2FASession.fromMap(doc.data()!);
      }

      // Check expiration
      if (DateTime.now().isAfter(session.expiresAt)) {
        await _cleanupSession(sessionId);
        return Admin2FAVerifyResult(
          success: false,
          error: 'Código expirado. Solicite um novo.',
        );
      }

      // Check attempts
      if (session.attempts >= maxVerificationAttempts) {
        await _lockAdmin(session.adminId);
        await _cleanupSession(sessionId);

        await _auditService.logSecurityEvent(
          userId: session.adminId,
          eventType: SecurityEventType.unauthorizedAccess,
          description: 'Admin 2FA max attempts exceeded',
          metadata: {'attempts': session.attempts},
          severity: SecuritySeverity.critical,
        );

        return Admin2FAVerifyResult(
          success: false,
          error: 'Muitas tentativas incorretas. Conta bloqueada temporariamente.',
        );
      }

      // Verify code based on method
      bool isCodeValid = false;

      if (session.method == Admin2FAMethod.authenticator) {
        // Get TOTP secret from admin profile
        final adminDoc =
            await _firestore.collection('users').doc(session.adminId).get();
        final totpSecret = adminDoc.data()?['totpSecret'] as String?;

        if (totpSecret != null) {
          isCodeValid = verifyTOTP(totpSecret, code.trim());
        }
      } else {
        // SMS verification - compare hashed codes
        final hashedInput = _hashOTP(code.trim());
        isCodeValid = hashedInput == session.hashedOtp;
      }

      if (!isCodeValid) {
        // Increment attempts
        session = Admin2FASession(
          sessionId: session.sessionId,
          adminId: session.adminId,
          method: session.method,
          hashedOtp: session.hashedOtp,
          createdAt: session.createdAt,
          expiresAt: session.expiresAt,
          attempts: session.attempts + 1,
        );

        _pendingSessions[sessionId] = session;
        await _firestore
            .collection('admin_2fa_sessions')
            .doc(sessionId)
            .update({'attempts': session.attempts});

        await _auditService.logSecurityEvent(
          userId: session.adminId,
          eventType: SecurityEventType.loginFailure,
          description: 'Admin 2FA verification failed',
          metadata: {
            'attempt': session.attempts,
            'sessionId': sessionId,
          },
          severity: SecuritySeverity.warning,
        );

        final remainingAttempts = maxVerificationAttempts - session.attempts;
        return Admin2FAVerifyResult(
          success: false,
          error: 'Código incorreto. $remainingAttempts tentativas restantes.',
          remainingAttempts: remainingAttempts,
        );
      }

      // Verification successful
      await _cleanupSession(sessionId);

      // Trust device if requested
      if (trustDevice) {
        await _trustDevice(
          adminId: session.adminId,
          deviceId: deviceId,
          deviceName: deviceName,
        );
      }

      // Log successful verification
      await _auditService.logSecurityEvent(
        userId: session.adminId,
        eventType: SecurityEventType.loginSuccess,
        description: 'Admin 2FA verification successful',
        metadata: {
          'method': session.method.name,
          'deviceTrusted': trustDevice,
          'deviceId': deviceId,
        },
        severity: SecuritySeverity.info,
      );

      // Update last 2FA verification timestamp
      await _firestore.collection('users').doc(session.adminId).update({
        'last2FAVerification': FieldValue.serverTimestamp(),
        'lastLoginDeviceId': deviceId,
      });

      debugPrint('✅ Admin 2FA verified successfully: ${session.adminId}');

      return Admin2FAVerifyResult(
        success: true,
        adminId: session.adminId,
        deviceTrusted: trustDevice,
      );
    } catch (e) {
      debugPrint('❌ Error verifying 2FA: $e');
      return Admin2FAVerifyResult(
        success: false,
        error: 'Erro ao verificar código: $e',
      );
    }
  }

  /// Resend 2FA code (only for SMS, authenticator generates codes locally)
  Future<Admin2FAInitResult> resend2FA({
    required String sessionId,
  }) async {
    try {
      Admin2FASession? session = _pendingSessions[sessionId];

      if (session == null) {
        final doc = await _firestore
            .collection('admin_2fa_sessions')
            .doc(sessionId)
            .get();

        if (!doc.exists) {
          return Admin2FAInitResult(
            success: false,
            error: 'Sessão não encontrada',
          );
        }

        session = Admin2FASession.fromMap(doc.data()!);
      }

      // Authenticator app generates codes locally - no resend needed
      if (session.method == Admin2FAMethod.authenticator) {
        return Admin2FAInitResult(
          success: false,
          error: 'Authenticator gera códigos automaticamente. Verifique seu app.',
        );
      }

      // Get admin details for resend
      final adminDoc =
          await _firestore.collection('users').doc(session.adminId).get();

      if (!adminDoc.exists) {
        return Admin2FAInitResult(
          success: false,
          error: 'Admin não encontrado',
        );
      }

      final adminData = adminDoc.data()!;

      // Clean old session and create new one
      await _cleanupSession(sessionId);

      // Initiate new 2FA with same method
      return initiate2FA(
        adminId: session.adminId,
        method: session.method,
        phoneNumber: adminData['phone'] as String?,
      );
    } catch (e) {
      debugPrint('❌ Error resending 2FA: $e');
      return Admin2FAInitResult(
        success: false,
        error: 'Erro ao reenviar código: $e',
      );
    }
  }

  /// Get trusted devices for admin
  Future<List<TrustedDevice>> getTrustedDevices(String adminId) async {
    try {
      final snapshot = await _firestore
          .collection('admin_trusted_devices')
          .where('adminId', isEqualTo: adminId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      return snapshot.docs
          .map((doc) => TrustedDevice.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting trusted devices: $e');
      return [];
    }
  }

  /// Remove trusted device
  Future<bool> removeTrustedDevice({
    required String adminId,
    required String deviceId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('admin_trusted_devices')
          .where('adminId', isEqualTo: adminId)
          .where('deviceId', isEqualTo: deviceId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      await _auditService.logSecurityEvent(
        userId: adminId,
        eventType: SecurityEventType.sessionTerminated,
        description: 'Admin removed trusted device',
        metadata: {'deviceId': deviceId},
        severity: SecuritySeverity.info,
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error removing trusted device: $e');
      return false;
    }
  }

  /// Remove all trusted devices (force re-authentication on all devices)
  Future<bool> removeAllTrustedDevices(String adminId) async {
    try {
      final snapshot = await _firestore
          .collection('admin_trusted_devices')
          .where('adminId', isEqualTo: adminId)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await _auditService.logSecurityEvent(
        userId: adminId,
        eventType: SecurityEventType.sessionTerminated,
        description: 'Admin removed all trusted devices',
        metadata: {'devicesRemoved': snapshot.docs.length},
        severity: SecuritySeverity.warning,
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error removing all trusted devices: $e');
      return false;
    }
  }

  // ==================== TOTP METHODS ====================

  /// Generate a new TOTP secret for authenticator app setup
  String generateTOTPSecret() {
    final random = Random.secure();
    final bytes = Uint8List(20); // 160-bit secret
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base32.encode(bytes);
  }

  /// Generate TOTP URI for QR code (otpauth:// format)
  String generateTOTPUri({
    required String secret,
    required String accountName,
  }) {
    final encodedIssuer = Uri.encodeComponent(totpIssuer);
    final encodedAccount = Uri.encodeComponent(accountName);
    return 'otpauth://totp/$encodedIssuer:$encodedAccount?secret=$secret&issuer=$encodedIssuer&algorithm=SHA1&digits=6&period=$totpTimeStep';
  }

  /// Verify a TOTP code against the secret
  bool verifyTOTP(String secret, String code) {
    if (code.length != 6) return false;

    try {
      // Check current time window and adjacent windows (±1) for clock drift
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      for (int offset = -1; offset <= 1; offset++) {
        final timeCounter = (currentTime ~/ totpTimeStep) + offset;
        final expectedCode = _generateTOTPCode(secret, timeCounter);
        if (expectedCode == code) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error verifying TOTP: $e');
      return false;
    }
  }

  /// Generate TOTP code for a specific time counter
  String _generateTOTPCode(String secret, int timeCounter) {
    // Decode the base32 secret
    final secretBytes = base32.decode(secret);

    // Convert time counter to 8-byte big-endian
    final timeBytes = Uint8List(8);
    var counter = timeCounter;
    for (int i = 7; i >= 0; i--) {
      timeBytes[i] = counter & 0xff;
      counter >>= 8;
    }

    // Calculate HMAC-SHA1
    final hmac = Hmac(sha1, secretBytes);
    final hash = hmac.convert(timeBytes).bytes;

    // Dynamic truncation
    final offset = hash[hash.length - 1] & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);

    // Generate 6-digit code
    final otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  /// Setup TOTP for an admin (saves secret to Firestore)
  Future<TOTPSetupResult> setupTOTP({
    required String adminId,
    required String adminEmail,
  }) async {
    try {
      final secret = generateTOTPSecret();
      final uri = generateTOTPUri(
        secret: secret,
        accountName: adminEmail,
      );

      // Store the secret (encrypted in production)
      await _firestore.collection('users').doc(adminId).update({
        'totpSecret': secret,
        'totpEnabled': false, // Not enabled until verified
        'totpSetupAt': FieldValue.serverTimestamp(),
      });

      await _auditService.logSecurityEvent(
        userId: adminId,
        eventType: SecurityEventType.loginSuccess,
        description: 'Admin initiated TOTP setup',
        severity: SecuritySeverity.info,
      );

      return TOTPSetupResult(
        success: true,
        secret: secret,
        uri: uri,
      );
    } catch (e) {
      debugPrint('❌ Error setting up TOTP: $e');
      return TOTPSetupResult(
        success: false,
        error: 'Erro ao configurar authenticator: $e',
      );
    }
  }

  /// Verify and enable TOTP after initial setup
  Future<bool> verifyAndEnableTOTP({
    required String adminId,
    required String code,
  }) async {
    try {
      final adminDoc =
          await _firestore.collection('users').doc(adminId).get();
      final totpSecret = adminDoc.data()?['totpSecret'] as String?;

      if (totpSecret == null) {
        return false;
      }

      if (!verifyTOTP(totpSecret, code)) {
        return false;
      }

      // Enable TOTP
      await _firestore.collection('users').doc(adminId).update({
        'totpEnabled': true,
        'twoFactorMethod': 'authenticator',
        'totpVerifiedAt': FieldValue.serverTimestamp(),
      });

      await _auditService.logSecurityEvent(
        userId: adminId,
        eventType: SecurityEventType.loginSuccess,
        description: 'Admin enabled TOTP authentication',
        severity: SecuritySeverity.info,
      );

      debugPrint('✅ TOTP enabled for admin: $adminId');
      return true;
    } catch (e) {
      debugPrint('❌ Error enabling TOTP: $e');
      return false;
    }
  }

  /// Disable TOTP for an admin
  Future<bool> disableTOTP(String adminId) async {
    try {
      await _firestore.collection('users').doc(adminId).update({
        'totpSecret': FieldValue.delete(),
        'totpEnabled': false,
        'twoFactorMethod': 'sms',
      });

      await _auditService.logSecurityEvent(
        userId: adminId,
        eventType: SecurityEventType.sessionTerminated,
        description: 'Admin disabled TOTP authentication',
        severity: SecuritySeverity.warning,
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error disabling TOTP: $e');
      return false;
    }
  }

  // ==================== PRIVATE METHODS ====================

  /// Generate random OTP
  String _generateOTP() {
    final random = Random.secure();
    return List.generate(otpLength, (_) => random.nextInt(10)).join();
  }

  /// Hash OTP for secure storage
  String _hashOTP(String otp) {
    final bytes = utf8.encode(otp);
    return sha256.convert(bytes).toString();
  }

  /// Send OTP via SMS
  Future<bool> _sendSmsOTP(String phoneNumber, String otp) async {
    try {
      // In production, use Twilio or other SMS provider
      // For now, store in Firestore for testing and use Firebase phone auth
      debugPrint('📱 Admin 2FA SMS OTP: $otp to $phoneNumber');

      // Store OTP for verification (in production, send via SMS API)
      // This is a placeholder - integrate with your SMS service
      await _firestore.collection('admin_otp_log').add({
        'phone': phoneNumber,
        'otp': otp, // In production, don't store plaintext OTP
        'type': 'sms',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(Duration(minutes: otpValidityMinutes)),
        ),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error sending SMS OTP: $e');
      return false;
    }
  }

  /// Check if device is trusted
  Future<bool> _isDeviceTrusted(String adminId, String deviceId) async {
    try {
      final snapshot = await _firestore
          .collection('admin_trusted_devices')
          .where('adminId', isEqualTo: adminId)
          .where('deviceId', isEqualTo: deviceId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking trusted device: $e');
      return false;
    }
  }

  /// Trust a device
  Future<void> _trustDevice({
    required String adminId,
    required String deviceId,
    String? deviceName,
  }) async {
    try {
      final expiresAt = DateTime.now()
          .add(Duration(days: trustedDeviceValidityDays));

      await _firestore.collection('admin_trusted_devices').add({
        'adminId': adminId,
        'deviceId': deviceId,
        'deviceName': deviceName ?? 'Unknown Device',
        'trustedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      debugPrint('✅ Device trusted: $deviceId for $adminId');
    } catch (e) {
      debugPrint('❌ Error trusting device: $e');
    }
  }

  /// Check if admin is locked
  Future<bool> _isAdminLocked(String adminId) async {
    try {
      final doc = await _firestore
          .collection('admin_2fa_lockouts')
          .doc(adminId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final lockedUntil = (data['lockedUntil'] as Timestamp?)?.toDate();

      if (lockedUntil == null) return false;

      return DateTime.now().isBefore(lockedUntil);
    } catch (e) {
      debugPrint('❌ Error checking admin lockout: $e');
      return false;
    }
  }

  /// Lock admin after too many attempts
  Future<void> _lockAdmin(String adminId) async {
    try {
      final lockedUntil =
          DateTime.now().add(Duration(minutes: lockoutDurationMinutes));

      await _firestore.collection('admin_2fa_lockouts').doc(adminId).set({
        'adminId': adminId,
        'lockedAt': FieldValue.serverTimestamp(),
        'lockedUntil': Timestamp.fromDate(lockedUntil),
        'reason': 'Too many failed 2FA attempts',
      });

      debugPrint('🔒 Admin locked: $adminId until $lockedUntil');
    } catch (e) {
      debugPrint('❌ Error locking admin: $e');
    }
  }

  /// Clean up session
  Future<void> _cleanupSession(String sessionId) async {
    _pendingSessions.remove(sessionId);
    try {
      await _firestore
          .collection('admin_2fa_sessions')
          .doc(sessionId)
          .delete();
    } catch (e) {
      debugPrint('❌ Error cleaning up session: $e');
    }
  }

  /// Mask phone number
  String _maskPhone(String phone) {
    if (phone.length < 4) return '****';
    return '****${phone.substring(phone.length - 4)}';
  }
}

// ==================== MODELS ====================

/// 2FA Method options
enum Admin2FAMethod {
  sms,
  authenticator,
}

/// 2FA Requirement check result
class Admin2FARequirement {
  final bool required;
  final String? reason;
  final Admin2FAMethod? preferredMethod;
  final String? phoneNumber;
  final String? totpSecret;
  final bool totpEnabled;
  final bool isTrustedDevice;

  Admin2FARequirement({
    required this.required,
    this.reason,
    this.preferredMethod,
    this.phoneNumber,
    this.totpSecret,
    this.totpEnabled = false,
    this.isTrustedDevice = false,
  });
}

/// 2FA initiation result
class Admin2FAInitResult {
  final bool success;
  final String? sessionId;
  final DateTime? expiresAt;
  final String? destination;
  final Admin2FAMethod? method;
  final String? error;
  final bool requiresSetup;

  Admin2FAInitResult({
    required this.success,
    this.sessionId,
    this.expiresAt,
    this.destination,
    this.method,
    this.error,
    this.requiresSetup = false,
  });
}

/// TOTP Setup result
class TOTPSetupResult {
  final bool success;
  final String? secret;
  final String? uri;
  final String? error;

  TOTPSetupResult({
    required this.success,
    this.secret,
    this.uri,
    this.error,
  });
}

/// 2FA verification result
class Admin2FAVerifyResult {
  final bool success;
  final String? adminId;
  final String? error;
  final int? remainingAttempts;
  final bool deviceTrusted;

  Admin2FAVerifyResult({
    required this.success,
    this.adminId,
    this.error,
    this.remainingAttempts,
    this.deviceTrusted = false,
  });
}

/// 2FA Session
class Admin2FASession {
  final String sessionId;
  final String adminId;
  final Admin2FAMethod method;
  final String hashedOtp;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int attempts;

  Admin2FASession({
    required this.sessionId,
    required this.adminId,
    required this.method,
    required this.hashedOtp,
    required this.createdAt,
    required this.expiresAt,
    required this.attempts,
  });

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'adminId': adminId,
        'method': method.name,
        'hashedOtp': hashedOtp,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attempts': attempts,
      };

  factory Admin2FASession.fromMap(Map<String, dynamic> map) =>
      Admin2FASession(
        sessionId: map['sessionId'] as String,
        adminId: map['adminId'] as String,
        method: Admin2FAMethod.values.firstWhere(
          (m) => m.name == map['method'],
          orElse: () => Admin2FAMethod.authenticator,
        ),
        hashedOtp: map['hashedOtp'] as String,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        expiresAt: (map['expiresAt'] as Timestamp).toDate(),
        attempts: map['attempts'] as int? ?? 0,
      );
}

/// Trusted Device
class TrustedDevice {
  final String adminId;
  final String deviceId;
  final String deviceName;
  final DateTime trustedAt;
  final DateTime expiresAt;

  TrustedDevice({
    required this.adminId,
    required this.deviceId,
    required this.deviceName,
    required this.trustedAt,
    required this.expiresAt,
  });

  factory TrustedDevice.fromMap(Map<String, dynamic> map) => TrustedDevice(
        adminId: map['adminId'] as String,
        deviceId: map['deviceId'] as String,
        deviceName: map['deviceName'] as String? ?? 'Unknown Device',
        trustedAt: (map['trustedAt'] as Timestamp).toDate(),
        expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      );

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
