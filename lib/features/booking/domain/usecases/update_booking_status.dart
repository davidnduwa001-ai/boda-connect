import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// Parameters for updating booking status
class UpdateBookingStatusParams {
  const UpdateBookingStatusParams({
    required this.bookingId,
    required this.newStatus,
    required this.userId,
  });

  /// ID of the booking to update
  final String bookingId;

  /// New status to set
  final BookingStatus newStatus;

  /// ID of the user making the update (for audit purposes)
  final String userId;
}

/// UseCase for updating the status of a booking
///
/// This UseCase handles status transitions for bookings
/// e.g., pending -> confirmed, confirmed -> completed, etc.
class UpdateBookingStatus {
  const UpdateBookingStatus(this._repository);

  final BookingRepository _repository;

  /// Updates the status of a booking
  ///
  /// Parameters:
  /// - [params]: Parameters containing bookingId, newStatus, and userId
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the updated booking
  ///
  /// Example:
  /// ```dart
  /// final params = UpdateBookingStatusParams(
  ///   bookingId: 'booking123',
  ///   newStatus: BookingStatus.confirmed,
  ///   userId: 'supplier456',
  /// );
  /// final result = await updateBookingStatus(params);
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (booking) => print('Status updated to: ${booking.status}'),
  /// );
  /// ```
  ResultFuture<BookingEntity> call(UpdateBookingStatusParams params) async {
    return await _repository.updateBookingStatus(
      bookingId: params.bookingId,
      newStatus: params.newStatus,
      userId: params.userId,
    );
  }
}
