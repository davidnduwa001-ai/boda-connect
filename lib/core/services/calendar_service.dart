import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Calendar Service for Google/Apple Calendar Integration
class CalendarService {
  static final CalendarService _instance = CalendarService._();
  factory CalendarService() => _instance;
  CalendarService._();

  /// Add event to device calendar
  /// Opens the native calendar app with pre-filled event details
  Future<bool> addToCalendar({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    List<String>? attendees,
  }) async {
    try {
      final Uri calendarUri;

      // On web or Android, use Google Calendar (works in browser)
      // On iOS, use Apple Calendar URL scheme
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS: Use Apple Calendar URL scheme
        calendarUri = _buildAppleCalendarUri(
          title: title,
          description: description,
          startDate: startDate,
          endDate: endDate,
          location: location,
        );
      } else {
        // Web/Android: Use Google Calendar
        calendarUri = _buildGoogleCalendarUri(
          title: title,
          description: description,
          startDate: startDate,
          endDate: endDate,
          location: location,
          attendees: attendees,
        );
      }

      if (await canLaunchUrl(calendarUri)) {
        await launchUrl(calendarUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        debugPrint('❌ Cannot launch calendar URI');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error adding to calendar: $e');
      return false;
    }
  }

  /// Build Google Calendar URI
  Uri _buildGoogleCalendarUri({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    List<String>? attendees,
  }) {
    // Format dates for Google Calendar
    final startStr = _formatDateForGoogle(startDate);
    final endStr = _formatDateForGoogle(endDate);

    final queryParams = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      'details': description,
      'dates': '$startStr/$endStr',
    };

    if (location != null && location.isNotEmpty) {
      queryParams['location'] = location;
    }

    if (attendees != null && attendees.isNotEmpty) {
      queryParams['add'] = attendees.join(',');
    }

    return Uri.https('calendar.google.com', '/calendar/render', queryParams);
  }

  /// Build Apple Calendar URI
  Uri _buildAppleCalendarUri({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
  }) {
    // Format dates for iCal
    final startStr = _formatDateForICal(startDate);
    final endStr = _formatDateForICal(endDate);

    // Build ICS content
    final icsContent = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART:$startStr
DTEND:$endStr
SUMMARY:$title
DESCRIPTION:$description
${location != null ? 'LOCATION:$location' : ''}
END:VEVENT
END:VCALENDAR
''';

    // Use data URI for iOS
    final encodedIcs = Uri.encodeComponent(icsContent);
    return Uri.parse('data:text/calendar;charset=utf-8,$encodedIcs');
  }

  /// Format date for Google Calendar (YYYYMMDDTHHmmssZ)
  String _formatDateForGoogle(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}'
        'Z';
  }

  /// Format date for iCal (YYYYMMDDTHHmmss)
  String _formatDateForICal(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}'
        'T'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}';
  }

  /// Create event from booking data
  Future<bool> addBookingToCalendar({
    required String eventName,
    required String supplierName,
    required String packageName,
    required DateTime eventDate,
    String? eventTime,
    String? eventLocation,
    String? clientName,
    int? totalPrice,
  }) async {
    // Parse time if provided
    DateTime startDate = eventDate;
    if (eventTime != null && eventTime.isNotEmpty) {
      final timeParts = eventTime.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        startDate = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          hour,
          minute,
        );
      }
    }

    // Default event duration: 3 hours
    final endDate = startDate.add(const Duration(hours: 3));

    // Build description
    final description = StringBuffer()
      ..writeln('Evento: $eventName')
      ..writeln('Fornecedor: $supplierName')
      ..writeln('Pacote: $packageName');

    if (clientName != null) {
      description.writeln('Cliente: $clientName');
    }
    if (totalPrice != null) {
      description.writeln('Valor: ${_formatPrice(totalPrice)} Kz');
    }
    description.writeln('\nAgendado via BODA CONNECT');

    return addToCalendar(
      title: '$eventName - $supplierName',
      description: description.toString(),
      startDate: startDate,
      endDate: endDate,
      location: eventLocation,
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  /// Generate calendar download link (ICS file content)
  String generateIcsContent({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    String? organizerEmail,
    String? organizerName,
  }) {
    final startStr = _formatDateForICal(startDate.toUtc());
    final endStr = _formatDateForICal(endDate.toUtc());
    final uid = '${DateTime.now().millisecondsSinceEpoch}@bodaconnect.com';

    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//BODA CONNECT//Event//PT')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH')
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTART:${startStr}Z')
      ..writeln('DTEND:${endStr}Z')
      ..writeln('SUMMARY:${_escapeIcal(title)}')
      ..writeln('DESCRIPTION:${_escapeIcal(description)}');

    if (location != null && location.isNotEmpty) {
      buffer.writeln('LOCATION:${_escapeIcal(location)}');
    }

    if (organizerEmail != null) {
      final name = organizerName ?? 'BODA CONNECT';
      buffer.writeln('ORGANIZER;CN=$name:mailto:$organizerEmail');
    }

    buffer
      ..writeln('STATUS:CONFIRMED')
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');

    return buffer.toString();
  }

  /// Escape special characters for iCal
  String _escapeIcal(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }
}
