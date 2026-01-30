import 'package:boda_connect/features/supplier/data/models/geopoint_model.dart';
import 'package:boda_connect/features/supplier/data/models/location_model.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocationModel', () {
    const testCity = 'Luanda';
    const testProvince = 'Luanda';
    const testCountry = 'Angola';
    const testAddress = 'Rua 1 de Maio, 123';
    const testLatitude = -8.8383;
    const testLongitude = 13.2344;

    late LocationModel testLocationModel;
    late GeoPointModel testGeoPoint;

    setUp(() {
      testGeoPoint = const GeoPointModel(
        latitude: testLatitude,
        longitude: testLongitude,
      );
      testLocationModel = LocationModel(
        city: testCity,
        province: testProvince,
        country: testCountry,
        address: testAddress,
        geopoint: testGeoPoint,
      );
    });

    group('fromEntity', () {
      test('should create LocationModel from LocationEntity with all fields',
          () {
        // Arrange
        const geoPointEntity = GeoPointEntity(
          latitude: testLatitude,
          longitude: testLongitude,
        );
        const entity = LocationEntity(
          city: testCity,
          province: testProvince,
          country: testCountry,
          address: testAddress,
          geopoint: geoPointEntity,
        );

        // Act
        final model = LocationModel.fromEntity(entity);

        // Assert
        expect(model, isA<LocationModel>());
        expect(model.city, equals(testCity));
        expect(model.province, equals(testProvince));
        expect(model.country, equals(testCountry));
        expect(model.address, equals(testAddress));
        expect(model.geopoint, isA<GeoPointModel>());
        expect(model.geopoint?.latitude, equals(testLatitude));
        expect(model.geopoint?.longitude, equals(testLongitude));
      });

      test('should handle entity with null geopoint', () {
        // Arrange
        const entity = LocationEntity(
          city: testCity,
          province: testProvince,
          country: testCountry,
          address: testAddress,
          geopoint: null,
        );

        // Act
        final model = LocationModel.fromEntity(entity);

        // Assert
        expect(model.city, equals(testCity));
        expect(model.geopoint, isNull);
      });

      test('should handle entity with null optional fields', () {
        // Arrange
        const entity = LocationEntity(
          city: null,
          province: null,
          country: null,
          address: null,
          geopoint: null,
        );

        // Act
        final model = LocationModel.fromEntity(entity);

        // Assert
        expect(model.city, isNull);
        expect(model.province, isNull);
        expect(model.country, isNull);
        expect(model.address, isNull);
        expect(model.geopoint, isNull);
      });

      test('should convert geopoint entity to model', () {
        // Arrange
        const geoPointEntity = GeoPointEntity(latitude: 10.0, longitude: 20.0);
        const entity = LocationEntity(geopoint: geoPointEntity);

        // Act
        final model = LocationModel.fromEntity(entity);

        // Assert
        expect(model.geopoint, isA<GeoPointModel>());
        expect(model.geopoint?.latitude, equals(10.0));
        expect(model.geopoint?.longitude, equals(20.0));
      });
    });

    group('fromFirestore', () {
      test('should create LocationModel from Firestore map with all fields',
          () {
        // Arrange
        final map = <String, dynamic>{
          'city': testCity,
          'province': testProvince,
          'country': testCountry,
          'address': testAddress,
          'geopoint': GeoPoint(testLatitude, testLongitude),
        };

        // Act
        final model = LocationModel.fromFirestore(map);

        // Assert
        expect(model.city, equals(testCity));
        expect(model.province, equals(testProvince));
        expect(model.country, equals(testCountry));
        expect(model.address, equals(testAddress));
        expect(model.geopoint, isNotNull);
        expect(model.geopoint?.latitude, equals(testLatitude));
        expect(model.geopoint?.longitude, equals(testLongitude));
      });

      test('should handle geopoint as Firebase GeoPoint type', () {
        // Arrange
        final map = <String, dynamic>{
          'city': testCity,
          'geopoint': GeoPoint(testLatitude, testLongitude),
        };

        // Act
        final model = LocationModel.fromFirestore(map);

        // Assert
        expect(model.geopoint, isA<GeoPointModel>());
        expect(model.geopoint?.latitude, equals(testLatitude));
        expect(model.geopoint?.longitude, equals(testLongitude));
      });

      test('should handle geopoint as Map type', () {
        // Arrange
        final map = <String, dynamic>{
          'city': testCity,
          'geopoint': {
            'latitude': testLatitude,
            'longitude': testLongitude,
          },
        };

        // Act
        final model = LocationModel.fromFirestore(map);

        // Assert
        expect(model.geopoint, isA<GeoPointModel>());
        expect(model.geopoint?.latitude, equals(testLatitude));
        expect(model.geopoint?.longitude, equals(testLongitude));
      });

      test('should handle null geopoint', () {
        // Arrange
        final map = <String, dynamic>{
          'city': testCity,
          'province': testProvince,
          'geopoint': null,
        };

        // Act
        final model = LocationModel.fromFirestore(map);

        // Assert
        expect(model.city, equals(testCity));
        expect(model.geopoint, isNull);
      });

      test('should handle null fields', () {
        // Arrange
        final map = <String, dynamic>{
          'city': null,
          'province': null,
          'country': null,
          'address': null,
          'geopoint': null,
        };

        // Act
        final model = LocationModel.fromFirestore(map);

        // Assert
        expect(model.city, isNull);
        expect(model.province, isNull);
        expect(model.country, isNull);
        expect(model.address, isNull);
        expect(model.geopoint, isNull);
      });

      test('should handle empty map', () {
        // Arrange
        final map = <String, dynamic>{};

        // Act
        final model = LocationModel.fromFirestore(map);

        // Assert
        expect(model.city, isNull);
        expect(model.province, isNull);
        expect(model.country, isNull);
        expect(model.address, isNull);
        expect(model.geopoint, isNull);
      });

      test('should handle partial data', () {
        // Arrange
        final map = <String, dynamic>{
          'city': testCity,
          'country': testCountry,
        };

        // Act
        final model = LocationModel.fromFirestore(map);

        // Assert
        expect(model.city, equals(testCity));
        expect(model.province, isNull);
        expect(model.country, equals(testCountry));
        expect(model.address, isNull);
        expect(model.geopoint, isNull);
      });
    });

    group('toFirestore', () {
      test('should convert to Firestore map with all fields', () {
        // Act
        final map = testLocationModel.toFirestore();

        // Assert
        expect(map, isA<Map<String, dynamic>>());
        expect(map['city'], equals(testCity));
        expect(map['province'], equals(testProvince));
        expect(map['country'], equals(testCountry));
        expect(map['address'], equals(testAddress));
        expect(map['geopoint'], isA<GeoPoint>());
      });

      test('should convert geopoint to Firebase GeoPoint', () {
        // Act
        final map = testLocationModel.toFirestore();

        // Assert
        final geoPoint = map['geopoint'] as GeoPoint;
        expect(geoPoint.latitude, equals(testLatitude));
        expect(geoPoint.longitude, equals(testLongitude));
      });

      test('should exclude null fields from map', () {
        // Arrange
        const model = LocationModel(
          city: testCity,
          province: null,
          country: null,
          address: null,
          geopoint: null,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.containsKey('city'), isTrue);
        expect(map.containsKey('province'), isFalse);
        expect(map.containsKey('country'), isFalse);
        expect(map.containsKey('address'), isFalse);
        expect(map.containsKey('geopoint'), isFalse);
      });

      test('should include all non-null fields', () {
        // Arrange
        final model = LocationModel(
          city: testCity,
          province: testProvince,
          country: null,
          address: testAddress,
          geopoint: testGeoPoint,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map['city'], equals(testCity));
        expect(map['province'], equals(testProvince));
        expect(map.containsKey('country'), isFalse);
        expect(map['address'], equals(testAddress));
        expect(map.containsKey('geopoint'), isTrue);
      });

      test('should return empty map when all fields are null', () {
        // Arrange
        const model = LocationModel(
          city: null,
          province: null,
          country: null,
          address: null,
          geopoint: null,
        );

        // Act
        final map = model.toFirestore();

        // Assert
        expect(map.isEmpty, isTrue);
      });
    });

    group('toEntity', () {
      test('should convert to LocationEntity with all fields', () {
        // Act
        final entity = testLocationModel.toEntity();

        // Assert
        expect(entity, isA<LocationEntity>());
        expect(entity.city, equals(testCity));
        expect(entity.province, equals(testProvince));
        expect(entity.country, equals(testCountry));
        expect(entity.address, equals(testAddress));
        expect(entity.geopoint, isNotNull);
        expect(entity.geopoint?.latitude, equals(testLatitude));
        expect(entity.geopoint?.longitude, equals(testLongitude));
      });

      test('should preserve null values', () {
        // Arrange
        const model = LocationModel(
          city: testCity,
          province: null,
          country: null,
          address: null,
          geopoint: null,
        );

        // Act
        final entity = model.toEntity();

        // Assert
        expect(entity.city, equals(testCity));
        expect(entity.province, isNull);
        expect(entity.country, isNull);
        expect(entity.address, isNull);
        expect(entity.geopoint, isNull);
      });
    });

    group('copyWith', () {
      test('should create new instance with updated city', () {
        // Arrange
        const newCity = 'Benguela';

        // Act
        final updated = testLocationModel.copyWith(city: newCity);

        // Assert
        expect(updated.city, equals(newCity));
        expect(updated.province, equals(testProvince));
        expect(updated.country, equals(testCountry));
        expect(updated.address, equals(testAddress));
        expect(updated.geopoint, equals(testGeoPoint));
      });

      test('should create new instance with updated province', () {
        // Arrange
        const newProvince = 'Benguela';

        // Act
        final updated = testLocationModel.copyWith(province: newProvince);

        // Assert
        expect(updated.province, equals(newProvince));
        expect(updated.city, equals(testCity));
      });

      test('should create new instance with updated country', () {
        // Arrange
        const newCountry = 'Portugal';

        // Act
        final updated = testLocationModel.copyWith(country: newCountry);

        // Assert
        expect(updated.country, equals(newCountry));
        expect(updated.city, equals(testCity));
      });

      test('should create new instance with updated address', () {
        // Arrange
        const newAddress = 'Rua 2, 456';

        // Act
        final updated = testLocationModel.copyWith(address: newAddress);

        // Assert
        expect(updated.address, equals(newAddress));
        expect(updated.city, equals(testCity));
      });

      test('should create new instance with updated geopoint', () {
        // Arrange
        const newGeoPoint = GeoPointModel(latitude: 10.0, longitude: 20.0);

        // Act
        final updated = testLocationModel.copyWith(geopoint: newGeoPoint);

        // Assert
        expect(updated.geopoint, equals(newGeoPoint));
        expect(updated.city, equals(testCity));
      });

      test('should create new instance with all fields updated', () {
        // Arrange
        const newCity = 'Benguela';
        const newProvince = 'Benguela';
        const newCountry = 'Angola';
        const newAddress = 'Rua Nova, 789';
        const newGeoPoint = GeoPointModel(latitude: 30.0, longitude: 40.0);

        // Act
        final updated = testLocationModel.copyWith(
          city: newCity,
          province: newProvince,
          country: newCountry,
          address: newAddress,
          geopoint: newGeoPoint,
        );

        // Assert
        expect(updated.city, equals(newCity));
        expect(updated.province, equals(newProvince));
        expect(updated.country, equals(newCountry));
        expect(updated.address, equals(newAddress));
        expect(updated.geopoint, equals(newGeoPoint));
      });

      test('should return same values when no parameters provided', () {
        // Act
        final updated = testLocationModel.copyWith();

        // Assert
        expect(updated.city, equals(testCity));
        expect(updated.province, equals(testProvince));
        expect(updated.country, equals(testCountry));
        expect(updated.address, equals(testAddress));
        expect(updated.geopoint, equals(testGeoPoint));
      });
    });

    group('equality', () {
      test('should be equal when all fields are the same', () {
        // Arrange
        final model1 = LocationModel(
          city: testCity,
          province: testProvince,
          country: testCountry,
          address: testAddress,
          geopoint: testGeoPoint,
        );
        final model2 = LocationModel(
          city: testCity,
          province: testProvince,
          country: testCountry,
          address: testAddress,
          geopoint: testGeoPoint,
        );

        // Assert
        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
      });

      test('should not be equal when city differs', () {
        // Arrange
        final model1 = const LocationModel(city: 'Luanda');
        final model2 = const LocationModel(city: 'Benguela');

        // Assert
        expect(model1, isNot(equals(model2)));
      });

      test('should not be equal when geopoint differs', () {
        // Arrange
        final model1 = const LocationModel(
          city: testCity,
          geopoint: GeoPointModel(latitude: 10.0, longitude: 20.0),
        );
        final model2 = const LocationModel(
          city: testCity,
          geopoint: GeoPointModel(latitude: 11.0, longitude: 21.0),
        );

        // Assert
        expect(model1, isNot(equals(model2)));
      });
    });

    group('round-trip conversion', () {
      test('should maintain data integrity through Firestore conversion', () {
        // Arrange
        final original = LocationModel(
          city: testCity,
          province: testProvince,
          country: testCountry,
          address: testAddress,
          geopoint: testGeoPoint,
        );

        // Act
        final map = original.toFirestore();
        final converted = LocationModel.fromFirestore(map);

        // Assert
        expect(converted.city, equals(original.city));
        expect(converted.province, equals(original.province));
        expect(converted.country, equals(original.country));
        expect(converted.address, equals(original.address));
        expect(converted.geopoint?.latitude, equals(original.geopoint?.latitude));
        expect(converted.geopoint?.longitude,
            equals(original.geopoint?.longitude));
      });

      test('should maintain data integrity through entity conversion', () {
        // Arrange
        final original = LocationModel(
          city: testCity,
          province: testProvince,
          country: testCountry,
          address: testAddress,
          geopoint: testGeoPoint,
        );

        // Act
        final entity = original.toEntity();
        final converted = LocationModel.fromEntity(entity);

        // Assert
        expect(converted, equals(original));
      });

      test('should handle null values in round-trip conversion', () {
        // Arrange
        const original = LocationModel(
          city: testCity,
          province: null,
          country: null,
          address: null,
          geopoint: null,
        );

        // Act
        final map = original.toFirestore();
        final converted = LocationModel.fromFirestore(map);

        // Assert
        expect(converted.city, equals(testCity));
        expect(converted.province, isNull);
        expect(converted.country, isNull);
        expect(converted.address, isNull);
        expect(converted.geopoint, isNull);
      });
    });
  });
}
