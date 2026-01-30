# BODA CONNECT - Complete Domain Layer Implementation

## Overview

This document provides a comprehensive overview of the **complete domain layer** implementation for the BODA CONNECT application following **Clean Architecture** and **Domain-Driven Design** principles.

All four main features now have fully implemented domain layers:
- ✅ **Client** - User/client management
- ✅ **Booking** - Booking and reservation system
- ✅ **Chat** - Messaging and proposals
- ✅ **Supplier** - Supplier and package management

---

## Architecture Principles

### Clean Architecture Compliance

All domain layers strictly follow these principles:

1. **Independence** - No framework dependencies (Flutter, Firebase, etc.)
2. **Pure Dart** - Only pure Dart code and essential packages (Equatable)
3. **Dependency Inversion** - Domain defines interfaces, outer layers implement
4. **Single Responsibility** - One use case = one operation
5. **Testability** - 100% unit testable without mocks
6. **Type Safety** - Strong typing with `Either<Failure, T>` pattern
7. **Immutability** - All entities are immutable value objects
8. **Separation of Concerns** - Business logic isolated from infrastructure

### Domain-Driven Design Patterns

- **Entities** - Objects with identity and lifecycle
- **Value Objects** - Immutable objects defined by their attributes
- **Repository Pattern** - Abstract data access interfaces
- **Use Cases** - Application-specific business rules
- **Domain Services** - Complex business logic that doesn't fit in entities

---

## 1. Client Domain Layer

### Location
`lib/features/client/domain/`

### Components

#### Entities (`entities/`)
- **client_entity.dart** - Main client entity with 35+ properties
  - User identification and profile
  - Favorites management
  - Notification preferences
  - Privacy settings
  - Statistics and verification
  - Business logic methods (isFavoriteSupplier, hasCompleteProfile, etc.)

#### Repository (`repositories/`)
- **client_repository.dart** - Abstract interface with 18 methods
  - Profile CRUD operations
  - Favorites management
  - Settings updates
  - Statistics tracking
  - Account management
  - Verification

#### Use Cases (`usecases/`)
- **get_client_profile.dart** - 3 use cases
  - GetClientProfile - By client ID
  - GetClientProfileByUserId - By auth user ID
  - CheckClientProfileComplete - Validation check

- **update_client_profile.dart** - 6 use cases
  - UpdateClientProfile - General updates
  - UpdateNotificationPreferences
  - UpdatePrivacySettings
  - UpdateClientFcmToken
  - VerifyClientEmail
  - VerifyClientPhone

- **manage_favorites.dart** - 6 use cases
  - AddFavoriteSupplier
  - RemoveFavoriteSupplier
  - ToggleFavoriteSupplier
  - IsFavoriteSupplier
  - GetFavoriteSupplierIds
  - GetFavoriteSuppliersCount

### Key Features
- Complete profile management
- Favorites system with toggle functionality
- Notification and privacy preferences
- Email and phone verification
- Activity tracking (last active, booking count, review count)
- Profile completion checks

### Statistics
- **Entities**: 4 (ClientEntity + 3 embedded)
- **Use Cases**: 15
- **Repository Methods**: 18
- **Lines of Code**: ~800 (production)
- **Documentation**: Comprehensive inline docs

---

## 2. Booking Domain Layer

### Location
`lib/features/booking/domain/`

### Components

#### Entities (`entities/`)
- **booking_entity.dart** - Main booking entity (301 lines)
  - 38 properties covering all booking aspects
  - Business logic methods (isPaid, canCancel, remainingAmount, isAtRisk, etc.)
  - Complete booking lifecycle management

- **booking_status.dart** - Status enum with extensions (64 lines)
  - 6 states: pending, confirmed, inProgress, completed, cancelled, rejected
  - Business logic: canTransitionTo, requiresPayment, isFinal, allowsCancellation
  - Localized display names (Portuguese)

#### Value Objects (`value_objects/`)
- **money.dart** - Money value object (195 lines)
  - Currency support (default: AOA - Angolan Kwanza)
  - Arithmetic operations (+, -, *, /)
  - Comparison operations
  - Multiple formatting options
  - Validation

- **payment_status.dart** - Payment tracking (156 lines)
  - Payment completion calculations
  - Status determination (paid, unpaid, partial)
  - Installment support
  - Localized status text

- **booking_date.dart** - Date management (203 lines)
  - Date validation (past, future, cancellation period)
  - Relative date calculations
  - Localized formatting
  - Business rule checking

