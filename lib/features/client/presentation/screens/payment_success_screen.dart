import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/providers/booking_provider.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String paymentMethod;
  final int totalAmount;

  const PaymentSuccessScreen({
    super.key,
    required this.bookingId,
    required this.paymentMethod,
    required this.totalAmount,
  });

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('PaymentSuccessScreen: Loading booking with ID: ${widget.bookingId}');
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: bookingAsync.when(
          data: (booking) {
            debugPrint('PaymentSuccessScreen: Booking loaded: ${booking?.id}');
            return _buildSuccessContent(context, booking);
          },
          loading: () {
            debugPrint('PaymentSuccessScreen: Loading...');
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            debugPrint('PaymentSuccessScreen: ERROR loading booking: $error');
            debugPrint('PaymentSuccessScreen: Stack trace: $stackTrace');
            return _buildErrorContent(context);
          },
        ),
      ),
    );
  }

  Widget _buildSuccessContent(BuildContext context, BookingModel? booking) {
    if (booking == null) {
      return _buildErrorContent(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Success Icon with animation
          ScaleTransition(
            scale: _animationController,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Success Message
          Text(
            'Reserva Confirmada!',
            style: AppTextStyles.h1.copyWith(color: AppColors.gray900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Sua reserva foi criada com sucesso',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xl),

          // Booking Details Card
          _buildBookingDetailsCard(booking),
          const SizedBox(height: AppDimensions.md),

          // Payment Info Card
          _buildPaymentInfoCard(),
          const SizedBox(height: AppDimensions.md),

          // Next Steps Card
          _buildNextStepsCard(),
          const SizedBox(height: AppDimensions.xl),

          // Action Buttons
          _buildActionButtons(context, booking),
        ],
      ),
    );
  }

  Widget _buildBookingDetailsCard(BookingModel booking) {
    return Container(
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
              const Icon(Icons.confirmation_number, color: AppColors.peach),
              const SizedBox(width: AppDimensions.sm),
              Text('Detalhes da Reserva', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          const Divider(),
          const SizedBox(height: AppDimensions.md),

          _buildInfoRow(Icons.event, 'Evento', booking.eventName),
          const SizedBox(height: AppDimensions.sm),
          _buildInfoRow(Icons.calendar_today, 'Data', _formatDate(booking.eventDate)),
          const SizedBox(height: AppDimensions.sm),
          _buildInfoRow(Icons.access_time, 'Hora', booking.eventTime ?? 'A definir'),
          const SizedBox(height: AppDimensions.sm),
          _buildInfoRow(Icons.location_on, 'Local', booking.eventLocation ?? 'A definir'),
          const SizedBox(height: AppDimensions.sm),
          _buildInfoRow(Icons.people, 'Convidados', '${booking.guestCount ?? 0} pessoas'),

          const SizedBox(height: AppDimensions.md),
          const Divider(),
          const SizedBox(height: AppDimensions.md),

          // Booking ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID da Reserva',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                '#${booking.id.substring(0, 8).toUpperCase()}',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.peachDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    final paymentMethodName = _getPaymentMethodName(widget.paymentMethod);

    return Container(
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
              const Icon(Icons.payment, color: AppColors.peach),
              const SizedBox(width: AppDimensions.sm),
              Text('Informações de Pagamento', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          const Divider(),
          const SizedBox(height: AppDimensions.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Método de Pagamento',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                paymentMethodName,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Valor Total',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                _formatPrice(widget.totalAmount),
                style: AppTextStyles.h3.copyWith(color: AppColors.peachDark),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  'Aguardando Pagamento',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.peachLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.peachDark),
              const SizedBox(width: AppDimensions.sm),
              Text(
                'Próximos Passos',
                style: AppTextStyles.h4.copyWith(color: AppColors.peachDark),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          _buildNextStepItem(
            '1',
            'Aguardar Confirmação',
            'O fornecedor irá revisar e confirmar sua reserva',
          ),
          const SizedBox(height: AppDimensions.sm),
          _buildNextStepItem(
            '2',
            'Efetuar Pagamento',
            'Siga as instruções de pagamento enviadas por mensagem',
          ),
          const SizedBox(height: AppDimensions.sm),
          _buildNextStepItem(
            '3',
            'Acompanhar Reserva',
            'Acompanhe o status da sua reserva na aba "Reservas"',
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.peach,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, BookingModel booking) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              context.go('/bookings');
            },
            icon: const Icon(Icons.calendar_today),
            label: const Text('Ver Minhas Reservas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              context.go('/home');
            },
            icon: const Icon(Icons.home),
            label: const Text('Voltar ao Início'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.peach,
              side: const BorderSide(color: AppColors.peach),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.gray700),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                value,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'Erro ao Carregar Reserva',
              style: AppTextStyles.h2.copyWith(color: AppColors.gray900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Não foi possível carregar os detalhes da reserva.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.xl),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.peach,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'bank_transfer':
        return 'Transferência Bancária';
      case 'cash':
        return 'Dinheiro';
      case 'mobile_money':
        return 'Pagamento Móvel';
      default:
        return method;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatPrice(int price) {
    final formatted = price
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted Kz';
  }
}
