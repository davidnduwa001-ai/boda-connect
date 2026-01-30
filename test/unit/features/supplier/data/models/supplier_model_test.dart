import 'package:boda_connect/features/supplier/data/models/geopoint_model.dart';
import 'package:boda_connect/features/supplier/data/models/location_model.dart';
import 'package:boda_connect/features/supplier/data/models/day_hours_model.dart';
import 'package:boda_connect/features/supplier/data/models/working_hours_model.dart';
import 'package:boda_connect/features/supplier/data/models/supplier_model.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupplierModel', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DateTime testDateTime;
    late Timestamp testTimestamp;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      testDateTime = DateTime(2024, 1, 15, 10, 30);
      testTimestamp = Timestamp.fromDate(testDateTime);
    });

    SupplierModel createTestSupplierModel() {
      return SupplierModel(
        id: 'supplier-1',
        userId: 'user-1',
        businessName: 'Photography Pro',
        category: 'fotografia',
        subcategories: ['casamento', 'evento'],
        description: 'Professional photography services',
        photos: ['photo1.jpg', 'photo2.jpg'],
        videos: ['video1.mp4'],
        location: const LocationModel(
          city: 'Luanda',
          province: 'Luanda',
          country: 'Angola',
          address: 'Rua 1, 123',
          geopoint: GeoPointModel(latitude: -8.8383, longitude: 13.2344),
        ),
        rating: 4.5,
        reviewCount: 10,
        isVerified: true,
        isActive: true,
        isFeatured: false,
        responseRate: 95.0,
        responseTime: '< 1 hour',
        phone: '+244912345678',
        email: 'photo@example.com',
        website: 'https://example.com',
        socialLinks: {'instagram': '@photopro', 'facebook': 'photopro'},
        languages: ['pt', 'en'],
        workingHours: WorkingHoursModel(
          schedule: {
            'monday': const DayHoursModel(
              isOpen: true,
              openTime: '09:00',
              closeTime: '18:00',
            ),
          },
        ),
        createdAt: testDateTime,
        updatedAt: testDateTime,
      );
    }

    Map<String, dynamic> createTestFirestoreData() {
      return {
        'userId': 'user-1',
        'businessName': 'Photography Pro',
        'category': 'fotografia',
        'subcategories': ['casamento', 'evento'],
        'description': 'Professional photography services',
        'photos': ['photo1.jpg', 'photo2.jpg'],
        'videos': ['video1.mp4'],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'country': 'Angola',
          'address': 'Rua 1, 123',
          'geopoint': GeoPoint(-8.8383, 13.2344),
        },
        'rating': 4.5,
        'reviewCount': 10,
        'isVerified': true,
        'isActive': true,
        'isFeatured': false,
        'responseRate': 95.0,
        'responseTime': '< 1 hour',
        'phone': '+244912345678',
        'email': 'photo@example.com',
        'website': 'https://example.com',
        'socialLinks': {'instagram': '@photopro', 'facebook': 'photopro'},
        'languages': ['pt', 'en'],
        'workingHours': {
          'monday': {
            'isOpen': true,
            'openTime': '09:00',
            'closeTime': '18:00',
          },
        },
        'createdAt': testTimestamp,
        'updatedAt': testTimestamp,
      };
    }

    group('fromEntity', () {
      test('should create SupplierModel from SupplierEntity with all fields',
          () {
        // Arrange
        const geoPoint = GeoPointEntity(latitude: -8.8383, longitude: 13.2344);
        const location = LocationEntity(
          city: 'Luanda',
          province: 'Luanda',
          country: 'Angola',
          address: 'Rua 1, 123',
          geopoint: geoPoint,
        );
        const workingHours = WorkingHoursEntity(
          schedule: {
            'monday': DayHoursEntity(
              isOpen: true,
              openTime: '09:00',
              closeTime: '18:00',
            ),
          },
        );

        final entity = SupplierEntity(
          id: 'supplier-1',
          userId: 'user-1',
          businessName: 'Photography Pro',
          category: 'fotografia',
          subcategories: const ['casamento', 'evento'],
          description: 'Professional photography services',
          photos: const ['photo1.jpg', 'photo2.jpg'],
          videos: const ['video1.mp4'],
          location: location,
          rating: 4.5,
          reviewCount: 10,
          isVerified: true,
          isActive: true,
          isFeatured: false,
          responseRate: 95.0,
          responseTime: '< 1 hour',
          phone: '+244912345678',
          email: 'photo@example.com',
          website: 'https://example.com',
          socialLinks: const {'instagram': '@photopro', 'facebook': 'photopro'},
          languages: const ['pt', 'en'],
          workingHours: workingHours,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final model = SupplierModel.fromEntity(entity);

        // Assert
        expect(model, isA<SupplierModel>());
        expect(model.id, equals('supplier-1'));
        expect(model.userId, equals('user-1'));
        expect(model.businessName, equals('Photography Pro'));
        expect(model.category, equals('fotografia'));
        expect(model.subcategories, equals(['casamento', 'evento']));
        expect(model.description, equals('Professional photography services'));
        expect(model.photos, equals(['photo1.jpg', 'photo2.jpg']));
        expect(model.videos, equals(['video1.mp4']));
        expect(model.location, isA<LocationModel>());
        expect(model.rating, equals(4.5));
        expect(model.reviewCount, equals(10));
        expect(model.isVerified, equals(true));
        expect(model.isActive, equals(true));
        expect(model.isFeatured, equals(false));
        expect(model.responseRate, equals(95.0));
        expect(model.responseTime, equals('< 1 hour'));
        expect(model.phone, equals('+244912345678'));
        expect(model.email, equals('photo@example.com'));
        expect(model.website, equals('https://example.com'));
        expect(model.socialLinks, isNotNull);
        expect(model.languages, equals(['pt', 'en']));
        expect(model.workingHours, isA<WorkingHoursModel>());
      });

      test('should handle entity with null optional fields', () {
        // Arrange
        final entity = SupplierEntity(
          id: 'supplier-1',
          userId: 'user-1',
          businessName: 'Test Business',
          category: 'fotografia',
          subcategories: const [],
          description: 'Description',
          photos: const [],
          videos: const [],
          location: null,
          rating: 0.0,
          reviewCount: 0,
          isVerified: false,
          isActive: true,
          isFeatured: false,
          responseRate: 0.0,
          responseTime: null,
          phone: null,
          email: null,
          website: null,
          socialLinks: null,
          languages: const [],
          workingHours: null,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final model = SupplierModel.fromEntity(entity);

        // Assert
        expect(model.location, isNull);
        expect(model.responseTime, isNull);
        expect(model.phone, isNull);
        expect(model.email, isNull);
        expect(model.website, isNull);
        expect(model.socialLinks, isNull);
        expect(model.workingHours, isNull);
      });

      test('should convert location entity to location model', () {
        // Arrange
        const location = LocationEntity(city: 'Luanda', province: 'Luanda');
        final entity = SupplierEntity(
          id: 'supplier-1',
          userId: 'user-1',
          businessName: 'Test',
          category: 'fotografia',
          subcategories: const [],
          description: 'Desc',
          photos: const [],
          videos: const [],
          location: location,
          rating: 0.0,
          reviewCount: 0,
          isVerified: false,
          isActive: true,
          isFeatured: false,
          responseRate: 0.0,
          languages: const [],
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final model = SupplierModel.fromEntity(entity);

        // Assert
        expect(model.location, isA<LocationModel>());
        expect(model.location?.city, equals('Luanda'));
      });
    });

    group('fromFirestore', () {
      test('should create SupplierModel from DocumentSnapshot', () async {
        // Arrange
        final data = createTestFirestoreData();
        await fakeFirestore.collection('suppliers').doc('supplier-1').set(data);
        final doc =
            await fakeFirestore.collection('suppliers').doc('supplier-1').get();

        // Act
        final model = SupplierModel.fromFirestore(doc);

        // Assert
        expect(model, isA<SupplierModel>());
        expect(model.id, equals('supplier-1'));
        expect(model.businessName, equals('Photography Pro'));
      });

      test('should use document ID as model ID', () async {
        // Arrange
        final data = createTestFirestoreData();
        await fakeFirestore.collection('suppliers').doc('test-id').set(data);
        final doc =
            await fakeFirestore.collection('suppliers').doc('test-id').get();

        // Act
        final model = SupplierModel.fromFirestore(doc);

        // Assert
        expect(model.id, equals('test-id'));
      });
    });

    group('fromMap', () {
      test('should create SupplierModel from map with all fields', () {
        // Arrange
        final map = createTestFirestoreData();
        const id = 'supplier-1';

        // Act
        final model = SupplierModel.fromMap(map, id);

        // Assert
        expect(model.id, equals(id));
        expect(model.userId, equals('user-1'));
        expect(model.businessName, equals('Photography Pro'));
        expect(model.category, equals('fotografia'));
        expect(model.subcategories, equals(['casamento', 'evento']));
        expect(model.description, equals('Professional photography services'));
        expect(model.photos, equals(['photo1.jpg', 'photo2.jpg']));
        expect(model.videos, equals(['video1.mp4']));
        expect(model.rating, equals(4.5));
        expect(model.reviewCount, equals(10));
        expect(model.isVerified, equals(true));
        expect(model.isActive, equals(true));
        expect(model.isFeatured, equals(false));
        expect(model.responseRate, equals(95.0));
        expect(model.responseTime, equals('< 1 hour'));
        expect(model.phone, equals('+244912345678'));
        expect(model.email, equals('photo@example.com'));
        expect(model.website, equals('https://example.com'));
        expect(model.languages, equals(['pt', 'en']));
      });

      test('should use default values for missing fields', () {
        // Arrange
        final map = <String, dynamic>{};
        const id = 'supplier-1';

        // Act
        final model = SupplierModel.fromMap(map, id);

        // Assert
        expect(model.id, equals(id));
        expect(model.userId, equals(''));
        expect(model.businessName, equals(''));
        expect(model.category, equals(''));
        expect(model.subcategories, equals([]));
        expect(model.description, equals(''));
        expect(model.photos, equals([]));
        expect(model.videos, equals([]));
        expect(model.location, isNull);
        expect(model.rating, equals(0.0));
        expect(model.reviewCount, equals(0));
        expect(model.isVerified, equals(false));
        expect(model.isActive, equals(true));
        expect(model.isFeatured, equals(false));
        expect(model.responseRate, equals(0.0));
        expect(model.responseTime, isNull);
        expect(model.languages, equals([]));
        expect(model.workingHours, isNull);
      });

      test('should handle null values in map', () {
        // Arrange
        final map = <String, dynamic>{
          'userId': null,
          'businessName': null,
          'category': null,
          'subcategories': null,
          'description': null,
          'photos': null,
          'videos': null,
          'location': null,
          'rating': null,
          'reviewCount': null,
          'isVerified': null,
          'isActive': null,
          'isFeatured': null,
          'responseRate': null,
          'responseTime': null,
          'phone': null,
          'email': null,
          'website': null,
          'socialLinks': null,
          'languages': null,
          'workingHours': null,
          'createdAt': null,
          'updatedAt': null,
        };
        const id = 'supplier-1';

        // Act
        final model = SupplierModel.fromMap(map, id);

        // Assert
        expect(model.userId, equals(''));
        expect(model.businessName, equals(''));
        expect(model.rating, equals(0.0));
        expect(model.isVerified, equals(false));
      });

      test('should parse location from map', () {
        // Arrange
        final map = <String, dynamic>{
          'location': {
            'city': 'Luanda',
            'province': 'Luanda',
            'geopoint': GeoPoint(-8.8383, 13.2344),
          },
        };
        const id = 'supplier-1';

        // Act
        final model = SupplierModel.fromMap(map, id);

        // Assert
        expect(model.location, isNotNull);
        expect(model.location?.city, equals('Luanda'));
        expect(model.location?.province, equals('Luanda'));
      });

      test('should parse working hours from map', () {
        // Arrange
        final map = <String, dynamic>{
          'workingHours': {
            'monday': {
              'isOpen': true,
              'openTime': '09:00',
              'closeTime': '18:00',
            },
          },
        };
        const id = 'supplier-1';

        // Act
        final model = SupplierModel.fromMap(map, id);

        // Assert
        expect(model.workingHours, isNotNull);
        expect(model.workingHours?.schedule.containsKey('monday'), isTrue);
      });

      test('should convert int rating to double', () {
        // Arrange
        final map = <String, dynamic>{'rating': 5};
        const id = 'supplier-1';

        // Act
        final model = SupplierModel.fromMap(map, id);

        // Assert
        expect(model.rating, equals(5.0));
      });

      test('should convert int responseRate to double', () {
        // Arrange
        final map = <String, dynamic>{'responseRate': 100};
        const id = 'supplier-1';

        // Act
        final model = SupplierModel.fromMap(map, id);

        // Assert
        expect(model.responseRate, equals(100.0));
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map with all fields', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map, isA<Map<String, dynamic>>());
        expect(map['userId'], equals('user-1'));
        expect(map['businessName'], equals('Photography Pro'));
        expect(map['category'], equals('fotografia'));
        expect(map['subcategories'], equals(['casamento', 'evento']));
        expect(map['description'], equals('Professional photography services'));
        expect(map['photos'], equals(['photo1.jpg', 'photo2.jpg']));
        expect(map['videos'], equals(['video1.mp4']));
        expect(map['rating'], equals(4.5));
        expect(map['reviewCount'], equals(10));
        expect(map['isVerified'], equals(true));
        expect(map['isActive'], equals(true));
        expect(map['isFeatured'], equals(false));
        expect(map['responseRate'], equals(95.0));
        expect(map['responseTime'], equals('< 1 hour'));
        expect(map['phone'], equals('+244912345678'));
        expect(map['email'], equals('photo@example.com'));
        expect(map['website'], equals('https://example.com'));
        expect(map['languages'], equals(['pt', 'en']));
      });

      test('should not include id field in map', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.containsKey('id'), isFalse);
      });

      test('should convert timestamps', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });

      test('should convert location to map', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['location'], isA<Map<String, dynamic>>());
        final location = map['location'] as Map<String, dynamic>;
        expect(location['city'], equals('Luanda'));
      });

      test('should convert working hours to map', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['workingHours'], isA<Map<String, dynamic>>());
      });

      test('should exclude null optional fields', () {
        // Arrange
        final model = SupplierModel(
          id: 'supplier-1',
          userId: 'user-1',
          businessName: 'Test',
          category: 'fotografia',
          subcategories: const [],
          description: 'Desc',
          photos: const [],
          videos: const [],
          location: null,
          rating: 0.0,
          reviewCount: 0,
          isVerified: false,
          isActive: true,
          isFeatured: false,
          responseRate: 0.0,
          responseTime: null,
          phone: null,
          email: null,
          website: null,
          socialLinks: null,
          languages: const [],
          workingHours: null,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.containsKey('location'), isFalse);
        expect(map.containsKey('responseTime'), isFalse);
        expect(map.containsKey('phone'), isFalse);
        expect(map.containsKey('email'), isFalse);
        expect(map.containsKey('website'), isFalse);
        expect(map.containsKey('socialLinks'), isFalse);
        expect(map.containsKey('workingHours'), isFalse);
      });
    });

    group('toEntity', () {
      test('should convert to SupplierEntity', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<SupplierEntity>());
        expect(entity.id, equals('supplier-1'));
        expect(entity.userId, equals('user-1'));
        expect(entity.businessName, equals('Photography Pro'));
        expect(entity.category, equals('fotografia'));
      });

      test('should preserve all field values', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.subcategories, equals(['casamento', 'evento']));
        expect(entity.photos, equals(['photo1.jpg', 'photo2.jpg']));
        expect(entity.rating, equals(4.5));
        expect(entity.isVerified, equals(true));
      });
    });

    group('copyWith', () {
      test('should create new instance with updated businessName', () {
        // Arrange
        final model = createTestSupplierModel();
        const newBusinessName = 'New Business';

        // Act
        final updated = model.copyWith(businessName: newBusinessName);

        // Assert
        expect(updated.businessName, equals(newBusinessName));
        expect(updated.userId, equals(model.userId));
      });

      test('should create new instance with updated rating', () {
        // Arrange
        final model = createTestSupplierModel();
        const newRating = 5.0;

        // Act
        final updated = model.copyWith(rating: newRating);

        // Assert
        expect(updated.rating, equals(newRating));
      });

      test('should create new instance with updated isVerified', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final updated = model.copyWith(isVerified: false);

        // Assert
        expect(updated.isVerified, equals(false));
        expect(model.isVerified, equals(true));
      });

      test('should return same values when no parameters provided', () {
        // Arrange
        final model = createTestSupplierModel();

        // Act
        final updated = model.copyWith();

        // Assert
        expect(updated.businessName, equals(model.businessName));
        expect(updated.rating, equals(model.rating));
      });
    });

    group('equality', () {
      test('should be equal when all fields are the same', () {
        // Arrange
        final model1 = createTestSupplierModel();
        final model2 = createTestSupplierModel();

        // Assert
        expect(model1, equals(model2));
      });

      test('should not be equal when businessName differs', () {
        // Arrange
        final model1 = createTestSupplierModel();
        final model2 = model1.copyWith(businessName: 'Different');

        // Assert
        expect(model1, isNot(equals(model2)));
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity through Firestore conversion', () {
        // Arrange
        final original = createTestSupplierModel();

        // Act
        final map = original.toFirestore();
        final converted = SupplierModel.fromMap(map, original.id);

        // Assert
        expect(converted.businessName, equals(original.businessName));
        expect(converted.category, equals(original.category));
        expect(converted.rating, equals(original.rating));
      });

      test('should maintain data integrity through entity conversion', () {
        // Arrange
        final original = createTestSupplierModel();

        // Act
        final entity = original.toEntity();
        final converted = SupplierModel.fromEntity(entity);

        // Assert
        expect(converted.businessName, equals(original.businessName));
        expect(converted.rating, equals(original.rating));
      });
    });
  });
}
