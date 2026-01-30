# Booking Domain Layer - Quick Reference

A concise guide to the Booking domain layer components and their usage.

## Quick Import

```dart
// Import everything from the domain layer
import 'package:boda_connect/features/booking/domain/booking_domain.dart';
```

---

## Entities

### BookingEntity

```dart
final booking = BookingEntity(
  id: 'booking_123',
  clientId: 'client_456',
  supplierId: 'supplier_789',
  packageId: 'package_012',
  eventName: 'Casamento Maria & João',
  eventDate: DateTime(2024, 6, 15),
  status: BookingStatus.pending,
  totalAmount: 50000000, // 500,000.00 AOA
  paidAmount: 0,
  currency: 'AOA',
  payments: [],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// Getters
booking.remainingAmount; // int: Amount still owed
booking.isPaid;          // bool: Fully paid?
booking.canCancel;       // bool: Can be cancelled?
booking.isActive;        // bool: Currently active?
```

### BookingStatus

```dart
enum BookingStatus {
  pending,      // Created, not confirmed
  confirmed,    // Supplier accepted
  inProgress,   // Event happening
  completed,    // Finished
  cancelled,    // Cancelled
  refunded,     // Refunded
}

// Usage
status.displayName;       // String: "Confirmado"
status.canBeCancelled;    // bool
status.canBeModified;     // bool
status.isFinal;           // bool
status.isActive;          // bool
```

---

## Value Objects

### Money

```dart
// Creation
final price = Money(amount: 50000000);              // 500k AOA
final deposit = Money.fromDecimal(150000.00);       // From decimal
final zero = Money.zero();                          // Zero amount

// Arithmetic
final total = price + deposit;
final remaining = total - price;
final doubled = price * 2;
final half = price / 2;

// Comparison
if (deposit >= price * 0.30) { /* ... */ }

// Formatting
price.format();              // "500000.00 AOA"
price.formatCompact();       // "500.0K AOA"

// Properties
price.isZero;                // bool
price.isPositive;            // bool
price.isNegative;            // bool
price.toDecimal();           // 500000.00
```

### PaymentStatus

```dart
// Creation
final status = PaymentStatus(
  totalAmount: Money(amount: 100000),
  paidAmount: Money(amount: 30000),
);

final unpaid = PaymentStatus.unpaid(Money(amount: 100000));
final paid = PaymentStatus.fullyPaid(Money(amount: 100000));

// Properties
status.remainingAmount;           // Money
status.isFullyPaid;               // bool
status.isPartiallyPaid;           // bool
status.completionPercentage;      // double (0-100)
status.statusText;                // "Parcialmente Pago"

// Operations
final updated = status.recordPayment(Money(amount: 20000));
final depositNeeded = status.minimumPaymentForPercentage(30.0);
```

### BookingDate

```dart
// Creation
final date = BookingDate(
  eventDate: DateTime(2024, 12, 25),
  eventTime: "14:00",
);

final today = BookingDate.today();

// Properties
date.isPast;                      // bool
date.isToday;                     // bool
date.isTomorrow;                  // bool
date.isFuture;                    // bool
date.daysUntilEvent;              // int

// Validation
date.isValidForBooking(minimumAdvanceDays: 7);
date.isWithinCancellationPeriod(minimumDays: 7);

// Formatting
date.formatDate();                // "25 de Dezembro, 2024"
date.formatDateShort();           // "25/12/2024"
date.formatDateTime();            // "25/12/2024 às 14:00"
date.getRelativeDescription();    // "Em 45 dias"
```

---

## Use Cases

All use cases return `ResultFuture<T>` (Either<Failure, T>)

### CreateBooking

```dart
final useCase = CreateBooking(repository);
final result = await useCase(bookingEntity);
```

### GetBookings (Flexible)

