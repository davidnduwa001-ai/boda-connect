import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewStatus {
  pending,      // Under review
  approved,     // Published
  rejected,     // Violated guidelines
  disputed,     // Being investigated
  resolved,     // Dispute resolved
}

class ReviewModel {
  final String id;
  final String bookingId;          // Which booking this is for

  // Who is reviewing whom
  final String reviewerId;          // Person leaving review
  final String reviewerType;        // 'client' or 'supplier'
  final String reviewedId;          // Person being reviewed
  final String reviewedType;        // 'client' or 'supplier'

  // Review content
  final double rating;              // 1-5 stars
  final String? comment;
  final List<String> tags;          // e.g., ['professional', 'on-time', 'quality-work']
  final List<String>? photos;       // Photo evidence

  // Context
  final String serviceCategory;     // What service was provided
  final DateTime serviceDate;       // When service occurred

  // Status
  final bool isPublic;              // Visible to others
  final bool isFlagged;             // Flagged for review
  final String? flagReason;
  final ReviewStatus status;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;      // When reviewed user responded
  final String? response;           // Supplier/client response to review

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.reviewerType,
    required this.reviewedId,
    required this.reviewedType,
    required this.rating,
    this.comment,
    this.tags = const [],
    this.photos,
    required this.serviceCategory,
    required this.serviceDate,
    this.isPublic = true,
    this.isFlagged = false,
    this.flagReason,
    this.status = ReviewStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.respondedAt,
    this.response,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse status
    final statusStr = data['status'] as String?;
    final status = ReviewStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ReviewStatus.pending,
    );

    // Parse tags
    final tagsRaw = data['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    // Parse photos
    final photosRaw = data['photos'];
    final photos = photosRaw is List
        ? photosRaw.map((e) => e.toString()).toList()
        : null;

    return ReviewModel(
      id: doc.id,
      bookingId: data['bookingId'] as String? ?? '',
      reviewerId: data['reviewerId'] as String? ?? '',
      reviewerType: data['reviewerType'] as String? ?? '',
      reviewedId: data['reviewedId'] as String? ?? '',
      reviewedType: data['reviewedType'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] as String?,
      tags: tags,
      photos: photos,
      serviceCategory: data['serviceCategory'] as String? ?? '',
      serviceDate: _parseTimestamp(data['serviceDate']) ?? DateTime.now(),
      isPublic: data['isPublic'] as bool? ?? true,
      isFlagged: data['isFlagged'] as bool? ?? false,
      flagReason: data['flagReason'] as String?,
      status: status,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']),
      respondedAt: _parseTimestamp(data['respondedAt']),
      response: data['response'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'reviewerId': reviewerId,
      'reviewerType': reviewerType,
      'reviewedId': reviewedId,
      'reviewedType': reviewedType,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'photos': photos,
      'serviceCategory': serviceCategory,
      'serviceDate': Timestamp.fromDate(serviceDate),
      'isPublic': isPublic,
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'response': response,
    };
  }

  ReviewModel copyWith({
    String? id,
    String? bookingId,
    String? reviewerId,
    String? reviewerType,
    String? reviewedId,
    String? reviewedType,
    double? rating,
    String? comment,
    List<String>? tags,
    List<String>? photos,
    String? serviceCategory,
    DateTime? serviceDate,
    bool? isPublic,
    bool? isFlagged,
    String? flagReason,
    ReviewStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? respondedAt,
    String? response,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerType: reviewerType ?? this.reviewerType,
      reviewedId: reviewedId ?? this.reviewedId,
      reviewedType: reviewedType ?? this.reviewedType,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      photos: photos ?? this.photos,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      serviceDate: serviceDate ?? this.serviceDate,
      isPublic: isPublic ?? this.isPublic,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      response: response ?? this.response,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

// Review tags for suppliers
class SupplierReviewTags {
  static const String professional = 'Profissional';
  static const String punctual = 'Pontual';
  static const String excellentQuality = 'Qualidade excelente';
  static const String goodCommunication = 'Boa comunicação';
  static const String goodValue = 'Bom valor';
  static const String creative = 'Criativo';
  static const String flexible = 'Flexível';
  static const String friendly = 'Amigável';
  static const String organized = 'Organizado';
  static const String exceeded = 'Superou expectativas';

  static const List<String> all = [
    professional,
    punctual,
    excellentQuality,
    goodCommunication,
    goodValue,
    creative,
    flexible,
    friendly,
    organized,
    exceeded,
  ];
}

// Review tags for clients
class ClientReviewTags {
  static const String respectful = 'Respeitoso';
  static const String communicative = 'Comunicativo';
  static const String punctualPayment = 'Pagamento pontual';
  static const String accurateDetails = 'Detalhes precisos';
  static const String wouldRecommend = 'Recomendaria';
  static const String organized = 'Organizado';
  static const String friendly = 'Amigável';
  static const String clear = 'Instruções claras';

  static const List<String> all = [
    respectful,
    communicative,
    punctualPayment,
    accurateDetails,
    wouldRecommend,
    organized,
    friendly,
    clear,
  ];
}
