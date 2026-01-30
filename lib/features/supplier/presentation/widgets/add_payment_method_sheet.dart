import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/payment_method_model.dart';
import '../../../../core/providers/payment_method_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/services/encryption_service.dart';

class AddPaymentMethodSheet extends ConsumerStatefulWidget {
  const AddPaymentMethodSheet({super.key});

  @override
  ConsumerState<AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends ConsumerState<AddPaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _encryptionService = EncryptionService();

  // Selected payment type
  PaymentMethodType? _selectedType;

  // Credit Card fields
  final _cardNumberController = TextEditingController();
  final _cardholderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  String _selectedCardType = 'Visa';

  // Multicaixa Express fields
  final _phoneController = TextEditingController();
  final _accountNameController = TextEditingController();

  // Bank Transfer fields
  final _bankAccountController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _ibanController = TextEditingController();
  String _selectedBank = 'BAI';

  bool _isLoading = false;
  bool _setAsDefault = false;

  @override
  void initState() {
    super.initState();
    _encryptionService.initialize();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardholderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _phoneController.dispose();
    _accountNameController.dispose();
    _bankAccountController.dispose();
    _bankAccountNameController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Adicionar Método de Pagamento',
                    style: AppTextStyles.h3,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment type selection
                    Text(
                      'Selecione o Tipo de Pagamento',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentTypeSelector(),
                    const SizedBox(height: 24),

                    // Dynamic form based on selected type
                    if (_selectedType != null) ...[
                      if (_selectedType == PaymentMethodType.creditCard)
                        _buildCreditCardForm(),
                      if (_selectedType == PaymentMethodType.multicaixaExpress)
                        _buildMulticaixaForm(),
                      if (_selectedType == PaymentMethodType.bankTransfer)
                        _buildBankTransferForm(),

                      const SizedBox(height: 16),

                      // Set as default checkbox
                      CheckboxListTile(
                        value: _setAsDefault,
                        onChanged: (value) => setState(() => _setAsDefault = value ?? false),
                        title: const Text('Definir como método padrão'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      const SizedBox(height: 24),

                      // Add button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleAddPaymentMethod,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.peach,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Adicionar Método'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeSelector() {
    return Column(
      children: [
        _buildPaymentTypeCard(
          type: PaymentMethodType.creditCard,
          icon: Icons.credit_card,
          title: 'Cartão de Crédito/Débito',
          subtitle: 'Visa, Mastercard',
        ),
        const SizedBox(height: 12),
        _buildPaymentTypeCard(
          type: PaymentMethodType.multicaixaExpress,
          icon: Icons.phone_android,
          title: 'Multicaixa Express',
          subtitle: 'Pagamento instantâneo via telemóvel',
        ),
        const SizedBox(height: 12),
        _buildPaymentTypeCard(
          type: PaymentMethodType.bankTransfer,
          icon: Icons.account_balance,
          title: 'Transferência Bancária',
          subtitle: 'BAI, BFA, BIC, Atlântico',
        ),
      ],
    );
  }

  Widget _buildPaymentTypeCard({
    required PaymentMethodType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach.withAlpha((0.1 * 255).toInt()) : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.peach : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.peach.withAlpha((0.2 * 255).toInt())
                    : Colors.grey.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.peach : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.peach),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Type
        Text('Tipo de Cartão', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: ['Visa', 'Mastercard'].map((type) {
            return DropdownMenuItem(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) => setState(() => _selectedCardType = value!),
        ),
        const SizedBox(height: 16),

        // Card Number
        Text('Número do Cartão', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
            _CardNumberInputFormatter(),
          ],
          decoration: InputDecoration(
            hintText: '0000 0000 0000 0000',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Insira o número do cartão';
            }
            final cleanNumber = value.replaceAll(' ', '');
            if (cleanNumber.length < 13 || cleanNumber.length > 19) {
              return 'Número do cartão inválido';
            }
            if (!_encryptionService.validateCardNumber(cleanNumber)) {
              return 'Número do cartão inválido (verificação Luhn falhou)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Cardholder Name
        Text('Nome no Cartão', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cardholderController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'NOME COMPLETO',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Insira o nome no cartão';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Expiry and CVV
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Validade', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryDateInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: 'MM/AA',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Insira a validade';
                      }
                      if (value.length < 5) {
                        return 'Formato inválido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CVV', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      hintText: '123',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Insira o CVV';
                      }
                      if (value.length < 3) {
                        return 'CVV inválido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMulticaixaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone Number
        Text('Número de Telefone', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          decoration: InputDecoration(
            hintText: '9XX XXX XXX',
            prefix: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('+244 '),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Insira o número de telefone';
            }
            if (value.length != 9) {
              return 'Número deve ter 9 dígitos';
            }
            if (!value.startsWith('9')) {
              return 'Número deve começar com 9';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Account Name
        Text('Nome da Conta', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _accountNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nome completo',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Insira o nome da conta';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBankTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bank Selection
        Text('Banco', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBank,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: ['BAI', 'BFA', 'BIC', 'Atlântico'].map((bank) {
            return DropdownMenuItem(value: bank, child: Text(bank));
          }).toList(),
          onChanged: (value) => setState(() => _selectedBank = value!),
        ),
        const SizedBox(height: 16),

        // Account Number
        Text('Número da Conta', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bankAccountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: 'XXXXXXXXXXXXXXXXX',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Insira o número da conta';
            }
            if (value.length < 10) {
              return 'Número da conta muito curto';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Account Name
        Text('Nome do Titular', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bankAccountNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nome completo',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Insira o nome do titular';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // IBAN (optional)
        Text('IBAN (Opcional)', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ibanController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            LengthLimitingTextInputFormatter(29),
          ],
          decoration: InputDecoration(
            hintText: 'AO06XXXXXXXXXXXXXXXXXXXXXXX',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!_encryptionService.validateIBAN(value)) {
                return 'IBAN inválido para Angola';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _handleAddPaymentMethod() async {
    if (!_formKey.currentState!.validate()) return;

    final supplierId = ref.read(supplierProvider).currentSupplier?.id;
    if (supplierId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Fornecedor não encontrado')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      PaymentMethodModel paymentMethod;
      final now = DateTime.now();

      switch (_selectedType!) {
        case PaymentMethodType.creditCard:
          // Encrypt card number before storing
          final cardNumber = _cardNumberController.text.replaceAll(' ', '');
          final lastFour = cardNumber.substring(cardNumber.length - 4);

          // Extract month and year from expiry
          final expiry = _expiryController.text.split('/');
          final expiryMonth = expiry[0];
          final expiryYear = expiry[1];

          paymentMethod = PaymentMethodModel(
            id: '',
            supplierId: supplierId,
            type: PaymentMethodType.creditCard,
            displayName: '$_selectedCardType terminado em $lastFour',
            details: PaymentMethodDetails.creditCard(
              lastFour: lastFour,
              cardType: _selectedCardType,
              expiryMonth: expiryMonth,
              expiryYear: expiryYear,
            ),
            isDefault: _setAsDefault,
            createdAt: now,
            updatedAt: now,
          );
          break;

        case PaymentMethodType.multicaixaExpress:
          paymentMethod = PaymentMethodModel(
            id: '',
            supplierId: supplierId,
            type: PaymentMethodType.multicaixaExpress,
            displayName: 'Multicaixa Express - ${_phoneController.text}',
            details: PaymentMethodDetails.multicaixaExpress(
              phone: _phoneController.text,
              accountName: _accountNameController.text,
            ),
            isDefault: _setAsDefault,
            createdAt: now,
            updatedAt: now,
          );
          break;

        case PaymentMethodType.bankTransfer:
          paymentMethod = PaymentMethodModel(
            id: '',
            supplierId: supplierId,
            type: PaymentMethodType.bankTransfer,
            displayName: '$_selectedBank - ${_bankAccountNameController.text}',
            details: PaymentMethodDetails.bankTransfer(
              bankName: _selectedBank,
              accountNumber: _bankAccountController.text,
              accountName: _bankAccountNameController.text,
              iban: _ibanController.text.isNotEmpty ? _ibanController.text : null,
            ),
            isDefault: _setAsDefault,
            createdAt: now,
            updatedAt: now,
          );
          break;
      }

      // Add payment method
      final result = await ref.read(paymentMethodProvider.notifier).addPaymentMethod(paymentMethod);

      if (result != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Método de pagamento adicionado com sucesso')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao adicionar método de pagamento')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Card number formatter with spaces
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Expiry date formatter (MM/YY)
class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
