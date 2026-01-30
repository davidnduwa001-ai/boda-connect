import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// UseCase for creating a new booking
///
/// This UseCase encapsulates the business logic for creating a booking
/// It validates the booking data and delegates to the repository
class CreateBooking {
  const CreateBooking(this._repository);

  final BookingRepository _repository;

  /// Creates a new booking
  ///
  /// Parameters:
  /// - [booking]: The booking entity to create
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the created booking
  ///
  /// Example:
  /// ```dart
  /// final result = await createBooking(bookingEntity);
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (booking) => print('Booking created: ${booking.id}'),
  /// );
  /// ```
  ResultFuture<BookingEntity> call(BookingEntity booking) async {
    return await _repository.createBooking(booking);
  }
}
