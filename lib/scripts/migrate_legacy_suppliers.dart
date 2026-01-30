import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';

/// Migration script for legacy supplier documents
///
/// This script ensures all supplier documents have the required fields
/// for the new onboarding workflow:
/// - accountStatus: 'active' for existing suppliers (they were implicitly approved)
/// - identityVerificationStatus: 'pending' (needs verification)
/// - acceptingBookings: true (default enabled)
/// - isActive: true (for active suppliers)
///
/// Run this ONCE during app update deployment
class LegacySupplierMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Run the migration
  /// Returns a MigrationResult with statistics
  Future<MigrationResult> migrate({bool dryRun = false}) async {
    Log.i('Starting legacy supplier migration (dryRun: $dryRun)...');

    int totalSuppliers = 0;
    int migratedSuppliers = 0;
    int skippedSuppliers = 0;
    int errorCount = 0;
    final List<String> errors = [];

    try {
      // Get all suppliers in batches
      QuerySnapshot? lastSnapshot;
      const batchSize = 100;

      do {
        Query query = _firestore.collection('suppliers').limit(batchSize);

        if (lastSnapshot != null && lastSnapshot.docs.isNotEmpty) {
          query = query.startAfterDocument(lastSnapshot.docs.last);
        }

        lastSnapshot = await query.get();

        for (final doc in lastSnapshot.docs) {
          totalSuppliers++;
          final data = doc.data() as Map<String, dynamic>;

          try {
            final updates = _calculateUpdates(data);

            if (updates.isEmpty) {
              skippedSuppliers++;
              Log.d('${doc.id}: Already migrated');
              continue;
            }

            if (dryRun) {
              Log.d('${doc.id}: Would update: ${updates.keys.join(', ')}');
              migratedSuppliers++;
            } else {
              await doc.reference.update(updates);
              Log.success('${doc.id}: Updated: ${updates.keys.join(', ')}');
              migratedSuppliers++;
            }
          } catch (e) {
            errorCount++;
            errors.add('${doc.id}: $e');
            Log.fail('${doc.id}: Error - $e');
          }
        }
      } while (lastSnapshot.docs.length == batchSize);

      Log.i('Migration complete: total=$totalSuppliers, migrated=$migratedSuppliers, skipped=$skippedSuppliers, errors=$errorCount');

      return MigrationResult(
        totalSuppliers: totalSuppliers,
        migratedSuppliers: migratedSuppliers,
        skippedSuppliers: skippedSuppliers,
        errorCount: errorCount,
        errors: errors,
        dryRun: dryRun,
      );
    } catch (e) {
      Log.fail('Migration failed: $e');
      rethrow;
    }
  }

  /// Calculate which fields need to be updated
  Map<String, dynamic> _calculateUpdates(Map<String, dynamic> data) {
    final updates = <String, dynamic>{};

    // Check accountStatus
    if (!data.containsKey('accountStatus') || data['accountStatus'] == null) {
      // Existing suppliers were implicitly approved before the new workflow
      updates['accountStatus'] = 'active';
    }

    // Check identityVerificationStatus
    if (!data.containsKey('identityVerificationStatus') ||
        data['identityVerificationStatus'] == null) {
      updates['identityVerificationStatus'] = 'pending';
    }

    // Check acceptingBookings
    if (!data.containsKey('acceptingBookings')) {
      updates['acceptingBookings'] = true;
    }

    // Ensure isActive matches accountStatus
    final accountStatus = data['accountStatus'] ?? updates['accountStatus'];
    if (accountStatus == 'active' && data['isActive'] != true) {
      updates['isActive'] = true;
    }

    // Ensure blocks field exists for booking availability
    if (!data.containsKey('blocks')) {
      updates['blocks'] = {
        'bookings_globally': false,
        'scheduled_blocks': <Map<String, dynamic>>[],
      };
    }

    // Add migration timestamp
    if (updates.isNotEmpty) {
      updates['_migratedAt'] = FieldValue.serverTimestamp();
      updates['_migrationVersion'] = 1;
    }

    return updates;
  }

  /// Verify migration was successful
  Future<MigrationVerification> verify() async {
    Log.i('Verifying migration...');

    int totalSuppliers = 0;
    int withAccountStatus = 0;
    int withIdentityStatus = 0;
    int withAcceptingBookings = 0;
    int activeWithIsActive = 0;
    int mismatches = 0;
    final List<String> mismatchIds = [];

    QuerySnapshot? lastSnapshot;
    const batchSize = 100;

    do {
      Query query = _firestore.collection('suppliers').limit(batchSize);

      if (lastSnapshot != null && lastSnapshot.docs.isNotEmpty) {
        query = query.startAfterDocument(lastSnapshot.docs.last);
      }

      lastSnapshot = await query.get();

      for (final doc in lastSnapshot.docs) {
        totalSuppliers++;
        final data = doc.data() as Map<String, dynamic>;

        if (data.containsKey('accountStatus') && data['accountStatus'] != null) {
          withAccountStatus++;
        }
        if (data.containsKey('identityVerificationStatus') &&
            data['identityVerificationStatus'] != null) {
          withIdentityStatus++;
        }
        if (data.containsKey('acceptingBookings')) {
          withAcceptingBookings++;
        }

        // Check for mismatch: accountStatus=active but isActive=false
        if (data['accountStatus'] == 'active' && data['isActive'] != true) {
          mismatches++;
          mismatchIds.add(doc.id);
        } else if (data['accountStatus'] == 'active' && data['isActive'] == true) {
          activeWithIsActive++;
        }
      }
    } while (lastSnapshot.docs.length == batchSize);

    Log.i('Verification: total=$totalSuppliers, withAccountStatus=$withAccountStatus, withIdentityStatus=$withIdentityStatus, withAcceptingBookings=$withAcceptingBookings, activeWithIsActive=$activeWithIsActive, mismatches=$mismatches');

    return MigrationVerification(
      totalSuppliers: totalSuppliers,
      withAccountStatus: withAccountStatus,
      withIdentityStatus: withIdentityStatus,
      withAcceptingBookings: withAcceptingBookings,
      activeWithIsActive: activeWithIsActive,
      mismatches: mismatches,
      mismatchIds: mismatchIds,
    );
  }

  /// Fix any remaining mismatches (accountStatus=active but isActive=false)
  Future<int> fixMismatches() async {
    Log.i('Fixing accountStatus/isActive mismatches...');

    int fixed = 0;

    final snapshot = await _firestore
        .collection('suppliers')
        .where('accountStatus', isEqualTo: 'active')
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isActive'] != true) {
        await doc.reference.update({
          'isActive': true,
          '_mismatchFixedAt': FieldValue.serverTimestamp(),
        });
        fixed++;
        Log.success('Fixed: ${doc.id}');
      }
    }

    Log.i('Fixed $fixed mismatches');
    return fixed;
  }
}

