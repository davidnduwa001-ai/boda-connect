import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/models/chat_model.dart';
import 'package:boda_connect/core/models/package_model.dart';
import 'package:boda_connect/core/models/review_category_models.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/services/file_upload/file_upload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// ==================== STORAGE SERVICE (Firebase Storage) ====================

/// Upload progress callback
typedef UploadProgressCallback = void Function(double progress, int bytesTransferred, int totalBytes);

/// Image upload result with metadata
class ImageUploadResult {
  final String url;
  final String fileName;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;

  const ImageUploadResult({
    required this.url,
    required this.fileName,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
  });
}

/// Image format for compression (platform-agnostic)
enum ImageFormat { jpeg, png }

/// Image compression settings (web-compatible - no dart:io dependency)
class ImageCompressionSettings {
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final ImageFormat format;

  const ImageCompressionSettings({
    this.maxWidth = 1920,
    this.maxHeight = 1920,
    this.quality = 85,
    this.format = ImageFormat.jpeg,
  });

  /// High quality settings for gallery photos
  static const highQuality = ImageCompressionSettings(
    maxWidth: 2048,
    maxHeight: 2048,
    quality: 90,
  );

  /// Medium quality for general uploads
  static const mediumQuality = ImageCompressionSettings(
    maxWidth: 1280,
    maxHeight: 1280,
    quality: 80,
  );

  /// Low quality for thumbnails
  static const thumbnail = ImageCompressionSettings(
    maxWidth: 400,
    maxHeight: 400,
    quality: 70,
  );

  /// Chat image settings
  static const chatImage = ImageCompressionSettings(
    maxWidth: 1024,
    maxHeight: 1024,
    quality: 75,
  );
}

