import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import '../services/tier_service.dart';

/// A badge widget that displays the supplier's tier
/// Optimized for performance - returns SizedBox.shrink() for starter tier
class TierBadge extends StatelessWidget {
  final SupplierTier tier;
  final bool showLabel;
  final double size;

  const TierBadge({
    super.key,
    required this.tier,
    this.showLabel = true,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    // Early return for starter tier - most common case
    if (tier == SupplierTier.starter) {
      return const SizedBox.shrink();
    }

    // Use cached display info (no allocation)
    final displayInfo = TierDisplayInfo.forTier(tier);

    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: displayInfo.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: displayInfo.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayInfo.icon,
              size: size,
              color: displayInfo.color,
            ),
            const SizedBox(width: 4),
            Text(
              displayInfo.name,
              style: TextStyle(
                fontSize: size * 0.75,
                fontWeight: FontWeight.w600,
                color: displayInfo.color,
              ),
            ),
          ],
        ),
      );
    }

    // Icon only
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: displayInfo.color,
        shape: BoxShape.circle,
      ),
      child: Icon(
        displayInfo.icon,
        size: size * 0.7,
        color: Colors.white,
      ),
    );
  }
}

/// A small tier indicator for supplier cards
/// Highly optimized - returns const SizedBox.shrink() for starter tier
class TierIndicator extends StatelessWidget {
  final SupplierTier tier;

  const TierIndicator({
    super.key,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    // Early return for starter tier (most common case) - no widget tree built
    if (tier == SupplierTier.starter) {
      return const SizedBox.shrink();
    }

    // Use cached display info (no allocation)
    final displayInfo = TierDisplayInfo.forTier(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: displayInfo.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            displayInfo.icon,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            displayInfo.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress card showing progress towards next tier
/// Only used in supplier dashboard, not in lists
class TierProgressCard extends StatelessWidget {
  final SupplierModel supplier;

  const TierProgressCard({
    super.key,
    required this.supplier,
  });

  @override
  Widget build(BuildContext context) {
    final progress = TierService.getProgressToNextTier(supplier);
    final currentTierInfo = TierDisplayInfo.forTier(progress.currentTier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current tier header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: currentTierInfo.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  currentTierInfo.icon,
                  color: currentTierInfo.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nível ${currentTierInfo.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: currentTierInfo.color,
                      ),
                    ),
                    Text(
                      currentTierInfo.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!progress.isMaxTier) ...[
            const SizedBox(height: 20),

            // Progress to next tier
            Text(
              'Progresso para ${TierDisplayInfo.forTier(progress.nextTier!).name}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Overall progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.overallProgress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  TierDisplayInfo.forTier(progress.nextTier!).color,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress.overallProgress * 100).toInt()}% completo',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 16),

            // Individual metrics
            _buildMetricRow(
              'Reservas',
              '${progress.currentBookings}/${progress.requiredBookings}',
              progress.bookingsProgress,
              Icons.calendar_today,
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Avaliação',
              '${progress.currentRating?.toStringAsFixed(1)}/${progress.requiredRating?.toStringAsFixed(1)}',
              progress.ratingProgress,
              Icons.star,
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Taxa de resposta',
              '${progress.currentResponseRate?.toInt()}%/${progress.requiredResponseRate?.toInt()}%',
              progress.responseRateProgress,
              Icons.chat_bubble_outline,
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentTierInfo.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: currentTierInfo.color,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Parabéns! Você alcançou o nível máximo!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    double progress,
    IconData icon,
  ) {
    final isComplete = progress >= 1.0;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isComplete ? Colors.green : Colors.grey[400],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isComplete ? Colors.green : Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          isComplete ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: isComplete ? Colors.green : Colors.grey[300],
        ),
      ],
    );
  }
}

/// Tier benefits display card
class TierBenefitsCard extends StatelessWidget {
  final SupplierTier tier;

  const TierBenefitsCard({
    super.key,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final benefits = TierBenefits.forTier(tier);
    final displayInfo = TierDisplayInfo.forTier(tier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: displayInfo.color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(displayInfo.icon, color: displayInfo.color, size: 24),
              const SizedBox(width: 8),
              Text(
                'Benefícios ${displayInfo.name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: displayInfo.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBenefitRow(
            'Aparece nas buscas',
            benefits.appearsInSearch,
          ),
          _buildBenefitRow(
            'Destaque na página inicial',
            _getFeaturedText(benefits.featuredPlacement),
          ),
          _buildBenefitRow(
            'Selo verificado',
            benefits.hasVerifiedBadge,
          ),
          _buildBenefitRow(
            'Taxa de comissão',
            '${benefits.commissionRate.toInt()}%',
          ),
          _buildBenefitRow(
            'Suporte prioritário',
            benefits.hasPrioritySupport,
          ),
          _buildBenefitRow(
            'Painel de análises',
            benefits.analyticsDashboard == 'full' ? 'Completo' : 'Básico',
          ),
        ],
      ),
    );
  }

  String _getFeaturedText(String placement) {
    switch (placement) {
      case 'never':
        return 'Não';
      case 'sometimes':
        return 'Às vezes';
      case 'often':
        return 'Frequente';
      case 'always':
        return 'Sempre';
      default:
        return 'Não';
    }
  }

  Widget _buildBenefitRow(String label, dynamic value) {
    final bool isBool = value is bool;
    final String displayValue = isBool ? (value ? 'Sim' : 'Não') : value.toString();
    final Color valueColor = isBool
        ? (value ? Colors.green : Colors.red)
        : Colors.grey[700]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Row(
            children: [
              if (isBool)
                Icon(
                  value ? Icons.check : Icons.close,
                  size: 16,
                  color: valueColor,
                ),
              if (isBool) const SizedBox(width: 4),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