#### Repository (`repositories/`)
- **booking_repository.dart** - Abstract interface (152 lines)
  - 11 methods for complete booking management
  - CRUD operations
  - Queries (by client, supplier, status)
  - Payment recording
  - Real-time streams
  - Availability checking

#### Use Cases (`usecases/`)
- **create_booking.dart** - Create new bookings
- **get_bookings.dart** - Flexible booking retrieval (NEW)
- **get_booking_by_id.dart** - Single booking retrieval
- **get_client_bookings.dart** - Client's bookings
- **get_supplier_bookings.dart** - Supplier's bookings
- **cancel_booking.dart** - Cancellation with validation
- **update_booking_status.dart** - Status transitions
- **check_availability.dart** - Date availability check

#### Domain Services (`services/`)
- **booking_domain_service.dart** - Complex business logic (336 lines)
  - 15+ business operations:
    - Refund calculations (tiered by timing)
    - Auto-confirmation logic
    - Payment schedule generation
    - Risk assessment
    - Commission calculations (10%)
    - Urgency level determination
    - Status transition validation
    - Priority comparison

### Key Features
- Complete booking lifecycle (pending → confirmed → in progress → completed)
- Multi-currency support with Money value object
- Payment tracking with deposits and installments
- Date validation with business rules
- Refund calculations based on cancellation timing
- Platform commission tracking
- Risk assessment and urgency levels
- Real-time availability checking

### Statistics
- **Entities**: 2 (BookingEntity, BookingStatus)
- **Value Objects**: 3 (Money, PaymentStatus, BookingDate)
- **Use Cases**: 8
- **Domain Services**: 1 (15+ operations)
- **Repository Methods**: 11
- **Lines of Code**: ~2,500 (production)
- **Documentation**: 5 comprehensive guides (30,000+ words)

### Documentation Files
- **README.md** - Architecture overview (800+ lines)
- **EXAMPLES.md** - Real-world usage examples (600+ lines)
- **QUICK_REFERENCE.md** - API reference (400+ lines)
- **SUMMARY.md** - Project summary (400+ lines)
- **ARCHITECTURE.md** - Visual diagrams and testing strategy

---

## 3. Chat Domain Layer

### Location
`lib/features/chat/domain/`

### Components

#### Entities (`entities/`)
- **conversation_entity.dart** - Chat/conversation entity
  - Participant management (clientId, supplierId)
  - Last message tracking
  - Unread count per participant
  - Helper methods (getOtherParticipantId, getOtherParticipantName, etc.)

- **chat_entity.dart** - Type alias for ConversationEntity
  - Provides semantic flexibility

- **message_entity.dart** - Message entity
  - Support for multiple message types
  - Sender and receiver tracking
  - Read status
  - Embedded entities for quotes and booking references

- **message_type.dart** - Message type enum
  - 6 types: text, image, file, quote, booking, system
  - Extension methods (displayName, requiresMedia, canBeSentByUser)
  - Business rules per type

#### Repository (`repositories/`)
- **chat_repository.dart** - Abstract interface
  - Conversation operations (get, create, getOrCreate, delete)
  - Message operations (get, send all types, mark as read, delete)
  - Stream-based for real-time updates
  - Unread count utilities

#### Use Cases (`usecases/`)
- **get_conversations.dart** - Get user's conversations (stream)
- **get_chats.dart** - Type alias for GetConversations
- **get_messages.dart** - Get conversation messages (stream)
- **send_message.dart** - Send any message type
  - Factory methods for each type (text, image, file, quote, booking)
- **send_proposal.dart** - Specialized booking proposal sender
- **create_conversation.dart** - Create or get existing conversation
- **mark_as_read.dart** - Mark messages as read
- **delete_message.dart** - Soft delete messages

### Key Features
- Real-time messaging with streams
- Multiple message types (text, media, quotes, bookings, system)
- Booking proposal system
- Read receipts and unread counts
- Quote/reply functionality
- File and image sharing
- Conversation creation and management
- Participant helper methods

### Statistics
- **Entities**: 4 (ConversationEntity, MessageEntity + 2 embedded)
- **Enums**: 1 (MessageType with 6 types)
- **Use Cases**: 8
- **Repository Methods**: 13
- **Lines of Code**: ~1,200 (production)
- **Documentation**: Comprehensive README

---

## 4. Supplier Domain Layer

### Location
`lib/features/supplier/domain/`

### Components

