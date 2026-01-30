import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// Parameters for cancelling a booking
class CancelBookingParams {
  const CancelBookingParams({
    required this.bookingId,
    required this.cancelledBy,
    this.reason,
  });

  /// ID of the booking to cancel
  final String bookingId;

  /// ID of the user cancelling (client or supplier)
  final String cancelledBy;

  /// Optional reason for cancellation
  final String? reason;
}

/// UseCase for cancelling a booking
///
/// This UseCase handles the cancellation of bookings
/// It updates the booking status to cancelled and records who cancelled and why
class CancelBooking {
  const CancelBooking(this._repository);

  final BookingRepository _repository;

  /// Cancels a booking
  ///
  /// Parameters:
  /// - [params]: Parameters containing bookingId, cancelledBy, and optional reason
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the cancelled booking
  ///
  /// Example:
  /// ```dart
  /// final params = CancelBookingParams(
  ///   bookingId: 'booking123',
  ///   cancelledBy: 'client456',
  ///   reason: 'Cliente não disponível na data',
  /// );
  /// final result = await cancelBooking(params);
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (booking) => print('Booking cancelled at: ${booking.cancelledAt}'),
  /// );
  /// ```
  ResultFuture<BookingEntity> call(CancelBookingParams params) async {
    return await _repository.cancelBooking(
      bookingId: params.bookingId,
      cancelledBy: params.cancelledBy,
      reason: params.reason,
    );
  }
}
