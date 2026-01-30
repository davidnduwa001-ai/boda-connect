import 'package:boda_connect/core/models/package_model.dart';
import 'package:boda_connect/core/models/review_category_models.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/services/firestore_service.dart';
import 'package:boda_connect/core/services/storage_service.dart' hide FirestoreService;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class SupplierRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  // ==================== SUPPLIER CRUD ====================

  /// Create a new supplier profile
  Future<String> createSupplier(SupplierModel supplier) async {
    return await _firestoreService.createSupplier(supplier);
  }

  /// Get supplier by ID
  Future<SupplierModel?> getSupplier(String id) async {
    return await _firestoreService.getSupplier(id);
  }

  /// Get supplier by user ID
  Future<SupplierModel?> getSupplierByUserId(String userId) async {
    return await _firestoreService.getSupplierByUserId(userId);
  }

  /// Update supplier profile
  Future<void> updateSupplier(String id, Map<String, dynamic> data) async {
    await _firestoreService.updateSupplier(id, data);
  }

  /// Get all suppliers with optional filters
  Future<List<SupplierModel>> getSuppliers({
    String? category,
    String? city,
    double? minRating,
    bool? isVerified,
    int limit = 20,
    String? startAfterId,
  }) async {
    DocumentSnapshot? startAfterDoc;

    if (startAfterId != null) {
      startAfterDoc = await _firestoreService.suppliers.doc(startAfterId).get();
    }

    return await _firestoreService.getSuppliers(
      category: category,
      city: city,
      minRating: minRating,
      isVerified: isVerified,
      limit: limit,
      startAfter: startAfterDoc,
    );
  }

  /// Get featured suppliers
  Future<List<SupplierModel>> getFeaturedSuppliers({int limit = 10}) async {
    return await _firestoreService.getFeaturedSuppliers(limit: limit);
  }

  /// Search suppliers by name with optional filters
  Future<List<SupplierModel>> searchSuppliers(
    String query, {
    double? minRating,
    String? city,
  }) async {
    return await _firestoreService.searchSuppliers(
      query,
      minRating: minRating,
      city: city,
    );
  }

  /// CATEGORY-STRICT Search - only returns suppliers within specified category
  /// Use this to ensure search results don't pollute across industries
  Future<List<SupplierModel>> searchSuppliersInCategory(
    String query,
    String category, {
    double? minRating,
    String? city,
  }) async {
    return await _firestoreService.searchSuppliersInCategory(
      query,
      category,
      minRating: minRating,
      city: city,
    );
  }

  /// Get suppliers by category
  Future<List<SupplierModel>> getSuppliersByCategory(String category) async {
    return await _firestoreService.getSuppliers(category: category);
  }

  // ==================== PHOTOS & VIDEOS ====================

  /// Upload supplier photos
  Future<List<String>> uploadSupplierPhotos(
    String supplierId,
    List<XFile> files, {
    Function(int, int)? onProgress,
  }) async {
    return await _storageService.uploadSupplierPhotos(
      supplierId,
      files,
      onProgress: onProgress,
    );
  }

  /// Upload single supplier photo
  Future<String> uploadSupplierPhoto(String supplierId, XFile file) async {
    return await _storageService.uploadSupplierPhoto(supplierId, file);
  }

  /// Upload supplier video
  Future<String> uploadSupplierVideo(String supplierId, XFile file) async {
    return await _storageService.uploadSupplierVideo(supplierId, file);
  }

  /// Delete photo
  Future<void> deletePhoto(String photoUrl) async {
    await _storageService.deleteFileByUrl(photoUrl);
  }

  // ==================== PACKAGES ====================

  /// Create a new package
  Future<String> createPackage(PackageModel package) async {
    return await _firestoreService.createPackage(package);
  }

  /// Get package by ID
  Future<PackageModel?> getPackage(String id) async {
    return await _firestoreService.getPackage(id);
  }

  /// Get all packages for a supplier
  Future<List<PackageModel>> getSupplierPackages(String supplierId) async {
    return await _firestoreService.getSupplierPackages(supplierId);
  }

  /// Update package
  Future<void> updatePackage(String id, Map<String, dynamic> data) async {
    await _firestoreService.updatePackage(id, data);
  }

  /// Delete package (soft delete)
  Future<void> deletePackage(String id) async {
    await _firestoreService.deletePackage(id);
  }

  /// Upload package photo
  Future<String> uploadPackagePhoto(String packageId, XFile file) async {
    return await _storageService.uploadPackagePhoto(packageId, file);
  }

  // ==================== REVIEWS ====================

  /// Get supplier reviews
  Future<List<ReviewModel>> getSupplierReviews(
    String supplierId, {
    int limit = 20,
  }) async {
    return await _firestoreService.getSupplierReviews(supplierId, limit: limit);
  }

  /// Add reply to review
  Future<void> addReviewReply(String reviewId, String reply) async {
    await _firestoreService.addSupplierReply(reviewId, reply);
  }

  // ==================== CATEGORIES ====================

  /// Get all categories
  Future<List<CategoryModel>> getCategories() async {
    return await _firestoreService.getCategories();
  }

  /// Initialize default categories
  Future<void> initializeCategories() async {
    await _firestoreService.initializeCategories();
  }

  // ==================== AVAILABILITY ====================

  /// Update supplier availability
  Future<void> updateAvailability(
    String supplierId,
    WorkingHours workingHours,
  ) async {
    await updateSupplier(supplierId, {
      'workingHours': workingHours.toMap(),
    });
  }

  /// Add unavailable dates
  Future<void> addUnavailableDates(
    String supplierId,
    List<DateTime> dates,
  ) async {
    final timestamps = dates.map((d) => Timestamp.fromDate(d)).toList();

    await _firestoreService.suppliers.doc(supplierId).update({
      'unavailableDates': FieldValue.arrayUnion(timestamps),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Remove unavailable date
  Future<void> removeUnavailableDate(
    String supplierId,
    DateTime date,
  ) async {
    await _firestoreService.suppliers.doc(supplierId).update({
      'unavailableDates': FieldValue.arrayRemove([Timestamp.fromDate(date)]),
      'updatedAt': Timestamp.now(),
    });
  }

  // ==================== STATS ====================

  /// Get supplier statistics
  Future<Map<String, dynamic>> getSupplierStats(String supplierId) async {
    final bookingsSnapshot = await _firestoreService.bookings
        .where('supplierId', isEqualTo: supplierId)
        .get();

    int totalBookings = bookingsSnapshot.docs.length;
    int completedBookings = 0;
    int totalRevenue = 0;

    for (final doc in bookingsSnapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'completed') {
        completedBookings++;
        totalRevenue += (data['paidAmount'] ?? 0) as int;
      }
    }

    final reviewsSnapshot = await _firestoreService.reviews
        .where('supplierId', isEqualTo: supplierId)
        .get();

    double totalRating = 0;
    for (final doc in reviewsSnapshot.docs) {
      totalRating += (doc.data())['rating'] ?? 0;
    }

    final avgRating = reviewsSnapshot.docs.isNotEmpty
        ? totalRating / reviewsSnapshot.docs.length
        : 0.0;

    return {
      'totalBookings': totalBookings,
      'completedBookings': completedBookings,
      'totalRevenue': totalRevenue,
      'totalReviews': reviewsSnapshot.docs.length,
      'averageRating': avgRating,
    };
  }
}
