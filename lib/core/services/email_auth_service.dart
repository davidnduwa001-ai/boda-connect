import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:boda_connect/core/models/user_type.dart';

/// Email Authentication Service
/// 
/// Provides email/password authentication with:
/// - Sign up with email verification
/// - Sign in
/// - Password reset
/// - Email verification resend
class EmailAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== SIGN UP ====================

  /// Check if email is already registered and get user type
  /// Returns null if email is not registered or if query fails (e.g., not authenticated)
  /// This method gracefully handles permission denied errors since it may be called
  /// before user authentication is complete.
  Future<Map<String, dynamic>?> checkEmailUserType(String email) async {
    if (email.isEmpty) return null;

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final userData = snapshot.docs.first.data();
      return {
        'exists': true,
        'userType': userData['userType'] as String? ?? 'client',
        'userId': snapshot.docs.first.id,
        'isActive': userData['isActive'] as bool? ?? true,
      };
    } catch (e) {
      // If permission denied (user not authenticated yet), return null
      // Firebase Auth will handle duplicate email errors during account creation
      debugPrint('⚠️ checkEmailUserType failed (expected if not authenticated): $e');
      return null;
    }
  }

  /// Create new account with email and password
  ///
  /// [email] - User's email address
  /// [password] - Password (min 6 characters)
  /// [name] - User's display name
  /// [userType] - User type (client or supplier)
  ///
  /// Returns [EmailAuthResult] with success status
  Future<EmailAuthResult> signUp({
    required String email,
    required String password,
    required String name,
    required UserType userType,
  }) async {
    try {
      // Check if email is already registered with a different user type
      final existingCheck = await checkEmailUserType(email.trim());
      if (existingCheck != null) {
        final existingUserType = existingCheck['userType'] as String;
        final isActive = existingCheck['isActive'] as bool;

        // Check if account is deactivated
        if (!isActive) {
          return EmailAuthResult(
            success: false,
            message: 'Esta conta foi desativada. Entre em contacto com o suporte.',
          );
        }

        // Check if trying to register with different user type
        if (existingUserType != userType.name) {
          final userTypeLabel = existingUserType == 'client' ? 'cliente' : 'fornecedor';
          return EmailAuthResult(
            success: false,
            message: 'Este email já está registado como $userTypeLabel. Use outro email ou faça login como $userTypeLabel.',
          );
        }

        // Email already registered with same type - let Firebase handle the error
      }

      // Create user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return EmailAuthResult(
          success: false,
          message: 'Erro ao criar conta. Tente novamente.',
        );
      }

      // Update display name
      await user.updateDisplayName(name);

      // IMPORTANT: Wait for auth token to propagate to Firestore
      // This is needed especially on web where there can be a delay
      debugPrint('⏳ Waiting for auth token to propagate...');
      await user.reload();
      await Future.delayed(const Duration(milliseconds: 500));

      // Get fresh ID token to ensure Firestore can authenticate
      try {
        await user.getIdToken(true);
      } catch (e) {
        debugPrint('⚠️ getIdToken failed (non-critical): $e');
      }

      // Send email verification (but don't require it for testing)
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('⚠️ Email verification send failed: $e');
      }

      // Create user document in Firestore
      debugPrint('📝 Creating user document for: ${user.uid}');
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'email': email.trim(),
          'name': name,
          'userType': userType.name, // Save userType as string (client/supplier)
          'authMethod': 'email',
          'emailVerified': false,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ User document created successfully');
      } catch (e) {
        debugPrint('❌ User document creation failed: $e');
        rethrow;
      }

      // Create supplier profile if user is a supplier
      if (userType == UserType.supplier) {
        debugPrint('📝 Creating supplier profile for: ${user.uid}');
        try {
          await _firestore.collection('suppliers').doc(user.uid).set({
            'userId': user.uid,
            'businessName': name, // Use name as initial business name
            'email': email.trim(),
            'category': '', // Will be set during onboarding
            'subcategories': [], // Will be set during onboarding
            'description': '',
            'phone': '',
            'location': {
              'address': '',
              'city': '',
              'province': '',
              'latitude': 0.0,
              'longitude': 0.0,
            },
            'photos': [],
            'portfolioPhotos': [],
            'videos': [],
            'languages': ['pt'], // Default to Portuguese
            'rating': 5.0, // Start with perfect rating (security rule requirement)
            'reviewCount': 0,
            'responseRate': 0.0,
            'isFeatured': false,
            // Stats fields NOT set - managed by Cloud Functions: viewCount, leadCount, favoriteCount, confirmedBookings, completedBookings, totalBookings
            'isVerified': false,
            'isActive': true,
            'priceRange': '',
            'services': [],
            'workingHours': {},
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ Supplier profile created successfully');
        } catch (e) {
          debugPrint('❌ Supplier profile creation failed: $e');
          rethrow;
        }
      }

      debugPrint('✅ Email sign up successful: ${user.uid}');

      return EmailAuthResult(
        success: true,
        message: 'Conta criada com sucesso!',
        user: user,
        userId: user.uid,
        isNewUser: true,
        requiresVerification: false, // Skip verification for testing
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Email sign up error: ${e.code}');
      return EmailAuthResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Email sign up error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return EmailAuthResult(
        success: false,
        message: 'Erro inesperado. Tente novamente. ($e)',
      );
    }
  }

  // ==================== SIGN IN ====================

  /// Sign in with email and password
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// 
  /// Returns [EmailAuthResult] with success status
  Future<EmailAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return EmailAuthResult(
          success: false,
          message: 'Erro ao entrar. Tente novamente.',
        );
      }

      // Update last login
      await _firestore.collection('users').doc(user.uid).update({
        'updatedAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
      });

      debugPrint('✅ Email sign in successful: ${user.uid}');

      return EmailAuthResult(
        success: true,
        message: 'Login realizado com sucesso!',
        user: user,
        userId: user.uid,
        isNewUser: false,
        requiresVerification: false, // Skip verification for testing
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Email sign in error: ${e.code}');
      return EmailAuthResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e) {
      // Check if user is actually signed in despite the error
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email == email.trim()) {
        debugPrint('✅ Email sign in successful (despite error): ${currentUser.uid}');
        return EmailAuthResult(
          success: true,
          message: 'Login realizado com sucesso!',
          user: currentUser,
          userId: currentUser.uid,
          isNewUser: false,
          requiresVerification: false,
        );
      }

      debugPrint('❌ Email sign in error: $e');
      return EmailAuthResult(
        success: false,
        message: 'Erro inesperado. Tente novamente.',
      );
    }
  }

  // ==================== PASSWORD RESET ====================

  /// Send password reset email
  /// 
  /// [email] - User's email address
  Future<EmailAuthResult> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());

      debugPrint('✅ Password reset email sent to: $email');

      return EmailAuthResult(
        success: true,
        message: 'Email de recuperação enviado!',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Password reset error: ${e.code}');
      return EmailAuthResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      return EmailAuthResult(
        success: false,
        message: 'Erro ao enviar email. Tente novamente.',
      );
    }
  }

  // ==================== EMAIL VERIFICATION ====================

  /// Resend email verification
  Future<EmailAuthResult> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return EmailAuthResult(
          success: false,
          message: 'Nenhum usuário logado.',
        );
      }

      if (user.emailVerified) {
        return EmailAuthResult(
          success: true,
          message: 'Email já verificado!',
        );
      }

      await user.sendEmailVerification();

      debugPrint('✅ Verification email resent');

      return EmailAuthResult(
        success: true,
        message: 'Email de verificação reenviado!',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Resend verification error: ${e.code}');
      return EmailAuthResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e) {
      debugPrint('❌ Resend verification error: $e');
      return EmailAuthResult(
        success: false,
        message: 'Erro ao reenviar email. Tente novamente.',
      );
    }
  }

  /// Check if email is verified (refresh user)
  Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;

      if (verified) {
        // Update Firestore
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({'emailVerified': true});
      }

      return verified;
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return false;
    }
  }

  // ==================== SIGN OUT ====================

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
    debugPrint('✅ User signed out');
  }

  // ==================== PASSWORD MANAGEMENT ====================

  /// Update password
  /// 
  /// [currentPassword] - Current password for re-authentication
  /// [newPassword] - New password
  Future<EmailAuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return EmailAuthResult(
          success: false,
          message: 'Nenhum usuário logado.',
        );
      }

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      debugPrint('✅ Password updated');

      return EmailAuthResult(
        success: true,
        message: 'Senha atualizada com sucesso!',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Update password error: ${e.code}');
      return EmailAuthResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e) {
      debugPrint('❌ Update password error: $e');
      return EmailAuthResult(
        success: false,
        message: 'Erro ao atualizar senha. Tente novamente.',
      );
    }
  }

  // ==================== HELPERS ====================

  /// Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate password strength
  PasswordStrength checkPasswordStrength(String password) {
    if (password.length < 6) {
      return PasswordStrength.weak;
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// Get user-friendly error message from Firebase error code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este email já está em uso.';
      case 'invalid-email':
        return 'Email inválido.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'operation-not-allowed':
        return 'Login por email não está habilitado.';
      case 'invalid-credential':
        return 'Email ou senha incorretos.';
      case 'requires-recent-login':
        return 'Por favor, faça login novamente.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet.';
      default:
        debugPrint('❌ Unknown Firebase error code: $code');
        return 'Erro inesperado: $code. Tente novamente.';
    }
  }
}

// ==================== RESULT CLASS ====================

/// Result from email authentication operations
class EmailAuthResult {
  final bool success;
  final String message;
  final User? user;
  final String? userId;
  final bool isNewUser;
  final bool requiresVerification;
  final Object? error;

  EmailAuthResult({
    required this.success,
    required this.message,
    this.user,
    this.userId,
    this.isNewUser = false,
    this.requiresVerification = false,
    this.error,
  });
}

/// Password strength levels
enum PasswordStrength {
  weak,
  medium,
  strong,
}