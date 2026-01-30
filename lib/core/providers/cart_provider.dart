import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_model.dart';
import '../repositories/cart_repository.dart';

// Cart repository provider
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});

// Cart stream provider
final cartProvider = StreamProvider<Cart>((ref) {
  final repository = ref.watch(cartRepositoryProvider);
  return repository.watchCart();
});

// Cart item count provider
final cartItemCountProvider = Provider<int>((ref) {
  final cartAsync = ref.watch(cartProvider);
  return cartAsync.when(
    data: (cart) => cart.itemCount,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Cart total price provider
final cartTotalPriceProvider = Provider<int>((ref) {
  final cartAsync = ref.watch(cartProvider);
  return cartAsync.when(
    data: (cart) => cart.totalPrice,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Check if package is in cart provider
final isInCartProvider = FutureProvider.family<bool, String>((ref, packageId) async {
  final repository = ref.watch(cartRepositoryProvider);
  return repository.isInCart(packageId);
});
