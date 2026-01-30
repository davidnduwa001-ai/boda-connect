import 'package:cloud_firestore/cloud_firestore.dart';

/// Report severity levels (determines urgency of response)
enum ReportSeverity {
  low,       // Minor issues (e.g., spam, misleading info)
  medium,    // Moderate issues (e.g., unprofessional behavior, pricing disputes)
  high,      // Serious issues (e.g., harassment, discrimination)
  critical,  // Immediate action required (e.g., safety threats, violence)
}

/// Report status throughout investigation lifecycle
enum ReportStatus {
  pending,       // Awaiting review
  investigating, // Under investigation
  resolved,      // Issue resolved
  dismissed,     // Not a violation
  escalated,     // Escalated to higher authority
}

/// Report categories for different types of violations
enum ReportCategory {
  // Behavior issues
  harassment,
  discrimination,
  unprofessional,
  threatening,

  // Service issues
  noShow,
  poorQuality,
  overcharging,
  underdelivery,

  // Platform misuse
  spam,
  fraud,
  fakeProfile,
  scam,

  // Safety concerns
  safetyThreat,
  violence,
  inappropriate,

  // Other
  other,
}

/// Model for user reports (clients reporting suppliers OR suppliers reporting clients)
class ReportModel {
  final String id;
  final String reporterId;          // Who submitted the report
  final String reporterType;        // 'client' or 'supplier'
  final String reportedId;          // Who is being reported
  final String reportedType;        // 'client' or 'supplier'

  // Context
  final String? bookingId;          // Related booking (optional)
  final String? reviewId;           // Related review (optional)
  final String? chatId;             // Related chat (optional)

  // Report details
  final ReportCategory category;
  final ReportSeverity severity;
  final String reason;              // Detailed explanation
  final List<String> evidence;      // Photo/document URLs

  // Status & resolution
  final ReportStatus status;
  final String? assignedTo;         // Admin/moderator ID
  final String? resolution;         // Admin notes/decision
  final DateTime? resolvedAt;

  // Actions taken
  final List<String> actionsTaken;  // ['warning_sent', 'user_suspended', etc.]

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterType,
    required this.reportedId,
    required this.reportedType,
    this.bookingId,
    this.reviewId,
    this.chatId,
    required this.category,
    required this.severity,
    required this.reason,
    this.evidence = const [],
    this.status = ReportStatus.pending,
    this.assignedTo,
    this.resolution,
    this.resolvedAt,
    this.actionsTaken = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse category
    final categoryStr = data['category'] as String?;
    final category = ReportCategory.values.firstWhere(
      (e) => e.name == categoryStr,
      orElse: () => ReportCategory.other,
    );

    // Parse severity
    final severityStr = data['severity'] as String?;
    final severity = ReportSeverity.values.firstWhere(
      (e) => e.name == severityStr,
      orElse: () => ReportSeverity.low,
    );

