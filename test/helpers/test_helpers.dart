import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test helpers for setting up mocks and test environment

/// Creates a fake Firestore instance for testing
FakeFirebaseFirestore createFakeFirestore() {
  return FakeFirebaseFirestore();
}

/// Creates a mock Firebase Auth instance
MockFirebaseAuth createMockAuth({
  bool signedIn = false,
  MockUser? mockUser,
}) {
  final user = mockUser ??
      MockUser(
        uid: 'test-user-id',
        email: 'test@example.com',
        displayName: 'Test User',
        phoneNumber: '+244912345678',
      );

  return MockFirebaseAuth(
    signedIn: signedIn,
    mockUser: user,
  );
}

/// Creates a ProviderContainer for testing Riverpod providers
ProviderContainer createTestProviderContainer({
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: overrides,
  );

  addTearDown(container.dispose);
  return container;
}

/// Pumps a widget with Riverpod ProviderScope
Future<void> pumpProviderScope(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: child,
    ),
  );
}

/// Creates a Firestore timestamp for testing
Timestamp createTestTimestamp({DateTime? dateTime}) {
  return Timestamp.fromDate(dateTime ?? DateTime.now());
}

/// Mock data helpers
class MockData {
  static const String testUserId = 'test-user-id';
  static const String testSupplierId = 'test-supplier-id';
  static const String testPackageId = 'test-package-id';
  static const String testChatId = 'test-chat-id';
  static const String testBookingId = 'test-booking-id';

  static Map<String, dynamic> get testUserData => {
        'id': testUserId,
        'name': 'Test User',
        'email': 'test@example.com',
        'phone': '+244912345678',
        'role': 'client',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

  static Map<String, dynamic> get testSupplierData => {
        'id': testSupplierId,
        'name': 'Test Supplier',
        'email': 'supplier@example.com',
        'phone': '+244912345679',
        'role': 'supplier',
        'category': 'fotografia',
        'description': 'Professional photographer',
        'rating': 4.5,
        'reviewCount': 10,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

  static Map<String, dynamic> get testPackageData => {
        'id': testPackageId,
        'supplierId': testSupplierId,
        'name': 'Premium Package',
        'description': 'Full day coverage',
        'price': 50000,
        'duration': 480,
        'features': ['8 hours', 'Digital photos', 'Album'],
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

  static Map<String, dynamic> get testMessageData => {
        'id': 'test-message-id',
        'chatId': testChatId,
        'senderId': testUserId,
        'text': 'Test message',
        'timestamp': Timestamp.now(),
        'isRead': false,
      };

  static Map<String, dynamic> get testBookingData => {
        'id': testBookingId,
        'clientId': testUserId,
        'supplierId': testSupplierId,
        'packageId': testPackageId,
        'status': 'pending',
        'eventDate': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
        'totalAmount': 50000,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
}
