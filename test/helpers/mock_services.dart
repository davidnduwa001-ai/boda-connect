import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boda_connect/core/services/auth_service.dart';
import 'package:boda_connect/core/services/payment_service.dart';
import 'package:boda_connect/core/services/cancellation_service.dart';
import 'package:boda_connect/core/services/deep_link_service.dart';
import 'package:boda_connect/core/services/video_thumbnail_service.dart';
import 'package:boda_connect/core/services/platform_settings_service.dart';
import 'package:boda_connect/core/services/push_notification.dart';
import 'package:boda_connect/core/repositories/safety_score_repository.dart';
import 'package:boda_connect/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:boda_connect/features/supplier/data/repositories/supplier_repository_impl.dart';
import 'package:boda_connect/features/booking/data/repositories/booking_repository_impl.dart';

// ==================== MOCK CLASSES ====================

/// Mock Firebase Auth
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

/// Mock Firebase User
class MockUser extends Mock implements User {
  final String mockUid;
  final String? mockEmail;
  final String? mockDisplayName;
  final String? mockPhoneNumber;
  final bool mockEmailVerified;

  MockUser({
    this.mockUid = 'test-user-id',
    this.mockEmail = 'test@example.com',
    this.mockDisplayName = 'Test User',
    this.mockPhoneNumber = '+244912345678',
    this.mockEmailVerified = true,
  });

  @override
  String get uid => mockUid;

  @override
  String? get email => mockEmail;

  @override
  String? get displayName => mockDisplayName;

  @override
  String? get phoneNumber => mockPhoneNumber;

  @override
  bool get emailVerified => mockEmailVerified;
}

/// Mock Firebase Messaging
class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

/// Mock Auth Service
class MockAuthService extends Mock implements AuthService {}

/// Mock Payment Service
class MockPaymentService extends Mock implements PaymentService {}

/// Mock Cancellation Service
class MockCancellationService extends Mock implements CancellationService {}

/// Mock Deep Link Service
class MockDeepLinkService extends Mock implements DeepLinkService {}

/// Mock Video Thumbnail Service
class MockVideoThumbnailService extends Mock implements VideoThumbnailService {}

/// Mock Platform Settings Service
class MockPlatformSettingsService extends Mock
    implements PlatformSettingsService {}

/// Mock Push Notification Service
class MockPushNotificationService extends Mock
    implements PushNotificationService {}

/// Mock Safety Score Repository
class MockSafetyScoreRepository extends Mock implements SafetyScoreRepository {}

/// Mock Chat Repository
class MockChatRepository extends Mock implements ChatRepositoryImpl {}

/// Mock Supplier Repository
class MockSupplierRepository extends Mock implements SupplierRepositoryImpl {}

/// Mock Booking Repository
class MockBookingRepository extends Mock implements BookingRepositoryImpl {}

// ==================== FAKE CLASSES FOR FALLBACK VALUES ====================

class FakeTimestamp extends Fake implements Timestamp {
  @override
  DateTime toDate() => DateTime.now();

  @override
  int get millisecondsSinceEpoch => DateTime.now().millisecondsSinceEpoch;
}

// ==================== SETUP HELPERS ====================

/// Register all fallback values for mocktail
void registerFallbackValues() {
  registerFallbackValue(FakeTimestamp());
  registerFallbackValue(<String, dynamic>{});
}

/// Setup SharedPreferences for testing
Future<void> setupTestSharedPreferences({
  Map<String, Object>? values,
}) async {
  SharedPreferences.setMockInitialValues(values ?? {});
}
