import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// WhatsApp Authentication Service
///
/// Provides OTP-based authentication via WhatsApp messages.
/// Uses Firebase Cloud Functions + Twilio WhatsApp API.
///
/// Benefits over SMS:
/// - Cheaper (especially for Angola)
/// - More reliable delivery
/// - Users trust WhatsApp
class WhatsAppAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'africa-south1',
  );

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== SEND OTP ====================

  /// Send OTP code via WhatsApp
  ///
  /// [phone] - Phone number without country code (e.g., "923456789")
  /// [countryCode] - Country code with + (e.g., "+244" for Angola)
  ///
  /// Returns [WhatsAppOTPResult] with success status and expiry time
  Future<WhatsAppOTPResult> sendOTP({
    required String phone,
    String countryCode = '+244',
  }) async {
    try {
      final callable = _functions.httpsCallable('sendWhatsAppOTP');

      final result = await callable.call<Map<String, dynamic>>({
        'phone': phone,
        'countryCode': countryCode,
      });

      final data = result.data;

      return WhatsAppOTPResult(
        success: data['success'] ?? false,
        message: data['message'] ?? 'Código enviado',
        expiresIn: data['expiresIn'] ?? 300,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('WhatsApp OTP error: ${e.code} - ${e.message}');
      return WhatsAppOTPResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e) {
      debugPrint('WhatsApp OTP error: $e');
      return WhatsAppOTPResult(
        success: false,
        message: 'Erro ao enviar código. Tente novamente.',
      );
    }
  }

  // ==================== VERIFY OTP ====================

  /// Verify OTP code and sign in
  ///
  /// [phone] - Phone number without country code
  /// [otp] - 6-digit OTP code
  /// [countryCode] - Country code with +
  ///
  /// Returns [WhatsAppVerifyResult] with user credentials
  Future<WhatsAppVerifyResult> verifyOTP({
    required String phone,
    required String otp,
    String countryCode = '+244',
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyWhatsAppOTP');

      final result = await callable.call<Map<String, dynamic>>({
        'phone': phone,
        'otp': otp,
        'countryCode': countryCode,
      });

      final data = result.data;

      if (data['success'] == true && data['token'] != null) {
        // Sign in with custom token
        final userCredential = await _auth.signInWithCustomToken(
          data['token'] as String,
        );

        return WhatsAppVerifyResult(
          success: true,
          message: 'Login realizado com sucesso',
          userCredential: userCredential,
          userId: data['userId'] as String?,
          isNewUser: data['isNewUser'] ?? false,
        );
      }

      return WhatsAppVerifyResult(
        success: false,
        message: data['message'] ?? 'Erro ao verificar código',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('WhatsApp verify error: ${e.code} - ${e.message}');
      return WhatsAppVerifyResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e) {
      debugPrint('WhatsApp verify error: $e');
      return WhatsAppVerifyResult(
        success: false,
        message: 'Erro ao verificar código. Tente novamente.',
      );
    }
  }

  // ==================== RESEND OTP ====================

  /// Resend OTP code via WhatsApp
  ///
  /// Has a 60-second cooldown between resends
  Future<WhatsAppOTPResult> resendOTP({
    required String phone,
    String countryCode = '+244',
  }) async {
    return sendOTP(phone: phone, countryCode: countryCode);
  }

  // ==================== SIGN OUT ====================

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== HELPERS ====================

  /// Get user-friendly error message from Firebase error code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-argument':
        return 'Dados inválidos. Verifique o número de telefone.';
      case 'not-found':
        return 'Código não encontrado. Solicite um novo.';
      case 'deadline-exceeded':
        return 'Código expirado. Solicite um novo.';
      case 'resource-exhausted':
        return 'Muitas tentativas. Aguarde um momento.';
      case 'already-exists':
        return 'Este código já foi utilizado.';
      case 'failed-precondition':
        return 'Serviço indisponível. Tente SMS.';
      case 'unauthenticated':
        return 'Sessão expirada. Faça login novamente.';
      case 'permission-denied':
        return 'Sem permissão para esta ação.';
      default:
        return 'Erro inesperado. Tente novamente.';
    }
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phone) {
    // Remove non-digits
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    // Angola/Portugal numbers are typically 9 digits starting with 9
    return digits.length >= 9 && digits.startsWith('9');
  }

  /// Format phone number for display
  String formatPhoneDisplay(String phone, {String countryCode = '+244'}) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length >= 9) {
      // Format as: +244 923 456 789
      return '$countryCode ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }

    return '$countryCode $digits';
  }
}

// ==================== RESULT CLASSES ====================

/// Result from sending OTP
class WhatsAppOTPResult {
  final bool success;
  final String message;
  final int expiresIn;
  final Object? error;

  WhatsAppOTPResult({
    required this.success,
    required this.message,
    this.expiresIn = 300,
    this.error,
  });
}

/// Result from verifying OTP
class WhatsAppVerifyResult {
  final bool success;
  final String message;
  final UserCredential? userCredential;
  final String? userId;
  final bool isNewUser;
  final Object? error;

  WhatsAppVerifyResult({
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
