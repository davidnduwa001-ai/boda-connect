import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/models/user_model.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/services/auth_service.dart';
import 'package:boda_connect/core/services/presence_service.dart';
import 'package:boda_connect/core/services/security_service.dart';
import 'package:boda_connect/core/services/rate_limiter_service.dart';
import 'package:boda_connect/core/services/user_cache_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ==================== SERVICE PROVIDERS ====================

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ==================== AUTH STATE ====================

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {

  const AuthState({
    this.status = AuthStatus.initial,
    this.firebaseUser,
    this.user,
    this.userType,
    this.error,
    this.verificationId,
    this.resendToken,
  });
  final AuthStatus status;
  final User? firebaseUser;
  final UserModel? user;
  final UserType? userType;
  final String? error;
  final String? verificationId;
  final int? resendToken;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isSupplier => userType == UserType.supplier;
  bool get isClient => userType == UserType.client;

  AuthState copyWith({
    AuthStatus? status,
    User? firebaseUser,
    UserModel? user,
    UserType? userType,
    String? error,
    String? verificationId,
    int? resendToken,
  }) {
    return AuthState(
      status: status ?? this.status,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      user: user ?? this.user,
      userType: userType ?? this.userType,
      error: error ?? this.error,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
    );
  }

  AuthState clearError() {
    return copyWith();
  }
}

// ==================== AUTH NOTIFIER ====================

class AuthNotifier extends StateNotifier<AuthState> {

  AuthNotifier(this._authService) : super(const AuthState()) {
    _init();
  }
  final AuthService _authService;
  final PresenceService _presenceService = PresenceService();
  final UserCacheService _cacheService = UserCacheService();
  StreamSubscription<User?>? _authSubscription;

  void _init() {
    // Initialize cache service
    _cacheService.initialize();
    // Load cached user immediately for faster startup
    _loadCachedUser();
    // Listen to auth state changes
    _authSubscription =
        _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  /// Load cached user data for instant UI while fetching fresh data
  Future<void> _loadCachedUser() async {
    try {
      final cachedUser = await _cacheService.getCachedUser();
      final cachedUserType = await _cacheService.getCachedUserType();

      if (cachedUser != null) {
        debugPrint('📦 Loaded cached user: ${cachedUser.uid}');
        // Only update state if we're still in initial state
        if (state.status == AuthStatus.initial) {
          state = state.copyWith(
            user: cachedUser,
            userType: cachedUserType,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading cached user: $e');
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      // Clear cache on logout
      await _cacheService.clearUserCache();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } else {
      state = state.copyWith(
        status: AuthStatus.loading,
        firebaseUser: firebaseUser,
      );

      // Get user data from Firestore
      final user = await _authService.getUser(firebaseUser.uid);

      if (user != null) {
        // Cache user data for persistence
        await _cacheService.cacheUser(user);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          userType: user.userType,
        );

        // Start presence tracking
        _presenceService.startTracking(firebaseUser.uid);

        // Check if user is suspended - handle in UI layer via routing
        // The router will check user.isActive and redirect to suspension screen
      } else {
        // User exists in Firebase Auth but not in Firestore
        // This means registration is incomplete
        state = state.copyWith(
          status: AuthStatus.authenticated,
        );
      }
    }
  }

  // ==================== PHONE AUTHENTICATION ====================

  /// Send OTP to phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required UserType? userType,
    required bool isLogin,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final formattedPhone = _authService.formatPhoneNumberAO(phoneNumber);

      // Check rate limit before sending OTP
      final rateLimiter = RateLimiterService();
      final rateCheck = await rateLimiter.checkRateLimit(
        identifier: formattedPhone,
        type: RateLimitType.otpRequest,
      );

      if (!rateCheck.allowed) {
        state = state.copyWith(
          status: AuthStatus.error,
          error: rateCheck.reason ?? 'Demasiadas tentativas. Aguarde alguns minutos.',
        );
        return;
      }

      await _authService.sendOTP(
        phoneNumber: formattedPhone,
        onVerificationCompleted: (credential) async {
          // Auto-verification (Android only)
          await _signInWithCredential(credential, userType, isLogin);
        },
        onVerificationFailed: (e) {
          state = state.copyWith(
            status: AuthStatus.error,
            error: AuthException.fromFirebase(e).message,
          );
        },
        onCodeSent: (verificationId, resendToken) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            verificationId: verificationId,
            resendToken: resendToken,
            userType: userType,
          );
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
        forceResendingToken: state.resendToken,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Verify OTP code
  Future<bool> verifyOTP({
    required String smsCode,
    required bool isLogin,
    String? phoneNumber,
  }) async {
    if (state.verificationId == null) {
      state = state.copyWith(error: 'Sessão expirada. Solicite novo código.');
      return false;
    }

    // Check rate limit for OTP verification
    final rateLimiter = RateLimiterService();
    final identifier = phoneNumber ?? state.verificationId!;
    final rateCheck = await rateLimiter.checkRateLimit(
      identifier: identifier,
      type: RateLimitType.otpVerify,
    );

    if (!rateCheck.allowed) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: rateCheck.reason ?? 'Demasiadas tentativas. Aguarde alguns minutos.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading);

    try {
      final credential = await _authService.verifyOTP(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );

      final success = await _handleAuthSuccess(credential, state.userType, isLogin);

      // Clear rate limit on successful verification
      if (success) {
        rateLimiter.clearRateLimit(
          identifier: identifier,
          type: RateLimitType.otpVerify,
        );
        rateLimiter.clearRateLimit(
          identifier: identifier,
          type: RateLimitType.otpRequest,
        );
      }

      return success;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: AuthException.fromFirebase(e).message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Erro ao verificar código',
      );
      return false;
    }
  }

  /// Sign in with credential (auto-verification)
  Future<void> _signInWithCredential(
    PhoneAuthCredential credential,
    UserType? userType,
    bool isLogin,
  ) async {
    try {
      final userCredential =
          await _authService.signInWithCredential(credential);
      await _handleAuthSuccess(userCredential, userType, isLogin);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Erro na verificação automática',
      );
    }
  }

  /// Handle successful authentication
  Future<bool> _handleAuthSuccess(
    UserCredential credential,
    UserType? userType,
    bool isLogin,
  ) async {
    final user = credential.user;
    if (user == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Erro ao autenticar',
      );
      return false;
    }

    // Check if user exists in Firestore
    final exists = await _authService.userExists(user.uid);

    if (isLogin) {
      // Login flow
      if (!exists) {
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Conta não encontrada. Por favor, crie uma conta.',
        );
        await _authService.signOut();
        return false;
      }
      // User data will be loaded by _onAuthStateChanged
      return true;
    } else {
      // Registration flow
      if (exists) {
        // User already exists, just authenticate
        return true;
      }

      // Create new user in Firestore
      if (userType == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Tipo de utilizador não especificado',
        );
        return false;
      }

