import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/suspension_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SuspendedAccountScreen extends ConsumerWidget {
  const SuspendedAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.uid ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Erro ao carregar informações da conta'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go(Routes.welcome);
                  }
                },
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }

    final canAppealAsync = ref.watch(canAppealProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Suspension icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block,
                    size: 60,
                    color: AppColors.error,
                  ),
                ),

                const SizedBox(height: AppDimensions.xl),

                // Title
                Text(
                  'Conta Suspensa',
                  style: AppTextStyles.h1.copyWith(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppDimensions.md),

                // Message
                Text(
                  'Sua conta foi suspensa devido a violações das nossas políticas de uso.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppDimensions.xl),

                // Reason card
                _buildReasonCard(),

                const SizedBox(height: AppDimensions.xl),

                // What this means
                _buildInfoCard(
                  'O que isto significa?',
                  [
                    'Você não pode fazer login na sua conta',
                    'Suas reservas foram canceladas',
                    'Seu perfil está oculto para outros usuários',
                    'Você pode submeter um recurso se achar que foi um erro',
                  ],
                ),

                const SizedBox(height: AppDimensions.lg),

                // How to appeal
                canAppealAsync.when(
                  data: (canAppeal) => canAppeal
                      ? _buildAppealButton(context, userId, ref)
                      : _buildAppealSubmittedCard(),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => const SizedBox.shrink(),
                ),

                const SizedBox(height: AppDimensions.xl),

                // Sign out button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go(Routes.welcome);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gray400),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Terminar Sessão'),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 24),
              const SizedBox(width: AppDimensions.sm),
              Text(
                'Motivo da Suspensão',
                style: AppTextStyles.h3.copyWith(color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'Sua classificação caiu abaixo do limite mínimo (2.5) devido a múltiplas violações das nossas políticas, incluindo:',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppDimensions.md),
          _buildReasonItem('Partilha de informações de contacto'),
          _buildReasonItem('Tentativas de contacto fora do app'),
          _buildReasonItem('Violações repetidas apesar de avisos'),
        ],
      ),
    );
  }

  Widget _buildReasonItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.md),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: AppColors.peach),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAppealButton(BuildContext context, String userId, WidgetRef ref) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  'Acha que foi um erro? Você pode submeter um recurso.',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showAppealDialog(context, userId, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.edit),
            label: const Text('Submeter Recurso'),
          ),
        ),
      ],
    );
  }

  Widget _buildAppealSubmittedCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 32),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recurso Submetido',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seu recurso está sendo analisado pela nossa equipe. Você receberá uma resposta em breve.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAppealDialog(BuildContext context, String userId, WidgetRef ref) {
    final appealController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submeter Recurso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Explique por que você acha que sua conta deve ser reativada:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: appealController,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Escreva sua mensagem aqui...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (appealController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, escreva uma mensagem')),
                );
                return;
              }

              final suspensionService = ref.read(suspensionServiceProvider);
              final success = await suspensionService.submitAppeal(
                userId,
                appealController.text.trim(),
              );

              if (context.mounted) {
                Navigator.pop(context);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Recurso submetido com sucesso!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  // Refresh the screen
                  ref.invalidate(canAppealProvider(userId));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Erro ao submeter recurso. Tente novamente.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Submeter'),
          ),
        ],
      ),
    );
  }
}
