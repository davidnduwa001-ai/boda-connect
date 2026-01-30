import 'package:boda_connect/features/supplier/data/models/package_customization_model.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PackageCustomizationModel', () {
    const testName = 'Extra Hour';
    const testPrice = 5000;
    const testDescription = 'Additional hour of service';

    late PackageCustomizationModel testModel;

    setUp(() {
      testModel = const PackageCustomizationModel(
        name: testName,
        price: testPrice,
        description: testDescription,
      );
    });

    group('fromEntity', () {
      test(
          'should create PackageCustomizationModel from PackageCustomizationEntity with all fields',
          () {
        // Arrange
        const entity = PackageCustomizationEntity(
          name: testName,
          price: testPrice,
          description: testDescription,
        );

        // Act
        final model = PackageCustomizationModel.fromEntity(entity);

        // Assert
        expect(model, isA<PackageCustomizationModel>());
        expect(model.name, equals(testName));
        expect(model.price, equals(testPrice));
        expect(model.description, equals(testDescription));
      });

      test('should handle entity with null description', () {
        // Arrange
        const entity = PackageCustomizationEntity(
          name: testName,
          price: testPrice,
          description: null,
        );

        // Act
        final model = PackageCustomizationModel.fromEntity(entity);

        // Assert
        expect(model.name, equals(testName));
        expect(model.price, equals(testPrice));
        expect(model.description, isNull);
      });

      test('should preserve exact values', () {
        // Arrange
        const entity = PackageCustomizationEntity(
          name: 'Custom Service',
          price: 0,
          description: '',
        );

        // Act
        final model = PackageCustomizationModel.fromEntity(entity);

        // Assert
        expect(model.name, equals('Custom Service'));
        expect(model.price, equals(0));
        expect(model.description, equals(''));
      });

      test('should handle large price values', () {
        // Arrange
        const entity = PackageCustomizationEntity(
          name: testName,
          price: 999999999,
          description: testDescription,
        );

        // Act
        final model = PackageCustomizationModel.fromEntity(entity);

        // Assert
        expect(model.price, equals(999999999));
      });
    });

    group('fromFirestore', () {
      test('should create PackageCustomizationModel from Firestore map with all fields',
          () {
        // Arrange
        final map = <String, dynamic>{
          'name': testName,
          'price': testPrice,
          'description': testDescription,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals(testName));
        expect(model.price, equals(testPrice));
        expect(model.description, equals(testDescription));
      });

      test('should handle null description', () {
        // Arrange
        final map = <String, dynamic>{
          'name': testName,
          'price': testPrice,
          'description': null,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals(testName));
        expect(model.price, equals(testPrice));
        expect(model.description, isNull);
      });

      test('should use default values for missing fields', () {
        // Arrange
        final map = <String, dynamic>{};

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals(''));
        expect(model.price, equals(0));
        expect(model.description, isNull);
      });

      test('should handle null name', () {
        // Arrange
        final map = <String, dynamic>{
          'name': null,
          'price': testPrice,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals(''));
        expect(model.price, equals(testPrice));
      });

      test('should handle null price', () {
        // Arrange
        final map = <String, dynamic>{
          'name': testName,
          'price': null,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals(testName));
        expect(model.price, equals(0));
      });

      test('should handle partial data', () {
        // Arrange
        final map = <String, dynamic>{
          'name': testName,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals(testName));
        expect(model.price, equals(0));
        expect(model.description, isNull);
      });

      test('should handle zero price', () {
        // Arrange
        final map = <String, dynamic>{
          'name': 'Free Item',
          'price': 0,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals('Free Item'));
        expect(model.price, equals(0));
      });

      test('should handle negative price', () {
        // Arrange
        final map = <String, dynamic>{
          'name': 'Discount',
          'price': -1000,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.price, equals(-1000));
      });

      test('should handle empty string description', () {
        // Arrange
        final map = <String, dynamic>{
          'name': testName,
          'price': testPrice,
          'description': '',
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.description, equals(''));
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map with all fields', () {
        // Act
        final map = testModel.toFirestore();

        // Assert
        expect(map, isA<Map<String, dynamic>>());
        expect(map['name'], equals(testName));
        expect(map['price'], equals(testPrice));
        expect(map['description'], equals(testDescription));
      });

      test('should exclude null description from map', () {
        // Arrange
        const model = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: null,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['name'], equals(testName));
        expect(map['price'], equals(testPrice));
        expect(map.containsKey('description'), isFalse);
      });

      test('should include empty string description', () {
        // Arrange
        const model = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: '',
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.containsKey('description'), isTrue);
        expect(map['description'], equals(''));
      });

      test('should include zero price', () {
        // Arrange
        const model = PackageCustomizationModel(
          name: testName,
          price: 0,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['price'], equals(0));
      });

      test('should preserve negative price', () {
        // Arrange
        const model = PackageCustomizationModel(
          name: 'Discount',
          price: -500,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['price'], equals(-500));
      });

      test('should contain exactly three keys when all fields are present', () {
        // Act
        final map = testModel.toFirestore();

        // Assert
        expect(map.keys.length, equals(3));
        expect(map.containsKey('name'), isTrue);
        expect(map.containsKey('price'), isTrue);
        expect(map.containsKey('description'), isTrue);
      });

      test('should contain two keys when description is null', () {
        // Arrange
        const model = PackageCustomizationModel(
          name: testName,
          price: testPrice,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.keys.length, equals(2));
      });
    });

    group('toEntity', () {
      test('should convert to PackageCustomizationEntity with all fields', () {
        // Act
        final entity = testModel.toEntity();

        // Assert
        expect(entity, isA<PackageCustomizationEntity>());
        expect(entity.name, equals(testName));
        expect(entity.price, equals(testPrice));
        expect(entity.description, equals(testDescription));
      });

      test('should preserve null description', () {
        // Arrange
        const model = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: null,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.name, equals(testName));
        expect(entity.price, equals(testPrice));
        expect(entity.description, isNull);
      });

      test('should preserve all values', () {
        // Arrange
        const model = PackageCustomizationModel(
          name: 'Special',
          price: 12345,
          description: 'Very special item',
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.name, equals('Special'));
        expect(entity.price, equals(12345));
        expect(entity.description, equals('Very special item'));
      });
    });

    group('copyWith', () {
      test('should create new instance with updated name', () {
        // Arrange
        const newName = 'Updated Name';

        // Act
        final updated = testModel.copyWith(name: newName);

        // Assert
        expect(updated.name, equals(newName));
        expect(updated.price, equals(testPrice));
        expect(updated.description, equals(testDescription));
      });

      test('should create new instance with updated price', () {
        // Arrange
        const newPrice = 10000;

        // Act
        final updated = testModel.copyWith(price: newPrice);

        // Assert
        expect(updated.name, equals(testName));
        expect(updated.price, equals(newPrice));
        expect(updated.description, equals(testDescription));
      });

      test('should create new instance with updated description', () {
        // Arrange
        const newDescription = 'New description';

        // Act
        final updated = testModel.copyWith(description: newDescription);

        // Assert
        expect(updated.name, equals(testName));
        expect(updated.price, equals(testPrice));
        expect(updated.description, equals(newDescription));
      });

      test('should create new instance with all fields updated', () {
        // Arrange
        const newName = 'New Name';
        const newPrice = 7500;
        const newDescription = 'New Description';

        // Act
        final updated = testModel.copyWith(
          name: newName,
          price: newPrice,
          description: newDescription,
        );

        // Assert
        expect(updated.name, equals(newName));
        expect(updated.price, equals(newPrice));
        expect(updated.description, equals(newDescription));
      });

      test('should return same values when no parameters provided', () {
        // Act
        final updated = testModel.copyWith();

        // Assert
        expect(updated.name, equals(testName));
        expect(updated.price, equals(testPrice));
        expect(updated.description, equals(testDescription));
      });

      test('should allow setting price to zero', () {
        // Act
        final updated = testModel.copyWith(price: 0);

        // Assert
        expect(updated.price, equals(0));
      });
    });

    group('equality', () {
      test('should be equal when all fields are the same', () {
        // Arrange
        const model1 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: testDescription,
        );
        const model2 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: testDescription,
        );

        // Assert
        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
      });

      test('should not be equal when name differs', () {
        // Arrange
        const model1 = PackageCustomizationModel(name: 'Name1', price: 100);
        const model2 = PackageCustomizationModel(name: 'Name2', price: 100);

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should not be equal when price differs', () {
        // Arrange
        const model1 = PackageCustomizationModel(name: testName, price: 100);
        const model2 = PackageCustomizationModel(name: testName, price: 200);

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should not be equal when description differs', () {
        // Arrange
        const model1 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: 'Desc1',
        );
        const model2 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: 'Desc2',
        );

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should be equal when both have null description', () {
        // Arrange
        const model1 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
        );
        const model2 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
        );

        // Assert
        expect(model1, equals(model2));
      });

      test('should not be equal when one has null description', () {
        // Arrange
        const model1 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: testDescription,
        );
        const model2 = PackageCustomizationModel(
          name: testName,
          price: testPrice,
        );

        // Assert
        expect(model1, isNot(equals(model2)));
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity through Firestore conversion', () {
        // Arrange
        const original = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: testDescription,
        );

        // Act
        final map = original.toFirestore();
        final converted = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(converted, equals(original));
      });

      test('should maintain data integrity through entity conversion', () {
        // Arrange
        const original = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: testDescription,
        );

        // Act
        final entity = original.toEntity();
        final converted = PackageCustomizationModel.fromEntity(entity);

        // Assert
        expect(converted, equals(original));
      });

      test('should handle null description in round-trip conversion', () {
        // Arrange
        const original = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: null,
        );

        // Act
        final map = original.toFirestore();
        final converted = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(converted.name, equals(testName));
        expect(converted.price, equals(testPrice));
        expect(converted.description, isNull);
      });

      test('should maintain zero price in round-trip', () {
        // Arrange
        const original = PackageCustomizationModel(
          name: 'Free',
          price: 0,
        );

        // Act
        final entity = original.toEntity();
        final converted = PackageCustomizationModel.fromEntity(entity);

        // Assert
        expect(converted.price, equals(0));
      });
    });

    group('edge cases', () {
      test('should handle very long name', () {
        // Arrange
        final longName = 'A' * 1000;
        final map = <String, dynamic>{
          'name': longName,
          'price': testPrice,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name.length, equals(1000));
      });

      test('should handle very long description', () {
        // Arrange
        final longDescription = 'B' * 5000;
        final model = PackageCustomizationModel(
          name: testName,
          price: testPrice,
          description: longDescription,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['description'].toString().length, equals(5000));
      });

      test('should handle special characters in name', () {
        // Arrange
        const specialName = 'Extra @ #\$% & *';
        final map = <String, dynamic>{
          'name': specialName,
          'price': testPrice,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.name, equals(specialName));
      });

      test('should handle unicode characters', () {
        // Arrange
        const unicodeName = 'Extra 时间 ⏰';
        const model = PackageCustomizationModel(
          name: unicodeName,
          price: testPrice,
        );

        // Act
        final entity = model.toEntity();
        final converted = PackageCustomizationModel.fromEntity(entity);

        // Assert
        expect(converted.name, equals(unicodeName));
      });

      test('should handle maximum integer price', () {
        // Arrange
        const maxInt = 9223372036854775807;
        final map = <String, dynamic>{
          'name': testName,
          'price': maxInt,
        };

        // Act
        final model = PackageCustomizationModel.fromFirestore(map);

        // Assert
        expect(model.price, equals(maxInt));
      });
    });
  });
}
