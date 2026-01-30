import 'package:cloud_firestore/cloud_firestore.dart';

/// Account status for supplier onboarding workflow (Uber-style)
enum SupplierAccountStatus {
  /// Registration submitted, awaiting admin review
  pendingReview,

  /// All documents approved, full platform access granted
  active,

  /// Documents need correction (soft rejection)
  needsClarification,

  /// Application denied (hard rejection)
  rejected,

  /// Account suspended due to policy violation
  suspended,
}

/// Entity type for supplier (Individual or Company)
enum SupplierEntityType {
  /// Individual supplier (pessoa física)
  individual,

  /// Company/business (pessoa jurídica)
  empresa,
}

/// Document type for ID verification
enum IdentityDocumentType {
  /// Bilhete de Identidade (Angola)
  bilheteIdentidade,

  /// Passport
  passaporte,
}

/// Identity verification status (SEPARATE from onboarding approval)
///
/// This tracks whether the supplier's identity documents have been verified.
/// Booking eligibility requires BOTH:
/// - accountStatus === active (onboarding approved)
/// - identityVerificationStatus === verified (identity verified)
enum IdentityVerificationStatus {
  /// Documents not yet submitted or under review
  pending,

  /// Identity verified by admin
  verified,

  /// Identity verification rejected
  rejected,
}

/// Supplier tier levels (like Uber Blue/Pro/Diamond)
enum SupplierTier {
  /// New suppliers, basic features
  starter,

  /// Established suppliers with good metrics
  pro,

  /// Top-tier suppliers with excellent performance
  elite,

  /// Premium tier with exclusive benefits
  diamond,
}

class SupplierModel {
  final String id;
  final String userId;
  final String businessName;
  final String category;
  final List<String> subcategories;
  final String description;
  final List<String> photos;
  final List<String> portfolioPhotos;
  final List<String> videos;
  final LocationData? location;
  final double rating;
  final int reviewCount;
  final int completedBookings;
  final bool isVerified;
  final bool isActive;
  final bool isFeatured;
  final double responseRate;
  final String? responseTime;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final Map<String, String>? socialLinks;
  final List<String> languages;
  final WorkingHours? workingHours;
  final int viewCount;
  final int leadCount; // High-value interactions (contact clicks, messages, etc.)
  final int favoriteCount;
  final int confirmedBookings; // Bookings with status confirmed/paid
  final List<String> searchKeywords;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Pricing fields
  final int? minPrice;
  final int? maxPrice;
  final bool priceOnRequest;

  // Tier system
  final SupplierTier tier;

  // Business info fields
  final int? yearsExperience;
  final int? teamSize;
  final List<String> specialties;
  final bool instantBooking;
  final bool customPackages;

  // Privacy settings for public profile
  final PrivacySettings privacySettings;

  // Onboarding & Verification fields
  final SupplierAccountStatus accountStatus;
  final SupplierEntityType entityType;
  final String? nif; // Número de Identificação Fiscal
  final IdentityDocumentType? idDocumentType;
  final String? idDocumentNumber;
  final String? idDocumentUrl; // Uploaded ID document
  final String? rejectionReason; // Admin note for rejection/clarification
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin ID who reviewed

  // Identity Verification fields (SEPARATE from onboarding approval)
  // Booking eligibility requires BOTH onboarding approval AND identity verification
  final IdentityVerificationStatus identityVerificationStatus;
  final DateTime? identityVerifiedAt;
  final String? identityVerifiedBy; // Admin ID who verified identity
  final String? identityVerificationRejectionReason;
  final List<String> verificationDocuments; // URLs to verification documents

  // Booking availability (supplier can pause/resume accepting bookings)
  final bool acceptingBookings;

