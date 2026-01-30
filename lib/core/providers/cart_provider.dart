import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Validation status for a cart item
class CartItemValidation {
  final CartItem item;
  final bool isValid;
  final String? invalidReason;
  final bool supplierActive;
  final bool dateAvailable;
  final bool packageExists;

  const CartItemValidation({
    required this.item,
    required this.isValid,
    this.invalidReason,
    this.supplierActive = true,
    this.dateAvailable = true,
    this.packageExists = true,
  });
}

/// Validated cart with item status
class ValidatedCart {
  final List<CartItemValidation> validatedItems;
  final List<CartItem> validItems;
  final List<CartItem> invalidItems;

  ValidatedCart({
    required this.validatedItems,
  })  : validItems = validatedItems
            .where((v) => v.isValid)
            .map((v) => v.item)
            .toList(),
        invalidItems = validatedItems
            .where((v) => !v.isValid)
            .map((v) => v.item)
            .toList();

  int get validItemCount => validItems.length;
  int get invalidItemCount => invalidItems.length;
  int get totalValidPrice =>
      validItems.fold(0, (sum, item) => sum + item.totalPrice);
  bool get hasInvalidItems => invalidItems.isNotEmpty;
  bool get isEmpty => validatedItems.isEmpty;
}

/// Provider that validates cart items against current supplier/package status
///
/// Checks:
/// - Supplier is still active and accepting bookings
/// - Package still exists and is active
/// - Selected date is still available
final validatedCartProvider = FutureProvider<ValidatedCart>((ref) async {
  final cartAsync = ref.watch(cartProvider);

  return cartAsync.when(
    data: (cart) async {
      if (cart.isEmpty) {
        return ValidatedCart(validatedItems: []);
      }

      final validatedItems = <CartItemValidation>[];
      final firestore = FirebaseFirestore.instance;

      // Group items by supplier for efficiency
      final supplierIds = cart.supplierIds;

      // Batch fetch supplier data
      final supplierDocs = await Future.wait(
        supplierIds.map((id) => firestore.collection('suppliers').doc(id).get()),
      );

      final supplierData = <String, Map<String, dynamic>>{};
      for (final doc in supplierDocs) {
        if (doc.exists) {
          supplierData[doc.id] = doc.data()!;
        }
      }

      // Validate each cart item
      for (final item in cart.items) {
        final supplier = supplierData[item.supplierId];
        String? invalidReason;
        bool supplierActive = true;
        bool dateAvailable = true;
        bool packageExists = true;

        // Check supplier exists and is active
        if (supplier == null) {
          invalidReason = 'Fornecedor não encontrado';
          supplierActive = false;
        } else if (supplier['isActive'] != true) {
          invalidReason = 'Fornecedor temporariamente indisponível';
          supplierActive = false;
        } else if (supplier['accountStatus'] != 'active') {
          invalidReason = 'Fornecedor temporariamente indisponível';
          supplierActive = false;
        } else if (supplier['acceptingBookings'] == false) {
          invalidReason = 'Fornecedor não está aceitando reservas';
          supplierActive = false;
        }

        // Check if date is in the past
        if (invalidReason == null && item.selectedDate.isBefore(DateTime.now())) {
          invalidReason = 'Data selecionada já passou';
          dateAvailable = false;
        }

        // Check package exists (only if supplier is valid)
        if (invalidReason == null) {
          final packageDoc = await firestore
              .collection('packages')
              .doc(item.packageId)
              .get();

          if (!packageDoc.exists) {
            invalidReason = 'Pacote não mais disponível';
            packageExists = false;
          } else {
            final packageData = packageDoc.data()!;
            if (packageData['isActive'] != true) {
              invalidReason = 'Pacote temporariamente indisponível';
              packageExists = false;
            }
          }
        }

        validatedItems.add(CartItemValidation(
          item: item,
          isValid: invalidReason == null,
          invalidReason: invalidReason,
          supplierActive: supplierActive,
          dateAvailable: dateAvailable,
          packageExists: packageExists,
        ));
      }

      return ValidatedCart(validatedItems: validatedItems);
    },
    loading: () => ValidatedCart(validatedItems: []),
    error: (_, __) => ValidatedCart(validatedItems: []),
  );
});

/// Provider for checking if cart has any invalid items
final cartHasInvalidItemsProvider = Provider<bool>((ref) {
  final validatedCartAsync = ref.watch(validatedCartProvider);
  return validatedCartAsync.when(
    data: (cart) => cart.hasInvalidItems,
    loading: () => false,
    error: (_, __) => false,
  );
});
