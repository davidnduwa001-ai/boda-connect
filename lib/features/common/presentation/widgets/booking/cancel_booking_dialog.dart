import 'package:flutter/material.dart';
import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/dimensions.dart';
import '../../../../../core/constants/text_styles.dart';
import '../../../../../core/services/cancellation_service.dart';

class CancelBookingDialog extends StatefulWidget {
  final DateTime? eventDate;
  final double? totalAmount;
  final bool isSupplier;

  const CancelBookingDialog({
    super.key,
    this.eventDate,
    this.totalAmount,
    this.isSupplier = false,
  });

  @override
  State<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<CancelBookingDialog> {
  String? _selectedReason;
  final _additionalNotesController = TextEditingController();
  CancellationResult? _cancellationPreview;

  @override
  void initState() {
    super.initState();
    _calculateCancellationPreview();
  }

  void _calculateCancellationPreview() {
    if (widget.eventDate != null && widget.totalAmount != null) {
      final service = CancellationService();
      setState(() {
        _cancellationPreview = service.calculateCancellation(
          eventDate: widget.eventDate!,
          totalAmount: widget.totalAmount!,
          isClientCancelling: !widget.isSupplier,
        );
      });
    }
  }

  final List<Map<String, String>> _cancellationReasons = [
    {
      'id': 'found_better_option',
      'title': 'Encontrei uma opção melhor',
      'description': 'Encontrei outro fornecedor que atende melhor minhas necessidades',
    },
    {
      'id': 'price_too_high',
      'title': 'Preço muito alto',
      'description': 'O preço está acima do meu orçamento',
    },
    {
      'id': 'date_changed',
      'title': 'Data do evento alterada',
      'description': 'A data do meu evento foi alterada',
    },
    {
      'id': 'event_cancelled',
      'title': 'Evento cancelado',
      'description': 'Decidi cancelar o evento completamente',
    },
    {
      'id': 'supplier_unresponsive',
      'title': 'Fornecedor não responde',
      'description': 'O fornecedor não está respondendo às minhas mensagens',
    },
    {
      'id': 'changed_mind',
      'title': 'Mudei de ideia',
      'description': 'Decidi não contratar este serviço',
    },
    {
      'id': 'other',
      'title': 'Outro motivo',
      'description': 'Motivo não listado acima',
    },
  ];

  @override
  void dispose() {
    _additionalNotesController.dispose();
    super.dispose();
  }

  Widget _buildRefundPreviewCard() {
    final preview = _cancellationPreview!;
    final isNoRefund = preview.isWithinFreeCancellation;
    final hoursUntil = preview.timeUntilEvent.inHours;
    final daysUntil = preview.timeUntilEvent.inDays;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: isNoRefund ? AppColors.errorLight : AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isNoRefund
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNoRefund ? Icons.timer_off : Icons.info_outline,
                color: isNoRefund ? AppColors.error : AppColors.info,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  isNoRefund
                      ? 'Cancelamento dentro de 72 horas'
                      : 'Política de Cancelamento',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isNoRefund ? AppColors.error : AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            daysUntil > 0
                ? 'Faltam $daysUntil dias para o evento'
                : 'Faltam $hoursUntil horas para o evento',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Container(
            padding: const EdgeInsets.all(AppDimensions.sm),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reembolso',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${preview.refundPercentage.toInt()}%',
                      style: AppTextStyles.h3.copyWith(
                        color: isNoRefund ? AppColors.error : AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.totalAmount != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Valor a receber',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_formatPrice(preview.refundAmount.toInt())} Kz',
                        style: AppTextStyles.body.copyWith(
                          color: isNoRefund ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (isNoRefund) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Atenção: Cancelamentos dentro de 72 horas não têm direito a reembolso.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: const Icon(
                        Icons.cancel_outlined,
                        color: AppColors.error,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cancelar Reserva',
                            style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Por favor, informe o motivo',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.gray700,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),

                // 72-Hour Cancellation Policy Info
                if (_cancellationPreview != null) ...[
                  _buildRefundPreviewCard(),
                  const SizedBox(height: AppDimensions.md),
                ],

                // Warning Card
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Text(
                          'Cancelamentos frequentes podem afetar sua pontuação de segurança e limitar reservas futuras.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // Cancellation Reasons
                Text(
                  'Motivo do Cancelamento *',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),

                ..._cancellationReasons.map((reason) {
                  final isSelected = _selectedReason == reason['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedReason = reason['id'];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.errorLight : AppColors.gray50,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: isSelected ? AppColors.error : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected ? AppColors.error : AppColors.gray400,
                            size: 22,
                          ),
                          const SizedBox(width: AppDimensions.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reason['title']!,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.error
                                        : AppColors.gray900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  reason['description']!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: AppDimensions.md),

                // Additional Notes
                Text(
                  'Informações Adicionais (Opcional)',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                TextField(
                  controller: _additionalNotesController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'Adicione mais detalhes sobre o cancelamento...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      borderSide: const BorderSide(color: AppColors.error, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                        ),
                        child: Text(
                          'Voltar',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.gray700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedReason != null
                            ? () {
                                Navigator.of(context).pop({
                                  'reason': _selectedReason!,
                                  'reasonText': _cancellationReasons
                                      .firstWhere(
                                        (r) => r['id'] == _selectedReason,
                                      )['title']!,
                                  'additionalNotes':
                                      _additionalNotesController.text.trim(),
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.white,
                          disabledBackgroundColor: AppColors.gray300,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                        ),
                        child: Text(
                          'Confirmar Cancelamento',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
