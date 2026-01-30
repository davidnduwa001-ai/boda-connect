import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:boda_connect/features/supplier/data/models/package_customization_model.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Model class for Package that extends the domain entity
/// Handles conversion between Firestore data and domain PackageEntity
class PackageModel extends PackageEntity {
  const PackageModel({
    required super.id,
    required super.supplierId,
    required super.name,
    required super.description,
    required super.price,
    required super.currency,
    required super.duration,
    required super.includes,
    required super.customizations,
    required super.photos,
    required super.isActive,
    required super.isFeatured,
    required super.bookingCount,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create PackageModel from domain entity
  factory PackageModel.fromEntity(PackageEntity entity) {
    return PackageModel(
      id: entity.id,
      supplierId: entity.supplierId,
      name: entity.name,
      description: entity.description,
      price: entity.price,
      currency: entity.currency,
      duration: entity.duration,
      includes: entity.includes,
      customizations: entity.customizations
          .map((c) => PackageCustomizationModel.fromEntity(c))
          .toList(),
      photos: entity.photos,
      isActive: entity.isActive,
      isFeatured: entity.isFeatured,
      bookingCount: entity.bookingCount,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create PackageModel from Firestore DocumentSnapshot
  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as DataMap;
    return PackageModel.fromMap(data, doc.id);
  }

  /// Create PackageModel from Firestore map
  factory PackageModel.fromMap(DataMap map, String id) {
    return PackageModel(
      id: id,
      supplierId: map['supplierId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: map['price'] as int? ?? 0,
      currency: map['currency'] as String? ?? 'KES',
      duration: map['duration'] as String? ?? '',
      includes: (map['includes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      customizations: (map['customizations'] as List<dynamic>?)
              ?.map((c) =>
                  PackageCustomizationModel.fromFirestore(c as DataMap))
              .toList() ??
          [],
      photos: (map['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: map['isActive'] as bool? ?? true,
      isFeatured: map['isFeatured'] as bool? ?? false,
      bookingCount: map['bookingCount'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore map
  DataMap toFirestore() {
    return {
      'supplierId': supplierId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'duration': duration,
      'includes': includes,
      'customizations': customizations
          .map((c) => PackageCustomizationModel.fromEntity(c).toFirestore())
          .toList(),
      'photos': photos,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'bookingCount': bookingCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert to domain entity
  PackageEntity toEntity() {
    return PackageEntity(
      id: id,
      supplierId: supplierId,
      name: name,
      description: description,
      price: price,
      currency: currency,
      duration: duration,
      includes: includes,
      customizations: customizations,
      photos: photos,
      isActive: isActive,
      isFeatured: isFeatured,
      bookingCount: bookingCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  PackageModel copyWith({
    String? id,
    String? supplierId,
    String? name,
    String? description,
    int? price,
    String? currency,
    String? duration,
    List<String>? includes,
    List<PackageCustomizationEntity>? customizations,
    List<String>? photos,
    bool? isActive,
    bool? isFeatured,
    int? bookingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PackageModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      duration: duration ?? this.duration,
      includes: includes ?? this.includes,
      customizations: customizations ?? this.customizations,
      photos: photos ?? this.photos,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      bookingCount: bookingCount ?? this.bookingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
