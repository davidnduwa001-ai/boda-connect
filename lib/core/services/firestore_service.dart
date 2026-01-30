import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/models/package_model.dart';
import 'package:boda_connect/core/models/review_category_models.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== COLLECTION REFERENCES ====================

  /// Suppliers collection reference
  CollectionReference<Map<String, dynamic>> get suppliers =>
      _firestore.collection('suppliers');

  /// Bookings collection reference
  CollectionReference<Map<String, dynamic>> get bookings =>
      _firestore.collection('bookings');

  /// Reviews collection reference
  CollectionReference<Map<String, dynamic>> get reviews =>
      _firestore.collection('reviews');

  /// Categories collection reference
  CollectionReference<Map<String, dynamic>> get categories =>
      _firestore.collection('categories');

  // ==================== SUPPLIER METHODS ====================

  /// Create supplier profile
  Future<String> createSupplier(SupplierModel supplier) async {
    final docRef = await _firestore.collection('suppliers').add(supplier.toFirestore());
    return docRef.id;
  }

  /// Get supplier by ID
  /// Returns supplier regardless of isActive status (needed for onboarding/verification)
  Future<SupplierModel?> getSupplier(String id) async {
    final doc = await _firestore.collection('suppliers').doc(id).get();
    if (!doc.exists) return null;
    return SupplierModel.fromFirestore(doc);
  }

  /// Get supplier by user ID
  /// Returns the supplier regardless of isActive status (for onboarding flow)
  Future<SupplierModel?> getSupplierByUserId(String userId) async {
    // First try to get any supplier for this user (including pending review)
    final query = await _firestore
        .collection('suppliers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return SupplierModel.fromFirestore(doc);
  }

  /// Update supplier profile
  Future<void> updateSupplier(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('suppliers').doc(id).update(data);
  }

  /// Get suppliers with filters
  Future<List<SupplierModel>> getSuppliers({
    String? category,
    String? city,
    double? minRating,
    bool? isVerified,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore.collection('suppliers').where('isActive', isEqualTo: true);

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    if (isVerified != null) {
      query = query.where('isVerified', isEqualTo: isVerified);
    }

    // Apply pagination if startAfter is provided
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Fetch more to filter client-side for complex filters
    query = query.limit(limit * 3);

    final snapshot = await query.get();
    var suppliers = snapshot.docs
        .map((doc) => SupplierModel.fromFirestore(doc))
        .toList();

    // Client-side filtering for city and rating (avoids complex Firestore indexes)
    if (city != null && city.isNotEmpty) {
      suppliers = suppliers.where((s) => s.location?.city == city).toList();
    }

    if (minRating != null && minRating > 0) {
      suppliers = suppliers.where((s) => s.rating >= minRating).toList();
    }

    // Sort by rating descending
    suppliers.sort((a, b) => b.rating.compareTo(a.rating));

    return suppliers.take(limit).toList();
  }

  /// Search suppliers by text query
  Future<List<SupplierModel>> searchSuppliers(
    String query, {
    double? minRating,
    String? city,
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      return getSuppliers(minRating: minRating, city: city, limit: limit);
    }

    final queryLower = query.toLowerCase();

    // Get active suppliers and filter client-side for text search
    final snapshot = await _firestore
        .collection('suppliers')
        .where('isActive', isEqualTo: true)
        .limit(limit * 5) // Fetch more for client-side filtering
        .get();

    var suppliers = snapshot.docs
        .map((doc) => SupplierModel.fromFirestore(doc))
        .where((supplier) {
          // Text matching
          final nameMatch = supplier.businessName.toLowerCase().contains(queryLower);
          final categoryMatch = supplier.category.toLowerCase().contains(queryLower);
          final descMatch = supplier.description.toLowerCase().contains(queryLower);
          final keywordMatch = supplier.searchKeywords.any(
            (keyword) => keyword.toLowerCase().contains(queryLower),
          );

          return nameMatch || categoryMatch || descMatch || keywordMatch;
        })
        .toList();

    // Apply additional filters
    if (city != null && city.isNotEmpty) {
      suppliers = suppliers.where((s) => s.location?.city == city).toList();
    }

    if (minRating != null && minRating > 0) {
      suppliers = suppliers.where((s) => s.rating >= minRating).toList();
    }

    // Sort by relevance (verified first, then by rating)
    suppliers.sort((a, b) {
      if (a.isVerified != b.isVerified) {
        return a.isVerified ? -1 : 1;
      }
      return b.rating.compareTo(a.rating);
    });

    return suppliers.take(limit).toList();
  }

  /// Search suppliers within a specific category
  Future<List<SupplierModel>> searchSuppliersInCategory(
    String query,
    String category, {
    double? minRating,
    String? city,
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      return getSuppliers(category: category, minRating: minRating, city: city, limit: limit);
    }

    final queryLower = query.toLowerCase();

    // Get active suppliers in category and filter client-side for text search
    final snapshot = await _firestore
        .collection('suppliers')
        .where('isActive', isEqualTo: true)
        .where('category', isEqualTo: category)
        .limit(limit * 3)
        .get();

    var suppliers = snapshot.docs
        .map((doc) => SupplierModel.fromFirestore(doc))
        .where((supplier) {
          final nameMatch = supplier.businessName.toLowerCase().contains(queryLower);
          final descMatch = supplier.description.toLowerCase().contains(queryLower);
          final keywordMatch = supplier.searchKeywords.any(
            (keyword) => keyword.toLowerCase().contains(queryLower),
          );

          return nameMatch || descMatch || keywordMatch;
        })
        .toList();

    // Apply additional filters
    if (city != null && city.isNotEmpty) {
      suppliers = suppliers.where((s) => s.location?.city == city).toList();
    }

    if (minRating != null && minRating > 0) {
      suppliers = suppliers.where((s) => s.rating >= minRating).toList();
    }

    // Sort by relevance
    suppliers.sort((a, b) {
      if (a.isVerified != b.isVerified) {
        return a.isVerified ? -1 : 1;
      }
      return b.rating.compareTo(a.rating);
    });

    return suppliers.take(limit).toList();
  }

  /// Get featured suppliers
  Future<List<SupplierModel>> getFeaturedSuppliers({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('suppliers')
        .where('isActive', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .limit(limit)
        .get();

    var suppliers = snapshot.docs
        .map((doc) => SupplierModel.fromFirestore(doc))
        .toList();

    // Sort by rating
    suppliers.sort((a, b) => b.rating.compareTo(a.rating));

    return suppliers;
  }

  /// Get suppliers by category with count
  Future<Map<String, int>> getCategoryCounts() async {
    final snapshot = await _firestore
        .collection('suppliers')
        .where('isActive', isEqualTo: true)
        .get();

    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = data['category'] as String? ?? 'Outros';
      counts[category] = (counts[category] ?? 0) + 1;
    }

    return counts;
  }

  // ==================== PACKAGE METHODS ====================

  /// Create package
  Future<String> createPackage(PackageModel package) async {
    final data = package.toFirestore();
    data.remove('id'); // Remove id as it will be auto-generated

    final docRef = await _firestore.collection('packages').add(data);
    return docRef.id;
  }

  /// Get package by ID
  Future<PackageModel?> getPackage(String id) async {
    final doc = await _firestore.collection('packages').doc(id).get();
    if (!doc.exists) return null;
    return PackageModel.fromFirestore(doc);
  }

  /// Get packages for a supplier
  Future<List<PackageModel>> getSupplierPackages(String supplierId) async {
    final query = await _firestore
        .collection('packages')
        .where('supplierId', isEqualTo: supplierId)
        .where('isActive', isEqualTo: true)
        .get();

    // Sort in memory instead of using Firestore orderBy to avoid index requirement
    final packages = query.docs
        .map((doc) => PackageModel.fromFirestore(doc))
        .toList();

    packages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return packages;
  }

  /// Update package
  Future<void> updatePackage(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('packages').doc(id).update(data);
  }

  /// Delete package (soft delete)
  Future<void> deletePackage(String id) async {
    await _firestore.collection('packages').doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all packages with filters
  Future<List<PackageModel>> getPackages({
    String? category,
    int? minPrice,
    int? maxPrice,
    int limit = 20,
  }) async {
    Query query = _firestore.collection('packages').where('isActive', isEqualTo: true);

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => PackageModel.fromFirestore(doc))
        .toList();
  }

  // ==================== REVIEW METHODS ====================

  /// Get supplier reviews
  Future<List<ReviewModel>> getSupplierReviews(String supplierId, {int limit = 50}) async {
    final query = await _firestore
        .collection('reviews')
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return query.docs
        .map((doc) => ReviewModel.fromFirestore(doc))
        .toList();
  }

  /// Create review
  Future<String> createReview(ReviewModel review) async {
    final data = review.toFirestore();
    data.remove('id');

    final docRef = await _firestore.collection('reviews').add(data);
    return docRef.id;
  }

  /// Add supplier reply to review
  Future<void> addSupplierReply(String reviewId, String reply) async {
    await _firestore.collection('reviews').doc(reviewId).update({
      'supplierReply': reply,
      'supplierReplyAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== CATEGORY METHODS ====================

  /// Get all categories
  Future<List<CategoryModel>> getCategories() async {
    final snapshot = await _firestore
        .collection('categories')
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc))
        .toList();
  }

  /// Initialize default categories (for app setup)
  Future<void> initializeCategories() async {
    final existingCategories = await _firestore.collection('categories').limit(1).get();
    if (existingCategories.docs.isNotEmpty) return; // Already initialized

    final defaultCategories = [
      {'name': 'Decoração', 'icon': 'palette', 'order': 1},
      {'name': 'Fotografia', 'icon': 'camera_alt', 'order': 2},
      {'name': 'Catering', 'icon': 'restaurant', 'order': 3},
      {'name': 'Música', 'icon': 'music_note', 'order': 4},
      {'name': 'Flores', 'icon': 'local_florist', 'order': 5},
      {'name': 'Bolos', 'icon': 'cake', 'order': 6},
      {'name': 'Convites', 'icon': 'mail', 'order': 7},
      {'name': 'Locais', 'icon': 'location_on', 'order': 8},
      {'name': 'Vestuário', 'icon': 'checkroom', 'order': 9},
      {'name': 'Beleza', 'icon': 'face', 'order': 10},
      {'name': 'Transporte', 'icon': 'directions_car', 'order': 11},
      {'name': 'Outros', 'icon': 'more_horiz', 'order': 12},
    ];

    final batch = _firestore.batch();
    for (final category in defaultCategories) {
      final docRef = _firestore.collection('categories').doc();
      batch.set(docRef, {
        ...category,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
