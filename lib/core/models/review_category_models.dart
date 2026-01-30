import 'package:cloud_firestore/cloud_firestore.dart';

// ==================== REVIEW MODEL ====================

class ReviewModel {

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.supplierId,
    this.clientName,
    this.clientPhoto,
    required this.rating,
    this.comment,
    this.photos = const [],
    this.supplierReply,
    this.supplierReplyAt,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String bookingId;
  final String clientId;
  final String supplierId;
  final String? clientName;
  final String? clientPhoto;
  final double rating;
  final String? comment;
  final List<String> photos;
  final String? supplierReply;
  final DateTime? supplierReplyAt;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final photos = _parseStringList(data['photos']);

    return ReviewModel(
      id: doc.id,
      bookingId: data['bookingId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      clientName: data['clientName'] as String?,
      clientPhoto: data['clientPhoto'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] as String?,
      photos: photos,
      supplierReply: data['supplierReply'] as String?,
      supplierReplyAt: _parseTimestamp(data['supplierReplyAt']),
      isVerified: data['isVerified'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'clientId': clientId,
      'supplierId': supplierId,
      'clientName': clientName,
      'clientPhoto': clientPhoto,
      'rating': rating,
      'comment': comment,
      'photos': photos,
      'supplierReply': supplierReply,
      'supplierReplyAt': supplierReplyAt != null
          ? Timestamp.fromDate(supplierReplyAt!)
          : null,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ReviewModel copyWith({
    String? id,
    String? bookingId,
    String? clientId,
    String? supplierId,
    String? clientName,
    String? clientPhoto,
    double? rating,
    String? comment,
    List<String>? photos,
    String? supplierReply,
    DateTime? supplierReplyAt,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      clientId: clientId ?? this.clientId,
      supplierId: supplierId ?? this.supplierId,
      clientName: clientName ?? this.clientName,
      clientPhoto: clientPhoto ?? this.clientPhoto,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      photos: photos ?? this.photos,
      supplierReply: supplierReply ?? this.supplierReply,
      supplierReplyAt: supplierReplyAt ?? this.supplierReplyAt,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    final result = <String>[];
    if (value is List) {
      for (final item in value) {
        if (item is String) result.add(item);
      }
    }
    return result;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

// ==================== CATEGORY MODEL ====================

class CategoryModel {

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse subcategories
    final subcatRaw = data['subcategories'];
    final subcategories = <SubcategoryModel>[];
    if (subcatRaw is List) {
      for (final item in subcatRaw) {
        if (item is Map<String, dynamic>) {
          subcategories.add(SubcategoryModel.fromMap(item));
        }
      }
    }

    return CategoryModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      namePt: data['namePt'] as String? ?? data['name'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? '',
      icon: data['icon'] as String? ?? '📦',
      color: data['color'] as String? ?? '#FFAB91',
      image: data['image'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      subcategories: subcategories,
      supplierCount: (data['supplierCount'] as num?)?.toInt() ?? 0,
    );
  }
  final String id;
  final String name;
  final String namePt;
  final String nameEn;
  final String icon;
  final String color;
  final String? image;
  final int order;
  final bool isActive;
  final List<SubcategoryModel> subcategories;
  final int supplierCount;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.namePt,
    this.nameEn = '',
    required this.icon,
    required this.color,
    this.image,
    this.order = 0,
    this.isActive = true,
    this.subcategories = const [],
    this.supplierCount = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'namePt': namePt,
      'nameEn': nameEn,
      'icon': icon,
      'color': color,
      'image': image,
      'order': order,
      'isActive': isActive,
      'subcategories': subcategories.map((s) => s.toMap()).toList(),
      'supplierCount': supplierCount,
    };
  }

  static List<CategoryModel> get defaultCategories => [
        const CategoryModel(
          id: 'photography',
          name: 'Fotografia',
          namePt: 'Fotografia',
          nameEn: 'Photography',
          icon: '📸',
          color: '#F3E5F5',
          order: 1,
        ),
        const CategoryModel(
          id: 'catering',
          name: 'Catering',
          namePt: 'Catering',
          nameEn: 'Catering',
          icon: '🍽️',
          color: '#FFF3E0',
          order: 2,
        ),
        const CategoryModel(
          id: 'music',
          name: 'Música & DJ',
          namePt: 'Música & DJ',
          nameEn: 'Music & DJ',
          icon: '🎵',
          color: '#FCE4EC',
          order: 3,
        ),
        const CategoryModel(
          id: 'decoration',
          name: 'Decoração',
          namePt: 'Decoração',
          nameEn: 'Decoration',
          icon: '🎨',
          color: '#E8F5E9',
          order: 4,
        ),
        const CategoryModel(
          id: 'venue',
          name: 'Local',
          namePt: 'Local',
          nameEn: 'Venue',
          icon: '🏛️',
          color: '#E3F2FD',
          order: 5,
        ),
        const CategoryModel(
          id: 'clothing',
          name: 'Vestuário',
          namePt: 'Vestuário',
          nameEn: 'Clothing',
          icon: '👔',
          color: '#F5F5F5',
          order: 6,
        ),
        const CategoryModel(
          id: 'beauty',
          name: 'Beleza',
          namePt: 'Beleza',
          nameEn: 'Beauty',
          icon: '💄',
          color: '#FCE4EC',
          order: 7,
        ),
        const CategoryModel(
          id: 'transport',
          name: 'Transporte',
          namePt: 'Transporte',
          nameEn: 'Transport',
          icon: '🚗',
          color: '#E0F7FA',
          order: 8,
        ),
        const CategoryModel(
          id: 'flowers',
          name: 'Flores',
          namePt: 'Flores',
          nameEn: 'Flowers',
          icon: '💐',
          color: '#F8BBD9',
          order: 9,
        ),
        const CategoryModel(
          id: 'cake',
          name: 'Bolos & Doces',
          namePt: 'Bolos & Doces',
          nameEn: 'Cakes & Sweets',
          icon: '🎂',
          color: '#FFECB3',
          order: 10,
        ),
        const CategoryModel(
          id: 'entertainment',
          name: 'Entretenimento',
          namePt: 'Entretenimento',
          nameEn: 'Entertainment',
          icon: '🎭',
          color: '#D1C4E9',
          order: 11,
        ),
        const CategoryModel(
          id: 'video',
          name: 'Vídeo',
          namePt: 'Vídeo',
          nameEn: 'Video',
          icon: '🎬',
          color: '#B2DFDB',
          order: 12,
        ),
      ];
}

class SubcategoryModel {

  const SubcategoryModel({
    required this.id,
    required this.name,
    this.namePt,
    this.nameEn,
  });

  factory SubcategoryModel.fromMap(Map<String, dynamic> map) {
    return SubcategoryModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      namePt: map['namePt'] as String?,
      nameEn: map['nameEn'] as String?,
    );
  }
  final String id;
  final String name;
  final String? namePt;
  final String? nameEn;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'namePt': namePt,
      'nameEn': nameEn,
    };
  }
}

// ==================== FAVORITE MODEL ====================

class FavoriteModel {

