import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/repositories/booking_repository.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/availability_provider.dart';
import 'package:boda_connect/core/providers/supplier_stats_provider.dart';
import 'package:boda_connect/core/services/logger_service.dart';

// ==================== REPOSITORY PROVIDER ====================

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

// ==================== BOOKING STATE ====================

class BookingState {
  final List<BookingModel> clientBookings;
  final List<BookingModel> supplierBookings;
  final BookingModel? currentBooking;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const BookingState({
    this.clientBookings = const [],
    this.supplierBookings = const [],
    this.currentBooking,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  BookingState copyWith({
    List<BookingModel>? clientBookings,
    List<BookingModel>? supplierBookings,
    BookingModel? currentBooking,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return BookingState(
      clientBookings: clientBookings ?? this.clientBookings,
      supplierBookings: supplierBookings ?? this.supplierBookings,
      currentBooking: currentBooking ?? this.currentBooking,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }

  // Filtered bookings
  List<BookingModel> get upcomingClientBookings => clientBookings
      .where((b) => b.status == BookingStatus.pending || 
                    b.status == BookingStatus.confirmed)
      .toList();

  List<BookingModel> get pastClientBookings => clientBookings
      .where((b) => b.status == BookingStatus.completed || 
                    b.status == BookingStatus.cancelled)
      .toList();

  List<BookingModel> get pendingSupplierBookings => supplierBookings
      .where((b) => b.status == BookingStatus.pending)
      .toList();

  List<BookingModel> get confirmedSupplierBookings => supplierBookings
      .where((b) => b.status == BookingStatus.confirmed)
      .toList();
}

// ==================== BOOKING NOTIFIER ====================

class BookingNotifier extends StateNotifier<BookingState> {
  final BookingRepository _repository;
  final Ref _ref;

  BookingNotifier(this._repository, this._ref) : super(const BookingState());

  // ==================== CLIENT METHODS ====================

  // Load client's bookings
  Future<void> loadClientBookings() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final bookings = await _repository.getClientBookings(userId);
      state = state.copyWith(
        clientBookings: bookings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar reservas',
      );
    }
  }

  // Create new booking
  Future<String?> createBooking({
    required String supplierId,
    required String packageId,
    required String packageName,
    required String eventName,
    required DateTime eventDate,
    String? eventTime,
    String? eventLocation,
    required int totalPrice,
    String? notes,
    List<String>? selectedCustomizations,
    int? guestCount,
  }) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final now = DateTime.now();
      final booking = BookingModel(
        id: '',
        clientId: userId,
        supplierId: supplierId,
        packageId: packageId,
        packageName: packageName,
        eventName: eventName,
        eventDate: eventDate,
        eventTime: eventTime,
        eventLocation: eventLocation,
        totalPrice: totalPrice,
        notes: notes,
        selectedCustomizations: selectedCustomizations ?? [],
        guestCount: guestCount,
        createdAt: now,
        updatedAt: now,
      );

      final id = await _repository.createBooking(booking);
      
      // Reload bookings
      await loadClientBookings();
      
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Reserva criada com sucesso!',
      );
      
      return id;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao criar reserva',
      );
      return null;
    }
  }

  // Cancel booking (client)
  Future<bool> cancelBooking(String bookingId, String reason) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.updateBookingStatus(
        bookingId,
        BookingStatus.cancelled,
        reason: reason,
        cancelledBy: userId,
      );

      // Update local state
      final updatedBookings = state.clientBookings.map((b) {
        if (b.id == bookingId) {
          return b.copyWith(
            status: BookingStatus.cancelled,
            cancellationReason: reason,
            cancelledBy: userId,
            cancelledAt: DateTime.now(),
          );
        }
        return b;
      }).toList();

      state = state.copyWith(
        clientBookings: updatedBookings,
        isLoading: false,
        successMessage: 'Reserva cancelada',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao cancelar reserva',
      );
      return false;
    }
  }

  // ==================== SUPPLIER METHODS ====================

  // Load supplier's bookings
  Future<void> loadSupplierBookings(String supplierId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final bookings = await _repository.getSupplierBookings(supplierId);
      state = state.copyWith(
        supplierBookings: bookings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar pedidos',
      );
    }
  }

  // Confirm booking (supplier) - uses Cloud Function
  Future<bool> confirmBooking(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use Cloud Function instead of direct Firestore write
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('updateBookingStatus');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'newStatus': 'confirmed',
      });

      final response = result.data;
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to confirm booking');
      }

      Log.success('Booking $bookingId confirmed via Cloud Function');

      // Get the booking to find supplierId (null-safe lookup)
      final booking = state.supplierBookings.cast<BookingModel?>().firstWhere(
        (b) => b?.id == bookingId,
        orElse: () => state.clientBookings.cast<BookingModel?>().firstWhere(
          (b) => b?.id == bookingId,
          orElse: () => null,
        ),
      );

      // Update supplier stats for confirmed booking
      if (booking != null && booking.supplierId.isNotEmpty) {
        _ref.read(bookingStatsUpdateProvider).onBookingConfirmed(booking.supplierId);
      }

      // Note: Date blocking is now handled server-side in the Cloud Function
      // This ensures the date is blocked atomically with the booking confirmation
      // Reload availability to reflect the server-side changes
      _ref.read(availabilityProvider.notifier).loadAvailability();

      // Update local state
      final updatedBookings = state.supplierBookings.map((b) {
        if (b.id == bookingId) {
          return b.copyWith(
            status: BookingStatus.confirmed,
            confirmedAt: DateTime.now(),
          );
        }
        return b;
      }).toList();

      state = state.copyWith(
        supplierBookings: updatedBookings,
        isLoading: false,
        successMessage: 'Reserva confirmada!',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error confirming booking: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao confirmar reserva: ${e.toString()}',
      );
      return false;
    }
  }

  // Start booking / mark as in progress (supplier) - uses Cloud Function
  Future<bool> startBooking(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use Cloud Function instead of direct Firestore write
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('updateBookingStatus');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'newStatus': 'inProgress',
      });

      final response = result.data;
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to start booking');
      }

      debugPrint('✅ Booking $bookingId started via Cloud Function');

      // Update local state
      final updatedBookings = state.supplierBookings.map((b) {
        if (b.id == bookingId) {
          return b.copyWith(
            status: BookingStatus.inProgress,
            updatedAt: DateTime.now(),
          );
        }
        return b;
      }).toList();

      state = state.copyWith(
        supplierBookings: updatedBookings,
        isLoading: false,
        successMessage: 'Serviço iniciado!',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error starting booking: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao iniciar serviço: ${e.toString()}',
      );
      return false;
    }
  }

  // Mark booking as completed (supplier) - uses Cloud Function
  Future<bool> completeBooking(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use Cloud Function instead of direct Firestore write
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('updateBookingStatus');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'newStatus': 'completed',
      });

      final response = result.data;
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to complete booking');
      }

      Log.success('Booking $bookingId completed via Cloud Function');

      // Get the booking to find supplierId (null-safe lookup)
      final booking = state.supplierBookings.cast<BookingModel?>().firstWhere(
        (b) => b?.id == bookingId,
        orElse: () => state.clientBookings.cast<BookingModel?>().firstWhere(
          (b) => b?.id == bookingId,
          orElse: () => null,
        ),
      );

      // Update supplier stats for completed booking
      if (booking != null && booking.supplierId.isNotEmpty) {
        _ref.read(bookingStatsUpdateProvider).onBookingCompleted(booking.supplierId);
      }

      // Update local state
      final updatedBookings = state.supplierBookings.map((b) {
        if (b.id == bookingId) {
          return b.copyWith(
            status: BookingStatus.completed,
            completedAt: DateTime.now(),
          );
        }
        return b;
      }).toList();

      state = state.copyWith(
        supplierBookings: updatedBookings,
        isLoading: false,
        successMessage: 'Serviço concluído!',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error completing booking: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao concluir serviço: ${e.toString()}',
      );
      return false;
    }
  }

  // Reject booking (supplier) - uses Cloud Function
  Future<bool> rejectBooking(String bookingId, String reason) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use Cloud Function instead of direct Firestore write
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('updateBookingStatus');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'newStatus': 'cancelled',
      });

      final response = result.data;
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to reject booking');
      }

      debugPrint('✅ Booking $bookingId rejected via Cloud Function');

      // Update local state
      final updatedBookings = state.supplierBookings.map((b) {
        if (b.id == bookingId) {
          return b.copyWith(
            status: BookingStatus.cancelled,
            cancellationReason: reason,
            cancelledBy: userId,
            cancelledAt: DateTime.now(),
          );
        }
        return b;
      }).toList();

      state = state.copyWith(
        supplierBookings: updatedBookings,
        isLoading: false,
        successMessage: 'Pedido rejeitado',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting booking: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao rejeitar pedido: ${e.toString()}',
      );
      return false;
    }
  }

  // ==================== PAYMENTS ====================

  // Record payment
  Future<bool> recordPayment({
    required String bookingId,
    required int amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final payment = BookingPayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        method: method,
        reference: reference,
        paidAt: DateTime.now(),
        notes: notes,
      );

      await _repository.addPayment(bookingId, payment);

      // Reload bookings to get updated payment info
      await loadClientBookings();
      
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Pagamento registado!',
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao registar pagamento',
      );
      return false;
    }
  }

  // ==================== UTILITIES ====================

  // Get single booking
  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      return await _repository.getBooking(bookingId);
    } catch (e) {
      return null;
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ==================== PROVIDERS ====================

final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  final repository = ref.watch(bookingRepositoryProvider);
  return BookingNotifier(repository, ref);
});

