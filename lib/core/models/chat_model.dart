import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a chat conversation between a client and supplier.
class ChatModel {

  const ChatModel({
    required this.id,
    required this.participants,
    required this.clientId,
    required this.supplierId,
    required this.createdAt, required this.updatedAt, this.clientName,
    this.supplierName,
    this.clientPhoto,
    this.supplierPhoto,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCount = const {},
    this.isActive = true,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Safe parsing of participants list
    final rawParticipants = data['participants'];
    final participants = <String>[];
    if (rawParticipants is List) {
      for (final item in rawParticipants) {
        if (item is String) {
          participants.add(item);
        }
      }
    }

    // Safe parsing of unread count map
    final rawUnread = data['unreadCount'];
    final unreadCount = <String, int>{};
    if (rawUnread is Map) {
      rawUnread.forEach((key, value) {
        if (key is String && value is int) {
          unreadCount[key] = value;
        } else if (key is String && value is num) {
          unreadCount[key] = value.toInt();
        }
      });
    }

    return ChatModel(
      id: doc.id,
      participants: participants,
      clientId: data['clientId'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      clientName: data['clientName'] as String?,
      supplierName: data['supplierName'] as String?,
      clientPhoto: data['clientPhoto'] as String?,
      supplierPhoto: data['supplierPhoto'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: _parseTimestamp(data['lastMessageAt']),
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      unreadCount: unreadCount,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }
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

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'clientId': clientId,
      'supplierId': supplierId,
      'clientName': clientName,
      'supplierName': supplierName,
      'clientPhoto': clientPhoto,
      'supplierPhoto': supplierPhoto,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null 
          ? Timestamp.fromDate(lastMessageAt!) 
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ChatModel copyWith({
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
    return ChatModel(
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

  int getUnreadCountFor(String userId) => unreadCount[userId] ?? 0;

  String getOtherParticipantId(String currentUserId) {
    for (final id in participants) {
      if (id != currentUserId) return id;
    }
    return '';
  }

  String getOtherParticipantName(String currentUserId) {
    return currentUserId == clientId
        ? (supplierName ?? 'Fornecedor')
        : (clientName ?? 'Cliente');
  }

  String? getOtherParticipantPhoto(String currentUserId) {
    return currentUserId == clientId ? supplierPhoto : clientPhoto;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Message types supported in chat.
enum MessageType { text, image, quote, booking, system }

/// Represents a single message in a chat.
class MessageModel {

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.type,
    this.text,
    this.imageUrl,
    this.quoteData,
    this.bookingReference,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.isDeleted = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final typeStr = data['type'] as String?;
    final type = MessageType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => MessageType.text,
    );

    final quoteRaw = data['quoteData'];
    final quoteData = quoteRaw is Map<String, dynamic>
        ? QuoteData.fromMap(quoteRaw)
        : null;

    final bookingRaw = data['bookingReference'];
    final bookingRef = bookingRaw is Map<String, dynamic>
        ? BookingReference.fromMap(bookingRaw)
        : null;

    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String?,
      type: type,
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      quoteData: quoteData,
      bookingReference: bookingRef,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      readAt: _parseTimestamp(data['readAt']),
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final QuoteData? quoteData;
  final BookingReference? bookingReference;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isDeleted;

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'text': text,
      'imageUrl': imageUrl,
      'quoteData': quoteData?.toMap(),
      'bookingReference': bookingReference?.toMap(),
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'isDeleted': isDeleted,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    MessageType? type,
    String? text,
    String? imageUrl,
    QuoteData? quoteData,
    BookingReference? bookingReference,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isDeleted,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      quoteData: quoteData ?? this.quoteData,
      bookingReference: bookingReference ?? this.bookingReference,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Quote data attached to a message.
class QuoteData {

  factory QuoteData.fromMap(Map<String, dynamic> map) {
    return QuoteData(
      packageId: map['packageId'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'AOA',
      notes: map['notes'] as String?,
      validUntil: _parseTimestamp(map['validUntil']),
      status: map['status'] as String? ?? 'pending',
    );
  }

  const QuoteData({
    required this.packageId,
    required this.packageName,
    required this.price,
    this.currency = 'AOA',
    this.notes,
    this.validUntil,
    this.status = 'pending',
  });
  final String packageId;
  final String packageName;
  final int price;
  final String currency;
  final String? notes;
  final DateTime? validUntil;
  final String status;

  Map<String, dynamic> toMap() {
    return {
      'packageId': packageId,
      'packageName': packageName,
      'price': price,
      'currency': currency,
      'notes': notes,
      'validUntil': validUntil != null 
          ? Timestamp.fromDate(validUntil!) 
          : null,
      'status': status,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Reference to a booking attached to a message.
class BookingReference {

  const BookingReference({
    required this.bookingId,
    required this.eventName,
    required this.eventDate,
    required this.status,
  });

  factory BookingReference.fromMap(Map<String, dynamic> map) {
    return BookingReference(
      bookingId: map['bookingId'] as String? ?? '',
      eventName: map['eventName'] as String? ?? '',
      eventDate: _parseTimestamp(map['eventDate']) ?? DateTime.now(),
      status: map['status'] as String? ?? '',
    );
  }
  final String bookingId;
  final String eventName;
  final DateTime eventDate;
  final String status;

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'status': status,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}