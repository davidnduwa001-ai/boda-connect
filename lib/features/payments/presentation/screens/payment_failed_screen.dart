import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';

class PaymentFailedScreen extends StatelessWidget {
  final String? bookingId;
  final String? errorMessage;

  const PaymentFailedScreen({
    super.key,
    this.bookingId,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: AppColors.error,
                  size: 50,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Pagamento Falhou',
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                errorMessage ??
                'Não foi possível processar o seu pagamento. Por favor, tente novamente ou escolha outro método de pagamento.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Retry Button
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    if (bookingId != null) {
                      // Use query params for reload-safe navigation
                      context.go('${Routes.checkout}?bookingId=$bookingId');
                    } else {
                      context.pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peach,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    'Tentar Novamente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Go Home Button
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: OutlinedButton(
                  onPressed: () => context.go(Routes.clientHome),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    'Voltar ao Início',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Help Link
              TextButton.icon(
                onPressed: () => context.push(Routes.helpCenter),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Precisa de ajuda?'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
