import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Dialog for client to make a counter-offer on a proposal
class CounterOfferDialog extends StatefulWidget {
  const CounterOfferDialog({
    super.key,
    required this.originalPrice,
    required this.packageName,
  });

  final double originalPrice;
  final String packageName;

  @override
  State<CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<CounterOfferDialog> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitCounterOffer() {
    if (_formKey.currentState?.validate() ?? false) {
      final price = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^\d]'), ''));
      if (price != null) {
        Navigator.pop(context, {
          'price': price,
          'notes': _notesController.text.trim(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'Kz',
      decimalDigits: 0,
      locale: 'pt_AO',
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: const Icon(
                      Icons.sync_alt,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contra-Proposta',
                          style: AppTextStyles.h3,
                        ),
                        Text(
                          widget.packageName,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.lg),

              // Original price
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preço Original:',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      currencyFormat.format(widget.originalPrice),
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.md),

              // Counter-offer price input
              Text(
                'Seu Preço',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  hintText: 'Digite o valor (Kz)',
                  prefixText: 'Kz ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira um preço';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Preço inválido';
                  }
                  if (price >= widget.originalPrice) {
                    return 'O contra-oferta deve ser menor que o preço original';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppDimensions.md),

              // Notes (optional)
              Text(
                'Observações (opcional)',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Ex: Posso aceitar este valor se...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                ),
                maxLines: 3,
                maxLength: 200,
              ),

              const SizedBox(height: AppDimensions.lg),

              // Info message
              Container(
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'O fornecedor receberá sua contra-proposta e poderá aceitar ou recusar.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.lg),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitCounterOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                      ),
                      child: const Text('Enviar Proposta'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
