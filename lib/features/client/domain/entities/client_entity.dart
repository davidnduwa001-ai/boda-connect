import 'package:equatable/equatable.dart';

/// Pure Dart entity representing a Client in the domain layer
/// This entity is independent of any framework or external library (Firebase, etc.)
///
/// A client represents a user who searches for and books event services
/// from suppliers in the marketplace. Clients can browse suppliers,
/// save favorites, create bookings, and manage their profile.
class ClientEntity extends Equatable {
  /// Unique identifier for the client
  final String id;

  /// User ID from the authentication system
  final String userId;

  /// Client's full name
  final String? name;

  /// Client's email address
  final String? email;

  /// Client's phone number (required for authentication)
  final String phone;

  /// URL to the client's profile photo
  final String? photoUrl;

  /// Client's location information
  final ClientLocationEntity? location;

  /// List of favorite supplier IDs
  final List<String> favoriteSupplierIds;

  /// Client's preferred event categories (e.g., weddings, corporate events)
  final List<String> preferredCategories;

  /// Client's preferred language for communication
  final String? preferredLanguage;

  /// Total number of bookings made by this client
  final int totalBookings;

  /// Total number of reviews written by this client
  final int totalReviews;

  /// Whether the client account is active
  final bool isActive;

  /// Whether the client's email is verified
  final bool isEmailVerified;

  /// Whether the client's phone is verified
  final bool isPhoneVerified;

  /// Firebase Cloud Messaging token for push notifications
  final String? fcmToken;

  /// Client's notification preferences
  final NotificationPreferencesEntity? notificationPreferences;

  /// Client's privacy settings
  final PrivacySettingsEntity? privacySettings;

  /// Date and time when the client account was created
  final DateTime createdAt;

  /// Date and time when the client profile was last updated
  final DateTime updatedAt;

  /// Date and time of the client's last activity
  final DateTime? lastActiveAt;

