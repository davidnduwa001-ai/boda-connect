import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';

/// Use case for updating supplier profile information
/// This allows suppliers to modify their business profile details
class UpdateSupplierProfile {
  final SupplierRepository repository;

  const UpdateSupplierProfile(this.repository);

  /// Execute the use case
  /// Returns the updated [SupplierEntity] on success or [Failure] on error
  ResultFuture<SupplierEntity> call(UpdateSupplierProfileParams params) {
    return repository.updateSupplierProfile(
      supplierId: params.supplierId,
      businessName: params.businessName,
      description: params.description,
      subcategories: params.subcategories,
      phone: params.phone,
      email: params.email,
      website: params.website,
      socialLinks: params.socialLinks,
      languages: params.languages,
      location: params.location,
      workingHours: params.workingHours,
      photos: params.photos,
      videos: params.videos,
    );
  }
}

/// Parameters for updating supplier profile
/// This class encapsulates all the optional fields that can be updated
class UpdateSupplierProfileParams {
  final String supplierId;
  final String? businessName;
  final String? description;
  final List<String>? subcategories;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String>? socialLinks;
  final List<String>? languages;
  final LocationEntity? location;
  final WorkingHoursEntity? workingHours;
  final List<String>? photos;
  final List<String>? videos;

  const UpdateSupplierProfileParams({
    required this.supplierId,
    this.businessName,
    this.description,
    this.subcategories,
    this.phone,
    this.email,
    this.website,
    this.socialLinks,
    this.languages,
    this.location,
    this.workingHours,
    this.photos,
    this.videos,
  });
}