  const SupplierModel({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.category,
    this.subcategories = const [],
    required this.description,
    this.photos = const [],
    this.portfolioPhotos = const [],
    this.videos = const [],
    this.location,
    this.rating = 0.0, // Start at 0 until reviews are received
    this.reviewCount = 0,
    this.completedBookings = 0,
    this.isVerified = false,
    this.isActive = false, // Start inactive until approved
    this.isFeatured = false,
    this.responseRate = 0.0,
    this.responseTime,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.socialLinks,
    this.languages = const ['pt'],
    this.workingHours,
    this.viewCount = 0,
    this.leadCount = 0,
    this.favoriteCount = 0,
    this.confirmedBookings = 0,
    this.searchKeywords = const [],
    required this.createdAt,
    required this.updatedAt,
    this.minPrice,
    this.maxPrice,
    this.priceOnRequest = false,
    this.tier = SupplierTier.starter,
    this.yearsExperience,
    this.teamSize,
    this.specialties = const [],
    this.instantBooking = false,
    this.customPackages = true,
    this.privacySettings = const PrivacySettings(),
    this.accountStatus = SupplierAccountStatus.pendingReview,
    this.entityType = SupplierEntityType.individual,
    this.nif,
    this.idDocumentType,
    this.idDocumentNumber,
    this.idDocumentUrl,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    this.identityVerificationStatus = IdentityVerificationStatus.pending,
    this.identityVerifiedAt,
    this.identityVerifiedBy,
    this.identityVerificationRejectionReason,
    this.verificationDocuments = const [],
    this.acceptingBookings = true,
  });

  /// Generates search keywords from supplier data for searchable fields
  static List<String> generateSearchKeywords({
    required String businessName,
    required String category,
    required List<String> subcategories,
    String? city,
    String? description,
  }) {
    final keywords = <String>{};

    // Add full business name and each word (lowercase)
    keywords.add(businessName.toLowerCase());
    for (final word in businessName.toLowerCase().split(RegExp(r'\s+'))) {
      if (word.length >= 2) {
        keywords.add(word);
        // Add prefixes for partial matching
        for (int i = 2; i <= word.length; i++) {
          keywords.add(word.substring(0, i));
        }
      }
    }

    // Add category and its words
    keywords.add(category.toLowerCase());
    for (final word in category.toLowerCase().split(RegExp(r'\s+'))) {
      if (word.length >= 2) {
        keywords.add(word);
      }
    }

    // Add subcategories
    for (final sub in subcategories) {
      keywords.add(sub.toLowerCase());
      for (final word in sub.toLowerCase().split(RegExp(r'\s+'))) {
        if (word.length >= 2) {
          keywords.add(word);
        }
      }
    }

    // Add city
    if (city != null && city.isNotEmpty) {
      keywords.add(city.toLowerCase());
    }

    // Remove empty strings and common words
    keywords.removeWhere((k) => k.isEmpty || k.length < 2);

    return keywords.toList();
  }

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse string lists safely
    final subcategories = _parseStringList(data['subcategories']);
    final photos = _parseStringList(data['photos']);
    final portfolioPhotos = _parseStringList(data['portfolioPhotos']);
    final videos = _parseStringList(data['videos']);
    final languages = _parseStringList(data['languages']);
    if (languages.isEmpty) languages.add('pt');

    // Parse privacy settings
    final privacyRaw = data['privacySettings'];
    final privacySettings = privacyRaw is Map<String, dynamic>
        ? PrivacySettings.fromMap(privacyRaw)
        : const PrivacySettings();

    // Parse location
    final locationRaw = data['location'];
    final location = locationRaw is Map<String, dynamic>
        ? LocationData.fromMap(locationRaw)
        : null;

    // Parse social links
    final socialRaw = data['socialLinks'];
    Map<String, String>? socialLinks;
    if (socialRaw is Map) {
      socialLinks = <String, String>{};
      socialRaw.forEach((key, value) {
        if (key is String && value is String) {
          socialLinks![key] = value;
        }
      });
    }

    // Parse working hours
    final hoursRaw = data['workingHours'];
    final workingHours = hoursRaw is Map<String, dynamic>
        ? WorkingHours.fromMap(hoursRaw)
        : null;

