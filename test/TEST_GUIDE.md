# BODA CONNECT - Comprehensive Test Guide

## Overview

This document provides a complete guide for testing the BODA CONNECT application.
The test suite covers all major features including authentication, payments, bookings,
chat, supplier management, and more.

## Test Structure

```
test/
├── helpers/
│   ├── mock_services.dart       # Mock classes for services
│   ├── pump_app.dart            # Widget test helpers
│   └── test_helpers.dart        # General test utilities
│
├── unit/
│   ├── core/
│   │   ├── errors/
│   │   │   └── failures_test.dart
│   │   ├── repositories/
│   │   │   └── safety_score_test.dart
│   │   ├── services/
│   │   │   ├── auth_service_comprehensive_test.dart
│   │   │   ├── payment_service_test.dart
│   │   │   ├── deep_link_service_test.dart
│   │   │   ├── video_thumbnail_service_test.dart
│   │   │   └── platform_settings_test.dart
│   │   └── utils/
│   │       ├── validators_test.dart
│   │       └── phone_formatter_test.dart
│   │
│   └── features/
│       ├── booking/
│       │   ├── data/
│       │   │   ├── models/
│       │   │   │   └── booking_model_test.dart
│       │   │   └── repositories/
│       │   │       └── booking_repository_impl_test.dart
│       │   └── booking_flow_test.dart
│       │
│       ├── chat/
│       │   ├── data/
│       │   │   ├── models/
│       │   │   │   ├── conversation_model_test.dart
│       │   │   │   └── message_model_test.dart
│       │   │   └── repositories/
│       │   │       └── chat_repository_impl_test.dart
│       │   └── chat_service_test.dart
│       │
│       └── supplier/
│           ├── data/
│           │   ├── models/
│           │   │   ├── supplier_model_test.dart
│           │   │   ├── package_model_test.dart
│           │   │   └── ...
│           │   └── repositories/
│           │       └── supplier_repository_impl_test.dart
│           └── supplier_management_test.dart
│
├── integration/
│   └── app_integration_test.dart
│
└── widget_test.dart
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/unit/core/services/payment_service_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Run Tests in Verbose Mode
```bash
flutter test --reporter expanded
```

### Run Only Unit Tests
```bash
flutter test test/unit/
```

### Run Only Integration Tests
```bash
flutter test test/integration/
```

## Test Categories

### 1. Authentication Tests (`auth_service_comprehensive_test.dart`)

**Coverage:**
- Phone authentication (SMS OTP)
- Email authentication
- Google Sign-In
- WhatsApp authentication
- User registration (Client & Supplier)
- Session management
- FCM token updates
- Account deletion

**Key Test Cases:**
```dart
// Phone number formatting
test('should format Angola phone number correctly')

// User creation
test('should create new client user in Firestore')
test('should create new supplier user in Firestore')

// Duplicate prevention
test('should prevent duplicate phone registration')
test('should prevent duplicate email registration')

// Session management
test('should sign out user')
test('should emit auth state changes')
```

### 2. Payment Tests (`payment_service_test.dart`)

**Coverage:**
- ProxyPay/Multicaixa Express integration
- OPG (Online Payment Gateway)
- RPS (Reference Payment System)
- Escrow system (Uber/Lyft model)
- Refund processing
- Platform fee calculations

**Key Test Cases:**
```dart
// Escrow flow
test('should create escrow record with correct calculations')
test('should update escrow to funded status')
test('should release escrow and create payout record')
test('should handle escrow dispute')

// Payment status
test('PaymentStatus enum should have all required statuses')
test('should update payment status')

// Refunds
test('should create refund record')
test('should update refund status to completed')
```

### 3. Booking Flow Tests (`booking_flow_test.dart`)

**Coverage:**
- Booking creation
- Status transitions (pending → accepted → confirmed → completed)
- Cancellation with refund calculations
- Cart management
- Package selection
- Date/time scheduling

**Key Test Cases:**
```dart
// Status transitions
test('should transition from pending to accepted')
test('should track full booking lifecycle')

// Cancellation
test('should calculate refund based on cancellation policy')
test('should create cancellation record')

// Cart
test('should add item to cart')
test('should calculate cart total with multiple items')
```

### 4. Chat Tests (`chat_service_test.dart`)

**Coverage:**
- Conversation creation
- Message sending (text, image, file)
- Read receipts
- Typing indicators
- Contact detection (anti-fraud)
- Response rate calculation

**Key Test Cases:**
```dart
// Messages
test('should send text message')
test('should send image message')
test('should mark all messages as read')

// Contact detection
test('should detect phone number in message')
test('should detect email in message')
test('should flag message with contact info')

// Response rate
test('should calculate response rate from conversations')
test('should track quick response rate')
```

### 5. Supplier Management Tests (`supplier_management_test.dart`)

**Coverage:**
- Profile creation and updates
- Package management
- Portfolio/gallery
- Working hours and availability
- Verification and badges
- Tier system

**Key Test Cases:**
```dart
// Profile
test('should create supplier profile with all required fields')

// Packages
test('should create package with pricing and features')
test('should get packages ordered by position')

// Badges
test('should earn expert badge based on performance')
test('should earn fast responder badge')

