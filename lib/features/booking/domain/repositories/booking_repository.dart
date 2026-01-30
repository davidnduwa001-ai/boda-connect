import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';

/// Abstract repository interface for booking operations
/// This defines the contract that the data layer must implement
/// Following Clean Architecture principles, this interface is in the domain layer
/// and the implementation will be in the data layer
abstract class BookingRepository {
  /// Create a new booking
  ///
  /// Parameters:
  /// - [booking]: The booking entity to create
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the created booking
  ResultFuture<BookingEntity> createBooking(BookingEntity booking);

  /// Get a booking by its ID
  ///
  /// Parameters:
  /// - [bookingId]: The unique identifier of the booking
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the booking entity
  ResultFuture<BookingEntity> getBookingById(String bookingId);

  /// Get all bookings for a specific client
  ///
  /// Parameters:
  /// - [clientId]: The ID of the client
  /// - [status]: Optional status filter
  ///
  /// Returns:
  /// - [ResultFuture<List<BookingEntity>>]: Either a Failure or list of bookings
  ResultFuture<List<BookingEntity>> getClientBookings(
    String clientId, {
    BookingStatus? status,
  });

  /// Get all bookings for a specific supplier
  ///
  /// Parameters:
  /// - [supplierId]: The ID of the supplier
  /// - [status]: Optional status filter
  ///
  /// Returns:
  /// - [ResultFuture<List<BookingEntity>>]: Either a Failure or list of bookings
  ResultFuture<List<BookingEntity>> getSupplierBookings(
    String supplierId, {
    BookingStatus? status,
  });

  /// Update the status of a booking
  ///
  /// Parameters:
  /// - [bookingId]: The ID of the booking to update
  /// - [newStatus]: The new status to set
  /// - [userId]: ID of the user making the update (for audit purposes)
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the updated booking
  ResultFuture<BookingEntity> updateBookingStatus({
    required String bookingId,
    required BookingStatus newStatus,
    required String userId,
  });

  /// Cancel a booking
  ///
  /// Parameters:
  /// - [bookingId]: The ID of the booking to cancel
  /// - [cancelledBy]: ID of the user cancelling (client or supplier)
  /// - [reason]: Reason for cancellation
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the cancelled booking
  ResultFuture<BookingEntity> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    String? reason,
  });

  /// Check if a supplier is available on a specific date
  ///
  /// Parameters:
  /// - [supplierId]: The ID of the supplier
  /// - [date]: The date to check availability
  /// - [excludeBookingId]: Optional booking ID to exclude from check (for updates)
  ///
  /// Returns:
  /// - [ResultFuture<bool>]: Either a Failure or true if available, false if not
  ResultFuture<bool> checkAvailability({
    required String supplierId,
    required DateTime date,
    String? excludeBookingId,
  });

  /// Update booking details
  ///
  /// Parameters:
  /// - [bookingId]: The ID of the booking to update
  /// - [updates]: Map of fields to update
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the updated booking
  ResultFuture<BookingEntity> updateBooking({
    required String bookingId,
    required Map<String, dynamic> updates,
  });

  /// Add a payment to a booking
  ///
  /// Parameters:
  /// - [bookingId]: The ID of the booking
  /// - [payment]: The payment entity to add
  ///
  /// Returns:
  /// - [ResultFuture<BookingEntity>]: Either a Failure or the updated booking
  ResultFuture<BookingEntity> addPayment({
    required String bookingId,
    required BookingPaymentEntity payment,
  });

  /// Stream bookings for a client in real-time
  ///
  /// Parameters:
  /// - [clientId]: The ID of the client
  ///
  /// Returns:
  /// - [Stream<List<BookingEntity>>]: Stream of booking lists
  Stream<List<BookingEntity>> streamClientBookings(String clientId);

  /// Stream bookings for a supplier in real-time
  ///
  /// Parameters:
  /// - [supplierId]: The ID of the supplier
  ///
  /// Returns:
  /// - [Stream<List<BookingEntity>>]: Stream of booking lists
  Stream<List<BookingEntity>> streamSupplierBookings(String supplierId);

  /// Stream a specific booking in real-time
  ///
  /// Parameters:
  /// - [bookingId]: The ID of the booking
  ///
  /// Returns:
  /// - [Stream<BookingEntity?>]: Stream of booking entity (null if deleted)
  Stream<BookingEntity?> streamBooking(String bookingId);
}
