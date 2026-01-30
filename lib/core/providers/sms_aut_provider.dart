import 'dart:async';

import 'package:boda_connect/core/services/sms_auth_service.dart';
import 'package:boda_connect/core/services/rate_limiter_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SMS Auth Service Provider
final smsAuthServiceProvider = Provider<SmsAuthService>((ref) {
  return SmsAuthService();
});

/// SMS Auth State
class SmsAuthState {
  final bool isLoading;
  final bool codeSent;
  final bool isVerifying;
  final bool autoVerified;
  final String? error;
  final String? verificationId;
  final int? resendToken;
  final int? resendCooldown;
  final PhoneAuthCredential? autoCredential;

  const SmsAuthState({
    this.isLoading = false,
    this.codeSent = false,
    this.isVerifying = false,
    this.autoVerified = false,
    this.error,
    this.verificationId,
    this.resendToken,
    this.resendCooldown,
    this.autoCredential,
  });

  SmsAuthState copyWith({
    bool? isLoading,
    bool? codeSent,
    bool? isVerifying,
    bool? autoVerified,
    String? error,
    String? verificationId,
    int? resendToken,
    int? resendCooldown,
    PhoneAuthCredential? autoCredential,
  }) {
    return SmsAuthState(
      isLoading: isLoading ?? this.isLoading,
      codeSent: codeSent ?? this.codeSent,
      isVerifying: isVerifying ?? this.isVerifying,
      autoVerified: autoVerified ?? this.autoVerified,
      error: error,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      autoCredential: autoCredential ?? this.autoCredential,
    );
  }
}

/// SMS Auth Notifier
class SmsAuthNotifier extends StateNotifier<SmsAuthState> {
  final SmsAuthService _authService;
  final RateLimiterService _rateLimiter = RateLimiterService();
  Timer? _resendTimer;

  SmsAuthNotifier(this._authService) : super(const SmsAuthState());

  /// Send OTP via SMS
  Future<bool> sendOTP({
    required String phone,
    String countryCode = '+244',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final rateLimit = await _rateLimiter.checkRateLimit(
      identifier: phone,
      type: RateLimitType.otpRequest,
    );
    if (!rateLimit.allowed) {
      state = state.copyWith(
        isLoading: false,
        error: rateLimit.reason ?? 'Too many attempts',
      );
      return false;
    }

    final completer = Completer<bool>();

    await _authService.sendOTP(
      phone: phone,
      countryCode: countryCode,
      onCodeSent: (verificationId, resendToken) {
        state = state.copyWith(
          isLoading: false,
          codeSent: true,
          verificationId: verificationId,
          resendToken: resendToken,
          resendCooldown: 60,
        );
        _startResendTimer();
        if (!completer.isCompleted) completer.complete(true);
      },
      onVerificationCompleted: (credential) {
        // Auto-verification on Android
        state = state.copyWith(
          isLoading: false,
          autoVerified: true,
          autoCredential: credential,
        );
        if (!completer.isCompleted) completer.complete(true);
      },
      onVerificationFailed: (error) {
        state = state.copyWith(
          isLoading: false,
          error: _getErrorMessage(error.code),
        );
        if (!completer.isCompleted) completer.complete(false);
      },
      forceResendingToken: state.resendToken,
    );

    return completer.future;
  }

  /// Verify OTP and sign in
  Future<SmsVerifyResult> verifyOTP({
    required String otp,
  }) async {
    state = state.copyWith(isVerifying: true, error: null);

    final identifier = state.verificationId ?? otp;
    final rateLimit = await _rateLimiter.checkRateLimit(
      identifier: identifier,
      type: RateLimitType.otpVerify,
    );
    if (!rateLimit.allowed) {
      final message = rateLimit.reason ?? 'Too many attempts';
      state = state.copyWith(isVerifying: false, error: message);
      return SmsVerifyResult(success: false, message: message);
    }

    final result = await _authService.verifyOTP(
      otp: otp,
      verificationId: state.verificationId,
    );

    if (result.success) {
      state = state.copyWith(isVerifying: false);
      _rateLimiter.clearRateLimit(
        identifier: identifier,
        type: RateLimitType.otpVerify,
      );
      _cancelTimers();
    } else {
      state = state.copyWith(
        isVerifying: false,
        error: result.message,
      );
    }

    return result;
  }

  /// Sign in with auto-verified credential
  Future<SmsVerifyResult> signInWithAutoCredential() async {
    if (state.autoCredential == null) {
      return SmsVerifyResult(
        success: false,
        message: 'Nenhuma credencial automática disponível.',
      );
    }

    state = state.copyWith(isVerifying: true, error: null);

    final result = await _authService.signInWithCredential(
      state.autoCredential!,
    );

    state = state.copyWith(isVerifying: false);
    if (result.success) {
      _cancelTimers();
    }

    return result;
  }

  /// Resend OTP
  Future<bool> resendOTP({
    required String phone,
    String countryCode = '+244',
  }) async {
    if (state.resendCooldown != null && state.resendCooldown! > 0) {
      return false;
    }

    return sendOTP(phone: phone, countryCode: countryCode);
  }

  /// Reset state
  void reset() {
    _cancelTimers();
    _authService.clearVerificationData();
    state = const SmsAuthState();
  }

  /// Start resend cooldown timer
  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.resendCooldown ?? 0;
      if (current > 0) {
        state = state.copyWith(resendCooldown: current - 1);
      } else {
        timer.cancel();
      }
    });
  }

  /// Cancel all timers
  void _cancelTimers() {
    _resendTimer?.cancel();
  }

  /// Get error message from code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Número de telefone inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'quota-exceeded':
        return 'Limite de SMS excedido. Tente WhatsApp.';
      default:
        return 'Erro ao enviar SMS. Tente WhatsApp.';
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

/// SMS Auth Provider
final smsAuthProvider =
    StateNotifierProvider<SmsAuthNotifier, SmsAuthState>((ref) {
  final authService = ref.watch(smsAuthServiceProvider);
  return SmsAuthNotifier(authService);
});