```dart
final useCase = GetBookings(repository);

// Client bookings
final params1 = GetBookingsParams(clientId: 'client_123');
final result1 = await useCase(params1);

// Supplier confirmed bookings
final params2 = GetBookingsParams(
  supplierId: 'supplier_456',
  status: BookingStatus.confirmed,
);
final result2 = await useCase(params2);
```

### GetClientBookings

```dart
final useCase = GetClientBookings(repository);
final params = GetClientBookingsParams(
  clientId: 'client_123',
  status: BookingStatus.pending,
);
final result = await useCase(params);
```

### GetSupplierBookings

```dart
final useCase = GetSupplierBookings(repository);
final params = GetSupplierBookingsParams(
  supplierId: 'supplier_456',
);
final result = await useCase(params);
```

### GetBookingById

```dart
final useCase = GetBookingById(repository);
final result = await useCase('booking_123');
```

### CancelBooking

```dart
final useCase = CancelBooking(repository);
final params = CancelBookingParams(
  bookingId: 'booking_123',
  cancelledBy: 'client_456',
  reason: 'Mudança de planos',
);
final result = await useCase(params);
```

### UpdateBookingStatus

```dart
final useCase = UpdateBookingStatus(repository);
final params = UpdateBookingStatusParams(
  bookingId: 'booking_123',
  newStatus: BookingStatus.confirmed,
  userId: 'supplier_789',
);
final result = await useCase(params);
```

### CheckAvailability

```dart
final useCase = CheckAvailability(repository);
final params = CheckAvailabilityParams(
  supplierId: 'supplier_789',
  date: DateTime(2024, 12, 25),
  excludeBookingId: 'current_booking', // Optional
);
final result = await useCase(params);
```

---

## Domain Service

### BookingDomainService

```dart
final service = BookingDomainService();

// Refund calculations
final refund = service.calculateRefundAmount(booking);
final penalty = service.calculateCancellationPenalty(booking);

// Auto-confirmation check
if (service.shouldAutoConfirm(booking)) { /* ... */ }

// Payment calculations
final deposit = service.calculateSuggestedDeposit(booking);
final final = service.calculateFinalPayment(booking);

// Risk assessment
if (service.isAtRiskOfCancellation(booking)) { /* ... */ }

// Payment schedule
final schedule = service.generatePaymentSchedule(booking);

// Commission calculations
final commission = service.calculatePlatformCommission(booking);
final earnings = service.calculateSupplierEarnings(booking);

// Urgency
final level = service.calculateUrgencyLevel(booking);
final label = service.getUrgencyLabel(level);

// Status validation
final isValid = service.isValidStatusTransition(
  currentStatus: BookingStatus.pending,
  newStatus: BookingStatus.confirmed,
);

// Priority comparison
bookings.sort((a, b) => service.compareByPriority(a, b));
```

---

## Error Handling Pattern

```dart
final result = await useCase(params);

result.fold(
  // Left: Failure
  (failure) {
    if (failure is ValidationFailure) {
      print('Validation error: ${failure.message}');
    } else if (failure is ServerFailure) {
      print('Server error: ${failure.message}');
    }
  },
  // Right: Success
  (data) {
    print('Success: $data');
  },
);
```

---

## Common Patterns

### Create Booking with Validation

```dart
// 1. Validate date
final bookingDate = BookingDate(eventDate: proposedDate);
if (!bookingDate.isValidForBooking(minimumAdvanceDays: 7)) {
  return Left(ValidationFailure('Date too soon'));
}

// 2. Check availability
final availParams = CheckAvailabilityParams(
  supplierId: supplierId,
  date: proposedDate,
);
final availResult = await checkAvailability(availParams);

final isAvailable = availResult.fold(
  (failure) => false,
  (available) => available,
);

if (!isAvailable) {
  return Left(ValidationFailure('Supplier not available'));
}

// 3. Create booking
final booking = BookingEntity(/* ... */);
return await createBooking(booking);
```

### Process Payment

