import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/payment_method_model.dart';
import '../../../../core/providers/payment_method_provider.dart';
import '../widgets/add_payment_method_sheet.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(paymentMethodProvider.notifier).loadPaymentMethods());
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentMethodProvider);
    final paymentMethods = paymentState.paymentMethods;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Métodos de Pagamento'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: paymentState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Security banner
                Container(
                  margin: const EdgeInsets.all(AppDimensions.md),
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield, color: Colors.yellow.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pagamentos seguros',
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Todos os seus dados são protegidos com criptografia de ponta a ponta',
                              style: AppTextStyles.caption.copyWith(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Payment methods list
                Expanded(
                  child: paymentMethods.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          itemCount: paymentMethods.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
                          itemBuilder: (_, index) => _buildPaymentCard(paymentMethods[index]),
                        ),
                ),

                // Add button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: const AddPaymentMethodSheet(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Adicionar Novo Método'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhum método de pagamento',
            style: AppTextStyles.h3.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione um método para receber pagamentos',
            style: AppTextStyles.body.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PaymentMethodModel pm) {
    return InkWell(
      onTap: pm.isDefault ? null : () => _setAsDefault(pm),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: pm.isDefault ? AppColors.peach : AppColors.border,
            width: pm.isDefault ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payment, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pm.typeLabel,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (pm.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha((0.1 * 255).toInt()),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Padrão',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(pm.maskedInfo, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600)),
                  if (!pm.isDefault) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Toque para definir como padrão',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.peach,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showDeleteDialog(pm),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setAsDefault(PaymentMethodModel pm) async {
    final success = await ref.read(paymentMethodProvider.notifier).setDefaultPaymentMethod(pm.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${pm.typeLabel} definido como padrão'
                : 'Erro ao definir método padrão',
          ),
        ),
      );
    }
  }

  void _showDeleteDialog(PaymentMethodModel pm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover método?'),
        content: Text('Deseja remover ${pm.typeLabel}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(paymentMethodProvider.notifier).deletePaymentMethod(pm.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Método removido')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
