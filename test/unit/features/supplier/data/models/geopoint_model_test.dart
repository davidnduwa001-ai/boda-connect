import 'package:boda_connect/features/supplier/data/models/geopoint_model.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoPointModel', () {
    const testLatitude = -8.8383;
    const testLongitude = 13.2344;

    late GeoPointModel testGeoPointModel;
    late GeoPoint testGeoPoint;

    setUp(() {
      testGeoPointModel = const GeoPointModel(
        latitude: testLatitude,
        longitude: testLongitude,
      );
      testGeoPoint = GeoPoint(testLatitude, testLongitude);
    });

    group('fromEntity', () {
      test('should create GeoPointModel from GeoPointEntity', () {
        // Arrange
        const entity = GeoPointEntity(
          latitude: testLatitude,
          longitude: testLongitude,
        );

        // Act
        final model = GeoPointModel.fromEntity(entity);

        // Assert
        expect(model, isA<GeoPointModel>());
        expect(model.latitude, equals(testLatitude));
        expect(model.longitude, equals(testLongitude));
      });

      test('should preserve exact latitude and longitude values', () {
        // Arrange
        const entity = GeoPointEntity(latitude: 0.0, longitude: 0.0);

        // Act
        final model = GeoPointModel.fromEntity(entity);

        // Assert
        expect(model.latitude, equals(0.0));
        expect(model.longitude, equals(0.0));
      });

      test('should handle negative coordinates', () {
        // Arrange
        const entity = GeoPointEntity(latitude: -90.0, longitude: -180.0);

        // Act
        final model = GeoPointModel.fromEntity(entity);

        // Assert
        expect(model.latitude, equals(-90.0));
        expect(model.longitude, equals(-180.0));
      });

      test('should handle extreme coordinate values', () {
        // Arrange
        const entity = GeoPointEntity(latitude: 90.0, longitude: 180.0);

        // Act
        final model = GeoPointModel.fromEntity(entity);

        // Assert
        expect(model.latitude, equals(90.0));
        expect(model.longitude, equals(180.0));
      });
    });

    group('fromGeoPoint', () {
      test('should create GeoPointModel from Firebase GeoPoint', () {
        // Act
        final model = GeoPointModel.fromGeoPoint(testGeoPoint);

        // Assert
        expect(model, isA<GeoPointModel>());
        expect(model.latitude, equals(testLatitude));
        expect(model.longitude, equals(testLongitude));
      });

      test('should handle zero coordinates from GeoPoint', () {
        // Arrange
        final geoPoint = GeoPoint(0.0, 0.0);

        // Act
        final model = GeoPointModel.fromGeoPoint(geoPoint);

        // Assert
        expect(model.latitude, equals(0.0));
        expect(model.longitude, equals(0.0));
      });

      test('should handle negative coordinates from GeoPoint', () {
        // Arrange
        final geoPoint = GeoPoint(-45.0, -90.0);

        // Act
        final model = GeoPointModel.fromGeoPoint(geoPoint);

        // Assert
        expect(model.latitude, equals(-45.0));
        expect(model.longitude, equals(-90.0));
      });
    });

    group('fromFirestore', () {
      test('should create GeoPointModel from map with geopoint field', () {
        // Arrange
        final map = <String, dynamic>{
          'geopoint': GeoPoint(testLatitude, testLongitude),
        };

        // Act
        final model = GeoPointModel.fromFirestore(map);

        // Assert
        expect(model.latitude, equals(testLatitude));
        expect(model.longitude, equals(testLongitude));
      });

      test('should create GeoPointModel from map with latitude/longitude fields',
          () {
        // Arrange
        final map = <String, dynamic>{
          'latitude': testLatitude,
          'longitude': testLongitude,
        };

        // Act
        final model = GeoPointModel.fromFirestore(map);

        // Assert
        expect(model.latitude, equals(testLatitude));
        expect(model.longitude, equals(testLongitude));
      });

      test('should handle int values for latitude and longitude', () {
        // Arrange
        final map = <String, dynamic>{
          'latitude': 10,
          'longitude': 20,
        };

        // Act
        final model = GeoPointModel.fromFirestore(map);

        // Assert
        expect(model.latitude, equals(10.0));
        expect(model.longitude, equals(20.0));
      });

      test('should return default values when fields are null', () {
        // Arrange
        final map = <String, dynamic>{
          'latitude': null,
          'longitude': null,
        };

        // Act
        final model = GeoPointModel.fromFirestore(map);

        // Assert
        expect(model.latitude, equals(0.0));
        expect(model.longitude, equals(0.0));
      });

      test('should return default values when map is empty', () {
        // Arrange
        final map = <String, dynamic>{};

        // Act
        final model = GeoPointModel.fromFirestore(map);

        // Assert
        expect(model.latitude, equals(0.0));
        expect(model.longitude, equals(0.0));
      });

      test('should handle partial data in map', () {
        // Arrange
        final map = <String, dynamic>{
          'latitude': testLatitude,
        };

        // Act
        final model = GeoPointModel.fromFirestore(map);

        // Assert
        expect(model.latitude, equals(testLatitude));
        expect(model.longitude, equals(0.0));
      });
    });

    group('toGeoPoint', () {
      test('should convert GeoPointModel to Firebase GeoPoint', () {
        // Act
        final geoPoint = testGeoPointModel.toGeoPoint();

        // Assert
        expect(geoPoint, isA<GeoPoint>());
        expect(geoPoint.latitude, equals(testLatitude));
        expect(geoPoint.longitude, equals(testLongitude));
      });

      test('should preserve coordinate precision', () {
        // Arrange
        const model = GeoPointModel(
          latitude: 12.345678,
          longitude: -98.765432,
        );

        // Act
        final geoPoint = model.toGeoPoint();

        // Assert
        expect(geoPoint.latitude, equals(12.345678));
        expect(geoPoint.longitude, equals(-98.765432));
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map with latitude and longitude', () {
        // Act
        final map = testGeoPointModel.toFirestore();

        // Assert
        expect(map, isA<Map<String, dynamic>>());
        expect(map['latitude'], equals(testLatitude));
        expect(map['longitude'], equals(testLongitude));
        expect(map.keys.length, equals(2));
      });

      test('should include zero values in map', () {
        // Arrange
        const model = GeoPointModel(latitude: 0.0, longitude: 0.0);

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['latitude'], equals(0.0));
        expect(map['longitude'], equals(0.0));
      });

      test('should preserve negative coordinates', () {
        // Arrange
        const model = GeoPointModel(latitude: -45.0, longitude: -90.0);

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['latitude'], equals(-45.0));
        expect(map['longitude'], equals(-90.0));
      });
    });

    group('toEntity', () {
      test('should convert to GeoPointEntity', () {
        // Act
        final entity = testGeoPointModel.toEntity();

        // Assert
        expect(entity, isA<GeoPointEntity>());
        expect(entity.latitude, equals(testLatitude));
        expect(entity.longitude, equals(testLongitude));
      });

      test('should preserve all coordinate values', () {
        // Arrange
        const model = GeoPointModel(latitude: 12.345, longitude: 67.890);

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.latitude, equals(12.345));
        expect(entity.longitude, equals(67.890));
      });
    });

    group('copyWith', () {
      test('should create new instance with updated latitude', () {
        // Arrange
        const newLatitude = 45.0;

        // Act
        final updated = testGeoPointModel.copyWith(latitude: newLatitude);

        // Assert
        expect(updated.latitude, equals(newLatitude));
        expect(updated.longitude, equals(testLongitude));
        expect(updated, isNot(equals(testGeoPointModel)));
      });

      test('should create new instance with updated longitude', () {
        // Arrange
        const newLongitude = 90.0;

        // Act
        final updated = testGeoPointModel.copyWith(longitude: newLongitude);

        // Assert
        expect(updated.latitude, equals(testLatitude));
        expect(updated.longitude, equals(newLongitude));
        expect(updated, isNot(equals(testGeoPointModel)));
      });

      test('should create new instance with both values updated', () {
        // Arrange
        const newLatitude = 10.0;
        const newLongitude = 20.0;

        // Act
        final updated = testGeoPointModel.copyWith(
          latitude: newLatitude,
          longitude: newLongitude,
        );

        // Assert
        expect(updated.latitude, equals(newLatitude));
        expect(updated.longitude, equals(newLongitude));
      });

      test('should return same values when no parameters provided', () {
        // Act
        final updated = testGeoPointModel.copyWith();

        // Assert
        expect(updated.latitude, equals(testLatitude));
        expect(updated.longitude, equals(testLongitude));
      });
    });

    group('equality', () {
      test('should be equal when latitude and longitude are the same', () {
        // Arrange
        const model1 = GeoPointModel(
          latitude: testLatitude,
          longitude: testLongitude,
        );
        const model2 = GeoPointModel(
          latitude: testLatitude,
          longitude: testLongitude,
        );

        // Assert
        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
      });

      test('should not be equal when latitude differs', () {
        // Arrange
        const model1 = GeoPointModel(latitude: 10.0, longitude: 20.0);
        const model2 = GeoPointModel(latitude: 11.0, longitude: 20.0);

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should not be equal when longitude differs', () {
        // Arrange
        const model1 = GeoPointModel(latitude: 10.0, longitude: 20.0);
        const model2 = GeoPointModel(latitude: 10.0, longitude: 21.0);

        // Assert
        expect(model1, isNot(equals(model2)));
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity through GeoPoint conversion', () {
        // Arrange
        const original = GeoPointModel(latitude: 12.3456, longitude: 78.9012);

        // Act
        final geoPoint = original.toGeoPoint();
        final converted = GeoPointModel.fromGeoPoint(geoPoint);

        // Assert
        expect(converted, equals(original));
      });

      test('should maintain data integrity through Firestore conversion', () {
        // Arrange
        const original = GeoPointModel(latitude: -12.34, longitude: 56.78);

        // Act
        final map = original.toFirestore();
        final converted = GeoPointModel.fromFirestore(map);

        // Assert
        expect(converted, equals(original));
      });

      test('should maintain data integrity through entity conversion', () {
        // Arrange
        const original = GeoPointModel(latitude: 0.123, longitude: -0.456);

        // Act
        final entity = original.toEntity();
        final converted = GeoPointModel.fromEntity(entity);

        // Assert
        expect(converted, equals(original));
      });
    });
  });
}
