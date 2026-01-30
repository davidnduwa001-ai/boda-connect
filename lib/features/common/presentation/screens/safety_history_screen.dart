import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/models/safety_score_model.dart';
import '../../../../core/providers/safety_score_provider.dart';
import '../../../../core/constants/colors.dart';
import '../widgets/safety/safety_score_card.dart';

class SafetyHistoryScreen extends ConsumerWidget {
  final String userId;

  const SafetyHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyScoreAsync = ref.watch(userSafetyScoreProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Segurança'),
        elevation: 0,
      ),
      body: safetyScoreAsync.when(
        data: (score) {
          if (score == null) {
            return _buildNoScoreView(context, ref);
          }
          return _buildHistoryView(context, score);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Erro ao carregar histórico: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(userSafetyScoreProvider(userId));
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoScoreView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Nenhuma pontuação de segurança disponível',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final notifier = ref.read(safetyScoreProvider.notifier);
              await notifier.calculateSafetyScore(userId);
              ref.invalidate(userSafetyScoreProvider(userId));
            },
            icon: const Icon(Icons.calculate),
            label: const Text('Calcular Pontuação'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView(BuildContext context, SafetyScoreModel score) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Safety Score Card
          SafetyScoreCard(score: score),
          const SizedBox(height: 24),

          // Warning History
          if (score.warningCount > 0) ...[
            _buildSectionHeader('Histórico de Avisos'),
            const SizedBox(height: 12),
            _buildWarningHistory(score),
            const SizedBox(height: 24),
          ],

          // Probation Info
          if (score.isOnProbation) ...[
            _buildSectionHeader('Informações de Período de Teste'),
            const SizedBox(height: 12),
            _buildProbationInfo(score),
            const SizedBox(height: 24),
          ],

          // Suspension Info
          if (score.isSuspended) ...[
            _buildSectionHeader('Informações de Suspensão'),
            const SizedBox(height: 12),
            _buildSuspensionInfo(score),
            const SizedBox(height: 24),
          ],

          // Badges Section
          if (score.badges.isNotEmpty) ...[
            _buildSectionHeader('Conquistas'),
            const SizedBox(height: 12),
            _buildBadgesList(score.badges),
            const SizedBox(height: 24),
          ],

          // Metrics Detail
          _buildSectionHeader('Detalhes das Métricas'),
          const SizedBox(height: 12),
          _buildMetricsDetail(score),
          const SizedBox(height: 24),

          // Last Updated
          _buildLastUpdated(score),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildWarningHistory(SafetyScoreModel score) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Total de Avisos: ${score.warningCount}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (score.lastWarningDate != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Último aviso: ${timeago.format(score.lastWarningDate!, locale: 'pt_BR')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProbationInfo(SafetyScoreModel score) {
    return Card(
      elevation: 2,
      color: AppColors.error.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: AppColors.error),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Conta em Período de Teste',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sua conta está em período de teste devido a múltiplas violações. '
              'Por favor, siga as diretrizes da plataforma para evitar suspensão.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (score.probationStartDate != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Início: ${timeago.format(score.probationStartDate!, locale: 'pt_BR')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuspensionInfo(SafetyScoreModel score) {
    final isPermanent = score.suspensionEndDate == null;

    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: Colors.red),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Conta Suspensa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isPermanent
                  ? 'Sua conta foi suspensa permanentemente devido a violações graves das diretrizes da plataforma.'
                  : 'Sua conta foi suspensa temporariamente. Por favor, revise as diretrizes da plataforma.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            if (score.suspensionStartDate != null)
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Início: ${timeago.format(score.suspensionStartDate!, locale: 'pt_BR')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            if (!isPermanent && score.suspensionEndDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Término: ${timeago.format(score.suspensionEndDate!, locale: 'pt_BR')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesList(List<Badge> badges) {
    return Column(
      children: badges.map((badge) {
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade100, Colors.amber.shade200],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: Center(
                child: Text(
                  BadgeInfo.getIcon(badge.type),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            title: Text(
              BadgeInfo.getLabel(badge.type),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(BadgeInfo.getDescription(badge.type)),
            trailing: Text(
              timeago.format(badge.awardedAt, locale: 'pt_BR'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricsDetail(SafetyScoreModel score) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow(
              'Avaliação Geral',
              score.totalReviews > 0
                  ? '${score.overallRating.toStringAsFixed(2)} ⭐'
                  : 'Nenhuma avaliação',
              '${score.totalReviews} avaliações',
            ),
            const Divider(),
            _buildMetricRow(
              'Denúncias Totais',
              score.totalReports.toString(),
              '${score.activeReportsCount} ativas',
            ),
            const Divider(),
            _buildMetricRow(
              'Taxa de Conclusão',
              '${(score.completionRate * 100).toStringAsFixed(1)}%',
              score.completionRate >= 0.8 ? 'Excelente' : 'Precisa Melhorar',
            ),
            const Divider(),
            _buildMetricRow(
              'Taxa de Cancelamento',
              '${(score.cancellationRate * 100).toStringAsFixed(1)}%',
              score.cancellationRate <= 0.2 ? 'Bom' : 'Alto',
            ),
            const Divider(),
            _buildMetricRow(
              'Taxa de Resposta',
              '${(score.responseRate * 100).toStringAsFixed(1)}%',
              score.responseRate >= 0.9 ? 'Excelente' : 'Pode Melhorar',
            ),
            const Divider(),
            _buildMetricRow(
              'Taxa de Pontualidade',
              '${(score.onTimeRate * 100).toStringAsFixed(1)}%',
              score.onTimeRate >= 0.8 ? 'Pontual' : 'Atrasado',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(SafetyScoreModel score) {
    return Center(
      child: Text(
        'Última atualização: ${timeago.format(score.lastCalculated, locale: 'pt_BR')}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
