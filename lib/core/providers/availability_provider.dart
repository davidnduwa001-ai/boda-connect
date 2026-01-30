import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';

// ==================== AVAILABILITY MODELS ====================

enum BlockedType { reserved, blocked, unavailable, requested }

class BlockedDate {
  final String id;
  final DateTime date;
  final String reason;
  final BlockedType type;
  final String? bookingId;
  final DateTime createdAt;

  const BlockedDate({
    required this.id,
    required this.date,
    required this.reason,
    required this.type,
    this.bookingId,
    required this.createdAt,
  });

  factory BlockedDate.fromFirestore(Map<String, dynamic> data, String id) {
    return BlockedDate(
      id: id,
      date: (data['date'] as Timestamp).toDate(),
      reason: data['reason'] as String? ?? '',
      type: _parseBlockedType(data['type'] as String?),
      bookingId: data['bookingId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'reason': reason,
      'type': type.name,
      'bookingId': bookingId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static BlockedType _parseBlockedType(String? value) {
    switch (value) {
      case 'reserved':
        return BlockedType.reserved;
      case 'blocked':
        return BlockedType.blocked;
      case 'unavailable':
        return BlockedType.unavailable;
      case 'requested':
        return BlockedType.requested;
      default:
        return BlockedType.blocked;
    }
  }
}

// ==================== AVAILABILITY STATE ====================

class AvailabilityState {
  final List<BlockedDate> blockedDates;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const AvailabilityState({
    this.blockedDates = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AvailabilityState copyWith({
    List<BlockedDate>? blockedDates,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return AvailabilityState(
      blockedDates: blockedDates ?? this.blockedDates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }

  // Calculate stats
  int get totalAvailable {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = endOfMonth.day;
    return daysInMonth - blockedDates.where((d) => d.date.month == now.month).length;
  }

  int get reservedCount {
    final now = DateTime.now();
    return blockedDates
        .where((d) => d.type == BlockedType.reserved && d.date.month == now.month)
        .length;
  }

  int get requestedCount {
    final now = DateTime.now();
    return blockedDates
        .where((d) => d.type == BlockedType.requested && d.date.month == now.month)
        .length;
  }

  int get blockedCount {
    final now = DateTime.now();
    return blockedDates
        .where((d) => d.type != BlockedType.reserved && d.type != BlockedType.requested && d.date.month == now.month)
        .length;
  }

  bool isDateBlocked(DateTime date) {
    return blockedDates.any((bd) =>
        bd.date.year == date.year &&
        bd.date.month == date.month &&
        bd.date.day == date.day);
  }
}

// ==================== AVAILABILITY NOTIFIER ====================

class AvailabilityNotifier extends StateNotifier<AvailabilityState> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AvailabilityNotifier(this._ref) : super(const AvailabilityState());

  // Load blocked dates for supplier
  Future<void> loadAvailability() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load supplier first if not already loaded
      final currentSupplier = _ref.read(supplierProvider).currentSupplier;
      if (currentSupplier == null) {
        await _ref.read(supplierProvider.notifier).loadCurrentSupplier();
      }

      final supplier = _ref.read(supplierProvider).currentSupplier;
      if (supplier == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Fornecedor não encontrado',
        );
        return;
      }

      final supplierId = supplier.id;
      final supplierAuthUid = supplier.userId;

      debugPrint('📅 Loading availability for supplierId=$supplierId, authUid=$supplierAuthUid');

      final snapshot = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .orderBy('date', descending: false)
          .get();

      final blockedDates = snapshot.docs
          .map((doc) => BlockedDate.fromFirestore(doc.data(), doc.id))
          .toList();

      // SECURITY: Booking data must come from Cloud Functions, not direct Firestore queries
      // Get booking IDs already in blocked_dates to avoid duplicates
      final blockedBookingIds = blockedDates
          .where((d) => d.bookingId != null)
          .map((d) => d.bookingId!)
          .toSet();

      // Get booking data via Cloud Function (secure)
      final bookingDatesFromCF = await _loadBookingDatesViaCloudFunction(blockedBookingIds);

      debugPrint('📅 Total dates from Cloud Function: ${bookingDatesFromCF.length}');

      // Combine blocked dates with booking dates from Cloud Function
      final allDates = [...blockedDates, ...bookingDatesFromCF];

      state = state.copyWith(
        blockedDates: allDates,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading availability: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar disponibilidade: $e',
      );
    }
  }

  /// Load booking dates via Cloud Function (secure - no direct Firestore access)
  /// Returns BlockedDate entries for pending and confirmed bookings
  Future<List<BlockedDate>> _loadBookingDatesViaCloudFunction(Set<String> existingBookingIds) async {
    final List<BlockedDate> bookingDates = [];

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getSupplierBookings');

      final result = await callable.call({});

      // Safely decode Cloud Function response (handles _Map<Object?, Object?>)
      final rawData = result.data;
      if (rawData == null) {
        debugPrint('⚠️ Cloud Function returned null data');
        return [];
      }

      // Convert to proper Map<String, dynamic>
      final Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        debugPrint('⚠️ Cloud Function returned unexpected type: ${rawData.runtimeType}');
        return [];
      }

      if (data['success'] != true) {
        debugPrint('⚠️ Cloud Function returned error: ${data['error']}');
        return [];
      }

      final rawBookingsList = data['bookings'];
      if (rawBookingsList == null || rawBookingsList is! List) {
        return [];
      }

      for (final booking in rawBookingsList) {
        // Safely convert each booking to Map<String, dynamic>
        final Map<String, dynamic> bookingMap;
        if (booking is Map<String, dynamic>) {
          bookingMap = booking;
        } else if (booking is Map) {
          bookingMap = Map<String, dynamic>.from(booking);
        } else {
          continue; // Skip invalid entries
        }
        final bookingId = bookingMap['id'] as String?;

        // Skip if already in blocked_dates
        if (bookingId == null || existingBookingIds.contains(bookingId)) continue;

        final status = bookingMap['status'] as String?;
        final eventDateStr = bookingMap['eventDate'] as String?;
        final eventName = bookingMap['eventName'] as String? ?? 'Reserva';
        final createdAtStr = bookingMap['createdAt'] as String?;

        if (eventDateStr == null) continue;

        final eventDate = DateTime.tryParse(eventDateStr);
        final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

        if (eventDate == null) continue;

        // Determine type based on status
        BlockedType type;
        String reason;
        if (status == 'pending') {
          type = BlockedType.requested;
          reason = eventName.isNotEmpty ? eventName : 'Pedido pendente';
        } else if (status == 'confirmed' || status == 'inProgress') {
          type = BlockedType.reserved;
          reason = eventName.isNotEmpty ? eventName : 'Reserva confirmada';
        } else {
          continue; // Skip other statuses
        }

        bookingDates.add(BlockedDate(
          id: 'booking_${bookingId}',
          date: eventDate,
          reason: reason,
          type: type,
          bookingId: bookingId,
          createdAt: createdAt ?? DateTime.now(),
        ));
      }

      debugPrint('📅 Loaded ${bookingDates.length} booking dates via Cloud Function');
    } catch (e) {
      debugPrint('⚠️ Error loading booking dates via CF: $e');
      // Return empty list on error - blocked_dates will still work
    }

    return bookingDates;
  }

  // Block a date
  Future<bool> blockDate({
    required DateTime date,
    required String reason,
    required BlockedType type,
    String? bookingId,
  }) async {
    final supplierId = _ref.read(supplierProvider).currentSupplier?.id;
    if (supplierId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final now = DateTime.now();
      final blockedDate = BlockedDate(
        id: '',
        date: date,
        reason: reason,
        type: type,
        bookingId: bookingId,
        createdAt: now,
      );

      await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .add(blockedDate.toFirestore());

      // Reload availability
      await loadAvailability();

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Data bloqueada com sucesso',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao bloquear data',
      );
      return false;
    }
  }

