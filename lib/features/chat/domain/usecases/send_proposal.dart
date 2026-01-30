import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/chat/domain/entities/message_entity.dart';
import 'package:boda_connect/features/chat/domain/repositories/chat_repository.dart';
import 'package:equatable/equatable.dart';

/// UseCase to send a booking proposal (quote) to a client
///
/// This use case is specifically designed for suppliers to send pricing
/// proposals to clients. It wraps the quote message functionality with
/// a more business-focused interface.
///
/// Usage:
/// ```dart
/// final sendProposal = SendProposal(chatRepository);
///
/// final result = await sendProposal(
///   SendProposalParams(
///     conversationId: 'conv_123',
///     supplierId: 'supplier_456',
///     clientId: 'client_789',
///     packageId: 'pkg_abc',
///     packageName: 'Premium Wedding Package',
///     price: 150000,
///     currency: 'AOA',
///     notes: 'This package includes photography, videography, and editing.',
///     validUntil: DateTime.now().add(Duration(days: 30)),
///     supplierName: 'João Photography',
///   ),
/// );
///
/// result.fold(
///   (failure) => print('Failed to send proposal: ${failure.message}'),
///   (message) => print('Proposal sent successfully'),
/// );
/// ```
class SendProposal {
  const SendProposal(this._repository);

  final ChatRepository _repository;

  /// Send a booking proposal/quote to a client
  ///
  /// This method creates a quote message with the provided pricing and
  /// package information. The quote will be sent to the client in the
  /// specified conversation.
  ///
  /// Parameters:
  /// - [params]: Contains all required information for the proposal
  ///
  /// Returns:
  /// - [ResultFuture<MessageEntity>]: The created message on success,
  ///   or a Failure on error
  ResultFuture<MessageEntity> call(SendProposalParams params) {
    // Create quote data entity from params
    final quoteData = QuoteDataEntity(
      packageId: params.packageId,
      packageName: params.packageName,
      price: params.price,
      currency: params.currency,
      notes: params.notes,
      validUntil: params.validUntil,
      status: 'pending', // Initial status is always pending
    );

    // Send quote message through repository
    return _repository.sendQuoteMessage(
      conversationId: params.conversationId,
      senderId: params.supplierId,
      receiverId: params.clientId,
      quoteData: quoteData,
      text: params.message,
      senderName: params.supplierName,
    );
  }
}

/// Parameters for sending a booking proposal
///
/// This class encapsulates all the information needed to create
/// and send a booking proposal from a supplier to a client.
class SendProposalParams extends Equatable {
  /// The conversation ID where the proposal will be sent
  final String conversationId;

  /// The ID of the supplier sending the proposal
  final String supplierId;

  /// The ID of the client receiving the proposal
  final String clientId;

  /// The ID of the package being proposed
  final String packageId;

  /// The name of the package being proposed
  final String packageName;

  /// The price of the package in the smallest currency unit
  /// (e.g., cents for USD, kwanzas for AOA)
  final int price;

  /// The currency code (e.g., 'AOA', 'USD', 'EUR')
  final String currency;

  /// Optional notes or description about the proposal
  /// Can include terms, conditions, or additional details
  final String? notes;

  /// Optional accompanying text message
  /// This appears as the message text alongside the quote
  final String? message;

  /// The date until which this proposal is valid
  /// After this date, the proposal may be considered expired
  final DateTime? validUntil;

  /// The name of the supplier (for display purposes)
  final String? supplierName;

  const SendProposalParams({
    required this.conversationId,
    required this.supplierId,
    required this.clientId,
    required this.packageId,
    required this.packageName,
    required this.price,
    this.currency = 'AOA',
    this.notes,
    this.message,
    this.validUntil,
    this.supplierName,
  });

  /// Creates a copy of this params object with updated values
  SendProposalParams copyWith({
    String? conversationId,
    String? supplierId,
    String? clientId,
    String? packageId,
    String? packageName,
    int? price,
    String? currency,
    String? notes,
    String? message,
    DateTime? validUntil,
    String? supplierName,
  }) {
    return SendProposalParams(
      conversationId: conversationId ?? this.conversationId,
      supplierId: supplierId ?? this.supplierId,
      clientId: clientId ?? this.clientId,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      message: message ?? this.message,
      validUntil: validUntil ?? this.validUntil,
      supplierName: supplierName ?? this.supplierName,
    );
  }

  @override
  List<Object?> get props => [
        conversationId,
        supplierId,
        clientId,
        packageId,
        packageName,
        price,
        currency,
        notes,
        message,
        validUntil,
        supplierName,
      ];

  @override
  String toString() {
    return 'SendProposalParams('
        'conversationId: $conversationId, '
        'supplierId: $supplierId, '
        'clientId: $clientId, '
        'packageId: $packageId, '
        'packageName: $packageName, '
        'price: $price, '
        'currency: $currency'
        ')';
  }
}
