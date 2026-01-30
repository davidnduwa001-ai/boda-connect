import 'dart:async';

import 'package:boda_connect/core/services/whatsapp_auth_service.dart';
import 'package:boda_connect/core/services/rate_limiter_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WhatsApp Auth Service Provider
final whatsAppAuthServiceProvider = Provider<WhatsAppAuthService>((ref) {
  return WhatsAppAuthService();
});

/// WhatsApp Auth State Provider
final whatsAppAuthStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(whatsAppAuthServiceProvider);
  return authService.authStateChanges;
});

/// WhatsApp OTP State
class WhatsAppOTPState {
  final bool isLoading;
  final bool otpSent;
  final bool isVerifying;
  final String? error;
  final int? expiresIn;
  final int? resendCooldown;

  const WhatsAppOTPState({
    this.isLoading = false,
    this.otpSent = false,
    this.isVerifying = false,
    this.error,
    this.expiresIn,
    this.resendCooldown,
  });

  WhatsAppOTPState copyWith({
    bool? isLoading,
    bool? otpSent,
    bool? isVerifying,
    String? error,
    int? expiresIn,
    int? resendCooldown,
  }) {
    return WhatsAppOTPState(
      isLoading: isLoading ?? this.isLoading,
      otpSent: otpSent ?? this.otpSent,
      isVerifying: isVerifying ?? this.isVerifying,
      error: error,
      expiresIn: expiresIn ?? this.expiresIn,
      resendCooldown: resendCooldown ?? this.resendCooldown,
    );
  }
}

/// WhatsApp OTP Notifier
class WhatsAppOTPNotifier extends StateNotifier<WhatsAppOTPState> {
  final WhatsAppAuthService _authService;
  final RateLimiterService _rateLimiter = RateLimiterService();
  Timer? _resendTimer;
  Timer? _expiryTimer;

  WhatsAppOTPNotifier(this._authService) : super(const WhatsAppOTPState());

  /// Send OTP via WhatsApp
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

    final result = await _authService.sendOTP(
      phone: phone,
      countryCode: countryCode,
    );

    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        expiresIn: result.expiresIn,
        resendCooldown: 60,
      );

      // Start resend cooldown timer
      _startResendTimer();
      
      // Start expiry timer
      _startExpiryTimer(result.expiresIn);

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.message,
      );
      return false;
    }
  }

  /// Verify OTP and sign in
  Future<WhatsAppVerifyResult> verifyOTP({
    required String phone,
    required String otp,
    String countryCode = '+244',
  }) async {
    state = state.copyWith(isVerifying: true, error: null);

    final rateLimit = await _rateLimiter.checkRateLimit(
      identifier: phone,
      type: RateLimitType.otpVerify,
    );
    if (!rateLimit.allowed) {
      final message = rateLimit.reason ?? 'Too many attempts';
      state = state.copyWith(isVerifying: false, error: message);
      return WhatsAppVerifyResult(success: false, message: message);
    }

    final result = await _authService.verifyOTP(
      phone: phone,
      otp: otp,
      countryCode: countryCode,
    );

    if (result.success) {
      state = state.copyWith(isVerifying: false);
      _rateLimiter.clearRateLimit(
        identifier: phone,
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
    state = const WhatsAppOTPState();
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

  /// Start expiry timer
  void _startExpiryTimer(int seconds) {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.expiresIn ?? 0;
      if (current > 0) {
        state = state.copyWith(expiresIn: current - 1);
      } else {
        timer.cancel();
        state = state.copyWith(
          error: 'Código expirado. Solicite um novo.',
          otpSent: false,
        );
      }
    });
  }

  /// Cancel all timers
  void _cancelTimers() {
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

/// WhatsApp OTP Provider
final whatsAppOTPProvider =
    StateNotifierProvider<WhatsAppOTPNotifier, WhatsAppOTPState>((ref) {
  final authService = ref.watch(whatsAppAuthServiceProvider);
  return WhatsAppOTPNotifier(authService);
});
