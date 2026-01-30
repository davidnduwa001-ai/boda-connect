import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/data/models/location_model.dart';
import 'package:boda_connect/features/supplier/data/models/working_hours_model.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Model class for Supplier that extends the domain entity
/// Handles conversion between Firestore data and domain SupplierEntity
class SupplierModel extends SupplierEntity {
  const SupplierModel({
    required super.id,
    required super.userId,
    required super.businessName,
    required super.category,
    required super.subcategories,
    required super.description,
    required super.photos,
    required super.videos,
    super.location,
    required super.rating,
    required super.reviewCount,
    required super.isVerified,
    required super.isActive,
    required super.isFeatured,
    required super.responseRate,
    super.responseTime,
    super.phone,
    super.email,
    super.website,
    super.socialLinks,
    required super.languages,
    super.workingHours,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create SupplierModel from domain entity
  factory SupplierModel.fromEntity(SupplierEntity entity) {
    return SupplierModel(
      id: entity.id,
      userId: entity.userId,
      businessName: entity.businessName,
      category: entity.category,
      subcategories: entity.subcategories,
      description: entity.description,
      photos: entity.photos,
      videos: entity.videos,
      location:
          entity.location != null ? LocationModel.fromEntity(entity.location!) : null,
      rating: entity.rating,
      reviewCount: entity.reviewCount,
      isVerified: entity.isVerified,
      isActive: entity.isActive,
      isFeatured: entity.isFeatured,
      responseRate: entity.responseRate,
      responseTime: entity.responseTime,
      phone: entity.phone,
      email: entity.email,
      website: entity.website,
      socialLinks: entity.socialLinks,
      languages: entity.languages,
      workingHours: entity.workingHours != null
          ? WorkingHoursModel.fromEntity(entity.workingHours!)
          : null,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create SupplierModel from Firestore DocumentSnapshot
  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as DataMap;
    return SupplierModel.fromMap(data, doc.id);
  }

  /// Create SupplierModel from Firestore map
  factory SupplierModel.fromMap(DataMap map, String id) {
    return SupplierModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      category: map['category'] as String? ?? '',
      subcategories: (map['subcategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: map['description'] as String? ?? '',
      photos: (map['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videos: (map['videos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      location: map['location'] != null
          ? LocationModel.fromFirestore(map['location'] as DataMap)
          : null,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] as int? ?? 0,
      isVerified: map['isVerified'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      isFeatured: map['isFeatured'] as bool? ?? false,
      responseRate: (map['responseRate'] as num?)?.toDouble() ?? 0.0,
      responseTime: map['responseTime'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      website: map['website'] as String?,
      socialLinks: map['socialLinks'] != null
          ? Map<String, String>.from(map['socialLinks'] as Map)
          : null,
      languages: (map['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      workingHours: map['workingHours'] != null
          ? WorkingHoursModel.fromFirestore(map['workingHours'] as DataMap)
          : null,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore map
  DataMap toFirestore() {
    return {
      'userId': userId,
      'businessName': businessName,
      'category': category,
      'subcategories': subcategories,
      'description': description,
      'photos': photos,
      'videos': videos,
      if (location != null)
        'location': LocationModel.fromEntity(location!).toFirestore(),
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'responseRate': responseRate,
      if (responseTime != null) 'responseTime': responseTime,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (website != null) 'website': website,
      if (socialLinks != null) 'socialLinks': socialLinks,
      'languages': languages,
      if (workingHours != null)
        'workingHours':
            WorkingHoursModel.fromEntity(workingHours!).toFirestore(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert to domain entity
  SupplierEntity toEntity() {
    return SupplierEntity(
      id: id,
      userId: userId,
      businessName: businessName,
      category: category,
      subcategories: subcategories,
      description: description,
      photos: photos,
      videos: videos,
      location: location,
      rating: rating,
      reviewCount: reviewCount,
      isVerified: isVerified,
      isActive: isActive,
      isFeatured: isFeatured,
      responseRate: responseRate,
      responseTime: responseTime,
      phone: phone,
      email: email,
      website: website,
      socialLinks: socialLinks,
      languages: languages,
      workingHours: workingHours,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  SupplierModel copyWith({
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
    return SupplierModel(
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
