import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/package_entity.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';

/// Use case for getting all packages for a specific supplier
/// This allows customers to view all available packages from a supplier
class GetSupplierPackages {
  final SupplierRepository repository;

  const GetSupplierPackages(this.repository);

  /// Execute the use case
  /// [supplierId] - The ID of the supplier whose packages to retrieve
  /// Returns a list of [PackageEntity] on success or [Failure] on error
  ResultFuture<List<PackageEntity>> call(String supplierId) {
    return repository.getSupplierPackages(supplierId);
  }
}
