import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive statistics model for supplier profiles
/// Tracks all key performance metrics in real-time
class SupplierStatsModel {
  /// Total profile views (passive views when page loads)
  final int viewCount;

  /// High-value views (when user clicks contact/sends message)
  final int leadCount;

  /// Number of users who favorited this supplier
  final int favoriteCount;

  /// Confirmed bookings (paid/confirmed status)
  final int confirmedBookings;

  /// Completed projects (status = completed)
  final int completedBookings;

  /// Total bookings (all statuses)
  final int totalBookings;

  /// Account creation date for tenure calculation
  final DateTime memberSince;

  /// Last stats update timestamp
  final DateTime lastUpdated;

  /// Average rating
  final double rating;

  /// Total reviews received
  final int reviewCount;

  /// Response rate percentage (0-100)
  final double responseRate;

  const SupplierStatsModel({
    this.viewCount = 0,
    this.leadCount = 0,
    this.favoriteCount = 0,
    this.confirmedBookings = 0,
    this.completedBookings = 0,
    this.totalBookings = 0,
    required this.memberSince,
    required this.lastUpdated,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.responseRate = 0.0,
  });

  /// Calculate total leads (views + high-value interactions)
  int get totalLeads => viewCount + leadCount;

  /// Calculate tenure in years
  int get tenureYears {
    final now = DateTime.now();
    return now.difference(memberSince).inDays ~/ 365;
  }

  /// Calculate tenure in months
  int get tenureMonths {
    final now = DateTime.now();
    return now.difference(memberSince).inDays ~/ 30;
  }

  /// Calculate tenure in days
  int get tenureDays => DateTime.now().difference(memberSince).inDays;

  /// Get human-readable tenure string
  String get tenureDisplay {
    final years = tenureYears;
    final months = tenureMonths;
    final days = tenureDays;

    if (years >= 1) {
      return years == 1 ? '1 Ano' : '$years Anos';
    } else if (months >= 1) {
      return months == 1 ? '1 Mês' : '$months Meses';
    } else if (days >= 1) {
      return days == 1 ? '1 Dia' : '$days Dias';
    } else {
      return 'Novo';
    }
  }

  /// Get "Member since" display string
  String get memberSinceDisplay {
    return 'Membro desde ${memberSince.year}';
  }

  /// Conversion rate (bookings / views)
  double get conversionRate {
    if (viewCount == 0) return 0.0;
    return (confirmedBookings / viewCount) * 100;
  }

  /// Success rate (completed / confirmed)
  double get successRate {
    if (confirmedBookings == 0) return 100.0;
    return (completedBookings / confirmedBookings) * 100;
  }

  factory SupplierStatsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupplierStatsModel.fromMap(data);
  }

  factory SupplierStatsModel.fromMap(Map<String, dynamic> data) {
    return SupplierStatsModel(
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      leadCount: (data['leadCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
      confirmedBookings: (data['confirmedBookings'] as num?)?.toInt() ?? 0,
      completedBookings: (data['completedBookings'] as num?)?.toInt() ?? 0,
      totalBookings: (data['totalBookings'] as num?)?.toInt() ?? 0,
      memberSince: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      lastUpdated: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      responseRate: (data['responseRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewCount': viewCount,
      'leadCount': leadCount,
      'favoriteCount': favoriteCount,
      'confirmedBookings': confirmedBookings,
      'completedBookings': completedBookings,
      'totalBookings': totalBookings,
      'createdAt': Timestamp.fromDate(memberSince),
      'updatedAt': Timestamp.fromDate(lastUpdated),
      'rating': rating,
      'reviewCount': reviewCount,
      'responseRate': responseRate,
    };
  }

  SupplierStatsModel copyWith({
    int? viewCount,
    int? leadCount,
    int? favoriteCount,
    int? confirmedBookings,
    int? completedBookings,
    int? totalBookings,
    DateTime? memberSince,
    DateTime? lastUpdated,
    double? rating,
    int? reviewCount,
    double? responseRate,
  }) {
    return SupplierStatsModel(
      viewCount: viewCount ?? this.viewCount,
      leadCount: leadCount ?? this.leadCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      confirmedBookings: confirmedBookings ?? this.confirmedBookings,
      completedBookings: completedBookings ?? this.completedBookings,
      totalBookings: totalBookings ?? this.totalBookings,
      memberSince: memberSince ?? this.memberSince,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      responseRate: responseRate ?? this.responseRate,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Create empty stats for a new supplier
  factory SupplierStatsModel.empty() {
    final now = DateTime.now();
    return SupplierStatsModel(
      memberSince: now,
      lastUpdated: now,
    );
  }
}

/// Enum for different view types to track
enum ProfileViewType {
  /// Standard page load view
  passive,

  /// User clicked contact button
  contactClick,

  /// User sent first message
  firstMessage,

  /// User clicked call button
  callClick,

  /// User clicked WhatsApp button
  whatsappClick,
}

/// Model for tracking individual profile view events
class ProfileViewEvent {
  final String id;
  final String supplierId;
  final String viewerId;
  final ProfileViewType viewType;
  final DateTime viewedAt;
  final String? source; // e.g., "search", "category", "direct", "share"

  const ProfileViewEvent({
    required this.id,
    required this.supplierId,
    required this.viewerId,
    required this.viewType,
    required this.viewedAt,
    this.source,
  });

  factory ProfileViewEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProfileViewEvent(
      id: doc.id,
      supplierId: data['supplierId'] as String? ?? '',
      viewerId: data['viewerId'] as String? ?? '',
      viewType: ProfileViewType.values.firstWhere(
        (e) => e.name == (data['viewType'] as String? ?? 'passive'),
        orElse: () => ProfileViewType.passive,
      ),
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'viewerId': viewerId,
      'viewType': viewType.name,
      'viewedAt': Timestamp.fromDate(viewedAt),
      'source': source,
    };
  }
}

/// Statistics breakdown by time period
class StatsTimePeriod {
  final int today;
  final int thisWeek;
  final int thisMonth;
  final int total;

  const StatsTimePeriod({
    this.today = 0,
    this.thisWeek = 0,
    this.thisMonth = 0,
    this.total = 0,
  });

  factory StatsTimePeriod.fromMap(Map<String, int> map) {
    return StatsTimePeriod(
      today: map['today'] ?? 0,
      thisWeek: map['week'] ?? map['thisWeek'] ?? 0,
      thisMonth: map['month'] ?? map['thisMonth'] ?? 0,
      total: map['total'] ?? 0,
    );
  }
}
