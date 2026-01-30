import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    test('shouldRefresh returns true when lastRefresh is null', () {
      const state = SupplierBookingsState();
      expect(state.shouldRefresh, isTrue);
    });

    test('shouldRefresh returns true after stale duration', () {
      final staleTime = DateTime.now().subtract(const Duration(minutes: 10));
      final state = SupplierBookingsState(lastRefresh: staleTime);

      expect(state.shouldRefresh, isTrue);
    });

    test('shouldRefresh returns false when fresh', () {
      final freshTime = DateTime.now().subtract(const Duration(seconds: 30));
      final state = SupplierBookingsState(lastRefresh: freshTime);

      expect(state.shouldRefresh, isFalse);
    });
  });
}

/// Helper to create test booking
BookingModel _createBooking(String id, BookingStatus status) {
  return BookingModel(
    id: id,
    clientId: 'client-1',
    supplierId: 'supplier-1',
    packageId: 'package-1',
    status: status,
    totalPrice: 100000,
    eventDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now(),
  );
}
