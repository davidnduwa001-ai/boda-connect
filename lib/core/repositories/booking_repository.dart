import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/models/review_category_models.dart';
import 'package:boda_connect/core/services/storage_service.dart';
import 'package:boda_connect/core/services/blocked_dates_service.dart';
import 'package:boda_connect/core/services/logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';


class BookingRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final BlockedDatesService _blockedDatesService = BlockedDatesService();

  // ==================== BOOKING CRUD ====================

  /// Firebase Functions instance
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Create a new booking via Cloud Function
  /// Server handles validation, conflict checking, and stats updates
  Future<String> createBooking(BookingModel booking) async {
    Log.i('BookingRepository.createBooking: Starting...');

    // Validate event date is not blocked (client-side pre-check)
    try {
      final isBlocked = await _blockedDatesService.isDateBlocked(
        booking.supplierId,
        booking.eventDate,
      );

      if (isBlocked) {
        throw Exception('Esta data está indisponível. O fornecedor bloqueou esta data.');
      }
    } catch (e) {
      Log.fail('BookingRepository: Blocked date check failed: $e');
      // Continue anyway - let Cloud Function do the final check
    }

    try {
      // Call the createBooking Cloud Function for server-side validation
      // and atomic conflict checking
      Log.i('BookingRepository: Calling createBooking Cloud Function...');
      final callable = _functions.httpsCallable('createBooking');

      // Format event date as YYYY-MM-DD string
      final eventDateStr =
          '${booking.eventDate.year}-${booking.eventDate.month.toString().padLeft(2, '0')}-${booking.eventDate.day.toString().padLeft(2, '0')}';

      Log.i('BookingRepository: packageId=${booking.packageId}, supplierId=${booking.supplierId}');
      final result = await callable.call<Map<String, dynamic>>({
        'supplierId': booking.supplierId,
        'packageId': booking.packageId,
        'eventDate': eventDateStr,
        'startTime': booking.eventTime,
        'notes': booking.clientNotes ?? booking.notes,
        'eventName': booking.eventName,
        'eventLocation': booking.eventLocation,
        'guestCount': booking.guestCount,
        'clientRequestId': booking.id.isNotEmpty ? booking.id : null,
        'totalPrice': booking.totalPrice,
        'packageName': booking.packageName,
        'selectedCustomizations': booking.selectedCustomizations,
      });
      Log.i('BookingRepository: Cloud Function returned');

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Falha ao criar reserva');
      }

      final bookingId = data['bookingId'] as String;
      Log.success('Booking created via Cloud Function: $bookingId');

      return bookingId;
    } on FirebaseFunctionsException catch (e) {
      Log.fail('Cloud Function error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Falha ao criar reserva');
    } catch (e) {
      Log.fail('Booking creation error: $e');
      rethrow;
    }
  }

  /// Get booking by ID
  Future<BookingModel?> getBooking(String id) async {
    return await _firestoreService.getBooking(id);
  }

  /// Get client bookings
  Future<List<BookingModel>> getClientBookings(
    String clientId, {
    List<BookingStatus>? statuses,
  }) async {
    return await _firestoreService.getClientBookings(clientId, statuses: statuses);
  }

  /// Stream client bookings for real-time updates
  ///
  /// @deprecated UI-FIRST VIOLATION: Use clientViewStreamProvider instead
  /// This direct Firestore read should be replaced with projection reads.
  /// See: lib/core/providers/client_view_provider.dart
  @Deprecated('Use clientViewStreamProvider from client_view_provider.dart')
  Stream<List<BookingModel>> streamClientBookings(String clientId) {
    // TODO: Remove this method after UI migration to projections
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromFirestore(doc))
            .toList());
  }

  /// Get supplier bookings
  Future<List<BookingModel>> getSupplierBookings(
    String supplierId, {
    List<BookingStatus>? statuses,
  }) async {
    return await _firestoreService.getSupplierBookings(supplierId, statuses: statuses);
  }

  /// Update booking
  Future<void> updateBooking(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _firestoreService.bookings.doc(id).update(data);
  }

  /// Update booking status
  Future<void> updateBookingStatus(
    String id,
    BookingStatus status, {
    String? reason,
    String? cancelledBy,
  }) async {
    await _firestoreService.updateBookingStatus(
      id,
      status,
      reason: reason,
      cancelledBy: cancelledBy,
    );
  }

  // ==================== PAYMENTS ====================

  /// Add payment to booking
  Future<void> addPayment(String bookingId, BookingPayment payment) async {
    await _firestoreService.addBookingPayment(bookingId, payment);
  }

  /// Get booking payments
  Future<List<BookingPayment>> getBookingPayments(String bookingId) async {
    final booking = await getBooking(bookingId);
    return booking?.payments ?? [];
  }

  // ==================== REVIEWS ====================

  /// Create review for completed booking via Cloud Function
  ///
  /// Uses server-side validation to prevent race conditions:
  /// - Booking completion check is done atomically
  /// - Duplicate review check uses transaction
  /// - Supplier stats update is atomic
  Future<String> createReview({
    required String bookingId,
    required String clientId,
    required String supplierId,
    required double rating,
    String? comment,
    List<String>? photos,
    String? clientName,
    String? clientPhoto,
    List<String>? tags,
  }) async {
    try {
      // Use Cloud Function for atomic review creation
      // This prevents race conditions and ensures data integrity
      final callable = _functions.httpsCallable('createReview');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
        'tags': tags ?? [],
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Erro ao criar avaliação');
      }

      final reviewId = data['reviewId'] as String;
      Log.success('Review created via Cloud Function: $reviewId');

      return reviewId;
    } on FirebaseFunctionsException catch (e) {
      Log.fail('Cloud Function error: ${e.code} - ${e.message}');

      // Map error codes to user-friendly messages
      switch (e.code) {
        case 'failed-precondition':
          throw Exception(e.message ?? 'Reserva não pode ser avaliada');
        case 'already-exists':
          throw Exception('Já avaliou esta reserva');
        case 'unauthenticated':
          throw Exception('Faça login para avaliar');
        default:
          throw Exception(e.message ?? 'Erro ao criar avaliação');
      }
    } catch (e) {
      Log.fail('Review creation error: $e');
      rethrow;
    }
  }

  // ==================== BOOKING QUERIES ====================

  /// Get upcoming bookings for client
  Future<List<BookingModel>> getUpcomingClientBookings(String clientId) async {
    return await getClientBookings(
      clientId,
      statuses: [BookingStatus.pending, BookingStatus.confirmed],
    );
  }

  /// Get past bookings for client
  Future<List<BookingModel>> getPastClientBookings(String clientId) async {
    return await getClientBookings(
      clientId,
      statuses: [BookingStatus.completed, BookingStatus.cancelled],
    );
  }

  /// Get pending bookings for supplier
  Future<List<BookingModel>> getPendingSupplierBookings(String supplierId) async {
    return await getSupplierBookings(
      supplierId,
      statuses: [BookingStatus.pending],
    );
  }

  /// Get bookings for a specific date (supplier)
  ///
  /// @deprecated UI-FIRST VIOLATION: Use supplierViewStreamProvider.blockedDates instead
  /// This direct Firestore read should be replaced with projection reads.
  @Deprecated('Use supplierBlockedDatesFromViewProvider from supplier_view_provider.dart')
  Future<List<BookingModel>> getBookingsForDate(
    String supplierId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestoreService.bookings
        .where('supplierId', isEqualTo: supplierId)
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('eventDate', isLessThan: Timestamp.fromDate(endOfDay))
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    return snapshot.docs
        .map((doc) => BookingModel.fromFirestore(doc))
        .toList();
  }

  /// Get bookings for date range (for calendar)
  Future<List<BookingModel>> getBookingsInRange(
    String supplierId,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _firestoreService.bookings
        .where('supplierId', isEqualTo: supplierId)
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('eventDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .where('status', whereIn: ['pending', 'confirmed', 'completed'])
        .get();

    return snapshot.docs
        .map((doc) => BookingModel.fromFirestore(doc))
        .toList();
  }

  // ==================== STATISTICS ====================

  /// Get booking statistics for supplier
  Future<Map<String, dynamic>> getSupplierBookingStats(
    String supplierId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _firestoreService.bookings
        .where('supplierId', isEqualTo: supplierId);

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final snapshot = await query.get();
    
    int total = snapshot.docs.length;
    int pending = 0;
    int confirmed = 0;
    int completed = 0;
    int cancelled = 0;
    int totalRevenue = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;
      
      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'confirmed':
          confirmed++;
          break;
        case 'completed':
          completed++;
          totalRevenue += (data['paidAmount'] ?? 0) as int;
          break;
        case 'cancelled':
          cancelled++;
          break;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'confirmed': confirmed,
      'completed': completed,
      'cancelled': cancelled,
      'revenue': totalRevenue,
      'completionRate': total > 0 ? (completed / total * 100).round() : 0,
    };
  }

  /// Get monthly revenue for supplier
  Future<List<Map<String, dynamic>>> getMonthlyRevenue(
    String supplierId, {
    int months = 6,
  }) async {
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];

    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final snapshot = await _firestoreService.bookings
          .where('supplierId', isEqualTo: supplierId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
          .where('completedAt', isLessThan: Timestamp.fromDate(nextMonth))
          .get();

      int revenue = 0;
      for (final doc in snapshot.docs) {
        revenue += ((doc.data() as Map<String, dynamic>)['paidAmount'] ?? 0) as int;
      }

      results.add({
        'month': month,
        'revenue': revenue,
        'bookings': snapshot.docs.length,
      });
    }

    return results;
  }

  // ==================== VALIDATION ====================

  /// Check if date is available for supplier
  Future<bool> isDateAvailable(String supplierId, DateTime date) async {
    // Check if date is blocked in supplier's blocked_dates subcollection
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDay = normalizedDate.add(const Duration(days: 1));

    final blockedSnapshot = await _firestoreService.suppliers
        .doc(supplierId)
        .collection('blocked_dates')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate))
        .where('date', isLessThan: Timestamp.fromDate(nextDay))
        .get();

    // If date is blocked, it's not available
    if (blockedSnapshot.docs.isNotEmpty) {
      return false;
    }

    // Avoid client-side reads of /bookings; final conflict check happens in Cloud Function.
    return true;
  }

  /// Validate booking can be created
  Future<void> validateBooking({
    required String supplierId,
    required String packageId,
    required DateTime eventDate,
  }) async {
    // Check if date is in the future
    if (eventDate.isBefore(DateTime.now())) {
      throw Exception('A data do evento deve ser no futuro');
    }

    // Check if date is available
    final isAvailable = await isDateAvailable(supplierId, eventDate);
    if (!isAvailable) {
      throw Exception('Data não disponível');
    }

    // Check if package exists and is active
    final packageDoc = await _firestoreService.packages.doc(packageId).get();
    if (!packageDoc.exists) {
      throw Exception('Pacote não encontrado');
    }
    
    final packageData = packageDoc.data() as Map<String, dynamic>?;
    if (packageData?['isActive'] != true) {
      throw Exception('Pacote não disponível');
    }
  }
}
