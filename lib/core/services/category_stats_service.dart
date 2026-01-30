import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing category statistics including supplier counts
class CategoryStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get real-time supplier count for a specific category
  Future<int> getSupplierCountForCategory(String categoryName) async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .where('category', isEqualTo: categoryName)
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting supplier count for $categoryName: $e');
      return 0;
    }
  }

  /// Update supplier count for a specific category
  Future<void> updateCategorySupplierCount(String categoryId, String categoryName) async {
    try {
      final count = await getSupplierCountForCategory(categoryName);
      await _firestore.collection('categories').doc(categoryId).update({
        'supplierCount': count,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Updated $categoryName supplier count to $count');
    } catch (e) {
      debugPrint('Error updating category supplier count: $e');
    }
  }

  /// Update supplier counts for ALL categories (batch operation)
  Future<Map<String, int>> updateAllCategorySupplierCounts() async {
    final results = <String, int>{};

    try {
      debugPrint('Starting category supplier count update...');

      // Get all categories
      final categoriesSnapshot = await _firestore.collection('categories').get();

      for (final categoryDoc in categoriesSnapshot.docs) {
        final categoryName = categoryDoc.data()['name'] as String?;
        if (categoryName == null) continue;

        // Count suppliers in this category
        final count = await getSupplierCountForCategory(categoryName);
        results[categoryName] = count;

        // Update category document
        await categoryDoc.reference.update({
          'supplierCount': count,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('$categoryName: $count suppliers');
      }

      debugPrint('Category supplier counts updated successfully!');
    } catch (e) {
      debugPrint('Error updating all category supplier counts: $e');
    }

    return results;
  }

  /// Stream real-time category data with live supplier counts
  Stream<List<CategoryWithCount>> streamCategoriesWithCounts() {
    return _firestore
        .collection('categories')
        .orderBy('order')
        .snapshots()
        .asyncMap((snapshot) async {
      final categories = <CategoryWithCount>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final categoryName = data['name'] as String? ?? '';

        // Get real-time supplier count
        final count = await getSupplierCountForCategory(categoryName);

        categories.add(CategoryWithCount(
          id: doc.id,
          name: categoryName,
          icon: data['icon'] as String? ?? 'category',
          isActive: data['isActive'] as bool? ?? true,
          supplierCount: count,
          order: data['order'] as int? ?? 0,
        ));
      }

      return categories;
    });
  }

  /// Get category statistics for admin dashboard
  Future<CategoryStats> getCategoryStats() async {
    try {
      final categoriesSnapshot = await _firestore.collection('categories').get();
      final totalCategories = categoriesSnapshot.docs.length;

      int activeCategories = 0;
      int totalSuppliers = 0;

      for (final doc in categoriesSnapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == true) {
          activeCategories++;
        }

        final categoryName = data['name'] as String?;
        if (categoryName != null) {
          final count = await getSupplierCountForCategory(categoryName);
          totalSuppliers += count;
        }
      }

      return CategoryStats(
        totalCategories: totalCategories,
        activeCategories: activeCategories,
        totalSuppliers: totalSuppliers,
      );
    } catch (e) {
      debugPrint('Error getting category stats: $e');
      return CategoryStats.empty();
    }
  }

  /// Increment supplier count when a new supplier is created
  Future<void> incrementSupplierCount(String categoryName) async {
    try {
      final categoryQuery = await _firestore
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .limit(1)
          .get();

      if (categoryQuery.docs.isNotEmpty) {
        await categoryQuery.docs.first.reference.update({
          'supplierCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Incremented supplier count for $categoryName');
      }
    } catch (e) {
      debugPrint('Error incrementing supplier count: $e');
    }
  }

  /// Decrement supplier count when a supplier is deleted/deactivated
  Future<void> decrementSupplierCount(String categoryName) async {
    try {
      final categoryQuery = await _firestore
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .limit(1)
          .get();

      if (categoryQuery.docs.isNotEmpty) {
        final currentCount = categoryQuery.docs.first.data()['supplierCount'] as int? ?? 0;
        await categoryQuery.docs.first.reference.update({
          'supplierCount': currentCount > 0 ? FieldValue.increment(-1) : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Decremented supplier count for $categoryName');
      }
    } catch (e) {
      debugPrint('Error decrementing supplier count: $e');
    }
  }
}

/// Category with real-time supplier count
class CategoryWithCount {
  final String id;
  final String name;
  final String icon;
  final bool isActive;
  final int supplierCount;
  final int order;

  CategoryWithCount({
    required this.id,
    required this.name,
    required this.icon,
    required this.isActive,
    required this.supplierCount,
    required this.order,
  });
}

/// Category statistics for dashboard
class CategoryStats {
  final int totalCategories;
  final int activeCategories;
  final int totalSuppliers;

  CategoryStats({
    required this.totalCategories,
    required this.activeCategories,
    required this.totalSuppliers,
  });

  factory CategoryStats.empty() => CategoryStats(
        totalCategories: 0,
        activeCategories: 0,
        totalSuppliers: 0,
      );
}
