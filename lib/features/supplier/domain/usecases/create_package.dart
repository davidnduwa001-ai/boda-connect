import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';

/// Use case for creating a new package
/// This allows suppliers to add new service packages to their offerings
class CreatePackage {
  final SupplierRepository repository;

  const CreatePackage(this.repository);

  /// Execute the use case
  /// [package] - The package entity to create
  /// Returns the created [PackageEntity] on success or [Failure] on error
  ResultFuture<PackageEntity> call(PackageEntity package) {
    return repository.createPackage(package);
  }
}
