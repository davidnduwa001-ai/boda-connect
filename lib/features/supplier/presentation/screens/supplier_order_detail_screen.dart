import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/widgets/loading_widget.dart';

class SupplierOrderDetailScreen extends ConsumerStatefulWidget {
  final BookingModel? booking;
  final String? bookingId;

  const SupplierOrderDetailScreen({
    super.key,
    this.booking,
    this.bookingId,
  });

  @override
  ConsumerState<SupplierOrderDetailScreen> createState() =>
      _SupplierOrderDetailScreenState();
}

class _SupplierOrderDetailScreenState
    extends ConsumerState<SupplierOrderDetailScreen> {
  BookingModel? _booking;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (_booking == null && widget.bookingId != null) {
      _loadBooking();
    }
  }

  Future<void> _loadBooking() async {
    if (widget.bookingId == null) return;

    setState(() => _isLoading = true);

    try {
      // Use Cloud Function to get booking details securely
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getSupplierBookingDetails');
      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': widget.bookingId,
      });

      final data = result.data;
      if (data['success'] == true && data['booking'] != null) {
        final booking = BookingModel.fromCloudFunction(
          data['booking'] as Map<String, dynamic>,
        );
        if (mounted) {
          setState(() {
            _booking = booking;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Booking not found');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Erro ao carregar detalhes do pedido';
        if (e.code == 'not-found') {
          message = 'Pedido não encontrado';
        } else if (e.code == 'permission-denied') {
          message = 'Não tem permissão para ver este pedido';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar detalhes do pedido'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            'Detalhes do Pedido',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
          ),
          centerTitle: true,
        ),
        body: const ShimmerListLoading(itemCount: 4, itemHeight: 100),
      );
    }

    if (_booking == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.gray300,
              ),
              const SizedBox(height: 16),
              Text(
                'Pedido não encontrado',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }

    final booking = _booking!;
    final dateFormat = DateFormat('dd MMMM yyyy', 'pt_BR');
    final currencyFormat = NumberFormat('#,##0', 'pt_BR');

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
          'Pedido #${booking.id.length > 8 ? booking.id.substring(0, 8) : booking.id}',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
        actions: [
          if (booking.clientId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.gray900),
              onPressed: () => _openChat(booking),
              tooltip: 'Conversar com cliente',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBooking,
        color: AppColors.peach,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(booking),
              const SizedBox(height: AppDimensions.md),

              // Event Details Card
              _buildEventDetailsCard(booking, dateFormat),
              const SizedBox(height: AppDimensions.md),

              // Client Info Card
              _buildClientInfoCard(booking),
              const SizedBox(height: AppDimensions.md),

              // Package & Customizations Card
              _buildPackageCard(booking),
              const SizedBox(height: AppDimensions.md),

              // Payment Info Card
              _buildPaymentCard(booking, currencyFormat),
              const SizedBox(height: AppDimensions.md),

              // Notes Card
              if (booking.notes != null ||
                  booking.clientNotes != null ||
                  booking.supplierNotes != null)
                _buildNotesCard(booking),

              // Cancellation Info
              if (booking.status == BookingStatus.cancelled)
                _buildCancellationCard(booking),

              const SizedBox(height: AppDimensions.xl),

              // Action Buttons
              _buildActionButtons(booking),

              const SizedBox(height: AppDimensions.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BookingModel booking) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    String statusDescription;

    switch (booking.status) {
      case BookingStatus.pending:
        statusColor = AppColors.warning;
        statusText = 'Pendente';
        statusIcon = Icons.schedule;
        statusDescription = 'Aguardando sua confirmação';
        break;
      case BookingStatus.confirmed:
        statusColor = AppColors.success;
        statusText = 'Confirmado';
        statusIcon = Icons.check_circle;
        statusDescription = 'Reserva confirmada, aguardando evento';
        break;
      case BookingStatus.inProgress:
        statusColor = AppColors.info;
        statusText = 'Em Andamento';
        statusIcon = Icons.play_circle;
        statusDescription = 'Serviço em execução';
        break;
      case BookingStatus.completed:
        statusColor = AppColors.gray700;
        statusText = 'Concluído';
        statusIcon = Icons.check_circle_outline;
        statusDescription = 'Serviço finalizado com sucesso';
        break;
      case BookingStatus.cancelled:
        statusColor = AppColors.error;
        statusText = 'Cancelado';
        statusIcon = Icons.cancel_outlined;
        statusDescription = 'Reserva cancelada';
        break;
      case BookingStatus.disputed:
        statusColor = AppColors.error;
        statusText = 'Em Disputa';
        statusIcon = Icons.warning_outlined;
        statusDescription = 'Aguardando resolução da disputa';
        break;
      case BookingStatus.refunded:
        statusColor = AppColors.gray700;
        statusText = 'Reembolsado';
        statusIcon = Icons.undo;
        statusDescription = 'Pagamento foi reembolsado';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusDescription,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailsCard(BookingModel booking, DateFormat dateFormat) {
    return _buildCard(
      title: 'Detalhes do Evento',
      icon: Icons.event,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Evento', booking.eventName),
          if (booking.eventType != null)
            _buildInfoRow('Tipo', booking.eventType!),
          _buildInfoRow('Data', dateFormat.format(booking.eventDate)),
          if (booking.eventTime != null)
            _buildInfoRow('Horário', booking.eventTime!),
          if (booking.eventLocation != null)
            _buildInfoRowWithAction(
              'Local',
              booking.eventLocation!,
              Icons.map_outlined,
              () => _openMaps(booking.eventLocation!),
            ),
          if (booking.guestCount != null)
            _buildInfoRow('Convidados', '${booking.guestCount} pessoas'),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard(BookingModel booking) {
    return _buildCard(
      title: 'Informações do Cliente',
      icon: Icons.person,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Nome', booking.clientName ?? 'Cliente'),
          _buildInfoRowWithAction(
            'ID',
            booking.clientId.length > 12 ? booking.clientId.substring(0, 12) : booking.clientId,
            Icons.copy,
            () => _copyToClipboard(booking.clientId),
          ),
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openChat(booking),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Enviar mensagem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.peach,
                side: const BorderSide(color: AppColors.peach),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(BookingModel booking) {
    return _buildCard(
      title: 'Pacote & Serviços',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booking.packageName != null)
            _buildInfoRow('Pacote', booking.packageName!),
          if (booking.selectedCustomizations.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Personalizações',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: booking.selectedCustomizations.map((item) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.peach.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.peach.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    item,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.peachDark,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BookingModel booking, NumberFormat currencyFormat) {
    final remainingAmount = booking.totalPrice - booking.paidAmount;
    final isPaid = remainingAmount <= 0;

    return _buildCard(
      title: 'Pagamento',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Valor Total',
                style: AppTextStyles.body,
              ),
              Text(
                '${currencyFormat.format(booking.totalPrice)} ${booking.currency}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Valor Pago',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${currencyFormat.format(booking.paidAmount)} ${booking.currency}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Valor Pendente',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.error,
                  ),
                ),
                Text(
                  '${currencyFormat.format(remainingAmount)} ${booking.currency}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          // Payment history
          if (booking.payments.isNotEmpty) ...[
            Text(
              'Histórico de Pagamentos',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...booking.payments.map((payment) {
              final paymentDateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.method,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          paymentDateFormat.format(payment.paidAt),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${currencyFormat.format(payment.amount)} ${booking.currency}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Text(
              'Nenhum pagamento registado',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(BookingModel booking) {
    return _buildCard(
      title: 'Notas',
      icon: Icons.note_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booking.clientNotes != null) ...[
            Text(
              'Nota do Cliente',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(booking.clientNotes!, style: AppTextStyles.body),
            const SizedBox(height: 12),
          ],
          if (booking.notes != null) ...[
            Text(
              'Notas do Pedido',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(booking.notes!, style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }

  Widget _buildCancellationCard(BookingModel booking) {
    final cancelDateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Informações do Cancelamento',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (booking.cancelledAt != null)
            _buildInfoRow(
              'Data',
              cancelDateFormat.format(booking.cancelledAt!),
            ),
          if (booking.cancellationReason != null)
            _buildInfoRow('Motivo', booking.cancellationReason!),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BookingModel booking) {
    // UI-FIRST: Use uiFlags from backend if available, fallback to local logic
    final canAccept = booking.uiFlags?.canAccept ?? (booking.paidAmount > 0);
    final canDecline = booking.uiFlags?.canDecline ?? booking.canCancel;
    final isPaid = booking.paidAmount > 0;

    switch (booking.status) {
      case BookingStatus.pending:
        return Column(
          children: [
            // Show payment status warning if not paid
            if (!isPaid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aguardando pagamento do cliente',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton.icon(
                // UI-FIRST: Use backend uiFlags
                onPressed: canAccept ? () => _confirmBooking() : null,
                icon: const Icon(Icons.check),
                label: Text(canAccept ? 'Aceitar Pedido' : 'Aguardando Pagamento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAccept ? AppColors.success : AppColors.gray300,
                  foregroundColor: canAccept ? AppColors.white : AppColors.gray400,
                  disabledBackgroundColor: AppColors.gray200,
                  disabledForegroundColor: AppColors.gray400,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton.icon(
                // UI-FIRST: Use backend uiFlags
                onPressed: canDecline ? () => _showRejectDialog() : null,
                icon: const Icon(Icons.close),
                label: const Text('Recusar Pedido'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        );

      case BookingStatus.confirmed:
        final canCancel = booking.uiFlags?.canCancel ?? booking.canCancel;
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: () => _startBooking(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Serviço'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton.icon(
                // UI-FIRST: Use backend uiFlags
                onPressed: canCancel ? () => _showCancelDialog() : null,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar Reserva'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        );

      case BookingStatus.inProgress:
        return SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () => _completeBooking(),
            icon: const Icon(Icons.check_circle),
            label: const Text('Marcar como Concluído'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
            ),
          ),
        );

      case BookingStatus.completed:
        return SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => _openChat(booking),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Enviar Mensagem'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.peach,
              side: const BorderSide(color: AppColors.peach),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.peach, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithAction(
    String label,
    String value,
    IconData actionIcon,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body,
            ),
          ),
          IconButton(
            icon: Icon(actionIcon, size: 18, color: AppColors.peach),
            onPressed: onAction,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // Action Methods - Using Cloud Functions
  Future<void> _confirmBooking() async {
    if (_booking == null) return;

    // Check if client has paid - supplier cannot accept unpaid bookings
    if (_booking!.paidAmount <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pagamento Pendente'),
          content: const Text(
            'Não pode aceitar este pedido porque o cliente ainda não efetuou o pagamento. '
            'Aguarde o pagamento do cliente antes de aceitar o pedido.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('respondToBooking');
      await callable.call<Map<String, dynamic>>({
        'bookingId': _booking!.id,
        'action': 'confirm',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido confirmado com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadBooking();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
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

  Future<void> _startBooking() async {
    if (_booking == null) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateBookingStatus');
      await callable.call<Map<String, dynamic>>({
        'bookingId': _booking!.id,
        'newStatus': 'inProgress',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço iniciado!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadBooking();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = 'Erro ao iniciar serviço';
      if (e.code == 'permission-denied') {
        message = 'Não tem permissão para esta ação';
      } else if (e.code == 'failed-precondition') {
        message = e.message ?? 'Não é possível iniciar o serviço agora';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao iniciar serviço'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeBooking() async {
    if (_booking == null) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateBookingStatus');
      await callable.call<Map<String, dynamic>>({
        'bookingId': _booking!.id,
        'newStatus': 'completed',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço concluído com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadBooking();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = 'Erro ao concluir serviço';
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
          content: Text('Erro ao concluir serviço'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _rejectBooking(reasonController.text);
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

  void _showCancelDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar Reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tem certeza que deseja cancelar esta reserva?',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Informe o motivo do cancelamento',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _cancelBooking(reasonController.text);
            },
            child: Text(
              'Cancelar Reserva',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectBooking(String reason) async {
    if (_booking == null) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('respondToBooking');
      await callable.call<Map<String, dynamic>>({
        'bookingId': _booking!.id,
        'action': 'reject',
        'reason': reason.isNotEmpty ? reason : 'Recusado pelo fornecedor',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido recusado'),
          backgroundColor: AppColors.warning,
        ),
      );
      context.pop();
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

  Future<void> _cancelBooking(String reason) async {
    if (_booking == null) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateBookingStatus');
      await callable.call<Map<String, dynamic>>({
        'bookingId': _booking!.id,
        'newStatus': 'cancelled',
        'reason': reason.isNotEmpty ? reason : 'Cancelado pelo fornecedor',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada'),
          backgroundColor: AppColors.error,
        ),
      );
      context.pop();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = 'Erro ao cancelar reserva';
      if (e.code == 'permission-denied') {
        message = 'Não tem permissão para cancelar esta reserva';
      } else if (e.code == 'failed-precondition') {
        message = e.message ?? 'Não é possível cancelar esta reserva';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao cancelar reserva'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openChat(BookingModel booking) {
    context.push(
      '${Routes.chatDetail}?userId=${booking.clientId}&userName=${Uri.encodeComponent(booking.clientName ?? 'Cliente')}',
    );
  }

  Future<void> _openMaps(String location) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado para área de transferência'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
