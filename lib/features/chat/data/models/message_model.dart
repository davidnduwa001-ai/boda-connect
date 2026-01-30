import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';

/// Data model for Message that extends MessageEntity
/// Handles conversion between Firestore and domain entity
class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.receiverId,
    super.senderName,
    required super.type,
    super.text,
    super.imageUrl,
    super.fileUrl,
    super.fileName,
    super.quoteData,
    super.bookingReference,
    required super.isRead,
    required super.timestamp,
    super.readAt,
    super.isDeleted,
  });

  /// Create MessageModel from MessageEntity
  factory MessageModel.fromEntity(MessageEntity entity) {
    return MessageModel(
      id: entity.id,
      conversationId: entity.conversationId,
      senderId: entity.senderId,
      receiverId: entity.receiverId,
      senderName: entity.senderName,
      type: entity.type,
      text: entity.text,
      imageUrl: entity.imageUrl,
      fileUrl: entity.fileUrl,
      fileName: entity.fileName,
      quoteData: entity.quoteData,
      bookingReference: entity.bookingReference,
      isRead: entity.isRead,
      timestamp: entity.timestamp,
      readAt: entity.readAt,
      isDeleted: entity.isDeleted,
    );
  }

  /// Create MessageModel from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as DataMap;

    // Extract conversationId from document path if not in data
    // Path format: conversations/{conversationId}/messages/{messageId}
    // or: chats/{conversationId}/messages/{messageId}
    String conversationId = data['conversationId'] as String? ?? '';
    if (conversationId.isEmpty && doc.reference.parent.parent != null) {
      conversationId = doc.reference.parent.parent!.id;
    }

    // Handle null senderId/receiverId gracefully
    final senderId = data['senderId'] as String? ?? '';
    final receiverId = data['receiverId'] as String? ?? '';

    // Handle timestamp - could be 'timestamp' or 'createdAt'
    DateTime messageTimestamp;
    if (data['timestamp'] != null) {
      messageTimestamp = (data['timestamp'] as Timestamp).toDate();
    } else if (data['createdAt'] != null) {
      messageTimestamp = (data['createdAt'] as Timestamp).toDate();
    } else {
      messageTimestamp = DateTime.now();
    }

    return MessageModel(
      id: doc.id,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      senderName: data['senderName'] as String?,
      type: _messageTypeFromString(data['type'] as String? ?? 'text'),
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      fileUrl: data['fileUrl'] as String?,
      fileName: data['fileName'] as String?,
      quoteData: data['quoteData'] != null
          ? QuoteDataModel.fromMap(data['quoteData'] as DataMap).toEntity()
          : null,
      bookingReference: data['bookingReference'] != null
          ? BookingReferenceModel.fromMap(
              data['bookingReference'] as DataMap,
            ).toEntity()
          : null,
      isRead: data['isRead'] as bool? ?? false,
      timestamp: messageTimestamp,
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  /// Convert MessageModel to Firestore document data
  DataMap toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'type': type.name,
      'text': text,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'quoteData': quoteData != null
          ? QuoteDataModel.fromEntity(quoteData!).toMap()
          : null,
      'bookingReference': bookingReference != null
          ? BookingReferenceModel.fromEntity(bookingReference!).toMap()
          : null,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'isDeleted': isDeleted,
    };
  }

  /// Convert MessageModel to MessageEntity
  MessageEntity toEntity() {
    return MessageEntity(
      id: id,
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
      isRead: isRead,
      timestamp: timestamp,
      readAt: readAt,
      isDeleted: isDeleted,
    );
  }

  /// Helper method to convert string to MessageType enum
  static MessageType _messageTypeFromString(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'quote':
        return MessageType.quote;
      case 'booking':
        return MessageType.booking;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? senderName,
    MessageType? type,
    String? text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    QuoteDataEntity? quoteData,
    BookingReferenceEntity? bookingReference,
    bool? isRead,
    DateTime? timestamp,
    DateTime? readAt,
    bool? isDeleted,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      quoteData: quoteData ?? this.quoteData,
      bookingReference: bookingReference ?? this.bookingReference,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      readAt: readAt ?? this.readAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Data model for QuoteData
class QuoteDataModel extends QuoteDataEntity {
  const QuoteDataModel({
    required super.packageId,
    required super.packageName,
    required super.price,
    super.currency,
    super.notes,
    super.validUntil,
    super.status,
  });

  /// Create QuoteDataModel from QuoteDataEntity
  factory QuoteDataModel.fromEntity(QuoteDataEntity entity) {
    return QuoteDataModel(
      packageId: entity.packageId,
      packageName: entity.packageName,
      price: entity.price,
      currency: entity.currency,
      notes: entity.notes,
      validUntil: entity.validUntil,
      status: entity.status,
    );
  }

  /// Create QuoteDataModel from map
  factory QuoteDataModel.fromMap(DataMap map) {
    return QuoteDataModel(
      packageId: map['packageId'] as String,
      packageName: map['packageName'] as String,
      price: map['price'] as int,
      currency: map['currency'] as String? ?? 'AOA',
      notes: map['notes'] as String?,
      validUntil: map['validUntil'] != null
          ? (map['validUntil'] as Timestamp).toDate()
          : null,
      status: map['status'] as String? ?? 'pending',
    );
  }

  /// Convert QuoteDataModel to map
  DataMap toMap() {
    return {
      'packageId': packageId,
      'packageName': packageName,
      'price': price,
      'currency': currency,
      'notes': notes,
      'validUntil':
          validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'status': status,
    };
  }

  /// Convert QuoteDataModel to QuoteDataEntity
  QuoteDataEntity toEntity() {
    return QuoteDataEntity(
      packageId: packageId,
      packageName: packageName,
      price: price,
      currency: currency,
      notes: notes,
      validUntil: validUntil,
      status: status,
    );
  }
}

/// Data model for BookingReference
class BookingReferenceModel extends BookingReferenceEntity {
  const BookingReferenceModel({
    required super.bookingId,
    required super.eventName,
    required super.eventDate,
    required super.status,
  });

  /// Create BookingReferenceModel from BookingReferenceEntity
  factory BookingReferenceModel.fromEntity(BookingReferenceEntity entity) {
    return BookingReferenceModel(
      bookingId: entity.bookingId,
      eventName: entity.eventName,
      eventDate: entity.eventDate,
      status: entity.status,
    );
  }

  /// Create BookingReferenceModel from map
  factory BookingReferenceModel.fromMap(DataMap map) {
    return BookingReferenceModel(
      bookingId: map['bookingId'] as String,
      eventName: map['eventName'] as String,
      eventDate: (map['eventDate'] as Timestamp).toDate(),
      status: map['status'] as String,
    );
  }

  /// Convert BookingReferenceModel to map
  DataMap toMap() {
    return {
      'bookingId': bookingId,
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'status': status,
    };
  }

  /// Convert BookingReferenceModel to BookingReferenceEntity
  BookingReferenceEntity toEntity() {
    return BookingReferenceEntity(
      bookingId: bookingId,
      eventName: eventName,
      eventDate: eventDate,
      status: status,
    );
  }
}
