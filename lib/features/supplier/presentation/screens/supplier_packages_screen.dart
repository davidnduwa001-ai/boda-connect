import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/models/package_model.dart';
import '../../../../core/models/booking_model.dart';
import '../widgets/supplier_bottom_nav.dart';

class SupplierPackagesScreen extends ConsumerStatefulWidget {
  const SupplierPackagesScreen({super.key});

  @override
  ConsumerState<SupplierPackagesScreen> createState() => _SupplierPackagesScreenState();
}

class _SupplierPackagesScreenState extends ConsumerState<SupplierPackagesScreen> {
  @override
  void initState() {
    super.initState();
    // Load supplier packages
    Future.microtask(() {
      ref.read(supplierProvider.notifier).loadCurrentSupplier();
      // Set nav index to packages
      ref.read(supplierNavIndexProvider.notifier).state = SupplierNavTab.packages.tabIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final supplierState = ref.watch(supplierProvider);
    final packages = supplierState.packages;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text('Meus Pacotes',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
        centerTitle: true,
      ),
      body: supplierState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(supplierProvider.notifier).loadCurrentSupplier();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildStatsSection(packages),
                    _buildCreateButton(),
                    _buildPackagesList(packages),
                    _buildTipCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const SupplierBottomNav(),
    );
  }

  Widget _buildStatsSection(List<PackageModel> packages) {
    final total = packages.length;
    final active = packages.where((p) => p.isActive).length;

    // Calculate reservations from bookings (exclude cancelled and rejected)
    final bookings = ref.watch(supplierBookingsProvider);
    final reservations = bookings
        .where((b) => b.status != BookingStatus.cancelled && b.status != BookingStatus.rejected)
        .length;

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          _buildStatCard('$total', 'Total', AppColors.gray700),
          const SizedBox(width: AppDimensions.sm),
          _buildStatCard('$active', 'Ativos', AppColors.success),
          const SizedBox(width: AppDimensions.sm),
          _buildStatCard('$reservations', 'Reservas', AppColors.peach),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.h2
                  .copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.push(Routes.supplierCreateService),
          icon: const Icon(Icons.add, color: AppColors.white),
          label: Text('Criar Novo Pacote',
              style: AppTextStyles.button.copyWith(color: AppColors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.peach,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesList(List<PackageModel> packages) {
    if (packages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.gray300),
              const SizedBox(height: 16),
              Text(
                'Nenhum pacote criado ainda',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        children: packages.map((package) => _buildPackageCard(package)).toList(),
      ),
    );
  }

  Widget _buildPackageCard(PackageModel package) {
    // Calculate reservations for this specific package (exclude cancelled and rejected)
    final bookings = ref.watch(supplierBookingsProvider);
    final packageReservations = bookings
        .where((b) => b.packageId == package.id &&
                      b.status != BookingStatus.cancelled &&
                      b.status != BookingStatus.rejected)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        package.name,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: package.isActive
                            ? AppColors.successLight
                            : AppColors.gray200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        package.isActive ? 'Ativo' : 'Inativo',
                        style: AppTextStyles.caption.copyWith(
                          color: package.isActive
                              ? AppColors.success
                              : AppColors.gray700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  package.description,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    Text(package.duration, style: AppTextStyles.caption),
                    const SizedBox(width: AppDimensions.md),
                    Icon(Icons.event_available,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '$packageReservations reserva${packageReservations != 1 ? 's' : ''}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: AppColors.peachLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Text('Valor do pacote',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(
                        '${_formatPrice(package.price)} Kz',
                        style: AppTextStyles.h3.copyWith(
                            color: AppColors.peachDark,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Text('Inclui:',
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimensions.xs),
                ...package.includes.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.peach,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(item,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _togglePackageStatus(package),
                    icon: Icon(
                      package.isActive
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.gray700,
                    ),
                    label: Text(
                      package.isActive ? 'Ocultar' : 'Ativar',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.gray700),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _editPackage(package),
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.info),
                    label: Text('Editar',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.info)),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showDeleteDialog(package),
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    label: Text('Excluir',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child:
                const Icon(Icons.lightbulb_outline, color: AppColors.warning),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dica Profissional',
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'Crie pelo menos 3 pacotes com diferentes faixas de preço. Isso aumenta suas chances de conversão em até 40%.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePackageStatus(PackageModel package) async {
    final success = await ref.read(supplierProvider.notifier).togglePackageStatus(
          package.id,
          !package.isActive,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            package.isActive ? 'Pacote ocultado' : 'Pacote ativado',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao atualizar pacote'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _editPackage(PackageModel package) {
    // Navigate to create service screen with package data for editing
    context.push(Routes.supplierCreateService, extra: package);
  }

  void _showDeleteDialog(PackageModel package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Pacote?'),
        content: Text(
            'Tem certeza que deseja excluir "${package.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(supplierProvider.notifier)
                  .deletePackage(package.id);

              if (!mounted) return;

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pacote excluído com sucesso'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Erro ao excluir pacote'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${price ~/ 1000}K';
    }
    return price.toString();
  }
}
