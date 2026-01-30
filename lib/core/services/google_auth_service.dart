import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:boda_connect/core/models/user_type.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '801918014868-fdf41g41nmesmpktrebm8lg6rccebmncc.apps.googleusercontent.com'
        : null,
  );

  /// Sign in with Google
  /// [userType] - Whether user is registering as client or supplier
  /// Returns [GoogleAuthResult] with success status
  Future<GoogleAuthResult> signInWithGoogle({required UserType userType}) async {
    try {
      // Sign out first to force account picker to show
      await _googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return GoogleAuthResult(
          success: false,
          message: 'Login cancelado',
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        return GoogleAuthResult(
          success: false,
          message: 'Erro ao autenticar com Google',
        );
      }

      // ALWAYS check Firestore for user document existence
      // Firebase Auth isNewUser flag can be false even when Firestore doc doesn't exist
      // (e.g., when same email signs in again after account deletion)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final bool userExistsInFirestore = userDoc.exists;
      final now = Timestamp.now();
      bool isNewUser = false;

      if (!userExistsInFirestore) {
        // Create user document in Firestore with proper structure
        await _firestore.collection('users').doc(user.uid).set({
          'phone': user.phoneNumber ?? '',  // May be empty, will be filled in details screen
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'userType': userType.name,
          'location': null,
          'createdAt': now,
          'updatedAt': now,
          'isActive': true,
          'fcmToken': null,
          'preferences': null,
          'rating': 5.0,
        });

        debugPrint('✅ User document created in Firestore: ${user.uid}');
        isNewUser = true;
      } else {
        // User exists in Firestore - check if userType matches and account is active
        final existingData = userDoc.data() as Map<String, dynamic>;
        final existingUserType = existingData['userType'] as String?;
        final isActive = existingData['isActive'] as bool? ?? true;

        // Check if account was disabled/suspended
        if (!isActive) {
          debugPrint('⚠️ User ${user.uid} account is disabled');
          await _auth.signOut();
          await _googleSignIn.signOut();
          return GoogleAuthResult(
            success: false,
            message: 'Esta conta foi desativada. Entre em contacto com o suporte.',
          );
        }

        if (existingUserType != userType.name) {
          // User exists with different userType
          debugPrint('⚠️ User ${user.uid} exists as $existingUserType but trying to register as ${userType.name}');
          await _auth.signOut();
          await _googleSignIn.signOut();
          return GoogleAuthResult(
            success: false,
            message: 'Esta conta já está registada como $existingUserType. Use outra conta do Google ou faça login como $existingUserType.',
          );
        }

        debugPrint('✅ Existing user signed in with Google: ${user.uid}');
      }

      // For supplier userType, ALWAYS check if supplier profile exists
      if (userType == UserType.supplier) {
        final supplierQuery = await _firestore
            .collection('suppliers')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (supplierQuery.docs.isEmpty) {
          // User exists but supplier profile doesn't - create it
          final supplierRef = await _firestore.collection('suppliers').add({
            'userId': user.uid,  // Link to user document
            'businessName': user.displayName ?? '',
            'category': '',
            'subcategories': [],
            'description': '',
            'phone': user.phoneNumber ?? '',
            'email': user.email ?? '',
            'website': null,
            'socialLinks': null,
            'location': {
              'address': '',
              'city': '',
              'province': '',
              'country': 'Angola',
              'geopoint': null,
            },
            'photos': [],
            'portfolioPhotos': [],
            'videos': [],
            'rating': 5.0,  // Must be 5.0 on creation per security rules
            'reviewCount': 0,
            'completedBookings': 0,
            'isVerified': false,
            'isActive': true,
            'isFeatured': false,
            'responseRate': 0.0,
            'responseTime': null,
            'languages': ['pt'],
            'workingHours': null,
            'createdAt': now,
            'updatedAt': now,
          });
          debugPrint('✅ Supplier profile created with ID: ${supplierRef.id} for user: ${user.uid}');
        } else {
          debugPrint('✅ Supplier profile already exists: ${supplierQuery.docs.first.id}');
        }
      }

      if (isNewUser) {
        debugPrint('✅ New user registered with Google: ${user.uid}');
      }

      return GoogleAuthResult(
        success: true,
        message: isNewUser ? 'Conta criada com sucesso!' : 'Login realizado com sucesso!',
        user: user,
        userId: user.uid,
        isNewUser: isNewUser,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Google sign in error: ${e.code}');
      return GoogleAuthResult(
        success: false,
        message: _getErrorMessage(e.code),
        error: e,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Google sign in error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return GoogleAuthResult(
        success: false,
        message: 'Erro inesperado: $e. Tente novamente.',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Get user-friendly error message from Firebase error code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'Já existe uma conta com este email usando outro método de login.';
      case 'invalid-credential':
        return 'Credenciais inválidas.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet.';
      default:
        debugPrint('❌ Unknown Firebase error code: $code');
        return 'Erro inesperado: $code. Tente novamente.';
    }
  }
}

// ==================== RESULT CLASS ====================

class GoogleAuthResult {
  final bool success;
  final String message;
  final User? user;
  final String? userId;
  final bool isNewUser;
  final Exception? error;

  GoogleAuthResult({
    required this.success,
    required this.message,
    this.user,
    this.userId,
    this.isNewUser = false,
    this.error,
  });
}
