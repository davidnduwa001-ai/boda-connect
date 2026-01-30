import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/services/admin_eligibility_service.dart';
import 'package:flutter/material.dart';

/// Admin Dashboard Supplier Eligibility Cards - READ-ONLY
///
/// Displays system health at a glance using exportMigrationMetrics.
/// - Total suppliers
/// - Eligible suppliers
/// - Blocked suppliers
/// - Top blocking reason
///
/// This widget NEVER writes data or computes eligibility client-side.
class SupplierEligibilityCards extends StatefulWidget {
  final VoidCallback? onTapEligible;
  final VoidCallback? onTapBlocked;
  final VoidCallback? onInspect;

  const SupplierEligibilityCards({
    super.key,
    this.onTapEligible,
    this.onTapBlocked,
    this.onInspect,
  });

  @override
  State<SupplierEligibilityCards> createState() => _SupplierEligibilityCardsState();
}

class _SupplierEligibilityCardsState extends State<SupplierEligibilityCards> {
  final _service = AdminEligibilityService();
  EligibilityMetrics? _metrics;
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
          _error = 'Failed to load eligibility metrics';
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

    return _buildCards(_metrics!);
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
              const Icon(Icons.analytics_outlined, color: AppColors.peach),
              const SizedBox(width: 8),
              Text(
                'Supplier Eligibility',
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
                'Eligibility Metrics',
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

  Widget _buildCards(EligibilityMetrics metrics) {
    final totals = metrics.totals;
    final topReason = _formatBlockingReason(metrics.topBlockingReason);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.analytics_outlined, color: AppColors.peach, size: 20),
            const SizedBox(width: 8),
            Text(
              'Supplier Eligibility',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (metrics.legacyFallbackActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Legacy Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
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
            final isWide = constraints.maxWidth > 600;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _buildMetricCard(
                    title: 'Total',
                    value: '${totals.totalSuppliers}',
                    icon: Icons.store_outlined,
                    color: Colors.blue,
                    subtitle: 'suppliers',
                  ),
                ),
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _buildMetricCard(
                    title: 'Eligible',
                    value: '${totals.eligible}',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    subtitle: '${totals.eligiblePercentage.toStringAsFixed(0)}% ready',
                    onTap: widget.onTapEligible,
                  ),
                ),
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _buildMetricCard(
                    title: 'Blocked',
                    value: '${totals.blocked}',
                    icon: Icons.block_outlined,
                    color: Colors.red,
                    subtitle: 'cannot book',
                    onTap: widget.onTapBlocked,
                  ),
                ),
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _buildMetricCard(
                    title: 'Top Block',
                    value: topReason ?? 'None',
                    icon: Icons.warning_amber_outlined,
                    color: Colors.orange,
                    subtitle: topReason != null
                        ? '${metrics.topBlockingReasonCount} suppliers'
                        : 'all clear',
                    isText: true,
                  ),
                ),
              ],
            );
          },
        ),

        // Migration status note
        if (metrics.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: metrics.legacyFallbackActive
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: metrics.legacyFallbackActive
                    ? Colors.orange.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  metrics.legacyFallbackActive
                      ? Icons.sync_outlined
                      : Icons.check_circle_outline,
                  size: 16,
                  color: metrics.legacyFallbackActive
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metrics.notes.first,
                    style: TextStyle(
                      fontSize: 12,
                      color: metrics.legacyFallbackActive
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Inspector link
        if (widget.onInspect != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onInspect,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Inspect Supplier'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.peach,
              ),
            ),
          ),
        ],

        // Last updated timestamp
        const SizedBox(height: 8),
        Text(
          'Updated: ${_formatTimestamp(metrics.generatedAt)}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool isText = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5), size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: isText ? 14 : 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatBlockingReason(String? reason) {
    if (reason == null) return null;
    // Convert snake_case to readable
    switch (reason) {
      case 'lifecycle_not_active':
        return 'Lifecycle';
      case 'payouts_not_ready':
        return 'Payouts';
      case 'kyc_not_verified':
        return 'KYC';
      case 'not_listed':
        return 'Visibility';
      case 'globally_blocked':
        return 'Paused';
      case 'date_blocked':
        return 'Date';
      case 'rate_limited':
        return 'Rate Limit';
      default:
        return reason.replaceAll('_', ' ').split(' ').map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w
        ).join(' ');
    }
  }

  String _formatTimestamp(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return isoTimestamp;
    }
  }
}
