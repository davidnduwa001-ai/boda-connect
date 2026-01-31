import 'package:boda_connect/core/models/custom_offer_model.dart';
import 'package:boda_connect/core/models/chat_model.dart';
import 'package:boda_connect/core/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Repository for managing custom offers between suppliers and clients
class CustomOfferRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Collection reference for custom offers
  CollectionReference<Map<String, dynamic>> get _offers =>
      _firestore.collection('custom_offers');

  /// Collection references for conversations (new) and chats (legacy)
  CollectionReference get _conversations => _firestore.collection('conversations');
  CollectionReference get _chats => _firestore.collection('chats');

  /// Get the correct collection reference for a chat/conversation ID
  /// Returns the collection where the document exists (conversations first, then chats)
  Future<({CollectionReference collection, DocumentSnapshot doc})> _getConversationDoc(String chatId) async {
    // Try conversations collection first (newer format)
    final convDoc = await _conversations.doc(chatId).get();
    if (convDoc.exists) {
      return (collection: _conversations, doc: convDoc);
    }

    // Fall back to chats collection (legacy format)
    final chatDoc = await _chats.doc(chatId).get();
    return (collection: _chats, doc: chatDoc);
  }

  // ==================== CREATE OFFER ====================

  /// Create a new custom offer or price proposal
  /// Can be created by supplier (offer) or client (price proposal)
  /// Returns the created offer ID and the message ID
  Future<({String offerId, String messageId})> createOffer({
    required String chatId,
    required String sellerId,
    required String buyerId,
    required String sellerName,
    String? buyerName,
    required int customPrice,
    required String description,
    String? basePackageId,
    String? basePackageName,
    String? deliveryTime,
    DateTime? eventDate,
    String? eventName,
    DateTime? validUntil,
    String? initiatedBy, // 'seller' or 'buyer'
  }) async {
    // Verify the chat/conversation exists (supports both collections)
    final (:collection, :doc) = await _getConversationDoc(chatId);
    if (!doc.exists) {
      throw Exception('Conversa não encontrada');
    }

    final chatData = doc.data() as Map<String, dynamic>?;

    // Determine who initiated the offer
    final actualInitiatedBy = initiatedBy ??
        (chatData?['supplierId'] == sellerId ? 'seller' : 'buyer');

    // Verify the user is part of this conversation
    final isSupplier = chatData?['supplierId'] == sellerId;
    final isClient = chatData?['clientId'] == buyerId;

    if (actualInitiatedBy == 'seller' && !isSupplier) {
      throw Exception('Apenas o fornecedor pode criar ofertas');
    }
    if (actualInitiatedBy == 'buyer' && !isClient) {
      throw Exception('Apenas o cliente pode propor preços');
    }

    final now = DateTime.now();

    // Create the offer document
    final offer = CustomOfferModel(
      id: '',
      chatId: chatId,
      sellerId: sellerId,
      buyerId: buyerId,
      sellerName: sellerName,
      buyerName: buyerName,
      customPrice: customPrice,
      description: description,
      basePackageId: basePackageId,
      basePackageName: basePackageName,
      deliveryTime: deliveryTime,
      eventDate: eventDate,
      eventName: eventName,
      validUntil: validUntil ?? now.add(const Duration(days: 7)), // Default 7 days validity
      status: OfferStatus.pending,
      initiatedBy: actualInitiatedBy,
      createdAt: now,
      updatedAt: now,
    );

    // Save offer to Firestore
    final offerRef = await _offers.add(offer.toFirestore());
    final offerId = offerRef.id;

    // Create a chat message with the offer
    final offerData = OfferMessageData(
      offerId: offerId,
      customPrice: customPrice,
      description: description,
      deliveryTime: deliveryTime,
      validUntil: validUntil ?? now.add(const Duration(days: 7)),
      status: 'pending',
    );

    // Determine sender based on who initiated
    final senderId = actualInitiatedBy == 'buyer' ? buyerId : sellerId;
    final senderName = actualInitiatedBy == 'buyer' ? (buyerName ?? 'Cliente') : sellerName;
    final messageText = actualInitiatedBy == 'buyer'
        ? 'Proposta de preço do cliente: $description'
        : 'Proposta personalizada: $description';

    final message = MessageModel(
      id: '',
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.quote, // Using existing quote type for offers
      text: messageText,
      quoteData: QuoteData(
        packageId: basePackageId ?? 'custom',
        packageName: actualInitiatedBy == 'buyer'
            ? 'Proposta do Cliente'
            : (basePackageName ?? 'Oferta Personalizada'),
        price: customPrice,
        notes: description,
        validUntil: validUntil ?? now.add(const Duration(days: 7)),
        status: 'pending',
      ),
      createdAt: now,
    );

    // Add message to chat/conversation (uses correct collection)
    final messageRef = await collection
        .doc(chatId)
        .collection('messages')
        .add({
          ...message.toFirestore(),
          'offerData': offerData.toMap(),
        });

    final messageId = messageRef.id;

    // Update offer with message reference
    await _offers.doc(offerId).update({
      'messageId': messageId,
    });

    // Update chat's last message - notify the recipient (opposite of sender)
    final recipientId = actualInitiatedBy == 'buyer' ? sellerId : buyerId;
    final lastMessageText = actualInitiatedBy == 'buyer'
        ? 'Proposta do cliente: ${_formatPrice(customPrice)} AOA'
        : 'Proposta: ${_formatPrice(customPrice)} AOA';

    await collection.doc(chatId).update({
      'lastMessage': lastMessageText,
      'lastMessageAt': Timestamp.fromDate(now),
      'lastMessageSenderId': senderId,
      'unreadCount.$recipientId': FieldValue.increment(1),
      'updatedAt': Timestamp.fromDate(now),
    });

    return (offerId: offerId, messageId: messageId);
  }

  // ==================== ACCEPT OFFER ====================

  /// Accept an offer and create a booking
  /// For supplier offers: buyer accepts
  /// For client proposals: supplier (seller) accepts
  Future<String> acceptOffer({
    required String offerId,
    required String buyerId, // The user accepting (can be buyer or seller depending on initiator)
    required String eventName,
    required DateTime eventDate,
    String? eventLocation,
    String? notes,
  }) async {
    // Get the offer
    final offerDoc = await _offers.doc(offerId).get();
    if (!offerDoc.exists) {
      throw Exception('Oferta não encontrada');
    }

    final offer = CustomOfferModel.fromFirestore(offerDoc);

    // Security check: determine who can accept based on who initiated
    // For supplier offers (initiatedBy = seller): buyer accepts
    // For client proposals (initiatedBy = buyer): seller accepts
    final isClientProposal = offer.initiatedBy == 'buyer';
    final canAccept = isClientProposal
        ? offer.sellerId == buyerId // Supplier accepts client proposal
        : offer.buyerId == buyerId; // Buyer accepts supplier offer

    if (!canAccept) {
      throw Exception(isClientProposal
          ? 'Apenas o fornecedor pode aceitar esta proposta'
          : 'Apenas o cliente pode aceitar esta oferta');
    }

    // Check offer status
    if (!offer.canBeAccepted) {
      throw Exception('Esta oferta não pode ser aceite (${offer.statusText})');
    }

    // Check if expired
    if (offer.validUntil != null && DateTime.now().isAfter(offer.validUntil!)) {
      // Mark as expired
      await _offers.doc(offerId).update({
        'status': OfferStatus.expired.name,
        'updatedAt': Timestamp.now(),
      });
      throw Exception('Esta oferta expirou');
    }

    final now = DateTime.now();

    // Create booking via Cloud Function (server-side validation & conflict checks)
    final eventDateStr =
        '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';
    final combinedNotes = [
      offer.description,
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
    ].where((value) => value.trim().isNotEmpty).join('\n\n');

    final callable = _functions.httpsCallable('createBooking');
    final String bookingId;
    try {
      final result = await callable.call<Map<String, dynamic>>({
        'supplierId': offer.sellerId,
        'packageId': offer.basePackageId ?? 'custom_offer_$offerId',
        'eventDate': eventDateStr,
        'startTime': null,
        'notes': combinedNotes.isNotEmpty ? combinedNotes : null,
        'eventName': eventName,
        'eventLocation': eventLocation,
        'guestCount': null,
        'clientRequestId': offerId,
        'totalPrice': offer.customPrice,
        'packageName': offer.basePackageName ?? 'Oferta Personalizada',
        'selectedCustomizations': <String>[],
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Falha ao criar reserva');
      }

      bookingId = data['bookingId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Falha ao criar reserva');
    }

    // Update offer status and link to booking
    await _offers.doc(offerId).update({
      'status': OfferStatus.accepted.name,
      'acceptedAt': Timestamp.fromDate(now),
      'bookingId': bookingId,
      'updatedAt': Timestamp.fromDate(now),
    });

    // Send system message about acceptance
    await _sendSystemMessage(
      chatId: offer.chatId,
      text: 'Oferta aceite! Reserva #${bookingId.substring(0, 8)} criada.',
      senderId: buyerId,
    );

    return bookingId;
  }

  // ==================== REJECT OFFER ====================

  /// Reject an offer
  /// For supplier offers: buyer rejects
  /// For client proposals: supplier (seller) rejects
  Future<void> rejectOffer({
    required String offerId,
    required String buyerId, // The user rejecting (can be buyer or seller depending on initiator)
    String? reason,
  }) async {
    final offerDoc = await _offers.doc(offerId).get();
    if (!offerDoc.exists) {
      throw Exception('Oferta não encontrada');
    }

    final offer = CustomOfferModel.fromFirestore(offerDoc);

    // Security check: determine who can reject based on who initiated
    final isClientProposal = offer.initiatedBy == 'buyer';
    final canReject = isClientProposal
        ? offer.sellerId == buyerId // Supplier rejects client proposal
        : offer.buyerId == buyerId; // Buyer rejects supplier offer

    if (!canReject) {
      throw Exception(isClientProposal
          ? 'Apenas o fornecedor pode rejeitar esta proposta'
          : 'Apenas o cliente pode rejeitar esta oferta');
    }

    if (!offer.canBeRejected) {
      throw Exception('Esta oferta não pode ser rejeitada');
    }

    final now = DateTime.now();

    await _offers.doc(offerId).update({
      'status': OfferStatus.rejected.name,
      'rejectedAt': Timestamp.fromDate(now),
      'rejectionReason': reason,
      'updatedAt': Timestamp.fromDate(now),
    });

    // Send system message with appropriate text based on who rejected
    final rejectMessage = isClientProposal
        ? (reason != null
            ? 'Proposta rejeitada pelo fornecedor: $reason'
            : 'Proposta rejeitada pelo fornecedor.')
        : (reason != null
            ? 'Oferta rejeitada: $reason'
            : 'Oferta rejeitada pelo cliente.');

    await _sendSystemMessage(
      chatId: offer.chatId,
      text: rejectMessage,
      senderId: buyerId,
    );
  }

  // ==================== CANCEL OFFER ====================

  /// Cancel an offer
  /// For supplier offers: seller cancels
  /// For client proposals: buyer cancels
  Future<void> cancelOffer({
    required String offerId,
    required String sellerId, // The user cancelling (can be buyer or seller depending on initiator)
  }) async {
    final offerDoc = await _offers.doc(offerId).get();
    if (!offerDoc.exists) {
      throw Exception('Oferta não encontrada');
    }

    final offer = CustomOfferModel.fromFirestore(offerDoc);

    // Security check: determine who can cancel based on who initiated
    final isClientProposal = offer.initiatedBy == 'buyer';
    final canCancel = isClientProposal
        ? offer.buyerId == sellerId // Client cancels their own proposal
        : offer.sellerId == sellerId; // Supplier cancels their own offer

    if (!canCancel) {
      throw Exception(isClientProposal
          ? 'Apenas o cliente pode cancelar esta proposta'
          : 'Apenas o fornecedor pode cancelar esta oferta');
    }

    if (!offer.canBeCancelled) {
      throw Exception('Esta oferta não pode ser cancelada');
    }

    final now = DateTime.now();

    await _offers.doc(offerId).update({
      'status': OfferStatus.cancelled.name,
      'updatedAt': Timestamp.fromDate(now),
    });

    // Send system message with appropriate text
    final cancelMessage = isClientProposal
        ? 'Proposta cancelada pelo cliente.'
        : 'Oferta cancelada pelo fornecedor.';

    await _sendSystemMessage(
      chatId: offer.chatId,
      text: cancelMessage,
      senderId: sellerId,
    );
  }

  // ==================== QUERIES ====================

  /// Get offer by ID
  Future<CustomOfferModel?> getOffer(String offerId) async {
    final doc = await _offers.doc(offerId).get();
    if (!doc.exists) return null;
    return CustomOfferModel.fromFirestore(doc);
  }

  /// Get offers for a chat
  Future<List<CustomOfferModel>> getChatOffers(String chatId) async {
    final snapshot = await _offers
        .where('chatId', isEqualTo: chatId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CustomOfferModel.fromFirestore(doc))
        .toList();
  }

  /// Get pending offers for a buyer
  Future<List<CustomOfferModel>> getPendingOffersForBuyer(String buyerId) async {
    final snapshot = await _offers
        .where('buyerId', isEqualTo: buyerId)
        .where('status', isEqualTo: OfferStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CustomOfferModel.fromFirestore(doc))
        .toList();
  }

  /// Get offers created by seller
  Future<List<CustomOfferModel>> getSellerOffers(
    String sellerId, {
    OfferStatus? status,
  }) async {
    Query<Map<String, dynamic>> query = _offers
        .where('sellerId', isEqualTo: sellerId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CustomOfferModel.fromFirestore(doc))
        .toList();
  }

  /// Stream offers for a chat (real-time updates)
  Stream<List<CustomOfferModel>> streamChatOffers(String chatId) {
    return _offers
        .where('chatId', isEqualTo: chatId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomOfferModel.fromFirestore(doc))
            .toList());
  }

  // ==================== HELPER METHODS ====================

  Future<void> _sendSystemMessage({
    required String chatId,
    required String text,
    required String senderId,
  }) async {
    // Get correct collection (conversations or chats)
    final (:collection, :doc) = await _getConversationDoc(chatId);
    if (!doc.exists) return; // Chat not found, skip

    final now = DateTime.now();
    await collection
        .doc(chatId)
        .collection('messages')
        .add({
      'chatId': chatId,
      'senderId': senderId,
      'type': MessageType.system.name,
      'text': text,
      'isRead': false,
      'createdAt': Timestamp.fromDate(now),
      'isDeleted': false,
    });

    await collection.doc(chatId).update({
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // ==================== EXPIRATION CHECK ====================

  /// Check and mark expired offers (can be called periodically)
  Future<void> markExpiredOffers() async {
    final now = DateTime.now();
    final snapshot = await _offers
        .where('status', isEqualTo: OfferStatus.pending.name)
        .where('validUntil', isLessThan: Timestamp.fromDate(now))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': OfferStatus.expired.name,
        'updatedAt': Timestamp.fromDate(now),
      });
    }
    await batch.commit();
  }
}
