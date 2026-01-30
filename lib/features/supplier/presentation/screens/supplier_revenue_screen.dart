import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/booking_provider.dart';
import 'package:boda_connect/core/providers/navigation_provider.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/models/booking_model.dart';
import '../widgets/supplier_bottom_nav.dart';

class SupplierRevenueScreen extends ConsumerStatefulWidget {
  const SupplierRevenueScreen({super.key});

  @override
  ConsumerState<SupplierRevenueScreen> createState() => _SupplierRevenueScreenState();
}

class _SupplierRevenueScreenState extends ConsumerState<SupplierRevenueScreen> {
  int _selectedPeriod = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Set nav index to revenue
      ref.read(supplierNavIndexProvider.notifier).state = SupplierNavTab.revenue.tabIndex;

      final supplierId = ref.read(supplierProvider).currentSupplier?.id;
      if (supplierId != null) {
        ref.read(bookingProvider.notifier).loadSupplierBookings(supplierId);
      }
    });
  }

  List<BookingModel> _getFilteredBookings(List<BookingModel> bookings) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 0: // Este Mês
        return bookings.where((b) =>
          b.eventDate.year == now.year && b.eventDate.month == now.month
        ).toList();
      case 1: // Trimestre
        final currentQuarter = ((now.month - 1) ~/ 3);
        final quarterStartMonth = currentQuarter * 3 + 1;
        final quarterEndMonth = quarterStartMonth + 2;
        return bookings.where((b) =>
          b.eventDate.year == now.year &&
          b.eventDate.month >= quarterStartMonth &&
          b.eventDate.month <= quarterEndMonth
        ).toList();
      case 2: // Ano
        return bookings.where((b) => b.eventDate.year == now.year).toList();
      default:
        return bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final allBookings = bookingState.supplierBookings;
    final bookings = _getFilteredBookings(allBookings);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text('Receita & Ganhos', style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
        centerTitle: true,
      ),
      body: bookingState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : RefreshIndicator(
              onRefresh: () async {
                final supplierId = ref.read(supplierProvider).currentSupplier?.id;
                if (supplierId != null) {
                  await ref.read(bookingProvider.notifier).loadSupplierBookings(supplierId);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRevenueHeader(bookings),
                    _buildPeriodSelector(),
                    _buildExportButton(),
                    _buildTransactionsList(bookings),
                    _buildStatsCards(bookings),
                    _buildAutoPaymentInfo(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const SupplierBottomNav(),
    );
  }

  Widget _buildRevenueHeader(List<BookingModel> bookings) {
    // Use the already filtered bookings from the selected period
    final paidTotal = bookings
        .where((b) => b.status == BookingStatus.completed)
        .fold<int>(0, (sum, b) => sum + b.paidAmount);

    final pendingTotal = bookings
        .where((b) => b.status == BookingStatus.confirmed)
        .fold<int>(0, (sum, b) => sum + b.totalPrice);

    final paidCount = bookings
        .where((b) => b.status == BookingStatus.completed)
        .length;

    final periodTitle = _getPeriodTitle();

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.peach, AppColors.peachDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receita Total ($periodTitle)',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatPrice(paidTotal)} Kz',
                      style: AppTextStyles.h1.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up, color: AppColors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$paidCount eventos concluídos',
                            style: AppTextStyles.caption.copyWith(color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: const Icon(Icons.attach_money, color: AppColors.white, size: 28),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transações', style: AppTextStyles.caption.copyWith(color: AppColors.white.withValues(alpha: 0.8))),
                        Text('$paidCount', style: AppTextStyles.h3.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pendente', style: AppTextStyles.caption.copyWith(color: AppColors.white.withValues(alpha: 0.8))),
                        Text('${_formatPrice(pendingTotal)}', style: AppTextStyles.h3.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Este Mês', 'Trimestre', 'Ano'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.peach : AppColors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: isSelected ? AppColors.peach : AppColors.border),
                ),
                child: Center(
                  child: Text(
                    periods[index],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected ? AppColors.white : AppColors.gray700,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _exportReport,
          icon: const Icon(Icons.download_outlined, color: AppColors.gray700),
          label: Text('Exportar Relatório', style: AppTextStyles.button.copyWith(color: AppColors.gray700)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<BookingModel> bookings) {
    // Get recent completed bookings
    final recentBookings = bookings
        .where((b) => b.status == BookingStatus.completed || b.status == BookingStatus.confirmed)
        .toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    final displayBookings = recentBookings.take(10).toList();

    if (displayBookings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.gray300),
              const SizedBox(height: 16),
              Text('Nenhuma transação ainda', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transações Recentes', style: AppTextStyles.h3),
              Text('${displayBookings.length} total', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ...displayBookings.map((booking) => _buildTransactionCard(booking)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.eventName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                Text(booking.packageName ?? 'Pacote', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    Text(_formatDate(booking.eventDate), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatPrice(booking.paidAmount > 0 ? booking.paidAmount : booking.totalPrice)} Kz',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: booking.status == BookingStatus.completed ? AppColors.peachDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: booking.status == BookingStatus.completed ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.status == BookingStatus.completed ? 'Pago' : 'Pendente',
                  style: AppTextStyles.caption.copyWith(
                    color: booking.status == BookingStatus.completed ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(List<BookingModel> bookings) {
    final completedBookings = bookings.where((b) => b.status == BookingStatus.completed).toList();
    final avgPerEvent = completedBookings.isNotEmpty
        ? completedBookings.fold<int>(0, (sum, b) => sum + b.paidAmount) ~/ completedBookings.length
        : 0;

    final pendingTotal = bookings
        .where((b) => b.status == BookingStatus.confirmed)
        .fold<int>(0, (sum, b) => sum + b.totalPrice);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.trending_up, color: AppColors.success, size: 24),
                  const SizedBox(height: 8),
                  Text('Média/Evento', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  Text('${_formatPrice(avgPerEvent)} Kz', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.info, size: 24),
                  const SizedBox(height: 8),
                  Text('Próximos', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  Text('${_formatPrice(pendingTotal)} Kz', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoPaymentInfo() {
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
            child: const Icon(Icons.account_balance_wallet, color: AppColors.warning),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pagamento Automático', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'Os pagamentos são transferidos automaticamente para sua conta bancária registada dentro de 2-3 dias úteis após confirmação.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodTitle() {
    final now = DateTime.now();
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

    switch (_selectedPeriod) {
      case 0: // Este Mês
        return '${months[now.month - 1]} ${now.year}';
      case 1: // Trimestre
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        return 'Q$currentQuarter ${now.year}';
      case 2: // Ano
        return '${now.year}';
      default:
        return '${months[now.month - 1]} ${now.year}';
    }
  }

  Future<void> _exportReport() async {
    final bookingState = ref.read(bookingProvider);
    final allBookings = bookingState.supplierBookings;
    final bookings = _getFilteredBookings(allBookings);

    if (bookings.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma transação para exportar'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Generate CSV content
    final csv = _generateCSV(bookings);

    // Share the CSV content
    await Share.share(
      csv,
      subject: 'Relatório de Receitas - ${_getPeriodTitle()}',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Relatório exportado com sucesso'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  String _generateCSV(List<BookingModel> bookings) {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('Data,Evento,Pacote,Status,Valor Pago,Valor Total');

    // Data rows
    for (final booking in bookings) {
      final date = _formatDate(booking.eventDate);
      final event = booking.eventName.replaceAll(',', ';');
      final package = (booking.packageName ?? 'Pacote').replaceAll(',', ';');
      final status = booking.status == BookingStatus.completed ? 'Pago' :
                     booking.status == BookingStatus.confirmed ? 'Pendente' :
                     'Cancelado';
      final paid = booking.paidAmount;
      final total = booking.totalPrice;

      buffer.writeln('$date,$event,$package,$status,$paid Kz,$total Kz');
    }

    // Summary
    final totalPaid = bookings
        .where((b) => b.status == BookingStatus.completed)
        .fold<int>(0, (sum, b) => sum + b.paidAmount);
    final totalPending = bookings
        .where((b) => b.status == BookingStatus.confirmed)
        .fold<int>(0, (sum, b) => sum + b.totalPrice);

    buffer.writeln('');
    buffer.writeln('RESUMO');
    buffer.writeln('Total Pago,$totalPaid Kz');
    buffer.writeln('Total Pendente,$totalPending Kz');
    buffer.writeln('Total de Transações,${bookings.length}');
    buffer.writeln('Período,${_getPeriodTitle()}');

    return buffer.toString();
  }

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${price ~/ 1000}K';
    }
    return price.toString();
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}
