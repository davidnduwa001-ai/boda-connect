import 'package:boda_connect/core/services/file_upload/file_upload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:boda_connect/core/models/review_category_models.dart';

// ==================== REVIEWS PROVIDER ====================

/// Provider to fetch reviews for a specific supplier
/// Usage: ref.watch(reviewsProvider(supplierId))
final reviewsProvider = FutureProvider.family<List<ReviewModel>, String>((ref, supplierId) async {
  final firestore = FirebaseFirestore.instance;

  try {
    final querySnapshot = await firestore
        .collection('reviews')
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return querySnapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc))
        .toList();
  } catch (e) {
    print('❌ Error loading reviews: $e');
    return [];
  }
});

// ==================== REVIEW STATS PROVIDER ====================

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
}

/// Provider to calculate review statistics for a supplier
/// Usage: ref.watch(reviewStatsProvider(supplierId))
final reviewStatsProvider = FutureProvider.family<ReviewStats, String>((ref, supplierId) async {
  final reviews = await ref.watch(reviewsProvider(supplierId).future);

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
});

// ==================== REVIEW SUBMISSION ====================

class ReviewNotifier extends StateNotifier<AsyncValue<void>> {
  ReviewNotifier() : super(const AsyncValue.data(null));

  Future<String?> submitReview({
    required String bookingId,
    required String clientId,
    required String supplierId,
    String? clientName,
    String? clientPhoto,
    required double rating,
    required String comment,
    List<XFile>? photoFiles,
  }) async {
    state = const AsyncValue.loading();

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // VALIDATE: Booking must exist and be completed before allowing review
      final bookingDoc = await firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Reserva não encontrada');
      }

      final bookingData = bookingDoc.data()!;
      final bookingStatus = bookingData['status'] as String?;

      // Only allow reviews for completed bookings
      if (bookingStatus != 'completed') {
        throw Exception('Só pode avaliar após o serviço ser concluído');
      }

      // Check if review already exists for this booking
      if (bookingData['hasReview'] == true) {
        throw Exception('Já avaliou esta reserva');
      }

      // Validate that the client is the one who made the booking
      if (bookingData['clientId'] != clientId) {
        throw Exception('Não tem permissão para avaliar esta reserva');
      }

      // Upload photos if any
      List<String> photoUrls = [];
      if (photoFiles != null && photoFiles.isNotEmpty) {
        for (int i = 0; i < photoFiles.length; i++) {
          final file = photoFiles[i];
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final ref = storage.ref().child('reviews/$supplierId/$fileName');

          final bytes = await fileUploadHelper.readAsBytes(file);
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          photoUrls.add(url);
        }
      }

      // Create review document
      final reviewData = {
        'bookingId': bookingId,
        'clientId': clientId,
        'supplierId': supplierId,
        'clientName': clientName ?? 'Cliente',
        'clientPhoto': clientPhoto,
        'rating': rating,
        'comment': comment,
        'photos': photoUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isVerified': true, // Since it's from a booking
      };

      final docRef = await firestore.collection('reviews').add(reviewData);

      // Update booking to mark as reviewed
      await firestore.collection('bookings').doc(bookingId).update({
        'hasReview': true,
        'reviewId': docRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update supplier rating stats
      await _updateSupplierRating(supplierId);

      state = const AsyncValue.data(null);
      return docRef.id;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  Future<void> _updateSupplierRating(String supplierId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Fetch all reviews for this supplier
      final reviewsSnapshot = await firestore
          .collection('reviews')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      if (reviewsSnapshot.docs.isEmpty) return;

      // Calculate average rating
      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        totalRating += rating;
      }

      final averageRating = totalRating / reviewsSnapshot.docs.length;
      final reviewCount = reviewsSnapshot.docs.length;

      // Update supplier document
      await firestore.collection('suppliers').doc(supplierId).update({
        'rating': averageRating,
        'reviewCount': reviewCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating supplier rating: $e');
    }
  }
}

final reviewNotifierProvider = StateNotifierProvider<ReviewNotifier, AsyncValue<void>>((ref) {
  return ReviewNotifier();
});
