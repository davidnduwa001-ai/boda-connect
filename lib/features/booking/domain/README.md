# Booking Domain Layer

This directory contains the **Domain Layer** for the Booking feature, following **Clean Architecture** and **Domain-Driven Design (DDD)** principles.

## Overview

The domain layer is the **core** of the application. It contains:
- Pure business logic
- Entity definitions
- Repository interfaces
- Use cases
- Value objects

**Important**: This layer has **NO dependencies** on:
- Firebase or any external database
- UI frameworks (Flutter widgets)
- Third-party libraries (except utilities like Equatable and Dartz)

## Directory Structure

```
domain/
├── entities/                    # Core domain entities
│   ├── booking_entity.dart     # Main booking entity
│   └── booking_status.dart     # Booking status enum
├── repositories/                # Repository interfaces
│   └── booking_repository.dart # Abstract booking repository
├── usecases/                    # Business use cases
│   ├── create_booking.dart     # Create new booking
│   ├── get_bookings.dart       # Get bookings (flexible)
│   ├── get_booking_by_id.dart  # Get specific booking
│   ├── get_client_bookings.dart # Get client's bookings
│   ├── get_supplier_bookings.dart # Get supplier's bookings
│   ├── cancel_booking.dart     # Cancel a booking
│   ├── update_booking_status.dart # Update booking status
│   └── check_availability.dart # Check supplier availability
├── value_objects/               # Domain value objects
│   ├── money.dart              # Money value object
│   ├── payment_status.dart     # Payment status value object
│   └── booking_date.dart       # Booking date value object
├── booking_domain.dart          # Barrel file for exports
└── README.md                    # This file
```

## Entities

### BookingEntity

The main entity representing a booking/reservation in the system.

**Key Properties:**
- `id`: Unique identifier
- `clientId`: ID of the client making the booking
- `supplierId`: ID of the service provider
- `packageId`: ID of the booked package
- `eventDate`: When the event will occur
- `status`: Current booking status
- `totalAmount`: Total price to be paid
- `paidAmount`: Amount already paid
- `payments`: List of payment transactions

**Business Methods:**
- `remainingAmount`: Calculate amount still owed
- `isPaid`: Check if fully paid
- `canCancel`: Check if cancellation is allowed
- `canModify`: Check if modification is allowed
- `isActive`: Check if booking is active

### BookingStatus (Enum)

Represents the lifecycle states of a booking:

- `pending`: Created but not confirmed
- `confirmed`: Accepted by supplier
- `inProgress`: Event is happening
- `completed`: Successfully completed
- `cancelled`: Cancelled by either party
- `refunded`: Payment returned to client

**Extension Methods:**
- `displayName`: Localized display text (Portuguese)
- `canBeCancelled`: Whether this status allows cancellation
- `canBeModified`: Whether this status allows modification
- `isFinal`: Whether this is a terminal state
- `isActive`: Whether the booking is currently active

### BookingPaymentEntity

Sub-entity representing a payment transaction:

- `id`: Payment identifier
- `amount`: Payment amount
- `method`: Payment method (cash, transfer, card)
- `reference`: Transaction reference
- `paidAt`: Payment timestamp
- `notes`: Additional payment notes

## Value Objects

Value objects encapsulate domain concepts with validation and behavior.

### Money

Represents monetary values consistently across the application.

**Features:**
- Stores amount in smallest unit (centimos for AOA)
- Prevents currency mixing
- Arithmetic operations (+, -, *, /)
- Comparison operations (>, <, >=, <=)
- Formatting methods

**Example:**
```dart
// Create money
final price = Money(amount: 50000, currency: 'AOA'); // 500.00 AOA
final deposit = Money.fromDecimal(150.00); // 150.00 AOA

// Operations
final total = price + deposit; // 650.00 AOA
final remaining = total - price; // 150.00 AOA

// Formatting
print(price.format()); // "500.00 AOA"
print(total.formatCompact()); // "650.00 AOA" or "6.5K AOA" for larger amounts

// Comparison
if (deposit >= price * 0.3) {
  print('Deposit requirement met');
}
```

### PaymentStatus

Encapsulates payment state and calculations.

**Features:**
- Tracks total and paid amounts
- Calculates remaining balance
- Determines payment completion percentage
- Validates payment operations

