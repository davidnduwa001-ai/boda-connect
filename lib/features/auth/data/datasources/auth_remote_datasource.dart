import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? firebaseUser() => _auth.currentUser;

  Future<Map<String, dynamic>?> userDoc(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }
}
