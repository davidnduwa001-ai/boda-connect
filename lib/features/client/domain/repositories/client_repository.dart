import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/client/domain/entities/client_entity.dart';

/// Abstract repository interface for Client operations
/// This defines the contract that the data layer must implement
///
/// Following Clean Architecture principles:
/// - The domain layer defines the interface (this abstract class)
/// - The data layer provides the concrete implementation
/// - This ensures the domain layer is independent of data sources (Firebase, API, etc.)
abstract class ClientRepository {
  /// Get a client profile by client ID
  ///
  /// Returns [ClientEntity] on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> getClientProfile(String clientId);

  /// Get a client profile by user ID (from auth system)
  ///
  /// This is useful when you have the authenticated user ID
  /// and need to fetch the associated client profile
  ///
  /// Returns [ClientEntity] on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> getClientProfileByUserId(String userId);

  /// Create a new client profile
  ///
  /// This is typically called after user registration
  ///
  /// Returns the created [ClientEntity] on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [ValidationFailure] if the data is invalid
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> createClientProfile(ClientEntity client);

  /// Update an existing client profile
  ///
  /// This allows clients to modify their profile information
  /// Only the provided fields will be updated (partial update)
  ///
  /// Returns the updated [ClientEntity] on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [ValidationFailure] if the data is invalid
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> updateClientProfile({
    required String clientId,
    String? name,
    String? email,
    String? photoUrl,
    ClientLocationEntity? location,
    List<String>? preferredCategories,
    String? preferredLanguage,
    NotificationPreferencesEntity? notificationPreferences,
    PrivacySettingsEntity? privacySettings,
    String? fcmToken,
  });

  /// Add a supplier to the client's favorites
  ///
  /// Returns the updated [ClientEntity] with the supplier added to favorites
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> addFavoriteSupplier({
    required String clientId,
    required String supplierId,
  });

  /// Remove a supplier from the client's favorites
  ///
  /// Returns the updated [ClientEntity] with the supplier removed from favorites
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> removeFavoriteSupplier({
    required String clientId,
    required String supplierId,
  });

  /// Get all favorite suppliers for a client
  ///
  /// Returns a list of favorite supplier IDs on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<List<String>> getFavoriteSupplierIds(String clientId);

  /// Check if a supplier is in the client's favorites
  ///
  /// Returns true if the supplier is a favorite, false otherwise
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<bool> isFavoriteSupplier({
    required String clientId,
    required String supplierId,
  });

  /// Update client's notification preferences
  ///
  /// Returns the updated [ClientEntity] with new notification preferences
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> updateNotificationPreferences({
    required String clientId,
    required NotificationPreferencesEntity preferences,
  });

  /// Update client's privacy settings
  ///
  /// Returns the updated [ClientEntity] with new privacy settings
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> updatePrivacySettings({
    required String clientId,
    required PrivacySettingsEntity settings,
  });

  /// Increment the client's booking count
  ///
  /// This should be called when a new booking is created
  ///
  /// Returns the updated [ClientEntity] with incremented booking count
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> incrementBookingCount(String clientId);

  /// Increment the client's review count
  ///
  /// This should be called when the client writes a new review
  ///
  /// Returns the updated [ClientEntity] with incremented review count
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> incrementReviewCount(String clientId);

  /// Update the client's last active timestamp
  ///
  /// This should be called periodically to track user activity
  ///
  /// Returns void on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFutureVoid updateLastActive(String clientId);

  /// Delete a client profile
  ///
  /// This permanently deletes the client's profile
  /// Use with caution - this operation cannot be undone
  ///
  /// Returns void on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [PermissionFailure] if user doesn't have permission
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFutureVoid deleteClientProfile(String clientId);

  /// Deactivate a client account
  ///
  /// This sets the client's isActive flag to false
  /// The account can be reactivated later
  ///
  /// Returns the updated [ClientEntity] with isActive set to false
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> deactivateAccount(String clientId);

  /// Reactivate a client account
  ///
  /// This sets the client's isActive flag to true
  ///
  /// Returns the updated [ClientEntity] with isActive set to true
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> reactivateAccount(String clientId);

  /// Verify client's email
  ///
  /// This sets the client's isEmailVerified flag to true
  ///
  /// Returns the updated [ClientEntity] with verified email status
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> verifyEmail(String clientId);

  /// Verify client's phone
  ///
  /// This sets the client's isPhoneVerified flag to true
  ///
  /// Returns the updated [ClientEntity] with verified phone status
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> verifyPhone(String clientId);
}
