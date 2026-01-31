import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/supplier_view_provider.dart';
import '../../../../core/providers/dashboard_stats_provider.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../shared/widgets/network_indicator.dart';
import '../widgets/supplier_bottom_nav.dart';

class SupplierDashboardScreen extends ConsumerStatefulWidget {
  const SupplierDashboardScreen({super.key});

  @override
  ConsumerState<SupplierDashboardScreen> createState() => _SupplierDashboardScreenState();
}

class _SupplierDashboardScreenState extends ConsumerState<SupplierDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _hasCheckedStatus = false;

  // Animation controller for greeting entrance animation
  late final AnimationController _greetingAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize greeting animation (one-time entrance, 300ms)
    _greetingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _greetingAnimationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _greetingAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Start animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _greetingAnimationController.forward();
    });

    // Load supplier profile and bookings
    Future.microtask(() async {
      if (!mounted) return;

      // Set nav index to dashboard
      ref.read(supplierNavIndexProvider.notifier).state = SupplierNavTab.dashboard.tabIndex;

      await ref.read(supplierProvider.notifier).loadCurrentSupplier();

      if (!mounted) return;

      // Check if supplier is validated before allowing dashboard access
      final supplier = ref.read(supplierProvider).currentSupplier;
      if (!_hasCheckedStatus) {
        _hasCheckedStatus = true;

        if (supplier == null) {
          // Supplier not found - redirect to verification pending which handles this
          if (mounted) {
            context.go(Routes.supplierVerificationPending);
          }
          return;
        }

        if (supplier.accountStatus != SupplierAccountStatus.active) {
          // Redirect to verification pending screen
          if (mounted) {
            context.go(Routes.supplierVerificationPending);
          }
          return;
        }
      }

      // Load supplier view from projections
      if (supplier?.id != null && mounted) {
        await ref.read(supplierViewProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _greetingAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh projections when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      ref.read(supplierViewProvider.notifier).refresh();
    }
  }

  /// Get time-based greeting in Portuguese
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde';
    } else {
      return 'Boa noite';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        title: Image.asset(
          'assets/images/boda_logo.png',
          width: 100,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'BODA CONNECT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.peach,
              ),
            );
          },
        ),
        actions: [
          // Chat button with unread count
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            onPressed: () {
              context.push(Routes.chatList);
            },
          ),
          // Notifications bell with unread notification badge
          Builder(
            builder: (context) {
              final unreadNotifications = ref.watch(supplierUnreadNotificationsProvider);
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined, color: Colors.black),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.peach,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  context.push(Routes.notifications);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black),
            onPressed: () {
              // Show help dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Central de Ajuda'),
                  content: const Text(
                    'Precisa de ajuda?\n\n'
                    'Entre em contato conosco:\n'
                    '📧 Email: suporte@bodaconnect.com\n'
                    '📱 WhatsApp: +244 123 456 789\n\n'
                    'Horário: Segunda a Sexta, 8h-18h',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: NetworkIndicator(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(supplierProvider.notifier).loadCurrentSupplier();
            await ref.read(supplierViewProvider.notifier).refresh();
          },
          child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = AppDimensions.getHorizontalPadding(context);
            final maxWidth = AppDimensions.getMaxContentWidth(context);

            return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              100,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated Greeting with fade + slide entrance
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Builder(
                    builder: (context) {
                      // For suppliers, prefer business name over user name
                      final supplier = ref.watch(supplierProvider).currentSupplier;
                      final currentUser = ref.watch(currentUserProvider);
                      final displayName = supplier?.businessName ??
                          currentUser?.name?.split(' ').first ??
                          'Fornecedor';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getTimeBasedGreeting()}, $displayName!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Aqui está o resumo do seu negócio',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Stats Grid
              _buildStatsGrid(),

              const SizedBox(height: 28),

              // Recent Orders
              _buildRecentOrdersSection(),

              const SizedBox(height: 28),

              // Upcoming Events
              _buildUpcomingEventsSection(),

              const SizedBox(height: 28),

              // Quick Actions
              _buildSectionTitle('Ações Rápidas'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.add_box_outlined,
                      label: 'Novo Pacote',
                      onTap: () => context.push(Routes.supplierCreateService),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.edit_calendar,
                      label: 'Atualizar Agenda',
                      onTap: () => context.push(Routes.supplierAvailability),
                    ),
                  ),
                ],
              ),
            ],
          ),
              ),
            ),
          );
          },
        ),
        ),
      ),
      bottomNavigationBar: const SupplierBottomNav(),
    );
  }

  Widget _buildStatsGrid() {
    final stats = ref.watch(dashboardStatsProvider);
    // UI-FIRST: Use stream provider for real-time updates
    final supplierViewAsync = ref.watch(supplierViewStreamProvider);
    final pendingCount = ref.watch(supplierPendingCountProvider);

    return supplierViewAsync.when(
      loading: () => _buildStatsShimmer(),
      error: (e, _) => _buildStatsShimmer(), // Show shimmer on error, data still loads from cache
      data: (supplierView) {
        if (supplierView == null) {
          return _buildStatsShimmer();
        }

        return _buildStatsGridContent(stats, pendingCount);
      },
    );
  }

  Widget _buildStatsGridContent(DashboardStats stats, int pendingCount) {

    final gridColumns = AppDimensions.getStatsGridColumns(context);
    // Adjust aspect ratio based on column count
    final aspectRatio = gridColumns == 1 ? 2.5 : (gridColumns == 2 ? 1.5 : 1.4);

    return GridView.count(
      crossAxisCount: gridColumns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: [
        _buildStatCard(
          title: 'Pedidos Pendentes',
          value: '$pendingCount',
          icon: Icons.inbox,
          iconColor: pendingCount > 0 ? AppColors.warning : AppColors.info,
          hasBadge: pendingCount > 0,
        ),
        _buildStatCard(
          title: 'Receita Mês',
          value: stats.formattedRevenue,
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.success,
          suffix: ' Kz',
        ),
        _buildStatCard(
          title: 'Avaliação',
          value: stats.formattedRating,
          icon: Icons.star,
          iconColor: AppColors.warning,
          suffix: ' ★',
        ),
        _buildStatCard(
          title: 'Taxa Resposta',
          value: '${stats.responseRate}',
          icon: Icons.speed,
          iconColor: AppColors.peach,
          suffix: '%',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    String suffix = '',
    bool hasBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: AppColors.cardShadow,
        border: hasBadge
            ? Border.all(color: AppColors.warning, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: hasBadge ? AppColors.warning : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: hasBadge ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  if (hasBadge)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: hasBadge ? AppColors.warning : null,
                ),
              ),
              if (suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 2),
                  child: Text(
                    suffix,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersSection() {
    // Check if supplier is eligible for bookings
    final supplier = ref.watch(supplierProvider).currentSupplier;
    final isEligible = supplier?.isEligibleForBookings ?? false;

    // If not eligible, show restricted message
    if (!isEligible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Pedidos Recentes', action: null, onActionTap: null),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Não pode ver pedidos até a verificação de identidade ser concluída.',
                    style: TextStyle(
                      color: AppColors.gray700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Use projection provider for immediate updates
    final recentOrders = ref.watch(supplierRecentBookingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Pedidos Recentes',
          action: 'Ver todos',
          onActionTap: () => context.push(Routes.supplierOrders),
        ),
        const SizedBox(height: 12),
        if (recentOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              boxShadow: AppColors.cardShadow,
            ),
            child: const Center(
              child: Text(
                'Nenhum pedido recente',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          // Show only 5 recent orders on dashboard, "Ver todos" shows all
          ...recentOrders.take(5).map((booking) => _buildOrderCard(
            booking: booking,
            name: booking.clientName,
            event: booking.eventName,
            date: DateFormat('dd MMM yyyy').format(booking.eventDate),
            status: _getStatusText(booking.status),
            statusColor: _getStatusColor(booking.status),
          )),
      ],
    );
  }

  Widget _buildUpcomingEventsSection() {
    // Use projection provider for immediate updates
    final upcomingEvents = ref.watch(supplierUpcomingEventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Próximos Eventos',
          action: 'Agenda',
          onActionTap: () => context.push(Routes.supplierAvailability),
        ),
        const SizedBox(height: 12),
        if (upcomingEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              boxShadow: AppColors.cardShadow,
            ),
            child: const Center(
              child: Text(
                'Nenhum evento próximo',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...upcomingEvents.take(5).map((event) {
            final eventDate = event.eventDate;
            return _buildEventCard(
              bookingId: event.bookingId,
              day: DateFormat('dd').format(eventDate),
              month: DateFormat('MMM').format(eventDate),
              name: event.eventName,
              type: 'Evento',
              time: '--:--',
              price: '',
            );
          }),
      ],
    );
  }

  String _getStatusText(dynamic status) {
    final statusStr = status.toString().split('.').last;
    switch (statusStr) {
      case 'pending':
        return 'Pendente';
      case 'confirmed':
        return 'Confirmado';
      case 'inProgress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      case 'disputed':
        return 'Disputado';
      default:
        return 'Desconhecido';
    }
  }

  Color _getStatusColor(dynamic status) {
    final statusStr = status.toString().split('.').last;
    switch (statusStr) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'inProgress':
        return AppColors.peach;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'disputed':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildSectionTitle(String title, {String? action, VoidCallback? onActionTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              action,
              style: const TextStyle(
                color: AppColors.peach,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderCard({
    required SupplierBookingSummary booking,
    required String name,
    required String event,
    required String date,
    required String status,
    required Color statusColor,
  }) {
    final safeInitial = name.trim().isNotEmpty ? name.trim()[0] : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.peach.withValues(alpha: 0.15),
                    child: Text(
                      safeInitial,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.peach,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$event • $date',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    // UI-FIRST: Only allow messaging if backend permits
                    onPressed: booking.uiFlags.canMessage
                        ? () {
                            // Navigate to chat with client
                            context.push(
                              '${Routes.chatDetail}?userId=${booking.clientId}&userName=${Uri.encodeComponent(booking.clientName)}',
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.peach,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Responder',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    // UI-FIRST: Only allow navigation if backend permits
                    onPressed: booking.uiFlags.canViewDetails
                        ? () {
                            // Navigate to order detail
                            context.push('${Routes.supplierOrderDetail}?bookingId=${booking.bookingId}');
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Ver Detalhes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard({
    required String bookingId,
    required String day,
    required String month,
    required String name,
    required String type,
    required String time,
    required String price,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigate to booking detail - must always work
        context.push('${Routes.supplierOrderDetail}?bookingId=$bookingId');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.peach,
                    ),
                  ),
                  Text(
                    month,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.peach,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$type • $time',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                color: AppColors.peach,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.peach),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer loading for stats grid
  Widget _buildStatsShimmer() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: List.generate(4, (index) {
        return ShimmerLoading(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppColors.gray300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.gray300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 26,
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
