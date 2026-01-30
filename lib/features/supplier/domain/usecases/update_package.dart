import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';

/// Use case for updating an existing package
/// This allows suppliers to modify their service package details
class UpdatePackage {
  final SupplierRepository repository;

  const UpdatePackage(this.repository);

  /// Execute the use case
  /// [package] - The package entity with updated information
  /// Returns the updated [PackageEntity] on success or [Failure] on error
  ResultFuture<PackageEntity> call(PackageEntity package) {
    return repository.updatePackage(package);
  }
}
