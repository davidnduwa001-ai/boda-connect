import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing supplier blocked dates (unavailability)
class BlockedDatesService {
  static final BlockedDatesService _instance = BlockedDatesService._internal();
  factory BlockedDatesService() => _instance;
  BlockedDatesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all blocked dates for a supplier
  Future<List<DateTime>> getBlockedDates(String supplierId) async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['date'] as Timestamp?;
        return timestamp?.toDate() ?? DateTime.now();
      }).toList();
    } catch (e) {
      debugPrint('Error getting blocked dates: $e');
      return [];
    }
  }

  /// Stream blocked dates for real-time updates
  Stream<List<DateTime>> streamBlockedDates(String supplierId) {
    return _firestore
        .collection('suppliers')
        .doc(supplierId)
        .collection('blocked_dates')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['date'] as Timestamp?;
        return timestamp?.toDate() ?? DateTime.now();
      }).toList();
    });
  }

  /// Add a blocked date
  Future<bool> addBlockedDate(String supplierId, DateTime date) async {
    try {
      // Normalize to start of day
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateId = _formatDateId(normalizedDate);

      await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .doc(dateId)
          .set({
        'date': Timestamp.fromDate(normalizedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Blocked date added: $dateId');
      return true;
    } catch (e) {
      debugPrint('Error adding blocked date: $e');
      return false;
    }
  }

  /// Remove a blocked date
  Future<bool> removeBlockedDate(String supplierId, DateTime date) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateId = _formatDateId(normalizedDate);

      await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .doc(dateId)
          .delete();

      debugPrint('Blocked date removed: $dateId');
      return true;
    } catch (e) {
      debugPrint('Error removing blocked date: $e');
      return false;
    }
  }

  /// Toggle a blocked date (add if not blocked, remove if blocked)
  Future<bool> toggleBlockedDate(String supplierId, DateTime date) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateId = _formatDateId(normalizedDate);

      final doc = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .doc(dateId)
          .get();

      if (doc.exists) {
        await removeBlockedDate(supplierId, date);
        return false; // Now unblocked
      } else {
        await addBlockedDate(supplierId, date);
        return true; // Now blocked
      }
    } catch (e) {
      debugPrint('Error toggling blocked date: $e');
      return false;
    }
  }

  /// Check if a date is blocked
  Future<bool> isDateBlocked(String supplierId, DateTime date) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateId = _formatDateId(normalizedDate);

      final doc = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .doc(dateId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking blocked date: $e');
      return false;
    }
  }

  /// Add multiple blocked dates at once
  Future<bool> addBlockedDateRange(
      String supplierId, DateTime startDate, DateTime endDate) async {
    try {
      final batch = _firestore.batch();
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (!currentDate.isAfter(end)) {
        final dateId = _formatDateId(currentDate);
        final docRef = _firestore
            .collection('suppliers')
            .doc(supplierId)
            .collection('blocked_dates')
            .doc(dateId);

        batch.set(docRef, {
          'date': Timestamp.fromDate(currentDate),
          'createdAt': FieldValue.serverTimestamp(),
        });

        currentDate = currentDate.add(const Duration(days: 1));
      }

      await batch.commit();
      debugPrint('Blocked date range added: $startDate to $endDate');
      return true;
    } catch (e) {
      debugPrint('Error adding blocked date range: $e');
      return false;
    }
  }

  /// Clear all blocked dates
  Future<bool> clearAllBlockedDates(String supplierId) async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .collection('blocked_dates')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('All blocked dates cleared');
      return true;
    } catch (e) {
      debugPrint('Error clearing blocked dates: $e');
      return false;
    }
  }

  /// Format date to document ID (YYYY-MM-DD)
  String _formatDateId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
