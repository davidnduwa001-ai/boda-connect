import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/services/rate_limit_metrics_service.dart';
import 'package:flutter/material.dart';

/// Admin Dashboard Rate Limit Monitor - READ-ONLY
///
/// Displays rate limit activity at a glance using exportRateLimitMetrics.
/// - Active rate limits
/// - Users affected
/// - Top actions hitting limits
/// - Trend indicator
///
/// This widget NEVER writes data or enforces limits client-side.
class RateLimitDashboard extends StatefulWidget {
  final VoidCallback? onTapDetails;

  const RateLimitDashboard({
    super.key,
    this.onTapDetails,
  });

  @override
  State<RateLimitDashboard> createState() => _RateLimitDashboardState();
}

class _RateLimitDashboardState extends State<RateLimitDashboard> {
  final _service = RateLimitMetricsService();
  RateLimitMetrics? _metrics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _service.startAutoRefresh();
    _service.metricsStream.listen((metrics) {
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _isLoading = false;
          _error = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _service.stopAutoRefresh();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    try {
      final metrics = await _service.getMetrics();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load rate limit metrics';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null || _metrics == null) {
      return _buildErrorState();
    }

    return _buildDashboard(_metrics!);
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_outlined, color: AppColors.peach),
              const SizedBox(width: 8),
              Text(
                'Rate Limits',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Loading metrics...'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Rate Limit Monitor',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadMetrics();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Failed to load metrics',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(RateLimitMetrics metrics) {
    final totals = metrics.totals;
    final topAction = metrics.actionBreakdown.isNotEmpty
        ? metrics.actionBreakdown.first
        : null;

    // Determine severity color
    Color severityColor;
    String severityLabel;
    switch (metrics.severityLevel) {
      case 'high':
        severityColor = Colors.red;
        severityLabel = 'Alta';
        break;
      case 'medium':
        severityColor = Colors.orange;
        severityLabel = 'Media';
        break;
      case 'low':
        severityColor = Colors.yellow.shade700;
        severityLabel = 'Baixa';
        break;
      default:
        severityColor = Colors.green;
        severityLabel = 'Normal';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.speed_outlined, color: AppColors.peach, size: 20),
              const SizedBox(width: 8),
              Text(
                'Rate Limits',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Severity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      metrics.hasViolations
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 12,
                      color: severityColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      severityLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: severityColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadMetrics();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                    child: _buildMetricCard(
                      title: 'Ativos',
                      value: '${totals.activeRateLimits}',
                      icon: Icons.block_outlined,
                      color: totals.activeRateLimits > 0 ? Colors.red : Colors.green,
                      subtitle: 'rate limits',
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                    child: _buildMetricCard(
                      title: 'Usuarios',
                      value: '${totals.uniqueUsersLimited}',
                      icon: Icons.people_outline,
                      color: Colors.blue,
                      subtitle: 'afetados',
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                    child: _buildMetricCard(
                      title: 'Top Acao',
                      value: topAction?.displayName ?? 'Nenhuma',
                      icon: Icons.trending_up,
                      color: Colors.orange,
                      subtitle: topAction != null
                          ? '${topAction.hitCount} hits'
                          : 'tudo limpo',
                      isText: true,
                    ),
                  ),
                ],
              );
            },
          ),

          // Action breakdown (if any)
          if (metrics.actionBreakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Acoes Mais Frequentes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...metrics.actionBreakdown.take(3).map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      action.displayName,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: action.hitCount /
                            (metrics.actionBreakdown.first.hitCount > 0
                                ? metrics.actionBreakdown.first.hitCount
                                : 1),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.orange.shade400,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${action.hitCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            )),
          ],

          // Top offenders (if any)
          if (metrics.topOffenders.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Top Usuarios Afetados',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...metrics.topOffenders.take(3).map((offender) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      offender.displayUserId,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${offender.totalHits} hits',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],

          // View details link
          if (widget.onTapDetails != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onTapDetails,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver Detalhes'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.peach,
                ),
              ),
            ),
          ],

          // Last updated timestamp
          const SizedBox(height: 8),
          Text(
            'Periodo: ultimas ${metrics.hoursBack}h | Atualizado: ${_formatTimestamp(metrics.generatedAt)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool isText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isText ? 12 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'agora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m atras';
      if (diff.inHours < 24) return '${diff.inHours}h atras';
      return '${diff.inDays}d atras';
    } catch (_) {
      return isoTimestamp;
    }
  }
}
