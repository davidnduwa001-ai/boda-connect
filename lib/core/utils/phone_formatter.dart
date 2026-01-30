/// Phone number formatting utilities for Angola and Portugal
class PhoneFormatter {
  PhoneFormatter._();

  /// Format phone number for Angola (+244)
  static String formatPhoneNumberAO(String phone) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    // If starts with 244, add +
    if (digits.startsWith('244')) {
      return '+$digits';
    }

    // If starts with 9 and is 9 digits (Angola mobile)
    if (digits.startsWith('9') && digits.length == 9) {
      return '+244$digits';
    }

    // Already formatted or international
    if (phone.startsWith('+')) {
      return phone;
    }

    return '+244$digits';
  }

  /// Format phone number for Portugal (+351)
  static String formatPhoneNumberPT(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('351')) {
      return '+$digits';
    }

    if (digits.startsWith('9') && digits.length == 9) {
      return '+351$digits';
    }

    if (phone.startsWith('+')) {
      return phone;
    }

    return '+351$digits';
  }
}
