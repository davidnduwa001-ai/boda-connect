import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/cart_model.dart';
import 'package:intl/intl.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with supplier and delete button
              Row(
                children: [
                  const Icon(
                    Icons.store,
                    size: 16,
                    color: AppColors.peach,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.supplierName,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.peach,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                    iconSize: 20,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.sm),

              // Package name
              Text(
                item.packageName,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900,
                ),
              ),

              const SizedBox(height: AppDimensions.sm),

              // Date and guests
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.gray400),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(item.selectedDate),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  const Icon(Icons.people, size: 14, color: AppColors.gray400),
                  const SizedBox(width: 4),
                  Text(
                    '${item.guestCount} pessoas',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Customizations (if any)
              if (item.selectedCustomizations.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: item.selectedCustomizations.map((custom) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.peachLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Text(
                        custom,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.peachDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: AppDimensions.md),

              // Price breakdown
              Container(
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pacote base',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _formatPrice(item.basePrice),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                    if (item.customizationsPrice > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Personalizações',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _formatPrice(item.customizationsPrice),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.gray700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray900,
                          ),
                        ),
                        Text(
                          _formatPrice(item.totalPrice),
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.peachDark,
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'pt').format(date);
  }

  String _formatPrice(int price) {
    final formatted = price
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted Kz';
  }
}
