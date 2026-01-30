import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/supplier_stats_provider.dart';

// ==================== FAVORITES STATE ====================

class FavoritesState {
  final List<String> favoriteSupplierIds;
  final List<SupplierModel> favoriteSuppliers;
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.favoriteSupplierIds = const [],
    this.favoriteSuppliers = const [],
    this.isLoading = false,
    this.error,
  });

  FavoritesState copyWith({
    List<String>? favoriteSupplierIds,
    List<SupplierModel>? favoriteSuppliers,
    bool? isLoading,
    String? error,
  }) {
    return FavoritesState(
      favoriteSupplierIds: favoriteSupplierIds ?? this.favoriteSupplierIds,
      favoriteSuppliers: favoriteSuppliers ?? this.favoriteSuppliers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool isFavorite(String supplierId) {
    return favoriteSupplierIds.contains(supplierId);
  }
}

// ==================== FAVORITES NOTIFIER ====================

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FavoritesNotifier(this._ref) : super(const FavoritesState());

  // Load user's favorites
  Future<void> loadFavorites() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Query favorites collection for this user
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();

      if (favoritesSnapshot.docs.isEmpty) {
        state = state.copyWith(
          favoriteSupplierIds: [],
          favoriteSuppliers: [],
          isLoading: false,
        );
        return;
      }

      // Extract supplier IDs from favorites
      final favoriteIds = favoritesSnapshot.docs
          .map((doc) => doc.data()['supplierId'] as String)
          .toList();

      // Load supplier details for favorites (only active suppliers)
      final suppliers = <SupplierModel>[];
      for (final supplierId in favoriteIds) {
        try {
          final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
          if (supplierDoc.exists) {
            final supplier = SupplierModel.fromFirestore(supplierDoc);
            // Only add if supplier is active
            if (supplier.isActive) {
              suppliers.add(supplier);
            }
          }
        } catch (_) {
          // Skip if supplier not found
        }
      }

      state = state.copyWith(
        favoriteSupplierIds: favoriteIds,
        favoriteSuppliers: suppliers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar favoritos: ${e.toString()}',
      );
    }
  }

  // Add supplier to favorites
  Future<bool> addFavorite(String supplierId) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return false;

    try {
      // Create favorite document with format: userId_supplierId
      final favoriteId = '${userId}_$supplierId';
      await _firestore.collection('favorites').doc(favoriteId).set({
        'userId': userId,
        'supplierId': supplierId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update supplier's favorite count (for dynamic stats)
      await _ref.read(favoriteActionProvider).addToFavorites(
        supplierId: supplierId,
        userId: userId,
      );

      // Load supplier details (only if active)
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      if (supplierDoc.exists) {
        final supplier = SupplierModel.fromFirestore(supplierDoc);

        // Only add if supplier is active
        if (supplier.isActive) {
          state = state.copyWith(
            favoriteSupplierIds: [...state.favoriteSupplierIds, supplierId],
            favoriteSuppliers: [...state.favoriteSuppliers, supplier],
          );
        }
      }

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Erro ao adicionar favorito: ${e.toString()}');
      return false;
    }
  }

  // Remove supplier from favorites
  Future<bool> removeFavorite(String supplierId) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return false;

    try {
      // Delete favorite document with format: userId_supplierId
      final favoriteId = '${userId}_$supplierId';
      await _firestore.collection('favorites').doc(favoriteId).delete();

      // Update supplier's favorite count (for dynamic stats)
      await _ref.read(favoriteActionProvider).removeFromFavorites(
        supplierId: supplierId,
        userId: userId,
      );

      // Update local state
      state = state.copyWith(
        favoriteSupplierIds: state.favoriteSupplierIds.where((id) => id != supplierId).toList(),
        favoriteSuppliers: state.favoriteSuppliers.where((s) => s.id != supplierId).toList(),
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Erro ao remover favorito: ${e.toString()}');
      return false;
    }
  }

  // Toggle favorite status
  Future<bool> toggleFavorite(String supplierId) async {
    if (state.isFavorite(supplierId)) {
      return await removeFavorite(supplierId);
    } else {
      return await addFavorite(supplierId);
    }
  }

  // Clear all favorites
  Future<bool> clearAllFavorites() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return false;

    try {
      // Query and delete all favorites for this user
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();

      // Delete all favorite documents in a batch
      final batch = _firestore.batch();
      for (final doc in favoritesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      state = state.copyWith(
        favoriteSupplierIds: [],
        favoriteSuppliers: [],
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Erro ao limpar favoritos: ${e.toString()}');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ==================== PROVIDERS ====================

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});

// Check if supplier is favorite
final isFavoriteProvider = Provider.family<bool, String>((ref, supplierId) {
  return ref.watch(favoritesProvider).isFavorite(supplierId);
});

// Get favorite suppliers list
final favoriteSuppliersProvider = Provider<List<SupplierModel>>((ref) {
  return ref.watch(favoritesProvider).favoriteSuppliers;
});
