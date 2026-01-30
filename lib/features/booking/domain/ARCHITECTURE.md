# Booking Domain Layer - Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        BOOKING DOMAIN LAYER                         │
│                     (Clean Architecture Core)                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER (UI)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   Screens    │  │   Widgets    │  │  Providers   │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────────────┐
│                      DATA LAYER (Infrastructure)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │ Repository   │  │ Data Sources │  │    Models    │             │
│  │ Implementation│  │  (Firebase)  │  │              │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────────────┐
│                       DOMAIN LAYER (Business Logic)                 │
│                                                                     │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐       │
│  │   Entities     │  │  Value Objects │  │   Use Cases    │       │
│  │                │  │                │  │                │       │
│  │ BookingEntity  │  │ Money          │  │ CreateBooking  │       │
│  │ BookingStatus  │  │ PaymentStatus  │  │ GetBookings    │       │
│  │ PaymentEntity  │  │ BookingDate    │  │ CancelBooking  │       │
│  └────────────────┘  └────────────────┘  └────────────────┘       │
│                                                                     │
│  ┌────────────────┐  ┌────────────────┐                            │
│  │  Repository    │  │ Domain Service │                            │
│  │  Interface     │  │                │                            │
│  │                │  │ Booking        │                            │
│  │ (Abstract)     │  │ DomainService  │                            │
│  └────────────────┘  └────────────────┘                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────────────┐
│                        CORE UTILITIES                               │
│                                                                     │
│         Either<Failure, T>    •    Equatable    •    Dartz         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Domain Component Relationships

```
                    ┌─────────────────────────────────┐
                    │       Use Cases (8)             │
                    │                                 │
                    │  • CreateBooking                │
                    │  • GetBookings                  │
                    │  • GetBookingById               │
                    │  • GetClientBookings            │
                    │  • GetSupplierBookings          │
                    │  • CancelBooking                │
                    │  • UpdateBookingStatus          │
                    │  • CheckAvailability            │
                    │                                 │
                    └────────────┬────────────────────┘
                                 │ uses
                                 ↓
                    ┌─────────────────────────────────┐
                    │  Repository Interface           │
                    │  (BookingRepository)            │
                    │                                 │
                    │  11 abstract methods            │
                    └─────────────────────────────────┘
                                 ↑
                                 │ implements
                    ┌────────────┴────────────────────┐
                    │  Data Layer Implementation      │
                    │  (BookingRepositoryImpl)        │
                    └─────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                        Entities & Value Objects                      │
│                                                                     │
│  BookingEntity ──────uses──────→ BookingStatus (enum)              │
│       │                                                             │
│       └──────uses──────→ BookingPaymentEntity                      │
│                                                                     │
│                                                                     │
│  Value Objects (Independent):                                       │
│                                                                     │
│  Money ──────────uses──────→ PaymentStatus                         │
│                                                                     │
│  BookingDate (Independent)                                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                       Domain Service                                │
│                                                                     │
│  BookingDomainService                                               │
│       │                                                             │
│       ├──→ operates on BookingEntity                               │
│       ├──→ uses Money                                              │
│       ├──→ uses PaymentStatus                                      │
│       └──→ uses BookingDate                                        │
│                                                                     │
│  Complex business logic:                                            │
│  • Refund calculations                                              │
│  • Payment schedules                                                │
│  • Risk assessment                                                  │
│  • Commission calculations                                          │
│  • Status validation                                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Creating a Booking

```
User Action (UI)
      ↓
┌─────────────────┐
│  Provider       │  Presentation Layer
│  createBooking()│
└────────┬────────┘
         │ calls
         ↓
┌─────────────────┐
│  CreateBooking  │  Use Case (Domain)
│  (Use Case)     │
└────────┬────────┘
         │ validates & calls
         ↓
┌─────────────────┐
│  Repository     │  Interface (Domain)
│  createBooking()│
└────────┬────────┘
         │ implements
         ↓
┌─────────────────┐
│  Repository     │  Implementation (Data)
│  Impl           │
└────────┬────────┘
         │ converts Entity → Model
         │ saves to Firebase
         │ converts Model → Entity
         ↓
┌─────────────────┐
│  BookingEntity  │  Domain Entity
└─────────────────┘
         │
         ↓ returns Either<Failure, BookingEntity>
         │
      Success/Error to UI
```

### Value Object Usage

```
Domain Service or Use Case needs to handle money:

┌──────────────────┐
│  Use Case        │
└────────┬─────────┘
         │
         │ creates
         ↓