/// Platform-agnostic Storage Service using XFile
/// Works on both mobile (dart:io) and web (dart:html)
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== OPTIMIZED IMAGE UPLOAD ====================

  /// Compress image bytes using platform helper
  /// On mobile: uses flutter_image_compress
  /// On web: returns original bytes (compression not supported)
  Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    ImageCompressionSettings settings = const ImageCompressionSettings(),
  }) async {
    return await fileUploadHelper.compressImageBytes(
      bytes,
      maxWidth: settings.maxWidth,
      maxHeight: settings.maxHeight,
      quality: settings.quality,
    );
  }

  /// Upload image with compression and progress tracking (XFile version)
  /// This is the primary upload method - works on all platforms
  Future<ImageUploadResult> uploadImageOptimized({
    required XFile file,
    required String storagePath,
    ImageCompressionSettings settings = const ImageCompressionSettings(),
    UploadProgressCallback? onProgress,
    Map<String, String>? customMetadata,
  }) async {
    // Read file as bytes
    final originalBytes = await fileUploadHelper.readAsBytes(file);
    final originalSize = originalBytes.length;

    // Compress image (on mobile) or use original (on web)
    final compressedBytes = await compressImageBytes(originalBytes, settings: settings);
    final compressedSize = compressedBytes.length;

    // Generate unique filename
    final extension = settings.format == ImageFormat.png ? 'png' : 'jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final fullPath = '$storagePath/$fileName';

    // Setup metadata
    final metadata = SettableMetadata(
      contentType: settings.format == ImageFormat.png ? 'image/png' : 'image/jpeg',
      customMetadata: {
        'originalSize': originalSize.toString(),
        'compressedSize': compressedSize.toString(),
        'uploadedAt': DateTime.now().toIso8601String(),
        ...?customMetadata,
      },
    );

    // Upload with progress tracking (using bytes - works on all platforms)
    final ref = _storage.ref().child(fullPath);
    final uploadTask = await fileUploadHelper.uploadBytes(
      ref: ref,
      bytes: compressedBytes,
      metadata: metadata,
    );

    // Track progress
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress, snapshot.bytesTransferred, snapshot.totalBytes);
      });
    }

    // Wait for completion
    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();

    return ImageUploadResult(
      url: url,
      fileName: fileName,
      originalSize: originalSize,
      compressedSize: compressedSize,
      compressionRatio: originalSize > 0 ? (1 - (compressedSize / originalSize)) : 0,
    );
  }

  /// Upload multiple images with progress tracking
  Future<List<ImageUploadResult>> uploadImagesOptimized({
    required List<XFile> files,
    required String storagePath,
    ImageCompressionSettings settings = const ImageCompressionSettings(),
    void Function(int current, int total, double fileProgress)? onProgress,
  }) async {
    final results = <ImageUploadResult>[];

    for (int i = 0; i < files.length; i++) {
      final result = await uploadImageOptimized(
        file: files[i],
        storagePath: storagePath,
        settings: settings,
        onProgress: (progress, bytes, total) {
          onProgress?.call(i + 1, files.length, progress);
        },
      );
      results.add(result);
    }

    return results;
  }

  // ==================== CONVENIENCE UPLOAD METHODS ====================

  /// Upload chat image
  Future<String> uploadChatImage(String chatId, XFile file) async {
    final result = await uploadImageOptimized(
      file: file,
      storagePath: 'chats/$chatId',
      settings: ImageCompressionSettings.chatImage,
    );
    return result.url;
  }

  /// Upload supplier photos (multiple)
  Future<List<String>> uploadSupplierPhotos(
    String supplierId,
    List<XFile> files, {
    Function(int, int)? onProgress,
  }) async {
    final results = await uploadImagesOptimized(
      files: files,
      storagePath: 'suppliers/$supplierId/photos',
      settings: ImageCompressionSettings.highQuality,
      onProgress: (current, total, progress) {
        onProgress?.call(current, total);
      },
    );
    return results.map((r) => r.url).toList();
  }

  /// Upload single supplier photo
  Future<String> uploadSupplierPhoto(String supplierId, XFile file) async {
    final result = await uploadImageOptimized(
      file: file,
      storagePath: 'suppliers/$supplierId/photos',
      settings: ImageCompressionSettings.highQuality,
    );
    return result.url;
  }

  /// Upload supplier video
  Future<String> uploadSupplierVideo(
    String supplierId,
    XFile file, {
    UploadProgressCallback? onProgress,
  }) async {
    final bytes = await fileUploadHelper.readAsBytes(file);
    final originalName = file.name;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$originalName';
    final ref = _storage.ref().child('suppliers/$supplierId/videos/$fileName');

    final metadata = SettableMetadata(
      contentType: 'video/mp4',
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final uploadTask = await fileUploadHelper.uploadBytes(
      ref: ref,
      bytes: bytes,
      metadata: metadata,
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress, snapshot.bytesTransferred, snapshot.totalBytes);
      });
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload package photo
  Future<String> uploadPackagePhoto(String packageId, XFile file) async {
    final result = await uploadImageOptimized(
      file: file,
      storagePath: 'packages/$packageId/photos',
      settings: ImageCompressionSettings.highQuality,
    );
    return result.url;
  }

  /// Upload user profile photo
  Future<String> uploadProfilePhoto(String userId, XFile file) async {
    final result = await uploadImageOptimized(
      file: file,
      storagePath: 'users/$userId/profile',
      settings: ImageCompressionSettings.mediumQuality,
    );
    return result.url;
  }

  /// Generate thumbnail for image
  Future<String> uploadThumbnail({
    required XFile file,
    required String storagePath,
  }) async {
    final result = await uploadImageOptimized(
      file: file,
      storagePath: '$storagePath/thumbnails',
      settings: ImageCompressionSettings.thumbnail,
    );
    return result.url;
  }

  /// Upload raw bytes directly (for generated content)
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String storagePath,
    required String fileName,
    String contentType = 'application/octet-stream',
    Map<String, String>? customMetadata,
  }) async {
    final fullPath = '$storagePath/$fileName';
    final ref = _storage.ref().child(fullPath);

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        ...?customMetadata,
      },
    );

    final uploadTask = await fileUploadHelper.uploadBytes(
      ref: ref,
      bytes: bytes,
      metadata: metadata,
    );

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Delete file by URL
  Future<void> deleteFileByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  /// Delete multiple files
  Future<void> deleteFiles(List<String> urls) async {
    for (final url in urls) {
      await deleteFileByUrl(url);
    }
  }

  /// Get file metadata
  Future<FullMetadata?> getFileMetadata(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      return await ref.getMetadata();
    } catch (e) {
      debugPrint('Error getting file metadata: $e');
      return null;
    }
  }
}

