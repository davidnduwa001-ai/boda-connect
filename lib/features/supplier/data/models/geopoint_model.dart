import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Model class for GeoPoint that extends the domain entity
/// Handles conversion between Firebase GeoPoint and domain GeoPointEntity
class GeoPointModel extends GeoPointEntity {
  const GeoPointModel({
    required super.latitude,
    required super.longitude,
  });

  /// Create GeoPointModel from domain entity
  factory GeoPointModel.fromEntity(GeoPointEntity entity) {
    return GeoPointModel(
      latitude: entity.latitude,
      longitude: entity.longitude,
    );
  }

  /// Create GeoPointModel from Firebase GeoPoint
  factory GeoPointModel.fromGeoPoint(GeoPoint geoPoint) {
    return GeoPointModel(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
    );
  }

  /// Create GeoPointModel from Firestore map
  factory GeoPointModel.fromFirestore(DataMap map) {
    if (map['geopoint'] is GeoPoint) {
      final geoPoint = map['geopoint'] as GeoPoint;
      return GeoPointModel(
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
      );
    }

    return GeoPointModel(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to Firebase GeoPoint
  GeoPoint toGeoPoint() {
    return GeoPoint(latitude, longitude);
  }

  /// Convert to Firestore map
  DataMap toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Convert to domain entity
  GeoPointEntity toEntity() {
    return GeoPointEntity(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  GeoPointModel copyWith({
    double? latitude,
    double? longitude,
  }) {
    return GeoPointModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
