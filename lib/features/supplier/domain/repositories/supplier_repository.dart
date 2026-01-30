import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';

/// Abstract repository interface for Supplier operations
/// This defines the contract that the data layer must implement
/// Following Clean Architecture, the domain layer defines the interface
/// and the data layer provides the implementation
abstract class SupplierRepository {
  /// Get a supplier by ID
  /// Returns [SupplierEntity] on success or [Failure] on error
  ResultFuture<SupplierEntity> getSupplierById(String supplierId);

  /// Get suppliers by category
  /// Returns a list of [SupplierEntity] on success or [Failure] on error
  ResultFuture<List<SupplierEntity>> getSuppliersByCategory({
    required String category,
    String? subcategory,
    int? limit,
  });

  /// Get all packages for a specific supplier
  /// Returns a list of [PackageEntity] on success or [Failure] on error
  ResultFuture<List<PackageEntity>> getSupplierPackages(String supplierId);

  /// Get a specific package by ID
  /// Returns [PackageEntity] on success or [Failure] on error
  ResultFuture<PackageEntity> getPackageById(String packageId);

  /// Create a new package for a supplier
  /// Returns the created [PackageEntity] on success or [Failure] on error
  ResultFuture<PackageEntity> createPackage(PackageEntity package);

  /// Update an existing package
  /// Returns the updated [PackageEntity] on success or [Failure] on error
  ResultFuture<PackageEntity> updatePackage(PackageEntity package);

  /// Delete a package
  /// Returns void on success or [Failure] on error
  ResultFutureVoid deletePackage(String packageId);

  /// Update supplier profile information
  /// Returns the updated [SupplierEntity] on success or [Failure] on error
  ResultFuture<SupplierEntity> updateSupplierProfile({
    required String supplierId,
    String? businessName,
    String? description,
    List<String>? subcategories,
    String? phone,
    String? email,
    String? website,
    Map<String, String>? socialLinks,
    List<String>? languages,
    LocationEntity? location,
    WorkingHoursEntity? workingHours,
    List<String>? photos,
    List<String>? videos,
  });

  /// Search suppliers by query
  /// Returns a list of [SupplierEntity] on success or [Failure] on error
  ResultFuture<List<SupplierEntity>> searchSuppliers({
    required String query,
    String? category,
    String? city,
    int? limit,
  });

  /// Get featured suppliers
  /// Returns a list of featured [SupplierEntity] on success or [Failure] on error
  ResultFuture<List<SupplierEntity>> getFeaturedSuppliers({int? limit});

  /// Get verified suppliers
  /// Returns a list of verified [SupplierEntity] on success or [Failure] on error
  ResultFuture<List<SupplierEntity>> getVerifiedSuppliers({
    String? category,
    int? limit,
  });

  /// Toggle package active status
  /// Returns the updated [PackageEntity] on success or [Failure] on error
  ResultFuture<PackageEntity> togglePackageStatus({
    required String packageId,
    required bool isActive,
  });

  /// Toggle supplier active status
  /// Returns the updated [SupplierEntity] on success or [Failure] on error
  ResultFuture<SupplierEntity> toggleSupplierStatus({
    required String supplierId,
    required bool isActive,
  });
}
