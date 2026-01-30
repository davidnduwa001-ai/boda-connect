import 'package:dartz/dartz.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/client/domain/entities/client_entity.dart';
import 'package:boda_connect/features/client/domain/repositories/client_repository.dart';

/// Use case for adding a supplier to the client's favorites
///
/// This use case encapsulates the business logic for adding a supplier
/// to a client's list of favorite suppliers.
///
/// Usage:
/// ```dart
/// final useCase = AddFavoriteSupplier(repository);
/// final result = await useCase(AddFavoriteSupplierParams(
///   clientId: 'client123',
///   supplierId: 'supplier456',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (client) => print('Favorite added'),
/// );
/// ```
class AddFavoriteSupplier {
  final ClientRepository repository;

  const AddFavoriteSupplier(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] with the supplier added to favorites
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> call(AddFavoriteSupplierParams params) {
    return repository.addFavoriteSupplier(
      clientId: params.clientId,
      supplierId: params.supplierId,
    );
  }
}

/// Parameters for adding a favorite supplier
class AddFavoriteSupplierParams {
  /// The unique identifier of the client
  final String clientId;

  /// The unique identifier of the supplier to add to favorites
  final String supplierId;

  const AddFavoriteSupplierParams({
    required this.clientId,
    required this.supplierId,
  });
}

/// Use case for removing a supplier from the client's favorites
///
/// This use case encapsulates the business logic for removing a supplier
/// from a client's list of favorite suppliers.
///
/// Usage:
/// ```dart
/// final useCase = RemoveFavoriteSupplier(repository);
/// final result = await useCase(RemoveFavoriteSupplierParams(
///   clientId: 'client123',
///   supplierId: 'supplier456',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (client) => print('Favorite removed'),
/// );
/// ```
class RemoveFavoriteSupplier {
  final ClientRepository repository;

  const RemoveFavoriteSupplier(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] with the supplier removed from favorites
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> call(RemoveFavoriteSupplierParams params) {
    return repository.removeFavoriteSupplier(
      clientId: params.clientId,
      supplierId: params.supplierId,
    );
  }
}

/// Parameters for removing a favorite supplier
class RemoveFavoriteSupplierParams {
  /// The unique identifier of the client
  final String clientId;

  /// The unique identifier of the supplier to remove from favorites
  final String supplierId;

  const RemoveFavoriteSupplierParams({
    required this.clientId,
    required this.supplierId,
  });
}

/// Use case for toggling a supplier's favorite status
///
/// This use case provides a convenient way to toggle a supplier's favorite status.
/// If the supplier is already a favorite, it will be removed. If not, it will be added.
///
/// This is particularly useful for UI components like favorite buttons that toggle state.
///
/// Usage:
/// ```dart
/// final useCase = ToggleFavoriteSupplier(repository);
/// final result = await useCase(ToggleFavoriteSupplierParams(
///   clientId: 'client123',
///   supplierId: 'supplier456',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (isFavorite) => print('Is favorite: $isFavorite'),
/// );
/// ```
class ToggleFavoriteSupplier {
  final ClientRepository repository;

  const ToggleFavoriteSupplier(this.repository);

  /// Execute the use case
  ///
  /// Returns true if the supplier is now a favorite, false if it was removed
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<bool> call(ToggleFavoriteSupplierParams params) async {
    // First, check if the supplier is currently a favorite
    final isFavoriteResult = await repository.isFavoriteSupplier(
      clientId: params.clientId,
      supplierId: params.supplierId,
    );

    return isFavoriteResult.fold(
      (failure) => Left(failure),
      (isFavorite) async {
        // Toggle the favorite status
        if (isFavorite) {
          // Remove from favorites
          final result = await repository.removeFavoriteSupplier(
            clientId: params.clientId,
            supplierId: params.supplierId,
          );
          return result.fold(
            (failure) => Left(failure),
            (_) => const Right(false),
          );
        } else {
          // Add to favorites
          final result = await repository.addFavoriteSupplier(
            clientId: params.clientId,
            supplierId: params.supplierId,
          );
          return result.fold(
            (failure) => Left(failure),
            (_) => const Right(true),
          );
        }
      },
    );
  }
}

