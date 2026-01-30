import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/client_view_provider.dart';
import 'package:boda_connect/core/providers/cancellation_provider.dart';
import 'package:boda_connect/core/services/cancellation_service.dart';
import 'package:boda_connect/core/providers/navigation_provider.dart';
import 'package:boda_connect/core/widgets/loading_widget.dart';
import 'package:boda_connect/features/common/presentation/widgets/booking/cancel_booking_dialog.dart';
import 'package:boda_connect/features/client/presentation/widgets/client_bottom_nav.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClientBookingsScreen extends ConsumerStatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  ConsumerState<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends ConsumerState<ClientBookingsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);

    // Load client bookings from projection
    Future.microtask(() {
      ref.read(clientViewProvider.notifier).refresh();
      // Set nav index to bookings
      ref.read(clientNavIndexProvider.notifier).state = ClientNavTab.bookings.tabIndex;
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
      ref.read(clientViewProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use real-time stream for instant updates when supplier acts on bookings
    final clientViewAsync = ref.watch(clientViewStreamProvider);
    final now = DateTime.now();

    return clientViewAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
            onPressed: () => context.pop(),
          ),
          title: Text('Minhas Reservas',
              style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
          centerTitle: true,
        ),
        body: const ShimmerListLoading(itemCount: 3, itemHeight: 160),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          title: const Text('Minhas Reservas'),
        ),
        body: Center(child: Text('Erro ao carregar reservas: $e')),
      ),
      data: (clientView) {
        if (clientView == null) {
          return _buildBookingsScaffold([], []);
        }

        // Combine active and recent bookings, then filter
        final allBookings = [...clientView.activeBookings, ...clientView.recentBookings];

        // Deduplicate by bookingId
        final seenIds = <String>{};
        final uniqueBookings = allBookings.where((b) {
          if (seenIds.contains(b.bookingId)) return false;
          seenIds.add(b.bookingId);
          return true;
        }).toList();

        // Filter into upcoming and past
        final upcomingBookings = uniqueBookings
            .where((b) => b.eventDate.isAfter(now))
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

        final pastBookings = uniqueBookings
            .where((b) => b.eventDate.isBefore(now) || b.eventDate.isAtSameMomentAs(now))
            .toList()
          ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

        return _buildBookingsScaffold(upcomingBookings, pastBookings);
      },
    );
  }

  Widget _buildBookingsScaffold(List<ClientBookingSummary> upcomingBookings, List<ClientBookingSummary> pastBookings) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text('Minhas Reservas',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.peach,
          labelColor: AppColors.peach,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Próximas (${upcomingBookings.length})'),
            Tab(text: 'Passadas (${pastBookings.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(upcomingBookings, isUpcoming: true),
          _buildBookingsList(pastBookings, isUpcoming: false),
        ],
      ),
      bottomNavigationBar: const ClientBottomNav(),
    );
  }

  Widget _buildBookingsList(List<ClientBookingSummary> bookings,
      {required bool isUpcoming,}) {
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(clientViewProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 64, color: AppColors.gray300,),
                  const SizedBox(height: 16),
                  Text('Nenhuma reserva ${isUpcoming ? 'próxima' : 'passada'}',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),),
                  const SizedBox(height: 24),
                  if (isUpcoming)
                    ElevatedButton(
                      onPressed: () => context.push(Routes.clientSearch),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
                      child: const Text('Explorar Fornecedores'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(clientViewProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        itemCount: bookings.length,
        itemBuilder: (context, index) =>
            _buildBookingCard(bookings[index], isUpcoming: isUpcoming),
      ),
    );
  }

  Widget _buildBookingCard(ClientBookingSummary booking, {required bool isUpcoming}) {
    // Get event emoji based on category
    String getEventEmoji(String? category) {
      if (category == null) return '🎉';
      final cat = category.toLowerCase();
      if (cat.contains('casamento') || cat.contains('wedding')) return '💒';
      if (cat.contains('aniversário') || cat.contains('birthday')) return '🎂';
      if (cat.contains('corporativo') || cat.contains('corporate')) return '🏢';
      if (cat.contains('formatura') || cat.contains('graduation')) return '🎓';
      if (cat.contains('batizado') || cat.contains('baptism')) return '👶';
      if (cat.contains('música') || cat.contains('dj') || cat.contains('music')) return '🎵';
      if (cat.contains('foto') || cat.contains('photo')) return '📸';
      return '🎉';
    }

    final eventEmoji = getEventEmoji(booking.categoryName);

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
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.peachLight.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusLg),),
            ),
            child: Row(
              children: [
                Text(eventEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.eventName,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.bold),),
                      Text(_formatDate(booking.eventDate),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),),
                    ],
                  ),
                ),
                _buildStatusBadge(booking.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business_outlined,
                        size: 16, color: AppColors.gray400,),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.supplierName,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.category_outlined,
                        size: 16, color: AppColors.gray400,),
                    const SizedBox(width: 8),
                    Text(booking.categoryName.isNotEmpty ? booking.categoryName : 'Serviço',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),),
                  ],
                ),
                if (isUpcoming) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_formatPrice(booking.totalAmount.toInt())} ${booking.currency}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.peachDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (booking.uiFlags.canMessage)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '${Routes.chatDetail}?userId=${booking.supplierId}&userName=${Uri.encodeComponent(booking.supplierName)}',
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gray700,
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    if (booking.uiFlags.canMessage)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (isUpcoming && booking.uiFlags.canViewDetails) {
                            _showBookingDetailsModal(booking);
                          } else if (booking.uiFlags.canReview) {
                            // Navigate to supplier detail to leave review
                            context.push(Routes.clientSupplierDetail, extra: booking.supplierId);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.peach,
                          foregroundColor: AppColors.white,
                        ),
                        child: Text(booking.uiFlags.canReview ? 'Avaliar' : 'Ver Detalhes'),
                      ),
                    ),
                  ],
                ),
                // Use uiFlags.canPay for payment button
                if (booking.uiFlags.canPay) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push(
                        Routes.checkout,
                        extra: {
                          'bookingId': booking.bookingId,
                          'amount': booking.totalAmount.toInt(),
                          'description': booking.eventName,
                          'supplierName': booking.supplierName,
                        },
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                      ),
                      child: const Text('Pagar Sinal'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color;
    final String text;

    switch (status) {
      case 'pending':
        color = AppColors.warning;
        text = 'Pendente';
      case 'confirmed':
        color = AppColors.success;
        text = 'Confirmado';
      case 'inProgress':
        color = AppColors.peach;
        text = 'Em Andamento';
      case 'completed':
        color = AppColors.info;
        text = 'Concluído';
      case 'cancelled':
        color = AppColors.error;
        text = 'Cancelado';
      case 'disputed':
        color = AppColors.error;
        text = 'Em Disputa';
      case 'refunded':
        color = AppColors.gray700;
        text = 'Reembolsado';
      default:
        color = AppColors.gray400;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${price ~/ 1000}K';
    }
    return price.toString();
  }

  void _showBookingDetailsModal(ClientBookingSummary booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                  vertical: AppDimensions.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalhes da Reserva',
                        style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.gray700,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  children: [
                    // Status Badge
                    Center(child: _buildStatusBadge(booking.status)),
                    const SizedBox(height: AppDimensions.lg),

                    // Event Info Card
                    _buildDetailCard(
                      icon: Icons.event,
                      title: 'Informações do Evento',
                      children: [
                        _buildDetailRow('Nome', booking.eventName),
                        _buildDetailRow('Data', _formatDate(booking.eventDate)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),

                    // Supplier Info Card
                    _buildDetailCard(
                      icon: Icons.business,
                      title: 'Fornecedor',
                      children: [
                        _buildDetailRow('Nome', booking.supplierName),
                        _buildDetailRow('Categoria', booking.categoryName),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),

                    // Payment Info Card
                    _buildDetailCard(
                      icon: Icons.payments,
                      title: 'Informações de Pagamento',
                      children: [
                        _buildDetailRow('Valor Total', '${_formatPrice(booking.totalAmount.toInt())} ${booking.currency}'),
                        if (booking.uiFlags.showPaymentPending)
                          _buildDetailRow('Estado', 'Pagamento pendente',
                            valueColor: AppColors.warning),
                        if (booking.uiFlags.showEscrowHeld)
                          _buildDetailRow('Estado', 'Em custódia',
                            valueColor: AppColors.info),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),

                    // Booking ID
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ID da Reserva',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '#${booking.bookingId.length >= 8 ? booking.bookingId.substring(0, 8).toUpperCase() : booking.bookingId.toUpperCase()}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.peachDark,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Action Buttons - use uiFlags for visibility
                    // Cancel Button (only if cancellable)
                    if (booking.uiFlags.canCancel) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _handleCancelBooking(booking);
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: const Text('Cancelar Reserva'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],

                    // Report Problem Button (for completed bookings)
                    if (booking.uiFlags.canRequestRefund) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _handleOpenDispute(booking);
                          },
                          icon: const Icon(Icons.report_problem_outlined, size: 20),
                          label: const Text('Reportar Problema'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: const BorderSide(color: AppColors.warning),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],

                    if (booking.status == 'completed') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _handleReportUser(booking);
                          },
                          icon: const Icon(Icons.flag_outlined, size: 20),
                          label: const Text('Reportar Usuário'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gray700,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.peach),
              const SizedBox(width: AppDimensions.sm),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.gray900,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelBooking(ClientBookingSummary booking) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CancelBookingDialog(),
    );

    if (result == null || !mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário não autenticado'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final previewNotifier =
        ref.read(cancellationPreviewProvider(booking.bookingId).notifier);
    await previewNotifier.loadPreview(requestedByRole: 'client');
    final previewState = ref.read(cancellationPreviewProvider(booking.bookingId));
    final preview = previewState.preview;

    if (preview == null) {
      final error = previewState.error ?? 'Não foi possível carregar prévia do cancelamento';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final confirmed = await _showCancellationPreviewDialog(
      preview: preview,
      reason: result['reasonText'] ?? 'Cancelamento',
    );

    if (!confirmed || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.peach),
      ),
    );

    try {
      final reasonText = result['reasonText'] ?? 'Cancelamento';
      final notes = result['additionalNotes'] ?? '';
      final reason = notes.isNotEmpty ? '$reasonText - $notes' : reasonText;

      final success = await previewNotifier.processCancellation(
        cancelledBy: currentUser.uid,
        cancelledByRole: 'client',
        reason: reason,
      );

      // Reload bookings
      await ref.read(clientViewProvider.notifier).refresh();

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show success/error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Reserva cancelada com sucesso'
                  : 'Não foi possível cancelar a reserva',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar reserva: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _handleReportUser(ClientBookingSummary booking) {
    context.push(
      Routes.submitReport,
      extra: {
        'reportedId': booking.supplierId,
        'reportedType': 'supplier',
        'reportedName': booking.supplierName,
        'bookingId': booking.bookingId,
      },
    );
  }

  Future<void> _handleOpenDispute(ClientBookingSummary booking) async {
    // Show confirmation dialog for dispute
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar Problema'),
        content: const Text(
          'Deseja abrir uma disputa para esta reserva? '
          'A equipa irá analisar o seu caso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Call Cloud Function to open dispute
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateBookingStatus');
      await callable.call<Map<String, dynamic>>({
        'bookingId': booking.bookingId,
        'newStatus': 'disputed',
      });

      // Reload bookings
      await ref.read(clientViewProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disputa aberta com sucesso'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = 'Erro ao abrir disputa';
      if (e.code == 'permission-denied') {
        message = 'Não tem permissão para esta ação';
      } else if (e.code == 'failed-precondition') {
        message = e.message ?? 'Não é possível abrir disputa agora';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao abrir disputa'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<bool> _showCancellationPreviewDialog({
    required CancellationResult preview,
    required String reason,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm cancellation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason: $reason'),
            const SizedBox(height: 12),
            Text(preview.message),
            const SizedBox(height: 16),
            _buildCancellationSummaryRow(
              label: 'Refund',
              value: '${_formatCurrency(preview.refundAmount)} Kz',
            ),
            _buildCancellationSummaryRow(
              label: 'Platform fee',
              value: '${_formatCurrency(preview.platformFee)} Kz',
            ),
            _buildCancellationSummaryRow(
              label: 'Supplier payout',
              value: '${_formatCurrency(preview.supplierPayout)} Kz',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Widget _buildCancellationSummaryRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatCurrency(num value) {
    final rounded = value.round();
    return rounded.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}
