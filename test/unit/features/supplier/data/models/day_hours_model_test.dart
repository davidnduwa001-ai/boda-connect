import 'package:boda_connect/features/supplier/data/models/day_hours_model.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DayHoursModel', () {
    const testOpenTime = '09:00';
    const testCloseTime = '18:00';

    late DayHoursModel testDayHoursModel;

    setUp(() {
      testDayHoursModel = const DayHoursModel(
        isOpen: true,
        openTime: testOpenTime,
        closeTime: testCloseTime,
      );
    });

    group('fromEntity', () {
      test('should create DayHoursModel from DayHoursEntity with all fields',
          () {
        // Arrange
        const entity = DayHoursEntity(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: testCloseTime,
        );

        // Act
        final model = DayHoursModel.fromEntity(entity);

        // Assert
        expect(model, isA<DayHoursModel>());
        expect(model.isOpen, equals(true));
        expect(model.openTime, equals(testOpenTime));
        expect(model.closeTime, equals(testCloseTime));
      });

      test('should handle entity with null times when closed', () {
        // Arrange
        const entity = DayHoursEntity(
          isOpen: false,
          openTime: null,
          closeTime: null,
        );

        // Act
        final model = DayHoursModel.fromEntity(entity);

        // Assert
        expect(model.isOpen, equals(false));
        expect(model.openTime, isNull);
        expect(model.closeTime, isNull);
      });

      test('should preserve exact time values', () {
        // Arrange
        const entity = DayHoursEntity(
          isOpen: true,
          openTime: '00:00',
          closeTime: '23:59',
        );

        // Act
        final model = DayHoursModel.fromEntity(entity);

        // Assert
        expect(model.openTime, equals('00:00'));
        expect(model.closeTime, equals('23:59'));
      });

      test('should handle entity with only openTime', () {
        // Arrange
        const entity = DayHoursEntity(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: null,
        );

        // Act
        final model = DayHoursModel.fromEntity(entity);

        // Assert
        expect(model.isOpen, equals(true));
        expect(model.openTime, equals(testOpenTime));
        expect(model.closeTime, isNull);
      });
    });

    group('fromFirestore', () {
      test('should create DayHoursModel from Firestore map with all fields',
          () {
        // Arrange
        final map = <String, dynamic>{
          'isOpen': true,
          'openTime': testOpenTime,
          'closeTime': testCloseTime,
        };

        // Act
        final model = DayHoursModel.fromFirestore(map);

        // Assert
        expect(model.isOpen, equals(true));
        expect(model.openTime, equals(testOpenTime));
        expect(model.closeTime, equals(testCloseTime));
      });

      test('should handle closed day with no times', () {
        // Arrange
        final map = <String, dynamic>{
          'isOpen': false,
        };

        // Act
        final model = DayHoursModel.fromFirestore(map);

        // Assert
        expect(model.isOpen, equals(false));
        expect(model.openTime, isNull);
        expect(model.closeTime, isNull);
      });

      test('should default to closed when isOpen is null', () {
        // Arrange
        final map = <String, dynamic>{
          'openTime': testOpenTime,
          'closeTime': testCloseTime,
        };

        // Act
        final model = DayHoursModel.fromFirestore(map);

        // Assert
        expect(model.isOpen, equals(false));
        expect(model.openTime, equals(testOpenTime));
        expect(model.closeTime, equals(testCloseTime));
      });

      test('should handle empty map', () {
        // Arrange
        final map = <String, dynamic>{};

        // Act
        final model = DayHoursModel.fromFirestore(map);

        // Assert
        expect(model.isOpen, equals(false));
        expect(model.openTime, isNull);
        expect(model.closeTime, isNull);
      });

      test('should handle null values in map', () {
        // Arrange
        final map = <String, dynamic>{
          'isOpen': null,
          'openTime': null,
          'closeTime': null,
        };

        // Act
        final model = DayHoursModel.fromFirestore(map);

        // Assert
        expect(model.isOpen, equals(false));
        expect(model.openTime, isNull);
        expect(model.closeTime, isNull);
      });

      test('should handle partial data with only openTime', () {
        // Arrange
        final map = <String, dynamic>{
          'isOpen': true,
          'openTime': testOpenTime,
        };

        // Act
        final model = DayHoursModel.fromFirestore(map);

        // Assert
        expect(model.isOpen, equals(true));
        expect(model.openTime, equals(testOpenTime));
        expect(model.closeTime, isNull);
      });

      test('should handle partial data with only closeTime', () {
        // Arrange
        final map = <String, dynamic>{
          'isOpen': true,
          'closeTime': testCloseTime,
        };

        // Act
        final model = DayHoursModel.fromFirestore(map);

        // Assert
        expect(model.isOpen, equals(true));
        expect(model.openTime, isNull);
        expect(model.closeTime, equals(testCloseTime));
      });

      test('should throw type error when isOpen is string instead of boolean', () {
        // Arrange - Firestore always serializes booleans correctly,
        // but test that invalid data throws as expected
        final map = <String, dynamic>{
          'isOpen': 'true',
          'openTime': testOpenTime,
          'closeTime': testCloseTime,
        };

        // Act & Assert - expect a type cast error
        expect(
          () => DayHoursModel.fromFirestore(map),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map with all fields', () {
        // Act
        final map = testDayHoursModel.toFirestore();

        // Assert
        expect(map, isA<Map<String, dynamic>>());
        expect(map['isOpen'], equals(true));
        expect(map['openTime'], equals(testOpenTime));
        expect(map['closeTime'], equals(testCloseTime));
      });

      test('should include isOpen even when false', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: false,
          openTime: null,
          closeTime: null,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['isOpen'], equals(false));
        expect(map.containsKey('openTime'), isFalse);
        expect(map.containsKey('closeTime'), isFalse);
      });

      test('should exclude null times from map', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: null,
          closeTime: null,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['isOpen'], equals(true));
        expect(map.containsKey('openTime'), isFalse);
        expect(map.containsKey('closeTime'), isFalse);
      });

      test('should include only openTime when closeTime is null', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: null,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['isOpen'], equals(true));
        expect(map['openTime'], equals(testOpenTime));
        expect(map.containsKey('closeTime'), isFalse);
      });

      test('should include only closeTime when openTime is null', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: null,
          closeTime: testCloseTime,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['isOpen'], equals(true));
        expect(map.containsKey('openTime'), isFalse);
        expect(map['closeTime'], equals(testCloseTime));
      });

      test('should preserve time format', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: '00:00',
          closeTime: '23:59',
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['openTime'], equals('00:00'));
        expect(map['closeTime'], equals('23:59'));
      });
    });

    group('toEntity', () {
      test('should convert to DayHoursEntity with all fields', () {
        // Act
        final entity = testDayHoursModel.toEntity();

        // Assert
        expect(entity, isA<DayHoursEntity>());
        expect(entity.isOpen, equals(true));
        expect(entity.openTime, equals(testOpenTime));
        expect(entity.closeTime, equals(testCloseTime));
      });

      test('should preserve null values', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: false,
          openTime: null,
          closeTime: null,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.isOpen, equals(false));
        expect(entity.openTime, isNull);
        expect(entity.closeTime, isNull);
      });

      test('should preserve partial values', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: null,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.isOpen, equals(true));
        expect(entity.openTime, equals(testOpenTime));
        expect(entity.closeTime, isNull);
      });
    });

    group('copyWith', () {
      test('should create new instance with updated isOpen', () {
        // Act
        final updated = testDayHoursModel.copyWith(isOpen: false);

        // Assert
        expect(updated.isOpen, equals(false));
        expect(updated.openTime, equals(testOpenTime));
        expect(updated.closeTime, equals(testCloseTime));
      });

      test('should create new instance with updated openTime', () {
        // Arrange
        const newOpenTime = '08:00';

        // Act
        final updated = testDayHoursModel.copyWith(openTime: newOpenTime);

        // Assert
        expect(updated.isOpen, equals(true));
        expect(updated.openTime, equals(newOpenTime));
        expect(updated.closeTime, equals(testCloseTime));
      });

      test('should create new instance with updated closeTime', () {
        // Arrange
        const newCloseTime = '20:00';

        // Act
        final updated = testDayHoursModel.copyWith(closeTime: newCloseTime);

        // Assert
        expect(updated.isOpen, equals(true));
        expect(updated.openTime, equals(testOpenTime));
        expect(updated.closeTime, equals(newCloseTime));
      });

      test('should create new instance with all fields updated', () {
        // Arrange
        const newIsOpen = false;
        const newOpenTime = '10:00';
        const newCloseTime = '22:00';

        // Act
        final updated = testDayHoursModel.copyWith(
          isOpen: newIsOpen,
          openTime: newOpenTime,
          closeTime: newCloseTime,
        );

        // Assert
        expect(updated.isOpen, equals(newIsOpen));
        expect(updated.openTime, equals(newOpenTime));
        expect(updated.closeTime, equals(newCloseTime));
      });

      test('should return same values when no parameters provided', () {
        // Act
        final updated = testDayHoursModel.copyWith();

        // Assert
        expect(updated.isOpen, equals(true));
        expect(updated.openTime, equals(testOpenTime));
        expect(updated.closeTime, equals(testCloseTime));
      });
    });

    group('equality', () {
      test('should be equal when all fields are the same', () {
        // Arrange
        const model1 = DayHoursModel(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: testCloseTime,
        );
        const model2 = DayHoursModel(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: testCloseTime,
        );

        // Assert
        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
      });

      test('should not be equal when isOpen differs', () {
        // Arrange
        const model1 = DayHoursModel(isOpen: true);
        const model2 = DayHoursModel(isOpen: false);

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should not be equal when openTime differs', () {
        // Arrange
        const model1 = DayHoursModel(isOpen: true, openTime: '09:00');
        const model2 = DayHoursModel(isOpen: true, openTime: '10:00');

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should not be equal when closeTime differs', () {
        // Arrange
        const model1 = DayHoursModel(isOpen: true, closeTime: '17:00');
        const model2 = DayHoursModel(isOpen: true, closeTime: '18:00');

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should be equal when both have null times', () {
        // Arrange
        const model1 = DayHoursModel(isOpen: false);
        const model2 = DayHoursModel(isOpen: false);

        // Assert
        expect(model1, equals(model2));
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity through Firestore conversion', () {
        // Arrange
        const original = DayHoursModel(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: testCloseTime,
        );

        // Act
        final map = original.toFirestore();
        final converted = DayHoursModel.fromFirestore(map);

        // Assert
        expect(converted, equals(original));
      });

      test('should maintain data integrity through entity conversion', () {
        // Arrange
        const original = DayHoursModel(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: testCloseTime,
        );

        // Act
        final entity = original.toEntity();
        final converted = DayHoursModel.fromEntity(entity);

        // Assert
        expect(converted, equals(original));
      });

      test('should handle closed day in round-trip conversion', () {
        // Arrange
        const original = DayHoursModel(
          isOpen: false,
          openTime: null,
          closeTime: null,
        );

        // Act
        final map = original.toFirestore();
        final converted = DayHoursModel.fromFirestore(map);

        // Assert
        expect(converted, equals(original));
      });

      test('should handle partial times in round-trip conversion', () {
        // Arrange
        const original = DayHoursModel(
          isOpen: true,
          openTime: testOpenTime,
          closeTime: null,
        );

        // Act
        final map = original.toFirestore();
        final converted = DayHoursModel.fromFirestore(map);

        // Assert
        expect(converted, equals(original));
      });
    });

    group('edge cases', () {
      test('should handle midnight times', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: '00:00',
          closeTime: '00:00',
        );

        // Act
        final map = model.toFirestore();
        final converted = DayHoursModel.fromFirestore(map);

        // Assert
        expect(converted, equals(model));
      });

      test('should handle 24-hour operation', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: '00:00',
          closeTime: '23:59',
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.isOpen, equals(true));
        expect(entity.openTime, equals('00:00'));
        expect(entity.closeTime, equals('23:59'));
      });

      test('should handle overnight hours', () {
        // Arrange
        const model = DayHoursModel(
          isOpen: true,
          openTime: '18:00',
          closeTime: '02:00',
        );

        // Act
        final map = model.toFirestore();
        final converted = DayHoursModel.fromFirestore(map);

        // Assert
        expect(converted.openTime, equals('18:00'));
        expect(converted.closeTime, equals('02:00'));
      });
    });
  });
}