  const FavoriteModel({
    required this.id,
    required this.clientId,
    required this.supplierId,
    required this.createdAt,
  });
  final String id;
  final String clientId;
  final String supplierId;
  final DateTime createdAt;

  factory FavoriteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FavoriteModel(
      id: doc.id,
      clientId: data['clientId'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'supplierId': supplierId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static String generateId(String clientId, String supplierId) {
    return '${clientId}_$supplierId';
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

// ==================== NOTIFICATION MODEL ====================

class NotificationModel {

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final docData = doc.data() as Map<String, dynamic>? ?? {};

    // Parse data map safely
    final rawData = docData['data'];
    Map<String, dynamic>? parsedData;
    if (rawData is Map<String, dynamic>) {
      parsedData = rawData;
    }

    return NotificationModel(
      id: doc.id,
      userId: docData['userId'] as String? ?? '',
      title: docData['title'] as String? ?? '',
      body: docData['body'] as String? ?? '',
      type: docData['type'] as String? ?? '',
      data: parsedData,
      isRead: docData['isRead'] as bool? ?? false,
      createdAt: _parseTimestamp(docData['createdAt']) ?? DateTime.now(),
    );
  }
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

// ==================== NOTIFICATION TYPES ====================

class NotificationTypes {
  static const String newBooking = 'new_booking';
  static const String bookingConfirmed = 'booking_confirmed';
  static const String bookingCancelled = 'booking_cancelled';
  static const String newMessage = 'new_message';
  static const String newReview = 'new_review';
  static const String paymentReceived = 'payment_received';
  static const String reminderEvent = 'reminder_event';
  static const String promotional = 'promotional';
  static const String system = 'system';
}