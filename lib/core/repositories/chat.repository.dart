import 'package:boda_connect/core/models/chat_model.dart';
import 'package:boda_connect/core/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ChatRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  // ==================== CHAT MANAGEMENT ====================

  /// Get or create chat between client and supplier
  Future<String> getOrCreateChat({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
  }) async {
    return await _firestoreService.getOrCreateChat(
      clientId: clientId,
      supplierId: supplierId,
      clientName: clientName,
      supplierName: supplierName,
    );
  }

  /// Get single chat by ID
  Future<ChatModel?> getChat(String chatId) async {
    final doc = await _firestoreService.chats.doc(chatId).get();
    if (!doc.exists) return null;
    return ChatModel.fromFirestore(doc);
  }

  /// Get user's chats as stream
  Stream<List<ChatModel>> getUserChatsStream(String userId) {
    return _firestoreService.getUserChats(userId);
  }

  /// Get user's chats (one-time)
  Future<List<ChatModel>> getUserChats(String userId) async {
    final snapshot = await _firestoreService.chats
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
  }

  /// Delete/archive chat
  Future<void> archiveChat(String chatId) async {
    await _firestoreService.chats.doc(chatId).update({
      'isActive': false,
      'updatedAt': Timestamp.now(),
    });
  }

  // ==================== MESSAGES ====================

  /// Send message
  Future<String> sendMessage(MessageModel message) async {
    return await _firestoreService.sendMessage(message);
  }

  /// Get messages as stream
  Stream<List<MessageModel>> getMessagesStream(String chatId,
      {int limit = 50}) {
    return _firestoreService.getChatMessages(chatId, limit: limit);
  }

  /// Get messages (one-time, for pagination)
  Future<List<MessageModel>> getMessages(
    String chatId, {
    DateTime? startAfter,
    int limit = 50,
  }) async {
    Query query = _firestoreService.chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    await _firestoreService.markMessagesAsRead(chatId, userId);
  }

  /// Upload chat image
  Future<String> uploadChatImage(String chatId, XFile file) async {
    return await _storageService.uploadChatImage(chatId, file);
  }

  /// Delete message (soft delete)
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestoreService.chats
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeleted': true,
      'text': 'Mensagem eliminada',
    });
  }

  // ==================== UNREAD COUNTS ====================

  /// Get total unread count for user
  Future<int> getTotalUnreadCount(String userId) async {
    final chats = await getUserChats(userId);
    int total = 0;
    for (final chat in chats) {
      total += chat.getUnreadCountFor(userId);
    }
    return total;
  }

  /// Get unread count for specific chat
  Future<int> getUnreadCount(String chatId, String userId) async {
    final chat = await getChat(chatId);
    return chat?.getUnreadCountFor(userId) ?? 0;
  }

  // ==================== FAVORITES ====================

  /// Add supplier to favorites
  Future<void> addFavorite(String clientId, String supplierId) async {
    await _firestoreService.addFavorite(clientId, supplierId);
  }

  /// Remove supplier from favorites
  Future<void> removeFavorite(String clientId, String supplierId) async {
    await _firestoreService.removeFavorite(clientId, supplierId);
  }

  /// Check if supplier is favorite
  Future<bool> isFavorite(String clientId, String supplierId) async {
    return await _firestoreService.isFavorite(clientId, supplierId);
  }

  /// Get user's favorite supplier IDs
  Future<List<String>> getUserFavorites(String clientId) async {
    return await _firestoreService.getUserFavorites(clientId);
  }

  // ==================== TYPING INDICATORS ====================

  /// Set typing status
  Future<void> setTyping(String chatId, String userId, bool isTyping) async {
    await _firestoreService.chats.doc(chatId).update({
      'typing.$userId': isTyping,
    });
  }

  /// Get typing status stream
  Stream<Map<String, bool>> getTypingStatus(String chatId) {
    return _firestoreService.chats.doc(chatId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final typing = data?['typing'] as Map<String, dynamic>?;
      return typing?.map((k, v) => MapEntry(k, v as bool)) ?? {};
    });
  }

  // ==================== SEARCH ====================

  /// Search messages in chat
  Future<List<MessageModel>> searchMessages(
    String chatId,
    String query,
  ) async {
    final snapshot = await _firestoreService.chats
        .doc(chatId)
        .collection('messages')
        .where('type', isEqualTo: 'text')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final lowercaseQuery = query.toLowerCase();

    return snapshot.docs
        .map((doc) => MessageModel.fromFirestore(doc))
        .where(
            (msg) => msg.text?.toLowerCase().contains(lowercaseQuery) ?? false)
        .toList();
  }

  // ==================== PRESENCE ====================

  /// Update user's online status
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _firestoreService.users.doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': Timestamp.now(),
    });
  }

  /// Get user's online status
  Future<Map<String, dynamic>> getUserPresence(String userId) async {
    final doc = await _firestoreService.users.doc(userId).get();
    final data = doc.data() as Map<String, dynamic>?;

    return {
      'isOnline': data?['isOnline'] ?? false,
      'lastSeen': (data?['lastSeen'] as Timestamp?)?.toDate(),
    };
  }
}