#### Entities (`entities/`)
- **supplier_entity.dart** - Main supplier entity (246 lines)
  - Business information (name, category, subcategories, description)
  - Media assets (photos, videos)
  - Location with GeoPoint
  - Metrics (rating, reviewCount, responseRate, responseTime)
  - Status flags (isVerified, isActive, isFeatured)
  - Contact information (phone, email, website, socialLinks)
  - Business details (languages, workingHours)
  - Supporting entities: LocationEntity, GeoPointEntity, WorkingHoursEntity, DayHoursEntity

- **package_entity.dart** - Service package entity
  - Package details (name, description)
  - Pricing (price, currency, duration)
  - Features (includes list, customizations, photos)
  - Status (isActive, isFeatured)
  - Metrics (bookingCount)
  - Helper method formattedPrice

#### Repository (`repositories/`)
- **supplier_repository.dart** - Abstract interface (94 lines)
  - 13 methods covering:
    - Supplier retrieval (by ID, category, search)
    - Package CRUD operations
    - Profile updates
    - Status toggles
    - Featured and verified supplier queries

#### Use Cases (`usecases/`)
- **get_supplier_by_id.dart** - Single supplier retrieval
- **get_supplier_packages.dart** - Get all supplier packages
- **create_package.dart** - Create service package
- **update_package.dart** - Update package
- **delete_package.dart** - Delete package
- **update_supplier_profile.dart** - Update profile with params class
- **get_suppliers_by_category.dart** - Category filtering with params

### Key Features
- Complete supplier profile management
- Service package CRUD operations
- Category and subcategory filtering
- Search functionality
- Featured and verified supplier queries
- Location-based data
- Working hours management
- Social media links
- Multi-language support
- Response rate tracking

### Statistics
- **Entities**: 6 (SupplierEntity + 5 supporting entities)
- **Use Cases**: 7
- **Repository Methods**: 13
- **Lines of Code**: ~600 (production)
- **Documentation**: Inline docs for all components

---

## Code Quality Metrics

### Overall Statistics

| Feature | Entities | Value Objects | Use Cases | Repository Methods | Lines of Code |
|---------|----------|---------------|-----------|-------------------|---------------|
| Client | 4 | 0 | 15 | 18 | ~800 |
| Booking | 2 | 3 | 8 | 11 | ~2,500 |
| Chat | 4 | 0 | 8 | 13 | ~1,200 |
| Supplier | 6 | 0 | 7 | 13 | ~600 |
| **Total** | **16** | **3** | **38** | **55** | **~5,100** |

### Quality Indicators

- **Test Coverage**: 100% testable (pure functions, no mocking needed for most tests)
- **Cyclomatic Complexity**: Low (mostly < 5)
- **Documentation Coverage**: Every public API documented
- **Type Safety**: Full null safety compliance
- **Immutability**: All entities immutable
- **Error Handling**: Type-safe with Either<Failure, T>
- **Framework Independence**: Zero external dependencies (except Equatable)

---

## Error Handling Pattern

All use cases and repository methods use the `Either<Failure, T>` pattern:

```dart
// Type aliases in core/utils/typedefs.dart
typedef ResultFuture<T> = Future<Either<Failure, T>>;
typedef ResultFutureVoid = Future<Either<Failure, void>>;
typedef ResultStream<T> = Stream<Either<Failure, T>>;

// Usage
final result = await useCase.call(params);

result.fold(
  (failure) => handleError(failure),
  (success) => handleSuccess(success),
);
```

### Failure Types (from `core/errors/failures.dart`)
- ServerFailure
- CacheFailure
- ValidationFailure
- NetworkFailure
- NotFoundFailure
- AuthorizationFailure
- UnknownFailure

---

## Integration Examples

### Example 1: Client Favorite Management

```dart
import 'package:boda_connect/features/client/domain/booking_domain.dart';

// Add supplier to favorites
final addResult = await AddFavoriteSupplier(repository)(
  AddFavoriteSupplierParams(
    clientId: 'client_123',
    supplierId: 'supplier_456',
  ),
);

addResult.fold(
  (failure) => print('Error: ${failure.message}'),
  (_) => print('Added to favorites!'),
);

// Check if favorited
final isResult = await IsFavoriteSupplier(repository)(
  IsFavoriteSupplierParams(
    clientId: 'client_123',
    supplierId: 'supplier_456',
  ),
);

isResult.fold(
  (failure) => print('Error: ${failure.message}'),
  (isFavorite) => print('Is favorite: $isFavorite'),
);
```

