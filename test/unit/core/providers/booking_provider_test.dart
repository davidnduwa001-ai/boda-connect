import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/providers/booking_provider.dart';

/// Booking Provider Tests
/// Tests for BookingState, BookingNotifier, and derived providers
void main() {
  group('BookingState Tests', () {
    test('should create empty BookingState with defaults', () {
      const state = BookingState();

      expect(state.clientBookings, isEmpty);
      expect(state.supplierBookings, isEmpty);
      expect(state.currentBooking, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.successMessage, isNull);
    });

    test('should copy state with new values', () {
      const state = BookingState();
      final newState = state.copyWith(
        isLoading: true,
        error: 'Test error',
      );

      expect(newState.isLoading, isTrue);
      expect(newState.error, 'Test error');
      expect(newState.clientBookings, isEmpty);
    });

    test('should clear error when copying with null', () {
      final state = const BookingState().copyWith(error: 'Error');
      final clearedState = state.copyWith(error: null);

      expect(clearedState.error, isNull);
    });

    test('should update success message', () {
      const state = BookingState();
      final updated = state.copyWith(successMessage: 'Reserva criada!');

      expect(updated.successMessage, 'Reserva criada!');
    });

    test('should update current booking', () {
      const state = BookingState();
      final booking = _createBooking('test-1', BookingStatus.pending);
      final updated = state.copyWith(currentBooking: booking);

      expect(updated.currentBooking, isNotNull);
      expect(updated.currentBooking?.id, 'test-1');
    });
  });

  group('BookingState Filtered Lists Tests', () {
    test('upcomingClientBookings should filter pending and confirmed', () {
      final bookings = [
        _createBooking('1', BookingStatus.pending),
        _createBooking('2', BookingStatus.confirmed),
        _createBooking('3', BookingStatus.completed),
        _createBooking('4', BookingStatus.cancelled),
      ];

      final state = BookingState(clientBookings: bookings);
      final upcoming = state.upcomingClientBookings;

      expect(upcoming.length, 2);
      expect(upcoming.any((b) => b.id == '1'), isTrue);
      expect(upcoming.any((b) => b.id == '2'), isTrue);
      expect(upcoming.any((b) => b.id == '3'), isFalse);
    });

    test('pastClientBookings should filter completed and cancelled', () {
      final bookings = [
        _createBooking('1', BookingStatus.pending),
        _createBooking('2', BookingStatus.confirmed),
        _createBooking('3', BookingStatus.completed),
        _createBooking('4', BookingStatus.cancelled),
      ];

      final state = BookingState(clientBookings: bookings);
      final past = state.pastClientBookings;

      expect(past.length, 2);
      expect(past.any((b) => b.id == '3'), isTrue);
      expect(past.any((b) => b.id == '4'), isTrue);
    });

    test('pendingSupplierBookings should filter pending only', () {
      final bookings = [
        _createBooking('1', BookingStatus.pending),
        _createBooking('2', BookingStatus.pending),
        _createBooking('3', BookingStatus.confirmed),
      ];

      final state = BookingState(supplierBookings: bookings);
      final pending = state.pendingSupplierBookings;

      expect(pending.length, 2);
    });

    test('confirmedSupplierBookings should filter confirmed only', () {
      final bookings = [
        _createBooking('1', BookingStatus.pending),
        _createBooking('2', BookingStatus.confirmed),
        _createBooking('3', BookingStatus.confirmed),
      ];

      final state = BookingState(supplierBookings: bookings);
      final confirmed = state.confirmedSupplierBookings;

      expect(confirmed.length, 2);
    });

    test('should handle empty bookings list', () {
      const state = BookingState();

      expect(state.upcomingClientBookings, isEmpty);
      expect(state.pastClientBookings, isEmpty);
      expect(state.pendingSupplierBookings, isEmpty);
      expect(state.confirmedSupplierBookings, isEmpty);
    });

    test('should filter inProgress bookings correctly', () {
      final bookings = [
        _createBooking('1', BookingStatus.pending),
        _createBooking('2', BookingStatus.inProgress),
        _createBooking('3', BookingStatus.confirmed),
      ];

      final state = BookingState(supplierBookings: bookings);

      // inProgress should NOT be in pending
      expect(state.pendingSupplierBookings.length, 1);
      expect(state.pendingSupplierBookings.first.id, '1');

      // inProgress should NOT be in confirmed
      expect(state.confirmedSupplierBookings.length, 1);
      expect(state.confirmedSupplierBookings.first.id, '3');
    });
  });

  group('SupplierBookingsState Tests', () {
    test('should create empty state', () {
      const state = SupplierBookingsState();

      expect(state.bookings, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.lastRefresh, isNull);
    });

    test('copyWith should preserve unset values', () {
      final now = DateTime.now();
      final state = SupplierBookingsState(
        bookings: [_createBooking('1', BookingStatus.pending)],
        isLoading: false,
        lastRefresh: now,
      );

      final newState = state.copyWith(isLoading: true);

      expect(newState.isLoading, isTrue);
      expect(newState.bookings.length, 1);
      expect(newState.lastRefresh, now);
    });

    test('copyWith should clear error when set to null', () {
      final state = SupplierBookingsState(
        error: 'Some error',
        isLoading: false,
      );

      final clearedState = state.copyWith(error: null);
      expect(clearedState.error, isNull);
    });

    test('should update bookings list', () {
      const state = SupplierBookingsState();
      final bookings = [
        _createBooking('1', BookingStatus.pending),
        _createBooking('2', BookingStatus.confirmed),
      ];

      final updated = state.copyWith(bookings: bookings);
      expect(updated.bookings.length, 2);
    });

    test('should track last refresh time', () {
      final now = DateTime.now();
      final state = SupplierBookingsState(lastRefresh: now);

      expect(state.lastRefresh, now);
    });
  });

  group('BookingUIFlags Tests', () {
    test('should create with defaults', () {
      const flags = BookingUIFlags();

      expect(flags.canAccept, isFalse);
      expect(flags.canDecline, isFalse);
      expect(flags.canComplete, isFalse);
      expect(flags.canCancel, isFalse);
      expect(flags.canMessage, isTrue);
      expect(flags.canViewDetails, isTrue);
      expect(flags.showExpiringSoon, isFalse);
      expect(flags.showPaymentReceived, isFalse);
    });

    test('should create from map', () {
      final flags = BookingUIFlags.fromMap({
        'canAccept': true,
        'canDecline': true,
        'canComplete': false,
        'showExpiringSoon': true,
      });

      expect(flags.canAccept, isTrue);
      expect(flags.canDecline, isTrue);
      expect(flags.canComplete, isFalse);
      expect(flags.showExpiringSoon, isTrue);
    });

    test('should use defaults for missing map values', () {
      final flags = BookingUIFlags.fromMap({});

      expect(flags.canAccept, isFalse);
      expect(flags.canMessage, isTrue);
      expect(flags.canViewDetails, isTrue);
    });
  });

  group('BookingStatus Tests', () {
    test('should have all expected statuses', () {
      expect(BookingStatus.values.length, 7);
      expect(BookingStatus.values.contains(BookingStatus.pending), isTrue);
      expect(BookingStatus.values.contains(BookingStatus.confirmed), isTrue);
      expect(BookingStatus.values.contains(BookingStatus.inProgress), isTrue);
      expect(BookingStatus.values.contains(BookingStatus.completed), isTrue);
      expect(BookingStatus.values.contains(BookingStatus.cancelled), isTrue);
      expect(BookingStatus.values.contains(BookingStatus.disputed), isTrue);
      expect(BookingStatus.values.contains(BookingStatus.refunded), isTrue);
    });
  });

  group('ContactVisibility Tests', () {
    test('should create with defaults', () {
      const visibility = ContactVisibility();

      expect(visibility.canSeePhone, isFalse);
      expect(visibility.canSeeWhatsapp, isFalse);
      expect(visibility.canSeeEmail, isFalse);
      expect(visibility.hasActiveBooking, isFalse);
      expect(visibility.canSeeAnyContact, isFalse);
    });

    test('canSeeAnyContact should return true when any contact visible', () {
      const visibility = ContactVisibility(canSeePhone: true);

      expect(visibility.canSeeAnyContact, isTrue);
    });

    test('should show message when no active booking', () {
      const visibility = ContactVisibility(
        hasActiveBooking: false,
        message: 'Informações de contacto disponíveis após reserva confirmada',
      );

      expect(visibility.message, isNotNull);
      expect(visibility.message, contains('reserva confirmada'));
    });

    test('should allow all contacts with active booking', () {
      const visibility = ContactVisibility(
        canSeePhone: true,
        canSeeWhatsapp: true,
        canSeeEmail: true,
        hasActiveBooking: true,
      );

      expect(visibility.canSeeAnyContact, isTrue);
      expect(visibility.hasActiveBooking, isTrue);
    });
  });
}

/// Helper to create test booking with all required fields
BookingModel _createBooking(String id, BookingStatus status) {
  final now = DateTime.now();
  return BookingModel(
    id: id,
    clientId: 'client-1',
    supplierId: 'supplier-1',
    packageId: 'package-1',
    eventName: 'Test Event',
    status: status,
    totalPrice: 100000,
    eventDate: now.add(const Duration(days: 30)),
    createdAt: now,
    updatedAt: now,
  );
}