// Convenience providers
final clientBookingsProvider = Provider<List<BookingModel>>((ref) {
  return ref.watch(bookingProvider).clientBookings;
});

final upcomingBookingsProvider = Provider<List<BookingModel>>((ref) {
  return ref.watch(bookingProvider).upcomingClientBookings;
});

final pastBookingsProvider = Provider<List<BookingModel>>((ref) {
  return ref.watch(bookingProvider).pastClientBookings;
});

final supplierBookingsProvider = Provider<List<BookingModel>>((ref) {
  return ref.watch(bookingProvider).supplierBookings;
});

final pendingBookingsProvider = Provider<List<BookingModel>>((ref) {
  return ref.watch(bookingProvider).pendingSupplierBookings;
});

// Single booking detail
final bookingDetailProvider = FutureProvider.family<BookingModel?, String>((ref, bookingId) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return await repository.getBooking(bookingId);
});

/// Real-time stream of client bookings for instant updates when supplier acts
///
/// @deprecated UI-FIRST VIOLATION: Use clientViewStreamProvider instead
/// This uses a deprecated repository method that reads directly from Firestore.
/// Migrate to: import 'package:boda_connect/core/providers/client_view_provider.dart';
///            final clientView = ref.watch(clientViewStreamProvider);
///            final bookings = clientView.value?.recentBookings ?? [];
// ignore: deprecated_member_use_from_same_package
final clientBookingsStreamProvider = StreamProvider<List<BookingModel>>((ref) {
  final userId = ref.watch(authProvider).firebaseUser?.uid;
  if (userId == null) return Stream.value([]);

  final repository = ref.watch(bookingRepositoryProvider);
  // ignore: deprecated_member_use_from_same_package
  return repository.streamClientBookings(userId);
});

