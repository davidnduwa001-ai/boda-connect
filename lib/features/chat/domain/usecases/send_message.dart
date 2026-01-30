import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:equatable/equatable.dart';

/// UseCase to send a message in a conversation
class SendMessage {
  const SendMessage(this._repository);

  final ChatRepository _repository;

  /// Send a message based on the provided parameters
  /// Supports different message types: text, image, file, quote, booking
  ResultFuture<MessageEntity> call(SendMessageParams params) {
    switch (params.type) {
      case MessageType.text:
        return _repository.sendMessage(
          conversationId: params.conversationId,
          senderId: params.senderId,
          receiverId: params.receiverId,
          text: params.text!,
          senderName: params.senderName,
        );

      case MessageType.image:
        return _repository.sendImageMessage(
          conversationId: params.conversationId,
          senderId: params.senderId,
          receiverId: params.receiverId,
          imageUrl: params.imageUrl!,
          text: params.text,
          senderName: params.senderName,
        );

      case MessageType.file:
        return _repository.sendFileMessage(
          conversationId: params.conversationId,
          senderId: params.senderId,
          receiverId: params.receiverId,
          fileUrl: params.fileUrl!,
          fileName: params.fileName!,
          text: params.text,
          senderName: params.senderName,
        );

      case MessageType.quote:
        return _repository.sendQuoteMessage(
          conversationId: params.conversationId,
          senderId: params.senderId,
          receiverId: params.receiverId,
          quoteData: params.quoteData!,
          text: params.text,
          senderName: params.senderName,
        );

      case MessageType.booking:
        return _repository.sendBookingMessage(
          conversationId: params.conversationId,
          senderId: params.senderId,
          receiverId: params.receiverId,
          bookingReference: params.bookingReference!,
          text: params.text,
          senderName: params.senderName,
        );

      case MessageType.system:
        // System messages should not be sent by users
        throw UnsupportedError('System messages cannot be sent by users');
    }
  }
}

/// Parameters for sending a message
class SendMessageParams extends Equatable {
  final String conversationId;
  final String senderId;
  final String receiverId;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final QuoteDataEntity? quoteData;
  final BookingReferenceEntity? bookingReference;
  final String? senderName;

  const SendMessageParams({
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    this.text,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.quoteData,
    this.bookingReference,
    this.senderName,
  });

  /// Factory for text message
  factory SendMessageParams.text({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    String? senderName,
  }) {
    return SendMessageParams(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      type: MessageType.text,
      text: text,
      senderName: senderName,
    );
  }

  /// Factory for image message
  factory SendMessageParams.image({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String? text,
    String? senderName,
  }) {
    return SendMessageParams(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      type: MessageType.image,
      imageUrl: imageUrl,
      text: text,
      senderName: senderName,
    );
  }

  /// Factory for file message
  factory SendMessageParams.file({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String fileUrl,
    required String fileName,
    String? text,
    String? senderName,
  }) {
    return SendMessageParams(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      type: MessageType.file,
      fileUrl: fileUrl,
      fileName: fileName,
      text: text,
      senderName: senderName,
    );
  }

  /// Factory for quote message
  factory SendMessageParams.quote({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required QuoteDataEntity quoteData,
    String? text,
    String? senderName,
  }) {
    return SendMessageParams(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      type: MessageType.quote,
      quoteData: quoteData,
      text: text,
      senderName: senderName,
    );
  }

  /// Factory for booking message
  factory SendMessageParams.booking({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required BookingReferenceEntity bookingReference,
    String? text,
    String? senderName,
  }) {
    return SendMessageParams(
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      type: MessageType.booking,
      bookingReference: bookingReference,
      text: text,
      senderName: senderName,
    );
  }

  @override
  List<Object?> get props => [
        conversationId,
        senderId,
        receiverId,
        type,
        text,
        imageUrl,
        fileUrl,
        fileName,
        quoteData,
        bookingReference,
        senderName,
      ];
}
