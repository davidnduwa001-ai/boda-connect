import 'package:flutter/foundation.dart';

/// Service for detecting contact information in text messages
/// Identifies phone numbers, emails, WhatsApp, social media, and other contact methods
class ContactDetectionService {
  // RegEx patterns for detecting contact information

  /// Detects phone numbers (various formats)
  /// Matches: +244 123 456 789, 923456789, 244923456789, etc.
  static final _phonePattern = RegExp(
    r'(?:\+?244[\s-]?)?[9][1-9][0-9][\s-]?[0-9]{3}[\s-]?[0-9]{3}|'
    r'\b[0-9]{9}\b|'
    r'\+?[0-9]{1,4}[\s-]?[0-9]{2,4}[\s-]?[0-9]{3,4}[\s-]?[0-9]{3,4}|'
    r'\b[0-9]{3}[\s-]?[0-9]{3}[\s-]?[0-9]{3}\b',
    caseSensitive: false,
  );

  /// Detects email addresses
  static final _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  );

  /// Detects WhatsApp mentions
  static final _whatsappPattern = RegExp(
    r'\b(?:whatsapp|whats\s?app|wpp|zap)\b',
    caseSensitive: false,
  );

  /// Detects Telegram mentions
  static final _telegramPattern = RegExp(
    r'\b(?:telegram|telegrm|@[A-Za-z0-9_]{5,})\b',
    caseSensitive: false,
  );

  /// Detects Instagram mentions
  static final _instagramPattern = RegExp(
    r'\b(?:instagram|insta|ig)\b',
    caseSensitive: false,
  );

  /// Detects Facebook mentions
  static final _facebookPattern = RegExp(
    r'\b(?:facebook|fb|face)\b',
    caseSensitive: false,
  );

  /// Detects attempts to share contact outside the app
  static final _contactRequestPattern = RegExp(
    r'\b(?:ligar|liga|chama|chamar|telefone|numero|número|contacto|contato|email|e-mail)\b',
    caseSensitive: false,
  );

  /// Detects URL patterns
  static final _urlPattern = RegExp(
    r'(?:https?://)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&/=]*)',
    caseSensitive: false,
  );

  /// Result of contact detection
  final bool hasContact;
  final List<ContactViolation> violations;
  final ContactSeverity severity;

  ContactDetectionService._({
    required this.hasContact,
    required this.violations,
    required this.severity,
  });

  /// Analyzes a message for contact information
  static ContactDetectionService analyzeMessage(String message) {
    if (message.trim().isEmpty) {
      return ContactDetectionService._(
        hasContact: false,
        violations: [],
        severity: ContactSeverity.none,
      );
    }

    final violations = <ContactViolation>[];

    // Check for phone numbers
    if (_phonePattern.hasMatch(message)) {
      final matches = _phonePattern.allMatches(message);
      for (final match in matches) {
        violations.add(ContactViolation(
          type: ContactType.phone,
          match: match.group(0) ?? '',
          severity: ContactSeverity.high,
          message: 'Número de telefone detectado',
        ));
      }
    }

    // Check for email addresses
    if (_emailPattern.hasMatch(message)) {
      final matches = _emailPattern.allMatches(message);
      for (final match in matches) {
        violations.add(ContactViolation(
          type: ContactType.email,
          match: match.group(0) ?? '',
          severity: ContactSeverity.high,
          message: 'Email detectado',
        ));
      }
    }

    // Check for WhatsApp
    if (_whatsappPattern.hasMatch(message)) {
      violations.add(ContactViolation(
        type: ContactType.whatsapp,
        match: 'WhatsApp',
        severity: ContactSeverity.medium,
        message: 'Menção ao WhatsApp detectada',
      ));
    }

    // Check for Telegram
    if (_telegramPattern.hasMatch(message)) {
      violations.add(ContactViolation(
        type: ContactType.telegram,
        match: 'Telegram',
        severity: ContactSeverity.medium,
        message: 'Menção ao Telegram detectada',
      ));
    }

    // Check for Instagram
    if (_instagramPattern.hasMatch(message)) {
      violations.add(ContactViolation(
        type: ContactType.instagram,
        match: 'Instagram',
        severity: ContactSeverity.low,
        message: 'Menção ao Instagram detectada',
      ));
    }

    // Check for Facebook
    if (_facebookPattern.hasMatch(message)) {
      violations.add(ContactViolation(
        type: ContactType.facebook,
        match: 'Facebook',
        severity: ContactSeverity.low,
        message: 'Menção ao Facebook detectada',
      ));
    }

    // Check for contact request language
    if (_contactRequestPattern.hasMatch(message)) {
      violations.add(ContactViolation(
        type: ContactType.contactRequest,
        match: 'Solicitação de contacto',
        severity: ContactSeverity.medium,
        message: 'Tentativa de solicitar contacto direto',
      ));
    }

    // Check for URLs
    if (_urlPattern.hasMatch(message)) {
      final matches = _urlPattern.allMatches(message);
      for (final match in matches) {
        violations.add(ContactViolation(
          type: ContactType.url,
          match: match.group(0) ?? '',
          severity: ContactSeverity.low,
          message: 'Link detectado',
        ));
      }
    }

    // Determine overall severity
    final maxSeverity = violations.isEmpty
        ? ContactSeverity.none
        : violations.map((v) => v.severity).reduce(
              (a, b) => a.index > b.index ? a : b,
            );

    return ContactDetectionService._(
      hasContact: violations.isNotEmpty,
      violations: violations,
      severity: maxSeverity,
    );
  }

  /// Gets a user-friendly warning message based on severity
  String getWarningMessage() {
    switch (severity) {
      case ContactSeverity.high:
        return '⚠️ AVISO: Partilhar informações de contacto direto é contra as nossas políticas. '
            'Por favor, use apenas o chat do app. Violações podem resultar em suspensão da conta.';
      case ContactSeverity.medium:
        return '⚠️ AVISO: Evite solicitar ou partilhar formas de contacto fora do app. '
            'Use as mensagens do Boda Connect para comunicação segura.';
      case ContactSeverity.low:
        return 'ℹ️ NOTA: Recomendamos manter toda a comunicação dentro do app para sua segurança.';
      case ContactSeverity.none:
        return '';
    }
  }

  /// Checks if message should be blocked (high severity)
  bool shouldBlockMessage() {
    return severity == ContactSeverity.high;
  }

  /// Checks if message should show a warning (medium/low severity)
  bool shouldWarnUser() {
    return severity == ContactSeverity.medium || severity == ContactSeverity.low;
  }

  /// Logs the violation for tracking purposes
  void logViolation(String userId, String messageId) {
    if (!hasContact) return;

    debugPrint('🚨 Contact Violation Detected:');
    debugPrint('   User ID: $userId');
    debugPrint('   Message ID: $messageId');
    debugPrint('   Severity: ${severity.name}');
    debugPrint('   Violations: ${violations.length}');
    for (final violation in violations) {
      debugPrint('   - ${violation.type.name}: ${violation.match}');
    }
  }
}

/// Type of contact information detected
enum ContactType {
  phone,
  email,
  whatsapp,
  telegram,
  instagram,
  facebook,
  contactRequest,
  url,
}

/// Severity level of the violation
enum ContactSeverity {
  none,    // No violation
  low,     // Social media mentions, general URLs
  medium,  // WhatsApp/Telegram mentions, contact requests
  high,    // Phone numbers, email addresses
}

/// Individual contact violation
class ContactViolation {
  final ContactType type;
  final String match;
  final ContactSeverity severity;
  final String message;

  ContactViolation({
    required this.type,
    required this.match,
    required this.severity,
    required this.message,
  });

  @override
  String toString() => '$message: $match';
}
