import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Model class for PackageCustomization that extends the domain entity
/// Handles conversion between Firestore data and domain PackageCustomizationEntity
class PackageCustomizationModel extends PackageCustomizationEntity {
  const PackageCustomizationModel({
    required super.name,
    required super.price,
    super.description,
  });

  /// Create PackageCustomizationModel from domain entity
  factory PackageCustomizationModel.fromEntity(
      PackageCustomizationEntity entity) {
    return PackageCustomizationModel(
      name: entity.name,
      price: entity.price,
      description: entity.description,
    );
  }

  /// Create PackageCustomizationModel from Firestore map
  factory PackageCustomizationModel.fromFirestore(DataMap map) {
    return PackageCustomizationModel(
      name: map['name'] as String? ?? '',
      price: map['price'] as int? ?? 0,
      description: map['description'] as String?,
    );
  }

  /// Convert to Firestore map
  DataMap toFirestore() {
    return {
      'name': name,
      'price': price,
      if (description != null) 'description': description,
    };
  }

  /// Convert to domain entity
  PackageCustomizationEntity toEntity() {
    return PackageCustomizationEntity(
      name: name,
      price: price,
      description: description,
    );
  }

  @override
  PackageCustomizationModel copyWith({
    String? name,
    int? price,
    String? description,
  }) {
    return PackageCustomizationModel(
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
    );
  }
}
