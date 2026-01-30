import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/providers/blocked_dates_provider.dart';

/// Calendar widget for suppliers to manage their blocked dates
class BlockedDatesCalendar extends ConsumerStatefulWidget {
  final String supplierId;
  final bool isEditable;

  const BlockedDatesCalendar({
    super.key,
    required this.supplierId,
    this.isEditable = true,
  });

  @override
  ConsumerState<BlockedDatesCalendar> createState() => _BlockedDatesCalendarState();
}

class _BlockedDatesCalendarState extends ConsumerState<BlockedDatesCalendar> {
  late DateTime _currentMonth;
  DateTime? _rangeStart;
  bool _isSelectingRange = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final blockedDatesState = ref.watch(blockedDatesNotifierProvider(widget.supplierId));
    final notifier = ref.read(blockedDatesNotifierProvider(widget.supplierId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with month navigation
        _buildHeader(),
        const SizedBox(height: AppDimensions.md),

        // Weekday labels
        _buildWeekdayLabels(),
        const SizedBox(height: AppDimensions.sm),

        // Calendar grid
        if (blockedDatesState.isLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.peach))
        else
          _buildCalendarGrid(blockedDatesState.blockedDates, notifier),

        const SizedBox(height: AppDimensions.md),

        // Legend
        _buildLegend(),

        if (widget.isEditable) ...[
          const SizedBox(height: AppDimensions.md),
          // Range selection toggle
          _buildRangeToggle(),
          const SizedBox(height: AppDimensions.sm),
          // Clear all button
          _buildClearButton(notifier),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
            });
          },
          icon: const Icon(Icons.chevron_left),
          color: AppColors.gray700,
        ),
        Text(
          '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
          style: AppTextStyles.h4.copyWith(color: AppColors.gray900),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
            });
          },
          icon: const Icon(Icons.chevron_right),
          color: AppColors.gray700,
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    const weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) => SizedBox(
        width: 40,
        child: Text(
          day,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid(List<DateTime> blockedDates, BlockedDatesNotifier notifier) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Convert to 0-6 (Sun-Sat)
    final daysInMonth = lastDayOfMonth.day;

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    final rows = <Widget>[];
    var currentDay = 1 - firstWeekday;

    while (currentDay <= daysInMonth) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        if (currentDay < 1 || currentDay > daysInMonth) {
          cells.add(const SizedBox(width: 40, height: 40));
        } else {
          final date = DateTime(_currentMonth.year, _currentMonth.month, currentDay);
          final isBlocked = blockedDates.any((d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
          );
          final isPast = date.isBefore(todayNormalized);
          final isToday = date.isAtSameMomentAs(todayNormalized);
          final isRangeStart = _rangeStart != null &&
              _rangeStart!.year == date.year &&
              _rangeStart!.month == date.month &&
              _rangeStart!.day == date.day;

          cells.add(_buildDayCell(
            day: currentDay,
            date: date,
            isBlocked: isBlocked,
            isPast: isPast,
            isToday: isToday,
            isRangeStart: isRangeStart,
            onTap: widget.isEditable && !isPast
                ? () => _onDayTapped(date, notifier)
                : null,
          ));
        }
        currentDay++;
      }
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: cells,
      ));
      rows.add(const SizedBox(height: 4));
    }

    return Column(children: rows);
  }

  Widget _buildDayCell({
    required int day,
    required DateTime date,
    required bool isBlocked,
    required bool isPast,
    required bool isToday,
    required bool isRangeStart,
    VoidCallback? onTap,
  }) {
    Color backgroundColor;
    Color textColor;
    BoxBorder? border;

    if (isBlocked) {
      backgroundColor = AppColors.error.withValues(alpha: 0.2);
      textColor = AppColors.error;
    } else if (isPast) {
      backgroundColor = Colors.transparent;
      textColor = AppColors.gray300;
    } else {
      backgroundColor = Colors.transparent;
      textColor = AppColors.gray700;
    }

    if (isToday) {
      border = Border.all(color: AppColors.peach, width: 2);
    }

    if (isRangeStart) {
      border = Border.all(color: AppColors.info, width: 2);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: textColor,
              fontWeight: isBlocked || isToday ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _onDayTapped(DateTime date, BlockedDatesNotifier notifier) {
    if (_isSelectingRange) {
      if (_rangeStart == null) {
        setState(() {
          _rangeStart = date;
        });
      } else {
        // Complete range selection
        final startDate = _rangeStart!.isBefore(date) ? _rangeStart! : date;
        final endDate = _rangeStart!.isBefore(date) ? date : _rangeStart!;

        notifier.addDateRange(startDate, endDate);

        setState(() {
          _rangeStart = null;
          _isSelectingRange = false;
        });
      }
    } else {
      notifier.toggleDate(date);
    }
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          color: AppColors.error.withValues(alpha: 0.2),
          label: 'Bloqueado',
        ),
        const SizedBox(width: AppDimensions.lg),
        _buildLegendItem(
          color: Colors.transparent,
          borderColor: AppColors.peach,
          label: 'Hoje',
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    Color? borderColor,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRangeToggle() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: _isSelectingRange ? AppColors.info.withValues(alpha: 0.1) : AppColors.gray50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _isSelectingRange ? AppColors.info : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 20,
            color: _isSelectingRange ? AppColors.info : AppColors.gray700,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              _isSelectingRange
                  ? _rangeStart != null
                      ? 'Selecione a data final'
                      : 'Selecione a data inicial'
                  : 'Bloquear período',
              style: AppTextStyles.bodySmall.copyWith(
                color: _isSelectingRange ? AppColors.info : AppColors.gray700,
              ),
            ),
          ),
          Switch(
            value: _isSelectingRange,
            onChanged: (value) {
              setState(() {
                _isSelectingRange = value;
                _rangeStart = null;
              });
            },
            activeColor: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton(BlockedDatesNotifier notifier) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showClearConfirmation(notifier),
        icon: const Icon(Icons.clear_all, size: 18),
        label: const Text('Limpar todas as datas bloqueadas'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  void _showClearConfirmation(BlockedDatesNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar datas bloqueadas?'),
        content: const Text(
          'Isto irá remover todas as datas bloqueadas. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.clearAllDates();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }
}