/// Result of running the migration
class MigrationResult {
  final int totalSuppliers;
  final int migratedSuppliers;
  final int skippedSuppliers;
  final int errorCount;
  final List<String> errors;
  final bool dryRun;

  MigrationResult({
    required this.totalSuppliers,
    required this.migratedSuppliers,
    required this.skippedSuppliers,
    required this.errorCount,
    required this.errors,
    required this.dryRun,
  });

  bool get isSuccess => errorCount == 0;

  @override
  String toString() {
    return 'MigrationResult(total: $totalSuppliers, migrated: $migratedSuppliers, '
        'skipped: $skippedSuppliers, errors: $errorCount, dryRun: $dryRun)';
  }
}

/// Result of verifying the migration
class MigrationVerification {
  final int totalSuppliers;
  final int withAccountStatus;
  final int withIdentityStatus;
  final int withAcceptingBookings;
  final int activeWithIsActive;
  final int mismatches;
  final List<String> mismatchIds;

  MigrationVerification({
    required this.totalSuppliers,
    required this.withAccountStatus,
    required this.withIdentityStatus,
    required this.withAcceptingBookings,
    required this.activeWithIsActive,
    required this.mismatches,
    required this.mismatchIds,
  });

  bool get isFullyMigrated =>
      withAccountStatus == totalSuppliers &&
      withIdentityStatus == totalSuppliers &&
      withAcceptingBookings == totalSuppliers &&
      mismatches == 0;

  @override
  String toString() {
    return 'MigrationVerification(total: $totalSuppliers, '
        'withAccountStatus: $withAccountStatus, mismatches: $mismatches)';
  }
}
