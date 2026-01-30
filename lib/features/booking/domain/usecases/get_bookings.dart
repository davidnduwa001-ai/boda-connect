import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// Parameters for retrieving bookings with flexible filtering
class GetBookingsParams {
  const GetBookingsParams({
    this.clientId,
    this.supplierId,
    this.status,
  }) : assert(
          clientId != null || supplierId != null,
          'Either clientId or supplierId must be provided',
        );

  /// ID of the client to filter by (optional)
  final String? clientId;

  /// ID of the supplier to filter by (optional)
  final String? supplierId;

  /// Optional status filter to get only bookings with specific status
  final BookingStatus? status;

  /// Check if this is a client query
  bool get isClientQuery => clientId != null;

  /// Check if this is a supplier query
  bool get isSupplierQuery => supplierId != null;
}

/// UseCase for retrieving bookings with flexible filtering
///
/// This UseCase provides a unified interface for fetching bookings for either
/// clients or suppliers, with optional status filtering. It delegates to the
/// appropriate repository method based on the parameters.
///
/// This is a convenience use case that wraps GetClientBookings and
/// GetSupplierBookings into a single, more flexible interface.
///
/// Example usage:
/// ```dart
/// // Get all bookings for a client
/// final clientParams = GetBookingsParams(clientId: 'client123');
/// final result = await getBookings(clientParams);
///
/// // Get confirmed bookings for a supplier
/// final supplierParams = GetBookingsParams(
///   supplierId: 'supplier456',
///   status: BookingStatus.confirmed,
/// );
/// final result2 = await getBookings(supplierParams);
/// ```
class GetBookings {
  const GetBookings(this._repository);

  final BookingRepository _repository;

  /// Retrieves bookings based on the provided parameters
  ///
  /// Parameters:
  /// - [params]: Parameters containing either clientId or supplierId, and optional status filter
  ///
  /// Returns:
  /// - [ResultFuture<List<BookingEntity>>]: Either a Failure or list of bookings
  ///
  /// Example:
  /// ```dart
  /// final params = GetBookingsParams(
  ///   clientId: 'client123',
  ///   status: BookingStatus.pending,
  /// );
  /// final result = await getBookings(params);
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (bookings) => print('Found ${bookings.length} pending bookings'),
  /// );
  /// ```
  ResultFuture<List<BookingEntity>> call(GetBookingsParams params) async {
    // Delegate to client bookings if clientId is provided
    if (params.isClientQuery) {
      return await _repository.getClientBookings(
        params.clientId!,
        status: params.status,
      );
    }

    // Delegate to supplier bookings if supplierId is provided
    if (params.isSupplierQuery) {
      return await _repository.getSupplierBookings(
        params.supplierId!,
        status: params.status,
      );
    }

    // This should never happen due to the assertion in the constructor
    throw ArgumentError(
      'Either clientId or supplierId must be provided in GetBookingsParams',
    );
  }
}
