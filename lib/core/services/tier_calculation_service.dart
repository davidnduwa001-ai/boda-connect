import 'package:boda_connect/core/models/supplier_tier.dart';

/// Service to calculate supplier tier based on metrics
class TierCalculationService {
  /// Calculate tier based on supplier metrics
  static SupplierTier calculateTier(SupplierMetrics metrics) {
    // Check Premium tier (highest requirements)
    final premiumReqs = TierRequirements.forTier(SupplierTier.premium);
    if (premiumReqs != null && _meetsRequirements(metrics, premiumReqs)) {
      return SupplierTier.premium;
    }

    // Check Diamond tier
    final diamondReqs = TierRequirements.forTier(SupplierTier.diamond);
    if (diamondReqs != null && _meetsRequirements(metrics, diamondReqs)) {
      return SupplierTier.diamond;
    }

    // Check Gold tier
    final goldReqs = TierRequirements.forTier(SupplierTier.gold);
    if (goldReqs != null && _meetsRequirements(metrics, goldReqs)) {
      return SupplierTier.gold;
    }

    // Default to Basic tier
    return SupplierTier.basic;
  }

  /// Check if metrics meet tier requirements
  static bool _meetsRequirements(
    SupplierMetrics metrics,
    TierRequirements requirements,
  ) {
    return metrics.rating >= requirements.minRating &&
        metrics.totalReviews >= requirements.minReviews &&
        metrics.accountAgeDays >= requirements.minAccountAgeDays &&
        metrics.serviceCount >= requirements.minServices &&
        metrics.responseRate >= requirements.minResponseRate &&
        metrics.completionRate >= requirements.minCompletionRate;
  }

  /// Get next tier and progress towards it
  static Map<String, dynamic> getNextTierProgress(SupplierMetrics metrics) {
    final currentTier = calculateTier(metrics);

    // If already at Premium, return null for next tier
    if (currentTier == SupplierTier.premium) {
      return {
        'currentTier': currentTier,
        'nextTier': null,
        'progress': 1.0,
        'missingRequirements': <String>[],
      };
    }

    // Determine next tier
    SupplierTier nextTier;
    switch (currentTier) {
      case SupplierTier.basic:
        nextTier = SupplierTier.gold;
        break;
      case SupplierTier.gold:
        nextTier = SupplierTier.diamond;
        break;
      case SupplierTier.diamond:
        nextTier = SupplierTier.premium;
        break;
      case SupplierTier.premium:
        nextTier = SupplierTier.premium;
        break;
    }

    final nextReqs = TierRequirements.forTier(nextTier);
    if (nextReqs == null) {
      return {
        'currentTier': currentTier,
        'nextTier': null,
        'progress': 1.0,
        'missingRequirements': <String>[],
      };
    }

    // Calculate progress and missing requirements
    final missingRequirements = <String>[];
    var totalChecks = 0;
    var passedChecks = 0;

    // Rating
    totalChecks++;
    if (metrics.rating >= nextReqs.minRating) {
      passedChecks++;
    } else {
      missingRequirements.add(
        'Rating: ${metrics.rating.toStringAsFixed(1)}/${nextReqs.minRating.toStringAsFixed(1)}',
      );
    }

    // Reviews
    totalChecks++;
    if (metrics.totalReviews >= nextReqs.minReviews) {
      passedChecks++;
    } else {
      missingRequirements.add(
        'Avaliações: ${metrics.totalReviews}/${nextReqs.minReviews}',
      );
    }

    // Account age
    totalChecks++;
    if (metrics.accountAgeDays >= nextReqs.minAccountAgeDays) {
      passedChecks++;
    } else {
      final daysNeeded = nextReqs.minAccountAgeDays - metrics.accountAgeDays;
      missingRequirements.add(
        'Conta ativa: ${metrics.accountAgeDays} dias (faltam $daysNeeded dias)',
      );
    }

    // Services
    totalChecks++;
    if (metrics.serviceCount >= nextReqs.minServices) {
      passedChecks++;
    } else {
      missingRequirements.add(
        'Serviços: ${metrics.serviceCount}/${nextReqs.minServices}',
      );
    }

    // Response rate (if required)
    if (nextReqs.minResponseRate > 0) {
      totalChecks++;
      if (metrics.responseRate >= nextReqs.minResponseRate) {
        passedChecks++;
      } else {
        missingRequirements.add(
          'Taxa de resposta: ${(metrics.responseRate * 100).toStringAsFixed(0)}%/${(nextReqs.minResponseRate * 100).toStringAsFixed(0)}%',
        );
      }
    }

    // Completion rate (if required)
    if (nextReqs.minCompletionRate > 0) {
      totalChecks++;
      if (metrics.completionRate >= nextReqs.minCompletionRate) {
        passedChecks++;
      } else {
        missingRequirements.add(
          'Taxa de conclusão: ${(metrics.completionRate * 100).toStringAsFixed(0)}%/${(nextReqs.minCompletionRate * 100).toStringAsFixed(0)}%',
        );
      }
    }

    final progress = totalChecks > 0 ? passedChecks / totalChecks : 0.0;

    return {
      'currentTier': currentTier,
      'nextTier': nextTier,
      'progress': progress,
      'missingRequirements': missingRequirements,
    };
  }

  /// Get tier description in Portuguese
  static String getTierDescription(SupplierTier tier) {
    switch (tier) {
      case SupplierTier.basic:
        return 'Nível inicial para novos fornecedores';
      case SupplierTier.gold:
        return 'Fornecedor de qualidade com boas avaliações';
      case SupplierTier.diamond:
        return 'Fornecedor premium com excelente histórico';
      case SupplierTier.premium:
        return 'Fornecedor de elite com o mais alto padrão de qualidade';
    }
  }

  /// Get tier benefits description
  static List<String> getTierBenefitsDescription(SupplierTier tier) {
    final benefits = TierBenefits.forTier(tier);
    if (benefits == null) return [];

    final descriptions = <String>[];

    if (benefits.canBeFeatured) {
      descriptions.add('✨ Destaque em pesquisas');
    }
    if (benefits.hasAnalytics) {
      descriptions.add('📊 Painel de analytics avançado');
    }
    if (benefits.hasDedicatedSupport) {
      descriptions.add('🎯 Suporte dedicado');
    }
    if (benefits.visibilityBoost > 1.0) {
      descriptions.add('🚀 ${((benefits.visibilityBoost - 1) * 100).toInt()}% mais visibilidade');
    }

    switch (tier) {
      case SupplierTier.basic:
        descriptions.add('📋 Listagem padrão');
        descriptions.add('💬 Suporte básico');
        break;
      case SupplierTier.gold:
        descriptions.add('🥇 Badge Ouro');
        descriptions.add('📧 Suporte prioritário por email');
        break;
      case SupplierTier.diamond:
        descriptions.add('💎 Badge Diamante');
        descriptions.add('📈 Relatórios detalhados');
        break;
      case SupplierTier.premium:
        descriptions.add('👑 Badge Premium');
        descriptions.add('🎁 Promoções exclusivas');
        descriptions.add('📢 Assistência de marketing');
        break;
    }

    return descriptions;
  }
}