// ==================== FIRESTORE SERVICE ====================

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get users => _db.collection('users');
  CollectionReference get suppliers => _db.collection('suppliers');
  CollectionReference get packages => _db.collection('packages');
  CollectionReference get bookings => _db.collection('bookings');
  CollectionReference get reviews => _db.collection('reviews');
  CollectionReference get chats => _db.collection('chats');
  CollectionReference get favorites => _db.collection('favorites');
  CollectionReference get categories => _db.collection('categories');
  CollectionReference get notifications => _db.collection('notifications');

  // ==================== SUPPLIERS ====================

  /// Create supplier profile
  Future<String> createSupplier(SupplierModel supplier) async {
    final docRef = await suppliers.add(supplier.toFirestore());
    return docRef.id;
  }

  /// Get supplier by ID
  Future<SupplierModel?> getSupplier(String id) async {
    final doc = await suppliers.doc(id).get();
    if (!doc.exists) return null;
    return SupplierModel.fromFirestore(doc);
  }

  /// Get supplier by user ID
  Future<SupplierModel?> getSupplierByUserId(String userId) async {
    final query =
        await suppliers.where('userId', isEqualTo: userId).limit(1).get();
    if (query.docs.isEmpty) return null;
    return SupplierModel.fromFirestore(query.docs.first);
  }

  /// Update supplier
  Future<void> updateSupplier(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await suppliers.doc(id).update(data);
  }

  /// Get all suppliers (paginated)
  Future<List<SupplierModel>> getSuppliers({
    String? category,
    String? city,
    double? minRating,
    bool? isVerified,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = suppliers
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    if (city != null) {
      query = query.where('location.city', isEqualTo: city);
    }
    if (minRating != null) {
      query = query.where('rating', isGreaterThanOrEqualTo: minRating);
    }
    if (isVerified != null) {
      query = query.where('isVerified', isEqualTo: isVerified);
    }

    query = query.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => SupplierModel.fromFirestore(doc))
        .toList();
  }

  /// Get featured suppliers
  Future<List<SupplierModel>> getFeaturedSuppliers({int limit = 10}) async {
    final snapshot = await suppliers
        .where('isActive', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SupplierModel.fromFirestore(doc))
        .toList();
  }

  /// Search suppliers with optional filters
  /// Uses multiple search strategies for better results:
  /// 1. Exact prefix match on businessName
  /// 2. Case-insensitive match on businessNameLower
  /// 3. Category/subcategory matching
  /// 4. Keyword search in searchKeywords array
  Future<List<SupplierModel>> searchSuppliers(
    String query, {
    double? minRating,
    String? city,
  }) async {
    final queryLower = query.toLowerCase().trim();
    final queryCapitalized = query.trim().isNotEmpty
        ? '${query.trim()[0].toUpperCase()}${query.trim().substring(1).toLowerCase()}'
        : '';

    // Strategy 1: Try prefix search on businessName (original case)
    var results = <SupplierModel>[];

    try {
      final snapshot1 = await suppliers
          .where('isActive', isEqualTo: true)
          .orderBy('businessName')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(30)
          .get();

      results.addAll(snapshot1.docs
          .map((doc) => SupplierModel.fromFirestore(doc)));
    } catch (e) {
      debugPrint('Search strategy 1 failed: $e');
    }

    // Strategy 2: Try with capitalized query (common format)
    if (results.length < 10 && queryCapitalized.isNotEmpty && queryCapitalized != query) {
      try {
        final snapshot2 = await suppliers
            .where('isActive', isEqualTo: true)
            .orderBy('businessName')
            .startAt([queryCapitalized])
            .endAt(['$queryCapitalized\uf8ff'])
            .limit(30)
            .get();

        // Add only suppliers not already in results
        final existingIds = results.map((s) => s.id).toSet();
        results.addAll(snapshot2.docs
            .map((doc) => SupplierModel.fromFirestore(doc))
            .where((s) => !existingIds.contains(s.id)));
      } catch (e) {
        debugPrint('Search strategy 2 failed: $e');
      }
    }

    // Strategy 3: Search by category name
    if (results.length < 10) {
      try {
        final categorySnapshot = await suppliers
            .where('isActive', isEqualTo: true)
            .where('category', isGreaterThanOrEqualTo: queryCapitalized)
            .where('category', isLessThanOrEqualTo: '$queryCapitalized\uf8ff')
            .limit(20)
            .get();

        final existingIds = results.map((s) => s.id).toSet();
        results.addAll(categorySnapshot.docs
            .map((doc) => SupplierModel.fromFirestore(doc))
            .where((s) => !existingIds.contains(s.id)));
      } catch (e) {
        debugPrint('Search strategy 3 (category) failed: $e');
      }
    }

    // Strategy 4: Search in searchKeywords array (if the field exists)
    if (results.length < 10) {
      try {
        final keywordSnapshot = await suppliers
            .where('isActive', isEqualTo: true)
            .where('searchKeywords', arrayContains: queryLower)
            .limit(20)
            .get();

        final existingIds = results.map((s) => s.id).toSet();
        results.addAll(keywordSnapshot.docs
            .map((doc) => SupplierModel.fromFirestore(doc))
            .where((s) => !existingIds.contains(s.id)));
      } catch (e) {
        debugPrint('Search strategy 4 (keywords) failed: $e');
      }
    }

    // Strategy 5: If still no results, do a broader search and filter client-side
    if (results.isEmpty) {
      try {
        final allActiveSnapshot = await suppliers
            .where('isActive', isEqualTo: true)
            .orderBy('rating', descending: true)
            .limit(100)
            .get();

        results = allActiveSnapshot.docs
            .map((doc) => SupplierModel.fromFirestore(doc))
            .where((supplier) {
              // Case-insensitive search across multiple fields
              final businessNameMatch = supplier.businessName.toLowerCase().contains(queryLower);
              final categoryMatch = supplier.category.toLowerCase().contains(queryLower);
              final subcategoryMatch = supplier.subcategories.any(
                (sub) => sub.toLowerCase().contains(queryLower)
              );
              final descriptionMatch = supplier.description.toLowerCase().contains(queryLower);
              final cityMatch = supplier.location?.city?.toLowerCase().contains(queryLower) ?? false;

              return businessNameMatch || categoryMatch || subcategoryMatch ||
                     descriptionMatch || cityMatch;
            })
            .toList();
      } catch (e) {
        debugPrint('Search strategy 5 (client-side) failed: $e');
      }
    }

    // Apply filters client-side (Firestore limitation with prefix queries)
    if (minRating != null && minRating > 0) {
      results = results.where((s) => s.rating >= minRating).toList();
    }
    if (city != null && city.isNotEmpty) {
      results = results.where((s) => s.location?.city == city).toList();
    }

    // Sort by relevance (exact matches first, then by rating)
    results.sort((a, b) {
      // Prioritize exact business name prefix match
      final aExact = a.businessName.toLowerCase().startsWith(queryLower);
      final bExact = b.businessName.toLowerCase().startsWith(queryLower);
      if (aExact && !bExact) return -1;
      if (bExact && !aExact) return 1;

      // Then sort by rating
      return b.rating.compareTo(a.rating);
    });

    return results.take(20).toList();
  }

  /// CATEGORY-STRICT Search
  /// Only returns suppliers from a specific category - no cross-category pollution
  /// Use this when a category filter is explicitly selected
  Future<List<SupplierModel>> searchSuppliersInCategory(
    String query,
    String category, {
    double? minRating,
    String? city,
  }) async {
    final queryLower = query.toLowerCase().trim();
    var results = <SupplierModel>[];

    // Get all suppliers in the exact category first
    try {
      final categorySnapshot = await suppliers
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category) // STRICT category match
          .orderBy('rating', descending: true)
          .limit(50)
          .get();

      results = categorySnapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc))
          .toList();

      // Filter by search query within category
      if (query.isNotEmpty) {
        results = results.where((supplier) {
          final businessNameMatch = supplier.businessName.toLowerCase().contains(queryLower);
          final subcategoryMatch = supplier.subcategories.any(
            (sub) => sub.toLowerCase().contains(queryLower)
          );
          final descriptionMatch = supplier.description.toLowerCase().contains(queryLower);

          return businessNameMatch || subcategoryMatch || descriptionMatch;
        }).toList();
      }
    } catch (e) {
      debugPrint('Category-strict search failed: $e');
    }

    // Apply additional filters
    if (minRating != null && minRating > 0) {
      results = results.where((s) => s.rating >= minRating).toList();
    }
    if (city != null && city.isNotEmpty) {
      results = results.where((s) => s.location?.city == city).toList();
    }

    // Sort by relevance within category
    results.sort((a, b) {
      if (query.isNotEmpty) {
        final aExact = a.businessName.toLowerCase().startsWith(queryLower);
        final bExact = b.businessName.toLowerCase().startsWith(queryLower);
        if (aExact && !bExact) return -1;
        if (bExact && !aExact) return 1;
      }
      return b.rating.compareTo(a.rating);
    });

    return results.take(20).toList();
  }

  // ==================== PACKAGES ====================

  /// Create package
  Future<String> createPackage(PackageModel package) async {
    final docRef = await packages.add(package.toFirestore());
    return docRef.id;
  }

  /// Get package by ID
  Future<PackageModel?> getPackage(String id) async {
    final doc = await packages.doc(id).get();
    if (!doc.exists) return null;
    return PackageModel.fromFirestore(doc);
  }

  /// Get packages for supplier
  Future<List<PackageModel>> getSupplierPackages(String supplierId) async {
    final snapshot = await packages
        .where('supplierId', isEqualTo: supplierId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => PackageModel.fromFirestore(doc)).toList();
  }

  /// Update package
  Future<void> updatePackage(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await packages.doc(id).update(data);
  }

  /// Delete package (soft delete)
  Future<void> deletePackage(String id) async {
    await packages.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.now(),
    });
  }

  // ==================== BOOKINGS ====================

  /// Create booking
  ///
  /// ⚠️ DEPRECATED: This method will fail with permission-denied error.
  /// Firestore security rules block direct client writes to bookings collection.
  /// Use BookingRepository.createBooking() which calls the createBooking Cloud Function.
  @Deprecated('Use BookingRepository.createBooking() instead - direct writes blocked by security rules')
  Future<String> createBooking(BookingModel booking) async {
    final docRef = await bookings.add(booking.toFirestore());
    return docRef.id;
  }

  /// Get booking by ID
  Future<BookingModel?> getBooking(String id) async {
    final doc = await bookings.doc(id).get();
    if (!doc.exists) return null;
    return BookingModel.fromFirestore(doc);
  }

  /// Get client bookings
  Future<List<BookingModel>> getClientBookings(
    String clientId, {
    List<BookingStatus>? statuses,
  }) async {
    Query query = bookings
        .where('clientId', isEqualTo: clientId)
        .orderBy('eventDate', descending: true);

    if (statuses != null && statuses.isNotEmpty) {
      query =
          query.where('status', whereIn: statuses.map((s) => s.name).toList());
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  /// Get supplier bookings
  Future<List<BookingModel>> getSupplierBookings(
    String supplierId, {
    List<BookingStatus>? statuses,
  }) async {
    Query query = bookings
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('eventDate', descending: true);

    if (statuses != null && statuses.isNotEmpty) {
      query =
          query.where('status', whereIn: statuses.map((s) => s.name).toList());
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  /// Update booking status
  ///
  /// ⚠️ DEPRECATED: This method will fail with permission-denied error.
  /// Firestore security rules block direct client writes to bookings collection.
  /// Use the updateBookingStatus Cloud Function instead.
  @Deprecated('Use updateBookingStatus Cloud Function instead - direct writes blocked by security rules')
  Future<void> updateBookingStatus(
    String id,
    BookingStatus status, {
    String? reason,
    String? cancelledBy,
  }) async {
    final data = <String, dynamic>{
      'status': status.name,
      'updatedAt': Timestamp.now(),
    };

    switch (status) {
      case BookingStatus.confirmed:
        data['confirmedAt'] = Timestamp.now();
        break;
      case BookingStatus.completed:
        data['completedAt'] = Timestamp.now();
        break;
      case BookingStatus.cancelled:
        data['cancelledAt'] = Timestamp.now();
        data['cancellationReason'] = reason;
        data['cancelledBy'] = cancelledBy;
        break;
      default:
        break;
    }

    await bookings.doc(id).update(data);
  }

  /// Add payment to booking
  ///
  /// ⚠️ DEPRECATED: This method will fail with permission-denied error.
  /// Firestore security rules block direct client writes to bookings collection.
  /// Use the addPayment Cloud Function instead.
  @Deprecated('Use addPayment Cloud Function instead - direct writes blocked by security rules')
  Future<void> addBookingPayment(
      String bookingId, BookingPayment payment) async {
    await bookings.doc(bookingId).update({
      'payments': FieldValue.arrayUnion([payment.toMap()]),
      'paidAmount': FieldValue.increment(payment.amount),
      'updatedAt': Timestamp.now(),
    });
  }

  // ==================== REVIEWS ====================

  /// Create review
  ///
  /// ⚠️ DEPRECATED: This method will fail with permission-denied error.
  /// Firestore security rules block direct client writes to reviews collection.
  /// Use BookingRepository.createReview() which calls the createReview Cloud Function.
  @Deprecated('Use BookingRepository.createReview() instead - direct writes blocked by security rules')
  Future<String> createReview(ReviewModel review) async {
    final docRef = await reviews.add(review.toFirestore());

    // Update supplier rating
    await _updateSupplierRating(review.supplierId);

    return docRef.id;
  }

  /// Get supplier reviews
  Future<List<ReviewModel>> getSupplierReviews(
    String supplierId, {
    int limit = 20,
  }) async {
    final snapshot = await reviews
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
  }

  /// Add supplier reply to review
  Future<void> addSupplierReply(String reviewId, String reply) async {
    await reviews.doc(reviewId).update({
      'supplierReply': reply,
      'supplierReplyAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Update supplier rating (called after new review)
  Future<void> _updateSupplierRating(String supplierId) async {
    final snapshot =
        await reviews.where('supplierId', isEqualTo: supplierId).get();

    if (snapshot.docs.isEmpty) return;

    double totalRating = 0;
    for (final doc in snapshot.docs) {
      totalRating += (doc.data()! as Map<String, dynamic>)['rating'] ?? 0;
    }

    final averageRating = totalRating / snapshot.docs.length;

    await suppliers.doc(supplierId).update({
      'rating': averageRating,
      'reviewCount': snapshot.docs.length,
      'updatedAt': Timestamp.now(),
    });
  }

  // ==================== CHATS ====================

  /// Create or get existing chat
  Future<String> getOrCreateChat({
    required String clientId,
    required String supplierId,
    String? clientName,
    String? supplierName,
  }) async {
    // Check if chat exists
    final existing = await chats
        .where('clientId', isEqualTo: clientId)
        .where('supplierId', isEqualTo: supplierId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // Create new chat
    final now = DateTime.now();
    final chat = ChatModel(
      id: '',
      participants: [clientId, supplierId],
      clientId: clientId,
      supplierId: supplierId,
      clientName: clientName,
      supplierName: supplierName,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await chats.add(chat.toFirestore());
    return docRef.id;
  }

  /// Get user chats
  Stream<List<ChatModel>> getUserChats(String userId) {
    return chats
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList());
  }

  /// Send message
  Future<String> sendMessage(MessageModel message) async {
    // Add message to subcollection
    final messagesRef = chats.doc(message.chatId).collection('messages');
    final docRef = await messagesRef.add(message.toFirestore());

    // Update chat with last message
    await chats.doc(message.chatId).update({
      'lastMessage': message.text ?? '[${message.type.name}]',
      'lastMessageAt': Timestamp.now(),
      'lastMessageSenderId': message.senderId,
      'updatedAt': Timestamp.now(),
      // Increment unread count for other participant
      'unreadCount.${message.senderId == message.chatId.split('_').first ? message.chatId.split('_').last : message.chatId.split('_').first}':
          FieldValue.increment(1),
    });

    return docRef.id;
  }

  /// Get chat messages
  Stream<List<MessageModel>> getChatMessages(String chatId, {int limit = 50}) {
    return chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    // Reset unread count for user
    await chats.doc(chatId).update({
      'unreadCount.$userId': 0,
    });

    // Mark individual messages as read (batch update)
    final unreadMessages = await chats
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  // ==================== FAVORITES ====================

  /// Add to favorites
  Future<void> addFavorite(String clientId, String supplierId) async {
    final id = FavoriteModel.generateId(clientId, supplierId);
    final favorite = FavoriteModel(
      id: id,
      clientId: clientId,
      supplierId: supplierId,
      createdAt: DateTime.now(),
    );
    await favorites.doc(id).set(favorite.toFirestore());
  }

  /// Remove from favorites
  Future<void> removeFavorite(String clientId, String supplierId) async {
    final id = FavoriteModel.generateId(clientId, supplierId);
    await favorites.doc(id).delete();
  }

  /// Check if supplier is favorite
  Future<bool> isFavorite(String clientId, String supplierId) async {
    final id = FavoriteModel.generateId(clientId, supplierId);
    final doc = await favorites.doc(id).get();
    return doc.exists;
  }

  /// Get user favorites
  Future<List<String>> getUserFavorites(String clientId) async {
    final snapshot =
        await favorites.where('clientId', isEqualTo: clientId).get();
    return snapshot.docs
        .map((doc) =>
            (doc.data()! as Map<String, dynamic>)['supplierId'] as String)
        .toList();
  }

  // ==================== CATEGORIES ====================

  /// Get all categories
  Future<List<CategoryModel>> getCategories() async {
    final snapshot = await categories
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc))
        .toList();
  }

  /// Initialize default categories (run once)
  Future<void> initializeCategories() async {
    final existing = await categories.limit(1).get();
    if (existing.docs.isNotEmpty) return; // Already initialized

    final batch = _db.batch();
    for (final category in CategoryModel.defaultCategories) {
      final docRef = categories.doc(category.id);
      batch.set(docRef, category.toFirestore());
    }
    await batch.commit();
  }

  // ==================== NOTIFICATIONS ====================

  /// Create notification
  Future<String> createNotification(NotificationModel notification) async {
    final docRef = await notifications.add(notification.toFirestore());
    return docRef.id;
  }

  /// Get user notifications
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String id) async {
    await notifications.doc(id).update({'isRead': true});
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    final unread = await notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}