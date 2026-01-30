import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a custom offer
enum OfferStatus {
  pending,
  accepted,
  rejected,
  expired,
  cancelled,
}

/// Represents a negotiated custom offer sent by a supplier to a client in chat
class CustomOfferModel {
  final String id;
  final String chatId;
  final String sellerId;
  final String buyerId;
  final String sellerName;
  final String? buyerName;

  /// Custom negotiated price (in smallest currency unit, e.g., cents)
  final int customPrice;
  final String currency;

  /// Description of what's included in this custom offer
  final String description;

  /// Optional reference to a base package being customized
  final String? basePackageId;
  final String? basePackageName;

  /// Delivery/service timeframe
  final String? deliveryTime;

  /// Event details (if applicable)
  final DateTime? eventDate;
  final String? eventName;

  /// Offer validity
  final DateTime? validUntil;

  /// Status tracking
  final OfferStatus status;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;

  /// Reference to created booking (when accepted)
  final String? bookingId;

  /// Message ID where this offer was sent (for UI linking)
  final String? messageId;

  /// Who initiated this offer/proposal ('seller' or 'buyer')
  /// Seller = supplier created offer, Buyer = client proposed price
  final String? initiatedBy;

  /// Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomOfferModel({
    required this.id,
    required this.chatId,
    required this.sellerId,
    required this.buyerId,
    required this.sellerName,
    this.buyerName,
    required this.customPrice,
    this.currency = 'AOA',
    required this.description,
    this.basePackageId,
    this.basePackageName,
    this.deliveryTime,
    this.eventDate,
    this.eventName,
    this.validUntil,
    this.status = OfferStatus.pending,
    this.acceptedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.bookingId,
    this.messageId,
    this.initiatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomOfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final statusStr = data['status'] as String?;
    final status = OfferStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => OfferStatus.pending,
    );

    return CustomOfferModel(
      id: doc.id,
      chatId: data['chatId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      buyerName: data['buyerName'] as String?,
      customPrice: (data['customPrice'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
      description: data['description'] as String? ?? '',
      basePackageId: data['basePackageId'] as String?,
      basePackageName: data['basePackageName'] as String?,
      deliveryTime: data['deliveryTime'] as String?,
      eventDate: _parseTimestamp(data['eventDate']),
      eventName: data['eventName'] as String?,
      validUntil: _parseTimestamp(data['validUntil']),
      status: status,
      acceptedAt: _parseTimestamp(data['acceptedAt']),
      rejectedAt: _parseTimestamp(data['rejectedAt']),
      rejectionReason: data['rejectionReason'] as String?,
      bookingId: data['bookingId'] as String?,
      messageId: data['messageId'] as String?,
      initiatedBy: data['initiatedBy'] as String?,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'sellerName': sellerName,
      'buyerName': buyerName,
      'customPrice': customPrice,
      'currency': currency,
      'description': description,
      'basePackageId': basePackageId,
      'basePackageName': basePackageName,
      'deliveryTime': deliveryTime,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'eventName': eventName,
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'status': status.name,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectionReason': rejectionReason,
      'bookingId': bookingId,
      'messageId': messageId,
      'initiatedBy': initiatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CustomOfferModel copyWith({
    String? id,
    String? chatId,
    String? sellerId,
    String? buyerId,
    String? sellerName,
    String? buyerName,
    int? customPrice,
    String? currency,
    String? description,
    String? basePackageId,
    String? basePackageName,
    String? deliveryTime,
    DateTime? eventDate,
    String? eventName,
    DateTime? validUntil,
    OfferStatus? status,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    String? rejectionReason,
    String? bookingId,
    String? messageId,
    String? initiatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomOfferModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      sellerId: sellerId ?? this.sellerId,
      buyerId: buyerId ?? this.buyerId,
      sellerName: sellerName ?? this.sellerName,
      buyerName: buyerName ?? this.buyerName,
      customPrice: customPrice ?? this.customPrice,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      basePackageId: basePackageId ?? this.basePackageId,
      basePackageName: basePackageName ?? this.basePackageName,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      eventDate: eventDate ?? this.eventDate,
      eventName: eventName ?? this.eventName,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      bookingId: bookingId ?? this.bookingId,
      messageId: messageId ?? this.messageId,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this offer was initiated by the buyer (client proposal)
  bool get isClientProposal => initiatedBy == 'buyer';

  /// Check if this offer was initiated by the seller (supplier offer)
  bool get isSupplierOffer => initiatedBy == 'seller' || initiatedBy == null;

  /// Check if offer is still valid (not expired)
  bool get isValid {
    if (status != OfferStatus.pending) return false;
    if (validUntil == null) return true;
    return DateTime.now().isBefore(validUntil!);
  }

  /// Check if offer can be accepted
  bool get canBeAccepted => status == OfferStatus.pending && isValid;

  /// Check if offer can be rejected
  bool get canBeRejected => status == OfferStatus.pending;

  /// Check if offer can be cancelled (by seller)
  bool get canBeCancelled => status == OfferStatus.pending;

  /// Get formatted price string
  String get formattedPrice {
    final priceStr = customPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$priceStr $currency';
  }

  /// Get status display text in Portuguese
  String get statusText {
    switch (status) {
      case OfferStatus.pending:
        return 'Pendente';
      case OfferStatus.accepted:
        return 'Aceite';
      case OfferStatus.rejected:
        return 'Rejeitada';
      case OfferStatus.expired:
        return 'Expirada';
      case OfferStatus.cancelled:
        return 'Cancelada';
    }
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Embedded offer data for chat messages (lightweight version)
class OfferMessageData {
  final String offerId;
  final int customPrice;
  final String currency;
  final String description;
  final String? deliveryTime;
  final DateTime? validUntil;
  final String status;

  const OfferMessageData({
    required this.offerId,
    required this.customPrice,
    this.currency = 'AOA',
    required this.description,
    this.deliveryTime,
    this.validUntil,
    this.status = 'pending',
  });

  factory OfferMessageData.fromMap(Map<String, dynamic> map) {
    return OfferMessageData(
      offerId: map['offerId'] as String? ?? '',
      customPrice: (map['customPrice'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'AOA',
      description: map['description'] as String? ?? '',
      deliveryTime: map['deliveryTime'] as String?,
      validUntil: _parseTimestamp(map['validUntil']),
      status: map['status'] as String? ?? 'pending',
    );
  }

  factory OfferMessageData.fromOffer(CustomOfferModel offer) {
    return OfferMessageData(
      offerId: offer.id,
      customPrice: offer.customPrice,
      currency: offer.currency,
      description: offer.description,
      deliveryTime: offer.deliveryTime,
      validUntil: offer.validUntil,
      status: offer.status.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'offerId': offerId,
      'customPrice': customPrice,
      'currency': currency,
      'description': description,
      'deliveryTime': deliveryTime,
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'status': status,
    };
  }

  String get formattedPrice {
    final priceStr = customPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$priceStr $currency';
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
