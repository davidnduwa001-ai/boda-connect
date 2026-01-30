import 'package:cloud_firestore/cloud_firestore.dart';

class PackageModel {

  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse includes list
    final includesRaw = data['includes'];
    final includes = <String>[];
    if (includesRaw is List) {
      for (final item in includesRaw) {
        if (item is String) {
          includes.add(item);
        }
      }
    }

    // Parse photos list
    final photosRaw = data['photos'];
    final photos = <String>[];
    if (photosRaw is List) {
      for (final item in photosRaw) {
        if (item is String) {
          photos.add(item);
        }
      }
    }

    // Parse customizations list
    final customRaw = data['customizations'];
    final customizations = <PackageCustomization>[];
    if (customRaw is List) {
      for (final item in customRaw) {
        if (item is Map<String, dynamic>) {
          customizations.add(PackageCustomization.fromMap(item));
        }
      }
    }

    return PackageModel(
      id: doc.id,
      supplierId: data['supplierId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
      duration: data['duration'] as String? ?? '',
      includes: includes,
      customizations: customizations,
      photos: photos,
      isActive: data['isActive'] as bool? ?? true,
      isFeatured: data['isFeatured'] as bool? ?? false,
      bookingCount: (data['bookingCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }
  final String id;
  final String supplierId;
  final String name;
  final String description;
  final int price;
  final String currency;
  final String duration;
  final List<String> includes;
  final List<PackageCustomization> customizations;
  final List<String> photos;
  final bool isActive;
  final bool isFeatured;
  final int bookingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PackageModel({
    required this.id,
    required this.supplierId,
    required this.name,
    required this.description,
    required this.price,
    this.currency = 'AOA',
    required this.duration,
    this.includes = const [],
    this.customizations = const [],
    this.photos = const [],
    this.isActive = true,
    this.isFeatured = false,
    this.bookingCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'duration': duration,
      'includes': includes,
      'customizations': customizations.map((c) => c.toMap()).toList(),
      'photos': photos,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'bookingCount': bookingCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PackageModel copyWith({
    String? id,
    String? supplierId,
    String? name,
    String? description,
    int? price,
    String? currency,
    String? duration,
    List<String>? includes,
    List<PackageCustomization>? customizations,
    List<String>? photos,
    bool? isActive,
    bool? isFeatured,
    int? bookingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PackageModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      duration: duration ?? this.duration,
      includes: includes ?? this.includes,
      customizations: customizations ?? this.customizations,
      photos: photos ?? this.photos,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      bookingCount: bookingCount ?? this.bookingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M $currency';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K $currency';
    }
    return '$price $currency';
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class PackageCustomization {

  const PackageCustomization({
    required this.name,
    required this.price,
    this.description,
  });

  factory PackageCustomization.fromMap(Map<String, dynamic> map) {
    return PackageCustomization(
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      description: map['description'] as String?,
    );
  }
  final String name;
  final int price;
  final String? description;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'description': description,
    };
  }
}
