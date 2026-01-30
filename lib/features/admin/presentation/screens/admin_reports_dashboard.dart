import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/report_model.dart';
import '../../../../core/providers/report_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../common/presentation/widgets/report/report_card.dart';

class AdminReportsDashboard extends ConsumerStatefulWidget {
  const AdminReportsDashboard({super.key});

  @override
  ConsumerState<AdminReportsDashboard> createState() => _AdminReportsDashboardState();
}

class _AdminReportsDashboardState extends ConsumerState<AdminReportsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Denúncias - Administração'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pendentes'),
            Tab(text: 'Investigando'),
            Tab(text: 'Resolvidas'),
            Tab(text: 'Rejeitadas'),
            Tab(text: 'Escaladas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsList(ReportStatus.pending),
          _buildReportsList(ReportStatus.investigating),
          _buildReportsList(ReportStatus.resolved),
          _buildReportsList(ReportStatus.dismissed),
          _buildReportsList(ReportStatus.escalated),
        ],
      ),
    );
  }

  Widget _buildReportsList(ReportStatus status) {
    final reportsAsync = ref.watch(reportsByStatusProvider(status));

    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return _buildEmptyState(status);
        }

        // Sort by severity (critical first) and then by date
        final sortedReports = List<ReportModel>.from(reports)
          ..sort((a, b) {
            // First compare by severity (critical > high > medium > low)
            final severityOrder = {
              ReportSeverity.critical: 0,
              ReportSeverity.high: 1,
              ReportSeverity.medium: 2,
              ReportSeverity.low: 3,
            };
            final severityCompare = severityOrder[a.severity]!
                .compareTo(severityOrder[b.severity]!);
            if (severityCompare != 0) return severityCompare;

            // Then by date (newest first)
            return b.createdAt.compareTo(a.createdAt);
          });

        return Column(
          children: [
            // Stats summary
            _buildStatsSummary(reports),
            const SizedBox(height: 8),

            // Reports list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(reportsByStatusProvider(status));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedReports.length,
                  itemBuilder: (context, index) {
                    final report = sortedReports[index];
                    return ReportCard(
                      report: report,
                      isAdminView: true,
                      onTap: () => _showReportDetails(context, report),
                      onAssign: status == ReportStatus.pending
                          ? () => _assignReport(report)
                          : null,
                      onResolve: status == ReportStatus.pending ||
                              status == ReportStatus.investigating
                          ? () => _resolveReport(report)
                          : null,
                      onDismiss: status == ReportStatus.pending ||
                              status == ReportStatus.investigating
                          ? () => _dismissReport(report)
                          : null,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Erro ao carregar denúncias: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(reportsByStatusProvider(status));
              },
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary(List<ReportModel> reports) {
    final criticalCount =
        reports.where((r) => r.severity == ReportSeverity.critical).length;
    final highCount =
        reports.where((r) => r.severity == ReportSeverity.high).length;
    final mediumCount =
        reports.where((r) => r.severity == ReportSeverity.medium).length;
    final lowCount =
        reports.where((r) => r.severity == ReportSeverity.low).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          _buildStatItem('Total', reports.length.toString(), Colors.grey),
          if (criticalCount > 0)
            _buildStatItem('Crítico', criticalCount.toString(), Colors.red),
          if (highCount > 0)
            _buildStatItem('Alto', highCount.toString(), Colors.orange),
          if (mediumCount > 0)
            _buildStatItem('Médio', mediumCount.toString(), Colors.amber),
          if (lowCount > 0)
            _buildStatItem('Baixo', lowCount.toString(), Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ReportStatus status) {
    String message;
    IconData icon;

    switch (status) {
      case ReportStatus.pending:
        message = 'Nenhuma denúncia pendente';
        icon = Icons.inbox;
        break;
      case ReportStatus.investigating:
        message = 'Nenhuma denúncia em investigação';
        icon = Icons.search_off;
        break;
      case ReportStatus.resolved:
        message = 'Nenhuma denúncia resolvida';
        icon = Icons.check_circle_outline;
        break;
      case ReportStatus.dismissed:
        message = 'Nenhuma denúncia rejeitada';
        icon = Icons.cancel_outlined;
        break;
      case ReportStatus.escalated:
        message = 'Nenhuma denúncia escalada';
        icon = Icons.warning_amber_outlined;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(BuildContext context, ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _ReportDetailsView(
            report: report,
            scrollController: scrollController,
            onAssign: () {
              Navigator.pop(context);
              _assignReport(report);
            },
            onResolve: () {
              Navigator.pop(context);
              _resolveReport(report);
            },
            onDismiss: () {
              Navigator.pop(context);
              _dismissReport(report);
            },
            onEscalate: () {
              Navigator.pop(context);
              _escalateReport(report);
            },
          );
        },
      ),
    );
  }

  Future<void> _assignReport(ReportModel report) async {
    // Show dialog to select admin
    final selectedAdmin = await showDialog<String>(
      context: context,
      builder: (context) => _AdminSelectionDialog(currentAssignee: report.assignedTo),
    );

    if (selectedAdmin == null) return;

    final repository = ref.read(reportRepositoryProvider);

    // First assign to admin
    final assigned = await repository.assignReport(
      reportId: report.id,
      adminId: selectedAdmin,
    );

    if (!assigned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atribuir denúncia'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Then update status to investigating
    final success = await repository.updateReportStatus(
      reportId: report.id,
      status: ReportStatus.investigating,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Denúncia atribuída e em investigação'),
          backgroundColor: AppColors.success,
        ),
      );
      ref.invalidate(reportsByStatusProvider(ReportStatus.pending));
      ref.invalidate(reportsByStatusProvider(ReportStatus.investigating));
    }
  }

  Future<void> _resolveReport(ReportModel report) async {
    final resolution = await _showResolutionDialog(context);
    if (resolution == null || resolution.isEmpty) return;

    final repository = ref.read(reportRepositoryProvider);
    final success = await repository.updateReportStatus(
      reportId: report.id,
      status: ReportStatus.resolved,
      resolution: resolution,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Denúncia resolvida'),
          backgroundColor: AppColors.success,
        ),
      );
      ref.invalidate(reportsByStatusProvider(report.status));
      ref.invalidate(reportsByStatusProvider(ReportStatus.resolved));
    }
  }

  Future<void> _dismissReport(ReportModel report) async {
    final resolution = await _showResolutionDialog(context, isDismissal: true);
    if (resolution == null || resolution.isEmpty) return;

    final repository = ref.read(reportRepositoryProvider);
    final success = await repository.updateReportStatus(
      reportId: report.id,
      status: ReportStatus.dismissed,
      resolution: resolution,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Denúncia rejeitada'),
          backgroundColor: AppColors.warning,
        ),
      );
      ref.invalidate(reportsByStatusProvider(report.status));
      ref.invalidate(reportsByStatusProvider(ReportStatus.dismissed));
    }
  }

  Future<void> _escalateReport(ReportModel report) async {
    final repository = ref.read(reportRepositoryProvider);
    final success = await repository.escalateReport(report.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Denúncia escalada'),
          backgroundColor: AppColors.error,
        ),
      );
      ref.invalidate(reportsByStatusProvider(report.status));
      ref.invalidate(reportsByStatusProvider(ReportStatus.escalated));
    }
  }

  Future<String?> _showResolutionDialog(
    BuildContext context, {
    bool isDismissal = false,
  }) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDismissal ? 'Rejeitar Denúncia' : 'Resolver Denúncia'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: isDismissal
                ? 'Motivo da rejeição...'
                : 'Ações tomadas e resolução...',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _ReportDetailsView extends StatelessWidget {
  final ReportModel report;
  final ScrollController scrollController;
  final VoidCallback? onAssign;
  final VoidCallback? onResolve;
  final VoidCallback? onDismiss;
  final VoidCallback? onEscalate;

  const _ReportDetailsView({
    required this.report,
    required this.scrollController,
    this.onAssign,
    this.onResolve,
    this.onDismiss,
    this.onEscalate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: scrollController,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  ReportCategoryInfo.getLabel(report.category),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Severity and Status
          Row(
            children: [
              _buildSeverityBadge(),
              const SizedBox(width: 8),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 24),

          // Reporter and Reported Info
          _buildInfoSection('Denunciante', report.reporterId, report.reporterType),
          const SizedBox(height: 16),
          _buildInfoSection('Denunciado', report.reportedId, report.reportedType),
          const SizedBox(height: 24),

          // Reason
          const Text(
            'Descrição',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.reason,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 24),

          // Evidence
          if (report.evidence.isNotEmpty) ...[
            const Text(
              'Evidências',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: report.evidence.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        report.evidence[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Context
          if (report.bookingId != null) ...[
            _buildContextItem(Icons.event, 'Reserva', report.bookingId!),
            const SizedBox(height: 8),
          ],
          if (report.reviewId != null) ...[
            _buildContextItem(Icons.star, 'Avaliação', report.reviewId!),
            const SizedBox(height: 8),
          ],
          if (report.chatId != null) ...[
            _buildContextItem(Icons.chat, 'Chat', report.chatId!),
            const SizedBox(height: 24),
          ],

          // Resolution (if resolved/dismissed)
          if (report.resolution != null) ...[
            const Text(
              'Resolução',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(report.resolution!),
            ),
            const SizedBox(height: 24),
          ],

          // Actions
          if (report.status == ReportStatus.pending ||
              report.status == ReportStatus.investigating)
            _buildActions(),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge() {
    Color color;
    String label;

    switch (report.severity) {
      case ReportSeverity.critical:
        color = Colors.red;
        label = 'CRÍTICO';
        break;
      case ReportSeverity.high:
        color = Colors.orange;
        label = 'ALTO';
        break;
      case ReportSeverity.medium:
        color = Colors.amber;
        label = 'MÉDIO';
        break;
      case ReportSeverity.low:
        color = Colors.blue;
        label = 'BAIXO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;

    switch (report.status) {
      case ReportStatus.pending:
        color = Colors.orange;
        label = 'Pendente';
        break;
      case ReportStatus.investigating:
        color = AppColors.info;
        label = 'Investigando';
        break;
      case ReportStatus.resolved:
        color = AppColors.success;
        label = 'Resolvido';
        break;
      case ReportStatus.dismissed:
        color = Colors.grey;
        label = 'Rejeitado';
        break;
      case ReportStatus.escalated:
        color = Colors.red;
        label = 'Escalado';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String userId, String userType) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            userType == 'supplier' ? Icons.business : Icons.person,
            color: AppColors.info,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  userType == 'supplier' ? 'Fornecedor' : 'Cliente',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextItem(IconData icon, String label, String id) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          id,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        if (onAssign != null && report.status == ReportStatus.pending)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAssign,
              icon: const Icon(Icons.person_add),
              label: const Text('Iniciar Investigação'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (onResolve != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onResolve,
              icon: const Icon(Icons.check_circle),
              label: const Text('Resolver Denúncia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (onDismiss != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Rejeitar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (onDismiss != null && onEscalate != null)
              const SizedBox(width: 8),
            if (onEscalate != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEscalate,
                  icon: const Icon(Icons.warning),
                  label: const Text('Escalar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ==================== ADMIN SELECTION DIALOG ====================

class _AdminSelectionDialog extends StatefulWidget {
  final String? currentAssignee;

  const _AdminSelectionDialog({this.currentAssignee});

  @override
  State<_AdminSelectionDialog> createState() => _AdminSelectionDialogState();
}

class _AdminSelectionDialogState extends State<_AdminSelectionDialog> {
  String? _selectedAdmin;
  bool _isLoading = true;
  List<Map<String, String>> _admins = [];

  @override
  void initState() {
    super.initState();
    _selectedAdmin = widget.currentAssignee;
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    // In a real app, fetch from Firestore users collection where role == 'admin'
    // For now, use placeholder data
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _admins = [
          {'id': 'admin_001', 'name': 'João Silva', 'role': 'Administrador Principal'},
          {'id': 'admin_002', 'name': 'Maria Santos', 'role': 'Moderador'},
          {'id': 'admin_003', 'name': 'Pedro Alves', 'role': 'Moderador'},
          {'id': 'admin_004', 'name': 'Ana Costa', 'role': 'Suporte'},
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atribuir Denúncia'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.peach),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecione um administrador para investigar esta denúncia:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _admins.length,
                    itemBuilder: (context, index) {
                      final admin = _admins[index];
                      final isSelected = _selectedAdmin == admin['id'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.peach : AppColors.gray200,
                          child: Text(
                            admin['name']![0],
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.gray700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          admin['name']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          admin['role']!,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.peach)
                            : null,
                        selected: isSelected,
                        selectedTileColor: AppColors.peachLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedAdmin = admin['id'];
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedAdmin == null
              ? null
              : () => Navigator.pop(context, _selectedAdmin),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.peach,
            disabledBackgroundColor: AppColors.gray300,
          ),
          child: const Text('Atribuir'),
        ),
      ],
    );
  }
}
