import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/suspension_provider.dart';
import 'package:boda_connect/core/services/suspension_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ViolationsScreen extends ConsumerWidget {
  const ViolationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final authState = ref.watch(authProvider);

    // Use Firebase user ID as fallback
    final userId = currentUser?.uid ?? authState.firebaseUser?.uid ?? '';

    if (userId.isEmpty) {
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
            'Violações & Avisos',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.peach),
        ),
      );
    }

    final warningLevelAsync = ref.watch(warningLevelProvider(userId));
    final violationsAsync = ref.watch(userViolationsProvider(userId));

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
          'Violações & Avisos',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Warning level card
            warningLevelAsync.when(
              data: (warningLevel) => _buildWarningLevelCard(context, warningLevel, currentUser?.rating ?? 5.0),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorCard('Erro ao carregar nível de aviso'),
            ),

            const SizedBox(height: AppDimensions.md),

            // Account status
            _buildAccountStatusCard(context, currentUser?.isActive ?? true, currentUser?.rating ?? 5.0),

            const SizedBox(height: AppDimensions.md),

            // Violations list
            violationsAsync.when(
              data: (violations) => _buildViolationsList(context, violations),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorCard('Erro ao carregar violações'),
            ),

            const SizedBox(height: AppDimensions.md),

            // Guidelines
            _buildGuidelinesCard(context),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningLevelCard(BuildContext context, WarningLevel level, double rating) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String title;
    String message;

    switch (level) {
      case WarningLevel.critical:
        backgroundColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        icon = Icons.error;
        title = '🚨 AVISO CRÍTICO';
        message = 'Sua conta está em risco de suspensão devido à classificação baixa. '
            'Por favor, melhore seu comportamento imediatamente ou sua conta será suspensa.';
        break;
      case WarningLevel.high:
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.warning;
        title = '⚠️ AVISO FINAL';
        message = 'Você recebeu múltiplas violações. Mais uma violação pode resultar em suspensão da conta.';
        break;
      case WarningLevel.medium:
        backgroundColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        icon = Icons.warning_amber;
        title = '⚠️ AVISO';
        message = 'Você tem violações recentes. Continue violando as políticas e sua conta será suspensa.';
        break;
      case WarningLevel.low:
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        icon = Icons.info;
        title = 'ℹ️ LEMBRETE';
        message = 'Por favor, siga as nossas políticas de uso para evitar problemas futuros.';
        break;
      case WarningLevel.none:
        backgroundColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        icon = Icons.check_circle;
        title = '✅ Conta em Bom Estado';
        message = 'Você não tem violações ativas. Continue seguindo nossas políticas!';
        break;
    }

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 32),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h3.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Classificação: ${rating.toStringAsFixed(1)} ⭐',
                      style: AppTextStyles.bodySmall.copyWith(color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatusCard(BuildContext context, bool isActive, double rating) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status da Conta', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.md),
          _buildStatusRow(
            'Estado',
            isActive ? 'Ativa' : 'Suspensa',
            isActive ? AppColors.success : AppColors.error,
          ),
          const Divider(height: 24),
          _buildStatusRow(
            'Classificação',
            '${rating.toStringAsFixed(1)} / 5.0',
            rating >= 3.5 ? AppColors.success : rating >= 2.5 ? AppColors.warning : AppColors.error,
          ),
          const Divider(height: 24),
          _buildStatusRow(
            'Limite de Suspensão',
            '2.5',
            AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViolationsList(BuildContext context, List<PolicyViolation> violations) {
    if (violations.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        padding: const EdgeInsets.all(AppDimensions.xl),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Column(
          children: [
            Icon(Icons.verified_user, size: 64, color: AppColors.success),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Nenhuma Violação',
              style: AppTextStyles.h3.copyWith(color: AppColors.success),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Você está seguindo todas as nossas políticas. Continue assim!',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Row(
              children: [
                Text('Histórico de Violações', style: AppTextStyles.h3),
                const SizedBox(width: AppDimensions.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${violations.length}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...violations.map((violation) => _buildViolationItem(violation)),
        ],
      ),
    );
  }

  Widget _buildViolationItem(PolicyViolation violation) {
    IconData icon;
    Color color;

    switch (violation.type) {
      case ViolationType.contactSharing:
        icon = Icons.phone_disabled;
        color = AppColors.error;
        break;
      case ViolationType.spam:
        icon = Icons.report;
        color = Colors.orange;
        break;
      case ViolationType.inappropriate:
        icon = Icons.block;
        color = AppColors.error;
        break;
      case ViolationType.noShow:
        icon = Icons.event_busy;
        color = AppColors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
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
                  _getViolationTitle(violation.type),
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  violation.description,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(violation.timestamp),
                  style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getViolationTitle(ViolationType type) {
    switch (type) {
      case ViolationType.contactSharing:
        return 'Partilha de Contacto';
      case ViolationType.spam:
        return 'Spam';
      case ViolationType.inappropriate:
        return 'Conteúdo Inapropriado';
      case ViolationType.noShow:
        return 'Não Comparecimento';
    }
  }

  Widget _buildGuidelinesCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nossas Políticas', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.md),
          _buildGuidelineItem(
            Icons.phone_disabled,
            'Não partilhar contactos',
            'Use apenas as mensagens do app para comunicar.',
          ),
          _buildGuidelineItem(
            Icons.handshake_outlined,
            'Ser respeitoso',
            'Trate todos os usuários com respeito e profissionalismo.',
          ),
          _buildGuidelineItem(
            Icons.event_available,
            'Cumprir compromissos',
            'Compareça às reservas confirmadas ou cancele com antecedência.',
          ),
          _buildGuidelineItem(
            Icons.verified_user,
            'Ser honesto',
            'Forneça informações verdadeiras sobre serviços e disponibilidade.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.peach, size: 24),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
