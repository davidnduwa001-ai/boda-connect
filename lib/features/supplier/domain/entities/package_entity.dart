import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a Package in the domain layer
/// This entity is independent of any framework or external library
class PackageEntity extends Equatable {
  final String id;
  final String supplierId;
  final String name;
  final String description;
  final int price;
  final String currency;
  final String duration;
  final List<String> includes;
  final List<PackageCustomizationEntity> customizations;
  final List<String> photos;
  final bool isActive;
  final bool isFeatured;
  final int bookingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PackageEntity({
    required this.id,
    required this.supplierId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.duration,
    required this.includes,
    required this.customizations,
    required this.photos,
    required this.isActive,
    required this.isFeatured,
    required this.bookingCount,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        supplierId,
        name,
        description,
        price,
        currency,
        duration,
        includes,
        customizations,
        photos,
        isActive,
        isFeatured,
        bookingCount,
        createdAt,
        updatedAt,
      ];

  PackageEntity copyWith({
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
    return PackageEntity(
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

  /// Get formatted price string
  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M $currency';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K $currency';
    }
    return '$price $currency';
  }
}

/// Package customization entity
class PackageCustomizationEntity extends Equatable {
  final String name;
  final int price;
  final String? description;

  const PackageCustomizationEntity({
    required this.name,
    required this.price,
    this.description,
  });

  @override
  List<Object?> get props => [name, price, description];

  PackageCustomizationEntity copyWith({
    String? name,
    int? price,
    String? description,
  }) {
    return PackageCustomizationEntity(
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
    );
  }
}