// Booking stats for supplier
final supplierBookingStatsProvider = Provider<Map<String, int>>((ref) {
  final bookings = ref.watch(supplierBookingsProvider);
  
  return {
    'total': bookings.length,
    'pending': bookings.where((b) => b.status == BookingStatus.pending).length,
    'confirmed': bookings.where((b) => b.status == BookingStatus.confirmed).length,
    'completed': bookings.where((b) => b.status == BookingStatus.completed).length,
    'cancelled': bookings.where((b) => b.status == BookingStatus.cancelled).length,
  };
});

// Total revenue for supplier
final supplierRevenueProvider = Provider<int>((ref) {
  final bookings = ref.watch(supplierBookingsProvider);
  return bookings
      .where((b) => b.status == BookingStatus.completed)
      .fold(0, (sum, b) => sum + b.paidAmount);
});

// ==================== SUPPLIER BOOKINGS VIA CLOUD FUNCTIONS ====================
// SECURITY: Suppliers MUST NOT read bookings directly from Firestore
// All supplier booking data comes from backend-controlled Cloud Functions

/// State for supplier bookings loaded via Cloud Functions
class SupplierBookingsState {
  final List<BookingModel> bookings;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  const SupplierBookingsState({
    this.bookings = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
  });

  SupplierBookingsState copyWith({
    List<BookingModel>? bookings,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return SupplierBookingsState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

/// Notifier for supplier bookings - uses Cloud Functions for data access
class SupplierBookingsNotifier extends StateNotifier<SupplierBookingsState> {
  final Ref _ref;

  SupplierBookingsNotifier(this._ref) : super(const SupplierBookingsState());

  /// Load all supplier bookings via Cloud Function
  Future<void> loadBookings() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getSupplierBookings');

      final result = await callable.call<Map<String, dynamic>>({});
      final data = result.data;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Erro ao carregar reservas');
      }

      final bookingsList = (data['bookings'] as List<dynamic>?) ?? [];
      final bookings = bookingsList
          .map((b) => BookingModel.fromCloudFunction(b as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        bookings: bookings,
        isLoading: false,
        lastRefresh: DateTime.now(),
      );

      debugPrint('📋 Loaded ${bookings.length} supplier bookings via Cloud Function');
    } catch (e) {
      debugPrint('❌ Error loading supplier bookings: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar reservas',
      );
    }
  }

  /// Respond to a booking (confirm/reject) via Cloud Function
  Future<bool> respondToBooking(String bookingId, String action, {String? reason}) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('respondToBooking');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'action': action,
        'reason': reason,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Erro ao responder');
      }

