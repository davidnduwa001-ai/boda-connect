import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../../core/models/report_model.dart';
import '../../../../../core/constants/colors.dart';

class ReportCard extends StatelessWidget {
  final ReportModel report;
  final bool isAdminView;
  final VoidCallback? onTap;
  final VoidCallback? onAssign;
  final VoidCallback? onResolve;
  final VoidCallback? onDismiss;
  final VoidCallback? onEscalate;

  const ReportCard({
    super.key,
    required this.report,
    this.isAdminView = false,
    this.onTap,
    this.onAssign,
    this.onResolve,
    this.onDismiss,
    this.onEscalate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getSeverityColor(report.severity).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category and severity
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ReportCategoryInfo.getLabel(report.category),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildSeverityBadge(),
                ],
              ),
              const SizedBox(height: 8),

              // Status badge
              _buildStatusBadge(),
              const SizedBox(height: 12),

              // Reason preview
              Text(
                report.reason,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),

              // Evidence indicator
              if (report.evidence.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.photo_library, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${report.evidence.length} evidência(s)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // Metadata row
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    timeago.format(report.createdAt, locale: 'pt_BR'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (report.bookingId != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.event, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Reserva vinculada',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),

              // Admin actions (if admin view)
              if (isAdminView && report.status == ReportStatus.pending)
                _buildAdminActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityBadge() {
    final color = _getSeverityColor(report.severity);
    final label = _getSeverityLabel(report.severity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final color = _getStatusColor(report.status);
    final label = _getStatusLabel(report.status);
    final icon = _getStatusIcon(report.status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (onAssign != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAssign,
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Atribuir', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          if (onAssign != null && (onResolve != null || onDismiss != null))
            const SizedBox(width: 8),
          if (onResolve != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Resolver', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          if (onDismiss != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Rejeitar', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getSeverityColor(ReportSeverity severity) {
    switch (severity) {
      case ReportSeverity.critical:
        return Colors.red;
      case ReportSeverity.high:
        return Colors.orange;
      case ReportSeverity.medium:
        return Colors.amber;
      case ReportSeverity.low:
        return Colors.blue;
    }
  }

  String _getSeverityLabel(ReportSeverity severity) {
    switch (severity) {
      case ReportSeverity.critical:
        return 'CRÍTICO';
      case ReportSeverity.high:
        return 'ALTO';
      case ReportSeverity.medium:
        return 'MÉDIO';
      case ReportSeverity.low:
        return 'BAIXO';
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.investigating:
        return AppColors.info;
      case ReportStatus.resolved:
        return AppColors.success;
      case ReportStatus.dismissed:
        return Colors.grey;
      case ReportStatus.escalated:
        return Colors.red;
    }
  }

  String _getStatusLabel(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return 'Pendente';
      case ReportStatus.investigating:
        return 'Em Investigação';
      case ReportStatus.resolved:
        return 'Resolvido';
      case ReportStatus.dismissed:
        return 'Rejeitado';
      case ReportStatus.escalated:
        return 'Escalado';
    }
  }

  IconData _getStatusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Icons.hourglass_empty;
      case ReportStatus.investigating:
        return Icons.search;
      case ReportStatus.resolved:
        return Icons.check_circle;
      case ReportStatus.dismissed:
        return Icons.cancel;
      case ReportStatus.escalated:
        return Icons.warning;
    }
  }
}
