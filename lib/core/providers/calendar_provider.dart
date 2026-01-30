import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/calendar_service.dart';
import '../models/booking_model.dart';

// ==================== CALENDAR SERVICE PROVIDER ====================

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

// ==================== CALENDAR STATE ====================

class CalendarState {
  final bool isAdding;
  final String? error;
  final String? successMessage;
  final Set<String> addedBookingIds;

  const CalendarState({
    this.isAdding = false,
    this.error,
    this.successMessage,
    this.addedBookingIds = const {},
  });

  CalendarState copyWith({
    bool? isAdding,
    String? error,
    String? successMessage,
    Set<String>? addedBookingIds,
  }) {
    return CalendarState(
      isAdding: isAdding ?? this.isAdding,
      error: error,
      successMessage: successMessage,
      addedBookingIds: addedBookingIds ?? this.addedBookingIds,
    );
  }

  bool isBookingAdded(String bookingId) => addedBookingIds.contains(bookingId);
}

// ==================== CALENDAR NOTIFIER ====================

class CalendarNotifier extends StateNotifier<CalendarState> {
  final CalendarService _calendarService;

  CalendarNotifier(this._calendarService) : super(const CalendarState());

  /// Add a booking to device calendar
  Future<bool> addBookingToCalendar(BookingModel booking) async {
    state = state.copyWith(isAdding: true, error: null, successMessage: null);

    try {
      final success = await _calendarService.addBookingToCalendar(
        eventName: booking.packageName ?? 'Evento',
        supplierName: booking.supplierName ?? 'Fornecedor',
        packageName: booking.packageName ?? 'Pacote',
        eventDate: booking.eventDate,
        eventTime: booking.eventTime,
        eventLocation: booking.eventLocation,
        clientName: booking.clientName,
        totalPrice: booking.totalPrice,
      );

      if (success) {
        // Mark booking as added to calendar
        final updatedIds = {...state.addedBookingIds, booking.id};
        state = state.copyWith(
          isAdding: false,
          successMessage: 'Evento adicionado ao calendário',
          addedBookingIds: updatedIds,
        );
      } else {
        state = state.copyWith(
          isAdding: false,
          error: 'Não foi possível abrir o calendário',
        );
      }

      return success;
    } catch (e) {
      state = state.copyWith(
        isAdding: false,
        error: 'Erro ao adicionar ao calendário: $e',
      );
      return false;
    }
  }

  /// Add custom event to calendar
  Future<bool> addCustomEvent({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
  }) async {
    state = state.copyWith(isAdding: true, error: null, successMessage: null);

    try {
      final success = await _calendarService.addToCalendar(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        location: location,
      );

      if (success) {
        state = state.copyWith(
          isAdding: false,
          successMessage: 'Evento adicionado ao calendário',
        );
      } else {
        state = state.copyWith(
          isAdding: false,
          error: 'Não foi possível abrir o calendário',
        );
      }

      return success;
    } catch (e) {
      state = state.copyWith(
        isAdding: false,
        error: 'Erro ao adicionar ao calendário: $e',
      );
      return false;
    }
  }

  /// Generate ICS file content for download
  String generateIcsForBooking(BookingModel booking) {
    final startDate = booking.eventDate;
    DateTime parsedStart = startDate;

    // Parse time if available
    if (booking.eventTime != null && booking.eventTime!.isNotEmpty) {
      final timeParts = booking.eventTime!.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        parsedStart = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          hour,
          minute,
        );
      }
    }

    final endDate = parsedStart.add(const Duration(hours: 3));

    return _calendarService.generateIcsContent(
      title: '${booking.packageName ?? "Evento"} - ${booking.supplierName ?? "Fornecedor"}',
      description: _buildEventDescription(booking),
      startDate: parsedStart,
      endDate: endDate,
      location: booking.eventLocation,
    );
  }

  String _buildEventDescription(BookingModel booking) {
    final buffer = StringBuffer()
      ..writeln('Evento: ${booking.packageName ?? "Evento"}');

    if (booking.supplierName != null) {
      buffer.writeln('Fornecedor: ${booking.supplierName}');
    }
    if (booking.clientName != null) {
      buffer.writeln('Cliente: ${booking.clientName}');
    }
    if (booking.guestCount != null && booking.guestCount! > 0) {
      buffer.writeln('Convidados: ${booking.guestCount}');
    }
    buffer.writeln('Valor: ${_formatPrice(booking.totalPrice)} Kz');
    buffer.writeln('\nAgendado via BODA CONNECT');

    return buffer.toString();
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ==================== PROVIDER ====================

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final calendarService = ref.watch(calendarServiceProvider);
  return CalendarNotifier(calendarService);
});
