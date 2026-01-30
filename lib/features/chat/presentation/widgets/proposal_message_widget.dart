import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget to display a proposal/quote message in chat
class ProposalMessageWidget extends StatelessWidget {
  const ProposalMessageWidget({
    super.key,
    required this.packageName,
    required this.price,
    this.notes,
    this.validUntil,
    this.status = 'pending',
    this.onAccept,
    this.onReject,
    this.isFromMe = false,
  });

  final String packageName;
  final double price;
  final String? notes;
  final DateTime? validUntil;
  final String status; // 'pending', 'accepted', 'rejected', 'counter_offered'
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isFromMe;

  Color get _statusColor {
    switch (status) {
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'counter_offered':
        return AppColors.warning;
      case 'pending':
      default:
        return AppColors.peach;
    }
  }

  String get _statusText {
    switch (status) {
      case 'accepted':
        return 'Aceite';
      case 'rejected':
        return 'Recusado';
      case 'counter_offered':
        return 'Contra-proposta enviada';
      case 'pending':
      default:
        return 'Pendente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'Kz',
      decimalDigits: 0,
      locale: 'pt_AO',
    );

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: isFromMe ? AppColors.peach.withValues(alpha: 0.1) : AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: AppColors.peach,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proposta de Pacote',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      packageName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  _statusText,
                  style: AppTextStyles.caption.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.md),

          // Price
          Row(
            children: [
              Text(
                'Preço:',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                currencyFormat.format(price),
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.peach,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Notes if available
          if (notes != null && notes!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Notas:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notes!,
              style: AppTextStyles.body,
            ),
          ],

          // Valid until
          if (validUntil != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Válido até: ${DateFormat('dd/MM/yyyy').format(validUntil!)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          // Action buttons (only show if pending and not from me)
          if (status == 'pending' && !isFromMe && (onAccept != null || onReject != null)) ...[
            const SizedBox(height: AppDimensions.md),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Recusar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                if (onReject != null && onAccept != null)
                  const SizedBox(width: AppDimensions.sm),
                if (onAccept != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aceitar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
