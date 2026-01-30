import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/supplier_model.dart';

/// Tier thresholds for automatic tier calculation
class TierThresholds {
  // Pro tier requirements
  static const int proMinBookings = 10;
  static const double proMinRating = 4.5;
  static const double proMinResponseRate = 80.0;

  // Elite tier requirements
  static const int eliteMinBookings = 50;
  static const double eliteMinRating = 4.7;
  static const double eliteMinResponseRate = 90.0;

  // Diamond tier requirements
  static const int diamondMinBookings = 100;
  static const double diamondMinRating = 4.9;
  static const double diamondMinResponseRate = 95.0;
}

/// Benefits configuration for each tier
class TierBenefits {
  final bool appearsInSearch;
  final String featuredPlacement; // 'never', 'sometimes', 'often', 'always'
  final bool hasVerifiedBadge;
  final double commissionRate; // percentage
  final bool hasPrioritySupport;
  final String analyticsDashboard; // 'basic', 'full'

  const TierBenefits({
    required this.appearsInSearch,
    required this.featuredPlacement,
    required this.hasVerifiedBadge,
    required this.commissionRate,
    required this.hasPrioritySupport,
    required this.analyticsDashboard,
  });

  /// Get benefits for a specific tier
  static TierBenefits forTier(SupplierTier tier) {
    switch (tier) {
      case SupplierTier.starter:
        return const TierBenefits(
          appearsInSearch: true,
          featuredPlacement: 'never',
          hasVerifiedBadge: false,
          commissionRate: 15.0,
          hasPrioritySupport: false,
          analyticsDashboard: 'basic',
        );
      case SupplierTier.pro:
        return const TierBenefits(
          appearsInSearch: true,
          featuredPlacement: 'sometimes',
          hasVerifiedBadge: true,
          commissionRate: 12.0,
          hasPrioritySupport: false,
          analyticsDashboard: 'full',
        );
      case SupplierTier.elite:
        return const TierBenefits(
          appearsInSearch: true,
          featuredPlacement: 'often',
          hasVerifiedBadge: true,
          commissionRate: 10.0,
          hasPrioritySupport: true,
          analyticsDashboard: 'full',
        );
      case SupplierTier.diamond:
        return const TierBenefits(
          appearsInSearch: true,
          featuredPlacement: 'always',
          hasVerifiedBadge: true,
          commissionRate: 8.0,
          hasPrioritySupport: true,
          analyticsDashboard: 'full',
        );
    }
  }

  /// Get featured placement probability (0.0 to 1.0)
  double get featuredProbability {
    switch (featuredPlacement) {
      case 'never':
        return 0.0;
      case 'sometimes':
        return 0.3; // 30% chance
      case 'often':
        return 0.6; // 60% chance
      case 'always':
        return 1.0; // 100% chance
      default:
        return 0.0;
    }
  }
}

