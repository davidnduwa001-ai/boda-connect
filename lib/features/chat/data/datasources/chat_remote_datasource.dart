import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/data/models/conversation_model.dart';
import 'package:boda_connect/features/chat/data/models/message_model.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';

/// Abstract interface for chat remote data source
abstract class ChatRemoteDataSource {
  // ==================== CONVERSATIONS ====================

  /// Get all conversations for a user as a stream
  Stream<List<ConversationModel>> getConversations(String userId);

  /// Get a specific conversation by ID
  Future<ConversationModel> getConversation(String conversationId);

  /// Create a new conversation
  Future<ConversationModel> createConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
  });

  /// Get or create conversation between two users
  /// [supplierAuthUid] - Optional: supplier's Firebase Auth UID for finding legacy conversations
  Future<ConversationModel> getOrCreateConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
    String? supplierAuthUid,
  });

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId);

  // ==================== MESSAGES ====================

  /// Get all messages for a conversation as a stream
  Stream<List<MessageModel>> getMessages(String conversationId);

  /// Send a message
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required MessageType type,
    String? text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    String? senderName,
    QuoteDataEntity? quoteData,
    BookingReferenceEntity? bookingReference,
  });

  /// Mark message as read
  Future<void> markMessageAsRead({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Mark all messages in a conversation as read
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  });

  /// Delete a message
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  /// Get unread message count for user
  ///
  /// @deprecated UI-FIRST VIOLATION: Use clientUnreadMessagesProvider or
  /// supplierUnreadMessagesProvider from projections instead.
  /// This direct Firestore query causes PERMISSION_DENIED errors.
  @Deprecated('Use projection providers: clientUnreadMessagesProvider or supplierUnreadMessagesProvider')
  Future<int> getUnreadCount(String userId);

  /// Get unread message count for a specific conversation
  Future<int> getConversationUnreadCount({
    required String conversationId,
    required String userId,
  });
}

