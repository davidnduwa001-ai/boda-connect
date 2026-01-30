import 'package:boda_connect/core/services/file_upload/file_upload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Firebase Functions instance for Cloud Function calls
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  // ==================== GET REVIEWS ====================

  /// Get all reviews where the specified user is being reviewed (reviewedId)
  Future<List<ReviewModel>> getReviewsForUser({
    required String userId,
    String? userType, // 'client' or 'supplier' - optional filter
    int limit = 50,
  }) async {
    try {
      var query = _firestore
          .collection('reviews')
          .where('reviewedId', isEqualTo: userId)
          .where('status', isEqualTo: ReviewStatus.approved.name);

      if (userType != null) {
        query = query.where('reviewedType', isEqualTo: userType);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching reviews for user: $e');
      return [];
    }
  }

  /// Get all reviews for a supplier (legacy method for backward compatibility)
  Future<List<ReviewModel>> getSupplierReviews(String supplierId, {int limit = 50}) async {
    return getReviewsForUser(userId: supplierId, userType: 'supplier', limit: limit);
  }

  /// Get reviews stream for real-time updates
  Stream<List<ReviewModel>> getReviewsStreamForUser({
    required String userId,
    String? userType,
    int limit = 50,
  }) {
    var query = _firestore
        .collection('reviews')
        .where('reviewedId', isEqualTo: userId)
        .where('status', isEqualTo: ReviewStatus.approved.name);

    if (userType != null) {
      query = query.where('reviewedType', isEqualTo: userType);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    });
  }

  /// Get reviews stream for a supplier (legacy method)
  Stream<List<ReviewModel>> getSupplierReviewsStream(String supplierId, {int limit = 50}) {
    return getReviewsStreamForUser(userId: supplierId, userType: 'supplier', limit: limit);
  }

  /// Get reviews created by a specific user (reviews they left)
  Future<List<ReviewModel>> getReviewsByUser({
    required String userId,
    String? userType, // Type of user who LEFT the review
    int limit = 50,
  }) async {
    try {
      var query = _firestore
          .collection('reviews')
          .where('reviewerId', isEqualTo: userId);

      if (userType != null) {
        query = query.where('reviewerType', isEqualTo: userType);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching reviews by user: $e');
      return [];
    }
  }

  /// Get reviews by a specific client (legacy - reviews they left)
  Future<List<ReviewModel>> getClientReviews(String clientId, {int limit = 50}) async {
    return getReviewsByUser(userId: clientId, userType: 'client', limit: limit);
  }

  /// Get all reviews for a specific booking (both client and supplier reviews)
  Future<List<ReviewModel>> getBookingReviews(String bookingId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .get();

      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching booking reviews: $e');
      return [];
    }
  }

  /// Get review for a specific booking (legacy - gets first one)
  Future<ReviewModel?> getBookingReview(String bookingId) async {
    try {
      final reviews = await getBookingReviews(bookingId);
      return reviews.isNotEmpty ? reviews.first : null;
    } catch (e) {
      debugPrint('❌ Error fetching booking review: $e');
      return null;
    }
  }

  /// Check if a specific user has reviewed a booking
  Future<bool> hasUserReviewedBooking({
    required String bookingId,
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('reviewerId', isEqualTo: userId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking user booking review: $e');
      return false;
    }
  }

  /// Check if a booking has been reviewed (legacy - checks if any review exists)
  Future<bool> hasReviewedBooking(String bookingId) async {
    try {
      final reviews = await getBookingReviews(bookingId);
      return reviews.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking booking review: $e');
      return false;
    }
  }

  // ==================== CREATE REVIEW ====================

  /// Submit a new review via Cloud Function
  /// Cloud Function handles:
  /// - Booking validation (exists, completed status)
  /// - Caller authorization (must be booking's client)
  /// - Duplicate review prevention (idempotency)
  /// - Supplier stats update (rating, reviewCount)
  ///
  /// IMPORTANT: Reviews can ONLY be submitted for COMPLETED bookings
  Future<String?> submitReview({
    required String bookingId,
    required String reviewerId,
    required String reviewerType, // 'client' or 'supplier'
    required String reviewedId,
    required String reviewedType, // 'client' or 'supplier'
    required String serviceCategory,
    required DateTime serviceDate,
    required double rating,
    String? comment,
    List<String>? tags,
    List<XFile>? photoFiles,
  }) async {
    try {
      // Call the createReview Cloud Function for server-side validation
      final callable = _functions.httpsCallable('createReview');

      final result = await callable.call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
        'tags': tags,
      });

      final data = result.data;
      if (data['success'] != true) {
        debugPrint('❌ ${data['error'] ?? 'Failed to submit review'}');
        return null;
      }

      final reviewId = data['reviewId'] as String;
      debugPrint('✅ Review submitted via Cloud Function: $reviewId');
      return reviewId;
    } on FirebaseFunctionsException catch (e) {
      // Handle specific Cloud Function errors with user-friendly messages
      debugPrint('❌ Cloud Function error: ${e.code} - ${e.message}');
      rethrow; // Let caller handle for UI display
    } catch (e) {
      debugPrint('❌ Error submitting review: $e');
      return null;
    }
  }

  /// Legacy method - kept for backward compatibility but routes through CF
  @Deprecated('Use submitReview instead - this method is now a wrapper')
  Future<String?> submitReviewLegacy({
    required String bookingId,
    required String reviewerId,
    required String reviewerType,
    required String reviewedId,
    required String reviewedType,
    required String serviceCategory,
    required DateTime serviceDate,
    required double rating,
    String? comment,
    List<String>? tags,
    List<XFile>? photoFiles,
  }) async {
    return submitReview(
      bookingId: bookingId,
      reviewerId: reviewerId,
      reviewerType: reviewerType,
      reviewedId: reviewedId,
      reviewedType: reviewedType,
      serviceCategory: serviceCategory,
      serviceDate: serviceDate,
      rating: rating,
      comment: comment,
      tags: tags,
      photoFiles: photoFiles,
    );
  }

  // ==================== BOOKING VALIDATION ====================

  /// Validation result for booking review eligibility
  static const List<String> _allowedBookingStatuses = ['completed'];

  /// Review window: Reviews must be submitted within this period after completion
  static const Duration reviewWindowDuration = Duration(days: 30);

  /// Validate that a booking can be reviewed
  Future<_BookingValidationResult> _validateBookingForReview({
    required String bookingId,
    required String reviewerId,
    required String reviewerType,
  }) async {
    try {
      // Get the booking
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        return _BookingValidationResult(
          isValid: false,
          error: 'Reserva não encontrada',
        );
      }

      final bookingData = bookingDoc.data()!;
      final status = bookingData['status'] as String?;
      final clientId = bookingData['clientId'] as String?;
      final supplierId = bookingData['supplierId'] as String?;

      // Check booking status - MUST be completed
      if (status == null || !_allowedBookingStatuses.contains(status)) {
        return _BookingValidationResult(
          isValid: false,
          error: 'Avaliações só podem ser feitas após a conclusão do serviço',
        );
      }

      // Verify the reviewer is part of this booking
      if (reviewerType == 'client' && reviewerId != clientId) {
        return _BookingValidationResult(
          isValid: false,
          error: 'Você não é o cliente desta reserva',
        );
      }

      if (reviewerType == 'supplier' && reviewerId != supplierId) {
        return _BookingValidationResult(
          isValid: false,
          error: 'Você não é o fornecedor desta reserva',
        );
      }

      // Check review window (optional but recommended)
      final completedAt = bookingData['completedAt'];
      if (completedAt != null) {
        final completionDate = completedAt is Timestamp
            ? completedAt.toDate()
            : DateTime.now();
        final daysSinceCompletion = DateTime.now().difference(completionDate).inDays;

        if (daysSinceCompletion > reviewWindowDuration.inDays) {
          // Still allow but flag as late review
          debugPrint('⚠️ Late review: $daysSinceCompletion days after completion');
        }
      }

      return _BookingValidationResult(isValid: true);
    } catch (e) {
      debugPrint('❌ Error validating booking for review: $e');
      return _BookingValidationResult(
        isValid: false,
        error: 'Erro ao validar reserva: $e',
      );
    }
  }

  /// Check if a booking is eligible for review (public method)
  Future<bool> canReviewBooking({
    required String bookingId,
    required String userId,
    required String userType,
  }) async {
    // First check if booking is valid for review
    final validation = await _validateBookingForReview(
      bookingId: bookingId,
      reviewerId: userId,
      reviewerType: userType,
    );

    if (!validation.isValid) return false;

    // Then check if user hasn't already reviewed
    final hasReviewed = await hasUserReviewedBooking(
      bookingId: bookingId,
      userId: userId,
    );

    return !hasReviewed;
  }

  /// Get bookings eligible for review by a user
  Future<List<Map<String, dynamic>>> getBookingsEligibleForReview({
    required String userId,
    required String userType, // 'client' or 'supplier'
  }) async {
    try {
      final field = userType == 'client' ? 'clientId' : 'supplierId';

      // Get completed bookings
      final snapshot = await _firestore
          .collection('bookings')
          .where(field, isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .get();

      final eligibleBookings = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final hasReviewed = await hasUserReviewedBooking(
          bookingId: doc.id,
          userId: userId,
        );

        if (!hasReviewed) {
          final data = doc.data();
          data['id'] = doc.id;
          eligibleBookings.add(data);
        }
      }

      return eligibleBookings;
    } catch (e) {
      debugPrint('❌ Error getting eligible bookings: $e');
      return [];
    }
  }

  /// Check if a user has already reviewed a booking
  Future<ReviewModel?> _getReviewByBookingAndReviewer(String bookingId, String reviewerId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('reviewerId', isEqualTo: reviewerId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ReviewModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking existing review: $e');
      return null;
    }
  }

  /// Upload review photos to Firebase Storage
  Future<List<String>> _uploadReviewPhotos(String bookingId, List<XFile> photos) async {
    final urls = <String>[];

    for (int i = 0; i < photos.length; i++) {
      try {
        final fileName = 'review_${bookingId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = _storage.ref().child('reviews/$bookingId/$fileName');

        final bytes = await fileUploadHelper.readAsBytes(photos[i]);
        await ref.putData(bytes);
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        debugPrint('❌ Error uploading review photo: $e');
      }
    }

    return urls;
  }

  // ==================== UPDATE REVIEW ====================

  /// Update a review (reviewer can edit their own review)
  Future<bool> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? tags,
    List<String>? photos,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rating != null) updates['rating'] = rating;
      if (comment != null) updates['comment'] = comment;
      if (tags != null) updates['tags'] = tags;
      if (photos != null) updates['photos'] = photos;

      await _firestore
          .collection('reviews')
          .doc(reviewId)
          .update(updates);

      // Update reviewed user's rating if rating changed
      if (rating != null) {
        final review = await _firestore.collection('reviews').doc(reviewId).get();
        final reviewedId = review.data()?['reviewedId'] as String?;
        final reviewedType = review.data()?['reviewedType'] as String?;
        if (reviewedId != null && reviewedType != null) {
          await _updateUserRating(reviewedId, reviewedType);
        }
      }

      debugPrint('✅ Review updated: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating review: $e');
      return false;
    }
  }

  // ==================== DELETE REVIEW ====================

  /// Delete a review
  Future<bool> deleteReview(String reviewId) async {
    try {
      // Get reviewed user info before deleting
      final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
      final reviewedId = reviewDoc.data()?['reviewedId'] as String?;
      final reviewedType = reviewDoc.data()?['reviewedType'] as String?;

      await _firestore.collection('reviews').doc(reviewId).delete();

      // Update reviewed user's rating
      if (reviewedId != null && reviewedType != null) {
        await _updateUserRating(reviewedId, reviewedType);
      }

      debugPrint('✅ Review deleted: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting review: $e');
      return false;
    }
  }

  // ==================== RESPONSE TO REVIEW ====================

  /// Add a response to a review (reviewed user can respond)
  Future<bool> addResponse({
    required String reviewId,
    required String response,
  }) async {
    try {
      await _firestore
          .collection('reviews')
          .doc(reviewId)
          .update({
        'response': response,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Response added to review: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding response: $e');
      return false;
    }
  }

  /// Update response to a review
  Future<bool> updateResponse({
    required String reviewId,
    required String response,
  }) async {
    try {
      await _firestore
          .collection('reviews')
          .doc(reviewId)
          .update({
        'response': response,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Response updated: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating response: $e');
      return false;
    }
  }

  /// Delete response to a review
  Future<bool> deleteResponse(String reviewId) async {
    try {
      await _firestore
          .collection('reviews')
          .doc(reviewId)
          .update({
        'response': FieldValue.delete(),
        'respondedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Response deleted: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting response: $e');
      return false;
    }
  }

  // ==================== STATISTICS ====================

  /// Calculate review statistics for a user (supplier or client)
  Future<ReviewStats> getUserStats({
    required String userId,
    required String userType, // 'client' or 'supplier'
  }) async {
    try {
      final reviews = await getReviewsForUser(userId: userId, userType: userType, limit: 1000);

      if (reviews.isEmpty) {
        return const ReviewStats(
          averageRating: 0.0,
          totalReviews: 0,
          ratingDistribution: {},
        );
      }

      // Calculate average rating
      final totalRating = reviews.fold<double>(0.0, (sum, review) => sum + review.rating);
      final averageRating = totalRating / reviews.length;

      // Calculate rating distribution
      final distribution = <int, int>{};
      for (var i = 1; i <= 5; i++) {
        distribution[i] = reviews.where((r) => r.rating.round() == i).length;
      }

      return ReviewStats(
        averageRating: averageRating,
        totalReviews: reviews.length,
        ratingDistribution: distribution,
      );
    } catch (e) {
      debugPrint('❌ Error calculating review stats: $e');
      return const ReviewStats(
        averageRating: 0.0,
        totalReviews: 0,
        ratingDistribution: {},
      );
    }
  }

  /// Calculate review statistics for a supplier (legacy method)
  Future<ReviewStats> getSupplierStats(String supplierId) async {
    return getUserStats(userId: supplierId, userType: 'supplier');
  }

  /// Update user's average rating in their profile
  Future<void> _updateUserRating(String userId, String userType) async {
    try {
      final stats = await getUserStats(userId: userId, userType: userType);

      final collection = userType == 'supplier' ? 'suppliers' : 'users';
      await _firestore.collection(collection).doc(userId).update({
        'rating': stats.averageRating,
        'reviewCount': stats.totalReviews,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ $userType rating updated: $userId (${stats.averageRating.toStringAsFixed(1)})');
    } catch (e) {
      debugPrint('❌ Error updating $userType rating: $e');
    }
  }

  // ==================== MODERATION & FLAGS ====================

  /// Flag a review as inappropriate
  Future<bool> flagReview({
    required String reviewId,
    required String flagReason,
  }) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'isFlagged': true,
        'flagReason': flagReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Review flagged: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error flagging review: $e');
      return false;
    }
  }

  /// Approve a review (change status to approved)
  Future<bool> approveReview(String reviewId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'status': ReviewStatus.approved.name,
        'isPublic': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Review approved: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error approving review: $e');
      return false;
    }
  }

  /// Reject a review (change status to rejected)
  Future<bool> rejectReview(String reviewId, String reason) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'status': ReviewStatus.rejected.name,
        'isPublic': false,
        'flagReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Review rejected: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting review: $e');
      return false;
    }
  }

  /// Dispute a review
  Future<bool> disputeReview(String reviewId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'status': ReviewStatus.disputed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Review disputed: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error disputing review: $e');
      return false;
    }
  }

  /// Resolve a disputed review
  Future<bool> resolveReview(String reviewId, bool approve) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'status': approve ? ReviewStatus.resolved.name : ReviewStatus.rejected.name,
        'isPublic': approve,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Review resolved: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error resolving review: $e');
      return false;
    }
  }

  // ==================== REPORT REVIEW ====================

  /// Report a review as inappropriate
  Future<bool> reportReview({
    required String reviewId,
    required String reportedBy,
    required String reason,
  }) async {
    try {
      await _firestore.collection('reviewReports').add({
        'reviewId': reviewId,
        'reportedBy': reportedBy,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Auto-flag the review
      await flagReview(reviewId: reviewId, flagReason: reason);

      debugPrint('✅ Review reported: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error reporting review: $e');
      return false;
    }
  }
}

// ==================== REVIEW STATS CLASS ====================

class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // 1-5 stars -> count

  const ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  /// Get percentage for a specific star rating (0.0 to 1.0)
  double getRatingPercentage(int stars) {
    if (totalReviews == 0) return 0.0;
    final count = ratingDistribution[stars] ?? 0;
    return count / totalReviews;
  }

  /// Get count for a specific star rating
  int getRatingCount(int stars) {
    return ratingDistribution[stars] ?? 0;
  }
}

// ==================== BOOKING VALIDATION RESULT ====================

/// Internal class for booking validation results
class _BookingValidationResult {
  final bool isValid;
  final String? error;

  const _BookingValidationResult({
    required this.isValid,
    this.error,
  });
}