/// Service for managing supplier tiers
class TierService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate the appropriate tier based on supplier metrics
  static SupplierTier calculateTier({
    required int completedBookings,
    required double rating,
    required double responseRate,
  }) {
    // Check Diamond tier
    if (completedBookings >= TierThresholds.diamondMinBookings &&
        rating >= TierThresholds.diamondMinRating &&
        responseRate >= TierThresholds.diamondMinResponseRate) {
      return SupplierTier.diamond;
    }

    // Check Elite tier
    if (completedBookings >= TierThresholds.eliteMinBookings &&
        rating >= TierThresholds.eliteMinRating &&
        responseRate >= TierThresholds.eliteMinResponseRate) {
      return SupplierTier.elite;
    }

    // Check Pro tier
    if (completedBookings >= TierThresholds.proMinBookings &&
        rating >= TierThresholds.proMinRating &&
        responseRate >= TierThresholds.proMinResponseRate) {
      return SupplierTier.pro;
    }

    // Default to Starter
    return SupplierTier.starter;
  }

  /// Calculate tier from a SupplierModel
  static SupplierTier calculateTierFromSupplier(SupplierModel supplier) {
    return calculateTier(
      completedBookings: supplier.completedBookings,
      rating: supplier.rating,
      responseRate: supplier.responseRate,
    );
  }

  /// Update supplier's tier in Firestore if it has changed
  Future<bool> updateSupplierTierIfNeeded(String supplierId) async {
    try {
      final doc = await _firestore.collection('suppliers').doc(supplierId).get();
      if (!doc.exists) return false;

      final supplier = SupplierModel.fromFirestore(doc);
      final calculatedTier = calculateTierFromSupplier(supplier);

      // Only update if tier has changed
      if (calculatedTier != supplier.tier) {
        await _firestore.collection('suppliers').doc(supplierId).update({
          'tier': calculatedTier.name,
          'tierUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Supplier $supplierId tier updated: ${supplier.tier.name} → ${calculatedTier.name}');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error updating supplier tier: $e');
      return false;
    }
  }

  /// Batch update all suppliers' tiers (for scheduled jobs)
  Future<int> updateAllSupplierTiers() async {
    int updatedCount = 0;
    try {
      final snapshot = await _firestore.collection('suppliers').get();

      for (final doc in snapshot.docs) {
        final supplier = SupplierModel.fromFirestore(doc);
        final calculatedTier = calculateTierFromSupplier(supplier);

        if (calculatedTier != supplier.tier) {
          await doc.reference.update({
            'tier': calculatedTier.name,
            'tierUpdatedAt': FieldValue.serverTimestamp(),
          });
          updatedCount++;
        }
      }

      debugPrint('✅ Updated $updatedCount supplier tiers');
      return updatedCount;
    } catch (e) {
      debugPrint('❌ Error batch updating tiers: $e');
      return updatedCount;
    }
  }

  /// Get progress towards next tier
  static TierProgress getProgressToNextTier(SupplierModel supplier) {
    final currentTier = supplier.tier;
    SupplierTier? nextTier;
    int requiredBookings = 0;
    double requiredRating = 0;
    double requiredResponseRate = 0;

    switch (currentTier) {
      case SupplierTier.starter:
        nextTier = SupplierTier.pro;
        requiredBookings = TierThresholds.proMinBookings;
        requiredRating = TierThresholds.proMinRating;
        requiredResponseRate = TierThresholds.proMinResponseRate;
        break;
      case SupplierTier.pro:
        nextTier = SupplierTier.elite;
        requiredBookings = TierThresholds.eliteMinBookings;
        requiredRating = TierThresholds.eliteMinRating;
        requiredResponseRate = TierThresholds.eliteMinResponseRate;
        break;
      case SupplierTier.elite:
        nextTier = SupplierTier.diamond;
        requiredBookings = TierThresholds.diamondMinBookings;
        requiredRating = TierThresholds.diamondMinRating;
        requiredResponseRate = TierThresholds.diamondMinResponseRate;
        break;
      case SupplierTier.diamond:
        // Already at max tier
        return TierProgress(
          currentTier: currentTier,
          nextTier: null,
          bookingsProgress: 1.0,
          ratingProgress: 1.0,
          responseRateProgress: 1.0,
          overallProgress: 1.0,
        );
    }

    final bookingsProgress = (supplier.completedBookings / requiredBookings).clamp(0.0, 1.0);
    final ratingProgress = (supplier.rating / requiredRating).clamp(0.0, 1.0);
    final responseRateProgress = (supplier.responseRate / requiredResponseRate).clamp(0.0, 1.0);
    final overallProgress = (bookingsProgress + ratingProgress + responseRateProgress) / 3;

    return TierProgress(
      currentTier: currentTier,
      nextTier: nextTier,
      bookingsProgress: bookingsProgress,
      ratingProgress: ratingProgress,
      responseRateProgress: responseRateProgress,
      overallProgress: overallProgress,
      requiredBookings: requiredBookings,
      currentBookings: supplier.completedBookings,
      requiredRating: requiredRating,
      currentRating: supplier.rating,
      requiredResponseRate: requiredResponseRate,
      currentResponseRate: supplier.responseRate,
    );
  }

  /// Get tier display info (uses cached instances for performance)
  static TierDisplayInfo getTierDisplayInfo(SupplierTier tier) {
    return TierDisplayInfo.forTier(tier);
  }
}

/// Progress towards next tier
class TierProgress {
  final SupplierTier currentTier;
  final SupplierTier? nextTier;
  final double bookingsProgress;
  final double ratingProgress;
  final double responseRateProgress;
  final double overallProgress;
  final int? requiredBookings;
  final int? currentBookings;
  final double? requiredRating;
  final double? currentRating;
  final double? requiredResponseRate;
  final double? currentResponseRate;

  const TierProgress({
    required this.currentTier,
    required this.nextTier,
    required this.bookingsProgress,
    required this.ratingProgress,
    required this.responseRateProgress,
    required this.overallProgress,
    this.requiredBookings,
    this.currentBookings,
    this.requiredRating,
    this.currentRating,
    this.requiredResponseRate,
    this.currentResponseRate,
  });

  bool get isMaxTier => nextTier == null;
}

/// Display information for a tier
class TierDisplayInfo {
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  const TierDisplayInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });

  /// Pre-cached display info for each tier (performance optimization)
  static const TierDisplayInfo _starter = TierDisplayInfo(
    name: 'Starter',
    icon: Icons.star_border,
    color: Color(0xFF9E9E9E),
    description: 'Novo fornecedor',
  );

  static const TierDisplayInfo _pro = TierDisplayInfo(
    name: 'Pro',
    icon: Icons.star_half,
    color: Color(0xFF2196F3),
    description: 'Fornecedor estabelecido',
  );

  static const TierDisplayInfo _elite = TierDisplayInfo(
    name: 'Elite',
    icon: Icons.star,
    color: Color(0xFFFF9800),
    description: 'Desempenho excelente',
  );

  static const TierDisplayInfo _diamond = TierDisplayInfo(
    name: 'Diamond',
    icon: Icons.diamond,
    color: Color(0xFF9C27B0),
    description: 'Fornecedor premium',
  );

  /// Get cached display info for a tier (no object allocation)
  static TierDisplayInfo forTier(SupplierTier tier) {
    switch (tier) {
      case SupplierTier.starter:
        return _starter;
      case SupplierTier.pro:
        return _pro;
      case SupplierTier.elite:
        return _elite;
      case SupplierTier.diamond:
        return _diamond;
    }
  }
}
