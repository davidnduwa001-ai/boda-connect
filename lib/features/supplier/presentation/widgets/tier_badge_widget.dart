import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/supplier_tier.dart';
import 'package:flutter/material.dart';

/// Widget to display supplier tier badge
class TierBadgeWidget extends StatelessWidget {
  const TierBadgeWidget({
    super.key,
    required this.tier,
    this.size = TierBadgeSize.medium,
    this.showLabel = true,
  });

  final SupplierTier tier;
  final TierBadgeSize size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final benefits = TierBenefits.forTier(tier);
    if (benefits == null) return const SizedBox.shrink();

    final color = Color(tier.color);
    final badge = benefits.badge;

    if (badge.isEmpty) {
      // Basic tier - no badge
      return const SizedBox.shrink();
    }

    // Size configurations
    final double badgeSize;
    final double fontSize;
    final double padding;

    switch (size) {
      case TierBadgeSize.small:
        badgeSize = 20;
        fontSize = 10;
        padding = 4;
        break;
      case TierBadgeSize.medium:
        badgeSize = 24;
        fontSize = 11;
        padding = 6;
        break;
      case TierBadgeSize.large:
        badgeSize = 32;
        fontSize = 12;
        padding = 8;
        break;
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.8),
            color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji badge
          Text(
            badge,
            style: TextStyle(fontSize: badgeSize),
          ),
          // Label (optional)
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              tier.labelPt,
              style: AppTextStyles.caption.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tier badge size options
enum TierBadgeSize {
  small,
  medium,
  large,
}
