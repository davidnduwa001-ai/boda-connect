import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:equatable/equatable.dart';

/// UseCase to mark messages as read
class MarkAsRead {
  const MarkAsRead(this._repository);

  final ChatRepository _repository;

  /// Mark message(s) as read
  /// If messageId is null, marks all messages in the conversation as read
  ResultFutureVoid call(MarkAsReadParams params) {
    if (params.messageId != null) {
      return _repository.markMessageAsRead(
        conversationId: params.conversationId,
        messageId: params.messageId!,
        userId: params.userId,
      );
    } else {
      return _repository.markConversationAsRead(
        conversationId: params.conversationId,
        userId: params.userId,
      );
    }
  }
}

/// Parameters for marking messages as read
class MarkAsReadParams extends Equatable {
  final String conversationId;
  final String userId;
  final String? messageId;

  const MarkAsReadParams({
    required this.conversationId,
    required this.userId,
    this.messageId,
  });

  /// Mark a specific message as read
  factory MarkAsReadParams.single({
    required String conversationId,
    required String messageId,
    required String userId,
  }) {
    return MarkAsReadParams(
      conversationId: conversationId,
      messageId: messageId,
      userId: userId,
    );
  }

  /// Mark all messages in a conversation as read
  factory MarkAsReadParams.all({
    required String conversationId,
    required String userId,
  }) {
    return MarkAsReadParams(
      conversationId: conversationId,
      userId: userId,
    );
  }

  @override
  List<Object?> get props => [conversationId, userId, messageId];
}
