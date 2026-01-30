import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:boda_connect/core/utils/typedefs.dart';
import 'package:boda_connect/features/booking/data/models/booking_model.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_entity.dart';
import 'package:boda_connect/features/booking/domain/entities/booking_status.dart';

/// Abstract interface for booking remote data source
abstract class BookingRemoteDataSource {
  /// Create a new booking in Firestore
  Future<BookingModel> createBooking(BookingModel booking);

  /// Get a booking by its ID using Cloud Function for secure access
  ///
  /// UI-FIRST: Uses getClientBookingDetails or getSupplierBookingDetails
  /// based on the userRole parameter for proper ownership validation.
  Future<BookingModel> getBookingById(String bookingId, {String userRole = 'client'});

  /// Get all bookings for a specific client
  Future<List<BookingModel>> getClientBookings(
    String clientId, {
    BookingStatus? status,
  });

  /// Get all bookings for a specific supplier
  Future<List<BookingModel>> getSupplierBookings(
    String supplierId, {
    BookingStatus? status,
  });

  /// Update the status of a booking
  Future<BookingModel> updateBookingStatus({
    required String bookingId,
    required BookingStatus newStatus,
    required String userId,
  });

  /// Cancel a booking
  Future<BookingModel> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    String? reason,
  });

  /// Check if a supplier is available on a specific date
  Future<bool> checkAvailability({
    required String supplierId,
    required DateTime date,
    String? excludeBookingId,
  });

  /// Update booking details
  Future<BookingModel> updateBooking({
    required String bookingId,
    required DataMap updates,
  });

  /// Add a payment to a booking
  Future<BookingModel> addPayment({
    required String bookingId,
    required BookingPaymentEntity payment,
  });

  /// Stream bookings for a client in real-time
  ///
  /// @deprecated UI-FIRST: Prefer using clientViewStreamProvider for real-time
  /// booking updates. Direct Firestore streams may cause permission issues.
  @Deprecated('Use clientViewStreamProvider for real-time client booking updates')
  Stream<List<BookingModel>> streamClientBookings(String clientId);

  /// Stream bookings for a supplier in real-time
  ///
  /// @deprecated UI-FIRST: Prefer using supplierViewStreamProvider for real-time
  /// booking updates. Direct Firestore streams may cause permission issues.
  @Deprecated('Use supplierViewStreamProvider for real-time supplier booking updates')
  Stream<List<BookingModel>> streamSupplierBookings(String supplierId);

  /// Stream a specific booking in real-time
  ///
  /// @deprecated UI-FIRST: Direct booking streams may cause permission errors.
  /// Use projection providers and Cloud Functions for booking details.
  @Deprecated('Use projection providers for real-time booking updates')
  Stream<BookingModel?> streamBooking(String bookingId);
}