      try {
        await _authService.createUser(
          uid: user.uid,
          phone: user.phoneNumber ?? '',
          userType: userType,
        );

        state = state.copyWith(userType: userType);
        return true;
      } on AuthException catch (e) {
        // Handle duplicate account error
        state = state.copyWith(
          status: AuthStatus.error,
          error: e.message,
        );
        await _authService.signOut();
        return false;
      } catch (e) {
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Erro ao criar conta',
        );
        await _authService.signOut();
        return false;
      }
    }
  }

  // ==================== USER MANAGEMENT ====================

  /// Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? email,
    String? photoUrl,
  }) async {
    if (state.firebaseUser == null) return;

    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _authService.updateUser(state.firebaseUser!.uid, {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      final updatedUser = await _authService.getUser(state.firebaseUser!.uid);

      // Update cache with new data
      if (updatedUser != null) {
        await _cacheService.cacheUser(updatedUser);
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: updatedUser,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        error: 'Erro ao atualizar perfil',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // Stop presence tracking before signing out
    await _presenceService.stopTracking();
    try {
      final securityService = SecurityService();
      final sessionId = securityService.currentSessionId;
      if (sessionId != null) {
        await securityService.terminateSession(
          sessionId: sessionId,
          reason: 'user_logout',
        );
      }
    } catch (e) {
      debugPrint('Error terminating session: $e');
    }
    // Clear cached user data
    await _cacheService.clearAll();
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
  }

  /// Refresh user data from Firestore
  /// Call this after updating user data directly in Firestore
  Future<void> refreshUser() async {
    if (state.firebaseUser == null) return;

    try {
      final user = await _authService.getUser(state.firebaseUser!.uid);
      if (user != null) {
        // Update cache with fresh data
        await _cacheService.cacheUser(user);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          userType: user.userType,
        );
      }
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// ==================== PROVIDERS ====================

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final currentUserTypeProvider = Provider<UserType?>((ref) {
  return ref.watch(authProvider).userType;
});

final isSupplierProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isSupplier;
});

// ==================== USER NAME LOOKUP ====================

/// Cache for user names to avoid repeated Firestore calls
final _userNameCache = <String, String>{};

/// Provider to fetch a user's display name by their ID
/// Useful for displaying names in bookings when clientName is null
final userNameByIdProvider = FutureProvider.family<String, String>((ref, userId) async {
  // Return from cache if available
  if (_userNameCache.containsKey(userId)) {
    return _userNameCache[userId]!;
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      final name = data?['displayName'] as String? ??
          data?['name'] as String? ??
          'Cliente';
      _userNameCache[userId] = name;
      return name;
    }
  } catch (e) {
    debugPrint('Error fetching user name for $userId: $e');
  }

  return 'Cliente';
});
