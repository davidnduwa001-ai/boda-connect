import 'package:equatable/equatable.dart';

/// Value Object representing a booking date
///
/// This encapsulates event date and time information with validation and utility
/// methods. Following Domain-Driven Design principles, this ensures that all
/// booking dates are valid and provides consistent date handling.
class BookingDate extends Equatable {
  /// The date of the event
  final DateTime eventDate;

  /// Optional time of the event (e.g., "14:00", "19:30")
  final String? eventTime;

  const BookingDate({
    required this.eventDate,
    this.eventTime,
  });

  /// Creates a BookingDate from date components
  ///
  /// Example:
  /// ```dart
  /// final date = BookingDate.fromComponents(
  ///   year: 2024,
  ///   month: 12,
  ///   day: 25,
  ///   time: "14:00",
  /// );
  /// ```
  factory BookingDate.fromComponents({
    required int year,
    required int month,
    required int day,
    String? time,
  }) {
    final date = DateTime(year, month, day);
    return BookingDate(eventDate: date, eventTime: time);
  }

  /// Creates a BookingDate for today
  factory BookingDate.today({String? time}) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    return BookingDate(eventDate: date, eventTime: time);
  }

  /// Check if the booking date is in the past
  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.isBefore(today);
  }

  /// Check if the booking date is today
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.year == today.year &&
        eventDate.month == today.month &&
        eventDate.day == today.day;
  }

  /// Check if the booking date is tomorrow
  bool get isTomorrow {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return eventDate.year == tomorrow.year &&
        eventDate.month == tomorrow.month &&
        eventDate.day == tomorrow.day;
  }

  /// Check if the booking date is in the future
  bool get isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.isAfter(today) || isToday;
  }

  /// Check if the booking date is within the next N days
  bool isWithinDays(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureDate = today.add(Duration(days: days));
    return eventDate.isBefore(futureDate) || eventDate.isAtSameMomentAs(futureDate);
  }

  /// Get the number of days until the event
  ///
  /// Returns negative if the event is in the past
  int get daysUntilEvent {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return eventDate.difference(today).inDays;
  }

  /// Check if the booking is within cancellation period
  ///
  /// [minimumDays] - Minimum days before event when cancellation is allowed
  ///
  /// Example:
  /// ```dart
  /// final date = BookingDate(eventDate: DateTime(2024, 12, 25));
  /// final canCancel = date.isWithinCancellationPeriod(minimumDays: 7);
  /// ```
  bool isWithinCancellationPeriod({int minimumDays = 7}) {
    return daysUntilEvent >= minimumDays;
  }

  /// Validate if this booking date is acceptable for new bookings
  ///
  /// [minimumAdvanceDays] - Minimum days in advance required for booking
  ///
  /// Returns true if the date is valid for booking
  bool isValidForBooking({int minimumAdvanceDays = 1}) {
    return daysUntilEvent >= minimumAdvanceDays;
  }

  /// Format the date in a readable format
  ///
  /// Example output: "25 de Dezembro, 2024"
  String formatDate() {
    final months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];

    return '${eventDate.day} de ${months[eventDate.month - 1]}, ${eventDate.year}';
  }

  /// Format the date in short format
  ///
  /// Example output: "25/12/2024"
  String formatDateShort() {
    return '${eventDate.day.toString().padLeft(2, '0')}/'
        '${eventDate.month.toString().padLeft(2, '0')}/'
        '${eventDate.year}';
  }

  /// Format date and time together
  ///
  /// Example output: "25/12/2024 às 14:00" or "25/12/2024" if no time
  String formatDateTime() {
    if (eventTime != null && eventTime!.isNotEmpty) {
      return '${formatDateShort()} às $eventTime';
    }
    return formatDateShort();
  }

  /// Get a relative description of when the event is
  ///
  /// Example outputs: "Hoje", "Amanhã", "Em 3 dias", "Há 2 dias"
  String getRelativeDescription() {
    if (isToday) return 'Hoje';
    if (isTomorrow) return 'Amanhã';

    final days = daysUntilEvent;
    if (days > 0) {
      return days == 1 ? 'Amanhã' : 'Em $days dias';
    } else if (days == 0) {
      return 'Hoje';
    } else {
      final pastDays = days.abs();
      return pastDays == 1 ? 'Ontem' : 'Há $pastDays dias';
    }
  }

  /// Check if this date is on the same day as another date
  bool isSameDay(DateTime other) {
    return eventDate.year == other.year &&
        eventDate.month == other.month &&
        eventDate.day == other.day;
  }

  /// Check if this date is on the same day as another BookingDate
  bool isSameDayAs(BookingDate other) {
    return isSameDay(other.eventDate);
  }

  @override
  List<Object?> get props => [eventDate, eventTime];

  @override
  String toString() => formatDateTime();

  /// Copy this BookingDate with optional parameter changes
  BookingDate copyWith({
    DateTime? eventDate,
    String? eventTime,
  }) {
    return BookingDate(
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
    );
  }
}
