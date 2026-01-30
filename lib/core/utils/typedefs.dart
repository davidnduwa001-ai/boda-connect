import 'package:dartz/dartz.dart';
import 'package:boda_connect/core/errors/failures.dart';

/// Type definitions for common patterns in the application

/// Result type that returns either a Failure or a Success value
/// This is used throughout the application for error handling
///
/// Example usage:
/// ```dart
/// ResultFuture<User> getUser(String id) async {
///   try {
///     final user = await dataSource.getUser(id);
///     return Right(user);
///   } on Exception catch (e) {
///     return Left(ServerFailure(e.toString()));
///   }
/// }
/// ```
typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// Synchronous version of ResultFuture
typedef ResultVoid = Either<Failure, void>;

/// Result type for void operations
typedef ResultFutureVoid = Future<Either<Failure, void>>;

/// Data map type for JSON operations
typedef DataMap = Map<String, dynamic>;