/// Implementation of ChatRemoteDataSource using Firebase Firestore
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final FirebaseFirestore _firestore;

  ChatRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection references
  // NOTE: Using 'conversations' collection to match Cloud Functions (sendMessage.ts)
  // The Cloud Function creates new conversations in 'conversations' collection
  CollectionReference get _conversationsCollection =>
      _firestore.collection('conversations');

  /// Get messages collection for a conversation, checking both new and legacy collections
  Future<CollectionReference> _getMessagesCollectionRef(String conversationId) async {
    // Check if conversation exists in new 'conversations' collection
    final convDoc = await _conversationsCollection.doc(conversationId).get();
    if (convDoc.exists) {
      return _conversationsCollection.doc(conversationId).collection('messages');
    }

    // Fallback to legacy 'chats' collection
    final legacyDoc = await _firestore.collection('chats').doc(conversationId).get();
    if (legacyDoc.exists) {
      return _firestore.collection('chats').doc(conversationId).collection('messages');
    }

    // Default to conversations collection if neither exists (for new conversations)
    return _conversationsCollection.doc(conversationId).collection('messages');
  }

  // ==================== CONVERSATIONS ====================

  @override
  Stream<List<ConversationModel>> getConversations(String userId) {
    debugPrint('🔍 Fetching conversations for user: $userId from both conversations and chats collections');

    // Use StreamController to merge both streams
    late StreamController<List<ConversationModel>> controller;

    QuerySnapshot? latestConversations;
    QuerySnapshot? latestChats;

    void emitMergedConversations() {
      if (latestConversations == null || latestChats == null) return;

      debugPrint('📬 Got ${latestConversations!.docs.length} conversations from new collection');
      debugPrint('📬 Got ${latestChats!.docs.length} conversations from legacy chats');

      // Parse conversations from new collection
      final newConversations = latestConversations!.docs
          .map((doc) {
            try {
              return ConversationModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('⚠️ Error parsing conversation ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ConversationModel>()
          .toList();

      // Parse conversations from legacy chats collection
      final legacyConversations = latestChats!.docs
          .map((doc) {
            try {
              return ConversationModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('⚠️ Error parsing legacy chat ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ConversationModel>()
          .toList();

      // Merge and deduplicate (in case a conversation exists in both)
      final allConversationsMap = <String, ConversationModel>{};

      // Add legacy conversations first
      for (final conv in legacyConversations) {
        if (conv.isActive) {
          allConversationsMap[conv.id] = conv;
        }
      }

      // Add new conversations (will override legacy if same ID)
      for (final conv in newConversations) {
        if (conv.isActive) {
          allConversationsMap[conv.id] = conv;
        }
      }

      final allConversations = allConversationsMap.values.toList();

      // Sort by lastMessageAt in code (descending - newest first)
      allConversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      debugPrint('📬 Total active conversations: ${allConversations.length}');
      controller.add(allConversations);
    }

    controller = StreamController<List<ConversationModel>>(
      onListen: () {
        // Listen to conversations collection
        final conversationsSub = _conversationsCollection
            .where('participants', arrayContains: userId)
            .snapshots()
            .listen((snapshot) {
          latestConversations = snapshot;
          emitMergedConversations();
        });

        // Listen to legacy chats collection
        final chatsSub = _firestore.collection('chats')
            .where('participants', arrayContains: userId)
            .snapshots()
            .listen((snapshot) {
          latestChats = snapshot;
          emitMergedConversations();
        });

        // Clean up subscriptions when stream is cancelled
        controller.onCancel = () {
          conversationsSub.cancel();
          chatsSub.cancel();
        };
      },
    );

    return controller.stream;
  }

  @override
  Future<ConversationModel> getConversation(String conversationId) async {
    final doc = await _conversationsCollection.doc(conversationId).get();

    if (!doc.exists) {
      throw Exception('Conversation not found');
    }

    return ConversationModel.fromFirestore(doc);
  }

  @override
  Future<ConversationModel> createConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
  }) async {
    final now = DateTime.now();
    final conversationData = {
      'participants': [clientId, supplierId],
      'clientId': clientId,
      'supplierId': supplierId,
      'clientName': clientName,
      'supplierName': supplierName,
      'clientPhoto': clientPhoto,
      'supplierPhoto': supplierPhoto,
      'lastMessage': null,
      'lastMessageAt': null,
      'lastMessageSenderId': null,
      'unreadCount': {
        clientId: 0,
        supplierId: 0,
      },
      'isActive': true,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    // Use Cloud Function to create conversation for proper validation
    // This ensures conversations are created in the correct collection
    final docRef = await _conversationsCollection.add(conversationData);
    final doc = await docRef.get();

    return ConversationModel.fromFirestore(doc);
  }

  @override
  Future<ConversationModel> getOrCreateConversation({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
    String? supplierAuthUid,
  }) async {
    debugPrint('🔍 Looking for conversation: clientId=$clientId, supplierId=$supplierId, supplierAuthUid=$supplierAuthUid');

    // Build list of supplier IDs to search for (document ID + auth UID for legacy)
    final supplierIdsToSearch = <String>{supplierId};
    if (supplierAuthUid != null && supplierAuthUid.isNotEmpty && supplierAuthUid != supplierId) {
      supplierIdsToSearch.add(supplierAuthUid);
    }

    // Strategy 1: Try exact match on clientId and each possible supplierId
    // Try both 'conversations' (new) and 'chats' (legacy) collections
    for (final searchSupplierId in supplierIdsToSearch) {
      // Try new 'conversations' collection
      try {
        final querySnapshot = await _conversationsCollection
            .where('clientId', isEqualTo: clientId)
            .where('supplierId', isEqualTo: searchSupplierId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          debugPrint('✅ Found existing conversation (exact match with $searchSupplierId): ${querySnapshot.docs.first.id}');
          return ConversationModel.fromFirestore(querySnapshot.docs.first);
        }
      } catch (e) {
        debugPrint('⚠️ Exact match query failed for $searchSupplierId: $e');
      }

      // Fallback: Try legacy 'chats' collection
      try {
        final legacySnapshot = await _firestore.collection('chats')
            .where('clientId', isEqualTo: clientId)
            .where('supplierId', isEqualTo: searchSupplierId)
            .limit(1)
            .get();

        if (legacySnapshot.docs.isNotEmpty) {
          debugPrint('✅ Found existing conversation in legacy chats (exact match with $searchSupplierId): ${legacySnapshot.docs.first.id}');
          return ConversationModel.fromFirestore(legacySnapshot.docs.first);
        }
      } catch (e) {
        debugPrint('⚠️ Legacy chats exact match query failed for $searchSupplierId: $e');
      }
    }

    // Strategy 2: Search by participants array - find any conversation with both users
    // This handles cases where IDs might be stored differently (userId vs documentId)
    try {
      debugPrint('🔍 Trying participants-based search in conversations collection...');
      var participantsQuery = await _conversationsCollection
          .where('participants', arrayContains: clientId)
          .get();

      // Check if any conversation contains the supplier in participants (using any supplier ID)
      for (final doc in participantsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final participants = data['participants'] as List<dynamic>?;
          final docSupplierId = data['supplierId'] as String?;

          // Check if any of the supplier IDs match
          for (final searchSupplierId in supplierIdsToSearch) {
            if (participants != null && participants.contains(searchSupplierId)) {
              debugPrint('✅ Found conversation via participants ($searchSupplierId): ${doc.id}');
              return ConversationModel.fromFirestore(doc);
            }
            if (docSupplierId == searchSupplierId) {
              debugPrint('✅ Found conversation via supplierId match ($searchSupplierId): ${doc.id}');
              return ConversationModel.fromFirestore(doc);
            }
          }
        }
      }

      // Try legacy 'chats' collection for participants-based search
      debugPrint('🔍 Trying participants-based search in legacy chats collection...');
      final legacyParticipantsQuery = await _firestore.collection('chats')
          .where('participants', arrayContains: clientId)
          .get();

      for (final doc in legacyParticipantsQuery.docs) {
        final data = doc.data();
        final participants = data['participants'] as List<dynamic>?;
        final docSupplierId = data['supplierId'] as String?;

        for (final searchSupplierId in supplierIdsToSearch) {
          if (participants != null && participants.contains(searchSupplierId)) {
            debugPrint('✅ Found conversation via participants in legacy chats ($searchSupplierId): ${doc.id}');
            return ConversationModel.fromFirestore(doc);
          }
          if (docSupplierId == searchSupplierId) {
            debugPrint('✅ Found conversation via supplierId match in legacy chats ($searchSupplierId): ${doc.id}');
            return ConversationModel.fromFirestore(doc);
          }
        }
      }

      // Strategy 3: Search from supplier's perspective using each possible supplier ID
      for (final searchSupplierId in supplierIdsToSearch) {
        debugPrint('🔍 Trying supplier-based search with $searchSupplierId...');
        final supplierQuery = await _conversationsCollection
            .where('participants', arrayContains: searchSupplierId)
            .get();

        for (final doc in supplierQuery.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final participants = data['participants'] as List<dynamic>?;
            if (participants != null && participants.contains(clientId)) {
              debugPrint('✅ Found conversation via supplier search ($searchSupplierId): ${doc.id}');
              return ConversationModel.fromFirestore(doc);
            }
            if (data['clientId'] == clientId) {
              debugPrint('✅ Found conversation via clientId match: ${doc.id}');
              return ConversationModel.fromFirestore(doc);
            }
          }
        }

        // Also try legacy 'chats' collection for supplier-based search
        debugPrint('🔍 Trying supplier-based search with $searchSupplierId in legacy chats...');
        final legacySupplierQuery = await _firestore.collection('chats')
            .where('participants', arrayContains: searchSupplierId)
            .get();

        for (final doc in legacySupplierQuery.docs) {
          final data = doc.data();
          final participants = data['participants'] as List<dynamic>?;
          if (participants != null && participants.contains(clientId)) {
            debugPrint('✅ Found conversation via supplier search in legacy chats ($searchSupplierId): ${doc.id}');
            return ConversationModel.fromFirestore(doc);
          }
          if (data['clientId'] == clientId) {
            debugPrint('✅ Found conversation via clientId match in legacy chats: ${doc.id}');
            return ConversationModel.fromFirestore(doc);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Participants query failed: $e');
    }

    // If still not found, create new conversation (always use document ID for new ones)
    debugPrint('📝 No existing conversation found, creating new one between $clientId and $supplierId');
    return createConversation(
      clientId: clientId,
      supplierId: supplierId,
      clientName: clientName,
      supplierName: supplierName,
      clientPhoto: clientPhoto,
      supplierPhoto: supplierPhoto,
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _conversationsCollection.doc(conversationId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ==================== MESSAGES ====================

  @override
  Stream<List<MessageModel>> getMessages(String conversationId) async* {
    // Query without isDeleted filter to handle messages that may not have this field set
    // Filter deleted messages in code instead to be more resilient

    // Get the correct collection reference (checks both conversations and legacy chats)
    final messagesRef = await _getMessagesCollectionRef(conversationId);

    // Stream messages from the correct collection
    yield* messagesRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .where((msg) => !msg.isDeleted) // Filter out deleted messages in code
          .toList();
    });
  }

  /// UI-FIRST: Send message via Cloud Function for secure permission validation
  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required MessageType type,
    String? text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    String? senderName,
    QuoteDataEntity? quoteData,
    BookingReferenceEntity? bookingReference,
  }) async {
    try {
      // Use Cloud Function for secure message sending
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendMessage');

      // Map message type to Cloud Function format
      String cfType;
      switch (type) {
        case MessageType.text:
          cfType = 'text';
        case MessageType.image:
          cfType = 'image';
        case MessageType.quote:
          cfType = 'quote';
        case MessageType.file:
          cfType = 'file';
        default:
          cfType = 'text';
      }

      // Build request payload
      final Map<String, dynamic> payload = {
        'conversationId': conversationId,
        'type': cfType,
      };

      if (text != null && text.isNotEmpty) {
        payload['text'] = text;
      }

      if (imageUrl != null) {
        payload['imageUrl'] = imageUrl;
      }

      if (fileUrl != null) {
        payload['fileUrl'] = fileUrl;
        payload['fileName'] = fileName;
      }

      if (quoteData != null) {
        payload['quoteData'] = {
          'description': quoteData.packageName,
          'amount': quoteData.price,
          'currency': quoteData.currency,
          if (quoteData.validUntil != null)
            'validUntil': quoteData.validUntil!.toIso8601String(),
        };
      }

      final result = await callable.call<Map<String, dynamic>>(payload);

      // Safely handle response
      final rawData = result.data;
      final Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        throw Exception('Invalid response from sendMessage');
      }

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to send message');
      }

      final messageId = data['messageId'] as String;
      final now = DateTime.now();

      // Return a MessageModel with the server-created ID
      return MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        senderName: senderName,
        type: type,
        text: text,
        imageUrl: imageUrl,
        fileUrl: fileUrl,
        fileName: fileName,
        quoteData: quoteData,
        bookingReference: bookingReference,
        isRead: false,
        timestamp: now,
        readAt: null,
        isDeleted: false,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ sendMessage Cloud Function error: ${e.code} - ${e.message}');
      // Re-throw with a user-friendly message
      if (e.code == 'permission-denied') {
        throw Exception('Sem permissão para enviar mensagem nesta conversa');
      } else if (e.code == 'unauthenticated') {
        throw Exception('Sessão expirada. Por favor, faça login novamente.');
      }
      throw Exception(e.message ?? 'Erro ao enviar mensagem');
    } catch (e) {
      debugPrint('⚠️ sendMessage error: $e');
      throw Exception('Erro ao enviar mensagem: $e');
    }
  }

  @override
  Future<void> markMessageAsRead({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    final messagesRef = await _getMessagesCollectionRef(conversationId);
    await messagesRef.doc(messageId).update({
      'isRead': true,
      'readAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update conversation unread count
    await _updateConversationUnreadCount(conversationId, userId);
  }

  /// UI-FIRST: Mark conversation as read via Cloud Function
  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('markConversationAsRead');

      final result = await callable.call<Map<String, dynamic>>({
        'conversationId': conversationId,
      });

      // Safely handle response
      final rawData = result.data;
      final Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        debugPrint('⚠️ markConversationAsRead: Invalid response type');
        return;
      }

      if (data['success'] == true) {
        debugPrint('✅ Marked ${data['markedCount']} messages as read');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ markConversationAsRead CF error: ${e.code} - ${e.message}');
      // Fail silently - this is not critical
    } catch (e) {
      debugPrint('⚠️ markConversationAsRead error: $e');
    }
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final messagesRef = await _getMessagesCollectionRef(conversationId);
    await messagesRef.doc(messageId).update({
      'isDeleted': true,
    });
  }

  @override
  @Deprecated('Use projection providers: clientUnreadMessagesProvider or supplierUnreadMessagesProvider')
  Future<int> getUnreadCount(String userId) async {
    // UI-FIRST: This method is deprecated. Unread counts should come from projections.
    // Returning 0 to avoid PERMISSION_DENIED errors from direct Firestore queries.
    // Use clientUnreadMessagesProvider or supplierUnreadMessagesProvider instead.
    debugPrint('⚠️ getUnreadCount is deprecated. Use projection providers for unread counts.');
    try {
      final conversations = await _conversationsCollection
          .where('participants', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      int totalUnread = 0;
      for (final doc in conversations.docs) {
        final data = doc.data() as DataMap;
        final unreadCount = data['unreadCount'] as Map<dynamic, dynamic>?;
        if (unreadCount != null && unreadCount.containsKey(userId)) {
          totalUnread += (unreadCount[userId] as int?) ?? 0;
        }
      }

      return totalUnread;
    } catch (e) {
      // Gracefully handle permission errors - return 0 and log warning
      debugPrint('⚠️ getUnreadCount failed (expected if using projections): $e');
      return 0;
    }
  }

  @override
  Future<int> getConversationUnreadCount({
    required String conversationId,
    required String userId,
  }) async {
    final doc = await _conversationsCollection.doc(conversationId).get();

    if (!doc.exists) {
      return 0;
    }

    final data = doc.data() as DataMap;
    final unreadCount = data['unreadCount'] as Map<dynamic, dynamic>?;

    if (unreadCount == null || !unreadCount.containsKey(userId)) {
      return 0;
    }

    return (unreadCount[userId] as int?) ?? 0;
  }

  // ==================== HELPER METHODS ====================

  /// Update conversation with last message information
  Future<void> _updateConversationLastMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    required DateTime timestamp,
  }) async {
    // Find the correct conversation reference (conversations or legacy chats)
    final convDoc = await _conversationsCollection.doc(conversationId).get();
    final conversationRef = convDoc.exists
        ? _conversationsCollection.doc(conversationId)
        : _firestore.collection('chats').doc(conversationId);

    // Get current unread count
    final doc = await conversationRef.get();
    final data = doc.data() as DataMap?;
    final currentUnreadCount = data?['unreadCount'] as Map<dynamic, dynamic>? ?? {};

    // Increment receiver's unread count
    final newUnreadCount = Map<String, int>.from(
      currentUnreadCount.map((key, value) =>
          MapEntry(key.toString(), value as int)),
    );
    newUnreadCount[receiverId] = (newUnreadCount[receiverId] ?? 0) + 1;

    await conversationRef.update({
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(timestamp),
      'lastMessageSenderId': senderId,
      'unreadCount': newUnreadCount,
      'updatedAt': Timestamp.fromDate(timestamp),
    });
  }

  /// Update conversation unread count for a user
  Future<void> _updateConversationUnreadCount(
    String conversationId,
    String userId,
  ) async {
    final messagesRef = await _getMessagesCollectionRef(conversationId);
    final unreadMessages = await messagesRef
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .get();

    // Update in the correct collection (conversations or legacy chats)
    final convDoc = await _conversationsCollection.doc(conversationId).get();
    final conversationRef = convDoc.exists
        ? _conversationsCollection.doc(conversationId)
        : _firestore.collection('chats').doc(conversationId);

    await conversationRef.update({
      'unreadCount.$userId': unreadMessages.docs.length,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Get message preview text based on message type
  String _getMessagePreview(MessageType type, String? text) {
    switch (type) {
      case MessageType.text:
        return text ?? '';
      case MessageType.image:
        return 'Enviou uma imagem';
      case MessageType.file:
        return 'Enviou um arquivo';
      case MessageType.quote:
        return 'Enviou um orçamento';
      case MessageType.booking:
        return 'Enviou uma referência de reserva';
      case MessageType.system:
        return text ?? 'Mensagem do sistema';
    }
  }
}
