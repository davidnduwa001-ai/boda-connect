import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking profile views and engagement analytics
class ProfileViewService {
  static final ProfileViewService _instance = ProfileViewService._internal();
  factory ProfileViewService() => _instance;
  ProfileViewService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record a profile view
  Future<void> recordProfileView({
    required String supplierId,
    String? viewerId,
    String? source, // 'search', 'category', 'direct', 'shared'
  }) async {
    try {
      // Create a profile view record
      await _firestore.collection('profile_views').add({
        'supplierId': supplierId,
        'viewerId': viewerId,
        'source': source ?? 'direct',
        'viewedAt': FieldValue.serverTimestamp(),
      });

      // Increment the view count on the supplier document
      await _firestore.collection('suppliers').doc(supplierId).update({
        'viewCount': FieldValue.increment(1),
      });

      debugPrint('Profile view recorded for supplier: $supplierId');
    } catch (e) {
      debugPrint('Error recording profile view: $e');
    }
  }

  /// Get profile view count for a supplier
  Future<int> getProfileViewCount(String supplierId) async {
    try {
      final doc = await _firestore.collection('suppliers').doc(supplierId).get();
      return (doc.data()?['viewCount'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error getting profile view count: $e');
      return 0;
    }
  }

  /// Get profile view analytics for a supplier (last 30 days)
  Future<ProfileViewAnalytics> getProfileViewAnalytics(String supplierId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('profile_views')
          .where('supplierId', isEqualTo: supplierId)
          .where('viewedAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final views = snapshot.docs;
      final totalViews = views.length;

      // Count unique viewers
      final uniqueViewers = views
          .where((v) => v.data()['viewerId'] != null)
          .map((v) => v.data()['viewerId'] as String)
          .toSet()
          .length;

      // Count views by source
      final viewsBySource = <String, int>{};
      for (final view in views) {
        final source = view.data()['source'] as String? ?? 'direct';
        viewsBySource[source] = (viewsBySource[source] ?? 0) + 1;
      }

      // Calculate daily views for chart
      final dailyViews = <DateTime, int>{};
      for (final view in views) {
        final timestamp = view.data()['viewedAt'] as Timestamp?;
        if (timestamp != null) {
          final date = DateTime(
            timestamp.toDate().year,
            timestamp.toDate().month,
            timestamp.toDate().day,
          );
          dailyViews[date] = (dailyViews[date] ?? 0) + 1;
        }
      }

      return ProfileViewAnalytics(
        totalViews: totalViews,
        uniqueViewers: uniqueViewers,
        viewsBySource: viewsBySource,
        dailyViews: dailyViews,
      );
    } catch (e) {
      debugPrint('Error getting profile view analytics: $e');
      return ProfileViewAnalytics.empty();
    }
  }

  /// Get recent viewers (for supplier dashboard)
  Future<List<RecentViewer>> getRecentViewers(String supplierId, {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('profile_views')
          .where('supplierId', isEqualTo: supplierId)
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get();

      final viewers = <RecentViewer>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final viewerId = data['viewerId'] as String?;
        String? viewerName;

        // Get viewer name if logged in
        if (viewerId != null) {
          final userDoc = await _firestore.collection('users').doc(viewerId).get();
          viewerName = userDoc.data()?['name'] as String?;
        }

        viewers.add(RecentViewer(
          viewerId: viewerId,
          viewerName: viewerName ?? 'Visitante anónimo',
          source: data['source'] as String? ?? 'direct',
          viewedAt: (data['viewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      return viewers;
    } catch (e) {
      debugPrint('Error getting recent viewers: $e');
      return [];
    }
  }
}

/// Profile view analytics model
class ProfileViewAnalytics {
  final int totalViews;
  final int uniqueViewers;
  final Map<String, int> viewsBySource;
  final Map<DateTime, int> dailyViews;

  const ProfileViewAnalytics({
    required this.totalViews,
    required this.uniqueViewers,
    required this.viewsBySource,
    required this.dailyViews,
  });

  factory ProfileViewAnalytics.empty() {
    return const ProfileViewAnalytics(
      totalViews: 0,
      uniqueViewers: 0,
      viewsBySource: {},
      dailyViews: {},
    );
  }

  /// Get view percentage by source
  double sourcePercentage(String source) {
    if (totalViews == 0) return 0;
    return (viewsBySource[source] ?? 0) / totalViews * 100;
  }
}

/// Recent viewer model
class RecentViewer {
  final String? viewerId;
  final String viewerName;
  final String source;
  final DateTime viewedAt;

  const RecentViewer({
    this.viewerId,
    required this.viewerName,
    required this.source,
    required this.viewedAt,
  });
}
