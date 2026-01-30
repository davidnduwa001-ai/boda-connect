import 'package:cloud_firestore/cloud_firestore.dart';

/// Safety status levels based on user behavior and metrics
enum SafetyStatus {
  safe,       // Good standing, no issues
  warning,    // Minor issues detected, warning sent
  probation,  // Multiple issues, on probation
  suspended,  // Account suspended
}

/// Badge types awarded for good behavior
enum BadgeType {
  verified,      // Identity verified
  topRated,      // Rating ≥ 4.8, 50+ reviews
  reliable,      // Completion rate > 95%
  responsive,    // Response rate > 90%
  professional,  // 0 behavior reports, 100+ bookings
  expert,        // Top performer in category
}

/// Badge model
class Badge {
  final BadgeType type;
  final DateTime awardedAt;
  final String? category; // For expert badge

  const Badge({
    required this.type,
    required this.awardedAt,
    this.category,
  });

  factory Badge.fromMap(Map<String, dynamic> data) {
    final typeStr = data['type'] as String?;
    final type = BadgeType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => BadgeType.verified,
    );

    return Badge(
      type: type,
      awardedAt: _parseTimestamp(data['awardedAt']) ?? DateTime.now(),
      category: data['category'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'awardedAt': Timestamp.fromDate(awardedAt),
      'category': category,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Safety Score Model - tracks user safety metrics and status
class SafetyScoreModel {
  final String userId;
  final String userType; // 'client' or 'supplier'

  // Overall metrics from reviews
  final double overallRating;
  final int totalReviews;

  // Report metrics
  final int totalReports;
  final int criticalReports;
  final int highReports;
  final int resolvedReports;
  final int dismissedReports;

  // Behavior metrics
  final double completionRate;    // % of completed bookings
  final double cancellationRate;  // % of cancelled bookings
  final double responseRate;      // % of messages responded to
  final double onTimeRate;        // % of on-time arrivals

  // Safety status
  final SafetyStatus status;
  final List<Badge> badges;
  final DateTime? lastWarningDate;
  final int warningCount;
  final DateTime? probationStartDate;
  final DateTime? suspensionStartDate;
  final DateTime? suspensionEndDate;

  // Calculated safety score (0-100)
  final double safetyScore;

  // Metadata
  final DateTime lastCalculated;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SafetyScoreModel({
    required this.userId,
    required this.userType,
    this.overallRating = 0.0,
    this.totalReviews = 0,
    this.totalReports = 0,
    this.criticalReports = 0,
    this.highReports = 0,
    this.resolvedReports = 0,
    this.dismissedReports = 0,
    this.completionRate = 0.0,
    this.cancellationRate = 0.0,
    this.responseRate = 0.0,
    this.onTimeRate = 0.0,
    this.status = SafetyStatus.safe,
    this.badges = const [],
    this.lastWarningDate,
    this.warningCount = 0,
    this.probationStartDate,
    this.suspensionStartDate,
    this.suspensionEndDate,
    required this.safetyScore,
    required this.lastCalculated,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SafetyScoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse status
    final statusStr = data['status'] as String?;
    final status = SafetyStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => SafetyStatus.safe,
    );

    // Parse badges
    final badgesRaw = data['badges'];
    final badges = badgesRaw is List
        ? badgesRaw
            .map((b) => Badge.fromMap(b as Map<String, dynamic>))
            .toList()
        : <Badge>[];

    return SafetyScoreModel(
      userId: data['userId'] as String? ?? '',
      userType: data['userType'] as String? ?? '',
      overallRating: (data['overallRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: data['totalReviews'] as int? ?? 0,
      totalReports: data['totalReports'] as int? ?? 0,
      criticalReports: data['criticalReports'] as int? ?? 0,
      highReports: data['highReports'] as int? ?? 0,
      resolvedReports: data['resolvedReports'] as int? ?? 0,
      dismissedReports: data['dismissedReports'] as int? ?? 0,
      completionRate: (data['completionRate'] as num?)?.toDouble() ?? 0.0,
      cancellationRate: (data['cancellationRate'] as num?)?.toDouble() ?? 0.0,
      responseRate: (data['responseRate'] as num?)?.toDouble() ?? 0.0,
      onTimeRate: (data['onTimeRate'] as num?)?.toDouble() ?? 0.0,
      status: status,
      badges: badges,
      lastWarningDate: _parseTimestamp(data['lastWarningDate']),
      warningCount: data['warningCount'] as int? ?? 0,
      probationStartDate: _parseTimestamp(data['probationStartDate']),
      suspensionStartDate: _parseTimestamp(data['suspensionStartDate']),
      suspensionEndDate: _parseTimestamp(data['suspensionEndDate']),
      safetyScore: (data['safetyScore'] as num?)?.toDouble() ?? 100.0,
      lastCalculated: _parseTimestamp(data['lastCalculated']) ?? DateTime.now(),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userType': userType,
      'overallRating': overallRating,
      'totalReviews': totalReviews,
      'totalReports': totalReports,
      'criticalReports': criticalReports,
      'highReports': highReports,
      'resolvedReports': resolvedReports,
      'dismissedReports': dismissedReports,
      'completionRate': completionRate,
      'cancellationRate': cancellationRate,
      'responseRate': responseRate,
      'onTimeRate': onTimeRate,
      'status': status.name,
      'badges': badges.map((b) => b.toMap()).toList(),
      'lastWarningDate': lastWarningDate != null
          ? Timestamp.fromDate(lastWarningDate!)
          : null,
      'warningCount': warningCount,
      'probationStartDate': probationStartDate != null
          ? Timestamp.fromDate(probationStartDate!)
          : null,
      'suspensionStartDate': suspensionStartDate != null
          ? Timestamp.fromDate(suspensionStartDate!)
          : null,
      'suspensionEndDate': suspensionEndDate != null
          ? Timestamp.fromDate(suspensionEndDate!)
          : null,
      'safetyScore': safetyScore,
      'lastCalculated': Timestamp.fromDate(lastCalculated),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SafetyScoreModel copyWith({
    String? userId,
    String? userType,
    double? overallRating,
    int? totalReviews,
    int? totalReports,
    int? criticalReports,
    int? highReports,
    int? resolvedReports,
    int? dismissedReports,
    double? completionRate,
    double? cancellationRate,
    double? responseRate,
    double? onTimeRate,
    SafetyStatus? status,
    List<Badge>? badges,
    DateTime? lastWarningDate,
    int? warningCount,
    DateTime? probationStartDate,
    DateTime? suspensionStartDate,
    DateTime? suspensionEndDate,
    double? safetyScore,
    DateTime? lastCalculated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SafetyScoreModel(
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      overallRating: overallRating ?? this.overallRating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalReports: totalReports ?? this.totalReports,
      criticalReports: criticalReports ?? this.criticalReports,
      highReports: highReports ?? this.highReports,
      resolvedReports: resolvedReports ?? this.resolvedReports,
      dismissedReports: dismissedReports ?? this.dismissedReports,
      completionRate: completionRate ?? this.completionRate,
      cancellationRate: cancellationRate ?? this.cancellationRate,
      responseRate: responseRate ?? this.responseRate,
      onTimeRate: onTimeRate ?? this.onTimeRate,
      status: status ?? this.status,
      badges: badges ?? this.badges,
      lastWarningDate: lastWarningDate ?? this.lastWarningDate,
      warningCount: warningCount ?? this.warningCount,
      probationStartDate: probationStartDate ?? this.probationStartDate,
      suspensionStartDate: suspensionStartDate ?? this.suspensionStartDate,
      suspensionEndDate: suspensionEndDate ?? this.suspensionEndDate,
      safetyScore: safetyScore ?? this.safetyScore,
      lastCalculated: lastCalculated ?? this.lastCalculated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if user is in good standing
  bool get isInGoodStanding => status == SafetyStatus.safe;

  /// Check if user is currently suspended
  bool get isSuspended {
    if (status != SafetyStatus.suspended) return false;
    if (suspensionEndDate == null) return true; // Permanent suspension
    return DateTime.now().isBefore(suspensionEndDate!);
  }

  /// Check if user is on probation
  bool get isOnProbation => status == SafetyStatus.probation;

  /// Get active reports count (total - resolved - dismissed)
  int get activeReportsCount =>
      totalReports - resolvedReports - dismissedReports;

  /// Get percentage of reports that are high/critical severity
  double get highSeverityReportPercentage {
    if (totalReports == 0) return 0.0;
    return (criticalReports + highReports) / totalReports * 100;
  }

  /// Check if user has specific badge
  bool hasBadge(BadgeType type) {
    return badges.any((b) => b.type == type);
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Helper class for badge information
class BadgeInfo {
  static String getLabel(BadgeType type) {
    switch (type) {
      case BadgeType.verified:
        return 'Verificado';
      case BadgeType.topRated:
        return 'Melhor Avaliado';
      case BadgeType.reliable:
        return 'Confiável';
      case BadgeType.responsive:
        return 'Responsivo';
      case BadgeType.professional:
        return 'Profissional';
      case BadgeType.expert:
        return 'Especialista';
    }
  }

  static String getDescription(BadgeType type) {
    switch (type) {
      case BadgeType.verified:
        return 'Identidade verificada';
      case BadgeType.topRated:
        return 'Avaliação ≥ 4.8 com mais de 50 avaliações';
      case BadgeType.reliable:
        return 'Taxa de conclusão > 95%';
      case BadgeType.responsive:
        return 'Taxa de resposta > 90%';
      case BadgeType.professional:
        return 'Sem denúncias comportamentais, 100+ reservas';
      case BadgeType.expert:
        return 'Melhor desempenho na categoria';
    }
  }

  static String getIcon(BadgeType type) {
    switch (type) {
      case BadgeType.verified:
        return '✅';
      case BadgeType.topRated:
        return '⭐';
      case BadgeType.reliable:
        return '🛡️';
      case BadgeType.responsive:
        return '⚡';
      case BadgeType.professional:
        return '🎯';
      case BadgeType.expert:
        return '🏆';
    }
  }
}
