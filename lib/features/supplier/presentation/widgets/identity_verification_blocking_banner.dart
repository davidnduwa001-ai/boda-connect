import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/supplier_onboarding_service.dart';

/// Supplier-Side Identity Verification Blocking Banner/Screen
///
/// Prevents booking attempts when identity verification is pending.
/// Shows clear explanation of WHY bookings are blocked and WHAT to do next.
///
/// Trigger Condition:
/// - onboarding_status = approved (active)
/// - identity_verification_status != verified
///
/// EXPLICITLY DOES NOT:
/// - Mention admin approval
/// - Allow booking actions
/// - Bypass backend checks
///
/// Constraints:
/// - No Firestore reads (uses provided data)
/// - No eligibility logic in UI
/// - Backend remains authoritative
class IdentityVerificationBlockingBanner extends StatelessWidget {
  final SupplierOnboardingStatus status;
  final bool isCompact;
  final VoidCallback? onUploadDocuments;

  const IdentityVerificationBlockingBanner({
    super.key,
    required this.status,
    this.isCompact = false,
    this.onUploadDocuments,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if onboarding approved but identity not verified
    if (!status.isBlockedByIdentityVerification) {
      return const SizedBox.shrink();
    }

    if (isCompact) {
      return _buildCompactBanner(context);
    }

    return _buildFullBanner(context);
  }

  Widget _buildCompactBanner(BuildContext context) {
    final isRejected = status.isIdentityRejected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRejected
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRejected
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRejected
                  ? AppColors.error.withValues(alpha: 0.15)
                  : AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRejected ? Icons.gpp_bad : Icons.hourglass_top,
              color: isRejected ? AppColors.error : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRejected
                      ? 'Verificacao Rejeitada'
                      : 'Verificacao de Identidade Pendente',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isRejected ? AppColors.error : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reservas temporariamente indisponiveis',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateToVerification(context),
            style: TextButton.styleFrom(
              foregroundColor: isRejected ? AppColors.error : AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Ver mais'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBanner(BuildContext context) {
    final isRejected = status.isIdentityRejected;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isRejected
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusMd),
                topRight: Radius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isRejected
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRejected ? Icons.gpp_bad : Icons.fingerprint,
                    size: 36,
                    color: isRejected ? AppColors.error : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  'Reservas Temporariamente Indisponiveis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isRejected ? AppColors.error : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRejected ? Icons.cancel : Icons.hourglass_top,
                        size: 16,
                        color: isRejected ? AppColors.error : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.identityVerificationStatusText,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color:
                              isRejected ? AppColors.error : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reason section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Motivo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getReasonText(),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rejection reason (if rejected)
                if (isRejected &&
                    status.identityVerificationRejectionReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.feedback_outlined,
                              size: 18,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Feedback da Equipa',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status.identityVerificationRejectionReason!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Action required section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.peach.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.peach.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.assignment_turned_in,
                            size: 18,
                            color: AppColors.peach,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Acao Necessaria',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.peach,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getActionText(),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: onUploadDocuments ??
                        () => _navigateToVerification(context),
                    icon: Icon(
                      isRejected ? Icons.refresh : Icons.upload_file,
                      size: 20,
                    ),
                    label: Text(
                      isRejected
                          ? 'Reenviar Documentos'
                          : 'Enviar Documentos de Identidade',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.peach,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.buttonRadius),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Help button
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(Routes.helpCenter),
                    icon: const Icon(Icons.help_outline, size: 20),
                    label: const Text(
                      'Precisa de Ajuda?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.buttonRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.radiusMd),
                bottomRight: Radius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Verificacao de identidade protege voce e seus clientes',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getReasonText() {
    if (status.isIdentityRejected) {
      return 'A verificacao de identidade foi rejeitada. Por favor, reveja o feedback abaixo e envie novos documentos.';
    }
    return 'A verificacao de identidade e necessaria para garantir a seguranca da plataforma. Envie os seus documentos para desbloquear as reservas.';
  }

  String _getActionText() {
    if (status.isIdentityRejected) {
      return 'Envie documentos de identidade actualizados e claros para continuar a receber reservas.';
    }
    return 'Envie uma copia do seu Bilhete de Identidade ou Passaporte para completar a verificacao.';
  }

  void _navigateToVerification(BuildContext context) {
    // Navigate to document verification screen
    context.push(Routes.supplierDocumentVerification);
  }
}

/// Full-screen blocking widget for when identity verification is required
class IdentityVerificationBlockingScreen extends StatelessWidget {
  final SupplierOnboardingStatus status;
  final VoidCallback? onUploadDocuments;
  final VoidCallback? onLogout;

  const IdentityVerificationBlockingScreen({
    super.key,
    required this.status,
    this.onUploadDocuments,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.textSecondary),
              onPressed: onLogout,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: IdentityVerificationBlockingBanner(
            status: status,
            isCompact: false,
            onUploadDocuments: onUploadDocuments,
          ),
        ),
      ),
    );
  }
}
