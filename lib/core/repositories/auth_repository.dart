import 'package:boda_connect/core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/models/user_model.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  // ==================== AUTH STATE ====================

  /// Get current Firebase user
  User? get currentUser => _authService.currentUser;

  /// Get current user ID
  String? get currentUserId => _authService.currentUserId;

  /// Check if user is logged in
  bool get isLoggedIn => _authService.isLoggedIn;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // ==================== PHONE AUTHENTICATION ====================

  /// Send OTP to phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
    String countryCode = '+244', // Angola default
  }) async {
    final formattedPhone = _formatPhoneNumber(phoneNumber, countryCode);
    
    await _authService.sendOTP(
      phoneNumber: formattedPhone,
      onVerificationCompleted: onVerificationCompleted,
      onVerificationFailed: onVerificationFailed,
      onCodeSent: onCodeSent,
      onCodeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );
  }

  /// Verify OTP and sign in
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    return await _authService.verifyOTP(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  /// Sign in with credential (auto-verification)
  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _authService.signInWithCredential(credential);
  }

  // ==================== USER MANAGEMENT ====================

  /// Check if user exists in Firestore
  Future<bool> userExists(String uid) async {
    return await _authService.userExists(uid);
  }

  /// Get user type
  Future<UserType?> getUserType(String uid) async {
    return await _authService.getUserType(uid);
  }

  /// Create new user in Firestore
  Future<void> createUser({
    required String uid,
    required String phone,
    required UserType userType,
    String? name,
    String? email,
  }) async {
    await _authService.createUser(
      uid: uid,
      phone: phone,
      userType: userType,
      name: name,
      email: email,
    );
  }

  /// Get user data
  Future<UserModel?> getUser(String uid) async {
    return await _authService.getUser(uid);
  }

  /// Get current user data
  Future<UserModel?> getCurrentUser() async {
    if (currentUserId == null) return null;
    return await _authService.getUser(currentUserId!);
  }

  /// Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _authService.updateUser(uid, data);
  }

  /// Update current user's profile
  Future<void> updateCurrentUserProfile({
    String? name,
    String? email,
    String? photoUrl,
    String? city,
    String? province,
  }) async {
    if (currentUserId == null) return;

    final updates = <String, dynamic>{};
    
    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    
    if (city != null || province != null) {
      updates['location'] = {
        if (city != null) 'city': city,
        if (province != null) 'province': province,
        'country': 'Angola',
      };
    }

    await _authService.updateUser(currentUserId!, updates);
  }

  /// Update FCM token
  Future<void> updateFcmToken(String token) async {
    if (currentUserId == null) return;
    await _authService.updateFcmToken(currentUserId!, token);
  }

  // ==================== SIGN OUT ====================

  /// Sign out current user
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
  }

  // ==================== HELPERS ====================

  /// Format phone number with country code
  String _formatPhoneNumber(String phone, String countryCode) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // Remove country code if already present
    if (countryCode == '+244' && digits.startsWith('244')) {
      digits = digits.substring(3);
    } else if (countryCode == '+351' && digits.startsWith('351')) {
      digits = digits.substring(3);
    }
    
    return '$countryCode$digits';
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    // Angola numbers are 9 digits starting with 9
    // Portugal numbers are 9 digits starting with 9
    return digits.length >= 9 && digits.startsWith('9');
  }

  /// Get user-friendly error message
  String getErrorMessage(FirebaseAuthException e) {
    return AuthException.fromFirebase(e).message;
  }
}

// ==================== AUTH EXCEPTION HELPER ====================

class AuthException implements Exception {
  final String code;
  final String message;

  AuthException(this.code, this.message);

  factory AuthException.fromFirebase(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'invalid-phone-number':
        message = 'Número de telefone inválido';
        break;
      case 'too-many-requests':
        message = 'Muitas tentativas. Tente novamente mais tarde.';
        break;
      case 'invalid-verification-code':
        message = 'Código de verificação inválido';
        break;
      case 'session-expired':
        message = 'Sessão expirada. Solicite um novo código.';
        break;
      case 'quota-exceeded':
        message = 'Limite de SMS excedido. Tente novamente mais tarde.';
        break;
      case 'network-request-failed':
        message = 'Erro de conexão. Verifique sua internet.';
        break;
      case 'user-disabled':
        message = 'Esta conta foi desativada.';
        break;
      case 'operation-not-allowed':
        message = 'Operação não permitida.';
        break;
      default:
        message = e.message ?? 'Erro de autenticação';
    }
    return AuthException(e.code, message);
  }

  @override
  String toString() => message;
}