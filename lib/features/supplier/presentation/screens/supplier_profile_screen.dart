import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/services/seed_database_service.dart';
import '../../../../core/services/cleanup_database_service.dart';
import '../../../../core/widgets/tier_badge.dart';
import '../../../chat/presentation/providers/chat_provider.dart' as chat;
import '../widgets/supplier_bottom_nav.dart';
import '../widgets/profile_completeness_card.dart';

class SupplierProfileScreen extends ConsumerStatefulWidget {
  const SupplierProfileScreen({super.key});

  @override
  ConsumerState<SupplierProfileScreen> createState() =>
      _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends ConsumerState<SupplierProfileScreen> {
  bool _isSeeding = false;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Set nav index to profile
      ref.read(supplierNavIndexProvider.notifier).state = SupplierNavTab.profile.tabIndex;

      ref.read(supplierProvider.notifier).loadCurrentSupplier();
      final supplierId = ref.read(supplierProvider).currentSupplier?.id;
      if (supplierId != null) {
        ref.read(bookingProvider.notifier).loadSupplierBookings(supplierId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final supplierState = ref.watch(supplierProvider);
    final supplier = supplierState.currentSupplier;
    final packages = supplierState.packages;
    final bookings = ref.watch(supplierBookingsProvider);
    final unreadCount = ref.watch(chat.totalUnreadCountProvider);

    if (supplierState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.peach)),
      );
    }

