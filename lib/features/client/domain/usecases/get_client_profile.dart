import 'package:dartz/dartz.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/client/domain/entities/client_entity.dart';
import 'package:boda_connect/features/client/domain/repositories/client_repository.dart';

/// Use case for retrieving a client's profile
///
/// This use case encapsulates the business logic for fetching a client profile.
/// It follows the Single Responsibility Principle - one use case, one operation.
///
/// Usage:
/// ```dart
/// final useCase = GetClientProfile(repository);
/// final result = await useCase(GetClientProfileParams(clientId: 'client123'));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (client) => print('Client: ${client.name}'),
/// );
/// ```
class GetClientProfile {
  final ClientRepository repository;

  const GetClientProfile(this.repository);

  /// Execute the use case
  ///
  /// Returns [ClientEntity] on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> call(GetClientProfileParams params) {
    return repository.getClientProfile(params.clientId);
  }
}

/// Parameters for the GetClientProfile use case
///
/// This class encapsulates the parameters needed to fetch a client profile
class GetClientProfileParams {
  /// The unique identifier of the client to fetch
  final String clientId;

  const GetClientProfileParams({
    required this.clientId,
  });
}

/// Use case for retrieving a client's profile by user ID
///
/// This is useful when you have the authenticated user ID
/// and need to fetch the associated client profile.
///
/// Usage:
/// ```dart
/// final useCase = GetClientProfileByUserId(repository);
/// final result = await useCase(
///   GetClientProfileByUserIdParams(userId: 'user123'),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (client) => print('Client: ${client.name}'),
/// );
/// ```
class GetClientProfileByUserId {
  final ClientRepository repository;

  const GetClientProfileByUserId(this.repository);

  /// Execute the use case
  ///
  /// Returns [ClientEntity] on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> call(GetClientProfileByUserIdParams params) {
    return repository.getClientProfileByUserId(params.userId);
  }
}

/// Parameters for the GetClientProfileByUserId use case
class GetClientProfileByUserIdParams {
  /// The user ID from the authentication system
  final String userId;

  const GetClientProfileByUserIdParams({
    required this.userId,
  });
}

/// Use case for checking if a client has a complete profile
///
/// This use case fetches the client profile and checks if it's complete.
/// A complete profile has name, email, and location filled in.
///
/// This is useful for prompting users to complete their profile
/// before performing certain actions (like making a booking).
///
/// Usage:
/// ```dart
/// final useCase = CheckClientProfileComplete(repository);
/// final result = await useCase(
///   CheckClientProfileCompleteParams(clientId: 'client123'),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (isComplete) {
///     if (!isComplete) {
///       print('Please complete your profile');
///     }
///   },
/// );
/// ```
class CheckClientProfileComplete {
  final ClientRepository repository;

  const CheckClientProfileComplete(this.repository);

  /// Execute the use case
  ///
  /// Returns true if the profile is complete, false otherwise
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<bool> call(CheckClientProfileCompleteParams params) async {
    final result = await repository.getClientProfile(params.clientId);
    return result.fold(
      (failure) => Left(failure),
      (client) => Right(client.hasCompleteProfile),
    );
  }
}

/// Parameters for the CheckClientProfileComplete use case
class CheckClientProfileCompleteParams {
  /// The unique identifier of the client to check
  final String clientId;

  const CheckClientProfileCompleteParams({
    required this.clientId,
  });
}
