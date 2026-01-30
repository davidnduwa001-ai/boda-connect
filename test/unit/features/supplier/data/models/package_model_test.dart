import 'package:boda_connect/features/supplier/data/models/package_customization_model.dart';
import 'package:boda_connect/features/supplier/data/models/package_model.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PackageModel', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DateTime testDateTime;
    late Timestamp testTimestamp;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      testDateTime = DateTime(2024, 1, 15, 10, 30);
      testTimestamp = Timestamp.fromDate(testDateTime);
    });

    PackageModel createTestPackageModel() {
      return PackageModel(
        id: 'package-1',
        supplierId: 'supplier-1',
        name: 'Wedding Premium Package',
        description: 'Full day wedding photography coverage',
        price: 50000,
        currency: 'KES',
        duration: '8 hours',
        includes: ['Digital photos', 'Photo album', 'Drone shots'],
        customizations: const [
          PackageCustomizationModel(
            name: 'Extra Hour',
            price: 5000,
            description: 'Additional hour of coverage',
          ),
          PackageCustomizationModel(
            name: 'Video Highlights',
            price: 15000,
            description: '5-minute highlight reel',
          ),
        ],
        photos: ['package1.jpg', 'package2.jpg'],
        isActive: true,
        isFeatured: false,
        bookingCount: 5,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      );
    }

    Map<String, dynamic> createTestFirestoreData() {
      return {
        'supplierId': 'supplier-1',
        'name': 'Wedding Premium Package',
        'description': 'Full day wedding photography coverage',
        'price': 50000,
        'currency': 'KES',
        'duration': '8 hours',
        'includes': ['Digital photos', 'Photo album', 'Drone shots'],
        'customizations': [
          {
            'name': 'Extra Hour',
            'price': 5000,
            'description': 'Additional hour of coverage',
          },
          {
            'name': 'Video Highlights',
            'price': 15000,
            'description': '5-minute highlight reel',
          },
        ],
        'photos': ['package1.jpg', 'package2.jpg'],
        'isActive': true,
        'isFeatured': false,
        'bookingCount': 5,
        'createdAt': testTimestamp,
        'updatedAt': testTimestamp,
      };
    }

    group('fromEntity', () {
      test('should create PackageModel from PackageEntity with all fields', () {
        // Arrange
        const customizations = [
          PackageCustomizationEntity(
            name: 'Extra Hour',
            price: 5000,
            description: 'Additional hour',
          ),
        ];

        final entity = PackageEntity(
          id: 'package-1',
          supplierId: 'supplier-1',
          name: 'Wedding Package',
          description: 'Full day coverage',
          price: 50000,
          currency: 'KES',
          duration: '8 hours',
          includes: const ['Photos', 'Album'],
          customizations: customizations,
          photos: const ['photo1.jpg'],
          isActive: true,
          isFeatured: false,
          bookingCount: 5,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final model = PackageModel.fromEntity(entity);

        // Assert
        expect(model, isA<PackageModel>());
        expect(model.id, equals('package-1'));
        expect(model.supplierId, equals('supplier-1'));
        expect(model.name, equals('Wedding Package'));
        expect(model.description, equals('Full day coverage'));
        expect(model.price, equals(50000));
        expect(model.currency, equals('KES'));
        expect(model.duration, equals('8 hours'));
        expect(model.includes, equals(['Photos', 'Album']));
        expect(model.customizations.length, equals(1));
        expect(model.customizations[0], isA<PackageCustomizationModel>());
        expect(model.photos, equals(['photo1.jpg']));
        expect(model.isActive, equals(true));
        expect(model.isFeatured, equals(false));
        expect(model.bookingCount, equals(5));
      });

      test('should handle entity with empty lists', () {
        // Arrange
        final entity = PackageEntity(
          id: 'package-1',
          supplierId: 'supplier-1',
          name: 'Basic Package',
          description: 'Simple package',
          price: 10000,
          currency: 'KES',
          duration: '2 hours',
          includes: const [],
          customizations: const [],
          photos: const [],
          isActive: true,
          isFeatured: false,
          bookingCount: 0,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final model = PackageModel.fromEntity(entity);

        // Assert
        expect(model.includes, isEmpty);
        expect(model.customizations, isEmpty);
        expect(model.photos, isEmpty);
      });

      test('should convert customization entities to models', () {
        // Arrange
        const customizations = [
          PackageCustomizationEntity(name: 'Custom 1', price: 1000),
          PackageCustomizationEntity(name: 'Custom 2', price: 2000),
        ];

        final entity = PackageEntity(
          id: 'package-1',
          supplierId: 'supplier-1',
          name: 'Package',
          description: 'Desc',
          price: 10000,
          currency: 'KES',
          duration: '1 hour',
          includes: const [],
          customizations: customizations,
          photos: const [],
          isActive: true,
          isFeatured: false,
          bookingCount: 0,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final model = PackageModel.fromEntity(entity);

        // Assert
        expect(model.customizations.length, equals(2));
        expect(model.customizations[0].name, equals('Custom 1'));
        expect(model.customizations[1].name, equals('Custom 2'));
      });
    });

    group('fromFirestore', () {
      test('should create PackageModel from DocumentSnapshot', () async {
        // Arrange
        final data = createTestFirestoreData();
        await fakeFirestore.collection('packages').doc('package-1').set(data);
        final doc =
            await fakeFirestore.collection('packages').doc('package-1').get();

        // Act
        final model = PackageModel.fromFirestore(doc);

        // Assert
        expect(model, isA<PackageModel>());
        expect(model.id, equals('package-1'));
        expect(model.name, equals('Wedding Premium Package'));
      });

      test('should use document ID as model ID', () async {
        // Arrange
        final data = createTestFirestoreData();
        await fakeFirestore.collection('packages').doc('test-id').set(data);
        final doc =
            await fakeFirestore.collection('packages').doc('test-id').get();

        // Act
        final model = PackageModel.fromFirestore(doc);

        // Assert
        expect(model.id, equals('test-id'));
      });
    });

    group('fromMap', () {
      test('should create PackageModel from map with all fields', () {
        // Arrange
        final map = createTestFirestoreData();
        const id = 'package-1';

        // Act
        final model = PackageModel.fromMap(map, id);

        // Assert
        expect(model.id, equals(id));
        expect(model.supplierId, equals('supplier-1'));
        expect(model.name, equals('Wedding Premium Package'));
        expect(model.description, equals('Full day wedding photography coverage'));
        expect(model.price, equals(50000));
        expect(model.currency, equals('KES'));
        expect(model.duration, equals('8 hours'));
        expect(model.includes, equals(['Digital photos', 'Photo album', 'Drone shots']));
        expect(model.customizations.length, equals(2));
        expect(model.photos, equals(['package1.jpg', 'package2.jpg']));
        expect(model.isActive, equals(true));
        expect(model.isFeatured, equals(false));
        expect(model.bookingCount, equals(5));
      });

      test('should use default values for missing fields', () {
        // Arrange
        final map = <String, dynamic>{};
        const id = 'package-1';

        // Act
        final model = PackageModel.fromMap(map, id);

        // Assert
        expect(model.id, equals(id));
        expect(model.supplierId, equals(''));
        expect(model.name, equals(''));
        expect(model.description, equals(''));
        expect(model.price, equals(0));
        expect(model.currency, equals('KES'));
        expect(model.duration, equals(''));
        expect(model.includes, equals([]));
        expect(model.customizations, equals([]));
        expect(model.photos, equals([]));
        expect(model.isActive, equals(true));
        expect(model.isFeatured, equals(false));
        expect(model.bookingCount, equals(0));
      });

      test('should handle null values in map', () {
        // Arrange
        final map = <String, dynamic>{
          'supplierId': null,
          'name': null,
          'description': null,
          'price': null,
          'currency': null,
          'duration': null,
          'includes': null,
          'customizations': null,
          'photos': null,
          'isActive': null,
          'isFeatured': null,
          'bookingCount': null,
          'createdAt': null,
          'updatedAt': null,
        };
        const id = 'package-1';

        // Act
        final model = PackageModel.fromMap(map, id);

        // Assert
        expect(model.supplierId, equals(''));
        expect(model.name, equals(''));
        expect(model.price, equals(0));
        expect(model.currency, equals('KES'));
        expect(model.isActive, equals(true));
      });

      test('should parse customizations list', () {
        // Arrange
        final map = <String, dynamic>{
          'customizations': [
            {'name': 'Custom 1', 'price': 1000},
            {'name': 'Custom 2', 'price': 2000, 'description': 'Desc'},
          ],
        };
        const id = 'package-1';

        // Act
        final model = PackageModel.fromMap(map, id);

        // Assert
        expect(model.customizations.length, equals(2));
        expect(model.customizations[0].name, equals('Custom 1'));
        expect(model.customizations[0].price, equals(1000));
        expect(model.customizations[1].name, equals('Custom 2'));
        expect(model.customizations[1].description, equals('Desc'));
      });

      test('should handle empty customizations list', () {
        // Arrange
        final map = <String, dynamic>{'customizations': []};
        const id = 'package-1';

        // Act
        final model = PackageModel.fromMap(map, id);

        // Assert
        expect(model.customizations, isEmpty);
      });

      test('should parse includes list', () {
        // Arrange
        final map = <String, dynamic>{
          'includes': ['Item 1', 'Item 2', 'Item 3'],
        };
        const id = 'package-1';

        // Act
        final model = PackageModel.fromMap(map, id);

        // Assert
        expect(model.includes.length, equals(3));
        expect(model.includes, equals(['Item 1', 'Item 2', 'Item 3']));
      });

      test('should parse photos list', () {
        // Arrange
        final map = <String, dynamic>{
          'photos': ['photo1.jpg', 'photo2.jpg'],
        };
        const id = 'package-1';

        // Act
        final model = PackageModel.fromMap(map, id);

        // Assert
        expect(model.photos.length, equals(2));
        expect(model.photos, equals(['photo1.jpg', 'photo2.jpg']));
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map with all fields', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map, isA<Map<String, dynamic>>());
        expect(map['supplierId'], equals('supplier-1'));
        expect(map['name'], equals('Wedding Premium Package'));
        expect(map['description'], equals('Full day wedding photography coverage'));
        expect(map['price'], equals(50000));
        expect(map['currency'], equals('KES'));
        expect(map['duration'], equals('8 hours'));
        expect(map['includes'], equals(['Digital photos', 'Photo album', 'Drone shots']));
        expect(map['photos'], equals(['package1.jpg', 'package2.jpg']));
        expect(map['isActive'], equals(true));
        expect(map['isFeatured'], equals(false));
        expect(map['bookingCount'], equals(5));
      });

      test('should not include id field in map', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.containsKey('id'), isFalse);
      });

      test('should convert timestamps', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });

      test('should convert customizations to list of maps', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['customizations'], isA<List>());
        final customizations = map['customizations'] as List;
        expect(customizations.length, equals(2));
        expect(customizations[0], isA<Map<String, dynamic>>());
        expect(customizations[0]['name'], equals('Extra Hour'));
        expect(customizations[1]['name'], equals('Video Highlights'));
      });

      test('should handle empty lists', () {
        // Arrange
        final model = PackageModel(
          id: 'package-1',
          supplierId: 'supplier-1',
          name: 'Basic Package',
          description: 'Simple',
          price: 10000,
          currency: 'KES',
          duration: '1 hour',
          includes: const [],
          customizations: const [],
          photos: const [],
          isActive: true,
          isFeatured: false,
          bookingCount: 0,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['includes'], equals([]));
        expect(map['customizations'], equals([]));
        expect(map['photos'], equals([]));
      });
    });

    group('toEntity', () {
      test('should convert to PackageEntity', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity, isA<PackageEntity>());
        expect(entity.id, equals('package-1'));
        expect(entity.supplierId, equals('supplier-1'));
        expect(entity.name, equals('Wedding Premium Package'));
        expect(entity.description, equals('Full day wedding photography coverage'));
        expect(entity.price, equals(50000));
        expect(entity.currency, equals('KES'));
      });

      test('should preserve all field values', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.duration, equals('8 hours'));
        expect(entity.includes, equals(['Digital photos', 'Photo album', 'Drone shots']));
        expect(entity.customizations.length, equals(2));
        expect(entity.photos, equals(['package1.jpg', 'package2.jpg']));
        expect(entity.isActive, equals(true));
        expect(entity.isFeatured, equals(false));
        expect(entity.bookingCount, equals(5));
      });
    });

    group('copyWith', () {
      test('should create new instance with updated name', () {
        // Arrange
        final model = createTestPackageModel();
        const newName = 'Updated Package Name';

        // Act
        final updated = model.copyWith(name: newName);

        // Assert
        expect(updated.name, equals(newName));
        expect(updated.supplierId, equals(model.supplierId));
      });

      test('should create new instance with updated price', () {
        // Arrange
        final model = createTestPackageModel();
        const newPrice = 75000;

        // Act
        final updated = model.copyWith(price: newPrice);

        // Assert
        expect(updated.price, equals(newPrice));
        expect(updated.name, equals(model.name));
      });

      test('should create new instance with updated isActive', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final updated = model.copyWith(isActive: false);

        // Assert
        expect(updated.isActive, equals(false));
        expect(model.isActive, equals(true));
      });

      test('should create new instance with updated customizations', () {
        // Arrange
        final model = createTestPackageModel();
        const newCustomizations = [
          PackageCustomizationModel(name: 'New Custom', price: 3000),
        ];

        // Act
        final updated = model.copyWith(customizations: newCustomizations);

        // Assert
        expect(updated.customizations.length, equals(1));
        expect(updated.customizations[0].name, equals('New Custom'));
      });

      test('should return same values when no parameters provided', () {
        // Arrange
        final model = createTestPackageModel();

        // Act
        final updated = model.copyWith();

        // Assert
        expect(updated.name, equals(model.name));
        expect(updated.price, equals(model.price));
        expect(updated.isActive, equals(model.isActive));
      });
    });

    group('equality', () {
      test('should be equal when all fields are the same', () {
        // Arrange
        final model1 = createTestPackageModel();
        final model2 = createTestPackageModel();

        // Assert
        expect(model1, equals(model2));
      });

      test('should not be equal when name differs', () {
        // Arrange
        final model1 = createTestPackageModel();
        final model2 = model1.copyWith(name: 'Different Name');

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should not be equal when price differs', () {
        // Arrange
        final model1 = createTestPackageModel();
        final model2 = model1.copyWith(price: 60000);

        // Assert
        expect(model1, isNot(equals(model2)));
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity through Firestore conversion', () {
        // Arrange
        final original = createTestPackageModel();

        // Act
        final map = original.toFirestore();
        final converted = PackageModel.fromMap(map, original.id);

        // Assert
        expect(converted.name, equals(original.name));
        expect(converted.price, equals(original.price));
        expect(converted.duration, equals(original.duration));
        expect(converted.includes, equals(original.includes));
        expect(converted.customizations.length, equals(original.customizations.length));
      });

      test('should maintain data integrity through entity conversion', () {
        // Arrange
        final original = createTestPackageModel();

        // Act
        final entity = original.toEntity();
        final converted = PackageModel.fromEntity(entity);

        // Assert
        expect(converted.name, equals(original.name));
        expect(converted.price, equals(original.price));
        expect(converted.isActive, equals(original.isActive));
      });
    });

    group('edge cases', () {
      test('should handle zero price', () {
        // Arrange
        final model = PackageModel(
          id: 'package-1',
          supplierId: 'supplier-1',
          name: 'Free Package',
          description: 'Free',
          price: 0,
          currency: 'KES',
          duration: '1 hour',
          includes: const [],
          customizations: const [],
          photos: const [],
          isActive: true,
          isFeatured: false,
          bookingCount: 0,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        );

        // Act
        final map = model.toFirestore();
        final converted = PackageModel.fromMap(map, model.id);

        // Assert
        expect(converted.price, equals(0));
      });

      test('should handle large booking count', () {
        // Arrange
        final model = createTestPackageModel().copyWith(bookingCount: 99999);

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.bookingCount, equals(99999));
      });

      test('should handle very long description', () {
        // Arrange
        final longDesc = 'A' * 5000;
        final model = createTestPackageModel().copyWith(description: longDesc);

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['description'].toString().length, equals(5000));
      });

      test('should handle special characters in name', () {
        // Arrange
        const specialName = 'Package @ #\$% & *';
        final model = createTestPackageModel().copyWith(name: specialName);

        // Act
        final entity = model.toEntity();
        final converted = PackageModel.fromEntity(entity);

        // Assert
        expect(converted.name, equals(specialName));
      });

      test('should handle multiple customizations', () {
        // Arrange
        final manyCustomizations = List.generate(
          20,
          (i) => PackageCustomizationModel(
            name: 'Customization $i',
            price: i * 1000,
          ),
        );
        final model = createTestPackageModel().copyWith(
          customizations: manyCustomizations,
        );

        // Act
        final map = model.toFirestore();
        final converted = PackageModel.fromMap(map, model.id);

        // Assert
        expect(converted.customizations.length, equals(20));
      });
    });
  });
}
