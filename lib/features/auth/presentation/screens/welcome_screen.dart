import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWideScreen = AppDimensions.isWideScreen(context);
    final maxWidth = AppDimensions.getMaxContentWidth(context);
    final horizontalPadding = AppDimensions.getHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth > 500 ? 500 : maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Column(
                children: [
                  SizedBox(height: isWideScreen ? 60 : 44),

                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/boda_logo.png',
                      width: isWideScreen ? 180 : 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Text(
                            'BODA CONNECT',
                            style: TextStyle(
                              fontSize: isWideScreen ? 28 : 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.peach,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'Conecte-se com os melhores fornecedores de\neventos em Angola. Do casamento dos sonhos\nà festa perfeita.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isWideScreen ? 15 : 13.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Feature cards
                  const _FeatureCard(
                    title: 'Fornecedores Verificados',
                    subtitle: 'Profissionais qualificados e avaliados',
                    icon: Icons.verified_rounded,
                  ),
                  const SizedBox(height: 14),
                  const _FeatureCard(
                    title: 'Chat Direto',
                    subtitle: 'Converse e receba propostas\ninstantâneas',
                    icon: Icons.chat_bubble_rounded,
                  ),
                  const SizedBox(height: 14),
                  const _FeatureCard(
                    title: 'Pacotes Prontos',
                    subtitle: 'Soluções completas para o seu evento',
                    icon: Icons.inventory_2_rounded,
                  ),

                  const Spacer(),

                  // Primary button (Começar)
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peach,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.buttonRadius,
                          ),
                        ),
                      ),
                      onPressed: () => context.go(Routes.accountType),
                      child: const Text(
                        'Começar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secondary button (Já tenho conta)
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.buttonRadius,
                          ),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => context.go(Routes.login),
                      child: const Text(
                        'Já tenho conta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.peach.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.peach, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
