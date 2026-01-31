import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/models/cart_model.dart';
import '../../../../core/providers/booking_provider.dart';
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

      // Create bookings for each cart item using Cloud Function
      final cartRepository = ref.read(cartRepositoryProvider);
      final bookingRepository = ref.read(bookingRepositoryProvider);
      final auth = FirebaseAuth.instance;
      final userId = auth.currentUser?.uid;

      if (userId == null) throw Exception('Usuário não autenticado');

      int successCount = 0;
      int failureCount = 0;

      for (final item in items) {
        try {
          final cartItem = item as CartItem;
          final now = DateTime.now();

          // Create booking model and use Cloud Function
          final booking = BookingModel(
            id: '', // Will be generated by Cloud Function
            clientId: userId,
            clientName: '', // Will be fetched by Cloud Function
            supplierId: cartItem.supplierId,
            supplierName: '', // Will be fetched by Cloud Function
            packageId: cartItem.packageId,
            packageName: cartItem.packageName,
            eventName: '',
            eventDate: cartItem.selectedDate,
            status: BookingStatus.pending,
            totalPrice: cartItem.totalPrice,
            paidAmount: 0,
            currency: 'AOA',
            selectedCustomizations: cartItem.selectedCustomizations,
            guestCount: cartItem.guestCount,
            createdAt: now,
            updatedAt: now,
          );

          await bookingRepository.createBooking(booking);
          successCount++;
        } catch (e) {
          failureCount++;
          debugPrint('Error creating booking: $e');
        }
      }

      // Clear cart after successful bookings
      if (successCount > 0) {
        await cartRepository.clearCart();
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount reservas criadas, $failureCount falharam'),
              backgroundColor: AppColors.warning,
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
