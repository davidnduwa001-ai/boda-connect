import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/providers/supplier_availability_provider.dart';
import '../../../../core/providers/availability_provider.dart';

// Note: supplierBlockedDatesProvider is imported from availability_provider.dart

class AvailabilityCalendarWidget extends ConsumerStatefulWidget {
  final String supplierId;
  final Function(DateTime) onDateSelected;
  final DateTime? initialSelectedDate;

  const AvailabilityCalendarWidget({
    super.key,
    required this.supplierId,
    required this.onDateSelected,
    this.initialSelectedDate,
  });

  @override
  ConsumerState<AvailabilityCalendarWidget> createState() =>
      _AvailabilityCalendarWidgetState();
}

class _AvailabilityCalendarWidgetState
    extends ConsumerState<AvailabilityCalendarWidget> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialSelectedDate ?? DateTime.now();
    _selectedDay = widget.initialSelectedDate;
  }

  /// Check if a date is in the blocked dates list
  bool _isDateBlocked(DateTime day, List<DateTime> blockedDates) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return blockedDates.any((blocked) {
      final normalizedBlocked = DateTime(blocked.year, blocked.month, blocked.day);
      return normalizedDay.isAtSameMomentAs(normalizedBlocked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final availabilityParams = SupplierAvailabilityParams(
      supplierId: widget.supplierId,
      year: _focusedDay.year,
      month: _focusedDay.month,
    );

    final availabilityAsync = ref.watch(
      supplierAvailabilityProvider(availabilityParams),
    );

    // Watch blocked dates from supplier
    final blockedDatesAsync = ref.watch(
      supplierBlockedDatesProvider(widget.supplierId),
    );
    final blockedDates = blockedDatesAsync.valueOrNull ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(
                  color: AppColors.success,
                  label: 'Disponível',
                ),
                _buildLegendItem(
                  color: AppColors.warning,
                  label: 'Parcial',
                ),
                _buildLegendItem(
                  color: AppColors.error,
                  label: 'Esgotado',
                ),
                _buildLegendItem(
                  color: AppColors.gray400,
                  label: 'Indisponível',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Calendar
          availabilityAsync.when(
            data: (availabilityCollection) => TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: AppTextStyles.h4.copyWith(
                  color: AppColors.gray900,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.peach,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.peach,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: AppTextStyles.body.copyWith(
                  color: AppColors.error,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.peach,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (selectedDay.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
                  return; // Don't allow selecting past dates
                }

                // Check if date is blocked by supplier
                if (_isDateBlocked(selectedDay, blockedDates)) {
                  _showBlockedDateMessage(selectedDay);
                  return;
                }

                final availability = availabilityCollection.getAvailability(selectedDay);
                if (availability?.isFullyBooked ?? false) {
                  _showFullyBookedMessage(selectedDay);
                  return;
                }

                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                widget.onDateSelected(selectedDay);
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return _buildDayCell(
                    day,
                    availabilityCollection,
                    blockedDates,
                    isSelected: isSameDay(day, _selectedDay),
                    isToday: isSameDay(day, DateTime.now()),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return _buildDayCell(
                    day,
                    availabilityCollection,
                    blockedDates,
                    isSelected: isSameDay(day, _selectedDay),
                    isToday: true,
                  );
                },
                selectedBuilder: (context, day, focusedDay) {
                  return _buildDayCell(
                    day,
                    availabilityCollection,
                    blockedDates,
                    isSelected: true,
                    isToday: isSameDay(day, DateTime.now()),
                  );
                },
              ),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.xl),
                child: CircularProgressIndicator(color: AppColors.peach),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Text(
                'Erro ao carregar disponibilidade',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    dynamic availabilityCollection,
    List<DateTime> blockedDates,
    {required bool isSelected,
    required bool isToday}
  ) {
    final isPast = day.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final isBlocked = _isDateBlocked(day, blockedDates);

    Color? backgroundColor;
    Color? textColor;

    if (isPast) {
      backgroundColor = AppColors.gray100;
      textColor = AppColors.gray400;
    } else if (isBlocked) {
      // Blocked by supplier - show as unavailable with distinct styling
      backgroundColor = AppColors.gray300;
      textColor = AppColors.gray700;
    } else if (isSelected) {
      backgroundColor = AppColors.peach;
      textColor = AppColors.white;
    } else {
      final availability = availabilityCollection.getAvailability(day);

      if (availability != null) {
        if (availability.isFullyBooked) {
          backgroundColor = AppColors.error.withValues(alpha: 0.1);
          textColor = AppColors.error;
        } else if (availability.isPartiallyBooked) {
          backgroundColor = AppColors.warning.withValues(alpha: 0.1);
          textColor = AppColors.warning;
        } else {
          backgroundColor = AppColors.success.withValues(alpha: 0.1);
          textColor = AppColors.success;
        }
      } else {
        // No data = assume available
        backgroundColor = AppColors.success.withValues(alpha: 0.05);
        textColor = isToday ? AppColors.peach : AppColors.gray900;
      }
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: isToday && !isSelected && !isBlocked
            ? Border.all(color: AppColors.peach, width: 2)
            : isBlocked
                ? Border.all(color: AppColors.gray400, width: 1)
                : null,
      ),
      child: Center(
        child: isBlocked
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: AppTextStyles.body.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  // Strikethrough line to indicate blocked
                  Positioned(
                    child: Container(
                      width: 20,
                      height: 1.5,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              )
            : Text(
                '${day.day}',
                style: AppTextStyles.body.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.gray700),
        ),
      ],
    );
  }

  void _showFullyBookedMessage(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Esta data está completamente reservada. Por favor, escolha outra data.',
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showBlockedDateMessage(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Esta data está indisponível. O fornecedor bloqueou esta data.',
        ),
        backgroundColor: AppColors.gray700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
