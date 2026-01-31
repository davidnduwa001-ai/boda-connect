import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/providers/booking_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ClientHistoryScreen extends ConsumerWidget {
  const ClientHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(clientBookingsProvider);

    // Filter only completed, cancelled, and rejected bookings (history)
    final historyBookings = bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled ||
            b.status == BookingStatus.rejected)
        .toList();

    // Sort by most recent first
    historyBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
          'Histórico',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientBookingsProvider);
        },
        child: historyBookings.isEmpty
            ? _buildEmptyState(context)
            : ListView.separated(
                padding: const EdgeInsets.all(AppDimensions.md),
                itemCount: historyBookings.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppDimensions.md),
                itemBuilder: (context, index) {
                  final booking = historyBookings[index];
                  return _buildHistoryCard(context, booking);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history,
                    size: 60,
                    color: AppColors.gray400,
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                Text(
                  'Sem Histórico',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.gray900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'Você ainda não possui reservas concluídas ou canceladas.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, BookingModel booking) {
    final isCompleted = booking.status == BookingStatus.completed;
    final statusColor = isCompleted ? AppColors.success : AppColors.gray400;
    final statusText = isCompleted ? 'Concluído' : 'Cancelado';
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm');

    return InkWell(
      onTap: () {
        // Navigate to client bookings screen for now
        // In future, could add a booking details route
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.radiusMd),
                  topRight: Radius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.cancel,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    statusText,
                    style: AppTextStyles.body.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateFormat.format(booking.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.eventName,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900,
                    ),
                  ),
                  if (booking.packageName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      booking.packageName!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.peach,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(booking.eventDate),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (booking.eventTime != null) ...[
                        const SizedBox(width: AppDimensions.md),
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.eventTime!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (booking.eventLocation != null) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.eventLocation!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.notes,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              booking.notes!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.gray700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Price and action
                  const SizedBox(height: AppDimensions.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${booking.totalPrice.toStringAsFixed(2)} Kz',
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.peach,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // Navigate to bookings screen for now
                          context.push(Routes.clientBookings);
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Ver Detalhes'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.peach,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
