/// Supplier tier levels (like Uber's tier system)
enum SupplierTier {
  basic(
    priority: 4,
    label: 'Basic',
    labelPt: 'Básico',
    color: 0xFF9E9E9E, // Gray
  ),
  gold(
    priority: 3,
    label: 'Gold',
    labelPt: 'Ouro',
    color: 0xFFFFD700, // Gold
  ),
  diamond(
    priority: 2,
    label: 'Diamond',
    labelPt: 'Diamante',
    color: 0xFFB9F2FF, // Diamond blue
  ),
  premium(
    priority: 1,
    label: 'Premium',
    labelPt: 'Premium',
    color: 0xFFFF6B6B, // Premium red/pink
  );

  const SupplierTier({
    required this.priority,
    required this.label,
    required this.labelPt,
    required this.color,
  });

  /// Search priority (1 = highest, 4 = lowest)
  final int priority;

  /// English label
  final String label;

  /// Portuguese label
  final String labelPt;

  /// Tier color
  final int color;

  /// Get tier from string
  static SupplierTier fromString(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'gold':
        return SupplierTier.gold;
      case 'diamond':
        return SupplierTier.diamond;
      case 'premium':
        return SupplierTier.premium;
      case 'basic':
      default:
        return SupplierTier.basic;
    }
  }
}

/// Tier requirements and benefits
class TierRequirements {
  final double minRating;
  final int minReviews;
  final int minAccountAgeDays;
  final int minServices;
  final double minResponseRate;
  final double minCompletionRate;

  const TierRequirements({
    required this.minRating,
    required this.minReviews,
    required this.minAccountAgeDays,
    required this.minServices,
    this.minResponseRate = 0.0,
    this.minCompletionRate = 0.0,
  });

  /// Requirements for each tier
  static const Map<SupplierTier, TierRequirements> requirements = {
    SupplierTier.basic: TierRequirements(
      minRating: 0.0,
      minReviews: 0,
      minAccountAgeDays: 0,
      minServices: 0,
    ),
    SupplierTier.gold: TierRequirements(
      minRating: 4.5,
      minReviews: 20,
      minAccountAgeDays: 90, // 3 months
      minServices: 5,
    ),
    SupplierTier.diamond: TierRequirements(
      minRating: 4.7,
      minReviews: 50,
      minAccountAgeDays: 180, // 6 months
      minServices: 10,
      minResponseRate: 0.90,
    ),
    SupplierTier.premium: TierRequirements(
      minRating: 4.9,
      minReviews: 100,
      minAccountAgeDays: 365, // 12 months
      minServices: 15,
      minResponseRate: 0.95,
      minCompletionRate: 0.98,
    ),
  };

  /// Get requirements for a specific tier
  static TierRequirements? forTier(SupplierTier tier) {
    return requirements[tier];
  }
}

/// Tier benefits
class TierBenefits {
  final bool canBeFeatured;
  final int searchPriority; // 1 = highest
  final bool hasAnalytics;
  final bool hasDedicatedSupport;
  final double visibilityBoost; // Multiplier for search ranking
  final String badge;

  const TierBenefits({
    required this.canBeFeatured,
    required this.searchPriority,
    required this.hasAnalytics,
    required this.hasDedicatedSupport,
    required this.visibilityBoost,
    required this.badge,
  });

  /// Benefits for each tier
  static const Map<SupplierTier, TierBenefits> benefits = {
    SupplierTier.basic: TierBenefits(
      canBeFeatured: false,
      searchPriority: 4,
      hasAnalytics: false,
      hasDedicatedSupport: false,
      visibilityBoost: 1.0,
      badge: '',
    ),
    SupplierTier.gold: TierBenefits(
      canBeFeatured: true,
      searchPriority: 3,
      hasAnalytics: false,
      hasDedicatedSupport: false,
      visibilityBoost: 1.2,
      badge: '🥇',
    ),
    SupplierTier.diamond: TierBenefits(
      canBeFeatured: true,
      searchPriority: 2,
      hasAnalytics: true,
      hasDedicatedSupport: true,
      visibilityBoost: 1.5,
      badge: '💎',
    ),
    SupplierTier.premium: TierBenefits(
      canBeFeatured: true,
      searchPriority: 1,
      hasAnalytics: true,
      hasDedicatedSupport: true,
      visibilityBoost: 2.0,
      badge: '👑',
    ),
  };

  /// Get benefits for a specific tier
  static TierBenefits? forTier(SupplierTier tier) {
    return benefits[tier];
  }
}

/// Supplier metrics for tier calculation
class SupplierMetrics {
  final double rating;
  final int totalReviews;
  final int accountAgeDays;
  final int serviceCount;
  final double responseRate;
  final double completionRate;

  const SupplierMetrics({
    required this.rating,
    required this.totalReviews,
    required this.accountAgeDays,
    required this.serviceCount,
    this.responseRate = 0.0,
    this.completionRate = 0.0,
  });

  /// Create from Firestore data
  factory SupplierMetrics.fromFirestore(Map<String, dynamic> data) {
    return SupplierMetrics(
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (data['reviewCount'] as num?)?.toInt() ?? 0,
      accountAgeDays: _calculateAccountAge(data['createdAt']),
      serviceCount: (data['serviceCount'] as num?)?.toInt() ?? 0,
      responseRate: (data['responseRate'] as num?)?.toDouble() ?? 0.0,
      completionRate: (data['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static int _calculateAccountAge(dynamic createdAt) {
    if (createdAt == null) return 0;

    DateTime? createdDate;
    if (createdAt is DateTime) {
      createdDate = createdAt;
    } else if (createdAt is Map && createdAt.containsKey('_seconds')) {
      createdDate = DateTime.fromMillisecondsSinceEpoch(
        (createdAt['_seconds'] as int) * 1000,
      );
    }

    if (createdDate == null) return 0;
    return DateTime.now().difference(createdDate).inDays;
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'rating': rating,
      'totalReviews': totalReviews,
      'accountAgeDays': accountAgeDays,
      'serviceCount': serviceCount,
      'responseRate': responseRate,
      'completionRate': completionRate,
      'lastCalculatedAt': DateTime.now().toIso8601String(),
    };
  }
}