/// Implementation of BookingRemoteDataSource using Firebase Firestore
class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  BookingRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Reference to the bookings collection
  CollectionReference get _bookingsCollection =>
      _firestore.collection('bookings');

  /// Firebase Functions instance
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<BookingModel> createBooking(BookingModel booking) async {
    try {
      // Call the createBooking Cloud Function for server-side validation
      // and atomic conflict checking
      final callable = _functions.httpsCallable('createBooking');

      // Format event date as YYYY-MM-DD string
      final eventDateStr =
          '${booking.eventDate.year}-${booking.eventDate.month.toString().padLeft(2, '0')}-${booking.eventDate.day.toString().padLeft(2, '0')}';

      final result = await callable.call<Map<String, dynamic>>({
        'supplierId': booking.supplierId,
        'packageId': booking.packageId,
        'eventDate': eventDateStr,
        'startTime': booking.eventTime, // eventTime is used for the time
        'notes': booking.notes,
        'eventName': booking.eventName,
        'eventLocation': booking.eventLocation,
        'guestCount': booking.guestCount,
        'clientRequestId': booking.id, // Use the client-generated ID for idempotency
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to create booking');
      }

      // Fetch the created booking from Firestore
      final bookingId = data['bookingId'] as String;
      final doc = await _bookingsCollection.doc(bookingId).get();

      if (!doc.exists) {
        throw Exception('Booking created but not found in database');
      }

      return BookingModel.fromFirestore(doc);
    } on FirebaseFunctionsException catch (e) {
      // Handle specific Cloud Function errors
      throw Exception(e.message ?? 'Failed to create booking');
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  /// Get booking by ID using Cloud Function for secure access
  ///
  /// UI-FIRST: Uses getClientBookingDetails or getSupplierBookingDetails
  /// based on the userRole parameter for proper ownership validation.
  @override
  Future<BookingModel> getBookingById(String bookingId, {String userRole = 'client'}) async {
    try {
      // Use appropriate Cloud Function based on user role
      final functionName = userRole == 'supplier'
          ? 'getSupplierBookingDetails'
          : 'getClientBookingDetails';

      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
      });

      // Safely handle Cloud Function response
      final rawData = result.data;
      if (rawData == null) {
        throw Exception('Booking not found');
      }

      final Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        throw Exception('Invalid response from Cloud Function');
      }

      if (data['success'] != true || data['booking'] == null) {
        throw Exception(data['error'] ?? 'Booking not found');
      }

      // Convert booking data
      final rawBooking = data['booking'];
      final Map<String, dynamic> bookingData;
      if (rawBooking is Map<String, dynamic>) {
        bookingData = rawBooking;
      } else if (rawBooking is Map) {
        bookingData = Map<String, dynamic>.from(rawBooking);
      } else {
        throw Exception('Invalid booking data from Cloud Function');
      }

      return BookingModel.fromCloudFunction(bookingData);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ getBookingById Cloud Function error: ${e.code} - ${e.message}');
      throw Exception('Failed to get booking: ${e.message}');
    } catch (e) {
      debugPrint('⚠️ getBookingById error: $e');
      throw Exception('Failed to get booking: $e');
    }
  }

  @override
  Future<List<BookingModel>> getClientBookings(
    String clientId, {
    BookingStatus? status,
  }) async {
    try {
      Query query = _bookingsCollection.where('clientId', isEqualTo: clientId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      // Order by creation date, newest first
      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get client bookings: $e');
    }
  }

  @override
  Future<List<BookingModel>> getSupplierBookings(
    String supplierId, {
    BookingStatus? status,
  }) async {
    try {
      Query query = _bookingsCollection.where('supplierId', isEqualTo: supplierId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      // Order by creation date, newest first
      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get supplier bookings: $e');
    }
  }

  @override
  Future<BookingModel> updateBookingStatus({
    required String bookingId,
    required BookingStatus newStatus,
    required String userId,
  }) async {
    try {
      // Call the updateBookingStatus Cloud Function for server-side
      // state machine validation and atomic updates
      final callable = _functions.httpsCallable('updateBookingStatus');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'newStatus': newStatus.name,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to update booking status');
      }

      // Fetch the updated booking from Firestore
      final doc = await _bookingsCollection.doc(bookingId).get();
      return BookingModel.fromFirestore(doc);
    } on FirebaseFunctionsException catch (e) {
      // Handle Cloud Function specific errors
      throw Exception('Failed to update booking status: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  @override
  Future<BookingModel> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    String? reason,
  }) async {
    try {
      // Call the cancelBooking Cloud Function for server-side
      // state machine validation and atomic cancellation
      final callable = _functions.httpsCallable('cancelBooking');

      final params = <String, dynamic>{
        'bookingId': bookingId,
      };

      if (reason != null) {
        params['reason'] = reason;
      }

      final result = await callable.call<Map<String, dynamic>>(params);

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to cancel booking');
      }

      // Fetch the updated booking from Firestore
      final doc = await _bookingsCollection.doc(bookingId).get();
      return BookingModel.fromFirestore(doc);
    } on FirebaseFunctionsException catch (e) {
      // Handle Cloud Function specific errors
      throw Exception('Failed to cancel booking: ${e.message}');
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  @override
  Future<bool> checkAvailability({
    required String supplierId,
    required DateTime date,
    String? excludeBookingId,
  }) async {
    try {
      // Get the start and end of the day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Query for bookings on the same date with active statuses
      Query query = _bookingsCollection
          .where('supplierId', isEqualTo: supplierId)
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('eventDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));

      final snapshot = await query.get();

      // Filter out cancelled/refunded bookings and the booking being excluded
      final activeBookings = snapshot.docs.where((doc) {
        final data = doc.data() as DataMap;
        final status = data['status'] as String?;
        final bookingId = doc.id;

        // Exclude the current booking if specified
        if (excludeBookingId != null && bookingId == excludeBookingId) {
          return false;
        }

        // Only consider pending, confirmed, and in-progress bookings
        return status == BookingStatus.pending.name ||
               status == BookingStatus.confirmed.name ||
               status == BookingStatus.inProgress.name;
      }).toList();

      // If there are any active bookings, supplier is not available
      return activeBookings.isEmpty;
    } catch (e) {
      throw Exception('Failed to check availability: $e');
    }
  }

  @override
  Future<BookingModel> updateBooking({
    required String bookingId,
    required DataMap updates,
  }) async {
    try {
      final docRef = _bookingsCollection.doc(bookingId);

      // Always update the updatedAt timestamp
      final updatesWithTimestamp = {
        ...updates,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await docRef.update(updatesWithTimestamp);

      final doc = await docRef.get();
      return BookingModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to update booking: $e');
    }
  }

  @override
  Future<BookingModel> addPayment({
    required String bookingId,
    required BookingPaymentEntity payment,
  }) async {
    try {
      final docRef = _bookingsCollection.doc(bookingId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Booking not found');
      }

      final booking = BookingModel.fromFirestore(doc);
      final paymentModel = BookingPaymentModel.fromEntity(payment);

      // Add the new payment to the list
      final updatedPayments = [...booking.payments, paymentModel];

      // Calculate the new paid amount
      final newPaidAmount = updatedPayments.fold<int>(
        0,
        (sum, p) => sum + p.amount,
      );

      // Update the booking with the new payment
      await docRef.update({
        'payments': updatedPayments.map((p) => BookingPaymentModel.fromEntity(p).toMap()).toList(),
        'paidAmount': newPaidAmount,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      final updatedDoc = await docRef.get();
      return BookingModel.fromFirestore(updatedDoc);
    } catch (e) {
      throw Exception('Failed to add payment: $e');
    }
  }

  @override
  Stream<List<BookingModel>> streamClientBookings(String clientId) {
    try {
      return _bookingsCollection
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => BookingModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to stream client bookings: $e');
    }
  }

  @override
  Stream<List<BookingModel>> streamSupplierBookings(String supplierId) {
    try {
      return _bookingsCollection
          .where('supplierId', isEqualTo: supplierId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => BookingModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      throw Exception('Failed to stream supplier bookings: $e');
    }
  }

  @override
  Stream<BookingModel?> streamBooking(String bookingId) {
    try {
      return _bookingsCollection.doc(bookingId).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }
        return BookingModel.fromFirestore(doc);
      });
    } catch (e) {
      throw Exception('Failed to stream booking: $e');
    }
  }
}
