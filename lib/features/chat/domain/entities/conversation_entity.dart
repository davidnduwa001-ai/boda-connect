import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a Conversation in the domain layer
/// This entity is independent of any framework or external library
class ConversationEntity extends Equatable {
  final String id;
  final List<String> participants;
  final String clientId;
  final String supplierId;
  final String? clientName;
  final String? supplierName;
  final String? clientPhoto;
  final String? supplierPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationEntity({
    required this.id,
    required this.participants,
    required this.clientId,
    required this.supplierId,
    this.clientName,
    this.supplierName,
    this.clientPhoto,
    this.supplierPhoto,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCount = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        participants,
        clientId,
        supplierId,
        clientName,
        supplierName,
        clientPhoto,
        supplierPhoto,
        lastMessage,
        lastMessageAt,
        lastMessageSenderId,
        unreadCount,
        isActive,
        createdAt,
        updatedAt,
      ];

  ConversationEntity copyWith({
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
    return ConversationEntity(
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

  /// Get unread count for a specific user
  int getUnreadCountFor(String userId) => unreadCount[userId] ?? 0;

  /// Get the other participant's ID
  String getOtherParticipantId(String currentUserId) {
    for (final id in participants) {
      if (id != currentUserId) return id;
    }
    return '';
  }

  /// Get the other participant's name
  String getOtherParticipantName(String currentUserId) {
    return currentUserId == clientId
        ? (supplierName ?? 'Fornecedor')
        : (clientName ?? 'Cliente');
  }

  /// Get the other participant's photo
  String? getOtherParticipantPhoto(String currentUserId) {
    return currentUserId == clientId ? supplierPhoto : clientPhoto;
  }
}
