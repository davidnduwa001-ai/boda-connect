import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/services/supplier_onboarding_service.dart';

/// Admin Identity Verification Panel - READ-ONLY + Controlled Actions
///
/// Clearly separates Onboarding approval from Identity verification.
/// Displays identity verification status and allows admin actions.
///
/// Data source: Uses existing SupplierOnboardingStatus data from backend.
/// - NEVER writes data directly to Firestore
/// - All actions go through SupplierOnboardingService (backend authoritative)
class IdentityVerificationPanel extends StatelessWidget {
  final SupplierOnboardingStatus supplier;
  final String adminId;
  final VoidCallback? onStatusChanged;

  const IdentityVerificationPanel({
    super.key,
    required this.supplier,
    required this.adminId,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Status Badge
          _buildStatusBadge(),
          const SizedBox(height: 16),

          // Booking Eligibility Warning (if not verified)
          if (!supplier.isIdentityVerified) _buildEligibilityWarning(),

          // Verification Details (if verified or rejected)
          if (supplier.identityVerifiedAt != null) ...[
            const SizedBox(height: 12),
            _buildVerificationDetails(),
          ],

          // Rejection Reason (if rejected)
          if (supplier.isIdentityRejected &&
              supplier.identityVerificationRejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildRejectionReason(),
          ],

          // Document Preview Section
          if (supplier.idDocumentUrl != null ||
              supplier.verificationDocuments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDocumentSection(context),
          ],

          // Admin Actions
          const SizedBox(height: 16),
          _buildAdminActions(context),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (supplier.identityVerificationStatus) {
      case IdentityVerificationStatus.verified:
        return AppColors.success.withValues(alpha: 0.05);
      case IdentityVerificationStatus.rejected:
        return AppColors.error.withValues(alpha: 0.05);
      case IdentityVerificationStatus.pending:
        return AppColors.warning.withValues(alpha: 0.05);
    }
  }

  Color _getBorderColor() {
    switch (supplier.identityVerificationStatus) {
      case IdentityVerificationStatus.verified:
        return AppColors.success.withValues(alpha: 0.3);
      case IdentityVerificationStatus.rejected:
        return AppColors.error.withValues(alpha: 0.3);
      case IdentityVerificationStatus.pending:
        return AppColors.warning.withValues(alpha: 0.3);
    }
  }

  Color _getStatusColor() {
    switch (supplier.identityVerificationStatus) {
      case IdentityVerificationStatus.verified:
        return AppColors.success;
      case IdentityVerificationStatus.rejected:
        return AppColors.error;
      case IdentityVerificationStatus.pending:
        return AppColors.warning;
    }
  }

  IconData _getStatusIcon() {
    switch (supplier.identityVerificationStatus) {
      case IdentityVerificationStatus.verified:
        return Icons.verified_user;
      case IdentityVerificationStatus.rejected:
        return Icons.gpp_bad;
      case IdentityVerificationStatus.pending:
        return Icons.hourglass_top;
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.fingerprint,
            color: _getStatusColor(),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VERIFICACAO DE IDENTIDADE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Separado da aprovacao de onboarding',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(),
                size: 16,
                color: _getStatusColor(),
              ),
              const SizedBox(width: 6),
              Text(
                supplier.identityVerificationStatusText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _getStatusColor(),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Eligibility indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: supplier.isEligibleForBookings
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                supplier.isEligibleForBookings
                    ? Icons.check_circle
                    : Icons.block,
                size: 14,
                color: supplier.isEligibleForBookings
                    ? AppColors.success
                    : AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                supplier.isEligibleForBookings
                    ? 'Reservas Activas'
                    : 'Reservas Bloqueadas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: supplier.isEligibleForBookings
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEligibilityWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reservas estao bloqueadas ate a verificacao de identidade ser concluida',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.calendar_today,
            label: 'Data da Verificacao',
            value: supplier.identityVerifiedAt != null
                ? DateFormat('dd/MM/yyyy HH:mm')
                    .format(supplier.identityVerifiedAt!)
                : 'N/A',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.admin_panel_settings,
            label: 'Verificado por',
            value: supplier.identityVerifiedBy ?? 'Sistema',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildRejectionReason() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.error),
              const SizedBox(width: 6),
              Text(
                'Motivo da Rejeicao',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            supplier.identityVerificationRejectionReason!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(BuildContext context) {
    final allDocs = <String>[
      if (supplier.idDocumentUrl != null) supplier.idDocumentUrl!,
      ...supplier.verificationDocuments,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Documentos de Verificacao (${allDocs.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (allDocs.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Nenhum documento de identidade enviado',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allDocs.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              return _buildDocumentThumbnail(context, url, index);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDocumentThumbnail(BuildContext context, String url, int index) {
    return GestureDetector(
      onTap: () => _showDocumentPreview(context, url),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          image: DecorationImage(
            image: NetworkImage(url),
            fit: BoxFit.cover,
            onError: (_, __) {},
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.zoom_in,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentPreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Erro ao carregar documento',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACOES DO ADMINISTRADOR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Mark as Verified button
            if (!supplier.isIdentityVerified)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showVerifyConfirmation(context),
                  icon: const Icon(Icons.verified_user, size: 18),
                  label: const Text('Verificar Identidade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (!supplier.isIdentityVerified &&
                !supplier.isIdentityRejected)
              const SizedBox(width: 8),
            // Reject button
            if (!supplier.isIdentityRejected)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(context),
                  icon: const Icon(Icons.gpp_bad, size: 18),
                  label: const Text('Rejeitar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            // Reset to pending (if already verified or rejected)
            if (supplier.isIdentityVerified || supplier.isIdentityRejected)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showResetConfirmation(context),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reiniciar Verificacao'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showVerifyConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: AppColors.success),
            SizedBox(width: 12),
            Text('Verificar Identidade'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tem a certeza que deseja marcar a identidade deste fornecedor como verificada?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Isto permitira que o fornecedor receba reservas.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirmar Verificacao'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final service = SupplierOnboardingService();
      final success = await service.verifyIdentity(
        supplierId: supplier.supplierId,
        adminId: adminId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Identidade verificada com sucesso!'
                  : 'Erro ao verificar identidade',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );

        if (success) onStatusChanged?.call();
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gpp_bad, color: AppColors.error),
            SizedBox(width: 12),
            Text('Rejeitar Verificacao'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indique o motivo da rejeicao da verificacao de identidade:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Ex: Documento ilegivel, dados nao correspondem ao perfil...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'O fornecedor nao podera receber reservas ate corrigir.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Rejeitar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      final service = SupplierOnboardingService();
      final success = await service.rejectIdentityVerification(
        supplierId: supplier.supplierId,
        adminId: adminId,
        rejectionReason: result,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Verificacao rejeitada'
                  : 'Erro ao rejeitar verificacao',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );

        if (success) onStatusChanged?.call();
      }
    }
  }

  Future<void> _showResetConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: AppColors.warning),
            SizedBox(width: 12),
            Text('Reiniciar Verificacao'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tem a certeza que deseja reiniciar a verificacao de identidade?',
            ),
            SizedBox(height: 12),
            Text(
              'O estado sera alterado para "Pendente" e o fornecedor devera reenviar os documentos.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reiniciar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final service = SupplierOnboardingService();
      final success = await service.resetIdentityVerification(
        supplierId: supplier.supplierId,
        adminId: adminId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Verificacao reiniciada'
                  : 'Erro ao reiniciar verificacao',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );

        if (success) onStatusChanged?.call();
      }
    }
  }
}
