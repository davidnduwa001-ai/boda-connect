import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/routing/route_names.dart';

class SupplierRegistrationSuccessScreen extends ConsumerStatefulWidget {
  const SupplierRegistrationSuccessScreen({super.key});

  @override
  ConsumerState<SupplierRegistrationSuccessScreen> createState() =>
      _SupplierRegistrationSuccessScreenState();
}

class _SupplierRegistrationSuccessScreenState
    extends ConsumerState<SupplierRegistrationSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppDimensions.getHorizontalPadding(context);
    final maxWidth = AppDimensions.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth > 600 ? 600 : maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  // Success Icon with animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.peach,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.peach.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Title
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: const Text(
                      'Registo Concluído!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Description
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: const Text(
                      'O seu perfil será analisado pela equipa da BODA CONNECT.\n'
                      'Após a verificação, você receberá o selo Fornecedor Verificado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Info Card
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                        border: Border.all(color: AppColors.border),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.schedule,
                            iconColor: AppColors.info,
                            title: 'Análise em andamento',
                            description:
                                'A verificação geralmente leva até 24 horas. '
                                'Você receberá uma notificação quando estiver completa.',
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 20),
                          _InfoRow(
                            icon: Icons.verified_user,
                            iconColor: AppColors.success,
                            title: 'Próximos passos',
                            description:
                                'Após a aprovação dos seus documentos, você poderá '
                                'criar pacotes e receber pedidos de clientes.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Confetti emojis decoration
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🎉', style: TextStyle(fontSize: 28)),
                        SizedBox(width: 16),
                        Text('🎊', style: TextStyle(fontSize: 28)),
                        SizedBox(width: 16),
                        Text('✨', style: TextStyle(fontSize: 28)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Primary CTA - Go to verification pending screen
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Refresh auth provider state with updated user data
                        await ref.read(authProvider.notifier).refreshUser();
                        if (context.mounted) {
                          // Redirect to verification pending - supplier must be validated first
                          context.go(Routes.supplierVerificationPending);
                        }
                      },
                      icon: const Icon(Icons.hourglass_top, size: 20),
                      label: const Text(
                        'Ver Estado da Candidatura',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peach,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
