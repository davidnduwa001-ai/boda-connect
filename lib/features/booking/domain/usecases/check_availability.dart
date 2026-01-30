import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/domain/repositories/booking_repository.dart';

/// Parameters for checking supplier availability
class CheckAvailabilityParams {
  const CheckAvailabilityParams({
    required this.supplierId,
    required this.date,
    this.excludeBookingId,
  });

  /// ID of the supplier to check availability for
  final String supplierId;

  /// Date to check availability on
  final DateTime date;

  /// Optional booking ID to exclude from availability check
  /// This is useful when updating an existing booking to avoid conflicts with itself
  final String? excludeBookingId;
}

/// UseCase for checking if a supplier is available on a specific date
///
/// This UseCase checks if a supplier already has a confirmed or in-progress booking
/// on the specified date
class CheckAvailability {
  const CheckAvailability(this._repository);

  final BookingRepository _repository;

  /// Checks supplier availability on a specific date
  ///
  /// Parameters:
  /// - [params]: Parameters containing supplierId, date, and optional excludeBookingId
  ///
  /// Returns:
  /// - [ResultFuture<bool>]: Either a Failure or true if available, false if not
  ///
  /// Example:
  /// ```dart
  /// final params = CheckAvailabilityParams(
  ///   supplierId: 'supplier123',
  ///   date: DateTime(2024, 12, 25),
  /// );
  /// final result = await checkAvailability(params);
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (isAvailable) => print('Available: $isAvailable'),
  /// );
  /// ```
  ResultFuture<bool> call(CheckAvailabilityParams params) async {
    return await _repository.checkAvailability(
      supplierId: params.supplierId,
      date: params.date,
      excludeBookingId: params.excludeBookingId,
    );
  }
}