      // Reload bookings to reflect the change
      await loadBookings();
      return true;
    } catch (e) {
      debugPrint('❌ Error responding to booking: $e');
      return false;
    }
  }

  /// Get booking details via Cloud Function
  Future<BookingModel?> getBookingDetails(String bookingId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getSupplierBookingDetails');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Erro ao carregar detalhes');
      }

      return BookingModel.fromCloudFunction(data['booking'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error getting booking details: $e');
      return null;
    }
  }
}

/// Provider for supplier bookings state notifier
final supplierBookingsNotifierProvider =
    StateNotifierProvider<SupplierBookingsNotifier, SupplierBookingsState>((ref) {
  return SupplierBookingsNotifier(ref);
});

/// Stream-like provider that auto-loads supplier bookings
/// Use this in place of the old supplierBookingsStreamProvider
final supplierBookingsStreamProvider = StreamProvider<List<BookingModel>>((ref) {
  // Watch the notifier state
  final state = ref.watch(supplierBookingsNotifierProvider);

  // Auto-load on first access if not loaded
  if (state.bookings.isEmpty && !state.isLoading && state.error == null && state.lastRefresh == null) {
    Future.microtask(() {
      ref.read(supplierBookingsNotifierProvider.notifier).loadBookings();
    });
  }

  // Return a stream that emits the current bookings
  return Stream.value(state.bookings);
});

/// Real-time count of pending bookings for supplier (for notification badge)
final pendingBookingsCountProvider = Provider<int>((ref) {
  final bookingsAsync = ref.watch(supplierBookingsStreamProvider);

  return bookingsAsync.when(
    data: (bookings) => bookings
        .where((b) => b.status == BookingStatus.pending)
        .length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Real-time upcoming events for supplier (CONFIRMED and IN_PROGRESS bookings only)
/// IMPORTANT: Agenda must NOT include pending bookings - only confirmed events
final upcomingEventsStreamProvider = Provider<List<BookingModel>>((ref) {
  final bookingsAsync = ref.watch(supplierBookingsStreamProvider);
  final now = DateTime.now();

  return bookingsAsync.when(
    data: (bookings) {
      // FIXED: Agenda only includes confirmed/inProgress, NOT pending
      final upcoming = bookings
          .where((b) =>
              (b.status == BookingStatus.confirmed ||
               b.status == BookingStatus.inProgress) &&
              b.eventDate.isAfter(now))
          .toList()
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      return upcoming.take(10).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Real-time recent orders for supplier (last 5 bookings by creation date)
final recentOrdersStreamProvider = Provider<List<BookingModel>>((ref) {
  final bookingsAsync = ref.watch(supplierBookingsStreamProvider);

  return bookingsAsync.when(
    data: (bookings) {
      final sorted = List<BookingModel>.from(bookings)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted.take(5).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ==================== CONTACT REVEAL PROVIDERS ====================

/// Check if the current user (client) has a confirmed or completed booking with a supplier
/// This is used to control contact info visibility (like Uber/Lyft model)
final hasConfirmedBookingWithSupplierProvider = FutureProvider.family<bool, String>((ref, supplierId) async {
  final userId = ref.watch(authProvider).firebaseUser?.uid;
  if (userId == null) return false;

  try {
    // Query for any confirmed or completed booking between client and supplier
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: userId)
        .where('supplierId', isEqualTo: supplierId)
        .where('status', whereIn: ['confirmed', 'completed', 'inProgress'])
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  } catch (e) {
    // In case of error, default to hiding contact info
    return false;
  }
});

/// Result class for contact visibility check
class ContactVisibility {
  final bool canSeePhone;
  final bool canSeeWhatsapp;
  final bool canSeeEmail;
  final bool hasActiveBooking;
  final String? message;

  const ContactVisibility({
    this.canSeePhone = false,
    this.canSeeWhatsapp = false,
    this.canSeeEmail = false,
    this.hasActiveBooking = false,
    this.message,
  });

  bool get canSeeAnyContact => canSeePhone || canSeeWhatsapp || canSeeEmail;
}

/// Provider that returns detailed contact visibility status for a supplier
final supplierContactVisibilityProvider = FutureProvider.family<ContactVisibility, String>((ref, supplierId) async {
  final hasBooking = await ref.watch(hasConfirmedBookingWithSupplierProvider(supplierId).future);

  if (hasBooking) {
    return const ContactVisibility(
      canSeePhone: true,
      canSeeWhatsapp: true,
      canSeeEmail: true,
      hasActiveBooking: true,
      message: null,
    );
  }

  return const ContactVisibility(
    canSeePhone: false,
    canSeeWhatsapp: false,
    canSeeEmail: false,
    hasActiveBooking: false,
    message: 'Informações de contacto disponíveis após reserva confirmada',
  );
});