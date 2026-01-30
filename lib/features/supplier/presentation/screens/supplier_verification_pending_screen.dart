import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/supplier_onboarding_service.dart';

/// Screen shown to suppliers while their account is pending review
/// Handles three states:
/// - PENDING_REVIEW: "Your application is being reviewed"
/// - NEEDS_CLARIFICATION: "Please make changes and resubmit"
/// - REJECTED: "Your application was not approved"
class SupplierVerificationPendingScreen extends ConsumerStatefulWidget {
  const SupplierVerificationPendingScreen({super.key});

  @override
  ConsumerState<SupplierVerificationPendingScreen> createState() =>
      _SupplierVerificationPendingScreenState();
}

class _SupplierVerificationPendingScreenState
    extends ConsumerState<SupplierVerificationPendingScreen> {
  final _onboardingService = SupplierOnboardingService();
  bool _isResubmitting = false;
  bool _isLoadingSupplier = false;

  @override
  void initState() {
    super.initState();
    // Load supplier if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSupplierLoaded();
    });
  }

  Future<void> _ensureSupplierLoaded() async {
    final supplierState = ref.read(supplierProvider);
    if (supplierState.currentSupplier == null && !_isLoadingSupplier) {
      setState(() => _isLoadingSupplier = true);

      // Try loading with retries in case of timing issues
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries && mounted) {
        await ref.read(supplierProvider.notifier).loadCurrentSupplier();
        final loaded = ref.read(supplierProvider).currentSupplier;

        if (loaded != null) {
          break;
        }

        retryCount++;
        if (retryCount < maxRetries) {
          Log.warn('Supplier not loaded, retry $retryCount of $maxRetries...');
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }

      if (mounted) {
        setState(() => _isLoadingSupplier = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierState = ref.watch(supplierProvider);
    final supplierId = supplierState.currentSupplier?.id;

    if (supplierId == null) {
      // Show loading with retry option if supplier isn't loading
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'A carregar perfil...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              if (!_isLoadingSupplier && !supplierState.isLoading) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _ensureSupplierLoaded,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go(Routes.welcome);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<SupplierOnboardingStatus?>(
        stream: _onboardingService.streamOnboardingStatus(supplierId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final status = snapshot.data;
          if (status == null) {
            return _buildErrorState();
          }

          // If approved, redirect to dashboard
          if (status.canAccessDashboard) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(Routes.supplierDashboard);
            });
            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = AppDimensions.getHorizontalPadding(context);
                final maxWidth = AppDimensions.getMaxContentWidth(context);

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),
                          _buildStatusIcon(status.accountStatus),
                          const SizedBox(height: 24),
                          _buildStatusTitle(status.accountStatus),
                          const SizedBox(height: 12),
                          _buildStatusDescription(status),
                          const SizedBox(height: 32),
                          if (status.rejectionReason != null &&
                              status.rejectionReason!.isNotEmpty)
                            _buildFeedbackCard(status),
                          const SizedBox(height: 24),
                          _buildInfoCards(status.accountStatus),
                          const SizedBox(height: 32),
                          _buildActions(status),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar estado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Não foi possível obter o estado da sua conta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SupplierAccountStatus status) {
    IconData icon;
    Color color;
    Color bgColor;

    switch (status) {
      case SupplierAccountStatus.pendingReview:
        icon = Icons.hourglass_top;
        color = AppColors.info;
        bgColor = AppColors.info.withValues(alpha: 0.15);
        break;
      case SupplierAccountStatus.needsClarification:
        icon = Icons.edit_note;
        color = AppColors.warning;
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        break;
      case SupplierAccountStatus.rejected:
        icon = Icons.cancel_outlined;
        color = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.15);
        break;
      case SupplierAccountStatus.suspended:
        icon = Icons.block;
        color = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.15);
        break;
      default:
        icon = Icons.hourglass_top;
        color = AppColors.info;
        bgColor = AppColors.info.withValues(alpha: 0.15);
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: color),
    );
  }

  Widget _buildStatusTitle(SupplierAccountStatus status) {
    String title;
    switch (status) {
      case SupplierAccountStatus.pendingReview:
        title = 'Em Análise';
        break;
      case SupplierAccountStatus.needsClarification:
        title = 'Alterações Necessárias';
        break;
      case SupplierAccountStatus.rejected:
        title = 'Candidatura Rejeitada';
        break;
      case SupplierAccountStatus.suspended:
        title = 'Conta Suspensa';
        break;
      default:
        title = 'Estado Desconhecido';
    }

    return Text(
      title,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusDescription(SupplierOnboardingStatus status) {
    return Text(
      status.statusDescription,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }

  Widget _buildFeedbackCard(SupplierOnboardingStatus status) {
    final isRejection = status.isRejected || status.isSuspended;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRejection
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(
          color: isRejection
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejection ? Icons.info_outline : Icons.feedback_outlined,
                size: 20,
                color: isRejection ? AppColors.error : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                isRejection ? 'Motivo da Decisão' : 'Feedback da Equipa',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isRejection ? AppColors.error : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status.rejectionReason!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          if (status.reviewedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Revisado em: ${_formatDate(status.reviewedAt!)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCards(SupplierAccountStatus status) {
    if (status == SupplierAccountStatus.pendingReview) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.border),
          color: Colors.white,
        ),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.schedule,
              iconColor: AppColors.info,
              title: 'Tempo de análise',
              description:
                  'A verificação geralmente leva até 24-48 horas úteis. Receberá uma notificação assim que houver uma actualização.',
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.notifications_active,
              iconColor: AppColors.peach,
              title: 'Notificações',
              description:
                  'Certifique-se de que as notificações estão activadas para receber actualizações sobre o estado da sua candidatura.',
            ),
          ],
        ),
      );
    }

    if (status == SupplierAccountStatus.needsClarification) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.border),
          color: Colors.white,
        ),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.edit,
              iconColor: AppColors.warning,
              title: 'Como proceder',
              description:
                  'Reveja o feedback acima, faça as alterações necessárias no seu perfil e clique em "Resubmeter" quando estiver pronto.',
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.help_outline,
              iconColor: AppColors.info,
              title: 'Precisa de ajuda?',
              description:
                  'Se tiver dúvidas sobre as alterações solicitadas, entre em contacto com o nosso suporte.',
            ),
          ],
        ),
      );
    }

    // Rejected or Suspended
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
        color: Colors.white,
      ),
      child: _InfoRow(
        icon: Icons.support_agent,
        iconColor: AppColors.info,
        title: 'Precisa de esclarecimentos?',
        description:
            'Se acredita que houve um erro ou deseja mais informações, entre em contacto com a nossa equipa de suporte.',
      ),
    );
  }

  Widget _buildActions(SupplierOnboardingStatus status) {
    switch (status.accountStatus) {
      case SupplierAccountStatus.pendingReview:
        return _buildPendingReviewActions();
      case SupplierAccountStatus.needsClarification:
        return _buildNeedsClarificationActions(status.supplierId);
      case SupplierAccountStatus.rejected:
      case SupplierAccountStatus.suspended:
        return _buildRejectedActions();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPendingReviewActions() {
    return Column(
      children: [
        // Animated waiting indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.info),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'A aguardar análise...',
                    style: TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Contact support button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => context.push(Routes.helpCenter),
            icon: const Icon(Icons.headset_mic, size: 20),
            label: const Text(
              'Contactar Suporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeedsClarificationActions(String supplierId) {
    return Column(
      children: [
        // Resubmit button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: _isResubmitting
                ? null
                : () => _handleResubmit(supplierId),
            icon: _isResubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Icon(Icons.send, size: 20),
            label: Text(
              _isResubmitting ? 'A resubmeter...' : 'Resubmeter Candidatura',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Edit profile button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => context.push(Routes.supplierProfileEdit),
            icon: const Icon(Icons.edit, size: 20),
            label: const Text(
              'Editar Perfil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedActions() {
    return Column(
      children: [
        // Contact support button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () => context.push(Routes.helpCenter),
            icon: const Icon(Icons.headset_mic, size: 20),
            label: const Text(
              'Contactar Suporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Logout button
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go(Routes.welcome);
              }
            },
            icon: const Icon(Icons.logout, size: 20),
            label: const Text(
              'Terminar Sessão',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleResubmit(String supplierId) async {
    setState(() => _isResubmitting = true);

    try {
      final success = await _onboardingService.resubmitForReview(supplierId);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Candidatura resubmetida com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao resubmeter. Tente novamente.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isResubmitting = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
