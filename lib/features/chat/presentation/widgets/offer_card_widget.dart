import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/custom_offer_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget to display a custom offer message in chat
class OfferCardWidget extends StatelessWidget {
  const OfferCardWidget({
    super.key,
    required this.offer,
    required this.isFromMe,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.isProcessing = false,
  });

  final CustomOfferModel offer;
  final bool isFromMe;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final bool isProcessing;

  Color get _statusColor {
    switch (offer.status) {
      case OfferStatus.accepted:
        return AppColors.success;
      case OfferStatus.rejected:
        return AppColors.error;
      case OfferStatus.expired:
        return AppColors.gray400;
      case OfferStatus.cancelled:
        return AppColors.gray400;
      case OfferStatus.pending:
        return AppColors.peach;
    }
  }

  IconData get _statusIcon {
    switch (offer.status) {
      case OfferStatus.accepted:
        return Icons.check_circle;
      case OfferStatus.rejected:
        return Icons.cancel;
      case OfferStatus.expired:
        return Icons.timer_off;
      case OfferStatus.cancelled:
        return Icons.block;
      case OfferStatus.pending:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isExpired = offer.validUntil != null &&
        DateTime.now().isAfter(offer.validUntil!) &&
        offer.status == OfferStatus.pending;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: isFromMe ? AppColors.peach.withValues(alpha: 0.08) : AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusMd - 2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Icon(
                    Icons.local_offer,
                    color: _statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proposta Personalizada',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (offer.basePackageName != null)
                        Text(
                          'Baseado em: ${offer.basePackageName}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon,
                        size: 14,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired ? 'Expirada' : offer.statusText,
                        style: AppTextStyles.caption.copyWith(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price highlight
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.peachLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Valor Negociado',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        offer.formattedPrice,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.peachDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.md),

                // Description
                Text(
                  'O que está incluído:',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  offer.description,
                  style: AppTextStyles.body,
                ),

                // Delivery time if available
                if (offer.deliveryTime != null) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.gray400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Prazo: ${offer.deliveryTime}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],

                // Validity
                if (offer.validUntil != null) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      Icon(
                        isExpired ? Icons.timer_off : Icons.event_available,
                        size: 16,
                        color: isExpired ? AppColors.error : AppColors.gray400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired
                            ? 'Expirou em ${dateFormat.format(offer.validUntil!)}'
                            : 'Válido até ${dateFormat.format(offer.validUntil!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isExpired ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],

                // Booking reference if accepted
                if (offer.status == OfferStatus.accepted && offer.bookingId != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Text(
                            'Reserva criada: #${offer.bookingId!.substring(0, 8).toUpperCase()}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Rejection reason if rejected
                if (offer.status == OfferStatus.rejected && offer.rejectionReason != null) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppDimensions.xs),
                        Expanded(
                          child: Text(
                            'Motivo: ${offer.rejectionReason}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons for pending offers
          if (offer.status == OfferStatus.pending && !isExpired && !isProcessing) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.sm),
              child: _buildActionButtons(),
            ),
          ],

          // Loading state
          if (isProcessing)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.peach,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      'A processar...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // If I'm the sender (seller), show cancel button
    if (isFromMe) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancelar Proposta'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gray700,
          ),
        ),
      );
    }

    // If I'm the receiver (buyer), show accept/reject buttons
    return Row(
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
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (onReject != null && onAccept != null)
          const SizedBox(width: AppDimensions.sm),
        if (onAccept != null)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Aceitar Proposta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget for displaying offer data embedded in a message
class OfferMessageDataWidget extends StatelessWidget {
  const OfferMessageDataWidget({
    super.key,
    required this.offerData,
    required this.isFromMe,
    this.onTap,
  });

  final OfferMessageData offerData;
  final bool isFromMe;
  final VoidCallback? onTap;

  Color get _statusColor {
    switch (offerData.status) {
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'expired':
      case 'cancelled':
        return AppColors.gray400;
      default:
        return AppColors.peach;
    }
  }

  String get _statusText {
    switch (offerData.status) {
      case 'accepted':
        return 'Aceite';
      case 'rejected':
        return 'Rejeitada';
      case 'expired':
        return 'Expirada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Pendente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: isFromMe ? AppColors.peach.withValues(alpha: 0.1) : AppColors.gray50,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_offer,
                  color: _statusColor,
                  size: 18,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  'Proposta Personalizada',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
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
            const SizedBox(height: AppDimensions.sm),
            Text(
              offerData.formattedPrice,
              style: AppTextStyles.h3.copyWith(
                color: AppColors.peachDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              offerData.description,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (onTap != null) ...[
              const SizedBox(height: AppDimensions.sm),
              Text(
                'Toque para ver detalhes',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.peach,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
