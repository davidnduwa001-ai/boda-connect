/// Script to verify and update supplier data for testing
///
/// This script helps ensure suppliers appear correctly on client home screen
/// Run this from Firebase Functions or Flutter app initialization

import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierDataVerification {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Verify all suppliers have required fields
  Future<void> verifyAllSuppliers() async {
    print('🔍 Checking all suppliers...\n');

    final snapshot = await _db.collection('suppliers').get();

    if (snapshot.docs.isEmpty) {
      print('❌ NO SUPPLIERS FOUND in Firestore!');
      print('   → You need to create at least one supplier first\n');
      return;
    }

    print('✅ Found ${snapshot.docs.length} supplier(s)\n');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final issues = <String>[];

      // Check required fields
      if (data['isActive'] != true) {
        issues.add('isActive is not true');
      }
      if (data['businessName'] == null || (data['businessName'] as String).isEmpty) {
        issues.add('businessName is missing');
      }
      if (data['category'] == null) {
        issues.add('category is missing');
      }
      if (data['rating'] == null || (data['rating'] as num) == 0) {
        issues.add('rating is 0 or missing');
      }

      // Check for featured
      final isFeatured = data['isFeatured'] == true;

      // Print status
      print('📋 Supplier: ${data['businessName'] ?? doc.id}');
      print('   ID: ${doc.id}');
      print('   Active: ${data['isActive']}');
      print('   Featured: $isFeatured ${!isFeatured ? '(won\'t appear in Destaques)' : ''}');
      print('   Rating: ${data['rating'] ?? 0}');
      print('   Category: ${data['category'] ?? 'N/A'}');
      print('   Photos: ${(data['photos'] as List?)?.length ?? 0}');

      if (issues.isNotEmpty) {
        print('   ⚠️  ISSUES:');
        for (final issue in issues) {
          print('      - $issue');
        }
      } else {
        print('   ✅ All required fields OK');
      }
      print('');
    }
  }

  /// Update a specific supplier to make it appear on client home
  Future<void> makeSupplierVisible(String supplierId, {
    bool featured = true,
    double rating = 4.5,
  }) async {
    print('📝 Updating supplier $supplierId...\n');

    try {
      await _db.collection('suppliers').doc(supplierId).update({
        'isActive': true,
        'isFeatured': featured,
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Supplier updated successfully');
      print('   - isActive: true');
      print('   - isFeatured: $featured');
      print('   - rating: $rating');
      print('');
      print('🎉 Supplier should now appear on client home!');
      if (featured) {
        print('   → Will appear in "Destaques" section');
      }
      print('   → Will appear in "Perto de si" section\n');
    } catch (e) {
      print('❌ Error updating supplier: $e\n');
    }
  }

  /// Find supplier by business name
  Future<String?> findSupplierIdByName(String businessName) async {
    final snapshot = await _db.collection('suppliers')
        .where('businessName', isEqualTo: businessName)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      print('❌ Supplier "$businessName" not found\n');
      return null;
    }

    final doc = snapshot.docs.first;
    print('✅ Found supplier: ${doc.data()['businessName']}');
    print('   ID: ${doc.id}\n');
    return doc.id;
  }

  /// Find supplier by user ID
  Future<String?> findSupplierIdByUserId(String userId) async {
    final snapshot = await _db.collection('suppliers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      print('❌ Supplier for user "$userId" not found\n');
      return null;
    }

    final doc = snapshot.docs.first;
    print('✅ Found supplier: ${doc.data()['businessName']}');
    print('   ID: ${doc.id}\n');
    return doc.id;
  }

  /// Create missing indexes reminder
  void printRequiredIndexes() {
    print('📊 Required Firestore Indexes:\n');
    print('1. Featured Suppliers Index:');
    print('   Collection: suppliers');
    print('   Fields:');
    print('     - isActive (Ascending)');
    print('     - isFeatured (Ascending)');
    print('     - rating (Descending)\n');

    print('2. General Suppliers Index:');
    print('   Collection: suppliers');
    print('   Fields:');
    print('     - isActive (Ascending)');
    print('     - rating (Descending)\n');

    print('3. Category Filter Index:');
    print('   Collection: suppliers');
    print('   Fields:');
    print('     - isActive (Ascending)');
    print('     - category (Ascending)');
    print('     - rating (Descending)\n');

    print('📝 Create these in: Firebase Console → Firestore → Indexes\n');
  }

  /// Quick fix for David supplier
  Future<void> fixDavidSupplier() async {
    print('🔧 Looking for David\'s supplier...\n');

    // Try to find by business name
    String? supplierId = await findSupplierIdByName('David');

    // If not found by name, you can manually set the ID here
    supplierId ??= 'YOUR_SUPPLIER_ID_HERE'; // Replace with actual ID

    if (supplierId == 'YOUR_SUPPLIER_ID_HERE') {
      print('⚠️  Please update the script with David\'s actual supplier ID');
      print('   Or run findSupplierIdByUserId(\'davidUserId\') first\n');
      return;
    }

    await makeSupplierVisible(supplierId, featured: true, rating: 4.8);
  }
}

/// Example usage:
///
/// ```dart
/// // In your app initialization or as a one-time script
/// Future<void> runVerification() async {
///   final verifier = SupplierDataVerification();
///
///   // Check all suppliers
///   await verifier.verifyAllSuppliers();
///
///   // Fix David's supplier
///   await verifier.fixDavidSupplier();
///
///   // Or update specific supplier
///   // await verifier.makeSupplierVisible('supplierId123', featured: true);
///
///   // Print required indexes
///   verifier.printRequiredIndexes();
/// }
/// ```
///
/// To run this script:
/// 1. Import it in your main.dart or a test file
/// 2. Call runVerification() once
/// 3. Check the console output
/// 4. Update supplier data as needed
