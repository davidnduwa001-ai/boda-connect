/// Contact Exchange Detection Service
///
/// This service detects attempts to share contact information in chat messages
/// to prevent direct contact between suppliers and clients outside the platform,
/// similar to Airbnb, Uber, and other marketplace platforms.

class ContactDetectionService {
  // Phone number patterns (various formats)
  static final List<RegExp> _phonePatterns = [
    // International format: +244 123 456 789, +1-234-567-8900
    RegExp(r'\+?\d{1,4}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}'),
    // Common formats: 123-456-7890, (123) 456-7890, 123.456.7890
    RegExp(r'\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'),
    // 9+ consecutive digits
    RegExp(r'\b\d{9,}\b'),
    // Spaced out numbers: 9 2 3 4 5 6 7 8 9
    RegExp(r'(?:\d\s){8,}\d'),
  ];

  // Email patterns
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  );

  // Social media patterns
  static final List<RegExp> _socialMediaPatterns = [
    // Direct mentions: @username
    RegExp(r'@[A-Za-z0-9_]{3,}'),
    // Facebook URLs
    RegExp(r'(?:facebook\.com|fb\.com|fb\.me)/[\w.-]+', caseSensitive: false),
    // Instagram
    RegExp(r'instagram\.com/[\w.-]+', caseSensitive: false),
    // WhatsApp
    RegExp(r'(?:wa\.me|whatsapp\.com)/[\w.-]+', caseSensitive: false),
    RegExp(r'(?:whats|wpp|zap)\s*[:=\-]?\s*\d', caseSensitive: false),
    // Telegram
    RegExp(r'(?:t\.me|telegram\.me)/[\w.-]+', caseSensitive: false),
    RegExp(r'telegram\s*[:=\-]?\s*[@\w]', caseSensitive: false),
    // Twitter/X
    RegExp(r'(?:twitter\.com|x\.com)/[\w.-]+', caseSensitive: false),
    // LinkedIn
    RegExp(r'linkedin\.com/in/[\w.-]+', caseSensitive: false),
    // TikTok
    RegExp(r'tiktok\.com/@[\w.-]+', caseSensitive: false),
    // Generic social handles
    RegExp(r'(?:insta|face|snap|tweet)\s*[:=\-]?\s*[@\w]', caseSensitive: false),
  ];

  // Messaging app patterns
  static final List<RegExp> _messagingAppPatterns = [
    RegExp(r'(?:whatsapp|wpp|zap|whats)\b', caseSensitive: false),
    RegExp(r'(?:telegram|tg)\b', caseSensitive: false),
    RegExp(r'(?:signal|viber|line)\b', caseSensitive: false),
    RegExp(r'(?:messenger|fb msg)\b', caseSensitive: false),
    RegExp(r'(?:wechat|kakao)\b', caseSensitive: false),
  ];

  // Suspicious phrases that indicate contact exchange intent
  static final List<RegExp> _suspiciousPhrases = [
    RegExp(r'(?:meu|minha)\s+(?:número|numero|telefone|contato|contacto|whats|email)', caseSensitive: false),
    RegExp(r'(?:me\s+)?(?:liga|ligar|chama|chamar|contacta|contata)', caseSensitive: false),
    RegExp(r'(?:envia|enviar|manda|mandar)\s+(?:mensagem|msg|direct|dm)', caseSensitive: false),
    RegExp(r'(?:adiciona|adicionar|add|segue|seguir)\s+(?:no|na|me)', caseSensitive: false),
    RegExp(r'(?:fora|outside)\s+(?:da|do)\s+(?:plataforma|app|aplicativo)', caseSensitive: false),
    RegExp(r'(?:vamos|vamo)\s+(?:conversar|falar)\s+(?:fora|outside|direto)', caseSensitive: false),
  ];

  /// Detects if a message contains contact information or suspicious content
  /// Returns a [ContactDetectionResult] with detection details
  static ContactDetectionResult detectContactInfo(String message) {
    if (message.isEmpty) {
      return ContactDetectionResult(isClean: true);
    }

    final detectedTypes = <ContactType>[];
    final matches = <String>[];

    // Check for phone numbers
    for (final pattern in _phonePatterns) {
      final phoneMatches = pattern.allMatches(message);
      if (phoneMatches.isNotEmpty) {
        detectedTypes.add(ContactType.phone);
        matches.addAll(phoneMatches.map((m) => m.group(0) ?? ''));
        break; // Only add phone type once
      }
    }

    // Check for emails
    final emailMatches = _emailPattern.allMatches(message);
    if (emailMatches.isNotEmpty) {
      detectedTypes.add(ContactType.email);
      matches.addAll(emailMatches.map((m) => m.group(0) ?? ''));
    }

    // Check for social media
    for (final pattern in _socialMediaPatterns) {
      final socialMatches = pattern.allMatches(message);
      if (socialMatches.isNotEmpty) {
        detectedTypes.add(ContactType.socialMedia);
        matches.addAll(socialMatches.map((m) => m.group(0) ?? ''));
        break; // Only add social media type once
      }
    }

    // Check for messaging apps
    for (final pattern in _messagingAppPatterns) {
      if (pattern.hasMatch(message)) {
        detectedTypes.add(ContactType.messagingApp);
        break;
      }
    }

    // Check for suspicious phrases
    for (final pattern in _suspiciousPhrases) {
      if (pattern.hasMatch(message)) {
        detectedTypes.add(ContactType.suspiciousPhrase);
        break;
      }
    }

    final isClean = detectedTypes.isEmpty;
    final riskLevel = _calculateRiskLevel(detectedTypes);

    return ContactDetectionResult(
      isClean: isClean,
      detectedTypes: detectedTypes,
      matches: matches,
      riskLevel: riskLevel,
      message: isClean ? null : _getWarningMessage(riskLevel),
    );
  }

  /// Calculates the risk level based on detected contact types
  static RiskLevel _calculateRiskLevel(List<ContactType> types) {
    if (types.isEmpty) return RiskLevel.none;

    // High risk: Direct contact info (phone, email)
    if (types.contains(ContactType.phone) || types.contains(ContactType.email)) {
      return RiskLevel.high;
    }

    // Medium risk: Social media or messaging apps mentioned
    if (types.contains(ContactType.socialMedia) ||
        types.contains(ContactType.messagingApp)) {
      return RiskLevel.medium;
    }

    // Low risk: Only suspicious phrases
    if (types.contains(ContactType.suspiciousPhrase)) {
      return RiskLevel.low;
    }

    return RiskLevel.none;
  }

  /// Returns appropriate warning message based on risk level
  static String _getWarningMessage(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return 'Esta mensagem parece conter informações de contacto (telefone ou email). '
               'Para sua segurança e proteção, todas as comunicações devem permanecer na plataforma.';
      case RiskLevel.medium:
        return 'Esta mensagem pode estar a solicitar contacto fora da plataforma. '
               'Recomendamos manter todas as conversas aqui para garantir sua segurança.';
      case RiskLevel.low:
        return 'Lembre-se: mantenha todas as comunicações na plataforma para sua proteção.';
      case RiskLevel.none:
        return '';
    }
  }

  /// Sanitizes a message by removing detected contact information
  static String sanitizeMessage(String message) {
    String sanitized = message;

    // Remove phone numbers
    for (final pattern in _phonePatterns) {
      sanitized = sanitized.replaceAll(pattern, '[TELEFONE REMOVIDO]');
    }

    // Remove emails
    sanitized = sanitized.replaceAll(_emailPattern, '[EMAIL REMOVIDO]');

    // Remove social media handles and URLs
    for (final pattern in _socialMediaPatterns) {
      sanitized = sanitized.replaceAll(pattern, '[CONTACTO REMOVIDO]');
    }

    return sanitized;
  }
}

/// Types of contact information that can be detected
enum ContactType {
  phone,
  email,
  socialMedia,
  messagingApp,
  suspiciousPhrase,
}

/// Risk levels for detected content
enum RiskLevel {
  none,
  low,
  medium,
  high,
}

/// Result of contact detection analysis
class ContactDetectionResult {
  final bool isClean;
  final List<ContactType> detectedTypes;
  final List<String> matches;
  final RiskLevel riskLevel;
  final String? message;

  ContactDetectionResult({
    required this.isClean,
    this.detectedTypes = const [],
    this.matches = const [],
    this.riskLevel = RiskLevel.none,
    this.message,
  });

  /// Whether the message should be blocked from sending
  bool get shouldBlock => riskLevel == RiskLevel.high;

  /// Whether the message should show a warning but allow sending
  bool get shouldWarn => riskLevel == RiskLevel.medium || riskLevel == RiskLevel.low;

  /// Whether the message should be flagged for admin review
  bool get shouldFlag => riskLevel != RiskLevel.none;
}
