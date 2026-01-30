import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// SMS Authentication Service using Firebase Phone Auth
///
/// Fallback option when WhatsApp OTP is unavailable.
/// Uses Firebase's built-in phone authentication.
class SmsAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== SEND OTP VIA SMS ====================

  /// Send OTP code via SMS using Firebase Phone Auth
  ///
  /// [phone] - Phone number without country code (e.g., "923456789")
  /// [countryCode] - Country code with + (e.g., "+244" for Angola)
  /// [onCodeSent] - Callback when code is sent successfully
  /// [onVerificationCompleted] - Callback for auto-verification (Android)
  /// [onVerificationFailed] - Callback when verification fails
  /// [onCodeAutoRetrievalTimeout] - Callback when auto-retrieval times out
  Future<void> sendOTP({
    required String phone,
    String countryCode = '+244',
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    required Function(FirebaseAuthException error) onVerificationFailed,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    // Check if phone already includes country code (starts with +)
    final String fullPhone;
    if (phone.startsWith('+')) {
      // Phone already has country code, use as-is (just normalize)
      fullPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    } else {
      // Phone doesn't have country code, add it
      fullPhone = '$countryCode${phone.replaceAll(RegExp(r'\D'), '')}';
    }

    debugPrint('📱 Sending SMS OTP to: $fullPhone');

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,

      // Called when code is sent
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('✅ SMS code sent, verificationId: $verificationId');
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent(verificationId, resendToken);
      },

      // Called on Android when auto-verification completes
      verificationCompleted: (PhoneAuthCredential credential) {
        debugPrint('✅ Auto-verification completed');
        onVerificationCompleted(credential);
      },

      // Called when verification fails
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('❌ Verification failed: ${e.code} - ${e.message}');
        onVerificationFailed(e);
      },

      // Called when auto-retrieval times out
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('⏱️ Auto-retrieval timeout');
        _verificationId = verificationId;
        onCodeAutoRetrievalTimeout?.call(verificationId);
      },
    );
  }

  /// Send OTP with automatic SMS → WhatsApp fallback
  ///
  /// Tries Firebase SMS first. If it fails, caller can trigger WhatsApp OTP.
  /// This method does NOT change existing behavior unless explicitly used.
  Future<void> sendOtpWithFallback({
    required String fullPhoneNumber, // MUST be E.164 (+XXXXXXXX)
    required VoidCallback onSmsSent,
    required VoidCallback onWhatsappFallback,
    required Function(FirebaseAuthException error) onFailure,
  }) async {
    debugPrint('📡 OTP attempt (SMS first): $fullPhoneNumber');

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _logAuthAttempt(
            phone: fullPhoneNumber,
            channel: 'sms',
            success: true,
          );
          onSmsSent();
        },
        verificationFailed: (e) {
          _logAuthAttempt(
            phone: fullPhoneNumber,
            channel: 'sms',
            success: false,
          );
          debugPrint('⚠️ SMS failed, fallback to WhatsApp');
          onWhatsappFallback();
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      _logAuthAttempt(
        phone: fullPhoneNumber,
        channel: 'sms',
        success: false,
      );
      onFailure(e);
    }
  }

  /// Normalize phone number to strict E.164
  /// Removes spaces, dashes, parentheses
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\s+|\(|\)|-'), '');
  }

  /// Lightweight audit log (NO OTPs, NO secrets)
  void _logAuthAttempt({
    required String phone,
    required String channel, // sms | whatsapp
    required bool success,
  }) {
    final normalized = _normalizePhone(phone);

    debugPrint(
      '🔐 AUTH_LOG | phone=$normalized | channel=$channel | success=$success',
    );
  }

  // ==================== VERIFY OTP ====================

  /// Verify OTP code and sign in
  ///
  /// [otp] - 6-digit OTP code
  /// [verificationId] - Optional, uses stored ID if not provided
  ///
  /// Returns [SmsVerifyResult] with user credentials
  Future<SmsVerifyResult> verifyOTP({
    required String otp,
    String? verificationId,
  }) async {
    final verId = verificationId ?? _verificationId;

    if (verId == null) {
      return SmsVerifyResult(
        success: false,
        message: 'Sessão expirada. Solicite um novo código.',
      );
    }

    try {
      // Create credential
      final credential = PhoneAuthProvider.credential(
        verificationId: verId,
        smsCode: otp,
      );

      // Sign in with credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if new user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      debugPrint('✅ SMS verification successful, isNewUser: $isNewUser');

      return SmsVerifyResult(
        success: true,
        message: 'Login realizado com sucesso',
        userCredential: userCredential,
        userId: userCredential.user?.uid,
        isNewUser: isNewUser,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ SMS verification error: ${e.code}');
      return SmsVerifyResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e) {
      debugPrint('❌ SMS verification error: $e');
      return SmsVerifyResult(
        success: false,
        message: 'Erro ao verificar código. Tente novamente.',
      );
    }
  }

  // ==================== SIGN IN WITH CREDENTIAL ====================

  /// Sign in with auto-verified credential (Android only)
  Future<SmsVerifyResult> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      return SmsVerifyResult(
        success: true,
        message: 'Login realizado com sucesso',
        userCredential: userCredential,
        userId: userCredential.user?.uid,
        isNewUser: isNewUser,
      );
    } on FirebaseAuthException catch (e) {
      return SmsVerifyResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    }
  }

  // ==================== RESEND OTP ====================

  /// Resend OTP code via SMS
  Future<void> resendOTP({
    required String phone,
    String countryCode = '+244',
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    required Function(FirebaseAuthException error) onVerificationFailed,
  }) async {
    await sendOTP(
      phone: phone,
      countryCode: countryCode,
      onCodeSent: onCodeSent,
      onVerificationCompleted: onVerificationCompleted,
      onVerificationFailed: onVerificationFailed,
      forceResendingToken: _resendToken,
    );
  }

  // ==================== SIGN OUT ====================

  /// Sign out current user
  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    await _auth.signOut();
  }

  // ==================== HELPERS ====================

  /// Get stored verification ID
  String? get verificationId => _verificationId;

  /// Get stored resend token
  int? get resendToken => _resendToken;

  /// Clear verification data
  void clearVerificationData() {
    _verificationId = null;
    _resendToken = null;
  }

  /// Get user-friendly error message from Firebase error code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Número de telefone inválido.';
      case 'invalid-verification-code':
        return 'Código inválido. Verifique e tente novamente.';
      case 'invalid-verification-id':
        return 'Sessão expirada. Solicite um novo código.';
      case 'session-expired':
        return 'Sessão expirada. Solicite um novo código.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'quota-exceeded':
        return 'Limite de SMS excedido. Tente WhatsApp.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'operation-not-allowed':
        return 'Autenticação por SMS não está habilitada.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet.';
      default:
        return 'Erro inesperado. Tente novamente.';
    }
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 9;
  }

  /// Format phone number for display
  String formatPhoneDisplay(String phone, {String countryCode = '+244'}) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length >= 9) {
      return '$countryCode ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }

    return '$countryCode $digits';
  }
}

// ==================== RESULT CLASS ====================

/// Result from SMS OTP verification
class SmsVerifyResult {
  final bool success;
  final String message;
  final UserCredential? userCredential;
  final String? userId;
  final bool isNewUser;
  final Object? error;

  SmsVerifyResult({
    required this.success,
    required this.message,
    this.userCredential,
    this.userId,
    this.isNewUser = false,
    this.error,
  });

  /// Get the authenticated user
  User? get user => userCredential?.user;
}
