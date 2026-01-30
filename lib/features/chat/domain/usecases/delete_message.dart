import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:equatable/equatable.dart';

/// UseCase to delete a message
class DeleteMessage {
  const DeleteMessage(this._repository);

  final ChatRepository _repository;

  /// Delete a message from a conversation
  /// This will mark the message as deleted rather than removing it completely
  ResultFutureVoid call(DeleteMessageParams params) {
    return _repository.deleteMessage(
      conversationId: params.conversationId,
      messageId: params.messageId,
    );
  }
}

/// Parameters for deleting a message
class DeleteMessageParams extends Equatable {
  final String conversationId;
  final String messageId;

  const DeleteMessageParams({
    required this.conversationId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [conversationId, messageId];
}
