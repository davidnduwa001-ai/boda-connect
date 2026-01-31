import 'package:boda_connect/core/errors/failures.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/client_view_provider.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/providers/supplier_view_provider.dart';
import 'package:boda_connect/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:boda_connect/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ==================== DATA SOURCE PROVIDERS ====================

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl();
});

// ==================== REPOSITORY PROVIDERS ====================

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remoteDataSource = ref.watch(chatRemoteDataSourceProvider);
  return ChatRepositoryImpl(remoteDataSource: remoteDataSource);
});

// ==================== CONVERSATION PROVIDERS ====================

/// Stream of all conversations for the current user
final conversationsStreamProvider =
    StreamProvider.autoDispose<Either<Failure, List<ConversationEntity>>>(
        (ref) {
  // Try to get userId from currentUserProvider first, fallback to Firebase Auth directly
  final userId = ref.watch(currentUserProvider)?.uid ??
                 FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    return Stream.value(
      Left(ChatFailure('User not authenticated')),
    );
  }

  // Get supplier document ID if user is a supplier
  // This is needed for legacy conversations where supplier doc ID was used in participants
  final supplierState = ref.watch(supplierProvider);
  final supplierDocId = supplierState.currentSupplier?.id;

  final repository = ref.watch(chatRepositoryProvider);
  return repository.getConversations(userId, supplierDocId: supplierDocId);
});

/// Get a specific conversation by ID
final conversationProvider = FutureProvider.autoDispose
    .family<Either<Failure, ConversationEntity>, String>((ref, conversationId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getConversation(conversationId);
});

// ==================== MESSAGE PROVIDERS ====================

/// Stream of messages for a specific conversation
final messagesStreamProvider = StreamProvider.autoDispose
    .family<Either<Failure, List<MessageEntity>>, String>((ref, conversationId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessages(conversationId);
});

/// Get unread count for current user (one-time fetch)
///
/// @deprecated UI-FIRST: Use clientUnreadMessagesProvider or supplierUnreadMessagesProvider
/// from projection providers instead. This avoids direct Firestore queries.
@Deprecated('Use clientUnreadMessagesProvider or supplierUnreadMessagesProvider from projections')
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // UI-FIRST: Try projection first, fallback to 0
  // The actual count should come from clientUnreadMessagesProvider or supplierUnreadMessagesProvider
  final clientView = ref.watch(clientViewProvider);
  if (clientView.view != null) {
    return clientView.view!.unreadMessages;
  }

  final supplierView = ref.watch(supplierViewProvider);
  if (supplierView.view != null) {
    return supplierView.view!.unreadMessages;
  }

  return 0;
});

/// Total unread count for current user (real-time updates)
/// UI-FIRST: Uses projections instead of direct Firestore queries
final totalUnreadCountProvider = Provider.autoDispose<int>((ref) {
  // Try client view first
  final clientUnread = ref.watch(clientUnreadMessagesProvider);
  if (clientUnread > 0) {
    return clientUnread;
  }

  // Then try supplier view
  final supplierUnread = ref.watch(supplierUnreadMessagesProvider);
  return supplierUnread;
});

// ==================== CHAT ACTIONS NOTIFIER ====================

