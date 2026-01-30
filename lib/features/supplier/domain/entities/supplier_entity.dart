import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a Supplier in the domain layer
/// This entity is independent of any framework or external library
class SupplierEntity extends Equatable {
  final String id;
  final String userId;
  final String businessName;
  final String category;
  final List<String> subcategories;
  final String description;
  final List<String> photos;
  final List<String> videos;
  final LocationEntity? location;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isActive;
  final bool isFeatured;
  final double responseRate;
  final String? responseTime;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String>? socialLinks;
  final List<String> languages;
  final WorkingHoursEntity? workingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierEntity({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.category,
    required this.subcategories,
    required this.description,
    required this.photos,
    required this.videos,
    this.location,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.isActive,
    required this.isFeatured,
    required this.responseRate,
    this.responseTime,
    this.phone,
    this.email,
    this.website,
    this.socialLinks,
    required this.languages,
    this.workingHours,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        businessName,
        category,
        subcategories,
        description,
        photos,
        videos,
        location,
        rating,
        reviewCount,
        isVerified,
        isActive,
        isFeatured,
        responseRate,
        responseTime,
        phone,
        email,
        website,
        socialLinks,
        languages,
        workingHours,
        createdAt,
        updatedAt,
      ];

  SupplierEntity copyWith({
    String? id,
    String? userId,
    String? businessName,
    String? category,
    List<String>? subcategories,
    String? description,
    List<String>? photos,
    List<String>? videos,
    LocationEntity? location,
    double? rating,
    int? reviewCount,
    bool? isVerified,
    bool? isActive,
    bool? isFeatured,
    double? responseRate,
    String? responseTime,
    String? phone,
    String? email,
    String? website,
    Map<String, String>? socialLinks,
    List<String>? languages,
    WorkingHoursEntity? workingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      category: category ?? this.category,
      subcategories: subcategories ?? this.subcategories,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      videos: videos ?? this.videos,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      responseRate: responseRate ?? this.responseRate,
      responseTime: responseTime ?? this.responseTime,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      socialLinks: socialLinks ?? this.socialLinks,
      languages: languages ?? this.languages,
      workingHours: workingHours ?? this.workingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Location entity for supplier
class LocationEntity extends Equatable {
  final String? city;
  final String? province;
  final String? country;
  final String? address;
  final GeoPointEntity? geopoint;

  const LocationEntity({
    this.city,
    this.province,
    this.country,
    this.address,
    this.geopoint,
  });

  @override
  List<Object?> get props => [city, province, country, address, geopoint];

  LocationEntity copyWith({
    String? city,
    String? province,
    String? country,
    String? address,
    GeoPointEntity? geopoint,
  }) {
    return LocationEntity(
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      address: address ?? this.address,
      geopoint: geopoint ?? this.geopoint,
    );
  }
}

/// Pure Dart GeoPoint entity (not dependent on Firebase)
class GeoPointEntity extends Equatable {
  final double latitude;
  final double longitude;

  const GeoPointEntity({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];

  GeoPointEntity copyWith({
    double? latitude,
    double? longitude,
  }) {
    return GeoPointEntity(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// Working hours entity for supplier
class WorkingHoursEntity extends Equatable {
  final Map<String, DayHoursEntity> schedule;

  const WorkingHoursEntity({required this.schedule});

  @override
  List<Object?> get props => [schedule];

  WorkingHoursEntity copyWith({
    Map<String, DayHoursEntity>? schedule,
  }) {
    return WorkingHoursEntity(
      schedule: schedule ?? this.schedule,
    );
  }
}

/// Day hours entity
class DayHoursEntity extends Equatable {
  final bool isOpen;
  final String? openTime;
  final String? closeTime;

  const DayHoursEntity({
    required this.isOpen,
    this.openTime,
    this.closeTime,
  });

  @override
  List<Object?> get props => [isOpen, openTime, closeTime];

  DayHoursEntity copyWith({
    bool? isOpen,
    String? openTime,
    String? closeTime,
  }) {
    return DayHoursEntity(
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}
