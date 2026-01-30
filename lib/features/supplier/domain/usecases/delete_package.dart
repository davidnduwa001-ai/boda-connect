import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';

/// Use case for deleting a package
/// This allows suppliers to remove packages they no longer offer
class DeletePackage {
  final SupplierRepository repository;

  const DeletePackage(this.repository);

  /// Execute the use case
  /// [packageId] - The ID of the package to delete
  /// Returns void on success or [Failure] on error
  ResultFutureVoid call(String packageId) {
    return repository.deletePackage(packageId);
  }
}