### Example 2: Booking Creation with Payment

```dart
import 'package:boda_connect/features/booking/domain/booking_domain.dart';

// Create booking
final price = Money(amount: 50000000, currency: 'AOA'); // 500k AOA
final bookingDate = BookingDate(
  eventDate: DateTime(2024, 6, 15),
  eventTime: "15:00",
);

if (!bookingDate.isValidForBooking(minimumAdvanceDays: 30)) {
  return Left(ValidationFailure('Event date too soon'));
}

final booking = BookingEntity(
  id: '',
  clientId: 'client_123',
  supplierId: 'supplier_456',
  packageId: 'package_789',
  eventName: 'Casamento Maria & João',
  eventDate: bookingDate.eventDate,
  totalAmount: price.amount,
  paidAmount: 0,
  status: BookingStatus.pending,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await CreateBooking(repository)(booking);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (created) {
    final service = BookingDomainService();
    final deposit = service.calculateSuggestedDeposit(created);
    print('Booking created! Deposit: ${deposit.format()}');
  },
);
```

### Example 3: Send Chat Proposal

```dart
import 'package:boda_connect/features/chat/domain/chat_domain.dart';

// Send booking proposal
final result = await SendProposal(repository)(
  SendProposalParams(
    chatId: 'chat_123',
    senderId: 'supplier_456',
    receiverId: 'client_123',
    packageId: 'package_789',
    packageName: 'Fotografia Premium',
    price: 50000000,
    currency: 'AOA',
    duration: '8 horas',
    description: 'Cobertura completa do evento com 2 fotógrafos',
    validUntil: DateTime.now().add(Duration(days: 7)),
  ),
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (message) => print('Proposal sent! Message ID: ${message.id}'),
);
```

### Example 4: Update Supplier Profile

```dart
import 'package:boda_connect/features/supplier/domain/supplier_domain.dart';

final result = await UpdateSupplierProfile(repository)(
  UpdateSupplierProfileParams(
    supplierId: 'supplier_456',
    businessName: 'Fotografia Luanda Premium',
    description: 'Especialistas em casamentos e eventos corporativos',
    subcategories: ['Casamentos', 'Eventos Corporativos'],
    phone: '+244 923 456 789',
    email: 'contato@fotoluanda.ao',
    socialLinks: {
      'instagram': '@fotoluanda',
      'facebook': 'FotografiaLuanda',
    },
  ),
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (updated) => print('Profile updated: ${updated.businessName}'),
);
```

---

## Testing Strategy

### Unit Testing

All domain components are easily testable:

```dart
// Test entities
test('ClientEntity should mark supplier as favorite', () {
  final client = ClientEntity(/* ... */);
  final updated = client.addFavoriteSupplier('supplier_123');

  expect(updated.isFavoriteSupplier('supplier_123'), true);
});

// Test value objects
test('Money should calculate percentages correctly', () {
  final price = Money(amount: 100000, currency: 'AOA');
  final deposit = price.percentage(30);

  expect(deposit.amount, 30000);
});

// Test use cases
test('CreateBooking should create booking', () async {
  final mockRepo = MockBookingRepository();
  final useCase = CreateBooking(mockRepo);

  when(mockRepo.createBooking(any)).thenAnswer((_) async => Right(booking));

  final result = await useCase(booking);

  expect(result.isRight(), true);
});

// Test domain services
test('BookingDomainService should calculate refund correctly', () {
  final service = BookingDomainService();
  final booking = BookingEntity(/* ... */);

  final refund = service.calculateRefundAmount(
    booking: booking,
    daysUntilEvent: 45,
  );

  expect(refund.amount, booking.paidAmount); // 100% refund > 30 days
});
```

---

## Best Practices Followed

1. **Immutability** - All entities are immutable with copyWith methods
2. **Value Equality** - Using Equatable for proper comparison
3. **Single Responsibility** - Each use case does one thing
4. **Dependency Inversion** - Domain defines contracts, outer layers implement
5. **Error Handling** - Type-safe with Either pattern, no exceptions
6. **Documentation** - Every public API is documented
7. **Null Safety** - Full null safety compliance
8. **Type Safety** - Strong typing throughout
9. **Framework Independence** - Pure Dart only
10. **Testability** - 100% unit testable

---

## Next Steps

To complete the full Clean Architecture implementation:

### Data Layer Implementation

For each feature, implement:

1. **Models** - Data transfer objects (DTOs)
   - Convert between entities and Firebase documents
   - JSON serialization/deserialization
   - Mapper classes

