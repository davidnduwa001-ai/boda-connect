import 'dart:async';

import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/services/email_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Email Auth Service Provider
final emailAuthServiceProvider = Provider<EmailAuthService>((ref) {
  return EmailAuthService();
});

/// Email Auth State
class EmailAuthState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final String? successMessage;
  final bool requiresVerification;
  final bool isEmailVerified;

  const EmailAuthState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.successMessage,
    this.requiresVerification = false,
    this.isEmailVerified = false,
  });

  EmailAuthState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    String? successMessage,
    bool? requiresVerification,
    bool? isEmailVerified,
  }) {
    return EmailAuthState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      successMessage: successMessage,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}

/// Email Auth Notifier
class EmailAuthNotifier extends StateNotifier<EmailAuthState> {
  final EmailAuthService _authService;
  Timer? _verificationCheckTimer;

  EmailAuthNotifier(this._authService) : super(const EmailAuthState());

  /// Sign up with email
  Future<EmailAuthResult> signUp({
    required String email,
    required String password,
    required String name,
    required UserType userType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.signUp(
      email: email,
      password: password,
      name: name,
      userType: userType,
    );

    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: result.message,
        requiresVerification: result.requiresVerification,
      );
      
      // Start checking for email verification
      if (result.requiresVerification) {
        _startVerificationCheck();
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.message,
      );
    }

    return result;
  }

  /// Sign in with email
  Future<EmailAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.signIn(
      email: email,
      password: password,
    );

    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: result.message,
        requiresVerification: result.requiresVerification,
        isEmailVerified: !result.requiresVerification,
      );

      // Start checking for email verification if needed
      if (result.requiresVerification) {
        _startVerificationCheck();
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.message,
      );
    }

    return result;
  }

  /// Send password reset email
  Future<bool> sendPasswordReset({required String email}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.sendPasswordResetEmail(email: email);

    state = state.copyWith(
      isLoading: false,
      isSuccess: result.success,
      successMessage: result.success ? result.message : null,
      error: result.success ? null : result.message,
    );

    return result.success;
  }

  /// Resend verification email
  Future<bool> resendVerificationEmail() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.resendVerificationEmail();

    state = state.copyWith(
      isLoading: false,
      successMessage: result.success ? result.message : null,
      error: result.success ? null : result.message,
    );

    return result.success;
  }

  /// Check email verification status
  Future<bool> checkEmailVerified() async {
    final verified = await _authService.checkEmailVerified();
    
    if (verified) {
      _cancelVerificationCheck();
      state = state.copyWith(
        isEmailVerified: true,
        requiresVerification: false,
      );
    }

    return verified;
  }

  /// Update password
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    state = state.copyWith(
      isLoading: false,
      isSuccess: result.success,
      successMessage: result.success ? result.message : null,
      error: result.success ? null : result.message,
    );

    return result.success;
  }

  /// Sign out
  Future<void> signOut() async {
    _cancelVerificationCheck();
    await _authService.signOut();
    state = const EmailAuthState();
  }

  /// Start periodic check for email verification
  void _startVerificationCheck() {
    _cancelVerificationCheck();
    _verificationCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkEmailVerified(),
    );
  }

  /// Cancel verification check timer
  void _cancelVerificationCheck() {
    _verificationCheckTimer?.cancel();
    _verificationCheckTimer = null;
  }

  /// Reset state
  void reset() {
    _cancelVerificationCheck();
    state = const EmailAuthState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear success message
  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  @override
  void dispose() {
    _cancelVerificationCheck();
    super.dispose();
  }
}

/// Email Auth Provider
final emailAuthProvider =
    StateNotifierProvider<EmailAuthNotifier, EmailAuthState>((ref) {
  final authService = ref.watch(emailAuthServiceProvider);
  return EmailAuthNotifier(authService);
});

/// Current user stream provider
final emailAuthUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(emailAuthServiceProvider);
  return authService.authStateChanges;
});