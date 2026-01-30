import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// UseCase for retrieving a booking by its ID
///
/// This UseCase fetches a specific booking from the repository
class GetBookingById {
  const GetBookingById(this._repository);

  final BookingRepository _repository;

  /// Retrieves a booking by its ID
  ///
  /// Parameters:
  /// - [bookingId]: The unique identifier of the booking
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the booking entity
  ///
  /// Example:
  /// ```dart
  /// final result = await getBookingById('booking123');
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (booking) => print('Found booking: ${booking.eventName}'),
  /// );
  /// ```
  ResultFuture<BookingEntity> call(String bookingId) async {
    return await _repository.getBookingById(bookingId);
  }
}
