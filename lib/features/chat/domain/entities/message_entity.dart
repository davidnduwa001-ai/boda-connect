import 'package:equatable/equatable.dart';
import 'message_type.dart';

export 'message_type.dart';

/// Pure Dart entity representing a Message in the domain layer
/// This entity is independent of any framework or external library
class MessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String? senderName;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final QuoteDataEntity? quoteData;
  final BookingReferenceEntity? bookingReference;
  final bool isRead;
  final DateTime timestamp;
  final DateTime? readAt;
  final bool isDeleted;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.senderName,
    required this.type,
    this.text,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.quoteData,
    this.bookingReference,
    required this.isRead,
    required this.timestamp,
    this.readAt,
    this.isDeleted = false,
  });

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        receiverId,
        senderName,
        type,
        text,
        imageUrl,
        fileUrl,
        fileName,
        quoteData,
        bookingReference,
        isRead,
        timestamp,
        readAt,
        isDeleted,
      ];

  MessageEntity copyWith({
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
    return MessageEntity(
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

/// Quote data entity attached to a message
class QuoteDataEntity extends Equatable {
  final String packageId;
  final String packageName;
  final int price;
  final String currency;
  final String? notes;
  final DateTime? validUntil;
  final String status;

  const QuoteDataEntity({
    required this.packageId,
    required this.packageName,
    required this.price,
    this.currency = 'AOA',
    this.notes,
    this.validUntil,
    this.status = 'pending',
  });

  @override
  List<Object?> get props => [
        packageId,
        packageName,
        price,
        currency,
        notes,
        validUntil,
        status,
      ];

  QuoteDataEntity copyWith({
    String? packageId,
    String? packageName,
    int? price,
    String? currency,
    String? notes,
    DateTime? validUntil,
    String? status,
  }) {
    return QuoteDataEntity(
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
    );
  }
}

/// Booking reference entity attached to a message
class BookingReferenceEntity extends Equatable {
  final String bookingId;
  final String eventName;
  final DateTime eventDate;
  final String status;

  const BookingReferenceEntity({
    required this.bookingId,
    required this.eventName,
    required this.eventDate,
    required this.status,
  });

  @override
  List<Object?> get props => [
        bookingId,
        eventName,
        eventDate,
        status,
      ];

  BookingReferenceEntity copyWith({
    String? bookingId,
    String? eventName,
    DateTime? eventDate,
    String? status,
  }) {
    return BookingReferenceEntity(
      bookingId: bookingId ?? this.bookingId,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      status: status ?? this.status,
    );
  }
}
