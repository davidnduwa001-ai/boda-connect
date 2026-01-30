import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/providers/supplier_view_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SupplierOrdersScreen extends ConsumerStatefulWidget {
  const SupplierOrdersScreen({super.key});

  @override
  ConsumerState<SupplierOrdersScreen> createState() => _SupplierOrdersScreenState();
}

class _SupplierOrdersScreenState extends ConsumerState<SupplierOrdersScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);

    // Load supplier view from projections
    Future.microtask(() {
      ref.read(supplierViewProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Check if supplier is eligible for bookings
    final supplier = ref.watch(supplierProvider).currentSupplier;
    final isEligible = supplier?.isEligibleForBookings ?? false;

    // If not eligible, show restricted screen
    if (!isEligible) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
            onPressed: () => context.pop(),
          ),
          title: Text('Pedidos', style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: AppColors.warning),
                const SizedBox(height: 24),
                Text(
                  'Acesso Restrito',
                  style: AppTextStyles.h2.copyWith(color: AppColors.gray900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Não pode ver pedidos até a verificação de identidade ser concluída.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peach,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final viewState = ref.watch(supplierViewProvider);

    // Use projection providers for filtered bookings
    final pendingBookings = ref.watch(supplierPendingBookingsProvider);
    final confirmedBookings = ref.watch(supplierConfirmedBookingsProvider);

    // History bookings: filter from all bookings in view
    final allBookings = viewState.view?.recentBookings ?? [];
    final historyBookings = allBookings
        .where((b) => b.status == 'completed' || b.status == 'cancelled' || b.status == 'disputed')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pedidos',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.peach,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.peach,
          labelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pendentes'),
                  if (pendingBookings.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingBookings.length}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Confirmados'),
                  if (confirmedBookings.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${confirmedBookings.length}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: viewState.isLoading
          ? const ShimmerListLoading(itemCount: 4, itemHeight: 180)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingsList(pendingBookings, 'pending'),
                _buildBookingsList(confirmedBookings, 'confirmed'),
                _buildBookingsList(historyBookings, 'completed'),
              ],
            ),
    );
  }

  Widget _buildBookingsList(List<SupplierBookingSummary> bookings, String statusType) {
    if (bookings.isEmpty) {
      String emptyMessage;
      IconData emptyIcon;

      switch (statusType) {
        case 'pending':
          emptyMessage = 'Nenhum pedido pendente';
          emptyIcon = Icons.inbox_outlined;
          break;
        case 'confirmed':
          emptyMessage = 'Nenhum evento confirmado';
          emptyIcon = Icons.event_available_outlined;
          break;
        default:
          emptyMessage = 'Nenhum histórico';
          emptyIcon = Icons.history_outlined;
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: AppColors.gray300),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(supplierViewProvider.notifier).refresh();
      },
      color: AppColors.peach,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(bookings[index]);
        },
      ),
    );
  }

  Widget _buildBookingCard(SupplierBookingSummary booking) {
    final dateFormat = DateFormat('dd MMM yyyy', 'pt_BR');

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (booking.status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Pendente';
        statusIcon = Icons.schedule;
        break;
      case 'confirmed':
        statusColor = AppColors.success;
        statusText = 'Confirmado';
        statusIcon = Icons.check_circle;
        break;
      case 'inProgress':
        statusColor = AppColors.info;
        statusText = 'Em Andamento';
        statusIcon = Icons.play_circle;
        break;
      case 'completed':
        statusColor = AppColors.gray700;
        statusText = 'Concluído';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusText = 'Cancelado';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'disputed':
        statusColor = AppColors.error;
        statusText = 'Em Disputa';
        statusIcon = Icons.warning_outlined;
        break;
      case 'refunded':
        statusColor = AppColors.gray700;
        statusText = 'Reembolsado';
        statusIcon = Icons.undo;
        break;
      default:
        statusColor = AppColors.gray400;
        statusText = 'Desconhecido';
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        // UI-FIRST: Only allow navigation if backend permits
        onTap: booking.uiFlags.canViewDetails
            ? () => context.push(Routes.supplierOrderDetail, extra: booking)
            : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'ID: #${booking.bookingId.substring(0, 8)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),

              // Event Name & Client
              Text(
                booking.eventName,
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                booking.clientName,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimensions.sm),

              // Event Date
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: AppColors.gray400),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(booking.eventDate),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),

              // Location
              if (booking.eventLocation != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        booking.eventLocation!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppDimensions.md),
              const Divider(height: 1),
              const SizedBox(height: AppDimensions.sm),

              // Price and Actions - use uiFlags for button visibility
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor Total',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        '${_formatPrice(booking.totalAmount.toInt())} ${booking.currency}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.peachDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Use uiFlags to control button visibility
                  if (booking.uiFlags.canAccept || booking.uiFlags.canDecline)
                    Row(
                      children: [
                        if (booking.uiFlags.canDecline)
                          OutlinedButton(
                            onPressed: () => _showRejectDialog(booking),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Recusar'),
                          ),
                        if (booking.uiFlags.canDecline && booking.uiFlags.canAccept)
                          const SizedBox(width: 8),
                        if (booking.uiFlags.canAccept)
                          ElevatedButton(
                            onPressed: () => _confirmBooking(booking),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              'Aceitar',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
                            ),
                          ),
                      ],
                    )
                  else
                    TextButton(
                      // UI-FIRST: Only allow navigation if backend permits
                      onPressed: booking.uiFlags.canViewDetails
                          ? () => context.push('${Routes.supplierOrderDetail}?bookingId=${booking.bookingId}')
                          : null,
                      child: const Text('Ver Detalhes'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    final formatter = NumberFormat('#,##0', 'pt_BR');
    return formatter.format(price);
  }

  Future<void> _confirmBooking(SupplierBookingSummary booking) async {
    try {
      // Call Cloud Function to confirm booking
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('respondToBooking');
      await callable.call<Map<String, dynamic>>({
        'bookingId': booking.bookingId,
        'action': 'confirm',
      });

      // Refresh supplier view
      await ref.read(supplierViewProvider.notifier).refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido confirmado com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      // Map error to human-friendly message
      String message = 'Erro ao confirmar pedido';
      if (e.code == 'failed-precondition') {
        message = e.message ?? 'Pagamento necessário antes de confirmar';
      } else if (e.code == 'permission-denied') {
        message = 'Não tem permissão para esta ação';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao confirmar pedido'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showRejectDialog(SupplierBookingSummary booking) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recusar Pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tem certeza que deseja recusar este pedido?',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Informe o motivo da recusa',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rejectBooking(booking, reasonController.text);
            },
            child: Text(
              'Recusar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectBooking(SupplierBookingSummary booking, String reason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada, faça login novamente'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // Call Cloud Function to reject booking
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('respondToBooking');
      await callable.call<Map<String, dynamic>>({
        'bookingId': booking.bookingId,
        'action': 'reject',
        'reason': reason.isNotEmpty ? reason : 'Rejeitado pelo fornecedor',
      });

      // Refresh supplier view
      await ref.read(supplierViewProvider.notifier).refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido recusado'),
          backgroundColor: AppColors.warning,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = 'Erro ao recusar pedido';
      if (e.code == 'permission-denied') {
        message = 'Não tem permissão para esta ação';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao recusar pedido'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