┌──────────────────┐     ┌──────────────────┐
│  Money           │────→│  Operations      │
│  amount: 100000  │     │  + - * /         │
│  currency: 'AOA' │     │  > < >= <=       │
└──────────────────┘     │  format()        │
         ↓               │  formatCompact() │
         │               └──────────────────┘
         │ uses in
         ↓
┌──────────────────┐
│  PaymentStatus   │
│  totalAmount     │
│  paidAmount      │
└────────┬─────────┘
         │
         │ provides business logic
         ↓
    Payment calculations,
    validation, status
```

## File Structure

```
lib/features/booking/domain/
│
├── 📁 entities/
│   ├── 📄 booking_entity.dart         (301 lines) ✅
│   └── 📄 booking_status.dart         (64 lines)  ✅
│
├── 📁 value_objects/
│   ├── 📄 money.dart                  (195 lines) 🆕
│   ├── 📄 payment_status.dart         (156 lines) 🆕
│   └── 📄 booking_date.dart           (203 lines) 🆕
│
├── 📁 repositories/
│   └── 📄 booking_repository.dart     (152 lines) ✅
│
├── 📁 usecases/
│   ├── 📄 create_booking.dart         (34 lines)  ✅
│   ├── 📄 get_bookings.dart           (91 lines)  🆕
│   ├── 📄 get_booking_by_id.dart      (33 lines)  ✅
│   ├── 📄 get_client_bookings.dart    (56 lines)  ✅
│   ├── 📄 get_supplier_bookings.dart  (56 lines)  ✅
│   ├── 📄 cancel_booking.dart         (61 lines)  ✅
│   ├── 📄 update_booking_status.dart  (62 lines)  ✅
│   └── 📄 check_availability.dart     (60 lines)  ✅
│
├── 📁 services/
│   └── 📄 booking_domain_service.dart (336 lines) 🆕
│
├── 📄 booking_domain.dart              (41 lines)  🆕  (Barrel file)
│
└── 📁 documentation/
    ├── 📄 README.md                   (800+ lines) 🆕
    ├── 📄 EXAMPLES.md                 (600+ lines) 🆕
    ├── 📄 QUICK_REFERENCE.md          (400+ lines) 🆕
    ├── 📄 SUMMARY.md                  (400+ lines) 🆕
    └── 📄 ARCHITECTURE.md             (this file)  🆕

Legend:
  ✅ = Already existed (may have been enhanced)
  🆕 = Newly created
```

## Component Interaction Example

### Complete Booking Creation Flow

```
┌────────────────────────────────────────────────────────────────────┐
│ 1. User selects package and date                                  │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 2. Presentation Layer validates input                             │
│    - Form validation (UI level)                                    │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 3. Create Value Objects                                           │
│    bookingDate = BookingDate(eventDate: date)                     │
│    totalPrice = Money(amount: price, currency: 'AOA')             │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 4. Business Validation (Domain)                                   │
│    if (!bookingDate.isValidForBooking(minimumAdvanceDays: 30))    │
│       return ValidationFailure                                     │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 5. Check Availability (Use Case)                                  │
│    params = CheckAvailabilityParams(...)                          │
│    result = await checkAvailability(params)                       │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓ if available
┌────────────────────────────────────────────────────────────────────┐
│ 6. Create Booking Entity                                          │
│    booking = BookingEntity(                                        │
│      clientId: clientId,                                           │
│      supplierId: supplierId,                                       │
│      eventDate: bookingDate.eventDate,                            │
│      totalAmount: totalPrice.amount,                              │
│      status: BookingStatus.pending,                               │
│      ...                                                           │
│    )                                                               │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 7. Execute Create Use Case                                        │
│    result = await createBooking(booking)                          │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 8. Repository Implementation                                      │
│    - Convert Entity → Firebase Model                              │
│    - Save to Firestore                                            │
│    - Convert Model → Entity                                       │
│    - Return Either<Failure, BookingEntity>                        │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 9. Calculate Payment Details (Domain Service)                     │
│    service = BookingDomainService()                               │
│    deposit = service.calculateSuggestedDeposit(booking)           │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────────┐
│ 10. Update UI with Result                                         │
│     result.fold(                                                   │
│       (failure) => showError(failure.message),                    │
│       (booking) => showSuccess(booking, deposit),                 │
│     )                                                              │
└────────────────────────────────────────────────────────────────────┘
```

## Dependency Injection Flow

```
main.dart
   │
   ├──→ Initialize Repositories
   │    BookingRepositoryImpl(
   │      remoteDataSource,
   │      localDataSource,
   │    )
   │
   ├──→ Initialize Use Cases
   │    CreateBooking(repository)
   │    GetBookings(repository)
   │    CancelBooking(repository)
   │    ...
   │
   ├──→ Initialize Domain Services
   │    BookingDomainService()
   │
   └──→ Inject into Providers
        BookingProvider(
          createBooking,
          getBookings,
          cancelBooking,
          domainService,
        )

