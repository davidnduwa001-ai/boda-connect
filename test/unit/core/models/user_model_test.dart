import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/models/user_model.dart';
import 'package:boda_connect/core/models/user_type.dart';

/// UserModel Tests
void main() {
  group('UserModel Creation Tests', () {
    test('should create UserModel with required fields', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        userType: UserType.client,
        createdAt: now,
        updatedAt: now,
      );

      expect(user.uid, 'user-123');
      expect(user.phone, '+244912345678');
      expect(user.userType, UserType.client);
      expect(user.isActive, isTrue);
      expect(user.rating, 5.0);
      expect(user.isOnline, isFalse);
    });

    test('should create UserModel with all fields', () {
      final now = DateTime.now();
      final location = LocationData(
        city: 'Luanda',
        province: 'Luanda',
        country: 'Angola',
      );
      final preferences = UserPreferences(
        categories: ['casamento', 'festas'],
        completedOnboarding: true,
        preferredLanguage: 'pt',
      );

      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        name: 'João Silva',
        email: 'joao@example.com',
        photoUrl: 'https://example.com/photo.jpg',
        description: 'Test user description',
        userType: UserType.supplier,
        location: location,
        createdAt: now,
        updatedAt: now,
        isActive: true,
        fcmToken: 'fcm-token-123',
        preferences: preferences,
        rating: 4.5,
        isOnline: true,
        lastSeen: now,
        violationsCount: 0,
      );

      expect(user.name, 'João Silva');
      expect(user.email, 'joao@example.com');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.description, 'Test user description');
      expect(user.userType, UserType.supplier);
      expect(user.location?.city, 'Luanda');
      expect(user.fcmToken, 'fcm-token-123');
      expect(user.preferences?.preferredLanguage, 'pt');
      expect(user.rating, 4.5);
      expect(user.isOnline, isTrue);
    });
  });

  group('UserModel.toFirestore Tests', () {
    test('should convert user to map', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        name: 'Test User',
        email: 'test@example.com',
        userType: UserType.client,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toFirestore();

      expect(map['phone'], '+244912345678');
      expect(map['name'], 'Test User');
      expect(map['email'], 'test@example.com');
      expect(map['userType'], 'client');
      expect(map['isActive'], true);
    });

    test('should include null values in map', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        userType: UserType.client,
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toFirestore();

      expect(map.containsKey('name'), isTrue);
      expect(map['name'], isNull);
      expect(map.containsKey('email'), isTrue);
      expect(map['email'], isNull);
    });

    test('should convert supplier user type', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'supplier-1',
        phone: '+244923456789',
        userType: UserType.supplier,
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toFirestore();
      expect(map['userType'], 'supplier');
    });
  });

  group('UserModel.copyWith Tests', () {
    test('should copy with new values', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        name: 'Original Name',
        userType: UserType.client,
        createdAt: now,
        updatedAt: now,
      );

      final updated = user.copyWith(name: 'Updated Name');

      expect(updated.name, 'Updated Name');
      expect(updated.phone, '+244912345678'); // Unchanged
      expect(updated.uid, 'user-123'); // Unchanged
    });

    test('should preserve values when not specified', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        name: 'Test User',
        email: 'test@example.com',
        userType: UserType.client,
        isActive: true,
        rating: 4.8,
        createdAt: now,
        updatedAt: now,
      );

      final updated = user.copyWith(isActive: false);

      expect(updated.isActive, isFalse);
      expect(updated.name, 'Test User');
      expect(updated.phone, '+244912345678');
      expect(updated.rating, 4.8);
    });

    test('should copy with new rating', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        userType: UserType.supplier,
        rating: 5.0,
        createdAt: now,
        updatedAt: now,
      );

      final updated = user.copyWith(rating: 4.5);
      expect(updated.rating, 4.5);
    });
  });

  group('UserType Tests', () {
    test('UserType enum should have correct types', () {
      expect(UserType.values.length, 2);
      expect(UserType.values.contains(UserType.client), isTrue);
      expect(UserType.values.contains(UserType.supplier), isTrue);
    });

    test('should convert string to UserType', () {
      expect(UserType.values.firstWhere((t) => t.name == 'client'), UserType.client);
      expect(UserType.values.firstWhere((t) => t.name == 'supplier'), UserType.supplier);
    });
  });

  group('LocationData Tests', () {
    test('should create LocationData from map', () {
      final data = {
        'city': 'Luanda',
        'province': 'Luanda',
        'country': 'Angola',
        'address': 'Rua Principal 123',
      };

      final location = LocationData.fromMap(data);

      expect(location.city, 'Luanda');
      expect(location.province, 'Luanda');
      expect(location.country, 'Angola');
      expect(location.address, 'Rua Principal 123');
    });

    test('should handle null values in LocationData', () {
      final location = LocationData.fromMap({});

      expect(location.city, isNull);
      expect(location.province, isNull);
      expect(location.geopoint, isNull);
    });

    test('should convert LocationData to map', () {
      const location = LocationData(
        city: 'Benguela',
        province: 'Benguela',
        country: 'Angola',
      );

      final map = location.toMap();

      expect(map['city'], 'Benguela');
      expect(map['province'], 'Benguela');
      expect(map['country'], 'Angola');
    });
  });

  group('UserPreferences Tests', () {
    test('should create UserPreferences from map', () {
      final data = {
        'categories': ['casamento', 'festas'],
        'completedOnboarding': true,
        'notifyNewMessages': true,
        'notifyBookingUpdates': true,
        'notifyPromotions': false,
        'preferredLanguage': 'pt',
        'darkMode': true,
        'showOnlineStatus': true,
        'maxDistance': 50,
      };

      final prefs = UserPreferences.fromMap(data);

      expect(prefs.categories, ['casamento', 'festas']);
      expect(prefs.completedOnboarding, isTrue);
      expect(prefs.notifyNewMessages, isTrue);
      expect(prefs.notifyPromotions, isFalse);
      expect(prefs.preferredLanguage, 'pt');
      expect(prefs.darkMode, isTrue);
      expect(prefs.maxDistance, 50);
    });

    test('should use defaults for missing preferences', () {
      final prefs = UserPreferences.fromMap({});

      expect(prefs.notifyNewMessages, isTrue);
      expect(prefs.notifyBookingUpdates, isTrue);
      expect(prefs.notifyPromotions, isTrue);
      expect(prefs.notifyReminders, isTrue);
      expect(prefs.darkMode, isFalse);
      expect(prefs.showOnlineStatus, isTrue);
      expect(prefs.allowDirectMessages, isTrue);
    });

    test('should convert UserPreferences to map', () {
      const prefs = UserPreferences(
        categories: ['musica'],
        preferredLanguage: 'en',
        darkMode: true,
        maxDistance: 100,
      );

      final map = prefs.toMap();

      expect(map['categories'], ['musica']);
      expect(map['preferredLanguage'], 'en');
      expect(map['darkMode'], true);
      expect(map['maxDistance'], 100);
    });

    test('should copy UserPreferences with new values', () {
      const prefs = UserPreferences(
        darkMode: false,
        preferredLanguage: 'pt',
      );

      final updated = prefs.copyWith(darkMode: true);

      expect(updated.darkMode, isTrue);
      expect(updated.preferredLanguage, 'pt'); // Preserved
    });
  });

  group('UserModel Violations Tests', () {
    test('should track violations count', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        userType: UserType.supplier,
        createdAt: now,
        updatedAt: now,
        violationsCount: 2,
        lastViolationAt: now,
      );

      expect(user.violationsCount, 2);
      expect(user.lastViolationAt, isNotNull);
    });

    test('should default to zero violations', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user-123',
        phone: '+244912345678',
        userType: UserType.client,
        createdAt: now,
        updatedAt: now,
      );

      expect(user.violationsCount, 0);
      expect(user.lastViolationAt, isNull);
    });
  });
}
