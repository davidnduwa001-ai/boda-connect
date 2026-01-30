import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/domain/entities/conversation_entity.dart';

/// Data model for Conversation that extends ConversationEntity
/// Handles conversion between Firestore and domain entity
class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.participants,
    required super.clientId,
    required super.supplierId,
    super.clientName,
    super.supplierName,
    super.clientPhoto,
    super.supplierPhoto,
    super.lastMessage,
    super.lastMessageAt,
    super.lastMessageSenderId,
    super.unreadCount,
    super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create ConversationModel from ConversationEntity
  factory ConversationModel.fromEntity(ConversationEntity entity) {
    return ConversationModel(
      id: entity.id,
      participants: entity.participants,
      clientId: entity.clientId,
      supplierId: entity.supplierId,
      clientName: entity.clientName,
      supplierName: entity.supplierName,
      clientPhoto: entity.clientPhoto,
      supplierPhoto: entity.supplierPhoto,
      lastMessage: entity.lastMessage,
      lastMessageAt: entity.lastMessageAt,
      lastMessageSenderId: entity.lastMessageSenderId,
      unreadCount: entity.unreadCount,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create ConversationModel from Firestore document
  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as DataMap;

    // Handle legacy documents that might have null clientId/supplierId
    // Extract from participants array if needed
    final participants = List<String>.from(data['participants'] as List<dynamic>? ?? []);
    String clientId = data['clientId'] as String? ?? '';
    String supplierId = data['supplierId'] as String? ?? '';

    // If clientId/supplierId are empty, try to extract from participants
    if (clientId.isEmpty && participants.isNotEmpty) {
      clientId = participants.first;
    }
    if (supplierId.isEmpty && participants.length > 1) {
      supplierId = participants[1];
    }

    // Skip invalid conversations that don't have required data
    if (clientId.isEmpty || supplierId.isEmpty) {
      throw FormatException('Conversation ${doc.id} missing required clientId or supplierId');
    }

    return ConversationModel(
      id: doc.id,
      participants: participants,
      clientId: clientId,
      supplierId: supplierId,
      clientName: data['clientName'] as String?,
      supplierName: data['supplierName'] as String?,
      clientPhoto: data['clientPhoto'] as String?,
      supplierPhoto: data['supplierPhoto'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      unreadCount: _parseUnreadCount(data['unreadCount']),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert ConversationModel to Firestore document data
  DataMap toFirestore() {
    return {
      'participants': participants,
      'clientId': clientId,
      'supplierId': supplierId,
      'clientName': clientName,
      'supplierName': supplierName,
      'clientPhoto': clientPhoto,
      'supplierPhoto': supplierPhoto,
      'lastMessage': lastMessage,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert ConversationModel to ConversationEntity
  ConversationEntity toEntity() {
    return ConversationEntity(
      id: id,
      participants: participants,
      clientId: clientId,
      supplierId: supplierId,
      clientName: clientName,
      supplierName: supplierName,
      clientPhoto: clientPhoto,
      supplierPhoto: supplierPhoto,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastMessageSenderId: lastMessageSenderId,
      unreadCount: unreadCount,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Helper method to parse unread count from Firestore
  static Map<String, int> _parseUnreadCount(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return Map<String, int>.from(
        data.map((key, value) => MapEntry(key.toString(), value as int)),
      );
    }
    return {};
  }

  ConversationModel copyWith({
    String? id,
    List<String>? participants,
    String? clientId,
    String? supplierId,
    String? clientName,
    String? supplierName,
    String? clientPhoto,
    String? supplierPhoto,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    Map<String, int>? unreadCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      clientId: clientId ?? this.clientId,
      supplierId: supplierId ?? this.supplierId,
      clientName: clientName ?? this.clientName,
      supplierName: supplierName ?? this.supplierName,
      clientPhoto: clientPhoto ?? this.clientPhoto,
      supplierPhoto: supplierPhoto ?? this.supplierPhoto,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