    // Parse status
    final statusStr = data['status'] as String?;
    final status = ReportStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ReportStatus.pending,
    );

    // Parse evidence list
    final evidenceRaw = data['evidence'];
    final evidence = evidenceRaw is List
        ? evidenceRaw.map((e) => e.toString()).toList()
        : <String>[];

    // Parse actions taken list
    final actionsRaw = data['actionsTaken'];
    final actionsTaken = actionsRaw is List
        ? actionsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] as String? ?? '',
      reporterType: data['reporterType'] as String? ?? '',
      reportedId: data['reportedId'] as String? ?? '',
      reportedType: data['reportedType'] as String? ?? '',
      bookingId: data['bookingId'] as String?,
      reviewId: data['reviewId'] as String?,
      chatId: data['chatId'] as String?,
      category: category,
      severity: severity,
      reason: data['reason'] as String? ?? '',
      evidence: evidence,
      status: status,
      assignedTo: data['assignedTo'] as String?,
      resolution: data['resolution'] as String?,
      resolvedAt: _parseTimestamp(data['resolvedAt']),
      actionsTaken: actionsTaken,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterType': reporterType,
      'reportedId': reportedId,
      'reportedType': reportedType,
      'bookingId': bookingId,
      'reviewId': reviewId,
      'chatId': chatId,
      'category': category.name,
      'severity': severity.name,
      'reason': reason,
      'evidence': evidence,
      'status': status.name,
      'assignedTo': assignedTo,
      'resolution': resolution,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'actionsTaken': actionsTaken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ReportModel copyWith({
    String? id,
    String? reporterId,
    String? reporterType,
    String? reportedId,
    String? reportedType,
    String? bookingId,
    String? reviewId,
    String? chatId,
    ReportCategory? category,
    ReportSeverity? severity,
    String? reason,
    List<String>? evidence,
    ReportStatus? status,
    String? assignedTo,
    String? resolution,
    DateTime? resolvedAt,
    List<String>? actionsTaken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterType: reporterType ?? this.reporterType,
      reportedId: reportedId ?? this.reportedId,
      reportedType: reportedType ?? this.reportedType,
      bookingId: bookingId ?? this.bookingId,
      reviewId: reviewId ?? this.reviewId,
      chatId: chatId ?? this.chatId,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      reason: reason ?? this.reason,
      evidence: evidence ?? this.evidence,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      actionsTaken: actionsTaken ?? this.actionsTaken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Helper class for report category information
class ReportCategoryInfo {
  static String getLabel(ReportCategory category) {
    switch (category) {
      case ReportCategory.harassment:
        return 'Assédio';
      case ReportCategory.discrimination:
        return 'Discriminação';
      case ReportCategory.unprofessional:
        return 'Comportamento não profissional';
      case ReportCategory.threatening:
        return 'Ameaças';
      case ReportCategory.noShow:
        return 'Não compareceu';
      case ReportCategory.poorQuality:
        return 'Qualidade ruim';
      case ReportCategory.overcharging:
        return 'Cobrança excessiva';
      case ReportCategory.underdelivery:
        return 'Serviço incompleto';
      case ReportCategory.spam:
        return 'Spam';
      case ReportCategory.fraud:
        return 'Fraude';
      case ReportCategory.fakeProfile:
        return 'Perfil falso';
      case ReportCategory.scam:
        return 'Golpe';
      case ReportCategory.safetyThreat:
        return 'Ameaça à segurança';
      case ReportCategory.violence:
        return 'Violência';
      case ReportCategory.inappropriate:
        return 'Conteúdo inapropriado';
      case ReportCategory.other:
        return 'Outro';
    }
  }

  static String getDescription(ReportCategory category) {
    switch (category) {
      case ReportCategory.harassment:
        return 'Assédio, intimidação ou comportamento ofensivo';
      case ReportCategory.discrimination:
        return 'Discriminação por raça, gênero, religião, etc.';
      case ReportCategory.unprofessional:
        return 'Comportamento pouco profissional ou desrespeitoso';
      case ReportCategory.threatening:
        return 'Ameaças de violência ou dano';
      case ReportCategory.noShow:
        return 'Não compareceu ao compromisso agendado';
      case ReportCategory.poorQuality:
        return 'Serviço de qualidade inferior ao esperado';
      case ReportCategory.overcharging:
        return 'Cobrança acima do valor acordado';
      case ReportCategory.underdelivery:
        return 'Serviço não foi completamente entregue';
      case ReportCategory.spam:
        return 'Mensagens indesejadas ou repetitivas';
      case ReportCategory.fraud:
        return 'Tentativa de fraude ou engano';
      case ReportCategory.fakeProfile:
        return 'Perfil falso ou informações enganosas';
      case ReportCategory.scam:
        return 'Tentativa de golpe ou roubo';
      case ReportCategory.safetyThreat:
        return 'Ameaça à segurança física ou propriedade';
      case ReportCategory.violence:
        return 'Violência física ou ameaça iminente';
      case ReportCategory.inappropriate:
        return 'Conteúdo sexual ou inapropriado';
      case ReportCategory.other:
        return 'Outra violação não listada';
    }
  }

  /// Get severity based on category (auto-suggestion)
  static ReportSeverity getSuggestedSeverity(ReportCategory category) {
    switch (category) {
      case ReportCategory.violence:
      case ReportCategory.safetyThreat:
      case ReportCategory.threatening:
        return ReportSeverity.critical;

      case ReportCategory.harassment:
      case ReportCategory.discrimination:
      case ReportCategory.fraud:
      case ReportCategory.scam:
        return ReportSeverity.high;

      case ReportCategory.unprofessional:
      case ReportCategory.noShow:
      case ReportCategory.poorQuality:
      case ReportCategory.overcharging:
      case ReportCategory.underdelivery:
      case ReportCategory.fakeProfile:
      case ReportCategory.inappropriate:
        return ReportSeverity.medium;

      case ReportCategory.spam:
      case ReportCategory.other:
        return ReportSeverity.low;
    }
  }

  /// Get all categories available for reporting users
  static List<ReportCategory> getAllCategories() {
    return ReportCategory.values;
  }

  /// Get categories specific to supplier reports
  static List<ReportCategory> getSupplierCategories() {
    return [
      ReportCategory.noShow,
      ReportCategory.poorQuality,
      ReportCategory.overcharging,
      ReportCategory.underdelivery,
      ReportCategory.unprofessional,
      ReportCategory.harassment,
      ReportCategory.discrimination,
      ReportCategory.threatening,
      ReportCategory.safetyThreat,
      ReportCategory.violence,
      ReportCategory.fraud,
      ReportCategory.scam,
      ReportCategory.fakeProfile,
      ReportCategory.inappropriate,
      ReportCategory.other,
    ];
  }

  /// Get categories specific to client reports
  static List<ReportCategory> getClientCategories() {
    return [
      ReportCategory.noShow,
      ReportCategory.unprofessional,
      ReportCategory.harassment,
      ReportCategory.discrimination,
      ReportCategory.threatening,
      ReportCategory.safetyThreat,
      ReportCategory.violence,
      ReportCategory.fraud,
      ReportCategory.scam,
      ReportCategory.fakeProfile,
      ReportCategory.inappropriate,
      ReportCategory.spam,
      ReportCategory.other,
    ];
  }
}
