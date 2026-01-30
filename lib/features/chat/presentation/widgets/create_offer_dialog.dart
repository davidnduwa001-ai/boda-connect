import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/package_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Dialog for supplier to create a custom offer for a client
class CreateOfferDialog extends StatefulWidget {
  const CreateOfferDialog({
    super.key,
    this.packages = const [],
    this.buyerName,
  });

  /// Available packages to base the offer on (optional)
  final List<PackageModel> packages;

  /// Name of the buyer (for display)
  final String? buyerName;

  @override
  State<CreateOfferDialog> createState() => _CreateOfferDialogState();
}

class _CreateOfferDialogState extends State<CreateOfferDialog> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _deliveryTimeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PackageModel? _selectedPackage;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    _deliveryTimeController.dispose();
    super.dispose();
  }

  void _selectPackage(PackageModel? package) {
    setState(() {
      _selectedPackage = package;
      if (package != null) {
        _priceController.text = package.price.toString();
        _descriptionController.text = package.description;
        _deliveryTimeController.text = package.duration;
      } else {
        _priceController.clear();
        _descriptionController.clear();
        _deliveryTimeController.clear();
      }
    });
  }

  Future<void> _selectValidityDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.peach,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.gray900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _validUntil = date;
      });
    }
  }

  void _submitOffer() {
    if (_formKey.currentState?.validate() ?? false) {
      final price = int.tryParse(_priceController.text.replaceAll(RegExp(r'[^\d]'), ''));
      if (price != null) {
        Navigator.pop(context, {
          'customPrice': price,
          'description': _descriptionController.text.trim(),
          'deliveryTime': _deliveryTimeController.text.trim().isNotEmpty
              ? _deliveryTimeController.text.trim()
              : null,
          'validUntil': _validUntil,
          'basePackageId': _selectedPackage?.id,
          'basePackageName': _selectedPackage?.name,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: const BoxDecoration(
                  color: AppColors.peach,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(
                        Icons.local_offer_outlined,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Criar Proposta Personalizada',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          if (widget.buyerName != null)
                            Text(
                              'Para ${widget.buyerName}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Package selection (if packages available)
                      if (widget.packages.isNotEmpty) ...[
                        Text(
                          'Baseado em pacote (opcional)',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Column(
                            children: [
                              // Custom offer option
                              RadioListTile<PackageModel?>(
                                value: null,
                                groupValue: _selectedPackage,
                                onChanged: _selectPackage,
                                title: Text(
                                  'Proposta personalizada',
                                  style: AppTextStyles.body,
                                ),
                                subtitle: Text(
                                  'Criar proposta do zero',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                activeColor: AppColors.peach,
                                dense: true,
                              ),
                              const Divider(height: 1),
                              // Package options
                              ...widget.packages.take(3).map((package) =>
                                RadioListTile<PackageModel?>(
                                  value: package,
                                  groupValue: _selectedPackage,
                                  onChanged: _selectPackage,
                                  title: Text(
                                    package.name,
                                    style: AppTextStyles.body,
                                  ),
                                  subtitle: Text(
                                    '${_formatPrice(package.price)} Kz',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.peach,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  activeColor: AppColors.peach,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.md),
                      ],

                      // Price input
                      Text(
                        'Valor da Proposta *',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          hintText: 'Ex: 150000',
                          prefixText: 'Kz ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          filled: true,
                          fillColor: AppColors.gray50,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira o valor';
                          }
                          final price = int.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppDimensions.md),

                      // Description
                      Text(
                        'Descrição do que está incluído *',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Descreva o que está incluído nesta proposta...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          filled: true,
                          fillColor: AppColors.gray50,
                        ),
                        maxLines: 3,
                        maxLength: 500,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, descreva o que está incluído';
                          }
                          if (value.trim().length < 10) {
                            return 'A descrição deve ter pelo menos 10 caracteres';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppDimensions.md),

                      // Delivery time (optional)
                      Text(
                        'Prazo de entrega (opcional)',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      TextFormField(
                        controller: _deliveryTimeController,
                        decoration: InputDecoration(
                          hintText: 'Ex: 3-5 dias úteis',
                          prefixIcon: const Icon(Icons.schedule, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          filled: true,
                          fillColor: AppColors.gray50,
                        ),
                      ),

                      const SizedBox(height: AppDimensions.md),

                      // Validity date
                      Text(
                        'Válido até',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      InkWell(
                        onTap: _selectValidityDate,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.md,
                            vertical: AppDimensions.sm + 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            color: AppColors.gray50,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: AppColors.gray700,
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              Text(
                                dateFormat.format(_validUntil),
                                style: AppTextStyles.body,
                              ),
                              const Spacer(),
                              Text(
                                '${_validUntil.difference(DateTime.now()).inDays} dias',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.md),

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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 20,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Expanded(
                              child: Text(
                                'Quando o cliente aceitar, uma reserva será criada automaticamente com este valor negociado.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppDimensions.radiusMd),
                  ),
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
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
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submitOffer,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Enviar Proposta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.peach,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
