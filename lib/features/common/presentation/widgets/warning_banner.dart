import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/suspension_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Warning banner that displays based on user's violation level
class WarningBanner extends StatelessWidget {
  final WarningLevel level;
  final double rating;
  final VoidCallback? onDismiss;

  const WarningBanner({
    super.key,
    required this.level,
    required this.rating,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (level == WarningLevel.none) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    Color textColor;
    IconData icon;
    String message;

    switch (level) {
      case WarningLevel.critical:
        backgroundColor = AppColors.error;
        textColor = AppColors.white;
        icon = Icons.error;
        message = '🚨 ATENÇÃO: Classificação ${rating.toStringAsFixed(1)} - '
            'Sua conta será suspensa se cair abaixo de 2.5!';
        break;
      case WarningLevel.high:
        backgroundColor = Colors.orange;
        textColor = AppColors.white;
        icon = Icons.warning;
        message = '⚠️ AVISO FINAL: Você tem múltiplas violações. '
            'Mais uma violação pode suspender sua conta.';
        break;
      case WarningLevel.medium:
        backgroundColor = AppColors.warning;
        textColor = AppColors.white;
        icon = Icons.warning_amber;
        message = '⚠️ AVISO: Você tem violações recentes. '
            'Continue seguindo nossas políticas.';
        break;
      case WarningLevel.low:
        backgroundColor = Colors.blue;
        textColor = AppColors.white;
        icon = Icons.info;
        message = 'ℹ️ LEMBRETE: Por favor, siga as nossas políticas de uso.';
        break;
      case WarningLevel.none:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push(Routes.violations),
                  child: Text(
                    'Ver detalhes →',
                    style: AppTextStyles.caption.copyWith(
                      color: textColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null && level != WarningLevel.critical)
            IconButton(
              icon: Icon(Icons.close, color: textColor, size: 20),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Compact warning badge for displaying in app bar or profile
class WarningBadge extends StatelessWidget {
  final WarningLevel level;
  final int violationCount;

  const WarningBadge({
    super.key,
    required this.level,
    this.violationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (level == WarningLevel.none) {
      return const SizedBox.shrink();
    }

    Color color;
    IconData icon;

    switch (level) {
      case WarningLevel.critical:
        color = AppColors.error;
        icon = Icons.error;
        break;
      case WarningLevel.high:
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case WarningLevel.medium:
        color = AppColors.warning;
        icon = Icons.warning_amber;
        break;
      case WarningLevel.low:
        color = Colors.blue;
        icon = Icons.info;
        break;
      case WarningLevel.none:
        return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => context.push(Routes.violations),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            if (violationCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$violationCount',
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
