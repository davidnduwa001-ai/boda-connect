import 'package:boda_connect/features/supplier/data/models/day_hours_model.dart';
import 'package:boda_connect/features/supplier/data/models/working_hours_model.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkingHoursModel', () {
    late Map<String, DayHoursEntity> testSchedule;
    late WorkingHoursModel testWorkingHoursModel;

    setUp(() {
      testSchedule = {
        'monday': const DayHoursModel(
          isOpen: true,
          openTime: '09:00',
          closeTime: '18:00',
        ),
        'tuesday': const DayHoursModel(
          isOpen: true,
          openTime: '09:00',
          closeTime: '18:00',
        ),
        'wednesday': const DayHoursModel(
          isOpen: true,
          openTime: '09:00',
          closeTime: '18:00',
        ),
        'thursday': const DayHoursModel(
          isOpen: true,
          openTime: '09:00',
          closeTime: '18:00',
        ),
        'friday': const DayHoursModel(
          isOpen: true,
          openTime: '09:00',
          closeTime: '18:00',
        ),
        'saturday': const DayHoursModel(
          isOpen: true,
          openTime: '10:00',
          closeTime: '14:00',
        ),
        'sunday': const DayHoursModel(
          isOpen: false,
          openTime: null,
          closeTime: null,
        ),
      };

      testWorkingHoursModel = WorkingHoursModel(schedule: testSchedule);
    });

    group('fromEntity', () {
      test('should create WorkingHoursModel from WorkingHoursEntity', () {
        // Arrange
        final entity = WorkingHoursEntity(schedule: testSchedule);

        // Act
        final model = WorkingHoursModel.fromEntity(entity);

        // Assert
        expect(model, isA<WorkingHoursModel>());
        expect(model.schedule.length, equals(7));
        expect(model.schedule['monday'], isA<DayHoursModel>());
        expect(model.schedule['sunday'], isA<DayHoursModel>());
      });

      test('should convert all day hours entities to models', () {
        // Arrange
        final entity = WorkingHoursEntity(schedule: testSchedule);

        // Act
        final model = WorkingHoursModel.fromEntity(entity);

        // Assert
        for (final day in testSchedule.keys) {
          expect(model.schedule[day], isA<DayHoursModel>());
          expect(
            model.schedule[day]?.isOpen,
            equals(testSchedule[day]?.isOpen),
          );
        }
      });

      test('should handle empty schedule', () {
        // Arrange
        final entity = WorkingHoursEntity(schedule: {});

        // Act
        final model = WorkingHoursModel.fromEntity(entity);

        // Assert
        expect(model.schedule.isEmpty, isTrue);
      });

      test('should handle partial week schedule', () {
        // Arrange
        final partialSchedule = {
          'monday': const DayHoursModel(isOpen: true, openTime: '09:00'),
          'friday': const DayHoursModel(isOpen: true, openTime: '09:00'),
        };
        final entity = WorkingHoursEntity(schedule: partialSchedule);

        // Act
        final model = WorkingHoursModel.fromEntity(entity);

        // Assert
        expect(model.schedule.length, equals(2));
        expect(model.schedule.containsKey('monday'), isTrue);
        expect(model.schedule.containsKey('friday'), isTrue);
        expect(model.schedule.containsKey('tuesday'), isFalse);
      });

      test('should preserve day hours data during conversion', () {
        // Arrange
        final schedule = {
          'monday': const DayHoursModel(
            isOpen: true,
            openTime: '08:00',
            closeTime: '17:00',
          ),
        };
        final entity = WorkingHoursEntity(schedule: schedule);

        // Act
        final model = WorkingHoursModel.fromEntity(entity);

        // Assert
        final monday = model.schedule['monday'] as DayHoursModel;
        expect(monday.isOpen, equals(true));
        expect(monday.openTime, equals('08:00'));
        expect(monday.closeTime, equals('17:00'));
      });
    });

    group('fromFirestore', () {
      test('should create WorkingHoursModel from Firestore map', () {
        // Arrange
        final map = <String, dynamic>{
          'monday': {
            'isOpen': true,
            'openTime': '09:00',
            'closeTime': '18:00',
          },
          'tuesday': {
            'isOpen': true,
            'openTime': '09:00',
            'closeTime': '18:00',
          },
          'sunday': {
            'isOpen': false,
          },
        };

        // Act
        final model = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(model, isA<WorkingHoursModel>());
        expect(model.schedule.length, equals(3));
        expect(model.schedule['monday'], isA<DayHoursModel>());
        expect(model.schedule['tuesday'], isA<DayHoursModel>());
        expect(model.schedule['sunday'], isA<DayHoursModel>());
      });

      test('should parse all days correctly', () {
        // Arrange
        final map = <String, dynamic>{
          'monday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '18:00'},
          'tuesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '18:00'},
          'wednesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '18:00'},
          'thursday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '18:00'},
          'friday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '18:00'},
          'saturday': {'isOpen': true, 'openTime': '10:00', 'closeTime': '14:00'},
          'sunday': {'isOpen': false},
        };

        // Act
        final model = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(model.schedule.length, equals(7));
        expect(model.schedule['monday']?.isOpen, equals(true));
        expect(model.schedule['sunday']?.isOpen, equals(false));
      });

      test('should handle empty map', () {
        // Arrange
        final map = <String, dynamic>{};

        // Act
        final model = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(model.schedule.isEmpty, isTrue);
      });

      test('should skip non-map values', () {
        // Arrange
        final map = <String, dynamic>{
          'monday': {'isOpen': true},
          'invalid': 'not a map',
          'tuesday': {'isOpen': false},
        };

        // Act
        final model = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(model.schedule.length, equals(2));
        expect(model.schedule.containsKey('monday'), isTrue);
        expect(model.schedule.containsKey('tuesday'), isTrue);
        expect(model.schedule.containsKey('invalid'), isFalse);
      });

      test('should handle nested day hours data', () {
        // Arrange
        final map = <String, dynamic>{
          'monday': {
            'isOpen': true,
            'openTime': '08:30',
            'closeTime': '20:00',
          },
        };

        // Act
        final model = WorkingHoursModel.fromFirestore(map);

        // Assert
        final monday = model.schedule['monday'];
        expect(monday?.isOpen, equals(true));
        expect(monday?.openTime, equals('08:30'));
        expect(monday?.closeTime, equals('20:00'));
      });

      test('should handle partial week data', () {
        // Arrange
        final map = <String, dynamic>{
          'monday': {'isOpen': true},
          'wednesday': {'isOpen': true},
          'friday': {'isOpen': false},
        };

        // Act
        final model = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(model.schedule.length, equals(3));
        expect(model.schedule.containsKey('tuesday'), isFalse);
        expect(model.schedule.containsKey('thursday'), isFalse);
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map', () {
        // Act
        final map = testWorkingHoursModel.toFirestore();

        // Assert
        expect(map, isA<Map<String, dynamic>>());
        expect(map.length, equals(7));
        expect(map['monday'], isA<Map<String, dynamic>>());
        expect(map['sunday'], isA<Map<String, dynamic>>());
      });

      test('should convert all day hours to maps', () {
        // Act
        final map = testWorkingHoursModel.toFirestore();

        // Assert
        for (final day in testSchedule.keys) {
          expect(map[day], isA<Map<String, dynamic>>());
          final dayMap = map[day] as Map<String, dynamic>;
          expect(dayMap.containsKey('isOpen'), isTrue);
        }
      });

      test('should preserve day hours data', () {
        // Act
        final map = testWorkingHoursModel.toFirestore();

        // Assert
        final mondayMap = map['monday'] as Map<String, dynamic>;
        expect(mondayMap['isOpen'], equals(true));
        expect(mondayMap['openTime'], equals('09:00'));
        expect(mondayMap['closeTime'], equals('18:00'));

        final sundayMap = map['sunday'] as Map<String, dynamic>;
        expect(sundayMap['isOpen'], equals(false));
      });

      test('should handle empty schedule', () {
        // Arrange
        final model = WorkingHoursModel(schedule: {});

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.isEmpty, isTrue);
      });

      test('should exclude null times from day maps', () {
        // Arrange
        final schedule = {
          'sunday': const DayHoursModel(
            isOpen: false,
            openTime: null,
            closeTime: null,
          ),
        };
        final model = WorkingHoursModel(schedule: schedule);

        // Act
        final map = model.toFirestore();

        // Assert
        final sundayMap = map['sunday'] as Map<String, dynamic>;
        expect(sundayMap['isOpen'], equals(false));
        expect(sundayMap.containsKey('openTime'), isFalse);
        expect(sundayMap.containsKey('closeTime'), isFalse);
      });

      test('should convert partial week schedule', () {
        // Arrange
        final partialSchedule = {
          'monday': const DayHoursModel(isOpen: true, openTime: '09:00'),
          'friday': const DayHoursModel(isOpen: false),
        };
        final model = WorkingHoursModel(schedule: partialSchedule);

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.length, equals(2));
        expect(map.containsKey('monday'), isTrue);
        expect(map.containsKey('friday'), isTrue);
      });
    });

    group('toEntity', () {
      test('should convert to WorkingHoursEntity', () {
        // Act
        final entity = testWorkingHoursModel.toEntity();

        // Assert
        expect(entity, isA<WorkingHoursEntity>());
        expect(entity.schedule.length, equals(7));
      });

      test('should preserve schedule data', () {
        // Act
        final entity = testWorkingHoursModel.toEntity();

        // Assert
        expect(entity.schedule['monday']?.isOpen, equals(true));
        expect(entity.schedule['monday']?.openTime, equals('09:00'));
        expect(entity.schedule['sunday']?.isOpen, equals(false));
      });

      test('should handle empty schedule', () {
        // Arrange
        final model = WorkingHoursModel(schedule: {});

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.schedule.isEmpty, isTrue);
      });
    });

    group('copyWith', () {
      test('should create new instance with updated schedule', () {
        // Arrange
        final newSchedule = {
          'monday': const DayHoursModel(
            isOpen: true,
            openTime: '08:00',
            closeTime: '17:00',
          ),
        };

        // Act
        final updated = testWorkingHoursModel.copyWith(schedule: newSchedule);

        // Assert
        expect(updated.schedule.length, equals(1));
        expect(updated.schedule['monday']?.openTime, equals('08:00'));
        expect(updated, isNot(equals(testWorkingHoursModel)));
      });

      test('should return same values when no parameters provided', () {
        // Act
        final updated = testWorkingHoursModel.copyWith();

        // Assert
        expect(updated.schedule.length, equals(testSchedule.length));
        expect(updated.schedule['monday'], equals(testSchedule['monday']));
      });
    });

    group('equality', () {
      test('should be equal when schedules are the same', () {
        // Arrange
        final model1 = WorkingHoursModel(schedule: testSchedule);
        final model2 = WorkingHoursModel(schedule: testSchedule);

        // Assert
        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
      });

      test('should not be equal when schedules differ', () {
        // Arrange
        final model1 = WorkingHoursModel(schedule: testSchedule);
        final differentSchedule = {
          'monday': const DayHoursModel(isOpen: false),
        };
        final model2 = WorkingHoursModel(schedule: differentSchedule);

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should be equal with empty schedules', () {
        // Arrange
        final model1 = WorkingHoursModel(schedule: {});
        final model2 = WorkingHoursModel(schedule: {});

        // Assert
        expect(model1, equals(model2));
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity through Firestore conversion', () {
        // Arrange
        final original = WorkingHoursModel(schedule: testSchedule);

        // Act
        final map = original.toFirestore();
        final converted = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(converted.schedule.length, equals(original.schedule.length));
        for (final day in testSchedule.keys) {
          expect(
            converted.schedule[day]?.isOpen,
            equals(original.schedule[day]?.isOpen),
          );
          expect(
            converted.schedule[day]?.openTime,
            equals(original.schedule[day]?.openTime),
          );
          expect(
            converted.schedule[day]?.closeTime,
            equals(original.schedule[day]?.closeTime),
          );
        }
      });

      test('should maintain data integrity through entity conversion', () {
        // Arrange
        final original = WorkingHoursModel(schedule: testSchedule);

        // Act
        final entity = original.toEntity();
        final converted = WorkingHoursModel.fromEntity(entity);

        // Assert
        expect(converted.schedule.length, equals(original.schedule.length));
        for (final day in testSchedule.keys) {
          expect(
            converted.schedule[day]?.isOpen,
            equals(original.schedule[day]?.isOpen),
          );
        }
      });

      test('should handle empty schedule in round-trip', () {
        // Arrange
        final original = WorkingHoursModel(schedule: {});

        // Act
        final map = original.toFirestore();
        final converted = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(converted.schedule.isEmpty, isTrue);
      });
    });

    group('edge cases', () {
      test('should handle 24/7 operation', () {
        // Arrange
        final alwaysOpenSchedule = <String, DayHoursEntity>{};
        for (final day in [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday'
        ]) {
          alwaysOpenSchedule[day] = const DayHoursModel(
            isOpen: true,
            openTime: '00:00',
            closeTime: '23:59',
          );
        }
        final model = WorkingHoursModel(schedule: alwaysOpenSchedule);

        // Act
        final map = model.toFirestore();
        final converted = WorkingHoursModel.fromFirestore(map);

        // Assert
        for (final day in alwaysOpenSchedule.keys) {
          expect(converted.schedule[day]?.isOpen, equals(true));
          expect(converted.schedule[day]?.openTime, equals('00:00'));
          expect(converted.schedule[day]?.closeTime, equals('23:59'));
        }
      });

      test('should handle completely closed schedule', () {
        // Arrange
        final closedSchedule = <String, DayHoursEntity>{};
        for (final day in [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday'
        ]) {
          closedSchedule[day] = const DayHoursModel(isOpen: false);
        }
        final model = WorkingHoursModel(schedule: closedSchedule);

        // Act
        final entity = model.toEntity();

        // Assert
        for (final day in closedSchedule.keys) {
          expect(entity.schedule[day]?.isOpen, equals(false));
        }
      });

      test('should handle mixed schedule with different times', () {
        // Arrange
        final mixedSchedule = {
          'monday': const DayHoursModel(
            isOpen: true,
            openTime: '09:00',
            closeTime: '18:00',
          ),
          'tuesday': const DayHoursModel(
            isOpen: true,
            openTime: '10:00',
            closeTime: '20:00',
          ),
          'wednesday': const DayHoursModel(
            isOpen: true,
            openTime: '08:00',
            closeTime: '16:00',
          ),
          'sunday': const DayHoursModel(isOpen: false),
        };
        final model = WorkingHoursModel(schedule: mixedSchedule);

        // Act
        final map = model.toFirestore();
        final converted = WorkingHoursModel.fromFirestore(map);

        // Assert
        expect(converted.schedule['monday']?.openTime, equals('09:00'));
        expect(converted.schedule['tuesday']?.openTime, equals('10:00'));
        expect(converted.schedule['wednesday']?.openTime, equals('08:00'));
        expect(converted.schedule['sunday']?.isOpen, equals(false));
      });
    });
  });
}
