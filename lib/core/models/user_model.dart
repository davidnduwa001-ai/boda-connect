import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/models/user_type.dart';

class UserModel {
  final String uid;
  final String phone;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String? description; // User bio/description
  final UserType userType;
  final LocationData? location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? fcmToken;
  final UserPreferences? preferences;
  final double rating;
  final bool isOnline;
  final DateTime? lastSeen;
  // Violations tracking (admin-managed)
  final int violationsCount;
  final DateTime? lastViolationAt;
  // Verification status (admin-controlled badge)
  final bool isVerified;
  final DateTime? verifiedAt;

  const UserModel({
    required this.uid,
    required this.phone,
    this.name,
    this.email,
    this.photoUrl,
    this.description,
    required this.userType,
    this.location,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.fcmToken,
    this.preferences,
    this.rating = 5.0,
    this.isOnline = false,
    this.lastSeen,
    this.violationsCount = 0,
    this.lastViolationAt,
    this.isVerified = false,
    this.verifiedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse user type
    final userTypeStr = data['userType'] as String?;
    final userType = UserType.values.firstWhere(
      (e) => e.name == userTypeStr,
      orElse: () => UserType.client,
    );

    // Parse location
    final locationRaw = data['location'];
    final location = locationRaw is Map<String, dynamic>
        ? LocationData.fromMap(locationRaw)
        : null;

    // Parse preferences
    final preferencesRaw = data['preferences'];
    final preferences = preferencesRaw is Map<String, dynamic>
        ? UserPreferences.fromMap(preferencesRaw)
        : null;

    return UserModel(
      uid: doc.id,
      phone: data['phone']?.toString() ?? '',
      name: data['name']?.toString(),
      email: data['email']?.toString(),
      photoUrl: data['photoUrl'] as String?,
      description: data['description'] as String?,
      userType: userType,
      location: location,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      fcmToken: data['fcmToken'] as String?,
      preferences: preferences,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: _parseTimestamp(data['lastSeen']),
      violationsCount: (data['violationsCount'] as num?)?.toInt() ?? 0,
      lastViolationAt: _parseTimestamp(data['lastViolationAt']),
      isVerified: data['isVerified'] as bool? ?? false,
      verifiedAt: _parseTimestamp(data['verifiedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phone': phone,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'description': description,
      'userType': userType.name,
      'location': location?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'fcmToken': fcmToken,
      'preferences': preferences?.toMap(),
      'rating': rating,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'violationsCount': violationsCount,
      'lastViolationAt': lastViolationAt != null ? Timestamp.fromDate(lastViolationAt!) : null,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    };
  }

  UserModel copyWith({
    String? uid,
    String? phone,
    String? name,
    String? email,
    String? photoUrl,
    String? description,
    UserType? userType,
    LocationData? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? fcmToken,
    UserPreferences? preferences,
    double? rating,
    bool? isOnline,
    DateTime? lastSeen,
    int? violationsCount,
    DateTime? lastViolationAt,
    bool? isVerified,
    DateTime? verifiedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      description: description ?? this.description,
      userType: userType ?? this.userType,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      preferences: preferences ?? this.preferences,
      rating: rating ?? this.rating,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      violationsCount: violationsCount ?? this.violationsCount,
      lastViolationAt: lastViolationAt ?? this.lastViolationAt,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
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

class UserPreferences {
  /// Preferred service categories
  final List<String>? categories;

  /// Whether user completed onboarding
  final bool? completedOnboarding;

  /// Notification preferences
  final bool notifyNewMessages;
  final bool notifyBookingUpdates;
  final bool notifyPromotions;
  final bool notifyReminders;

  /// Display preferences
  final String? preferredLanguage;
  final bool darkMode;

  /// Privacy preferences
  final bool showOnlineStatus;
  final bool allowDirectMessages;

  /// Search preferences
  final int? maxDistance; // in km
  final int? minBudget;
  final int? maxBudget;
  final List<String>? preferredLocations;

  const UserPreferences({
    this.categories,
    this.completedOnboarding,
    this.notifyNewMessages = true,
    this.notifyBookingUpdates = true,
    this.notifyPromotions = true,
    this.notifyReminders = true,
    this.preferredLanguage,
    this.darkMode = false,
    this.showOnlineStatus = true,
    this.allowDirectMessages = true,
    this.maxDistance,
    this.minBudget,
    this.maxBudget,
    this.preferredLocations,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    final categoriesRaw = map['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw.map((e) => e.toString()).toList()
        : null;

    final locationsRaw = map['preferredLocations'];
    final preferredLocations = locationsRaw is List
        ? locationsRaw.map((e) => e.toString()).toList()
        : null;

    return UserPreferences(
      categories: categories,
      completedOnboarding: map['completedOnboarding'] as bool?,
      notifyNewMessages: map['notifyNewMessages'] as bool? ?? true,
      notifyBookingUpdates: map['notifyBookingUpdates'] as bool? ?? true,
      notifyPromotions: map['notifyPromotions'] as bool? ?? true,
      notifyReminders: map['notifyReminders'] as bool? ?? true,
      preferredLanguage: map['preferredLanguage'] as String?,
      darkMode: map['darkMode'] as bool? ?? false,
      showOnlineStatus: map['showOnlineStatus'] as bool? ?? true,
      allowDirectMessages: map['allowDirectMessages'] as bool? ?? true,
      maxDistance: (map['maxDistance'] as num?)?.toInt(),
      minBudget: (map['minBudget'] as num?)?.toInt(),
      maxBudget: (map['maxBudget'] as num?)?.toInt(),
      preferredLocations: preferredLocations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categories': categories,
      'completedOnboarding': completedOnboarding,
      'notifyNewMessages': notifyNewMessages,
      'notifyBookingUpdates': notifyBookingUpdates,
      'notifyPromotions': notifyPromotions,
      'notifyReminders': notifyReminders,
      'preferredLanguage': preferredLanguage,
      'darkMode': darkMode,
      'showOnlineStatus': showOnlineStatus,
      'allowDirectMessages': allowDirectMessages,
      'maxDistance': maxDistance,
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'preferredLocations': preferredLocations,
    };
  }

  UserPreferences copyWith({
    List<String>? categories,
    bool? completedOnboarding,
    bool? notifyNewMessages,
    bool? notifyBookingUpdates,
    bool? notifyPromotions,
    bool? notifyReminders,
    String? preferredLanguage,
    bool? darkMode,
    bool? showOnlineStatus,
    bool? allowDirectMessages,
    int? maxDistance,
    int? minBudget,
    int? maxBudget,
    List<String>? preferredLocations,
  }) {
    return UserPreferences(
      categories: categories ?? this.categories,
      completedOnboarding: completedOnboarding ?? this.completedOnboarding,
      notifyNewMessages: notifyNewMessages ?? this.notifyNewMessages,
      notifyBookingUpdates: notifyBookingUpdates ?? this.notifyBookingUpdates,
      notifyPromotions: notifyPromotions ?? this.notifyPromotions,
      notifyReminders: notifyReminders ?? this.notifyReminders,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      darkMode: darkMode ?? this.darkMode,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowDirectMessages: allowDirectMessages ?? this.allowDirectMessages,
      maxDistance: maxDistance ?? this.maxDistance,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      preferredLocations: preferredLocations ?? this.preferredLocations,
    );
  }
}
