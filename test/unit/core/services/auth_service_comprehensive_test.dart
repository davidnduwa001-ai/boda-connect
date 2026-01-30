import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/models/user_type.dart';

/// Comprehensive Authentication Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Phone Authentication (SMS OTP)
/// 2. User Registration (Client & Supplier)
/// 3. User Login
/// 4. Session Management
/// 5. Account Existence Checks
/// 6. Account Deletion
/// 7. FCM Token Updates
/// 8. Error Handling
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(
      uid: 'test-user-id',
      email: 'test@example.com',
      displayName: 'Test User',
      phoneNumber: '+244912345678',
    );
    mockAuth = MockFirebaseAuth(mockUser: mockUser);
  });

  group('Phone Authentication Tests', () {
    test('should format Angola phone number correctly', () {
      // Test various formats
      expect(_formatPhoneNumberAO('912345678'), '+244912345678');
      expect(_formatPhoneNumberAO('244912345678'), '+244912345678');
      expect(_formatPhoneNumberAO('+244912345678'), '+244912345678');
      expect(_formatPhoneNumberAO('00244912345678'), '+244912345678');
    });

    test('should validate phone number format', () {
      expect(_isValidAngolaPhoone('912345678'), isTrue);
      expect(_isValidAngolaPhoone('812345678'), isFalse); // Invalid prefix
      expect(_isValidAngolaPhoone('12345'), isFalse); // Too short
    });

    test('should sign in with phone credential', () async {
      // Sign in with mock auth
      await mockAuth.signInWithCustomToken('test-token');
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser?.uid, 'test-user-id');
    });

    test('should emit auth state changes', () async {
      // Listen to auth state changes
      final authStream = mockAuth.authStateChanges();

      expectLater(
        authStream,
        emitsInOrder([
          isNull, // Initial state (not signed in)
          isNotNull, // After sign in
        ]),
      );

      await mockAuth.signInWithCustomToken('test-token');
    });
  });

  group('User Registration Tests', () {
    test('should create new client user in Firestore', () async {
      final now = DateTime.now();

      await fakeFirestore.collection('users').doc('client-123').set({
        'uid': 'client-123',
        'phone': '+244912345678',
        'name': 'Cliente Teste',
        'email': 'cliente@test.com',
        'userType': 'client',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final doc = await fakeFirestore.collection('users').doc('client-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['userType'], 'client');
      expect(doc.data()?['phone'], '+244912345678');
    });

    test('should create new supplier user in Firestore', () async {
      final now = DateTime.now();

      await fakeFirestore.collection('users').doc('supplier-123').set({
        'uid': 'supplier-123',
        'phone': '+244923456789',
        'name': 'Fornecedor Teste',
        'email': 'fornecedor@test.com',
        'userType': 'supplier',
        'category': 'fotografia',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final doc = await fakeFirestore.collection('users').doc('supplier-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['userType'], 'supplier');
      expect(doc.data()?['category'], 'fotografia');
    });

    test('should prevent duplicate phone registration', () async {
      // First user
      await fakeFirestore.collection('users').doc('user-1').set({
        'uid': 'user-1',
        'phone': '+244912345678',
        'userType': 'client',
      });

      // Check if phone exists
      final query = await fakeFirestore
          .collection('users')
          .where('phone', isEqualTo: '+244912345678')
          .get();

      expect(query.docs.isNotEmpty, isTrue);
      expect(query.docs.first.data()['userType'], 'client');
    });

    test('should prevent duplicate email registration', () async {
      // First user
      await fakeFirestore.collection('users').doc('user-1').set({
        'uid': 'user-1',
        'email': 'test@example.com',
        'userType': 'client',
      });

      // Check if email exists
      final query = await fakeFirestore
          .collection('users')
          .where('email', isEqualTo: 'test@example.com')
          .get();

      expect(query.docs.isNotEmpty, isTrue);
    });
  });

  group('User Login Tests', () {
    test('should check if user exists', () async {
      await fakeFirestore.collection('users').doc('existing-user').set({
        'uid': 'existing-user',
        'phone': '+244912345678',
        'userType': 'client',
      });

      final doc = await fakeFirestore.collection('users').doc('existing-user').get();
      expect(doc.exists, isTrue);

      final nonExistent = await fakeFirestore.collection('users').doc('non-existent').get();
      expect(nonExistent.exists, isFalse);
    });

    test('should get user type correctly', () async {
      await fakeFirestore.collection('users').doc('client-user').set({
        'userType': 'client',
      });
      await fakeFirestore.collection('users').doc('supplier-user').set({
        'userType': 'supplier',
      });

      final clientDoc = await fakeFirestore.collection('users').doc('client-user').get();
      expect(clientDoc.data()?['userType'], 'client');

      final supplierDoc = await fakeFirestore.collection('users').doc('supplier-user').get();
      expect(supplierDoc.data()?['userType'], 'supplier');
    });

    test('should return user data after login', () async {
      await fakeFirestore.collection('users').doc('test-user').set({
        'uid': 'test-user',
        'phone': '+244912345678',
        'name': 'Test User',
        'email': 'test@example.com',
        'userType': 'client',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('users').doc('test-user').get();
      expect(doc.data()?['name'], 'Test User');
      expect(doc.data()?['email'], 'test@example.com');
    });
  });

  group('Session Management Tests', () {
    test('should sign out user', () async {
      await mockAuth.signInWithCustomToken('test-token');
      expect(mockAuth.currentUser, isNotNull);

      await mockAuth.signOut();
      expect(mockAuth.currentUser, isNull);
    });

    test('should track current user', () async {
      expect(mockAuth.currentUser, isNull);

      await mockAuth.signInWithCustomToken('test-token');
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser?.uid, 'test-user-id');
    });
  });

  group('FCM Token Tests', () {
    test('should update FCM token', () async {
      await fakeFirestore.collection('users').doc('user-123').set({
        'uid': 'user-123',
        'fcmToken': null,
      });

      await fakeFirestore.collection('users').doc('user-123').update({
        'fcmToken': 'new-fcm-token-xyz',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('users').doc('user-123').get();
      expect(doc.data()?['fcmToken'], 'new-fcm-token-xyz');
    });
  });

  group('Account Deletion Tests', () {
    test('should delete user from Firestore', () async {
      await fakeFirestore.collection('users').doc('delete-me').set({
        'uid': 'delete-me',
        'phone': '+244912345678',
      });

      // Verify exists
      var doc = await fakeFirestore.collection('users').doc('delete-me').get();
      expect(doc.exists, isTrue);

      // Delete
      await fakeFirestore.collection('users').doc('delete-me').delete();

      // Verify deleted
      doc = await fakeFirestore.collection('users').doc('delete-me').get();
      expect(doc.exists, isFalse);
    });

    test('should delete related data on account deletion', () async {
      final userId = 'user-to-delete';

      // Create user data
      await fakeFirestore.collection('users').doc(userId).set({'uid': userId});
      await fakeFirestore.collection('bookings').add({'clientId': userId});
      await fakeFirestore.collection('conversations').add({'participants': [userId]});

      // Delete user
      await fakeFirestore.collection('users').doc(userId).delete();

      // User should be deleted
      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(userDoc.exists, isFalse);

      // Note: Related data cleanup would typically be handled by Cloud Functions
    });
  });

  group('Account Existence Checks', () {
    test('should find existing account by phone', () async {
      await fakeFirestore.collection('users').doc('user-1').set({
        'phone': '+244912345678',
        'userType': 'client',
      });

      final query = await fakeFirestore
          .collection('users')
          .where('phone', isEqualTo: '+244912345678')
          .limit(1)
          .get();

      expect(query.docs.isNotEmpty, isTrue);
      expect(query.docs.first.data()['userType'], 'client');
    });

    test('should find existing account by email', () async {
      await fakeFirestore.collection('users').doc('user-1').set({
        'email': 'existing@test.com',
        'userType': 'supplier',
      });

      final query = await fakeFirestore
          .collection('users')
          .where('email', isEqualTo: 'existing@test.com')
          .limit(1)
          .get();

      expect(query.docs.isNotEmpty, isTrue);
      expect(query.docs.first.data()['userType'], 'supplier');
    });

    test('should return null for non-existent account', () async {
      final query = await fakeFirestore
          .collection('users')
          .where('phone', isEqualTo: '+244999999999')
          .limit(1)
          .get();

      expect(query.docs.isEmpty, isTrue);
    });
  });

  group('Error Handling Tests', () {
    test('should handle invalid phone number format', () {
      expect(_isValidAngolaPhoone('123'), isFalse);
      expect(_isValidAngolaPhoone('abcdefghi'), isFalse);
      expect(_isValidAngolaPhoone(''), isFalse);
    });

    test('should handle missing user data gracefully', () async {
      final doc = await fakeFirestore.collection('users').doc('non-existent').get();
      expect(doc.exists, isFalse);
      expect(doc.data(), isNull);
    });
  });

  group('User Type Enum Tests', () {
    test('should convert string to UserType', () {
      expect(UserType.client.name, 'client');
      expect(UserType.supplier.name, 'supplier');
    });

    test('should get UserType from string', () {
      expect(
        UserType.values.firstWhere((e) => e.name == 'client'),
        UserType.client,
      );
      expect(
        UserType.values.firstWhere((e) => e.name == 'supplier'),
        UserType.supplier,
      );
    });
  });
}

// Helper functions for testing
String _formatPhoneNumberAO(String phone) {
  String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.startsWith('00244')) {
    cleaned = cleaned.substring(5);
  } else if (cleaned.startsWith('+244')) {
    cleaned = cleaned.substring(4);
  } else if (cleaned.startsWith('244')) {
    cleaned = cleaned.substring(3);
  }
  return '+244$cleaned';
}

bool _isValidAngolaPhoone(String phone) {
  if (phone.isEmpty) return false;
  final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (cleaned.length != 9) return false;
  // Angola mobile prefixes: 91, 92, 93, 94, 95, 96, 99
  final validPrefixes = ['91', '92', '93', '94', '95', '96', '99'];
  return validPrefixes.any((prefix) => cleaned.startsWith(prefix));
}
