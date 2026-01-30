import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/payment_provider.dart';
import 'package:boda_connect/core/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(paymentProvider.notifier).loadPaymentHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(paymentHistoryProvider);

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
          'Histórico de Pagamentos',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.peach),
        ),
        error: (error, _) => _buildErrorState(error.toString()),
        data: (payments) {
          if (payments.isEmpty) {
            return _buildEmptyState();
          }
          return _buildPaymentList(payments);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: AppColors.gray400,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'Nenhum pagamento ainda',
              style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Seus pagamentos aparecerão aqui após fazer reservas com fornecedores.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Erro ao carregar pagamentos',
              style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.lg),
            ElevatedButton(
              onPressed: () => ref.refresh(paymentHistoryProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.peach,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentList(List<PaymentRecord> payments) {
    // Group payments by month
    final groupedPayments = <String, List<PaymentRecord>>{};
    for (final payment in payments) {
      final monthKey = payment.createdAt != null
          ? DateFormat('MMMM yyyy', 'pt_BR').format(payment.createdAt!)
          : 'Sem data';
      groupedPayments.putIfAbsent(monthKey, () => []).add(payment);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(paymentHistoryProvider);
      },
      color: AppColors.peach,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        itemCount: groupedPayments.length,
        itemBuilder: (context, index) {
          final monthKey = groupedPayments.keys.elementAt(index);
          final monthPayments = groupedPayments[monthKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: AppDimensions.md),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                child: Text(
                  monthKey,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray700,
                  ),
                ),
              ),
              ...monthPayments.map((payment) => _buildPaymentCard(payment)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(PaymentRecord payment) {
    final statusInfo = _getStatusInfo(payment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(statusInfo.icon, color: statusInfo.color, size: 24),
              ),
              const SizedBox(width: AppDimensions.md),
              // Payment info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.description ?? 'Pagamento',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusInfo.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusInfo.label,
                            style: AppTextStyles.caption.copyWith(
                              color: statusInfo.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (payment.createdAt != null)
                          Text(
                            DateFormat('dd/MM/yyyy').format(payment.createdAt!),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                _formatPrice(payment.amount),
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: payment.status == PaymentStatus.completed
                      ? AppColors.success
                      : AppColors.gray900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetails(PaymentRecord payment) {
    final statusInfo = _getStatusInfo(payment.status);

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
            // Handle
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
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusInfo.icon, color: statusInfo.color, size: 28),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatPrice(payment.amount),
                        style: AppTextStyles.h2.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusInfo.label,
                          style: AppTextStyles.caption.copyWith(
                            color: statusInfo.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            const Divider(),
            const SizedBox(height: AppDimensions.md),
            // Details
            _buildDetailRow('Descrição', payment.description ?? '-'),
            _buildDetailRow('Referência', payment.reference ?? '-'),
            _buildDetailRow('Moeda', payment.currency),
            if (payment.createdAt != null)
              _buildDetailRow(
                'Data',
                DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt!),
              ),
            if (payment.completedAt != null)
              _buildDetailRow(
                'Concluído em',
                DateFormat('dd/MM/yyyy HH:mm').format(payment.completedAt!),
              ),
            const SizedBox(height: AppDimensions.lg),
            // Action buttons
            if (payment.status == PaymentStatus.completed)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Could download receipt
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recibo enviado para o seu email'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_outlined),
                  label: const Text('Baixar Recibo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.peach,
                    side: const BorderSide(color: AppColors.peach),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return _StatusInfo(
          label: 'Concluído',
          color: AppColors.success,
          icon: Icons.check_circle,
        );
      case PaymentStatus.pending:
        return _StatusInfo(
          label: 'Pendente',
          color: AppColors.warning,
          icon: Icons.schedule,
        );
      case PaymentStatus.processing:
        return _StatusInfo(
          label: 'Processando',
          color: AppColors.info,
          icon: Icons.sync,
        );
      case PaymentStatus.failed:
        return _StatusInfo(
          label: 'Falhou',
          color: AppColors.error,
          icon: Icons.error,
        );
      case PaymentStatus.cancelled:
        return _StatusInfo(
          label: 'Cancelado',
          color: AppColors.gray400,
          icon: Icons.cancel,
        );
      case PaymentStatus.expired:
        return _StatusInfo(
          label: 'Expirado',
          color: AppColors.gray400,
          icon: Icons.timer_off,
        );
      case PaymentStatus.refunded:
        return _StatusInfo(
          label: 'Reembolsado',
          color: AppColors.info,
          icon: Icons.replay,
        );
    }
  }

  String _formatPrice(int price) {
    final formatted = price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formatted Kz';
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}
