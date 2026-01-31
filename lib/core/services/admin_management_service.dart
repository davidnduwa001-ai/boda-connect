import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for admin management tasks:
/// - Featured suppliers (Destaques)
/// - User/Supplier verification (badge control)
class AdminManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== FEATURED SUPPLIERS ====================

  /// Set a supplier as featured (appears in Destaques)
  Future<bool> setSupplierFeatured({
    required String supplierId,
    required bool isFeatured,
    required String adminId,
  }) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).update({
        'isFeatured': isFeatured,
        'featuredAt': isFeatured ? Timestamp.now() : null,
        'featuredBy': isFeatured ? adminId : null,
        'updatedAt': Timestamp.now(),
      });

      // Log the action
      await _logAdminAction(
        adminId: adminId,
        action: isFeatured ? 'feature_supplier' : 'unfeature_supplier',
        targetId: supplierId,
        targetType: 'supplier',
      );

      debugPrint('Supplier $supplierId featured status set to $isFeatured');
      return true;
    } catch (e) {
      debugPrint('Error setting supplier featured status: $e');
      return false;
    }
  }

  /// Get all featured suppliers
  Stream<List<Map<String, dynamic>>> streamFeaturedSuppliers() {
    return _firestore
        .collection('suppliers')
        .where('isFeatured', isEqualTo: true)
        .orderBy('featuredAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  /// Get all active suppliers (for admin to select from)
  Future<List<Map<String, dynamic>>> getActiveSuppliers({
    int limit = 50,
    String? searchQuery,
  }) async {
    try {
      Query query = _firestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .orderBy('businessName')
          .limit(limit);

      final snapshot = await query.get();

      var results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Client-side search filter if query provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        results = results.where((s) {
          final name = (s['businessName'] as String? ?? '').toLowerCase();
          final category = (s['category'] as String? ?? '').toLowerCase();
          return name.contains(lowerQuery) || category.contains(lowerQuery);
        }).toList();
      }

      return results;
    } catch (e) {
      debugPrint('Error getting active suppliers: $e');
      return [];
    }
  }

  // ==================== USER VERIFICATION (BADGE) ====================

  /// Verify a supplier (grants the verified badge)
  Future<bool> verifySupplier({
    required String supplierId,
    required bool isVerified,
    required String adminId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).update({
        'isVerified': isVerified,
        'verifiedAt': isVerified ? Timestamp.now() : null,
        'verifiedBy': isVerified ? adminId : null,
        'verificationReason': reason,
        'updatedAt': Timestamp.now(),
      });

      // Log the action
      await _logAdminAction(
        adminId: adminId,
        action: isVerified ? 'verify_supplier' : 'unverify_supplier',
        targetId: supplierId,
        targetType: 'supplier',
        details: reason,
      );

      debugPrint('Supplier $supplierId verification set to $isVerified');
      return true;
    } catch (e) {
      debugPrint('Error setting supplier verification: $e');
      return false;
    }
  }

  /// Verify a client/user (grants the verified badge)
  Future<bool> verifyUser({
    required String userId,
    required bool isVerified,
    required String adminId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isVerified': isVerified,
        'verifiedAt': isVerified ? Timestamp.now() : null,
        'verifiedBy': isVerified ? adminId : null,
        'verificationReason': reason,
        'updatedAt': Timestamp.now(),
      });

      // Log the action
      await _logAdminAction(
        adminId: adminId,
        action: isVerified ? 'verify_user' : 'unverify_user',
        targetId: userId,
        targetType: 'user',
        details: reason,
      );

      debugPrint('User $userId verification set to $isVerified');
      return true;
    } catch (e) {
      debugPrint('Error setting user verification: $e');
      return false;
    }
  }

  /// Get all verified suppliers
  Stream<List<Map<String, dynamic>>> streamVerifiedSuppliers() {
    return _firestore
        .collection('suppliers')
        .where('isVerified', isEqualTo: true)
        .orderBy('verifiedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  /// Get all verified users/clients
  Stream<List<Map<String, dynamic>>> streamVerifiedUsers() {
    return _firestore
        .collection('users')
        .where('isVerified', isEqualTo: true)
        .orderBy('verifiedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  /// Get all users (for admin to select from)
  Future<List<Map<String, dynamic>>> getUsers({
    int limit = 50,
    String? searchQuery,
    String? userType, // 'client', 'supplier', or null for all
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .limit(limit);

      if (userType != null) {
        query = query.where('userType', isEqualTo: userType);
      }

      final snapshot = await query.get();

      var results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Client-side search filter if query provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        results = results.where((u) {
          final name = (u['name'] as String? ?? '').toLowerCase();
          final email = (u['email'] as String? ?? '').toLowerCase();
          final phone = (u['phone'] as String? ?? '').toLowerCase();
          return name.contains(lowerQuery) ||
                 email.contains(lowerQuery) ||
                 phone.contains(lowerQuery);
        }).toList();
      }

      return results;
    } catch (e) {
      debugPrint('Error getting users: $e');
      return [];
    }
  }

  // ==================== ADMIN AUDIT LOG ====================

  Future<void> _logAdminAction({
    required String adminId,
    required String action,
    required String targetId,
    required String targetType,
    String? details,
  }) async {
    try {
      await _firestore.collection('admin_audit_log').add({
        'adminId': adminId,
        'action': action,
        'targetId': targetId,
        'targetType': targetType,
        'details': details,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  /// Get admin audit log
  Stream<List<Map<String, dynamic>>> streamAuditLog({int limit = 100}) {
    return _firestore
        .collection('admin_audit_log')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  // ==================== STATISTICS ====================

  /// Get management statistics
  Future<Map<String, int>> getManagementStats() async {
    try {
      final featuredCount = await _firestore
          .collection('suppliers')
          .where('isFeatured', isEqualTo: true)
          .count()
          .get();

      final verifiedSuppliersCount = await _firestore
          .collection('suppliers')
          .where('isVerified', isEqualTo: true)
          .count()
          .get();

      final verifiedUsersCount = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .count()
          .get();

      final totalSuppliersCount = await _firestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      final totalUsersCount = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      return {
        'featuredSuppliers': featuredCount.count ?? 0,
        'verifiedSuppliers': verifiedSuppliersCount.count ?? 0,
        'verifiedUsers': verifiedUsersCount.count ?? 0,
        'totalSuppliers': totalSuppliersCount.count ?? 0,
        'totalUsers': totalUsersCount.count ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting management stats: $e');
      return {
        'featuredSuppliers': 0,
        'verifiedSuppliers': 0,
        'verifiedUsers': 0,
        'totalSuppliers': 0,
        'totalUsers': 0,
      };
    }
  }
}
