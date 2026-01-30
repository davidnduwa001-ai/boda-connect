import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/data/models/geopoint_model.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Model class for Location that extends the domain entity
/// Handles conversion between Firestore data and domain LocationEntity
class LocationModel extends LocationEntity {
  const LocationModel({
    super.city,
    super.province,
    super.country,
    super.address,
    super.geopoint,
  });

  /// Create LocationModel from domain entity
  factory LocationModel.fromEntity(LocationEntity entity) {
    return LocationModel(
      city: entity.city,
      province: entity.province,
      country: entity.country,
      address: entity.address,
      geopoint: entity.geopoint != null
          ? GeoPointModel.fromEntity(entity.geopoint!)
          : null,
    );
  }

  /// Create LocationModel from Firestore map
  factory LocationModel.fromFirestore(DataMap map) {
    GeoPointModel? geopointModel;

    // Handle Firebase GeoPoint
    if (map['geopoint'] is GeoPoint) {
      geopointModel = GeoPointModel.fromGeoPoint(map['geopoint'] as GeoPoint);
    } else if (map['geopoint'] is Map) {
      geopointModel = GeoPointModel.fromFirestore(map['geopoint'] as DataMap);
    }

    return LocationModel(
      city: map['city'] as String?,
      province: map['province'] as String?,
      country: map['country'] as String?,
      address: map['address'] as String?,
      geopoint: geopointModel,
    );
  }

  /// Convert to Firestore map
  DataMap toFirestore() {
    return {
      if (city != null) 'city': city,
      if (province != null) 'province': province,
      if (country != null) 'country': country,
      if (address != null) 'address': address,
      if (geopoint != null)
        'geopoint': GeoPointModel.fromEntity(geopoint!).toGeoPoint(),
    };
  }

  /// Convert to domain entity
  LocationEntity toEntity() {
    return LocationEntity(
      city: city,
      province: province,
      country: country,
      address: address,
      geopoint: geopoint,
    );
  }

  @override
  LocationModel copyWith({
    String? city,
    String? province,
    String? country,
    String? address,
    GeoPointEntity? geopoint,
  }) {
    return LocationModel(
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      address: address ?? this.address,
      geopoint: geopoint ?? this.geopoint,
    );
  }
}
