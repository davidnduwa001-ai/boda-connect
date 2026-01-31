import 'package:flutter_test/flutter_test.dart';
import 'package:boda_connect/core/providers/supplier_view_provider.dart';

/// SupplierViewProvider Tests
/// Tests for SupplierView models and providers
void main() {
  group('SupplierBookingSummary Tests', () {
    test('should create from map with all fields', () {
      final data = {
        'bookingId': 'booking-123',
        'clientId': 'client-456',
        'clientName': 'João Silva',
        'clientPhotoUrl': 'https://example.com/photo.jpg',
        'eventName': 'Casamento',
        'eventDate': null, // Will use DateTime.now() as fallback
        'eventLocation': 'Luanda',
        'status': 'pending',
        'totalAmount': 150000,
        'currency': 'AOA',
        'uiFlags': {
          'canAccept': true,
          'canDecline': true,
        },
        'createdAt': null,
      };

      final summary = SupplierBookingSummary.fromMap(data);

      expect(summary.bookingId, 'booking-123');
      expect(summary.clientId, 'client-456');
      expect(summary.clientName, 'João Silva');
      expect(summary.eventName, 'Casamento');
      expect(summary.eventLocation, 'Luanda');
      expect(summary.status, 'pending');
      expect(summary.totalAmount, 150000);
      expect(summary.currency, 'AOA');
    });

    test('should use defaults for missing fields', () {
      final data = <String, dynamic>{};

      final summary = SupplierBookingSummary.fromMap(data);

      expect(summary.bookingId, '');
      expect(summary.clientId, '');
      expect(summary.clientName, 'Cliente');
      expect(summary.eventName, 'Evento');
      expect(summary.status, 'pending');
      expect(summary.totalAmount, 0);
      expect(summary.currency, 'AOA');
    });
  });

  group('SupplierBookingUIFlags Tests', () {
    test('should create from map with all flags', () {
      final data = {
        'canAccept': true,
        'canDecline': true,
        'canComplete': false,
        'canCancel': false,
        'canMessage': true,
        'canViewDetails': true,
        'showExpiringSoon': true,
        'showPaymentReceived': false,
      };

      final flags = SupplierBookingUIFlags.fromMap(data);

      expect(flags.canAccept, isTrue);
      expect(flags.canDecline, isTrue);
      expect(flags.canComplete, isFalse);
      expect(flags.canCancel, isFalse);
      expect(flags.canMessage, isTrue);
      expect(flags.canViewDetails, isTrue);
      expect(flags.showExpiringSoon, isTrue);
      expect(flags.showPaymentReceived, isFalse);
    });

    test('should use defaults for missing flags', () {
      final flags = SupplierBookingUIFlags.fromMap({});

      expect(flags.canAccept, isFalse);
      expect(flags.canDecline, isFalse);
      expect(flags.canComplete, isFalse);
      expect(flags.canCancel, isFalse);
      expect(flags.canMessage, isTrue); // Default true
      expect(flags.canViewDetails, isTrue); // Default true
    });
  });

  group('SupplierEventSummary Tests', () {
    test('should create from map with eventTime', () {
      final data = {
        'bookingId': 'booking-123',
        'clientName': 'Maria Santos',
        'eventName': 'Aniversário',
        'eventTime': '14:30',
        'eventLocation': 'Benguela',
        'status': 'confirmed',
      };

      final event = SupplierEventSummary.fromMap(data);

      expect(event.bookingId, 'booking-123');
      expect(event.clientName, 'Maria Santos');
      expect(event.eventName, 'Aniversário');
      expect(event.eventTime, '14:30');
      expect(event.eventLocation, 'Benguela');
      expect(event.status, 'confirmed');
    });

    test('should handle null eventTime', () {
      final data = {
        'bookingId': 'booking-123',
        'clientName': 'Test Client',
        'eventName': 'Event',
        'status': 'pending',
      };

      final event = SupplierEventSummary.fromMap(data);

      expect(event.eventTime, isNull);
    });
  });

  group('SupplierDashboardStats Tests', () {
    test('should create from map', () {
      final data = {
        'totalBookings': 50,
        'completedBookings': 40,
        'cancelledBookings': 5,
        'averageRating': 4.7,
        'totalReviews': 35,
        'responseRate': 95.5,
        'responseTimeMinutes': 30,
      };

      final stats = SupplierDashboardStats.fromMap(data);

      expect(stats.totalBookings, 50);
      expect(stats.completedBookings, 40);
      expect(stats.cancelledBookings, 5);
      expect(stats.averageRating, 4.7);
      expect(stats.totalReviews, 35);
      expect(stats.responseRate, 95.5);
      expect(stats.responseTimeMinutes, 30);
    });

    test('should use zero defaults', () {
      final stats = SupplierDashboardStats.fromMap({});

      expect(stats.totalBookings, 0);
      expect(stats.completedBookings, 0);
      expect(stats.averageRating, 0);
      expect(stats.totalReviews, 0);
    });
  });

  group('SupplierAccountFlags Tests', () {
    test('should create from map', () {
      final data = {
        'isActive': true,
        'isVerified': true,
        'isBookable': true,
        'isPaused': false,
        'hasPayoutSetup': true,
        'showVerificationNeeded': false,
        'showPayoutSetupNeeded': false,
        'showRateLimitWarning': false,
      };

      final flags = SupplierAccountFlags.fromMap(data);

      expect(flags.isActive, isTrue);
      expect(flags.isVerified, isTrue);
      expect(flags.isBookable, isTrue);
      expect(flags.isPaused, isFalse);
      expect(flags.hasPayoutSetup, isTrue);
      expect(flags.showVerificationNeeded, isFalse);
    });

    test('should use safe defaults', () {
      final flags = SupplierAccountFlags.fromMap({});

      expect(flags.isActive, isFalse);
      expect(flags.isVerified, isFalse);
      expect(flags.isBookable, isFalse);
      expect(flags.showVerificationNeeded, isTrue); // Warn by default
      expect(flags.showPayoutSetupNeeded, isTrue); // Warn by default
    });
  });

  group('SupplierEarningsSummary Tests', () {
    test('should create from map', () {
      final data = {
        'thisMonth': 500000.0,
        'pendingPayout': 150000.0,
        'totalEarned': 2500000.0,
        'currency': 'AOA',
      };

      final earnings = SupplierEarningsSummary.fromMap(data);

      expect(earnings.thisMonth, 500000.0);
      expect(earnings.pendingPayout, 150000.0);
      expect(earnings.totalEarned, 2500000.0);
      expect(earnings.currency, 'AOA');
    });

    test('should use zero defaults', () {
      final earnings = SupplierEarningsSummary.fromMap({});

      expect(earnings.thisMonth, 0);
      expect(earnings.pendingPayout, 0);
      expect(earnings.totalEarned, 0);
      expect(earnings.currency, 'AOA');
    });
  });

  group('SupplierAvailabilitySummary Tests', () {
    test('should create from map', () {
      final data = {
        'availableThisMonth': 20,
        'reservedThisMonth': 8,
        'blockedThisMonth': 2,
        'requestedThisMonth': 5,
      };

      final availability = SupplierAvailabilitySummary.fromMap(data);

      expect(availability.availableThisMonth, 20);
      expect(availability.reservedThisMonth, 8);
      expect(availability.blockedThisMonth, 2);
      expect(availability.requestedThisMonth, 5);
    });
  });

  group('SupplierBlockedDateSummary Tests', () {
    test('should create from map', () {
      final data = {
        'id': 'blocked-123',
        'type': 'manual',
        'reason': 'Férias',
        'bookingId': null,
        'canUnblock': true,
      };

      final blocked = SupplierBlockedDateSummary.fromMap(data);

      expect(blocked.id, 'blocked-123');
      expect(blocked.type, 'manual');
      expect(blocked.reason, 'Férias');
      expect(blocked.bookingId, isNull);
      expect(blocked.canUnblock, isTrue);
    });

    test('should handle booking-blocked type', () {
      final data = {
        'id': 'blocked-456',
        'type': 'booking',
        'reason': 'Reserva confirmada',
        'bookingId': 'booking-789',
        'canUnblock': false,
      };

      final blocked = SupplierBlockedDateSummary.fromMap(data);

      expect(blocked.type, 'booking');
      expect(blocked.bookingId, 'booking-789');
      expect(blocked.canUnblock, isFalse);
    });
  });

  group('SupplierViewState Tests', () {
    test('should create with defaults', () {
      const state = SupplierViewState();

      expect(state.view, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should copy with new values', () {
      const state = SupplierViewState(isLoading: true);
      final newState = state.copyWith(isLoading: false, error: 'Test error');

      expect(newState.isLoading, isFalse);
      expect(newState.error, 'Test error');
    });
  });
}
