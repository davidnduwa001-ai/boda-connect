import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

/// UseCase to get all conversations for a user
/// This returns a stream for real-time updates
class GetConversations {
  const GetConversations(this._repository);

  final ChatRepository _repository;

  /// Get all conversations for the specified user
  /// Returns a stream that emits conversation updates in real-time
  Stream<Either<Failure, List<ConversationEntity>>> call(String userId) {
    return _repository.getConversations(userId);
  }
}
