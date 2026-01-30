/// Booking Domain Layer Barrel File
///
/// This file exports all domain layer components for the Booking feature.
/// Import this file to access all booking domain entities, repositories,
/// use cases, and value objects.
///
/// Example:
/// ```dart
/// import 'package:boda_connect/features/booking/domain/booking_domain.dart';
///
/// // Now you can use any domain component
/// final booking = BookingEntity(...);
/// final money = Money(amount: 100000);
/// final useCase = CreateBooking(repository);
/// ```

// Entities
export 'entities/booking_entity.dart';
export 'entities/booking_status.dart';

// Repositories
export 'repositories/booking_repository.dart';

// Use Cases
export 'usecases/create_booking.dart';
export 'usecases/get_bookings.dart';
export 'usecases/get_booking_by_id.dart';
export 'usecases/get_client_bookings.dart';
export 'usecases/get_supplier_bookings.dart';
export 'usecases/cancel_booking.dart';
export 'usecases/update_booking_status.dart';
export 'usecases/check_availability.dart';

// Value Objects
export 'value_objects/money.dart';
export 'value_objects/payment_status.dart';
export 'value_objects/booking_date.dart';

// Domain Services
export 'services/booking_domain_service.dart';
