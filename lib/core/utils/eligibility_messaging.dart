import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/supplier_model.dart';
import '../services/supplier_onboarding_service.dart';

/// Eligibility Messaging Utility - UI ONLY, NO LOGIC
///
/// Aligns UI messaging with existing backend eligibility rules.
/// Ensures consistent error messaging across:
/// - Admin dashboard
/// - Supplier app
/// - Booking attempts
///
/// RULES (DO NOT CHANGE - Backend authoritative):
/// Eligibility requires:
/// - onboarding_status === approved (active)
/// - identity_verification_status === verified
///
/// This utility DOES NOT:
/// - Implement eligibility logic
/// - Change backend behavior
/// - Query Firestore
///
/// It ONLY provides:
/// - Human-readable error messages
/// - UI state helpers
/// - Consistent messaging strings
class EligibilityMessaging {
  EligibilityMessaging._();

  // ==================== ERROR CODE MAPPING ====================

  /// Maps backend error codes to human-readable messages (Portuguese)
  static String mapErrorToMessage(String errorCode, {String? context}) {
    switch (errorCode) {
      // Identity verification errors
      case 'failed-precondition':
      case 'identity-verification-pending':
        return 'Verificacao de identidade pendente. Por favor, complete a verificacao para aceitar reservas.';

      case 'identity-verification-rejected':
        return 'A verificacao de identidade foi rejeitada. Por favor, envie novos documentos.';

      // Onboarding errors
      case 'onboarding-pending':
        return 'A sua candidatura esta em analise. Aguarde a aprovacao para aceitar reservas.';

      case 'onboarding-rejected':
        return 'A sua candidatura foi rejeitada. Contacte o suporte para mais informacoes.';

      case 'account-suspended':
        return 'A sua conta foi suspensa. Contacte o suporte para mais informacoes.';

      // Generic errors
      case 'not-eligible':
        return 'Nao esta elegivel para aceitar reservas neste momento.';

      case 'permission-denied':
        return 'Sem permissao para realizar esta acao.';

      default:
        return context ?? 'Ocorreu um erro. Tente novamente mais tarde.';
    }
  }

  // ==================== STATUS MESSAGES ====================

  /// Get eligibility status message for supplier
  static String getSupplierEligibilityMessage(SupplierOnboardingStatus status) {
    // Not yet approved
    if (status.accountStatus != SupplierAccountStatus.active) {
      return _getOnboardingStatusMessage(status.accountStatus);
    }

    // Approved but identity not verified
    if (!status.isIdentityVerified) {
      return _getIdentityVerificationMessage(status.identityVerificationStatus);
    }

    // Fully eligible
    return 'Conta activa e verificada. Pode aceitar reservas.';
  }

  static String _getOnboardingStatusMessage(SupplierAccountStatus status) {
    switch (status) {
      case SupplierAccountStatus.pendingReview:
        return 'A sua candidatura esta em analise. Recebera uma notificacao quando for aprovada.';
      case SupplierAccountStatus.needsClarification:
        return 'Sao necessarias alteracoes na sua candidatura. Reveja o feedback e resubmeta.';
      case SupplierAccountStatus.rejected:
        return 'A sua candidatura foi rejeitada. Consulte o motivo para mais detalhes.';
      case SupplierAccountStatus.suspended:
        return 'A sua conta foi suspensa. Contacte o suporte para mais informacoes.';
      case SupplierAccountStatus.active:
        return 'Conta aprovada.';
    }
  }

  static String _getIdentityVerificationMessage(
      IdentityVerificationStatus status) {
    switch (status) {
      case IdentityVerificationStatus.pending:
        return 'Verificacao de identidade pendente. Envie os seus documentos para desbloquear reservas.';
      case IdentityVerificationStatus.rejected:
        return 'Verificacao de identidade rejeitada. Por favor, envie novos documentos.';
      case IdentityVerificationStatus.verified:
        return 'Identidade verificada.';
    }
  }

  // ==================== ADMIN MESSAGES ====================

  /// Get admin-facing eligibility summary
  static String getAdminEligibilitySummary(SupplierOnboardingStatus status) {
    final List<String> issues = [];

    if (status.accountStatus != SupplierAccountStatus.active) {
      issues.add('Onboarding: ${status.statusText}');
    }

    if (!status.isIdentityVerified) {
      issues.add('Identidade: ${status.identityVerificationStatusText}');
    }

    if (issues.isEmpty) {
      return 'Elegivel para reservas';
    }

    return 'Bloqueado: ${issues.join(', ')}';
  }

  /// Get detailed admin-facing explanation
  static String getAdminEligibilityExplanation(SupplierOnboardingStatus status) {
    if (status.isEligibleForBookings) {
      return 'Este fornecedor pode receber e aceitar reservas normalmente.';
    }

    final StringBuffer explanation = StringBuffer();
    explanation.writeln('Este fornecedor NAO pode receber reservas porque:');
    explanation.writeln();

    if (status.accountStatus != SupplierAccountStatus.active) {
      explanation.writeln(
          '• Onboarding nao aprovado (estado: ${status.statusText})');
    }

    if (!status.isIdentityVerified) {
      explanation.writeln(
          '• Identidade nao verificada (estado: ${status.identityVerificationStatusText})');
    }

    return explanation.toString().trim();
  }

