import 'package:boda_connect/core/models/user_model.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/utils/phone_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // ==================== PHONE AUTHENTICATION ====================

  /// Send OTP to phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify OTP and sign in
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign in with phone credential (auto-verification)
  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return _auth.signInWithCredential(credential);
  }

  // ==================== USER MANAGEMENT ====================

  /// Check if user exists in Firestore
  Future<bool> userExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  /// Get user type from Firestore
  Future<UserType?> getUserType(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    final userTypeStr = data?['userType'] as String?;
    if (userTypeStr == null) return null;

    return UserType.values.firstWhere(
      (e) => e.name == userTypeStr,
      orElse: () => UserType.client,
    );
  }

  /// Check if phone number is already registered
  Future<bool> isPhoneNumberRegistered(String phone) async {
    final snapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    if (email.isEmpty) return false;
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Check if phone or email is already registered and return existing user type
  Future<Map<String, dynamic>?> checkExistingAccount({
    required String phone,
    String? email,
  }) async {
    // Check phone number
    final phoneSnapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (phoneSnapshot.docs.isNotEmpty) {
      final existingUser = phoneSnapshot.docs.first.data();
      return {
        'exists': true,
        'field': 'phone',
        'userType': existingUser['userType'],
        'userId': phoneSnapshot.docs.first.id,
      };
    }

    // Check email if provided
    if (email != null && email.isNotEmpty) {
      final emailSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailSnapshot.docs.isNotEmpty) {
        final existingUser = emailSnapshot.docs.first.data();
        return {
          'exists': true,
          'field': 'email',
          'userType': existingUser['userType'],
          'userId': emailSnapshot.docs.first.id,
        };
      }
    }

    return null; // No existing account found
  }

  /// Create new user in Firestore
  Future<void> createUser({
    required String uid,
    required String phone,
    required UserType userType,
    String? name,
    String? email,
  }) async {
    // Check for existing account with same phone or email
    final existingAccount = await checkExistingAccount(
      phone: phone,
      email: email,
    );

    if (existingAccount != null) {
      final field = existingAccount['field'] as String;
      final existingUserType = existingAccount['userType'] as String;

      throw AuthException(
        'account-already-exists',
        field == 'phone'
            ? 'Este número já está registado como $existingUserType'
            : 'Este email já está registado como $existingUserType',
      );
    }

    final now = DateTime.now();
    final user = UserModel(
      uid: uid,
      phone: phone,
      name: name,
      email: email,
      userType: userType,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('users').doc(uid).set(user.toFirestore());
  }

  /// Get user data from Firestore
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Update FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    // Skip FCM token storage on Web - Web uses different push notification flow
    if (kIsWeb) return;

    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
      'updatedAt': Timestamp.now(),
    });
  }

  // ==================== SIGN OUT ====================

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Delete user data from Firestore
    await _firestore.collection('users').doc(user.uid).delete();

    // Delete Firebase Auth account
    await user.delete();
  }

  // ==================== HELPERS ====================

  /// Format phone number for Angola (+244)
  String formatPhoneNumberAO(String phone) {
    return PhoneFormatter.formatPhoneNumberAO(phone);
  }

  /// Format phone number for Portugal (+351)
  String formatPhoneNumberPT(String phone) {
    return PhoneFormatter.formatPhoneNumberPT(phone);
  }
}

// ==================== AUTH EXCEPTIONS ====================

class AuthException implements Exception {

  AuthException(this.code, this.message);

  factory AuthException.fromFirebase(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'invalid-phone-number':
        message = 'Número de telefone inválido';
      case 'too-many-requests':
        message = 'Muitas tentativas. Tente novamente mais tarde.';
      case 'invalid-verification-code':
        message = 'Código de verificação inválido';
      case 'session-expired':
        message = 'Sessão expirada. Solicite um novo código.';
      case 'quota-exceeded':
        message = 'Limite de SMS excedido. Tente novamente mais tarde.';
      case 'account-already-exists':
        message = 'Esta conta já existe';
      default:
        message = e.message ?? 'Erro de autenticação';
    }
    return AuthException(e.code, message);
  }
  final String code;
  final String message;

  @override
  String toString() => message;
}
