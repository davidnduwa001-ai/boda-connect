import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_model.dart';

class CartRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CartRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference _getCartCollection() {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(_userId).collection('cart');
  }

  // Get all cart items
  Stream<Cart> watchCart() {
    if (_userId == null) {
      return Stream.value(const Cart([]));
    }

    return _getCartCollection()
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CartItem.fromFirestore(doc))
          .toList();
      return Cart(items);
    });
  }

  // Add item to cart
  Future<String> addToCart(CartItem item) async {
    final docRef = await _getCartCollection().add(item.toFirestore());
    return docRef.id;
  }

  // Remove item from cart
  Future<void> removeFromCart(String itemId) async {
    await _getCartCollection().doc(itemId).delete();
  }

  // Update item in cart
  Future<void> updateCartItem(String itemId, {
    DateTime? selectedDate,
    int? guestCount,
    List<String>? selectedCustomizations,
    int? totalPrice,
  }) async {
    final updates = <String, dynamic>{};

    if (selectedDate != null) {
      updates['selectedDate'] = Timestamp.fromDate(selectedDate);
    }
    if (guestCount != null) {
      updates['guestCount'] = guestCount;
    }
    if (selectedCustomizations != null) {
      updates['selectedCustomizations'] = selectedCustomizations;
    }
    if (totalPrice != null) {
      updates['totalPrice'] = totalPrice;
    }

    if (updates.isNotEmpty) {
      await _getCartCollection().doc(itemId).update(updates);
    }
  }

  // Clear entire cart
  Future<void> clearCart() async {
    final snapshot = await _getCartCollection().get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Check if package is already in cart
  Future<bool> isInCart(String packageId) async {
    final snapshot = await _getCartCollection()
        .where('packageId', isEqualTo: packageId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Get cart item count
  Future<int> getCartItemCount() async {
    final snapshot = await _getCartCollection().get();
    return snapshot.docs.length;
  }
}
