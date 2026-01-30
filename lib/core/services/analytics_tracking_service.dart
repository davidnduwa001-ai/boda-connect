import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking analytics events like profile views, favorites, etc.
class AnalyticsTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track a profile view for a supplier
  Future<void> trackProfileView({
    required String supplierId,
    required String viewerId,
  }) async {
    try {
      // Don't track if viewer is the supplier themselves
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      if (supplierDoc.exists) {
        final supplierUserId = supplierDoc.data()?['userId'] as String?;
        if (supplierUserId == viewerId) return;
      }

      // Check if this viewer has already viewed today (prevent spam)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final existingView = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewerId', isEqualTo: viewerId)
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      if (existingView.docs.isNotEmpty) {
        debugPrint('Profile already viewed today by this user');
        return;
      }

      // Record the view
      await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .add({
        'viewerId': viewerId,
        'viewedAt': Timestamp.now(),
      });

      // Increment the viewCount on the supplier document
      await _firestore.collection('suppliers').doc(supplierId).update({
        'viewCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Profile view tracked for supplier $supplierId');
    } catch (e) {
      debugPrint('Error tracking profile view: $e');
    }
  }

  // Track a package view
  Future<void> trackPackageView({
    required String packageId,
    required String supplierId,
    required String viewerId,
  }) async {
    try {
      // Check if already viewed today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final existingView = await _firestore
          .collection('packages')
          .doc(packageId)
          .collection('views')
          .where('viewerId', isEqualTo: viewerId)
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      if (existingView.docs.isNotEmpty) return;

      // Record the view
      await _firestore
          .collection('packages')
          .doc(packageId)
          .collection('views')
          .add({
        'viewerId': viewerId,
        'supplierId': supplierId,
        'viewedAt': Timestamp.now(),
      });

      debugPrint('Package view tracked for package $packageId');
    } catch (e) {
      debugPrint('Error tracking package view: $e');
    }
  }

  // Add supplier to favorites
  Future<bool> addToFavorites({
    required String supplierId,
    required String userId,
  }) async {
    try {
      // Check if already a favorite
      final existing = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(supplierId)
          .get();

      if (existing.exists) return true;

      // Add to user's favorites
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(supplierId)
          .set({
        'supplierId': supplierId,
        'addedAt': Timestamp.now(),
      });

      // Increment supplier's favorite count
      await _firestore.collection('suppliers').doc(supplierId).update({
        'favoriteCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Supplier $supplierId added to favorites');
      return true;
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      return false;
    }
  }

  // Remove supplier from favorites
  Future<bool> removeFromFavorites({
    required String supplierId,
    required String userId,
  }) async {
    try {
      // Check if exists
      final existing = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(supplierId)
          .get();

      if (!existing.exists) return true;

      // Remove from user's favorites
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(supplierId)
          .delete();

      // Decrement supplier's favorite count
      await _firestore.collection('suppliers').doc(supplierId).update({
        'favoriteCount': FieldValue.increment(-1),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Supplier $supplierId removed from favorites');
      return true;
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      return false;
    }
  }

  // Check if supplier is a favorite
  Future<bool> isFavorite({
    required String supplierId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(supplierId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }

  // Get user's favorite suppliers
  Future<List<String>> getUserFavorites(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting user favorites: $e');
      return [];
    }
  }

  // Get profile view stats for a supplier
  Future<Map<String, int>> getProfileViewStats(String supplierId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = today.subtract(const Duration(days: 7));
      final monthAgo = DateTime(now.year, now.month - 1, now.day);

      // Today's views
      final todayViews = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .count()
          .get();

      // Week's views
      final weekViews = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .count()
          .get();

      // Month's views
      final monthViews = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
          .count()
          .get();

      return {
        'today': todayViews.count ?? 0,
        'week': weekViews.count ?? 0,
        'month': monthViews.count ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting profile view stats: $e');
      return {'today': 0, 'week': 0, 'month': 0};
    }
  }
}
