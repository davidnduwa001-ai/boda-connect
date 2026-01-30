import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// Parameters for getting client bookings
class GetClientBookingsParams {
  const GetClientBookingsParams({
    required this.clientId,
    this.status,
  });

  /// ID of the client whose bookings to retrieve
  final String clientId;

  /// Optional status filter to get only bookings with specific status
  final BookingStatus? status;
}

/// UseCase for retrieving all bookings for a specific client
///
/// This UseCase fetches all bookings made by a client
/// Optionally filtered by booking status
class GetClientBookings {
  const GetClientBookings(this._repository);

  final BookingRepository _repository;

  /// Retrieves all bookings for a client
  ///
  /// Parameters:
  /// - [params]: Parameters containing clientId and optional status filter
  ///
  /// Returns:
  /// - [ResultFuture<List<BookingEntity>>]: Either a Failure or list of bookings
  ///
  /// Example:
  /// ```dart
  /// final params = GetClientBookingsParams(
  ///   clientId: 'client123',
  ///   status: BookingStatus.confirmed,
  /// );
  /// final result = await getClientBookings(params);
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (bookings) => print('Found ${bookings.length} bookings'),
  /// );
  /// ```
  ResultFuture<List<BookingEntity>> call(GetClientBookingsParams params) async {
    return await _repository.getClientBookings(
      params.clientId,
      status: params.status,
    );
  }
}
