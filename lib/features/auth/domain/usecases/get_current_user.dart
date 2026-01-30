import 'package:boda_connect/core/repositories/auth_repository.dart';
import 'package:boda_connect/core/models/user_model.dart';

class GetCurrentUser {
  const GetCurrentUser(this.repo);
  final AuthRepository repo;

  /// Gets the current logged in user
  Future<UserModel?> call() => repo.getCurrentUser();
}