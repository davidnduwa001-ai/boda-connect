import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// Parameters for getting supplier bookings
class GetSupplierBookingsParams {
  const GetSupplierBookingsParams({
    required this.supplierId,
    this.status,
  });

  /// ID of the supplier whose bookings to retrieve
  final String supplierId;

  /// Optional status filter to get only bookings with specific status
  final BookingStatus? status;
}

/// UseCase for retrieving all bookings for a specific supplier
///
/// This UseCase fetches all bookings assigned to a supplier
/// Optionally filtered by booking status
class GetSupplierBookings {
  const GetSupplierBookings(this._repository);

  final BookingRepository _repository;

  /// Retrieves all bookings for a supplier
  ///
  /// Parameters:
  /// - [params]: Parameters containing supplierId and optional status filter
  ///
  /// Returns:
  /// - [ResultFuture<List<BookingEntity>>]: Either a Failure or list of bookings
  ///
  /// Example:
  /// ```dart
  /// final params = GetSupplierBookingsParams(
  ///   supplierId: 'supplier123',
  ///   status: BookingStatus.pending,
  /// );
  /// final result = await getSupplierBookings(params);
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (bookings) => print('Found ${bookings.length} bookings'),
  /// );
  /// ```
  ResultFuture<List<BookingEntity>> call(GetSupplierBookingsParams params) async {
    return await _repository.getSupplierBookings(
      params.supplierId,
      status: params.status,
    );
  }
}