  // Unblock a date
  Future<bool> unblockDate(String blockedDateId) async {
    final supplierId = _ref.read(supplierProvider).currentSupplier?.id;
    if (supplierId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .doc(blockedDateId)
          .delete();

      // Update local state
      state = state.copyWith(
        blockedDates: state.blockedDates.where((d) => d.id != blockedDateId).toList(),
        isLoading: false,
        successMessage: 'Data desbloqueada',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao desbloquear data',
      );
      return false;
    }
  }

  // Block date from booking confirmation
  Future<bool> blockDateFromBooking({
    required String bookingId,
    required DateTime eventDate,
    required String eventName,
  }) async {
    return await blockDate(
      date: eventDate,
      reason: eventName,
      type: BlockedType.reserved,
      bookingId: bookingId,
    );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ==================== PROVIDERS ====================

final availabilityProvider = StateNotifierProvider<AvailabilityNotifier, AvailabilityState>((ref) {
  return AvailabilityNotifier(ref);
});

// Check if specific date is available
final isDateAvailableProvider = Provider.family<bool, DateTime>((ref, date) {
  return !ref.watch(availabilityProvider).isDateBlocked(date);
});

// Get blocked dates list
final blockedDatesProvider = Provider<List<BlockedDate>>((ref) {
  return ref.watch(availabilityProvider).blockedDates;
});

// Get availability stats
final availabilityStatsProvider = Provider<Map<String, int>>((ref) {
  final state = ref.watch(availabilityProvider);
  return {
    'available': state.totalAvailable,
    'reserved': state.reservedCount,
    'requested': state.requestedCount,
    'blocked': state.blockedCount,
  };
});

// ==================== CLIENT-FACING BLOCKED DATES ====================

/// Provider to fetch blocked dates for a specific supplier (used by clients)
/// This is a FutureProvider.family that fetches blocked dates for any supplier
final supplierBlockedDatesProvider = FutureProvider.family<List<DateTime>, String>((ref, supplierId) async {
  if (supplierId.isEmpty) return [];

  try {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('suppliers')
        .doc(supplierId)
        .collection('blocked_dates')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .get();

    final blockedDates = snapshot.docs.map((doc) {
      final data = doc.data();
      return (data['date'] as Timestamp).toDate();
    }).toList();

    debugPrint('📅 Loaded ${blockedDates.length} blocked dates for supplier $supplierId');
    return blockedDates;
  } catch (e) {
    debugPrint('❌ Error loading blocked dates for supplier $supplierId: $e');
    return [];
  }
});

/// Check if a specific date is blocked for a supplier (used by clients)
bool isDateBlockedForSupplier(List<DateTime> blockedDates, DateTime date) {
  return blockedDates.any((bd) =>
      bd.year == date.year &&
      bd.month == date.month &&
      bd.day == date.day);
}