    return SupplierModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      category: data['category'] as String? ?? '',
      subcategories: subcategories,
      description: data['description'] as String? ?? '',
      photos: photos,
      portfolioPhotos: portfolioPhotos,
      videos: videos,
      location: location,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      completedBookings: (data['completedBookings'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      isFeatured: data['isFeatured'] as bool? ?? false,
      responseRate: (data['responseRate'] as num?)?.toDouble() ?? 0.0,
      responseTime: data['responseTime'] as String?,
      phone: data['phone']?.toString(),
      whatsapp: data['whatsapp']?.toString(),
      email: data['email']?.toString(),
      website: data['website'] as String?,
      socialLinks: socialLinks,
      languages: languages,
      workingHours: workingHours,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      leadCount: (data['leadCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
      confirmedBookings: (data['confirmedBookings'] as num?)?.toInt() ?? 0,
      searchKeywords: _parseStringList(data['searchKeywords']),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      minPrice: (data['minPrice'] as num?)?.toInt(),
      maxPrice: (data['maxPrice'] as num?)?.toInt(),
      priceOnRequest: data['priceOnRequest'] as bool? ?? false,
      tier: SupplierTier.values.firstWhere(
        (e) => e.name == (data['tier'] as String?),
        orElse: () => SupplierTier.starter,
      ),
      yearsExperience: (data['yearsExperience'] as num?)?.toInt(),
      teamSize: (data['teamSize'] as num?)?.toInt(),
      specialties: _parseStringList(data['specialties']),
      instantBooking: data['instantBooking'] as bool? ?? false,
      customPackages: data['customPackages'] as bool? ?? true,
      privacySettings: privacySettings,
      accountStatus: SupplierAccountStatus.values.firstWhere(
        (e) => e.name == (data['accountStatus'] as String?),
        orElse: () => SupplierAccountStatus.pendingReview,
      ),
      entityType: SupplierEntityType.values.firstWhere(
        (e) => e.name == (data['entityType'] as String?),
        orElse: () => SupplierEntityType.individual,
      ),
      nif: data['nif'] as String?,
      idDocumentType: data['idDocumentType'] != null
          ? IdentityDocumentType.values.firstWhere(
              (e) => e.name == (data['idDocumentType'] as String),
              orElse: () => IdentityDocumentType.bilheteIdentidade,
            )
          : null,
      idDocumentNumber: data['idDocumentNumber'] as String?,
      idDocumentUrl: data['idDocumentUrl'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      reviewedAt: _parseTimestamp(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      identityVerificationStatus: IdentityVerificationStatus.values.firstWhere(
        (e) => e.name == (data['identityVerificationStatus'] as String?),
        orElse: () => IdentityVerificationStatus.pending,
      ),
      identityVerifiedAt: _parseTimestamp(data['identityVerifiedAt']),
      identityVerifiedBy: data['identityVerifiedBy'] as String?,
      identityVerificationRejectionReason: data['identityVerificationRejectionReason'] as String?,
      verificationDocuments: _parseStringList(data['verificationDocuments']),
      // Parse acceptingBookings - check both direct field and blocks.bookings_globally
      acceptingBookings: _parseAcceptingBookings(data),
    );
  }

  /// Parse accepting bookings from Firestore data
  /// Checks both 'acceptingBookings' field and 'blocks.bookings_globally' for compatibility
  static bool _parseAcceptingBookings(Map<String, dynamic> data) {
    // Direct field takes priority
    if (data.containsKey('acceptingBookings')) {
      return data['acceptingBookings'] as bool? ?? true;
    }
    // Check blocks.bookings_globally (inverted - if blocked globally, not accepting)
    final blocks = data['blocks'] as Map<String, dynamic>?;
    if (blocks != null && blocks.containsKey('bookings_globally')) {
      return !(blocks['bookings_globally'] as bool? ?? false);
    }
    return true; // Default: accepting bookings
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'businessName': businessName,
      'category': category,
      'subcategories': subcategories,
      'description': description,
      'photos': photos,
      'portfolioPhotos': portfolioPhotos,
      'videos': videos,
      'location': location?.toMap(),
      'rating': rating,
      'reviewCount': reviewCount,
      'completedBookings': completedBookings,
      'isVerified': isVerified,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'responseRate': responseRate,
      'responseTime': responseTime,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'website': website,
      'socialLinks': socialLinks,
      'languages': languages,
      'workingHours': workingHours?.toMap(),
      'viewCount': viewCount,
      'leadCount': leadCount,
      'favoriteCount': favoriteCount,
      'confirmedBookings': confirmedBookings,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'priceOnRequest': priceOnRequest,
      'tier': tier.name,
      'yearsExperience': yearsExperience,
      'teamSize': teamSize,
      'specialties': specialties,
      'instantBooking': instantBooking,
      'customPackages': customPackages,
      'privacySettings': privacySettings.toMap(),
      // Onboarding & Verification fields
      'accountStatus': accountStatus.name,
      'entityType': entityType.name,
      'nif': nif,
      'idDocumentType': idDocumentType?.name,
      'idDocumentNumber': idDocumentNumber,
      'idDocumentUrl': idDocumentUrl,
      'rejectionReason': rejectionReason,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      // Identity Verification fields
      'identityVerificationStatus': identityVerificationStatus.name,
      'identityVerifiedAt': identityVerifiedAt != null ? Timestamp.fromDate(identityVerifiedAt!) : null,
      'identityVerifiedBy': identityVerifiedBy,
      'identityVerificationRejectionReason': identityVerificationRejectionReason,
      'verificationDocuments': verificationDocuments,
      // Booking availability
      'acceptingBookings': acceptingBookings,
      'blocks': {
        'bookings_globally': !acceptingBookings,
      },
      // Auto-generate search keywords when saving
      'searchKeywords': generateSearchKeywords(
        businessName: businessName,
        category: category,
        subcategories: subcategories,
        city: location?.city,
        description: description,
      ),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SupplierModel copyWith({
    String? id,
    String? userId,
    String? businessName,
    String? category,
    List<String>? subcategories,
    String? description,
    List<String>? photos,
    List<String>? portfolioPhotos,
    List<String>? videos,
    LocationData? location,
    double? rating,
    int? reviewCount,
    int? completedBookings,
    bool? isVerified,
    bool? isActive,
    bool? isFeatured,
    double? responseRate,
    String? responseTime,
    String? phone,
    String? whatsapp,
    String? email,
    String? website,
    Map<String, String>? socialLinks,
    List<String>? languages,
    WorkingHours? workingHours,
    int? viewCount,
    int? leadCount,
    int? favoriteCount,
    int? confirmedBookings,
    List<String>? searchKeywords,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? minPrice,
    int? maxPrice,
    bool? priceOnRequest,
    SupplierTier? tier,
    int? yearsExperience,
    int? teamSize,
    List<String>? specialties,
    bool? instantBooking,
    bool? customPackages,
    PrivacySettings? privacySettings,
    SupplierAccountStatus? accountStatus,
    SupplierEntityType? entityType,
    String? nif,
    IdentityDocumentType? idDocumentType,
    String? idDocumentNumber,
    String? idDocumentUrl,
    String? rejectionReason,
    DateTime? reviewedAt,
    String? reviewedBy,
    IdentityVerificationStatus? identityVerificationStatus,
    DateTime? identityVerifiedAt,
    String? identityVerifiedBy,
    String? identityVerificationRejectionReason,
    List<String>? verificationDocuments,
    bool? acceptingBookings,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      category: category ?? this.category,
      subcategories: subcategories ?? this.subcategories,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      portfolioPhotos: portfolioPhotos ?? this.portfolioPhotos,
      videos: videos ?? this.videos,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      completedBookings: completedBookings ?? this.completedBookings,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      responseRate: responseRate ?? this.responseRate,
      responseTime: responseTime ?? this.responseTime,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      website: website ?? this.website,
      socialLinks: socialLinks ?? this.socialLinks,
      languages: languages ?? this.languages,
      workingHours: workingHours ?? this.workingHours,
      viewCount: viewCount ?? this.viewCount,
      leadCount: leadCount ?? this.leadCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      confirmedBookings: confirmedBookings ?? this.confirmedBookings,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      priceOnRequest: priceOnRequest ?? this.priceOnRequest,
      tier: tier ?? this.tier,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      teamSize: teamSize ?? this.teamSize,
      specialties: specialties ?? this.specialties,
      instantBooking: instantBooking ?? this.instantBooking,
      customPackages: customPackages ?? this.customPackages,
      privacySettings: privacySettings ?? this.privacySettings,
      accountStatus: accountStatus ?? this.accountStatus,
      entityType: entityType ?? this.entityType,
      nif: nif ?? this.nif,
      idDocumentType: idDocumentType ?? this.idDocumentType,
      idDocumentNumber: idDocumentNumber ?? this.idDocumentNumber,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      identityVerificationStatus: identityVerificationStatus ?? this.identityVerificationStatus,
      identityVerifiedAt: identityVerifiedAt ?? this.identityVerifiedAt,
      identityVerifiedBy: identityVerifiedBy ?? this.identityVerifiedBy,
      identityVerificationRejectionReason: identityVerificationRejectionReason ?? this.identityVerificationRejectionReason,
      verificationDocuments: verificationDocuments ?? this.verificationDocuments,
      acceptingBookings: acceptingBookings ?? this.acceptingBookings,
    );
  }

  /// Check if supplier can access the main dashboard
  bool get canAccessDashboard => accountStatus == SupplierAccountStatus.active;

  /// Check if supplier is pending review
  bool get isPendingReview => accountStatus == SupplierAccountStatus.pendingReview;

  /// Check if supplier needs to fix documents
  bool get needsClarification => accountStatus == SupplierAccountStatus.needsClarification;

  /// Check if supplier application was rejected
  bool get isRejected => accountStatus == SupplierAccountStatus.rejected;

  /// Check if identity is verified
  bool get isIdentityVerified => identityVerificationStatus == IdentityVerificationStatus.verified;

  /// Check if identity verification is pending
  bool get isIdentityPending => identityVerificationStatus == IdentityVerificationStatus.pending;

  /// Check if identity verification was rejected
  bool get isIdentityRejected => identityVerificationStatus == IdentityVerificationStatus.rejected;

  /// Check if supplier is eligible for bookings
  /// Requires BOTH onboarding approval AND identity verification
  bool get isEligibleForBookings =>
      accountStatus == SupplierAccountStatus.active &&
      identityVerificationStatus == IdentityVerificationStatus.verified;

  /// Get identity verification status display text (Portuguese)
  String get identityVerificationStatusText {
    switch (identityVerificationStatus) {
      case IdentityVerificationStatus.pending:
        return 'Verificação Pendente';
      case IdentityVerificationStatus.verified:
        return 'Identidade Verificada';
      case IdentityVerificationStatus.rejected:
        return 'Verificação Rejeitada';
    }
  }

  /// Get account status display text (Portuguese)
  String get accountStatusText {
    switch (accountStatus) {
      case SupplierAccountStatus.pendingReview:
        return 'Em Análise';
      case SupplierAccountStatus.active:
        return 'Ativo';
      case SupplierAccountStatus.needsClarification:
        return 'Documentos Pendentes';
      case SupplierAccountStatus.rejected:
        return 'Rejeitado';
      case SupplierAccountStatus.suspended:
        return 'Suspenso';
    }
  }

  /// Get entity type display text
  String get entityTypeText {
    switch (entityType) {
      case SupplierEntityType.individual:
        return 'Individual';
      case SupplierEntityType.empresa:
        return 'Empresa';
    }
  }

  /// Get formatted price range display
  String get priceRange {
    if (priceOnRequest) {
      return 'Preço sob consulta';
    }
    if (minPrice != null && minPrice! > 0) {
      final formattedPrice = _formatPrice(minPrice!);
      return 'Desde $formattedPrice Kz';
    }
    return 'Preço não definido';
  }

  /// Format price with K/M suffix
  static String _formatPrice(int price) {
    if (price >= 1000000) {
      final millions = price / 1000000;
      return millions == millions.toInt()
          ? '${millions.toInt()}M'
          : '${millions.toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      final thousands = price / 1000;
      return thousands == thousands.toInt()
          ? '${thousands.toInt()}K'
          : '${thousands.toStringAsFixed(1)}K';
    }
    return price.toString();
  }

  /// Get tier display text
  String get tierText {
    switch (tier) {
      case SupplierTier.starter:
        return 'Starter';
      case SupplierTier.pro:
        return 'Pro';
      case SupplierTier.elite:
        return 'Elite';
      case SupplierTier.diamond:
        return 'Diamond';
    }
  }

  /// Get tier badge color
  int get tierColorValue {
    switch (tier) {
      case SupplierTier.starter:
        return 0xFF9E9E9E; // Gray
      case SupplierTier.pro:
        return 0xFF2196F3; // Blue
      case SupplierTier.elite:
        return 0xFFFF9800; // Orange
      case SupplierTier.diamond:
        return 0xFF9C27B0; // Purple
    }
  }

  /// Get phone number respecting privacy settings
  String? get publicPhone => privacySettings.showPhone ? phone : null;

  /// Get email respecting privacy settings
  String? get publicEmail => privacySettings.showEmail ? email : null;

  /// Get full address respecting privacy settings (returns null if address is hidden)
  String? get publicAddress => privacySettings.showAddress ? location?.address : null;

  /// Get public location info (always shows city/province, detailed address only if allowed)
  String get publicLocationDisplay {
    final city = location?.city;
    final province = location?.province;
    final address = publicAddress;

    if (address != null && address.isNotEmpty) {
      return '$address, ${city ?? ''}, ${province ?? ''}';
    } else if (city != null) {
      return province != null ? '$city, $province' : city;
    } else {
      return province ?? 'Angola';
    }
  }

  /// Check if messages are allowed
  bool get allowsMessages => privacySettings.allowMessages;

  /// Check if profile is public
  bool get isPublicProfile => privacySettings.isProfilePublic;

  static List<String> _parseStringList(dynamic value) {
    final result = <String>[];
    if (value is List) {
      for (final item in value) {
        if (item is String) {
          result.add(item);
        }
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

class LocationData {
  final String? city;
  final String? province;
  final String? country;
  final String? address;
  final GeoPoint? geopoint;

  const LocationData({
    this.city,
    this.province,
    this.country,
    this.address,
    this.geopoint,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    final geoRaw = map['geopoint'];
    return LocationData(
      city: map['city'] as String?,
      province: map['province'] as String?,
      country: map['country'] as String?,
      address: map['address'] as String?,
      geopoint: geoRaw is GeoPoint ? geoRaw : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'province': province,
      'country': country,
      'address': address,
      'geopoint': geopoint,
    };
  }
}

class WorkingHours {
  final Map<String, DayHours> schedule;

  const WorkingHours({required this.schedule});

  factory WorkingHours.fromMap(Map<String, dynamic> map) {
    final schedule = <String, DayHours>{};
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        schedule[key] = DayHours.fromMap(value);
      }
    });
    return WorkingHours(schedule: schedule);
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};
    schedule.forEach((key, value) {
      result[key] = value.toMap();
    });
    return result;
  }
}

class DayHours {
  final bool isOpen;
  final String? openTime;
  final String? closeTime;

  const DayHours({
    this.isOpen = false,
    this.openTime,
    this.closeTime,
  });

  factory DayHours.fromMap(Map<String, dynamic> map) {
    return DayHours(
      isOpen: map['isOpen'] as bool? ?? false,
      openTime: map['openTime'] as String?,
      closeTime: map['closeTime'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOpen': isOpen,
      'openTime': openTime,
      'closeTime': closeTime,
    };
  }
}

/// Privacy settings for supplier profiles
/// Controls what information is visible on public profiles
class PrivacySettings {
  /// Whether the profile is publicly visible to clients
  final bool isProfilePublic;

  /// Whether to show email on public profile
  final bool showEmail;

  /// Whether to show phone number on public profile
  final bool showPhone;

  /// Whether to show physical address on public profile
  final bool showAddress;

  /// Whether to allow direct messages from clients
  final bool allowMessages;

  const PrivacySettings({
    this.isProfilePublic = true,
    this.showEmail = false,  // Default: hide email for privacy
    this.showPhone = false,  // Default: hide phone for privacy
    this.showAddress = false, // Default: hide address for privacy
    this.allowMessages = true,
  });

  factory PrivacySettings.fromMap(Map<String, dynamic> map) {
    return PrivacySettings(
      isProfilePublic: map['isProfilePublic'] as bool? ?? true,
      showEmail: map['showEmail'] as bool? ?? false,
      showPhone: map['showPhone'] as bool? ?? false,
      showAddress: map['showAddress'] as bool? ?? false,
      allowMessages: map['allowMessages'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isProfilePublic': isProfilePublic,
      'showEmail': showEmail,
      'showPhone': showPhone,
      'showAddress': showAddress,
      'allowMessages': allowMessages,
    };
  }

  PrivacySettings copyWith({
    bool? isProfilePublic,
    bool? showEmail,
    bool? showPhone,
    bool? showAddress,
    bool? allowMessages,
  }) {
    return PrivacySettings(
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showAddress: showAddress ?? this.showAddress,
      allowMessages: allowMessages ?? this.allowMessages,
    );
  }
}
