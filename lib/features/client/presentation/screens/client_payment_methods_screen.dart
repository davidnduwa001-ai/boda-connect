import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClientPaymentMethodsScreen extends StatelessWidget {
  const ClientPaymentMethodsScreen({super.key});

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
          'Métodos de Pagamento',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          _buildInfoCard(),
          const SizedBox(height: AppDimensions.lg),
          Text(
            'Métodos Disponíveis',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppDimensions.md),
          _buildPaymentOption(
            context,
            icon: Icons.account_balance,
            title: 'Transferência Bancária',
            subtitle: 'Pague diretamente ao fornecedor via transferência',
            color: AppColors.info,
          ),
          const SizedBox(height: AppDimensions.sm),
          _buildPaymentOption(
            context,
            icon: Icons.attach_money,
            title: 'Pagamento em Dinheiro',
            subtitle: 'Pague em dinheiro no dia do serviço',
            color: AppColors.success,
          ),
          const SizedBox(height: AppDimensions.sm),
          _buildPaymentOption(
            context,
            icon: Icons.credit_card,
            title: 'Cartão de Crédito/Débito',
            subtitle: 'Use seu cartão (processamento via fornecedor)',
            color: AppColors.peach,
          ),
          const SizedBox(height: AppDimensions.sm),
          _buildPaymentOption(
            context,
            icon: Icons.phone_android,
            title: 'Pagamento Móvel',
            subtitle: 'Multicaixa Express, Unitel Money, etc.',
            color: AppColors.info,
          ),
          const SizedBox(height: AppDimensions.lg),
          _buildSecurityInfo(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.peachLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.peach, size: 24),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              'Os pagamentos são processados diretamente com o fornecedor. '
              'Escolha o método mais conveniente ao fazer sua reserva.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.gray700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.md),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.gray400),
        onTap: () {
          // Could navigate to specific payment method details
          _showPaymentMethodInfo(context, title, subtitle);
        },
      ),
    );
  }

  Widget _buildSecurityInfo() {
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
          Row(
            children: [
              const Icon(Icons.security, color: AppColors.success, size: 20),
              const SizedBox(width: AppDimensions.xs),
              Text(
                'Segurança e Proteção',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          _buildSecurityPoint('Todas as transações são seguras'),
          _buildSecurityPoint('Fornecedores verificados pela plataforma'),
          _buildSecurityPoint('Suporte disponível para qualquer problema'),
          _buildSecurityPoint('Histórico completo de pagamentos'),
        ],
      ),
    );
  }

  Widget _buildSecurityPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodInfo(
      BuildContext context, String title, String subtitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 16),
            Text(
              'Este método de pagamento será coordenado diretamente '
              'com o fornecedor ao confirmar sua reserva.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}