**Example:**
```dart
// Create payment status
final status = PaymentStatus.unpaid(
  Money(amount: 100000, currency: 'AOA')
);

// Record payment
final updated = status.recordPayment(
  Money(amount: 30000, currency: 'AOA')
);

// Check status
print(updated.isPartiallyPaid); // true
print(updated.completionPercentage); // 30.0
print(updated.statusText); // "Parcialmente Pago"
print(updated.remainingAmount.format()); // "700.00 AOA"

// Calculate deposit requirement
final depositNeeded = status.minimumPaymentForPercentage(30.0);
print(depositNeeded.format()); // "300.00 AOA"
```

### BookingDate

Represents event dates with validation and utilities.

**Features:**
- Date validation
- Relative date calculations
- Cancellation period checks
- Localized formatting

**Example:**
```dart
// Create booking date
final date = BookingDate(
  eventDate: DateTime(2024, 12, 25),
  eventTime: "14:00",
);

// Check properties
print(date.isFuture); // true
print(date.daysUntilEvent); // 45
print(date.isWithinCancellationPeriod(minimumDays: 7)); // true

// Format
print(date.formatDate()); // "25 de Dezembro, 2024"
print(date.formatDateTime()); // "25/12/2024 às 14:00"
print(date.getRelativeDescription()); // "Em 45 dias"

// Validation
if (date.isValidForBooking(minimumAdvanceDays: 3)) {
  print('Date is valid for new booking');
}
```

## Repository Interface

### BookingRepository

Abstract interface defining all booking data operations.

**Methods:**

**CRUD Operations:**
- `createBooking(BookingEntity)`: Create new booking
- `getBookingById(String)`: Get specific booking
- `updateBooking(String, Map)`: Update booking details
- `updateBookingStatus(String, BookingStatus, String)`: Change status
- `cancelBooking(String, String, String?)`: Cancel booking

**Query Operations:**
- `getClientBookings(String, {BookingStatus?})`: Get client's bookings
- `getSupplierBookings(String, {BookingStatus?})`: Get supplier's bookings
- `checkAvailability(String, DateTime, {String?})`: Check supplier availability

**Payment Operations:**
- `addPayment(String, BookingPaymentEntity)`: Record payment

**Real-time Streams:**
- `streamClientBookings(String)`: Stream client bookings
- `streamSupplierBookings(String)`: Stream supplier bookings
- `streamBooking(String)`: Stream specific booking

## Use Cases

Use cases encapsulate business operations. Each use case:
- Has a single responsibility
- Contains business validation logic
- Returns `ResultFuture<T>` (Either Failure or Success)
- Is independent and testable

### CreateBooking

Creates a new booking in the system.

**Example:**
```dart
final useCase = CreateBooking(repository);

final booking = BookingEntity(
  id: 'booking123',
  clientId: 'client456',
  supplierId: 'supplier789',
  packageId: 'package012',
  eventName: 'Casamento Maria & João',
  eventDate: DateTime(2024, 12, 25),
  status: BookingStatus.pending,
  totalAmount: 100000,
  paidAmount: 0,
  currency: 'AOA',
  payments: [],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final result = await useCase(booking);
result.fold(
  (failure) => print('Error: ${failure.message}'),
  (created) => print('Booking created: ${created.id}'),
);
```

### GetBookings

Flexible use case to get bookings for either clients or suppliers.

**Example:**
```dart
final useCase = GetBookings(repository);

// Get all client bookings
final clientParams = GetBookingsParams(clientId: 'client123');
final result1 = await useCase(clientParams);

// Get confirmed supplier bookings
final supplierParams = GetBookingsParams(
  supplierId: 'supplier456',
  status: BookingStatus.confirmed,
);
final result2 = await useCase(supplierParams);
```

### GetClientBookings / GetSupplierBookings

Specific use cases for getting bookings by user type.

**Example:**
```dart
final useCase = GetClientBookings(repository);

final params = GetClientBookingsParams(
  clientId: 'client123',
  status: BookingStatus.confirmed,
);

final result = await useCase(params);
result.fold(
  (failure) => print('Error: ${failure.message}'),
  (bookings) => print('Found ${bookings.length} confirmed bookings'),
);
```

### CancelBooking

Cancels a booking with reason tracking.

**Example:**
```dart
final useCase = CancelBooking(repository);

final params = CancelBookingParams(
  bookingId: 'booking123',
  cancelledBy: 'client456',
  reason: 'Cliente mudou de planos',
);

final result = await useCase(params);
result.fold(
  (failure) => print('Error: ${failure.message}'),
  (cancelled) => print('Booking cancelled at: ${cancelled.cancelledAt}'),
);
```

