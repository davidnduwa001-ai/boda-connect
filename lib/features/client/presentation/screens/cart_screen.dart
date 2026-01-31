import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/cart_model.dart';
import '../../../../core/providers/cart_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../widgets/cart_item_card.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Carrinho'),
        actions: [
          cartAsync.when(
            data: (cart) => cart.isNotEmpty
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'clear') {
                        _showClearCartDialog(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep, size: 20, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Limpar carrinho'),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(cartProvider);
              },
              child: _buildEmptyCart(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(cartProvider);
            },
            child: Column(
              children: [
                // Summary card at top
                Container(
                  margin: const EdgeInsets.all(AppDimensions.md),
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.peachLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(
                      color: AppColors.peach.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cart.itemCount} ${cart.itemCount == 1 ? 'pacote' : 'pacotes'}',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.gray900,
                            ),
                          ),
                          if (cart.uniqueSuppliers > 1)
                            Text(
                              'de ${cart.uniqueSuppliers} fornecedores',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _formatPrice(cart.totalPrice),
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.peachDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Cart items list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return CartItemCard(
                        item: item,
                        onRemove: () => _showRemoveItemDialog(context, ref, item.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.peach),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'Erro ao carregar carrinho',
                style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                error.toString(),
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: cartAsync.when(
        data: (cart) => cart.isNotEmpty
            ? Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleCheckoutAll(context, ref, cart.items),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peach,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      child: Text(
                        'Finalizar Todas as Reservas',
                        style: AppTextStyles.button.copyWith(color: AppColors.white),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
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
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 120,
                  color: AppColors.gray300,
                ),
                const SizedBox(height: AppDimensions.lg),
                Text(
                  'Carrinho Vazio',
                  style: AppTextStyles.h2.copyWith(color: AppColors.gray900),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'Adicione pacotes ao seu carrinho para reservar múltiplos serviços de uma vez.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.xl),
                ElevatedButton.icon(
                  onPressed: () => context.go(Routes.clientCategories),
                  icon: const Icon(Icons.search),
                  label: const Text('Explorar Pacotes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peach,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.lg,
                      vertical: AppDimensions.md,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRemoveItemDialog(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do carrinho?'),
        content: const Text(
          'Tem certeza que deseja remover este pacote do carrinho?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(cartRepositoryProvider);
        await repository.removeFromCart(itemId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pacote removido do carrinho'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showClearCartDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar carrinho?'),
        content: const Text(
          'Tem certeza que deseja remover todos os pacotes do carrinho?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Limpar Tudo'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(cartRepositoryProvider);
        await repository.clearCart();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carrinho limpo'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao limpar carrinho: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCheckoutAll(BuildContext context, WidgetRef ref, List items) async {
    if (items.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar todas as reservas?'),
        content: Text(
          'Você está prestes a reservar ${items.length} ${items.length == 1 ? 'pacote' : 'pacotes'}. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.peach),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.peach),
                  SizedBox(height: 16),
                  Text('Processando reservas...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Create bookings via Cloud Function for each cart item
      final repository = ref.read(cartRepositoryProvider);
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final createBookingFn = functions.httpsCallable('createBooking');
      final firestore = FirebaseFirestore.instance;

      int successCount = 0;
      int failureCount = 0;
      final List<String> errors = [];

      for (final item in items) {
        try {
          final cartItem = item as CartItem;

          // Format event date as YYYY-MM-DD for Cloud Function
          final eventDateStr = DateFormat('yyyy-MM-dd').format(cartItem.selectedDate);

          // Call createBooking Cloud Function
          // This ensures proper validation, rate limiting, and notifications
          final result = await createBookingFn.call<Map<String, dynamic>>({
            'supplierId': cartItem.supplierId,
            'packageId': cartItem.packageId,
            'eventDate': eventDateStr,
            'guestCount': cartItem.guestCount,
            'eventName': cartItem.packageName,
          });

          final data = result.data is Map<String, dynamic>
              ? result.data
              : Map<String, dynamic>.from(result.data as Map);

          if (data['success'] == true && data['bookingId'] != null) {
            final bookingId = data['bookingId'] as String;

            // Update booking with cart-specific details (customizations, prices)
            // The Cloud Function creates the base booking, we add cart details
            await firestore.collection('bookings').doc(bookingId).update({
              'selectedCustomizations': cartItem.selectedCustomizations,
              'basePrice': cartItem.basePrice,
              'customizationsPrice': cartItem.customizationsPrice,
              'totalPrice': cartItem.totalPrice,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            successCount++;
          } else {
            failureCount++;
            errors.add(data['error'] as String? ?? 'Erro desconhecido');
          }
        } on FirebaseFunctionsException catch (e) {
          failureCount++;
          debugPrint('Error creating booking: ${e.code} - ${e.message}');
          errors.add(e.message ?? 'Erro ao criar reserva');
        } catch (e) {
          failureCount++;
          debugPrint('Error creating booking: $e');
          errors.add(e.toString());
        }
      }

      // Clear cart after successful bookings
      if (successCount > 0) {
        await repository.clearCart();
      }

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show result
      if (context.mounted) {
        if (failureCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount ${successCount == 1 ? 'reserva criada' : 'reservas criadas'} com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          // Navigate to bookings screen
          context.push(Routes.clientBookings);
        } else if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount reservas criadas, $failureCount falharam'),
              backgroundColor: AppColors.warning,
            ),
          );
          // Still navigate since some succeeded
          context.push(Routes.clientBookings);
        } else {
          // All failed - show first error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errors.isNotEmpty ? errors.first : 'Erro ao criar reservas'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar reservas: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatPrice(int price) {
    final formatted = price
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted Kz';
  }
}