```dart
// 1. Get current payment status
final status = PaymentStatus(
  totalAmount: Money(amount: booking.totalAmount),
  paidAmount: Money(amount: booking.paidAmount),
);

// 2. Validate payment
final payment = Money(amount: paymentAmount);
if (!status.canPayAmount(payment)) {
  return Left(ValidationFailure('Invalid payment amount'));
}

// 3. Check minimum deposit (30%)
final minDeposit = status.minimumPaymentForPercentage(30.0);
if (payment < minDeposit && status.isUnpaid) {
  return Left(ValidationFailure('Minimum 30% deposit required'));
}

// 4. Record payment
final paymentEntity = BookingPaymentEntity(
  id: generateId(),
  amount: payment.amount,
  method: 'transfer',
  paidAt: DateTime.now(),
);

return await addPayment(
  bookingId: booking.id,
  payment: paymentEntity,
);
```

### Handle Cancellation

```dart
// 1. Validate cancellation is allowed
final bookingDate = BookingDate(eventDate: booking.eventDate);
if (!bookingDate.isWithinCancellationPeriod(minimumDays: 7)) {
  return Left(ValidationFailure('Too late to cancel'));
}

if (!booking.canCancel) {
  return Left(ValidationFailure('Booking cannot be cancelled'));
}

// 2. Calculate refund
final service = BookingDomainService();
final refund = service.calculateRefundAmount(booking);

// 3. Cancel booking
final params = CancelBookingParams(
  bookingId: booking.id,
  cancelledBy: userId,
  reason: reason,
);

final result = await cancelBooking(params);

// 4. Process refund if applicable
return result.map((cancelled) {
  if (refund.isPositive) {
    // Process refund through payment gateway
  }
  return cancelled;
});
```

---

## Testing Examples

```dart
// Mock repository
class MockBookingRepository extends Mock implements BookingRepository {}

// Test use case
test('CreateBooking should create booking', () async {
  // Arrange
  final mockRepo = MockBookingRepository();
  final useCase = CreateBooking(mockRepo);
  final booking = BookingEntity(/* ... */);

  when(() => mockRepo.createBooking(booking))
      .thenAnswer((_) async => Right(booking));

  // Act
  final result = await useCase(booking);

  // Assert
  expect(result.isRight(), true);
  verify(() => mockRepo.createBooking(booking)).called(1);
});

// Test value object
test('Money should add correctly', () {
  // Arrange
  final a = Money(amount: 10000);
  final b = Money(amount: 5000);

  // Act
  final result = a + b;

  // Assert
  expect(result.amount, 15000);
});

// Test domain service
test('Should calculate 100% refund for >30 days', () {
  // Arrange
  final service = BookingDomainService();
  final booking = BookingEntity(
    // ... 45 days in future
    eventDate: DateTime.now().add(Duration(days: 45)),
    paidAmount: 100000,
  );

  // Act
  final refund = service.calculateRefundAmount(booking);

  // Assert
  expect(refund.amount, 100000);
});
```

---

## File Structure Reference

```
domain/
├── entities/
│   ├── booking_entity.dart
│   └── booking_status.dart
├── repositories/
│   └── booking_repository.dart
├── usecases/
│   ├── create_booking.dart
│   ├── get_bookings.dart
│   ├── get_booking_by_id.dart
│   ├── get_client_bookings.dart
│   ├── get_supplier_bookings.dart
│   ├── cancel_booking.dart
│   ├── update_booking_status.dart
│   └── check_availability.dart
├── value_objects/
│   ├── money.dart
│   ├── payment_status.dart
│   └── booking_date.dart
├── services/
│   └── booking_domain_service.dart
├── booking_domain.dart (barrel file)
├── README.md
├── EXAMPLES.md
└── QUICK_REFERENCE.md (this file)
```

---

## Dependencies

```yaml
dependencies:
  equatable: ^2.0.5    # Value equality
  dartz: ^0.10.1       # Functional programming (Either)
```

---

**Tip**: Always import from the barrel file for convenience:
```dart
import 'package:boda_connect/features/booking/domain/booking_domain.dart';
```

