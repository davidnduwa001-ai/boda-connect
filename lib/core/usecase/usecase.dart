import 'package:dartz/dartz.dart';
import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Base class for all use cases in the application
///
/// A use case represents a single business action/operation
/// It encapsulates business logic and coordinates between entities and repositories
///
/// Type parameters:
/// - [Type]: The return type of the use case
/// - [Params]: The parameters required by the use case
///
/// Example:
/// ```dart
/// class Login extends UseCase<User, LoginParams> {
///   final AuthRepository repository;
///
///   Login(this.repository);
///
///   @override
///   ResultFuture<User> call(LoginParams params) async {
///     return await repository.login(
///       email: params.email,
///       password: params.password,
///     );
///   }
/// }
/// ```
abstract class UseCase<Type, Params> {
  const UseCase();

  /// Executes the use case with the given parameters
  ResultFuture<Type> call(Params params);
}

/// Use case that doesn't require any parameters
///
/// Example:
/// ```dart
/// class GetCurrentUser extends UseCaseWithoutParams<User> {
///   final AuthRepository repository;
///
///   GetCurrentUser(this.repository);
///
///   @override
///   ResultFuture<User> call() async {
///     return await repository.getCurrentUser();
///   }
/// }
/// ```
abstract class UseCaseWithoutParams<Type> {
  const UseCaseWithoutParams();

  /// Executes the use case without parameters
  ResultFuture<Type> call();
}

/// Stream-based use case for real-time data
/// Used for features like chat, notifications, live updates
///
/// Example:
/// ```dart
/// class WatchMessages extends StreamUseCase<List<Message>, String> {
///   final ChatRepository repository;
///
///   WatchMessages(this.repository);
///
///   @override
///   Stream<Either<Failure, List<Message>>> call(String conversationId) {
///     return repository.watchMessages(conversationId);
///   }
/// }
/// ```
abstract class StreamUseCase<Type, Params> {
  const StreamUseCase();

  /// Returns a stream of results
  Stream<Either<Failure, Type>> call(Params params);
}

/// Stream-based use case without parameters
abstract class StreamUseCaseWithoutParams<Type> {
  const StreamUseCaseWithoutParams();

  /// Returns a stream of results without parameters
  Stream<Either<Failure, Type>> call();
}

/// Represents "no parameters" for use cases
class NoParams {
  const NoParams();
}