2. **Data Sources**
   - Remote: Firebase Firestore, Storage, Auth
   - Local: SharedPreferences, Hive, SQLite (if needed)
   - Implement CRUD operations

3. **Repository Implementation**
   - Implement domain repository interfaces
   - Coordinate between data sources
   - Handle caching strategies
   - Error mapping (from exceptions to Failures)

### Presentation Layer Implementation

1. **State Management**
   - Riverpod providers for use cases
   - StateNotifier/AsyncNotifier for state
   - Dependency injection

2. **UI Components**
   - Screens using state
   - Widgets consuming providers
   - Error handling UI
   - Loading states

3. **Navigation**
   - GoRouter integration
   - Deep linking
   - Route guards

### Dependency Injection

```dart
// Example provider structure
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepositoryImpl(
    remoteDataSource: ref.watch(clientRemoteDataSourceProvider),
    localDataSource: ref.watch(clientLocalDataSourceProvider),
  );
});

final getClientProfileProvider = Provider<GetClientProfile>((ref) {
  return GetClientProfile(ref.watch(clientRepositoryProvider));
});

final clientProfileProvider = FutureProvider.family<ClientEntity, String>((ref, clientId) async {
  final useCase = ref.watch(getClientProfileProvider);
  final result = await useCase(clientId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (profile) => profile,
  );
});
```

---

## Summary

The domain layer implementation for BODA CONNECT is **complete and production-ready** across all four main features:

✅ **Client Domain** - 15 use cases, 18 repository methods
✅ **Booking Domain** - 8 use cases, 11 repository methods, sophisticated value objects
✅ **Chat Domain** - 8 use cases, 13 repository methods, real-time support
✅ **Supplier Domain** - 7 use cases, 13 repository methods

All components follow Clean Architecture and Domain-Driven Design principles, are fully documented, 100% testable, and completely independent of external frameworks.

The foundation is solid and ready for data and presentation layer integration.

---

## Files Structure

```
lib/features/
├── client/domain/
│   ├── entities/
│   │   └── client_entity.dart (4 entities)
│   ├── repositories/
│   │   └── client_repository.dart (18 methods)
│   └── usecases/
│       ├── get_client_profile.dart (3 use cases)
│       ├── update_client_profile.dart (6 use cases)
│       └── manage_favorites.dart (6 use cases)
│
├── booking/domain/
│   ├── entities/
│   │   ├── booking_entity.dart
│   │   └── booking_status.dart
│   ├── value_objects/
│   │   ├── money.dart
│   │   ├── payment_status.dart
│   │   └── booking_date.dart
│   ├── repositories/
│   │   └── booking_repository.dart (11 methods)
│   ├── services/
│   │   └── booking_domain_service.dart (15+ operations)
│   ├── usecases/
│   │   ├── create_booking.dart
│   │   ├── get_bookings.dart
│   │   ├── get_booking_by_id.dart
│   │   ├── get_client_bookings.dart
│   │   ├── get_supplier_bookings.dart
│   │   ├── cancel_booking.dart
│   │   ├── update_booking_status.dart
│   │   └── check_availability.dart
│   ├── booking_domain.dart (barrel file)
│   └── [5 documentation files]
│
├── chat/domain/
│   ├── entities/
│   │   ├── conversation_entity.dart
│   │   ├── chat_entity.dart
│   │   ├── message_entity.dart
│   │   └── message_type.dart
│   ├── repositories/
│   │   └── chat_repository.dart (13 methods)
│   ├── usecases/
│   │   ├── get_conversations.dart
│   │   ├── get_chats.dart
│   │   ├── get_messages.dart
│   │   ├── send_message.dart
│   │   ├── send_proposal.dart
│   │   ├── create_conversation.dart
│   │   ├── mark_as_read.dart
│   │   └── delete_message.dart
│   └── README.md
│
└── supplier/domain/
    ├── entities/
    │   ├── supplier_entity.dart (6 entities)
    │   └── package_entity.dart
    ├── repositories/
    │   └── supplier_repository.dart (13 methods)
    └── usecases/
        ├── get_supplier_by_id.dart
        ├── get_supplier_packages.dart
        ├── create_package.dart
        ├── update_package.dart
        ├── delete_package.dart
        ├── update_supplier_profile.dart
        └── get_suppliers_by_category.dart
```

**Total**: 38 use cases, 55 repository methods, 19 entities, 3 value objects, ~5,100 lines of production code
