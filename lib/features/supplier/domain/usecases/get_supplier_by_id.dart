import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';

/// Use case for getting a supplier by their ID
/// Follows the Single Responsibility Principle - this use case does one thing only
class GetSupplierById {
  final SupplierRepository repository;

  const GetSupplierById(this.repository);

  /// Execute the use case
  /// [supplierId] - The ID of the supplier to retrieve
  /// Returns [SupplierEntity] on success or [Failure] on error
  ResultFuture<SupplierEntity> call(String supplierId) {
    return repository.getSupplierById(supplierId);
  }
}
