import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


class AccountTypeScreen extends StatelessWidget {
  const AccountTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenPaddingHorizontal,
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Logo - Responsive sizing
              Image.asset(
                'assets/images/boda_logo.png',
                width: AppDimensions.isWideScreen(context) ? 150 : 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  final isWide = AppDimensions.isWideScreen(context);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'B',
                          style: TextStyle(
                            fontSize: isWide ? 22 : 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        'ODA',
                        style: TextStyle(
                          fontSize: isWide ? 22 : 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.peach,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CONNECT',
                        style: TextStyle(
                          fontSize: isWide ? 22 : 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.peach.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              const Text(
                'Bem-vindo!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Escolha como deseja usar a BODA CONNECT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // Supplier Card
              _AccountCard(
                icon: Icons.storefront_outlined,
                title: 'Cadastrar-se como\nFornecedor',
                description:
                    'Oferece serviços para eventos? Receba pedidos e faça o seu negócio crescer.',
                chips: const [
                  'Receba propostas',
                  'Gerencie agenda',
                  'Cresça seu negócio',
                ],
                onTap: () => context.go(Routes.registerSupplier),
              ),

              const SizedBox(height: 18),

              // Client Card
              _AccountCard(
                icon: Icons.person_outline,
                title: 'Cadastrar-se como\nCliente',
                description:
                    'Está a planear um evento? Encontre os melhores fornecedores em Angola.',
                chips: const [
                  'Explore fornecedores',
                  'Compare preços',
                  'Planeie seu evento',
                ],
                onTap: () => context.go(Routes.registerClient),
              ),

              const Spacer(),

              // Footer login
              GestureDetector(
                onTap: () => context.go(Routes.login),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Já tem uma conta? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Fazer login',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.peach,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {

  const _AccountCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.chips,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final List<String> chips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.peach),
            ),

            const SizedBox(height: 14),

            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.peach.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.chipRadius,
                        ),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.peach,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
