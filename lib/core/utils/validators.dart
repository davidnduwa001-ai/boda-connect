/// Validators for form inputs
class Validators {
  // Angola country code
  static const String angolaCountryCode = '+244';

  /// Validates an Angolan phone number
  /// Angola mobile numbers: 9XX XXX XXX (9 digits starting with 9)
  /// Angola landlines: 2XX XXX XXX (9 digits starting with 2)
  static bool isValidPhone(String input) {
    // Remove all spaces, dashes, and parentheses
    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it's empty
    if (cleaned.isEmpty) return false;

    // If it has country code, remove it for validation
    String number = cleaned;
    if (number.startsWith('+244')) {
      number = number.substring(4);
    } else if (number.startsWith('244')) {
      number = number.substring(3);
    } else if (number.startsWith('00244')) {
      number = number.substring(5);
    }

    // Angolan numbers should be exactly 9 digits
    if (number.length != 9) return false;

    // Must start with 9 (mobile) or 2 (landline)
    if (!number.startsWith('9') && !number.startsWith('2')) return false;

    // Mobile numbers: 91, 92, 93, 94, 95, 96, 99
    // Valid mobile prefixes
    final validMobilePrefixes = ['91', '92', '93', '94', '95', '96', '99'];
    final validLandlinePrefixes = ['22', '23', '24', '25', '26', '27']; // Luanda and provinces

    final prefix = number.substring(0, 2);

    if (number.startsWith('9')) {
      // Mobile validation
      if (!validMobilePrefixes.contains(prefix)) return false;
    } else if (number.startsWith('2')) {
      // Landline validation
      if (!validLandlinePrefixes.contains(prefix)) return false;
    }

    // All digits must be numbers
    return RegExp(r'^[0-9]+$').hasMatch(number);
  }

  /// Validates email format
  static bool isValidEmail(String input) {
    if (input.isEmpty) return false;

    // Standard email regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return emailRegex.hasMatch(input.trim());
  }

  /// Validates password strength
  /// - Minimum 8 characters
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one digit
  static bool isValidPassword(String input) {
    if (input.length < 8) return false;

    final hasUppercase = input.contains(RegExp(r'[A-Z]'));
    final hasLowercase = input.contains(RegExp(r'[a-z]'));
    final hasDigit = input.contains(RegExp(r'[0-9]'));

    return hasUppercase && hasLowercase && hasDigit;
  }

  /// Validates password with custom rules (simpler version)
  /// - Minimum 8 characters
  static bool isValidPasswordSimple(String input) {
    return input.length >= 8;
  }

  /// Validates a name (not empty, at least 2 characters)
  static bool isValidName(String input) {
    final trimmed = input.trim();
    return trimmed.length >= 2;
  }

  /// Validates full name (at least two words)
  static bool isValidFullName(String input) {
    final trimmed = input.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.length >= 2 && parts.every((p) => p.length >= 2);
  }

  /// Validates NIF (Angola Tax ID) - 10 digits
  static bool isValidNIF(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-]'), '');
    return cleaned.length == 10 && RegExp(r'^[0-9]+$').hasMatch(cleaned);
  }

  /// Validates BI (Angola ID Card) - alphanumeric, typically 14 characters
  static bool isValidBI(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-]'), '');
    return cleaned.length >= 9 && cleaned.length <= 14;
  }

  /// Formats an Angolan phone number for display
  /// Input: 923456789 or +244923456789
  /// Output: 923 456 789
  static String formatPhoneForDisplay(String input) {
    String number = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Remove country code if present
    if (number.startsWith('+244')) {
      number = number.substring(4);
    } else if (number.startsWith('244')) {
      number = number.substring(3);
    }

    if (number.length != 9) return input;

    // Format as XXX XXX XXX
    return '${number.substring(0, 3)} ${number.substring(3, 6)} ${number.substring(6)}';
  }

  /// Formats phone number with country code for E.164
  /// Input: 923456789
  /// Output: +244923456789
  static String formatPhoneE164(String input) {
    String number = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Already has country code
    if (number.startsWith('+244')) {
      return number;
    }

    // Remove leading zeros
    if (number.startsWith('00244')) {
      number = number.substring(5);
    } else if (number.startsWith('244')) {
      number = number.substring(3);
    } else if (number.startsWith('0')) {
      number = number.substring(1);
    }

    return '+244$number';
  }

  /// Get validation error message for phone
  static String? getPhoneErrorMessage(String input) {
    if (input.isEmpty) {
      return 'Por favor, insira o número de telefone';
    }

    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    String number = cleaned;
    if (number.startsWith('+244')) {
      number = number.substring(4);
    } else if (number.startsWith('244')) {
      number = number.substring(3);
    }

    if (number.length < 9) {
      return 'Número muito curto. Use 9 dígitos (ex: 923 456 789)';
    }

    if (number.length > 9) {
      return 'Número muito longo. Use 9 dígitos (ex: 923 456 789)';
    }

    if (!number.startsWith('9') && !number.startsWith('2')) {
      return 'Número inválido. Deve começar com 9 (móvel) ou 2 (fixo)';
    }

    final validMobilePrefixes = ['91', '92', '93', '94', '95', '96', '99'];
    final validLandlinePrefixes = ['22', '23', '24', '25', '26', '27'];
    final prefix = number.substring(0, 2);

    if (number.startsWith('9') && !validMobilePrefixes.contains(prefix)) {
      return 'Prefixo móvel inválido. Use 91, 92, 93, 94, 95, 96 ou 99';
    }

    if (number.startsWith('2') && !validLandlinePrefixes.contains(prefix)) {
      return 'Prefixo fixo inválido';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(number)) {
      return 'Use apenas números';
    }

    return null; // Valid
  }

  /// Get validation error message for email
  static String? getEmailErrorMessage(String input) {
    if (input.isEmpty) {
      return 'Por favor, insira o email';
    }

    if (!isValidEmail(input)) {
      return 'Email inválido. Use o formato: exemplo@email.com';
    }

    return null;
  }

  /// Get validation error message for password
  static String? getPasswordErrorMessage(String input) {
    if (input.isEmpty) {
      return 'Por favor, insira a senha';
    }

    if (input.length < 8) {
      return 'A senha deve ter pelo menos 8 caracteres';
    }

    return null;
  }
}
