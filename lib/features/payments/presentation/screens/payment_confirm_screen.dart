import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/providers/payment_provider.dart';

class PaymentConfirmScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final int amount;
  final String paymentMethod;
  final String? reference;

  const PaymentConfirmScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    this.reference,
  });

  @override
  ConsumerState<PaymentConfirmScreen> createState() => _PaymentConfirmScreenState();
}

class _PaymentConfirmScreenState extends ConsumerState<PaymentConfirmScreen> {
  bool _isProcessing = false;

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
          'Confirmar Pagamento',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Payment Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.peach.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: AppColors.peach,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumo do Pagamento',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Reserva #${widget.bookingId.substring(0, 8)}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  _buildInfoRow('Método de Pagamento', _getPaymentMethodName(widget.paymentMethod)),
                  const SizedBox(height: 12),
                  if (widget.reference != null) ...[
                    _buildInfoRow('Referência', widget.reference!),
                    const SizedBox(height: 12),
                  ],
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total a Pagar',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.amount} AOA',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.peach,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.gray300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Confirmar Pagamento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'multicaixa':
        return 'Multicaixa Express';
      case 'bank_transfer':
        return 'Transferência Bancária';
      case 'cash':
        return 'Dinheiro';
      default:
        return method;
    }
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Process payment via provider
      final result = await ref.read(paymentProvider.notifier).createPayment(
        bookingId: widget.bookingId,
        amount: widget.amount,
        description: 'Pagamento para reserva #${widget.bookingId.length >= 8 ? widget.bookingId.substring(0, 8) : widget.bookingId}',
        customerPhone: '', // Will be filled from user profile in real implementation
      );

      if (!mounted) return;

      if (result != null) {
        // Use query params for reload-safe navigation
        context.go('${Routes.paymentSuccess}?bookingId=${widget.bookingId}&method=${Uri.encodeComponent(widget.paymentMethod)}&amount=${widget.amount}');
      } else {
        final errorMessage = ref.read(paymentProvider).error;
        final encodedError = Uri.encodeComponent(errorMessage ?? 'O pagamento não pôde ser processado. Tente novamente.');
        context.go('${Routes.paymentFailed}?bookingId=${widget.bookingId}&error=$encodedError');
      }
    } catch (e) {
      if (!mounted) return;
      final encodedError = Uri.encodeComponent(e.toString());
      context.go('${Routes.paymentFailed}?bookingId=${widget.bookingId}&error=$encodedError');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
