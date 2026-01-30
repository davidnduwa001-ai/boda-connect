/// Utility class for normalizing phone numbers to E.164 format
class PhoneNormalizer {
  // Angola country code
  static const String angolaCountryCode = '+244';

  /// Normalizes a phone number to E.164 format
  /// Firebase + Twilio require E.164 format: +[country code][number]
  ///
  /// Examples:
  /// - "923456789" -> "+244923456789"
  /// - "+244923456789" -> "+244923456789"
  /// - "244923456789" -> "+244923456789"
  /// - "923 456 789" -> "+244923456789"
  static String normalize(String? completeNumber) {
    if (completeNumber == null || completeNumber.isEmpty) {
      throw Exception('Invalid phone number: empty');
    }

    // Remove all non-digit characters except leading +
    String number = completeNumber.trim();
    final hasPlus = number.startsWith('+');
    number = number.replaceAll(RegExp(r'[^\d]'), '');

    if (number.isEmpty) {
      throw Exception('Invalid phone number: no digits');
    }

    // Handle various formats
    if (hasPlus && number.startsWith('244')) {
      // Already in E.164 format: +244XXXXXXXXX
      return '+$number';
    } else if (number.startsWith('244') && number.length == 12) {
      // 244XXXXXXXXX (country code without +)
      return '+$number';
    } else if (number.startsWith('00244') && number.length == 14) {
      // 00244XXXXXXXXX (international format)
      return '+${number.substring(2)}';
    } else if (number.length == 9 && (number.startsWith('9') || number.startsWith('2'))) {
      // Just the local number: 9XXXXXXXX or 2XXXXXXXX
      return '+244$number';
    } else if (number.startsWith('0') && number.length == 10) {
      // 09XXXXXXXX (with leading zero)
      return '+244${number.substring(1)}';
    }

    // If already starts with country code
    if (number.startsWith('244')) {
      return '+$number';
    }

    // Default: assume it's a local number
    return '+244$number';
  }

  /// Validates if a normalized number looks correct
  static bool isValidNormalized(String normalizedNumber) {
    if (!normalizedNumber.startsWith('+244')) return false;

    final localNumber = normalizedNumber.substring(4);
    if (localNumber.length != 9) return false;

    // Must start with 9 (mobile) or 2 (landline)
    if (!localNumber.startsWith('9') && !localNumber.startsWith('2')) return false;

    return true;
  }

  /// Extracts the local number without country code
  static String extractLocalNumber(String normalizedNumber) {
    if (normalizedNumber.startsWith('+244')) {
      return normalizedNumber.substring(4);
    } else if (normalizedNumber.startsWith('244')) {
      return normalizedNumber.substring(3);
    }
    return normalizedNumber;
  }

  /// Formats for display: +244 923 456 789
  static String formatForDisplay(String normalizedNumber) {
    final local = extractLocalNumber(normalizedNumber);
    if (local.length != 9) return normalizedNumber;

    return '+244 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
  }

  /// Formats without country code for display: 923 456 789
  static String formatLocalForDisplay(String normalizedNumber) {
    final local = extractLocalNumber(normalizedNumber);
    if (local.length != 9) return normalizedNumber;

    return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
  }
}
