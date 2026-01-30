import 'package:boda_connect/core/models/category_model.dart';
import 'package:boda_connect/core/services/category_stats_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Category Stats Service Provider
final categoryStatsServiceProvider = Provider<CategoryStatsService>((ref) {
  return CategoryStatsService();
});

/// Categories Stream Provider
/// Loads all active categories from Firestore in real-time
final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc.data(), doc.id))
        .toList();
  });
});

/// Categories with Live Supplier Counts Provider
/// This provider calculates real supplier counts from the suppliers collection
final categoriesWithLiveCountsProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final firestore = FirebaseFirestore.instance;

  // Get all categories
  final categoriesSnapshot = await firestore
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .get();

  // Get real supplier counts per category
  final suppliersSnapshot = await firestore
      .collection('suppliers')
      .where('isActive', isEqualTo: true)
      .get();

  // Count suppliers by category
  final categoryCounts = <String, int>{};
  for (final doc in suppliersSnapshot.docs) {
    final category = doc.data()['category'] as String? ?? 'Outros';
    categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
  }

  // Map categories with live counts
  return categoriesSnapshot.docs.map((doc) {
    final data = doc.data();
    final categoryName = data['name'] as String? ?? '';
    return CategoryModel.fromFirestore(data, doc.id).copyWith(
      supplierCount: categoryCounts[categoryName] ?? 0,
    );
  }).toList();
});

/// Featured Categories Provider
/// Returns top 8 categories based on supplier count
final featuredCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final categoriesAsync = ref.watch(categoriesProvider);

  return categoriesAsync.when(
    data: (categories) {
      // Sort by supplier count and take top 8
      final sorted = List<CategoryModel>.from(categories)
        ..sort((a, b) => b.supplierCount.compareTo(a.supplierCount));
      return sorted.take(8).toList();
    },
    loading: () {
      // Return default categories while loading
      return getDefaultCategories().take(8).toList();
    },
    error: (_, __) {
      // Return default categories on error
      return getDefaultCategories().take(8).toList();
    },
  );
});

/// Category by ID Provider
final categoryByIdProvider =
    Provider.family<CategoryModel?, String>((ref, categoryId) {
  final categoriesAsync = ref.watch(categoriesProvider);

  return categoriesAsync.when(
    data: (categories) {
      try {
        return categories.firstWhere((cat) => cat.id == categoryId);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
