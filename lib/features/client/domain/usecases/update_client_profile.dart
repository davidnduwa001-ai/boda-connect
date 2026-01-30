import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/client/domain/entities/client_entity.dart';
import 'package:boda_connect/features/client/domain/repositories/client_repository.dart';

/// Use case for updating a client's profile information
///
/// This use case allows clients to modify their profile details such as
/// name, email, location, preferences, and settings.
///
/// This follows the Single Responsibility Principle - one use case for
/// one specific operation (updating profile).
///
/// Usage:
/// ```dart
/// final useCase = UpdateClientProfile(repository);
/// final result = await useCase(UpdateClientProfileParams(
///   clientId: 'client123',
///   name: 'John Doe',
///   email: 'john@example.com',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (client) => print('Profile updated: ${client.name}'),
/// );
/// ```
class UpdateClientProfile {
  final ClientRepository repository;

  const UpdateClientProfile(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] on success or [Failure] on error
  ///
  /// Possible failures:
  /// - [NotFoundFailure] if client doesn't exist
  /// - [ValidationFailure] if the data is invalid
  /// - [NetworkFailure] if there's no internet connection
  /// - [ServerFailure] if the server returns an error
  ResultFuture<ClientEntity> call(UpdateClientProfileParams params) {
    return repository.updateClientProfile(
      clientId: params.clientId,
      name: params.name,
      email: params.email,
      photoUrl: params.photoUrl,
      location: params.location,
      preferredCategories: params.preferredCategories,
      preferredLanguage: params.preferredLanguage,
      notificationPreferences: params.notificationPreferences,
      privacySettings: params.privacySettings,
      fcmToken: params.fcmToken,
    );
  }
}

/// Parameters for updating a client profile
///
/// This class encapsulates all the optional fields that can be updated.
/// Only the fields that are provided (non-null) will be updated in the repository.
class UpdateClientProfileParams {
  /// The unique identifier of the client to update
  final String clientId;

  /// Updated client name
  final String? name;

  /// Updated email address
  final String? email;

  /// Updated profile photo URL
  final String? photoUrl;

  /// Updated location information
  final ClientLocationEntity? location;

  /// Updated list of preferred event categories
  final List<String>? preferredCategories;

  /// Updated preferred language
  final String? preferredLanguage;

  /// Updated notification preferences
  final NotificationPreferencesEntity? notificationPreferences;

  /// Updated privacy settings
  final PrivacySettingsEntity? privacySettings;

  /// Updated FCM token for push notifications
  final String? fcmToken;

  const UpdateClientProfileParams({
    required this.clientId,
    this.name,
    this.email,
    this.photoUrl,
    this.location,
    this.preferredCategories,
    this.preferredLanguage,
    this.notificationPreferences,
    this.privacySettings,
    this.fcmToken,
  });
}

/// Use case for updating client notification preferences
///
/// This is a specialized use case for updating only notification settings.
/// It's more focused than the general UpdateClientProfile use case.
///
/// Usage:
/// ```dart
/// final useCase = UpdateNotificationPreferences(repository);
/// final prefs = NotificationPreferencesEntity(
///   bookingUpdates: true,
///   promotions: false,
/// );
/// final result = await useCase(UpdateNotificationPreferencesParams(
///   clientId: 'client123',
///   preferences: prefs,
/// ));
/// ```
class UpdateNotificationPreferences {
  final ClientRepository repository;

  const UpdateNotificationPreferences(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] on success or [Failure] on error
  ResultFuture<ClientEntity> call(UpdateNotificationPreferencesParams params) {
    return repository.updateNotificationPreferences(
      clientId: params.clientId,
      preferences: params.preferences,
    );
  }
}

/// Parameters for updating notification preferences
class UpdateNotificationPreferencesParams {
  final String clientId;
  final NotificationPreferencesEntity preferences;

  const UpdateNotificationPreferencesParams({
    required this.clientId,
    required this.preferences,
  });
}

/// Use case for updating client privacy settings
///
/// This is a specialized use case for updating only privacy settings.
/// It's more focused than the general UpdateClientProfile use case.
///
/// Usage:
/// ```dart
/// final useCase = UpdatePrivacySettings(repository);
/// final settings = PrivacySettingsEntity(
///   profileVisibleToSuppliers: true,
///   showBookingHistory: false,
/// );
/// final result = await useCase(UpdatePrivacySettingsParams(
///   clientId: 'client123',
///   settings: settings,
/// ));
/// ```
class UpdatePrivacySettings {
  final ClientRepository repository;

  const UpdatePrivacySettings(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] on success or [Failure] on error
  ResultFuture<ClientEntity> call(UpdatePrivacySettingsParams params) {
    return repository.updatePrivacySettings(
      clientId: params.clientId,
      settings: params.settings,
    );
  }
}

/// Parameters for updating privacy settings
class UpdatePrivacySettingsParams {
  final String clientId;
  final PrivacySettingsEntity settings;

  const UpdatePrivacySettingsParams({
    required this.clientId,
    required this.settings,
  });
}

/// Use case for updating client's FCM token
///
/// This should be called when the device's FCM token changes
/// to ensure the client receives push notifications.
///
/// Usage:
/// ```dart
/// final useCase = UpdateClientFcmToken(repository);
/// final result = await useCase(UpdateClientFcmTokenParams(
///   clientId: 'client123',
///   fcmToken: 'new_fcm_token_here',
/// ));
/// ```
class UpdateClientFcmToken {
  final ClientRepository repository;

  const UpdateClientFcmToken(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] on success or [Failure] on error
  ResultFuture<ClientEntity> call(UpdateClientFcmTokenParams params) {
    return repository.updateClientProfile(
      clientId: params.clientId,
      fcmToken: params.fcmToken,
    );
  }
}

/// Parameters for updating FCM token
class UpdateClientFcmTokenParams {
  final String clientId;
  final String fcmToken;

  const UpdateClientFcmTokenParams({
    required this.clientId,
    required this.fcmToken,
  });
}

/// Use case for verifying client's email
///
/// This should be called after the client has verified their email address
/// through a verification link or code.
///
/// Usage:
/// ```dart
/// final useCase = VerifyClientEmail(repository);
/// final result = await useCase(VerifyClientEmailParams(
///   clientId: 'client123',
/// ));
/// ```
class VerifyClientEmail {
  final ClientRepository repository;

  const VerifyClientEmail(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] with verified email status
  ResultFuture<ClientEntity> call(VerifyClientEmailParams params) {
    return repository.verifyEmail(params.clientId);
  }
}

/// Parameters for verifying client email
class VerifyClientEmailParams {
  final String clientId;

  const VerifyClientEmailParams({
    required this.clientId,
  });
}

/// Use case for verifying client's phone
///
/// This should be called after the client has verified their phone number
/// through an OTP code.
///
/// Usage:
/// ```dart
/// final useCase = VerifyClientPhone(repository);
/// final result = await useCase(VerifyClientPhoneParams(
///   clientId: 'client123',
/// ));
/// ```
class VerifyClientPhone {
  final ClientRepository repository;

  const VerifyClientPhone(this.repository);

  /// Execute the use case
  ///
  /// Returns the updated [ClientEntity] with verified phone status
  ResultFuture<ClientEntity> call(VerifyClientPhoneParams params) {
    return repository.verifyPhone(params.clientId);
  }
}

/// Parameters for verifying client phone
class VerifyClientPhoneParams {
  final String clientId;

  const VerifyClientPhoneParams({
    required this.clientId,
  });
}