/// Notifier for chat actions (send message, mark as read, etc.)
class ChatActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repository;
  final String? _currentUserId;

  ChatActionsNotifier(this._repository, this._currentUserId)
      : super(const AsyncValue.data(null));

  /// Safely set state using Future.microtask to avoid modifying state during build
  void _safeSetState(AsyncValue<void> newState) {
    Future.microtask(() {
      if (mounted) {
        state = newState;
      }
    });
  }

  /// Send a text message
  Future<Either<Failure, MessageEntity>> sendTextMessage({
    required String conversationId,
    required String receiverId,
    required String text,
    String? senderName,
  }) async {
    if (_currentUserId == null) {
      return Left(ChatFailure('User not authenticated'));
    }

    _safeSetState(const AsyncValue.loading());

    try {
      final result = await _repository.sendMessage(
        conversationId: conversationId,
        senderId: _currentUserId!,
        receiverId: receiverId,
        text: text,
        senderName: senderName,
      );

      _safeSetState(const AsyncValue.data(null));
      return result;
    } catch (e) {
      _safeSetState(AsyncValue.error(e, StackTrace.current));
      return Left(ChatFailure('Failed to send message: ${e.toString()}'));
    }
  }

  /// Send an image message
  Future<Either<Failure, MessageEntity>> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required String imageUrl,
    String? text,
    String? senderName,
  }) async {
    if (_currentUserId == null) {
      return Left(ChatFailure('User not authenticated'));
    }

    _safeSetState(const AsyncValue.loading());

    try {
      final result = await _repository.sendImageMessage(
        conversationId: conversationId,
        senderId: _currentUserId!,
        receiverId: receiverId,
        imageUrl: imageUrl,
        text: text,
        senderName: senderName,
      );

      _safeSetState(const AsyncValue.data(null));
      return result;
    } catch (e) {
      _safeSetState(AsyncValue.error(e, StackTrace.current));
      return Left(ChatFailure('Failed to send image: ${e.toString()}'));
    }
  }

  /// Send a proposal message
  Future<Either<Failure, MessageEntity>> sendProposalMessage({
    required String conversationId,
    required String receiverId,
    required QuoteDataEntity quoteData,
    String? text,
    String? senderName,
  }) async {
    if (_currentUserId == null) {
      return Left(ChatFailure('User not authenticated'));
    }

    _safeSetState(const AsyncValue.loading());

    try {
      final result = await _repository.sendQuoteMessage(
        conversationId: conversationId,
        senderId: _currentUserId!,
        receiverId: receiverId,
        quoteData: quoteData,
        text: text,
        senderName: senderName,
      );

      _safeSetState(const AsyncValue.data(null));
      return result;
    } catch (e) {
      _safeSetState(AsyncValue.error(e, StackTrace.current));
      return Left(ChatFailure('Failed to send proposal: ${e.toString()}'));
    }
  }

  /// Mark a message as read
  Future<void> markMessageAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    if (_currentUserId == null) return;

    await _repository.markMessageAsRead(
      conversationId: conversationId,
      messageId: messageId,
      userId: _currentUserId!,
    );
  }

  /// Mark all messages in a conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    if (_currentUserId == null) return;

    await _repository.markConversationAsRead(
      conversationId: conversationId,
      userId: _currentUserId!,
    );
  }

  /// Delete a message
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    _safeSetState(const AsyncValue.loading());

    try {
      await _repository.deleteMessage(
        conversationId: conversationId,
        messageId: messageId,
      );
      _safeSetState(const AsyncValue.data(null));
    } catch (e) {
      _safeSetState(AsyncValue.error(e, StackTrace.current));
    }
  }

  /// Get or create conversation
  /// [supplierAuthUid] - Optional: supplier's Firebase Auth UID for finding legacy conversations
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
    String? supplierAuthUid,
  }) async {
    _safeSetState(const AsyncValue.loading());

    try {
      final result = await _repository.getOrCreateConversation(
        clientId: clientId,
        supplierId: supplierId,
        clientName: clientName,
        supplierName: supplierName,
        clientPhoto: clientPhoto,
        supplierPhoto: supplierPhoto,
        supplierAuthUid: supplierAuthUid,
      );

      _safeSetState(const AsyncValue.data(null));
      return result;
    } catch (e) {
      _safeSetState(AsyncValue.error(e, StackTrace.current));
      return Left(ChatFailure('Failed to create conversation: ${e.toString()}'));
    }
  }
}

// ==================== CHAT ACTIONS PROVIDER ====================

final chatActionsProvider =
    StateNotifierProvider<ChatActionsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final userId = ref.watch(currentUserProvider)?.uid ??
                 FirebaseAuth.instance.currentUser?.uid;
  return ChatActionsNotifier(repository, userId);
});

// ==================== UTILITY PROVIDERS ====================

/// Check if current user is in a conversation
/// Handles legacy conversations where supplier document ID might be used
final isParticipantProvider =
    Provider.family<bool, ConversationEntity>((ref, conversation) {
  final userId = ref.watch(currentUserProvider)?.uid ??
                 FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return false;

  // Check by auth UID
  if (conversation.participants.contains(userId)) return true;

  // For suppliers, also check by document ID
  final supplierState = ref.watch(supplierProvider);
  final supplierDocId = supplierState.currentSupplier?.id;
  if (supplierDocId != null && supplierDocId != userId) {
    return conversation.participants.contains(supplierDocId);
  }

  return false;
});

/// Get the other user in a conversation
/// Handles legacy conversations where supplier document ID might be used
final otherUserIdProvider =
    Provider.family<String?, ConversationEntity>((ref, conversation) {
  final userId = ref.watch(currentUserProvider)?.uid ??
                 FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return null;

  // Get supplier document ID if user is a supplier
  final supplierState = ref.watch(supplierProvider);
  final supplierDocId = supplierState.currentSupplier?.id;

  // Find participant that isn't the current user (by auth UID or supplier doc ID)
  return conversation.participants.firstWhere(
    (id) => id != userId && (supplierDocId == null || id != supplierDocId),
    orElse: () => '',
  );
});

// ==================== CHAT FAILURE ====================

class ChatFailure extends Failure {
  const ChatFailure(String message) : super(message);
}