/// Parameters for toggling a favorite supplier
class ToggleFavoriteSupplierParams {
  /// The unique identifier of the client
  final String clientId;

  /// The unique identifier of the supplier to toggle favorite status
  final String supplierId;

  const ToggleFavoriteSupplierParams({
    required this.clientId,
    required this.supplierId,
  });
}

/// Use case for checking if a supplier is in the client's favorites
///
/// This is useful for UI components that need to display the favorite status
/// of a supplier (e.g., showing a filled or outlined heart icon).
///
/// Usage:
/// ```dart
/// final useCase = IsFavoriteSupplier(repository);
/// final result = await useCase(IsFavoriteSupplierParams(
///   clientId: 'client123',
///   supplierId: 'supplier456',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (isFavorite) => print('Is favorite: $isFavorite'),
/// );
/// ```
class IsFavoriteSupplier {
  final ClientRepository repository;

  const IsFavoriteSupplier(this.repository);

  /// Execute the use case
  ///
  /// Returns true if the supplier is a favorite, false otherwise
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<bool> call(IsFavoriteSupplierParams params) {
    return repository.isFavoriteSupplier(
      clientId: params.clientId,
      supplierId: params.supplierId,
    );
  }
}

/// Parameters for checking if a supplier is a favorite
class IsFavoriteSupplierParams {
  /// The unique identifier of the client
  final String clientId;

  /// The unique identifier of the supplier to check
  final String supplierId;

  const IsFavoriteSupplierParams({
    required this.clientId,
    required this.supplierId,
  });
}

/// Use case for getting all favorite supplier IDs for a client
///
/// This is useful when you need to fetch just the IDs of favorite suppliers,
/// without loading the full supplier details.
///
/// Usage:
/// ```dart
/// final useCase = GetFavoriteSupplierIds(repository);
/// final result = await useCase(GetFavoriteSupplierIdsParams(
///   clientId: 'client123',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (ids) => print('Favorite IDs: $ids'),
/// );
/// ```
class GetFavoriteSupplierIds {
  final ClientRepository repository;

  const GetFavoriteSupplierIds(this.repository);

  /// Execute the use case
  ///
  /// Returns a list of favorite supplier IDs
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<List<String>> call(GetFavoriteSupplierIdsParams params) {
    return repository.getFavoriteSupplierIds(params.clientId);
  }
}

/// Parameters for getting favorite supplier IDs
class GetFavoriteSupplierIdsParams {
  /// The unique identifier of the client
  final String clientId;

  const GetFavoriteSupplierIdsParams({
    required this.clientId,
  });
}

/// Use case for getting the count of favorite suppliers
///
/// This is useful for displaying statistics or badges showing how many
/// favorites a client has.
///
/// Usage:
/// ```dart
/// final useCase = GetFavoriteSuppliersCount(repository);
/// final result = await useCase(GetFavoriteSuppliersCountParams(
///   clientId: 'client123',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (count) => print('Favorites count: $count'),
/// );
/// ```
class GetFavoriteSuppliersCount {
  final ClientRepository repository;

  const GetFavoriteSuppliersCount(this.repository);

  /// Execute the use case
  ///
  /// Returns the count of favorite suppliers
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<int> call(GetFavoriteSuppliersCountParams params) async {
    final result = await repository.getFavoriteSupplierIds(params.clientId);
    return result.fold(
      (failure) => Left(failure),
      (ids) => Right(ids.length),
    );
  }
}

/// Parameters for getting favorites count
class GetFavoriteSuppliersCountParams {
  /// The unique identifier of the client
  final String clientId;

  const GetFavoriteSuppliersCountParams({
    required this.clientId,
  });
}
