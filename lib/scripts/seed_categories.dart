import 'package:boda_connect/core/models/category_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Script to seed Firestore with default categories
/// Run this once to populate the categories collection
class SeedCategories {
  static Future<void> seedToFirestore() async {
    final db = FirebaseFirestore.instance;
    final categories = getDefaultCategories();

    print('🌱 Seeding ${categories.length} categories to Firestore...');

    int successCount = 0;
    int errorCount = 0;

    for (final category in categories) {
      try {
        await db.collection('categories').doc(category.id).set({
          'name': category.name,
          'icon': category.icon,
          'color': category.color.toARGB32(),
          'isActive': category.isActive,
          'supplierCount': category.supplierCount,
          'subcategories': category.subcategories,
          'order': categories.indexOf(category),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Seeded category: ${category.name}');
        successCount++;
      } catch (e) {
        print('❌ Error seeding ${category.name}: $e');
        errorCount++;
      }
    }

    print('\n📊 Seeding complete!');
    print('✅ Success: $successCount');
    if (errorCount > 0) {
      print('❌ Errors: $errorCount');
    }
  }

  /// Update supplier count for a category
  static Future<void> updateSupplierCount(
      String categoryId, int count) async {
    try {
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .update({
        'supplierCount': count,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated supplier count for $categoryId to $count');
    } catch (e) {
      print('❌ Error updating supplier count: $e');
    }
  }

  /// Calculate and update supplier counts for all categories
  static Future<void> updateAllSupplierCounts() async {
    final db = FirebaseFirestore.instance;

    print('📊 Calculating supplier counts...');

    // Get all categories
    final categoriesSnapshot = await db.collection('categories').get();

    for (final categoryDoc in categoriesSnapshot.docs) {
      final categoryName = categoryDoc.data()['name'] as String;

      // Count suppliers in this category
      final suppliersSnapshot = await db
          .collection('suppliers')
          .where('category', isEqualTo: categoryName)
          .where('isActive', isEqualTo: true)
          .get();

      final count = suppliersSnapshot.docs.length;

      // Update category
      await categoryDoc.reference.update({
        'supplierCount': count,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ $categoryName: $count suppliers');
    }

    print('\n✅ All supplier counts updated!');
  }

  /// Check if categories exist in Firestore
  static Future<bool> categoriesExist() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('categories').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }
}

/// Example usage in a Flutter widget or main.dart:
///
/// ```dart
/// // In your initState or onPressed:
/// Future<void> _seedCategories() async {
///   final exist = await SeedCategories.categoriesExist();
///   if (!exist) {
///     await SeedCategories.seedToFirestore();
///   } else {
///     print('Categories already exist!');
///   }
/// }
/// ```
