import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';

/// Dialog for clients to propose a price to suppliers
class ClientPriceProposalDialog extends StatefulWidget {
  const ClientPriceProposalDialog({
    super.key,
    this.supplierName,
  });

  final String? supplierName;

  @override
  State<ClientPriceProposalDialog> createState() =>
      _ClientPriceProposalDialogState();
}

class _ClientPriceProposalDialogState extends State<ClientPriceProposalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _eventDate;

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: SingleChildScrollView(
        child: Padding(
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.peachLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: const Icon(
                        Icons.monetization_on_outlined,
                        color: AppColors.peachDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Propor Preço',
                            style: AppTextStyles.h3,
                          ),
                          if (widget.supplierName != null)
                            Text(
                              'para ${widget.supplierName}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.lg),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Text(
                          'O fornecedor receberá sua proposta e pode aceitar, recusar ou fazer uma contraproposta.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.lg),

                // Price field
                Text(
                  'Valor Proposto *',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Ex: 150000',
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: 'Kz',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira um valor';
                    }
                    final price = int.tryParse(value);
                    if (price == null || price < 1000) {
                      return 'Valor mínimo: 1.000 Kz';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.md),

                // Description field
                Text(
                  'Descrição do Serviço *',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText:
                        'Descreva o que deseja incluir no serviço...\nEx: Sessão de fotos de 4 horas para casamento com 50 convidados',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, descreva o serviço desejado';
                    }
                    if (value.trim().length < 10) {
                      return 'Descrição muito curta (mínimo 10 caracteres)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.md),

                // Event date field (optional)
                Text(
                  'Data do Evento (opcional)',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                InkWell(
                  onTap: _selectEventDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _eventDate != null
                          ? _formatDate(_eventDate!)
                          : 'Selecionar data',
                      style: _eventDate != null
                          ? AppTextStyles.body
                          : AppTextStyles.body.copyWith(
                              color: AppColors.gray400,
                            ),
                    ),
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submitProposal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.peach,
                          foregroundColor: AppColors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }

  Future<void> _selectEventDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _eventDate = date);
    }
  }

  void _submitProposal() {
    if (_formKey.currentState?.validate() != true) return;

    final price = int.parse(_priceController.text);

    Navigator.pop(context, {
      'customPrice': price,
      'description': _descriptionController.text.trim(),
      'eventDate': _eventDate,
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
