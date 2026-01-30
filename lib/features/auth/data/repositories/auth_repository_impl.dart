import 'package:boda_connect/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:boda_connect/features/auth/data/models/app_user_model.dart';
import 'package:boda_connect/features/auth/domain/entities/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository for authentication operations
/// This is a standalone implementation that doesn't extend the core AuthRepository
class AuthRepositoryImpl {
  AuthRepositoryImpl(FirebaseAuth auth, FirebaseFirestore db)
      : _auth = auth,
        _ds = AuthRemoteDataSource(auth, db);

  final FirebaseAuth _auth;
  final AuthRemoteDataSource _ds;

  // ==================== AUTH STATE ====================

  /// Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== USER OPERATIONS ====================

  /// Get current app user
  Future<AppUser?> currentUser() async {
    final user = _ds.firebaseUser();
    if (user == null) return null;
    final data = await _ds.userDoc(user.uid) ?? {};
    return AppUserModel.fromMap(data, user.uid);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Check if user exists
  Future<bool> userExists(String uid) async {
    final data = await _ds.userDoc(uid);
    return data != null;
  }

  /// Get user data by ID
  Future<AppUser?> getUser(String uid) async {
    final data = await _ds.userDoc(uid);
    if (data == null) return null;
    return AppUserModel.fromMap(data, uid);
  }
}