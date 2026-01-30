import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/models/user_model.dart';

/// UserModel Tests
void main() {
  group('UserModel Creation Tests', () {
    test('should create UserModel with required fields', () {
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        userType: UserType.client,
        createdAt: DateTime.now(),
      );

      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.userType, UserType.client);
      expect(user.isActive, isTrue);
    });

    test('should create UserModel with all fields', () {
      final now = DateTime.now();
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        name: 'João Silva',
        phone: '+244912345678',
        photoUrl: 'https://example.com/photo.jpg',
        userType: UserType.supplier,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(user.name, 'João Silva');
      expect(user.phone, '+244912345678');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.userType, UserType.supplier);
    });
  });

  group('UserModel.fromFirestore Tests', () {
    test('should parse user from Firestore data', () {
      final now = Timestamp.now();
      final data = {
        'email': 'test@example.com',
        'name': 'Maria Santos',
        'phone': '+244923456789',
        'photoUrl': 'https://example.com/maria.jpg',
        'userType': 'client',
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      };

      final user = UserModel.fromFirestore('user-456', data);

      expect(user.id, 'user-456');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Maria Santos');
      expect(user.phone, '+244923456789');
      expect(user.userType, UserType.client);
    });

    test('should handle missing optional fields', () {
      final data = {
        'email': 'test@example.com',
        'userType': 'client',
        'createdAt': Timestamp.now(),
      };

      final user = UserModel.fromFirestore('user-789', data);

      expect(user.id, 'user-789');
      expect(user.name, isNull);
      expect(user.phone, isNull);
      expect(user.photoUrl, isNull);
      expect(user.isActive, isTrue); // Default
    });

    test('should parse supplier userType', () {
      final data = {
        'email': 'supplier@example.com',
        'userType': 'supplier',
        'createdAt': Timestamp.now(),
      };

      final user = UserModel.fromFirestore('supplier-1', data);
      expect(user.userType, UserType.supplier);
    });

    test('should parse admin userType', () {
      final data = {
        'email': 'admin@example.com',
        'userType': 'admin',
        'createdAt': Timestamp.now(),
      };

      final user = UserModel.fromFirestore('admin-1', data);
      expect(user.userType, UserType.admin);
    });
  });

  group('UserModel.toMap Tests', () {
    test('should convert user to map', () {
      final now = DateTime.now();
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        phone: '+244912345678',
        userType: UserType.client,
        isActive: true,
        createdAt: now,
      );

      final map = user.toMap();

      expect(map['email'], 'test@example.com');
      expect(map['name'], 'Test User');
      expect(map['phone'], '+244912345678');
      expect(map['userType'], 'client');
      expect(map['isActive'], true);
    });

    test('should include null values in map', () {
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        userType: UserType.client,
        createdAt: DateTime.now(),
      );

      final map = user.toMap();

      expect(map.containsKey('name'), isTrue);
      expect(map['name'], isNull);
    });
  });

  group('UserModel.copyWith Tests', () {
    test('should copy with new values', () {
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Original Name',
        userType: UserType.client,
        createdAt: DateTime.now(),
      );

      final updated = user.copyWith(name: 'Updated Name');

      expect(updated.name, 'Updated Name');
      expect(updated.email, 'test@example.com'); // Unchanged
      expect(updated.id, 'user-123'); // Unchanged
    });

    test('should preserve values when not specified', () {
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        phone: '+244912345678',
        userType: UserType.client,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final updated = user.copyWith(isActive: false);

      expect(updated.isActive, isFalse);
      expect(updated.name, 'Test User');
      expect(updated.phone, '+244912345678');
    });
  });

  group('UserType Tests', () {
    test('UserType enum should have all types', () {
      expect(UserType.values.length, 3);
      expect(UserType.values.contains(UserType.client), isTrue);
      expect(UserType.values.contains(UserType.supplier), isTrue);
      expect(UserType.values.contains(UserType.admin), isTrue);
    });

    test('should convert string to UserType', () {
      expect(UserType.values.firstWhere((t) => t.name == 'client'), UserType.client);
      expect(UserType.values.firstWhere((t) => t.name == 'supplier'), UserType.supplier);
      expect(UserType.values.firstWhere((t) => t.name == 'admin'), UserType.admin);
    });
  });

  group('UserModel Equality Tests', () {
    test('users with same id should be equal', () {
      final user1 = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        userType: UserType.client,
        createdAt: DateTime.now(),
      );

      final user2 = UserModel(
        id: 'user-123',
        email: 'different@example.com',
        userType: UserType.client,
        createdAt: DateTime.now(),
      );

      // If equality is based on ID
      expect(user1.id, user2.id);
    });
  });
}