  // ==================== HELPER TEXTS ====================

  /// Important clarification about approval vs verification
  static const String approvalVsVerificationNote =
      'A aprovacao de onboarding NAO desbloqueia reservas ate que a verificacao de identidade esteja completa.';

  /// Short version for compact UI
  static const String approvalVsVerificationNoteShort =
      'Requer aprovacao + verificacao de identidade';

  /// Booking blocked explanation
  static String getBookingBlockedReason(SupplierOnboardingStatus status) {
    if (status.accountStatus != SupplierAccountStatus.active) {
      return 'Onboarding pendente';
    }
    if (!status.isIdentityVerified) {
      return 'Verificacao de identidade pendente';
    }
    return 'Conta activa';
  }

  // ==================== UI HELPERS ====================

  /// Get color for eligibility status
  static Color getEligibilityColor(SupplierOnboardingStatus status) {
    if (status.isEligibleForBookings) {
      return AppColors.success;
    }
    if (status.accountStatus == SupplierAccountStatus.rejected ||
        status.accountStatus == SupplierAccountStatus.suspended ||
        status.isIdentityRejected) {
      return AppColors.error;
    }
    return AppColors.warning;
  }

  /// Get icon for eligibility status
  static IconData getEligibilityIcon(SupplierOnboardingStatus status) {
    if (status.isEligibleForBookings) {
      return Icons.check_circle;
    }
    if (status.accountStatus == SupplierAccountStatus.rejected ||
        status.accountStatus == SupplierAccountStatus.suspended ||
        status.isIdentityRejected) {
      return Icons.cancel;
    }
    return Icons.hourglass_top;
  }

  /// Check if CTA should be disabled
  static bool shouldDisableBookingCTA(SupplierOnboardingStatus status) {
    return !status.isEligibleForBookings;
  }

  /// Get CTA button text based on status
  static String getBookingCTAText(SupplierOnboardingStatus status) {
    if (status.isEligibleForBookings) {
      return 'Aceitar Reserva';
    }
    if (status.accountStatus != SupplierAccountStatus.active) {
      return 'Aguardando Aprovacao';
    }
    if (!status.isIdentityVerified) {
      return 'Verificar Identidade';
    }
    return 'Indisponivel';
  }

  /// Get tooltip for disabled CTA
  static String getDisabledCTATooltip(SupplierOnboardingStatus status) {
    if (status.isEligibleForBookings) {
      return '';
    }
    return getSupplierEligibilityMessage(status);
  }
}

/// Widget to display eligibility status badge
class EligibilityStatusBadge extends StatelessWidget {
  final SupplierOnboardingStatus status;
  final bool showLabel;
  final bool compact;

  const EligibilityStatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = EligibilityMessaging.getEligibilityColor(status);
    final icon = EligibilityMessaging.getEligibilityIcon(status);
    final label = status.isEligibleForBookings
        ? 'Elegivel'
        : EligibilityMessaging.getBookingBlockedReason(status);

    if (compact) {
      return Tooltip(
        message: EligibilityMessaging.getSupplierEligibilityMessage(status),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
    }

    return Tooltip(
      message: EligibilityMessaging.getSupplierEligibilityMessage(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget to display eligibility warning banner
class EligibilityWarningBanner extends StatelessWidget {
  final SupplierOnboardingStatus status;
  final VoidCallback? onAction;

  const EligibilityWarningBanner({
    super.key,
    required this.status,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (status.isEligibleForBookings) {
      return const SizedBox.shrink();
    }

    final color = EligibilityMessaging.getEligibilityColor(status);
    final message = EligibilityMessaging.getSupplierEligibilityMessage(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            EligibilityMessaging.getEligibilityIcon(status),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reservas Bloqueadas',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: color),
              child: const Text('Resolver'),
            ),
        ],
      ),
    );
  }
}

/// Widget for admin to see eligibility explanation
class AdminEligibilityCard extends StatelessWidget {
  final SupplierOnboardingStatus status;

  const AdminEligibilityCard({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = EligibilityMessaging.getEligibilityColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  EligibilityMessaging.getEligibilityIcon(status),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de Elegibilidade',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      EligibilityMessaging.getAdminEligibilitySummary(status),
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Status rows
          _buildStatusRow(
            'Onboarding',
            status.statusText,
            status.accountStatus == SupplierAccountStatus.active
                ? AppColors.success
                : AppColors.warning,
          ),
          const SizedBox(height: 8),
          _buildStatusRow(
            'Verificacao de Identidade',
            status.identityVerificationStatusText,
            status.isIdentityVerified ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: 8),
          _buildStatusRow(
            'Pode Receber Reservas',
            status.isEligibleForBookings ? 'Sim' : 'Nao',
            status.isEligibleForBookings ? AppColors.success : AppColors.error,
          ),

          // Note about approval vs verification
          if (!status.isEligibleForBookings) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      EligibilityMessaging.approvalVsVerificationNote,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