UI Widgets
   │
   └──→ Access via Provider
        context.read<BookingProvider>()
```

## Error Flow

```
Repository Implementation (Data Layer)
   │
   │ try-catch Firebase exception
   │
   ↓
Convert to Domain Failure
   │
   ├─ ServerException → ServerFailure
   ├─ ValidationException → ValidationFailure
   ├─ NetworkException → NetworkFailure
   └─ UnknownException → UnknownFailure
   │
   ↓
Return Left(Failure)
   │
   ↓
Use Case receives Either<Failure, T>
   │
   ↓
Presentation Layer handles
   │
   ├─ ValidationFailure → Show form errors
   ├─ ServerFailure → Show retry dialog
   ├─ NetworkFailure → Show network error
   └─ UnknownFailure → Show generic error
```

## Testing Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Unit Tests                                  │
│                                                                     │
│  Entities:                                                          │
│  ✓ Value equality                                                   │
│  ✓ CopyWith functionality                                           │
│  ✓ Computed properties                                              │
│                                                                     │
│  Value Objects:                                                     │
│  ✓ Money arithmetic                                                 │
│  ✓ PaymentStatus calculations                                       │
│  ✓ BookingDate validation                                           │
│                                                                     │
│  Domain Service:                                                    │
│  ✓ Refund calculations                                              │
│  ✓ Payment schedules                                                │
│  ✓ Risk assessment                                                  │
│  ✓ Status transitions                                               │
│                                                                     │
│  Use Cases:                                                         │
│  ✓ Business logic validation                                        │
│  ✓ Repository interaction                                           │
│  ✓ Error handling                                                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Scalability Considerations

### Horizontal Scaling

```
Current:
  BookingDomainService (single class)

Future:
  ├─ RefundPolicyService
  ├─ PaymentScheduleService
  ├─ RiskAssessmentService
  ├─ CommissionCalculationService
  └─ StatusTransitionService
```

### Vertical Scaling

```
Current:
  Simple entities and value objects

Future Enhancements:
  ├─ Aggregates
  │  └─ BookingAggregate (with invariants)
  │
  ├─ Domain Events
  │  ├─ BookingCreatedEvent
  │  ├─ BookingConfirmedEvent
  │  └─ PaymentReceivedEvent
  │
  └─ Specifications
     ├─ PendingBookingsSpec
     ├─ OverduePaymentsSpec
     └─ AtRiskBookingsSpec
```

## Performance Characteristics

### Memory

- **Immutable objects**: Memory efficient with structural sharing
- **Value objects**: Lightweight (few fields)
- **No caching**: Domain layer is stateless

### Computation

- **Pure functions**: No side effects, highly optimizable
- **O(1) operations**: Most calculations are constant time
- **Stream support**: Repository provides real-time streams

### Network

- **No network calls**: Domain layer is network-agnostic
- **Lazy evaluation**: Use cases execute only when called

## Security Considerations

### Domain Layer Security

```
✓ No sensitive data storage
✓ No authentication logic (delegated to auth domain)
✓ No authorization checks (handled by repository/data layer)
✓ Validation only (business rules)
✓ Pure computation (no side effects)
```

### What the Domain Layer Does NOT Do

- ❌ Encrypt/Decrypt data
- ❌ Manage authentication tokens
- ❌ Check user permissions
- ❌ Log sensitive information
- ❌ Make API calls
- ❌ Access file system
- ❌ Manage sessions

### What the Domain Layer DOES Do

- ✅ Define business rules
- ✅ Validate business logic
- ✅ Calculate values
- ✅ Define data structures
- ✅ Specify contracts (interfaces)

---

## Summary

This architecture provides:

1. **Separation of Concerns**: Each layer has a clear responsibility
2. **Testability**: Pure business logic, easily unit tested
3. **Flexibility**: Infrastructure can change without affecting domain
4. **Maintainability**: Clear structure, well-documented
5. **Scalability**: Easy to extend with new use cases or services
6. **Type Safety**: Compile-time error checking
7. **Robustness**: Proper error handling throughout

The domain layer is the **heart** of the application, containing all business logic in a framework-independent, testable manner.

