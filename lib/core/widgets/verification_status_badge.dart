import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/supplier_model.dart';

/// A badge widget to display identity verification status on supplier cards/listings
///
/// Shows different visual cues based on verification status:
/// - verified: Green check badge
/// - pending: Yellow hourglass badge
/// - rejected: Red warning badge
///
/// Can be used in compact (icon only) or full (icon + label) mode.
class VerificationStatusBadge extends StatelessWidget {
  final IdentityVerificationStatus status;
  final bool compact;
  final bool showTooltip;

  const VerificationStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();
    final label = _getLabel();
    final tooltip = _getTooltip();

    final badge = Container(
      padding: compact
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 6 : 12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );

    if (showTooltip) {
      return Tooltip(
        message: tooltip,
        child: badge,
      );
    }

    return badge;
  }

  Color _getColor() {
    switch (status) {
      case IdentityVerificationStatus.verified:
        return AppColors.success;
      case IdentityVerificationStatus.pending:
        return AppColors.warning;
      case IdentityVerificationStatus.rejected:
        return AppColors.error;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case IdentityVerificationStatus.verified:
        return Icons.verified_user;
      case IdentityVerificationStatus.pending:
        return Icons.hourglass_top;
      case IdentityVerificationStatus.rejected:
        return Icons.gpp_bad;
    }
  }

  String _getLabel() {
    switch (status) {
      case IdentityVerificationStatus.verified:
        return 'Verificado';
      case IdentityVerificationStatus.pending:
        return 'Pendente';
      case IdentityVerificationStatus.rejected:
        return 'Rejeitado';
    }
  }

  String _getTooltip() {
    switch (status) {
      case IdentityVerificationStatus.verified:
        return 'Identidade verificada';
      case IdentityVerificationStatus.pending:
        return 'Verificacao de identidade pendente';
      case IdentityVerificationStatus.rejected:
        return 'Verificacao de identidade rejeitada';
    }
  }
}

/// A combined badge showing both onboarding and identity verification status
/// Used to give a complete picture of a supplier's booking eligibility
class SupplierEligibilityBadge extends StatelessWidget {
  final SupplierAccountStatus accountStatus;
  final IdentityVerificationStatus identityVerificationStatus;
  final bool compact;

  const SupplierEligibilityBadge({
    super.key,
    required this.accountStatus,
    required this.identityVerificationStatus,
    this.compact = false,
  });

  bool get isEligible =>
      accountStatus == SupplierAccountStatus.active &&
      identityVerificationStatus == IdentityVerificationStatus.verified;

  @override
  Widget build(BuildContext context) {
    if (isEligible) {
      return _buildEligibleBadge();
    }

    return _buildNotEligibleBadge();
  }

  Widget _buildEligibleBadge() {
    return Container(
      padding: compact
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 6 : 12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: compact ? 12 : 14,
            color: AppColors.success,
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            const Text(
              'Aceita Reservas',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotEligibleBadge() {
    final reason = _getBlockingReason();
    final color = _getBlockingColor();

    return Tooltip(
      message: reason,
      child: Container(
        padding: compact
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 6 : 12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top,
              size: compact ? 12 : 14,
              color: color,
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                'Verificacao Pendente',
                style: TextStyle(
                  fontSize: 10,
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

  String _getBlockingReason() {
    if (accountStatus != SupplierAccountStatus.active) {
      return 'Aprovacao de cadastro pendente';
    }
    if (identityVerificationStatus != IdentityVerificationStatus.verified) {
      return 'Verificacao de identidade pendente';
    }
    return 'Reservas indisponiveis';
  }

  Color _getBlockingColor() {
    if (accountStatus == SupplierAccountStatus.rejected ||
        identityVerificationStatus == IdentityVerificationStatus.rejected) {
      return AppColors.error;
    }
    return AppColors.warning;
  }
}
