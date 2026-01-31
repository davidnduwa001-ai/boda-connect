import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';
import 'package:dartz/dartz.dart';

/// Abstract repository interface for Chat operations
/// This defines the contract that the data layer must implement
abstract class ChatRepository {
  // ==================== CONVERSATIONS ====================

  /// Get all conversations for a user
  /// Returns a stream for real-time updates
  /// [supplierDocId] - Optional: For suppliers, their document ID if different from userId
  Stream<Either<Failure, List<ConversationEntity>>> getConversations(
    String userId, {
    String? supplierDocId,
  });

  /// Get a specific conversation by ID
  ResultFuture<ConversationEntity> getConversation(String conversationId);

  /// Create a new conversation between client and supplier
  ResultFuture<ConversationEntity> createConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
  });

  /// Get or create conversation between two users
  /// If conversation exists, return it; otherwise create new one
  /// [supplierAuthUid] - Optional: supplier's Firebase Auth UID for finding legacy conversations
  ResultFuture<ConversationEntity> getOrCreateConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
    String? supplierAuthUid,
  });

  /// Delete a conversation
  ResultFutureVoid deleteConversation(String conversationId);

  // ==================== MESSAGES ====================

  /// Get all messages for a conversation
  /// Returns a stream for real-time updates
  Stream<Either<Failure, List<MessageEntity>>> getMessages(
    String conversationId,
  );

  /// Send a text message
  ResultFuture<MessageEntity> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    String? senderName,
  });

  /// Send an image message
  ResultFuture<MessageEntity> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String? text,
    String? senderName,
  });

  /// Send a file message
  ResultFuture<MessageEntity> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String fileUrl,
    required String fileName,
    String? text,
    String? senderName,
  });

  /// Send a quote message
  ResultFuture<MessageEntity> sendQuoteMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required QuoteDataEntity quoteData,
    String? text,
    String? senderName,
  });

  /// Send a booking reference message
  ResultFuture<MessageEntity> sendBookingMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required BookingReferenceEntity bookingReference,
    String? text,
    String? senderName,
  });

  /// Mark message as read
  ResultFutureVoid markMessageAsRead({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Mark all messages in a conversation as read
  ResultFutureVoid markConversationAsRead({
    required String conversationId,
    required String userId,
  });

  /// Delete a message
  ResultFutureVoid deleteMessage({
    required String conversationId,
    required String messageId,
  });

  /// Get unread message count for user
  ResultFuture<int> getUnreadCount(String userId);

  /// Get unread message count for a specific conversation
  ResultFuture<int> getConversationUnreadCount({
    required String conversationId,
    required String userId,
  });
}