  const ClientEntity({
    required this.id,
    required this.userId,
    this.name,
    this.email,
    required this.phone,
    this.photoUrl,
    this.location,
    this.favoriteSupplierIds = const [],
    this.preferredCategories = const [],
    this.preferredLanguage,
    this.totalBookings = 0,
    this.totalReviews = 0,
    this.isActive = true,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.fcmToken,
    this.notificationPreferences,
    this.privacySettings,
    required this.createdAt,
    required this.updatedAt,
    this.lastActiveAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        email,
        phone,
        photoUrl,
        location,
        favoriteSupplierIds,
        preferredCategories,
        preferredLanguage,
        totalBookings,
        totalReviews,
        isActive,
        isEmailVerified,
        isPhoneVerified,
        fcmToken,
        notificationPreferences,
        privacySettings,
        createdAt,
        updatedAt,
        lastActiveAt,
      ];

  /// Creates a copy of this entity with the specified fields replaced
  ClientEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    ClientLocationEntity? location,
    List<String>? favoriteSupplierIds,
    List<String>? preferredCategories,
    String? preferredLanguage,
    int? totalBookings,
    int? totalReviews,
    bool? isActive,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    String? fcmToken,
    NotificationPreferencesEntity? notificationPreferences,
    PrivacySettingsEntity? privacySettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActiveAt,
  }) {
    return ClientEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      favoriteSupplierIds: favoriteSupplierIds ?? this.favoriteSupplierIds,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      totalBookings: totalBookings ?? this.totalBookings,
      totalReviews: totalReviews ?? this.totalReviews,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
      privacySettings: privacySettings ?? this.privacySettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  // ==================== BUSINESS LOGIC METHODS ====================

  /// Checks if the supplier is in the client's favorites
  bool isFavoriteSupplier(String supplierId) {
    return favoriteSupplierIds.contains(supplierId);
  }

  /// Adds a supplier to favorites
  /// Returns a new ClientEntity with the supplier added to favorites
  ClientEntity addFavoriteSupplier(String supplierId) {
    if (isFavoriteSupplier(supplierId)) {
      return this; // Already a favorite
    }
    return copyWith(
      favoriteSupplierIds: [...favoriteSupplierIds, supplierId],
      updatedAt: DateTime.now(),
    );
  }

  /// Removes a supplier from favorites
  /// Returns a new ClientEntity with the supplier removed from favorites
  ClientEntity removeFavoriteSupplier(String supplierId) {
    if (!isFavoriteSupplier(supplierId)) {
      return this; // Not a favorite
    }
    return copyWith(
      favoriteSupplierIds: favoriteSupplierIds.where((id) => id != supplierId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Toggles a supplier's favorite status
  /// Returns a new ClientEntity with the supplier's favorite status toggled
  ClientEntity toggleFavoriteSupplier(String supplierId) {
    if (isFavoriteSupplier(supplierId)) {
      return removeFavoriteSupplier(supplierId);
    } else {
      return addFavoriteSupplier(supplierId);
    }
  }

  /// Checks if the client has completed their profile
  /// A complete profile has name, email, and location
  bool get hasCompleteProfile {
    return name != null &&
           name!.isNotEmpty &&
           email != null &&
           email!.isNotEmpty &&
           location != null;
  }

  /// Checks if the client is fully verified (email and phone)
  bool get isFullyVerified {
    return isEmailVerified && isPhoneVerified;
  }

  /// Gets the client's display name
  /// Returns name if available, otherwise returns phone number
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return phone;
  }

  /// Checks if the client is a new user (less than 7 days old)
  bool get isNewUser {
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
    return daysSinceCreation < 7;
  }

  /// Checks if the client is an active user (has made at least one booking)
  bool get hasBookingHistory {
    return totalBookings > 0;
  }

  /// Gets the client's activity status
  /// Returns true if the client was active in the last 30 days
  bool get isRecentlyActive {
    if (lastActiveAt == null) return false;
    final daysSinceLastActivity = DateTime.now().difference(lastActiveAt!).inDays;
    return daysSinceLastActivity <= 30;
  }

  /// Increments the total bookings count
  /// Returns a new ClientEntity with incremented booking count
  ClientEntity incrementBookingCount() {
    return copyWith(
      totalBookings: totalBookings + 1,
      updatedAt: DateTime.now(),
    );
  }

  /// Increments the total reviews count
  /// Returns a new ClientEntity with incremented review count
  ClientEntity incrementReviewCount() {
    return copyWith(
      totalReviews: totalReviews + 1,
      updatedAt: DateTime.now(),
    );
  }

  /// Updates the last active timestamp to now
  /// Returns a new ClientEntity with updated last active timestamp
  ClientEntity updateLastActive() {
    return copyWith(
      lastActiveAt: DateTime.now(),
    );
  }
}

/// Location entity for client
/// Contains geographical information about the client
class ClientLocationEntity extends Equatable {
  /// City name
  final String? city;

  /// Province/state name
  final String? province;

  /// Country name
  final String? country;

  /// Full street address
  final String? address;

  /// Geographic coordinates
  final GeoPointEntity? geopoint;

  const ClientLocationEntity({
    this.city,
    this.province,
    this.country,
    this.address,
    this.geopoint,
  });

  @override
  List<Object?> get props => [city, province, country, address, geopoint];

  ClientLocationEntity copyWith({
    String? city,
    String? province,
    String? country,
    String? address,
    GeoPointEntity? geopoint,
  }) {
    return ClientLocationEntity(
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      address: address ?? this.address,
      geopoint: geopoint ?? this.geopoint,
    );
  }

  /// Gets a formatted address string
  String get formattedAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }
}

/// Pure Dart GeoPoint entity (not dependent on Firebase)
/// Represents geographic coordinates
class GeoPointEntity extends Equatable {
  final double latitude;
  final double longitude;

  const GeoPointEntity({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];

  GeoPointEntity copyWith({
    double? latitude,
    double? longitude,
  }) {
    return GeoPointEntity(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Validates if the coordinates are valid
  bool get isValid {
    return latitude >= -90 && latitude <= 90 &&
           longitude >= -180 && longitude <= 180;
  }
}

/// Notification preferences entity
/// Defines what types of notifications the client wants to receive
class NotificationPreferencesEntity extends Equatable {
  /// Enable/disable booking status update notifications
  final bool bookingUpdates;

  /// Enable/disable promotional notifications
  final bool promotions;

  /// Enable/disable chat message notifications
  final bool messages;

  /// Enable/disable review reminder notifications
  final bool reviewReminders;

  /// Enable/disable supplier recommendations
  final bool recommendations;

  /// Enable/disable email notifications
  final bool emailNotifications;

  /// Enable/disable push notifications
  final bool pushNotifications;

  /// Enable/disable SMS notifications
  final bool smsNotifications;

  const NotificationPreferencesEntity({
    this.bookingUpdates = true,
    this.promotions = true,
    this.messages = true,
    this.reviewReminders = true,
    this.recommendations = true,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.smsNotifications = false,
  });

  @override
  List<Object?> get props => [
        bookingUpdates,
        promotions,
        messages,
        reviewReminders,
        recommendations,
        emailNotifications,
        pushNotifications,
        smsNotifications,
      ];

  NotificationPreferencesEntity copyWith({
    bool? bookingUpdates,
    bool? promotions,
    bool? messages,
    bool? reviewReminders,
    bool? recommendations,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
  }) {
    return NotificationPreferencesEntity(
      bookingUpdates: bookingUpdates ?? this.bookingUpdates,
      promotions: promotions ?? this.promotions,
      messages: messages ?? this.messages,
      reviewReminders: reviewReminders ?? this.reviewReminders,
      recommendations: recommendations ?? this.recommendations,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
    );
  }

  /// Checks if all notifications are disabled
  bool get allDisabled {
    return !bookingUpdates &&
           !promotions &&
           !messages &&
           !reviewReminders &&
           !recommendations;
  }
}

/// Privacy settings entity
/// Defines the client's privacy preferences
class PrivacySettingsEntity extends Equatable {
  /// Make profile visible to suppliers
  final bool profileVisibleToSuppliers;

  /// Show booking history to suppliers
  final bool showBookingHistory;

  /// Show reviews publicly
  final bool showReviews;

  /// Allow data collection for personalization
  final bool allowDataCollection;

  const PrivacySettingsEntity({
    this.profileVisibleToSuppliers = true,
    this.showBookingHistory = false,
    this.showReviews = true,
    this.allowDataCollection = true,
  });

  @override
  List<Object?> get props => [
        profileVisibleToSuppliers,
        showBookingHistory,
        showReviews,
        allowDataCollection,
      ];

  PrivacySettingsEntity copyWith({
    bool? profileVisibleToSuppliers,
    bool? showBookingHistory,
    bool? showReviews,
    bool? allowDataCollection,
  }) {
    return PrivacySettingsEntity(
      profileVisibleToSuppliers: profileVisibleToSuppliers ?? this.profileVisibleToSuppliers,
      showBookingHistory: showBookingHistory ?? this.showBookingHistory,
      showReviews: showReviews ?? this.showReviews,
      allowDataCollection: allowDataCollection ?? this.allowDataCollection,
    );
  }
}