// Tiers
test('should calculate tier based on revenue')
test('should update supplier tier')
```

### 6. Safety Score Tests (`safety_score_test.dart`)

**Coverage:**
- Overall score calculation
- Profile completeness
- Verification status
- Response rate
- Rating score with review weight
- Cancellation score
- Account age score
- Badge eligibility

**Key Test Cases:**
```dart
// Score calculation
test('should calculate safety score with all components')

// Components
test('should calculate profile completeness score')
test('should convert rating to normalized score')
test('should calculate cancellation score')

// Badges
test('should check expert badge eligibility (top 5% in category)')
test('should check fast responder badge eligibility')
```

### 7. Deep Link Tests (`deep_link_service_test.dart`)

**Coverage:**
- Payment callbacks
- Supplier profile links
- Booking links
- Category links
- Referral system

**Key Test Cases:**
```dart
// Payment links
test('should generate payment success URL')
test('should parse payment success deep link')

// Referral
test('should store referral code in SharedPreferences')
test('should expire referral code after 30 days')
test('should apply referral code and credit referrer')
```

### 8. Video Thumbnail Tests (`video_thumbnail_service_test.dart`)

**Coverage:**
- YouTube thumbnail extraction
- Vimeo thumbnail extraction
- Platform detection
- Cache management
- Placeholder generation

**Key Test Cases:**
```dart
// YouTube
test('should extract YouTube video ID from standard URL')
test('should generate YouTube thumbnail URL')

// Vimeo
test('should extract Vimeo video ID from standard URL')

// Cache
test('should cache thumbnail URL in Firestore')
test('should detect expired cache')
```

### 9. Platform Settings Tests (`platform_settings_test.dart`)

**Coverage:**
- Support contact settings
- Commission settings
- Maintenance mode
- Feature flags
- App version requirements

**Key Test Cases:**
```dart
// Support contact
test('should update support email')
test('should generate WhatsApp link')

// Commission
test('should validate commission percentage bounds')
test('should store tier-based commission rates')

// Maintenance
test('should enable maintenance mode')
test('should check if maintenance is scheduled to end')
```

### 10. Integration Tests (`app_integration_test.dart`)

**Coverage:**
- Complete client flow (browse → book → pay → complete)
- Complete supplier flow (register → setup → accept → deliver)
- Chat and booking integration
- Payment and escrow flow
- Referral system flow

**Key Test Cases:**
```dart
// Client flow
test('Client: Browse suppliers -> Select package -> Create booking')
test('Client: Booking acceptance -> Payment -> Escrow funded')
test('Client: Service completion -> Escrow release -> Review')

// Supplier flow
test('Supplier: Registration -> Profile setup -> Package creation')
test('Supplier: Receive booking -> Accept -> Complete -> Get paid')

// Integration
test('Chat initiated -> Booking created -> Chat continues')
test('Full payment flow: Create -> Pay -> Fund -> Release')
```

## Test Data

### Mock User Data
```dart
MockData.testUserId       // 'test-user-id'
MockData.testSupplierId   // 'test-supplier-id'
MockData.testPackageId    // 'test-package-id'
MockData.testBookingId    // 'test-booking-id'
MockData.testChatId       // 'test-chat-id'
```

### Test Phone Numbers
- Angola: `+244912345678`
- Portugal: `+351912345678`

### Test Amounts (AOA)
- Basic package: 50,000 Kz
- Premium package: 100,000 Kz
- Diamante package: 150,000 Kz

## Writing New Tests

### 1. Create Test File
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Feature Name Tests', () {
    test('should do something specific', () async {
      // Arrange
      await fakeFirestore.collection('items').add({...});

      // Act
      final result = await fakeFirestore.collection('items').get();

      // Assert
      expect(result.docs.length, 1);
    });
  });
}
```

### 2. Use Existing Helpers
```dart
import '../docs/helpers/test_helpers.dart';
import '../docs/helpers/mock_services.dart';

// Create fake Firestore
final fakeFirestore = createFakeFirestore();

// Create mock auth
final mockAuth = createMockAuth(signedIn: true);

// Setup SharedPreferences
await setupTestSharedPreferences(values: {'key': 'value'});
```

### 3. Test Async Operations
```dart
test('should handle async operation', () async {
  // Use await for async operations
  final result = await someAsyncFunction();
  expect(result, isNotNull);
});
```

### 4. Test Streams
```dart
test('should emit correct values', () {
  expectLater(
    stream,
    emitsInOrder([value1, value2, value3]),
  );
});
```

## Continuous Integration

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
```

## Coverage Goals

| Component | Target Coverage |
|-----------|-----------------|
| Core Services | 80% |
| Repositories | 75% |
| Models | 90% |
| Utils | 85% |
| Features | 70% |
| **Overall** | **75%** |

## Troubleshooting

### Common Issues

1. **Firebase not initialized**
   - Use `fake_cloud_firestore` instead of real Firestore
   - Don't call `Firebase.initializeApp()` in tests

2. **Async test timeout**
   - Increase timeout: `timeout: Timeout(Duration(seconds: 30))`
   - Use `await` properly

3. **SharedPreferences error**
   - Call `SharedPreferences.setMockInitialValues({})` in setUp

4. **Widget test issues**
   - Use `pumpApp` helper from `pump_app.dart`
   - Wrap widgets in `MaterialApp` and `ProviderScope`

## Contact

For questions about tests, contact the development team.
