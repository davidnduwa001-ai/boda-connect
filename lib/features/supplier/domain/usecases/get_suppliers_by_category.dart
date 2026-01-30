import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/supplier/domain/entities/supplier_entity.dart';
import 'package:boda_connect/features/supplier/domain/repositories/supplier_repository.dart';

/// Use case for getting suppliers filtered by category
/// This allows customers to browse suppliers in specific service categories
class GetSuppliersByCategory {
  final SupplierRepository repository;

  const GetSuppliersByCategory(this.repository);

  /// Execute the use case
  /// Returns a list of [SupplierEntity] on success or [Failure] on error
  ResultFuture<List<SupplierEntity>> call(GetSuppliersByCategoryParams params) {
    return repository.getSuppliersByCategory(
      category: params.category,
      subcategory: params.subcategory,
      limit: params.limit,
    );
  }
}

/// Parameters for getting suppliers by category
/// This class encapsulates the filtering options
class GetSuppliersByCategoryParams {
  final String category;
  final String? subcategory;
  final int? limit;

  const GetSuppliersByCategoryParams({
    required this.category,
    this.subcategory,
    this.limit,
  });
}
