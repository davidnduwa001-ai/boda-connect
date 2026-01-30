import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

/// UseCase to get all messages for a conversation
/// This returns a stream for real-time updates
class GetMessages {
  const GetMessages(this._repository);

  final ChatRepository _repository;

  /// Get all messages for the specified conversation
  /// Returns a stream that emits message updates in real-time
  Stream<Either<Failure, List<MessageEntity>>> call(String conversationId) {
    return _repository.getMessages(conversationId);
  }
}