### UpdateBookingStatus

Updates the status of a booking.

**Example:**
```dart
final useCase = UpdateBookingStatus(repository);

final params = UpdateBookingStatusParams(
  bookingId: 'booking123',
  newStatus: BookingStatus.confirmed,
  userId: 'supplier789',
);

final result = await useCase(params);
result.fold(
  (failure) => print('Error: ${failure.message}'),
  (updated) => print('Status updated to: ${updated.status.displayName}'),
);
```

### CheckAvailability

Checks if a supplier is available on a specific date.

**Example:**
```dart
final useCase = CheckAvailability(repository);

final params = CheckAvailabilityParams(
  supplierId: 'supplier789',
  date: DateTime(2024, 12, 25),
  excludeBookingId: 'booking123', // Optional: exclude current booking
);

final result = await useCase(params);
result.fold(
  (failure) => print('Error: ${failure.message}'),
  (isAvailable) => print('Supplier available: $isAvailable'),
);
```

## Clean Architecture Principles

### Dependency Rule

The domain layer is at the center and depends on nothing:

```
Presentation Layer (UI)
    ↓ depends on
Data Layer (Repository Implementation)
    ↓ depends on
Domain Layer (Entities, Use Cases, Interfaces)
    ↓ depends on
Nothing (pure business logic)
```

### Testability

All use cases and entities can be tested in isolation:

```dart
// Example test
test('CreateBooking should validate booking date', () async {
  // Arrange
  final mockRepo = MockBookingRepository();
  final useCase = CreateBooking(mockRepo);
  final booking = BookingEntity(...); // with past date

  // Act
  final result = await useCase(booking);

  // Assert
  expect(result.isLeft(), true); // Should return failure
});
```

### Separation of Concerns

- **Entities**: Define what a booking *is*
- **Value Objects**: Encapsulate domain concepts
- **Use Cases**: Define what you can *do* with bookings
- **Repository Interface**: Define *how* to access bookings (without implementation details)

## Error Handling

All operations return `ResultFuture<T>` which is:
```dart
typedef ResultFuture<T> = Future<Either<Failure, T>>;
```

This allows for:
- Type-safe error handling
- No exceptions in business logic
- Clear success/failure paths

**Example:**
```dart
final result = await useCase(params);

result.fold(
  (failure) {
    // Handle failure
    if (failure is ServerFailure) {
      print('Server error: ${failure.message}');
    } else if (failure is ValidationFailure) {
      print('Validation error: ${failure.message}');
    }
  },
  (success) {
    // Handle success
    print('Operation successful: $success');
  },
);
```

## Best Practices

1. **Immutability**: All entities and value objects are immutable
2. **Value Equality**: Use Equatable for value-based equality
3. **No Side Effects**: Pure functions with no hidden state changes
4. **Single Responsibility**: Each use case does one thing
5. **Interface Segregation**: Repository interface is focused and cohesive
6. **Dependency Inversion**: Depend on abstractions (interfaces), not implementations

## Integration with Other Layers

### Data Layer Integration

The data layer implements the repository interface:

```dart
class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource remoteDataSource;

  @override
  ResultFuture<BookingEntity> createBooking(BookingEntity booking) async {
    try {
      // Convert entity to model
      final model = BookingModel.fromEntity(booking);
      // Save to Firebase
      final created = await remoteDataSource.createBooking(model);
      // Convert back to entity
      return Right(created.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ... other implementations
}
```

### Presentation Layer Integration

The presentation layer uses use cases via providers:

```dart
class BookingProvider extends ChangeNotifier {
  final CreateBooking _createBooking;
  final GetClientBookings _getClientBookings;

  Future<void> createNewBooking(BookingEntity booking) async {
    final result = await _createBooking(booking);
    result.fold(
      (failure) => _handleError(failure),
      (created) => _handleSuccess(created),
    );
  }
}
```

## Future Enhancements

Potential additions to the domain layer:

1. **Domain Events**: For publish/subscribe patterns
2. **Specifications**: For complex query logic
3. **Aggregates**: For complex entity relationships
4. **Domain Services**: For operations spanning multiple entities
5. **Value Object Validation**: More sophisticated validation rules

## Related Documentation

- [Clean Architecture Guide](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [Equatable Package](https://pub.dev/packages/equatable)
- [Dartz Package](https://pub.dev/packages/dartz)

---

**Last Updated**: January 2026
**Maintainer**: Development Team
