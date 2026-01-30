import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/providers/availability_provider.dart';
import '../../../../core/providers/supplier_view_provider.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../widgets/supplier_bottom_nav.dart';

class SupplierAvailabilityScreen extends ConsumerStatefulWidget {
  const SupplierAvailabilityScreen({super.key});

  @override
  ConsumerState<SupplierAvailabilityScreen> createState() =>
      _SupplierAvailabilityScreenState();
}

class _SupplierAvailabilityScreenState
    extends ConsumerState<SupplierAvailabilityScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      // Set nav index to availability
      ref.read(supplierNavIndexProvider.notifier).state = SupplierNavTab.availability.tabIndex;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI-FIRST: Use stream provider for real-time updates
    final supplierViewAsync = ref.watch(supplierViewStreamProvider);
    final blockedDatesFromView = ref.watch(supplierBlockedDatesFromViewProvider);

    // Convert projection data to UI model
    final blockedDatesForUI = _convertProjectionToUIModel(blockedDatesFromView);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text('Disponibilidade',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
        centerTitle: true,
      ),
      body: supplierViewAsync.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCalendarHeader(blockedDatesFromView),
                  _buildBlockDateButton(),
                  _buildBlockedDatesList(blockedDatesForUI),
                  _buildTipCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: const SupplierBottomNav(),
    );
  }

  /// UI-FIRST: Convert projection model to existing UI model
  /// This ensures the list shows exactly what the projection contains
  List<BlockedDate> _convertProjectionToUIModel(List<SupplierBlockedDateSummary> projectionDates) {
    return projectionDates.map((summary) {
      return BlockedDate(
        id: summary.id,
        date: summary.date,
        reason: summary.reason,
        type: _mapProjectionTypeToBlockedType(summary.type),
        bookingId: summary.bookingId,
        createdAt: DateTime.now(), // Not critical for display
      );
    }).toList();
  }

  /// Map projection type strings to UI BlockedType enum
  BlockedType _mapProjectionTypeToBlockedType(String type) {
    switch (type.toLowerCase()) {
      case 'confirmed':
      case 'reserved':
        return BlockedType.reserved;
      case 'pending':
      case 'requested':
        return BlockedType.requested;
      case 'blocked':
        return BlockedType.blocked;
      case 'unavailable':
        return BlockedType.unavailable;
      default:
        return BlockedType.blocked;
    }
  }

  Widget _buildCalendarHeader(List<SupplierBlockedDateSummary> blockedDates) {
    // UI-FIRST: Calculate counters from projection data to match the displayed list
    // Count all blocked dates (across all months) to align with the list shown below
    final requested = blockedDates.where((d) => d.type == 'requested' || d.type == 'pending').length;
    final reserved = blockedDates.where((d) => d.type == 'reserved' || d.type == 'confirmed').length;
    final blocked = blockedDates.where((d) => d.type == 'blocked' || d.type == 'unavailable').length;

    // Calculate available days in current month only (as it was before)
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
    final blockedInCurrentMonth = blockedDates.where((d) =>
      d.date.isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
      d.date.isBefore(currentMonthEnd.add(const Duration(days: 1)))
    ).length;
    final available = daysInMonth - blockedInCurrentMonth;

    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
                      'Calendário',
                      style: AppTextStyles.h2.copyWith(
                          color: AppColors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gerir calendário de disponibilidade',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.white.withValues(alpha: 0.8)),
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
                  child:
                      const Icon(Icons.calendar_month, color: AppColors.white),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(
                AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildCalendarStat('$available', 'Disponíveis', 'neste mês',
                        AppColors.white.withValues(alpha: 0.2)),
                    const SizedBox(width: AppDimensions.xs),
                    _buildCalendarStat('$requested', 'Pedidos', 'pendentes',
                        Colors.amber.withValues(alpha: 0.4)),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Row(
                  children: [
                    _buildCalendarStat('$reserved', 'Confirmados', 'pagos',
                        AppColors.success.withValues(alpha: 0.4)),
                    const SizedBox(width: AppDimensions.xs),
                    _buildCalendarStat(
                        '$blocked', 'Bloqueados', 'manuais', AppColors.error.withValues(alpha: 0.4)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStat(String value, String label, String subtitle, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.h2.copyWith(
                  color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
            ),
            Text(
              '($subtitle)',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.white.withValues(alpha: 0.7), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockDateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showBlockDateDialog,
          icon: const Icon(Icons.event_busy, color: AppColors.peach),
          label: Text('Bloquear Nova Data',
              style: AppTextStyles.button.copyWith(color: AppColors.peach)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.peach),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedDatesList(List<BlockedDate> blockedDates) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datas Bloqueadas', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.md),
          if (blockedDates.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Column(
                  children: [
                    Icon(Icons.event_available, size: 64, color: AppColors.gray300),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma data bloqueada',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...blockedDates.map((date) => _buildBlockedDateCard(date)),
        ],
      ),
    );
  }

  Widget _buildBlockedDateCard(BlockedDate blockedDate) {
    Color statusColor;
    String statusText;

    // UI-FIRST: Clear labels matching booking lifecycle vocabulary
    switch (blockedDate.type) {
      case BlockedType.reserved:
        statusColor = AppColors.success;
        statusText = 'Reserva confirmada';
        break;
      case BlockedType.blocked:
        statusColor = AppColors.error;
        statusText = 'Indisponível (manual)';
        break;
      case BlockedType.unavailable:
        statusColor = AppColors.warning;
        statusText = 'Indisponível (manual)';
        break;
      case BlockedType.requested:
        statusColor = Colors.amber;
        statusText = 'Pedido pendente';
        break;
    }

    // UI-FIRST: Make card tappable if it represents a booking
    final hasBooking = blockedDate.bookingId != null && blockedDate.bookingId!.isNotEmpty;

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: const Icon(Icons.calendar_today,
                color: AppColors.gray700, size: 20),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatDate(blockedDate.date),
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _translateReason(blockedDate.reason),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (blockedDate.type != BlockedType.reserved)
            IconButton(
              onPressed: () => _removeBlockedDate(blockedDate),
              icon: const Icon(Icons.close, color: AppColors.error, size: 20),
            ),
          // Show chevron if this is a booking
          if (hasBooking)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right, color: AppColors.gray400, size: 20),
            ),
        ],
      ),
    );

    // Wrap in InkWell if it has a booking
    if (hasBooking) {
      return InkWell(
        onTap: () {
          context.push('${Routes.supplierOrderDetail}?bookingId=${blockedDate.bookingId}');
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildTipCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: const Icon(Icons.info_outline, color: AppColors.info),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gerir Disponibilidade',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.info)),
                Text(
                  'Mantenha seu calendário atualizado para evitar duplas reservas. Datas bloqueadas não aparecem para clientes.',
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

  /// Translate English reason texts to Portuguese
  String _translateReason(String reason) {
    final translations = {
      'booked': 'Reservado',
      'blocked': 'Bloqueado',
      'unavailable': 'Indisponível',
      'reserved': 'Reservado',
      'pending': 'Pedido pendente',
      'confirmed': 'Reserva confirmada',
      'Data bloqueada': 'Data bloqueada',
      'Reserva confirmada': 'Reserva confirmada',
      'Pedido pendente': 'Pedido pendente',
    };
    return translations[reason.toLowerCase()] ?? translations[reason] ?? reason;
  }

  void _showBlockDateDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String reason = '';
    BlockedType selectedType = BlockedType.blocked;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.gray300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 24),
              Text('Bloquear Data', style: AppTextStyles.h3),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setModalState(() => selectedDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.peach),
                      const SizedBox(width: 12),
                      Text(_formatDate(selectedDate),
                          style: AppTextStyles.body),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: AppColors.gray400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => reason = value,
                decoration: InputDecoration(
                  hintText: 'Motivo (opcional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildTypeChip('Bloqueado', BlockedType.blocked, selectedType,
                      (t) => setModalState(() => selectedType = t)),
                  const SizedBox(width: 8),
                  _buildTypeChip(
                      'Indisponível',
                      BlockedType.unavailable,
                      selectedType,
                      (t) => setModalState(() => selectedType = t)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await ref.read(availabilityProvider.notifier).blockDate(
                      date: selectedDate,
                      reason: reason.isEmpty ? 'Data bloqueada' : reason,
                      type: selectedType,
                    );
                    if (success && mounted) {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data bloqueada com sucesso'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peach,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Bloquear Data'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, BlockedType type, BlockedType selected,
      Function(BlockedType) onSelect) {
    final isSelected = type == selected;
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach : AppColors.gray100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? AppColors.white : AppColors.gray700),
        ),
      ),
    );
  }

  void _removeBlockedDate(BlockedDate date) async {
    final success = await ref.read(availabilityProvider.notifier).unblockDate(date.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data desbloqueada'),
          backgroundColor: AppColors.success,
        ),
      );
    }
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
      'Dez'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

}
