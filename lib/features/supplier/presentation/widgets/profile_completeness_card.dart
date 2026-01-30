import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/services/profile_completeness_service.dart';

/// Widget that displays the profile completeness score with progress and tips
class ProfileCompletenessCard extends StatelessWidget {
  final SupplierModel supplier;
  final int packageCount;
  final VoidCallback? onTap;
  final bool showDetails;

  const ProfileCompletenessCard({
    super.key,
    required this.supplier,
    this.packageCount = 0,
    this.onTap,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final result = ProfileCompletenessService.calculateCompleteness(
      supplier,
      packageCount: packageCount,
    );

    // Don't show if profile is complete
    if (result.isComplete && !showDetails) {
      return const SizedBox.shrink();
    }

    final levelColor = _getLevelColor(result.level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with percentage
                Row(
                  children: [
                    // Circular progress indicator
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: result.percentage / 100,
                            strokeWidth: 6,
                            backgroundColor: AppColors.gray200,
                            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                          ),
                          Center(
                            child: Text(
                              '${result.percentage}%',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: levelColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Perfil ${result.level.label}',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(result.level.emoji),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.isComplete
                                ? 'Parabéns! Seu perfil está completo.'
                                : '${result.missingItems.length} itens para completar',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.gray400,
                      ),
                  ],
                ),

                // Tip for next action
                if (!result.isComplete && result.nextTip != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: levelColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Próximo passo: ${result.nextTip}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.gray700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Detailed checklist (optional)
                if (showDetails && result.missingItems.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'O que falta:',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  ...result.missingItems.take(3).map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked,
                          size: 14,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (result.missingItems.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${result.missingItems.length - 3} mais',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(CompletenessLevel level) {
    switch (level) {
      case CompletenessLevel.excellent:
        return AppColors.success;
      case CompletenessLevel.good:
        return AppColors.info;
      case CompletenessLevel.fair:
        return AppColors.warning;
      case CompletenessLevel.needsWork:
        return AppColors.error;
    }
  }
}

/// Compact version of the profile completeness indicator
class ProfileCompletenessIndicator extends StatelessWidget {
  final SupplierModel supplier;
  final int packageCount;

  const ProfileCompletenessIndicator({
    super.key,
    required this.supplier,
    this.packageCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final result = ProfileCompletenessService.calculateCompleteness(
      supplier,
      packageCount: packageCount,
    );

    if (result.isComplete) {
      return const SizedBox.shrink();
    }

    final levelColor = _getLevelColor(result.level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: result.percentage / 100,
              strokeWidth: 2,
              backgroundColor: levelColor.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${result.percentage}%',
            style: AppTextStyles.caption.copyWith(
              color: levelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(CompletenessLevel level) {
    switch (level) {
      case CompletenessLevel.excellent:
        return AppColors.success;
      case CompletenessLevel.good:
        return AppColors.info;
      case CompletenessLevel.fair:
        return AppColors.warning;
      case CompletenessLevel.needsWork:
        return AppColors.error;
    }
  }
}