    if (supplier == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil do Fornecedor'),
        ),
        body: const Center(
          child: Text('Perfil não encontrado'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text('Perfil do Fornecedor',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(supplier),
            const SizedBox(height: AppDimensions.sm),
            ProfileCompletenessCard(
              supplier: supplier,
              packageCount: packages.length,
              onTap: () => context.push(Routes.supplierProfileEdit),
            ),
            const SizedBox(height: AppDimensions.sm),
            TierProgressCard(supplier: supplier),
            const SizedBox(height: AppDimensions.sm),
            _buildPerformanceCard(supplier, packages.length, bookings),
            _buildMenuSection('CONTA', [
              MenuItem(
                  icon: Icons.person_outline,
                  iconColor: AppColors.gray700,
                  title: 'Editar Perfil',
                  subtitle: 'Informações e contactos',
                  onTap: () => context.push(Routes.supplierProfileEdit)),
              MenuItem(
                  icon: Icons.chat_bubble_outline,
                  iconColor: AppColors.peach,
                  title: 'Mensagens',
                  subtitle: 'Conversar com clientes',
                  badge: unreadCount > 0 ? '$unreadCount' : null,
                  badgeColor: AppColors.peach,
                  onTap: () => context.push(Routes.chatList)),
              MenuItem(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.gray700,
                  title: 'Notificações',
                  subtitle: 'Pedidos e mensagens',
                  onTap: () => context.push(Routes.notifications)),
              MenuItem(
                  icon: Icons.settings_outlined,
                  iconColor: AppColors.gray700,
                  title: 'Preferências',
                  subtitle: 'Idioma e aparência',
                  onTap: () => context.push(Routes.supplierSettings)),
            ]),
            _buildAcceptingBookingsCard(supplier),
            _buildMenuSection('NEGÓCIO', [
              MenuItem(
                  icon: Icons.visibility_outlined,
                  iconColor: AppColors.info,
                  title: 'Perfil Público',
                  subtitle: 'Ver como clientes veem',
                  onTap: () => context.push(Routes.supplierPublicProfile)),
              MenuItem(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.peach,
                  title: 'Gerir Pacotes',
                  subtitle: '${packages.length} pacote${packages.length != 1 ? 's' : ''}',
                  badge: packages.length.toString(),
                  badgeColor: AppColors.peach,
                  onTap: () => context.push(Routes.supplierPackages)),
              MenuItem(
                  icon: Icons.calendar_month_outlined,
                  iconColor: AppColors.peach,
                  title: 'Agenda & Disponibilidade',
                  subtitle: 'Eventos confirmados',
                  onTap: () => context.push(Routes.supplierAvailability)),
              MenuItem(
                  icon: Icons.trending_up_outlined,
                  iconColor: AppColors.success,
                  title: 'Receitas & Relatórios',
                  subtitle: 'Financeiro e analytics',
                  onTap: () => context.push(Routes.supplierRevenue)),
              MenuItem(
                  icon: Icons.payment_outlined,
                  iconColor: AppColors.peach,
                  title: 'Métodos de Pagamento',
                  subtitle: 'Gerir formas de recebimento',
                  onTap: () => context.push(Routes.supplierPaymentMethods)),
              MenuItem(
                  icon: Icons.star_outline,
                  iconColor: AppColors.warning,
                  title: 'Avaliações',
                  subtitle: '${supplier.reviewCount} avaliação${supplier.reviewCount != 1 ? 'ões' : ''}',
                  badge: supplier.rating.toStringAsFixed(1),
                  badgeColor: AppColors.warning,
                  onTap: () => context.push(Routes.supplierReviews)),
            ]),
            _buildMenuSection('SUPORTE', [
              MenuItem(
                  icon: Icons.help_outline,
                  iconColor: AppColors.gray700,
                  title: 'Central de Ajuda',
                  subtitle: 'FAQ e tutoriais',
                  onTap: () => context.push(Routes.helpCenter)),
              MenuItem(
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.gray700,
                  title: 'Segurança & Privacidade',
                  subtitle: 'Proteção de dados',
                  onTap: () => context.push(Routes.securityPrivacy)),
              MenuItem(
                  icon: Icons.verified_user_outlined,
                  iconColor: AppColors.success,
                  title: 'Pontuação de Segurança',
                  subtitle: 'Métricas e conquistas',
                  onTap: () => context.push(Routes.safetyHistory, extra: supplier.id)),
              MenuItem(
                  icon: Icons.description_outlined,
                  iconColor: AppColors.gray700,
                  title: 'Termos para Fornecedores',
                  subtitle: 'Políticas da plataforma',
                  onTap: () => context.push(Routes.terms)),
            ]),
            _buildVersionInfo(),
            _buildCleanupButton(context),
            const SizedBox(height: AppDimensions.sm),
            _buildSeedButton(context),
            const SizedBox(height: AppDimensions.md),
            _buildLogoutButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const SupplierBottomNav(),
    );
  }

  Widget _buildProfileHeader(supplier) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [AppColors.peach, AppColors.peachDark]),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: supplier.photos.isNotEmpty
                ? ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    child: Image.network(
                      supplier.photos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.business,
                              color: AppColors.white, size: 32),
                    ),
                  )
                : const Icon(Icons.business, color: AppColors.white, size: 32),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(supplier.businessName,
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.white),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    if (supplier.tier != SupplierTier.starter) ...[
                      TierBadge(tier: supplier.tier, size: 12),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppColors.warning, size: 12),
                          const SizedBox(width: 2),
                          Text(supplier.rating.toStringAsFixed(1),
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (supplier.category.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 14, color: AppColors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text(supplier.category,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                if (supplier.phone != null)
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 14, color: AppColors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text(supplier.phone!,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                if (supplier.email != null)
                  Row(
                    children: [
                      Icon(Icons.email_outlined,
                          size: 14, color: AppColors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(supplier.email!,
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.8)),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                if (supplier.location?.city != null)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('${supplier.location!.city}, ${supplier.location!.province ?? "Angola"}',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.white.withValues(alpha: 0.8))),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(Routes.supplierProfileEdit),
            icon: const Icon(Icons.edit, color: AppColors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(supplier, int packageCount, List<BookingModel> bookings) {
    // Calculate current month statistics
    final now = DateTime.now();

    // Bookings with events this month (for revenue calculation)
    final currentMonthEventBookings = bookings.where((b) =>
      b.eventDate.year == now.year && b.eventDate.month == now.month
    ).toList();

    // Bookings CREATED this month (for "Novos Pedidos" count)
    final currentMonthNewBookings = bookings.where((b) =>
      b.createdAt.year == now.year && b.createdAt.month == now.month
    ).toList();

    // Calculate total events (all time)
    final totalEvents = bookings.where((b) => b.status == BookingStatus.completed).length;

    // Calculate chat conversations (unique clients)
    final uniqueClients = bookings.map((b) => b.clientId).toSet().length;

    // Calculate current month revenue (from events this month)
    final monthRevenue = currentMonthEventBookings
        .where((b) => b.status == BookingStatus.completed)
        .fold<int>(0, (sum, b) => sum + b.paidAmount);

    // Calculate new orders this month (bookings created this month)
    final monthOrders = currentMonthNewBookings.length;

    // Calculate acceptance rate (confirmed vs total)
    final confirmedOrPaid = bookings.where((b) =>
      b.status == BookingStatus.confirmed || b.status == BookingStatus.completed
    ).length;
    final acceptanceRate = bookings.isNotEmpty
        ? (confirmedOrPaid / bookings.length * 100).round()
        : 0;

    // Calculate growth percentage (compare with last month)
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthBookings = bookings.where((b) =>
      b.eventDate.year == lastMonth.year && b.eventDate.month == lastMonth.month
    ).toList();
    final lastMonthRevenue = lastMonthBookings
        .where((b) => b.status == BookingStatus.completed)
        .fold<int>(0, (sum, b) => sum + b.paidAmount);

    final growthPercentage = lastMonthRevenue > 0
        ? ((monthRevenue - lastMonthRevenue) / lastMonthRevenue * 100).round()
        : (monthRevenue > 0 ? 100 : 0);

    // Format month name
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
                    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    final monthName = months[now.month - 1];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatBox(Icons.event, '$totalEvents', 'Eventos'),
              const SizedBox(width: AppDimensions.sm),
              _buildStatBox(Icons.inventory_2, '$packageCount', 'Pacotes'),
              const SizedBox(width: AppDimensions.sm),
              _buildStatBox(Icons.chat_bubble_outline, '$uniqueClients', 'Conversas'),
              const SizedBox(width: AppDimensions.sm),
              _buildStatBox(Icons.trending_up,
                  '${(supplier.responseRate * 100).toInt()}%', 'Resposta'),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Performance Este Mês',
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: growthPercentage >= 0 ? AppColors.successLight : AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            growthPercentage >= 0 ? Icons.trending_up : Icons.trending_down,
                            size: 12,
                            color: growthPercentage >= 0 ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${growthPercentage >= 0 ? '+' : ''}$growthPercentage%',
                            style: AppTextStyles.caption.copyWith(
                              color: growthPercentage >= 0 ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text('$monthName ${now.year}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppDimensions.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Receita Total',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                          Text('${_formatPrice(monthRevenue)} Kz',
                              style: AppTextStyles.h3.copyWith(
                                  color: AppColors.peachDark,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Novos Pedidos',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                          Text('$monthOrders',
                              style: AppTextStyles.h3
                                  .copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Taxa Aceitação',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                          Text('$acceptanceRate%',
                              style: AppTextStyles.h3.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avaliações',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: AppColors.warning, size: 18),
                              const SizedBox(width: 4),
                              Text(supplier.rating.toStringAsFixed(1),
                                  style: AppTextStyles.h3
                                      .copyWith(fontWeight: FontWeight.bold)),
                              Text(' (${supplier.reviewCount})',
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gray400, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.bold)),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptingBookingsCard(SupplierModel supplier) {
    final isAccepting = supplier.acceptingBookings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.lg, AppDimensions.md, 0),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: isAccepting ? AppColors.successLight : AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isAccepting ? AppColors.success : AppColors.warning,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isAccepting
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(
                isAccepting ? Icons.event_available : Icons.event_busy,
                color: isAccepting ? AppColors.success : AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aceitar Reservas',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isAccepting
                        ? 'Você está aceitando novas reservas'
                        : 'Reservas pausadas temporariamente',
                    style: AppTextStyles.caption.copyWith(
                      color: isAccepting ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isAccepting,
              onChanged: (value) => _showToggleBookingsDialog(value),
              activeColor: AppColors.success,
              inactiveThumbColor: AppColors.warning,
              inactiveTrackColor: AppColors.warning.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showToggleBookingsDialog(bool newValue) {
    final title = newValue ? 'Activar Reservas?' : 'Pausar Reservas?';
    final message = newValue
        ? 'Você voltará a aparecer nos resultados de busca e clientes poderão fazer reservas.'
        : 'Você não aparecerá nos resultados de busca e clientes não poderão fazer novas reservas. Reservas existentes não serão afectadas.';
    final actionText = newValue ? 'Activar' : 'Pausar';
    final actionColor = newValue ? AppColors.success : AppColors.warning;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(supplierProvider.notifier)
                  .toggleAcceptingBookings(newValue);

              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newValue
                          ? '✅ Reservas activadas com sucesso!'
                          : '⏸️ Reservas pausadas temporariamente',
                    ),
                    backgroundColor: actionColor,
                  ),
                );
              }
            },
            child: Text(
              actionText,
              style: TextStyle(color: actionColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<MenuItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.lg, AppDimensions.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimensions.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    _buildMenuItem(item),
                    if (index < items.length - 1)
                      const Divider(height: 1, indent: 56),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.body),
                  Text(item.subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (item.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (item.badgeColor ?? AppColors.peach).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (item.badgeColor == AppColors.warning)
                      const Icon(Icons.star,
                          size: 12, color: AppColors.warning),
                    Text(
                      item.badge!,
                      style: AppTextStyles.caption.copyWith(
                        color: item.badgeColor ?? AppColors.peach,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
      child: Center(
        child: Text(
          'BODA CONNECT Fornecedor v1.0.0',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showLogoutDialog(context),
          icon: const Icon(Icons.logout, color: AppColors.error),
          label: Text('Terminar Sessão',
              style: AppTextStyles.button.copyWith(color: AppColors.error)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSeedButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isSeeding ? null : () => _showSeedDialog(context),
          icon: _isSeeding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline, color: AppColors.peach),
          label: Text(
            _isSeeding ? 'Populando Dados...' : 'Popular Base de Dados (Dev)',
            style: AppTextStyles.button.copyWith(color: AppColors.peach),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.peach),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  void _showSeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Popular Base de Dados?'),
        content: const Text(
          'Isto irá criar dados de teste:\n\n'
          '• 6 Categorias\n'
          '• 5 Fornecedores\n'
          '• 15-20 Pacotes\n'
          '• 20-25 Avaliações\n'
          '• 3 Reservas\n'
          '• 1 Conversa com mensagens\n\n'
          'Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _seedDatabase();
            },
            child: const Text(
              'Popular',
              style: TextStyle(color: AppColors.peach, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seedDatabase() async {
    setState(() {
      _isSeeding = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null || currentUser.uid.isEmpty) {
        throw Exception('Usuário não encontrado');
      }

      // Find any existing client user in the database to use for testing
      // You need at least one client account created before seeding
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'client')
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        throw Exception(
          'Nenhum cliente encontrado. Crie uma conta de cliente primeiro antes de popular o banco de dados.',
        );
      }

      final clientId = usersSnapshot.docs.first.id;

      final seedService = SeedDatabaseService();
      await seedService.seedDatabase(
        existingClientId: clientId,
        existingSupplierId: currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Base de dados populada com sucesso!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao popular: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }

  Widget _buildCleanupButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isCleaning ? null : () => _showCleanupDialog(context),
          icon: _isCleaning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep, color: AppColors.error),
          label: Text(
            _isCleaning ? 'Limpando...' : 'Limpar Base de Dados (Dev)',
            style: AppTextStyles.button.copyWith(color: AppColors.error),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  void _showCleanupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Base de Dados?'),
        content: const Text(
          'Isto irá DELETAR todos os dados de teste:\n\n'
          '• Fornecedores\n'
          '• Pacotes\n'
          '• Avaliações\n'
          '• Reservas\n'
          '• Conversas e mensagens\n'
          '• Favoritos\n\n'
          '⚠️ Categorias e usuários serão PRESERVADOS.\n\n'
          'Esta ação não pode ser desfeita!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cleanupDatabase();
            },
            child: const Text(
              'Limpar',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupDatabase() async {
    setState(() {
      _isCleaning = true;
    });

    try {
      final cleanupService = CleanupDatabaseService();
      await cleanupService.cleanupTestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Base de dados limpa com sucesso!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao limpar: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCleaning = false;
        });
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar Sessão?'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(Routes.welcome);
            },
            child: Text('Sair', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toString();
  }
}

class MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });
}
