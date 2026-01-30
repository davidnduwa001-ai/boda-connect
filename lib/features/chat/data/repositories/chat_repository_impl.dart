import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

/// Implementation of ChatRepository
/// Handles error handling and conversion between data models and domain entities
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;

  ChatRepositoryImpl({
    required ChatRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  // ==================== CONVERSATIONS ====================

  @override
  Stream<Either<Failure, List<ConversationEntity>>> getConversations(
    String userId,
  ) {
    try {
      return _remoteDataSource.getConversations(userId).map((conversations) {
        try {
          final entities =
              conversations.map((model) => model.toEntity()).toList();
          return Right<Failure, List<ConversationEntity>>(entities);
        } catch (e) {
          return Left<Failure, List<ConversationEntity>>(
            ChatFailure(
              'Erro ao processar conversas: ${e.toString()}',
            ),
          );
        }
      }).handleError((error) {
        return Left<Failure, List<ConversationEntity>>(
          _handleError(error),
        );
      });
    } catch (e) {
      return Stream.value(
        Left<Failure, List<ConversationEntity>>(
          _handleError(e),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> getConversation(
    String conversationId,
  ) async {
    try {
      final conversation =
          await _remoteDataSource.getConversation(conversationId);
      return Right(conversation.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> createConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
  }) async {
    try {
      final conversation = await _remoteDataSource.createConversation(
        clientId: clientId,
        supplierId: supplierId,
        clientName: clientName,
        supplierName: supplierName,
        clientPhoto: clientPhoto,
        supplierPhoto: supplierPhoto,
      );
      return Right(conversation.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
    String? supplierAuthUid,
  }) async {
    try {
      final conversation = await _remoteDataSource.getOrCreateConversation(
        clientId: clientId,
        supplierId: supplierId,
        clientName: clientName,
        supplierName: supplierName,
        clientPhoto: clientPhoto,
        supplierPhoto: supplierPhoto,
        supplierAuthUid: supplierAuthUid,
      );
      return Right(conversation.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteConversation(
    String conversationId,
  ) async {
    try {
      await _remoteDataSource.deleteConversation(conversationId);
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  // ==================== MESSAGES ====================

  @override
  Stream<Either<Failure, List<MessageEntity>>> getMessages(
    String conversationId,
  ) {
    try {
      return _remoteDataSource.getMessages(conversationId).map((messages) {
        try {
          final entities = messages.map((model) => model.toEntity()).toList();
          return Right<Failure, List<MessageEntity>>(entities);
        } catch (e) {
          return Left<Failure, List<MessageEntity>>(
            ChatFailure(
              'Erro ao processar mensagens: ${e.toString()}',
            ),
          );
        }
      }).handleError((error) {
        return Left<Failure, List<MessageEntity>>(
          _handleError(error),
        );
      });
    } catch (e) {
      return Stream.value(
        Left<Failure, List<MessageEntity>>(
          _handleError(e),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    String? senderName,
  }) async {
    try {
      final message = await _remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        type: MessageType.text,
        text: text,
        senderName: senderName,
      );
      return Right(message.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String? text,
    String? senderName,
  }) async {
    try {
      final message = await _remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        type: MessageType.image,
        imageUrl: imageUrl,
        text: text,
        senderName: senderName,
      );
      return Right(message.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String fileUrl,
    required String fileName,
    String? text,
    String? senderName,
  }) async {
    try {
      final message = await _remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        type: MessageType.file,
        fileUrl: fileUrl,
        fileName: fileName,
        text: text,
        senderName: senderName,
      );
      return Right(message.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendQuoteMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required QuoteDataEntity quoteData,
    String? text,
    String? senderName,
  }) async {
    try {
      final message = await _remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        type: MessageType.quote,
        quoteData: quoteData,
        text: text,
        senderName: senderName,
      );
      return Right(message.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendBookingMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required BookingReferenceEntity bookingReference,
    String? text,
    String? senderName,
  }) async {
    try {
      final message = await _remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        type: MessageType.booking,
        bookingReference: bookingReference,
        text: text,
        senderName: senderName,
      );
      return Right(message.toEntity());
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, void>> markMessageAsRead({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _remoteDataSource.markMessageAsRead(
        conversationId: conversationId,
        messageId: messageId,
        userId: userId,
      );
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, void>> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _remoteDataSource.markConversationAsRead(
        conversationId: conversationId,
        userId: userId,
      );
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _remoteDataSource.deleteMessage(
        conversationId: conversationId,
        messageId: messageId,
      );
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount(String userId) async {
    try {
      final count = await _remoteDataSource.getUnreadCount(userId);
      return Right(count);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  @override
  Future<Either<Failure, int>> getConversationUnreadCount({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final count = await _remoteDataSource.getConversationUnreadCount(
        conversationId: conversationId,
        userId: userId,
      );
      return Right(count);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  // ==================== HELPER METHODS ====================

  /// Handle and convert exceptions to appropriate Failure types
  Failure _handleError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();

    // Check for conversation not found
    if (errorMessage.contains('conversation not found')) {
      return const ConversationNotFoundFailure();
    }

    // Check for message send failures
    if (errorMessage.contains('permission') ||
        errorMessage.contains('denied')) {
      return const PermissionFailure('Sem permissão para esta operação');
    }

    // Check for network errors
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('socket')) {
      return const NetworkFailure();
    }

    // Check for Firebase errors
    if (errorMessage.contains('firebase')) {
      return ChatFailure('Erro ao conectar com o servidor: ${error.toString()}');
    }

    // Default to ChatFailure for other errors
    return ChatFailure(error.toString());
  }
}
