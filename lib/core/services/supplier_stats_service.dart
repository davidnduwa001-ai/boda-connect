import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/supplier_stats_model.dart';

/// Service for tracking and managing supplier statistics
/// Handles all stat updates, view tracking, and real-time counters
class SupplierStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== PROFILE VIEWS (LEADS) ====================

  /// Track a passive profile view (page load)
  /// Returns true if the view was counted (not a duplicate)
  Future<bool> trackProfileView({
    required String supplierId,
    required String viewerId,
    String? source,
  }) async {
    try {
      // Don't track if viewer is the supplier themselves
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      if (supplierDoc.exists) {
        final supplierUserId = supplierDoc.data()?['userId'] as String?;
        if (supplierUserId == viewerId) return false;
      }

      // Check if this viewer has already viewed today (prevent spam)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final existingView = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewerId', isEqualTo: viewerId)
          .where('viewType', isEqualTo: ProfileViewType.passive.name)
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      if (existingView.docs.isNotEmpty) {
        debugPrint('Profile already viewed today by this user');
        return false;
      }

      // Record the view event
      final viewEvent = ProfileViewEvent(
        id: '',
        supplierId: supplierId,
        viewerId: viewerId,
        viewType: ProfileViewType.passive,
        viewedAt: DateTime.now(),
        source: source,
      );

      await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .add(viewEvent.toMap());

      // Increment the viewCount on the supplier document (lightweight counter)
      await _firestore.collection('suppliers').doc(supplierId).update({
        'viewCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Profile view tracked for supplier $supplierId');
      return true;
    } catch (e) {
      debugPrint('Error tracking profile view: $e');
      return false;
    }
  }

  /// Track a high-value interaction (contact click, first message, etc.)
  /// These are counted as "leads" and are more valuable than passive views
  Future<bool> trackHighValueView({
    required String supplierId,
    required String viewerId,
    required ProfileViewType viewType,
    String? source,
  }) async {
    try {
      // Don't track if viewer is the supplier themselves
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      if (supplierDoc.exists) {
        final supplierUserId = supplierDoc.data()?['userId'] as String?;
        if (supplierUserId == viewerId) return false;
      }

      // For high-value views, we track each one but limit duplicates per session
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final existingView = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewerId', isEqualTo: viewerId)
          .where('viewType', isEqualTo: viewType.name)
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      if (existingView.docs.isNotEmpty) {
        debugPrint('High-value interaction already recorded today');
        return false;
      }

      // Record the high-value view event
      final viewEvent = ProfileViewEvent(
        id: '',
        supplierId: supplierId,
        viewerId: viewerId,
        viewType: viewType,
        viewedAt: DateTime.now(),
        source: source,
      );

      await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .add(viewEvent.toMap());

      // Increment leadCount (high-value interactions)
      await _firestore.collection('suppliers').doc(supplierId).update({
        'leadCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('High-value view tracked: ${viewType.name} for supplier $supplierId');
      return true;
    } catch (e) {
      debugPrint('Error tracking high-value view: $e');
      return false;
    }
  }

  /// Track contact button click
  Future<bool> trackContactClick({
    required String supplierId,
    required String viewerId,
  }) => trackHighValueView(
    supplierId: supplierId,
    viewerId: viewerId,
    viewType: ProfileViewType.contactClick,
    source: 'contact_button',
  );

  /// Track first message sent
  Future<bool> trackFirstMessage({
    required String supplierId,
    required String viewerId,
  }) => trackHighValueView(
    supplierId: supplierId,
    viewerId: viewerId,
    viewType: ProfileViewType.firstMessage,
    source: 'chat',
  );

  /// Track WhatsApp click
  Future<bool> trackWhatsAppClick({
    required String supplierId,
    required String viewerId,
  }) => trackHighValueView(
    supplierId: supplierId,
    viewerId: viewerId,
    viewType: ProfileViewType.whatsappClick,
    source: 'whatsapp',
  );

  /// Track call button click
  Future<bool> trackCallClick({
    required String supplierId,
    required String viewerId,
  }) => trackHighValueView(
    supplierId: supplierId,
    viewerId: viewerId,
    viewType: ProfileViewType.callClick,
    source: 'phone',
  );

  // ==================== FAVORITES ====================

  /// Add supplier to favorites and increment counter
  Future<bool> addToFavorites({
    required String supplierId,
    required String userId,
  }) async {
    try {
      final favoriteRef = _firestore
          .collection('favorites')
          .doc('${userId}_$supplierId');

      final existing = await favoriteRef.get();
      if (existing.exists) return true;

      // Use a batch write for atomicity
      final batch = _firestore.batch();

      // Add to favorites collection
      batch.set(favoriteRef, {
        'userId': userId,
        'supplierId': supplierId,
        'createdAt': Timestamp.now(),
      });

      // Also add to user's subcollection for easy listing
      batch.set(
        _firestore.collection('users').doc(userId).collection('favorites').doc(supplierId),
        {
          'supplierId': supplierId,
          'addedAt': Timestamp.now(),
        },
      );

      // Increment supplier's favorite count
      batch.update(
        _firestore.collection('suppliers').doc(supplierId),
        {
          'favoriteCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        },
      );

      await batch.commit();
      debugPrint('Supplier $supplierId added to favorites');
      return true;
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove supplier from favorites and decrement counter
  Future<bool> removeFromFavorites({
    required String supplierId,
    required String userId,
  }) async {
    try {
      final favoriteRef = _firestore
          .collection('favorites')
          .doc('${userId}_$supplierId');

      final existing = await favoriteRef.get();
      if (!existing.exists) return true;

      // Use a batch write for atomicity
      final batch = _firestore.batch();

      // Remove from favorites collection
      batch.delete(favoriteRef);

      // Remove from user's subcollection
      batch.delete(
        _firestore.collection('users').doc(userId).collection('favorites').doc(supplierId),
      );

      // Decrement supplier's favorite count (but don't go below 0)
      batch.update(
        _firestore.collection('suppliers').doc(supplierId),
        {
          'favoriteCount': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        },
      );

      await batch.commit();
      debugPrint('Supplier $supplierId removed from favorites');
      return true;
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      return false;
    }
  }

  /// Get accurate favorite count from favorites collection
  Future<int> getFavoriteCount(String supplierId) async {
    try {
      final count = await _firestore
          .collection('favorites')
          .where('supplierId', isEqualTo: supplierId)
          .count()
          .get();
      return count.count ?? 0;
    } catch (e) {
      debugPrint('Error getting favorite count: $e');
      return 0;
    }
  }

  // ==================== BOOKINGS ====================

  /// Update booking stats when status changes to CONFIRMED/PAID
  /// Call this when a booking is confirmed
  Future<void> onBookingConfirmed(String supplierId) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).update({
        'confirmedBookings': FieldValue.increment(1),
        'totalBookings': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });
      debugPrint('Booking confirmed stats updated for supplier $supplierId');
    } catch (e) {
      debugPrint('Error updating confirmed booking stats: $e');
    }
  }

  /// Update booking stats when status changes to COMPLETED
  /// Call this when a booking/job is completed
  Future<void> onBookingCompleted(String supplierId) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).update({
        'completedBookings': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });
      debugPrint('Booking completed stats updated for supplier $supplierId');
    } catch (e) {
      debugPrint('Error updating completed booking stats: $e');
    }
  }

  /// Recalculate booking stats from actual bookings collection
  /// Use this for periodic sync or when stats seem off
  Future<Map<String, int>> recalculateBookingStats(String supplierId) async {
    try {
      final bookingsRef = _firestore
          .collection('bookings')
          .where('supplierId', isEqualTo: supplierId);

      // Count confirmed bookings (confirmed, paid, inProgress, completed)
      final confirmedCount = await bookingsRef
          .where('status', whereIn: ['confirmed', 'paid', 'inProgress', 'completed'])
          .count()
          .get();

      // Count completed bookings only
      final completedCount = await bookingsRef
          .where('status', isEqualTo: 'completed')
          .count()
          .get();

      // Count total bookings
      final totalCount = await bookingsRef.count().get();

      final stats = {
        'confirmedBookings': confirmedCount.count ?? 0,
        'completedBookings': completedCount.count ?? 0,
        'totalBookings': totalCount.count ?? 0,
      };

      // Update the supplier document with accurate counts
      await _firestore.collection('suppliers').doc(supplierId).update({
        ...stats,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Booking stats recalculated for supplier $supplierId: $stats');
      return stats;
    } catch (e) {
      debugPrint('Error recalculating booking stats: $e');
      return {'confirmedBookings': 0, 'completedBookings': 0, 'totalBookings': 0};
    }
  }

  // ==================== COMPREHENSIVE STATS ====================

  /// Get complete stats for a supplier in a single request
  Future<SupplierStatsModel> getSupplierStats(String supplierId) async {
    try {
      final supplierDoc = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .get();

      if (!supplierDoc.exists) {
        return SupplierStatsModel.empty();
      }

      return SupplierStatsModel.fromFirestore(supplierDoc);
    } catch (e) {
      debugPrint('Error getting supplier stats: $e');
      return SupplierStatsModel.empty();
    }
  }

  /// Stream supplier stats for real-time updates
  Stream<SupplierStatsModel> streamSupplierStats(String supplierId) {
    return _firestore
        .collection('suppliers')
        .doc(supplierId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return SupplierStatsModel.empty();
      return SupplierStatsModel.fromFirestore(doc);
    });
  }

  /// Get detailed view statistics with time breakdowns
  Future<StatsTimePeriod> getViewStats(String supplierId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = today.subtract(const Duration(days: 7));
      final monthAgo = DateTime(now.year, now.month - 1, now.day);

      final viewsRef = _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views');

      // Today's views
      final todayViews = await viewsRef
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .count()
          .get();

      // Week's views
      final weekViews = await viewsRef
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .count()
          .get();

      // Month's views
      final monthViews = await viewsRef
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
          .count()
          .get();

      // Total views
      final totalViews = await viewsRef.count().get();

      return StatsTimePeriod(
        today: todayViews.count ?? 0,
        thisWeek: weekViews.count ?? 0,
        thisMonth: monthViews.count ?? 0,
        total: totalViews.count ?? 0,
      );
    } catch (e) {
      debugPrint('Error getting view stats: $e');
      return const StatsTimePeriod();
    }
  }

  /// Get lead statistics (high-value interactions)
  Future<StatsTimePeriod> getLeadStats(String supplierId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = today.subtract(const Duration(days: 7));
      final monthAgo = DateTime(now.year, now.month - 1, now.day);

      final viewsRef = _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewType', whereIn: [
            ProfileViewType.contactClick.name,
            ProfileViewType.firstMessage.name,
            ProfileViewType.callClick.name,
            ProfileViewType.whatsappClick.name,
          ]);

      // Today's leads
      final todayLeads = await viewsRef
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .count()
          .get();

      // Week's leads
      final weekLeads = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewType', whereIn: [
            ProfileViewType.contactClick.name,
            ProfileViewType.firstMessage.name,
            ProfileViewType.callClick.name,
            ProfileViewType.whatsappClick.name,
          ])
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .count()
          .get();

      // Month's leads
      final monthLeads = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewType', whereIn: [
            ProfileViewType.contactClick.name,
            ProfileViewType.firstMessage.name,
            ProfileViewType.callClick.name,
            ProfileViewType.whatsappClick.name,
          ])
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
          .count()
          .get();

      return StatsTimePeriod(
        today: todayLeads.count ?? 0,
        thisWeek: weekLeads.count ?? 0,
        thisMonth: monthLeads.count ?? 0,
        total: 0, // Total would require a separate query
      );
    } catch (e) {
      debugPrint('Error getting lead stats: $e');
      return const StatsTimePeriod();
    }
  }

  // ==================== SYNC & MAINTENANCE ====================

  /// Check if supplier has zero stats and trigger sync if needed
  /// Returns true if a sync was performed
  Future<bool> syncIfZeroStats(String supplierId) async {
    try {
      final stats = await getSupplierStats(supplierId);

      // Check if all meaningful stats are zero
      final hasZeroStats = stats.viewCount == 0 &&
          stats.leadCount == 0 &&
          stats.favoriteCount == 0 &&
          stats.completedBookings == 0 &&
          stats.totalBookings == 0;

      if (hasZeroStats) {
        debugPrint('Supplier $supplierId has zero stats, triggering sync...');
        await syncAllStats(supplierId);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking/syncing zero stats: $e');
      return false;
    }
  }

  /// Full stats sync - recalculates all counters from source data
  /// Use sparingly as it's resource-intensive
  Future<SupplierStatsModel> syncAllStats(String supplierId) async {
    try {
      // Get supplier document for basic info
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      if (!supplierDoc.exists) return SupplierStatsModel.empty();

      final supplierData = supplierDoc.data()!;

      // Recalculate view count from profile_views collection
      final viewsCount = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewType', isEqualTo: ProfileViewType.passive.name)
          .count()
          .get();

      // Recalculate lead count
      final leadsCount = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('profile_views')
          .where('viewType', whereIn: [
            ProfileViewType.contactClick.name,
            ProfileViewType.firstMessage.name,
            ProfileViewType.callClick.name,
            ProfileViewType.whatsappClick.name,
          ])
          .count()
          .get();

      // Recalculate favorite count
      final favoriteCount = await getFavoriteCount(supplierId);

      // Recalculate booking stats
      final bookingStats = await recalculateBookingStats(supplierId);

      // Update supplier document
      final updates = {
        'viewCount': viewsCount.count ?? 0,
        'leadCount': leadsCount.count ?? 0,
        'favoriteCount': favoriteCount,
        ...bookingStats,
        'updatedAt': Timestamp.now(),
      };

      await _firestore.collection('suppliers').doc(supplierId).update(updates);

      // Return updated stats
      return SupplierStatsModel(
        viewCount: viewsCount.count ?? 0,
        leadCount: leadsCount.count ?? 0,
        favoriteCount: favoriteCount,
        confirmedBookings: bookingStats['confirmedBookings'] ?? 0,
        completedBookings: bookingStats['completedBookings'] ?? 0,
        totalBookings: bookingStats['totalBookings'] ?? 0,
        memberSince: (supplierData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastUpdated: DateTime.now(),
        rating: (supplierData['rating'] as num?)?.toDouble() ?? 5.0,
        reviewCount: (supplierData['reviewCount'] as num?)?.toInt() ?? 0,
        responseRate: (supplierData['responseRate'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('Error syncing all stats: $e');
      return SupplierStatsModel.empty();
    }
  }
}
