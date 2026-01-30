import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/payment_provider.dart';
import 'package:boda_connect/features/payments/utils/web_redirect.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final int amount;
  final String description;
  final String? supplierName;

  const CheckoutScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.description,
    this.supplierName,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedPaymentMethod = 'multicaixa';
  bool _isProcessing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pagamento',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            const SizedBox(height: AppDimensions.lg),
            _buildPaymentMethods(),
            const SizedBox(height: AppDimensions.lg),
            _buildCustomerInfo(),
            const SizedBox(height: AppDimensions.lg),
            _buildSecurityInfo(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do Pedido',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.description,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (widget.supplierName != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Fornecedor: ${widget.supplierName}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total a Pagar',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                _formatPrice(widget.amount),
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.peach,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de Pagamento',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppDimensions.md),
        _buildPaymentOption(
          id: 'multicaixa',
          icon: Icons.phone_android,
          title: 'Multicaixa Express',
          subtitle: 'Pagamento instantâneo via telemóvel',
          color: AppColors.info,
        ),
        const SizedBox(height: AppDimensions.sm),
        _buildPaymentOption(
          id: 'transfer',
          icon: Icons.account_balance,
          title: 'Transferência Bancária',
          subtitle: 'Transferir para conta do fornecedor',
          color: AppColors.success,
        ),
        const SizedBox(height: AppDimensions.sm),
        _buildPaymentOption(
          id: 'cash',
          icon: Icons.attach_money,
          title: 'Dinheiro',
          subtitle: 'Pagar em dinheiro no dia do evento',
          color: AppColors.warning,
        ),
        if (kIsWeb) ...[
          const SizedBox(height: AppDimensions.sm),
          _buildPaymentOption(
            id: 'stripe',
            icon: Icons.credit_card,
            title: 'Cartão (Stripe)',
            subtitle: 'Pagar com cartão de crédito/débito',
            color: const Color(0xFF635BFF),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedPaymentMethod == id;

    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.peach : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppDimensions.md),
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
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                if (value != null) setState(() => _selectedPaymentMethod = value);
              },
              activeColor: AppColors.peach,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo() {
    if (_selectedPaymentMethod != 'multicaixa') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações para Pagamento',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppDimensions.md),
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de Telefone *',
                  hintText: '9XX XXX XXX',
                  prefixIcon: const Icon(Icons.phone),
                  prefixText: '+244 ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome Completo',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email (opcional)',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: AppColors.success, size: 24),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagamento Seguro',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Suas informações estão protegidas com encriptação de ponta a ponta.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _formatPrice(widget.amount),
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.peach,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      _getPaymentButtonText(),
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentButtonText() {
    switch (_selectedPaymentMethod) {
      case 'multicaixa':
        return 'Pagar com Multicaixa Express';
      case 'transfer':
        return 'Ver Dados Bancários';
      case 'cash':
        return 'Confirmar Pagamento em Dinheiro';
      case 'stripe':
        return 'Pagar com Cartão';
      default:
        return 'Continuar';
    }
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == 'multicaixa') {
      await _processMulticaixaPayment();
    } else if (_selectedPaymentMethod == 'transfer') {
      _showBankTransferInfo();
    } else if (_selectedPaymentMethod == 'cash') {
      _confirmCashPayment();
    } else if (_selectedPaymentMethod == 'stripe') {
      await _processStripePayment();
    }
  }

  /// Process Stripe payment - calls createPaymentIntent and redirects to Stripe Checkout
  Future<void> _processStripePayment() async {
    setState(() => _isProcessing = true);

    try {
      // Call Firebase callable function
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('createPaymentIntent');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': widget.bookingId,
        'amount': widget.amount,
        'paymentMethod': 'stripe',
        'successUrl': '${Uri.base.origin}/payment/success?bookingId=${widget.bookingId}',
        'cancelUrl': '${Uri.base.origin}/payment/cancel?bookingId=${widget.bookingId}',
      });

      final data = result.data;
      final checkoutUrl = data['checkoutUrl'] as String?;

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        // Redirect to Stripe Checkout using window.location.href
        redirectToUrl(checkoutUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar sessão de pagamento'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Erro ao processar pagamento'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processMulticaixaPayment() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira o número de telefone'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await ref.read(paymentProvider.notifier).createPayment(
        bookingId: widget.bookingId,
        amount: widget.amount,
        description: widget.description,
        customerPhone: _phoneController.text,
        customerEmail: _emailController.text.isNotEmpty ? _emailController.text : null,
        customerName: _nameController.text.isNotEmpty ? _nameController.text : null,
      );

      if (result != null && result.paymentUrl != null) {
        // Open payment URL
        final uri = Uri.parse(result.paymentUrl!);
        if (await canLaunchUrl(uri)) {
          // On web, open in same window so return URL works
          // On mobile, open in external app
          if (kIsWeb) {
            await launchUrl(uri, webOnlyWindowName: '_self');
          } else {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            // On mobile, navigate to pending screen after launching
            if (mounted) {
              // Include all params for reload-safety
              context.go('/payment-success?bookingId=${widget.bookingId}&paymentId=${result.paymentId}&method=multicaixa&amount=${widget.amount}');
            }
          }
        } else if (mounted) {
          // Fallback: navigate to pending screen with all params
          context.go('/payment-success?bookingId=${widget.bookingId}&paymentId=${result.paymentId}&method=multicaixa&amount=${widget.amount}');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.read(paymentProvider).error ?? 'Erro ao processar pagamento'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showBankTransferInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'Dados para Transferência',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.md),
            _buildBankInfoRow('Banco', 'BAI - Banco Angolano de Investimentos'),
            _buildBankInfoRow('IBAN', 'AO06 0040 0000 1234 5678 9012 3'),
            _buildBankInfoRow('Titular', widget.supplierName ?? 'Fornecedor'),
            _buildBankInfoRow('Valor', _formatPrice(widget.amount)),
            _buildBankInfoRow('Referência', 'BODA-${widget.bookingId.substring(0, 8).toUpperCase()}'),
            const SizedBox(height: AppDimensions.lg),
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'Após a transferência, envie o comprovativo pelo chat para confirmar o pagamento.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Include all params for reload-safety
                  context.go('/payment-success?bookingId=${widget.bookingId}&method=transfer&amount=${widget.amount}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peach,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Já Fiz a Transferência'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              // Copy to clipboard
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copiado')),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _confirmCashPayment() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pagamento em Dinheiro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valor a pagar: ${_formatPrice(widget.amount)}',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'O pagamento será feito diretamente ao fornecedor no dia do evento ou serviço.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Certifique-se de obter um recibo após o pagamento.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Include all params for reload-safety
              context.go('/payment-success?bookingId=${widget.bookingId}&method=cash&amount=${widget.amount}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    final formatted = price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formatted Kz';
  }
}
