import 'package:flutter/material.dart';
import '../../../../../core/models/safety_score_model.dart';
import '../../../../../core/constants/colors.dart';

class SafetyScoreCard extends StatelessWidget {
  final SafetyScoreModel score;
  final VoidCallback? onTap;

  const SafetyScoreCard({
    super.key,
    required this.score,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(score.status).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.shield, color: AppColors.info, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pontuação de Segurança',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 20),

              // Score display
              _buildScoreDisplay(),
              const SizedBox(height: 20),

              // Status badge
              _buildStatusBadge(),
              const SizedBox(height: 20),

              // Metrics grid
              _buildMetricsGrid(),
              const SizedBox(height: 20),

              // Badges
              if (score.badges.isNotEmpty) _buildBadges(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreDisplay() {
    final scoreColor = _getScoreColor(score.safetyScore);

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: score.safetyScore / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    score.safetyScore.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    'de 100',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getScoreLabel(score.safetyScore),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scoreColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusColor = _getStatusColor(score.status);
    final statusLabel = _getStatusLabel(score.status);
    final statusIcon = _getStatusIcon(score.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status da Conta',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métricas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                icon: Icons.star,
                label: 'Avaliação',
                value: score.totalReviews > 0
                    ? score.overallRating.toStringAsFixed(1)
                    : 'N/A',
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricItem(
                icon: Icons.flag,
                label: 'Denúncias',
                value: score.activeReportsCount.toString(),
                color: score.activeReportsCount > 0 ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                icon: Icons.check_circle,
                label: 'Conclusão',
                value: '${(score.completionRate * 100).toStringAsFixed(0)}%',
                color: score.completionRate >= 0.8 ? AppColors.success : AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricItem(
                icon: Icons.cancel,
                label: 'Cancelamento',
                value: '${(score.cancellationRate * 100).toStringAsFixed(0)}%',
                color: score.cancellationRate <= 0.2 ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conquistas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: score.badges.map((badge) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade100,
                    Colors.amber.shade200,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    BadgeInfo.getIcon(badge.type),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    BadgeInfo.getLabel(badge.type),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return Colors.amber;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _getScoreLabel(double score) {
    if (score >= 90) return 'Excelente';
    if (score >= 80) return 'Muito Bom';
    if (score >= 70) return 'Bom';
    if (score >= 60) return 'Regular';
    if (score >= 40) return 'Baixo';
    return 'Crítico';
  }

  Color _getStatusColor(SafetyStatus status) {
    switch (status) {
      case SafetyStatus.safe:
        return AppColors.success;
      case SafetyStatus.warning:
        return AppColors.warning;
      case SafetyStatus.probation:
        return AppColors.error;
      case SafetyStatus.suspended:
        return Colors.red.shade900;
    }
  }

  String _getStatusLabel(SafetyStatus status) {
    switch (status) {
      case SafetyStatus.safe:
        return 'Em Boa Situação';
      case SafetyStatus.warning:
        return 'Aviso';
      case SafetyStatus.probation:
        return 'Em Período de Teste';
      case SafetyStatus.suspended:
        return 'Suspenso';
    }
  }

  IconData _getStatusIcon(SafetyStatus status) {
    switch (status) {
      case SafetyStatus.safe:
        return Icons.verified_user;
      case SafetyStatus.warning:
        return Icons.warning;
      case SafetyStatus.probation:
        return Icons.error;
      case SafetyStatus.suspended:
        return Icons.block;
    }
  }
}
