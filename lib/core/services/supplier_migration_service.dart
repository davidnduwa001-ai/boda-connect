import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/core/services/logger_service.dart';

/// Service to fix supplier data inconsistencies
///
/// This handles:
/// - Ensuring all approved suppliers have isActive: true
/// - Fixing suppliers with accountStatus: active but missing isActive
/// - Syncing isActive with accountStatus
class SupplierMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _suppliers => _firestore.collection('suppliers');

  /// Run full migration - call this on app startup or periodically
  /// This ensures all suppliers with accountStatus: active have isActive: true
  Future<MigrationResult> runMigration() async {
    Log.d('🔄 Starting supplier migration...');

    int fixed = 0;
    int alreadyCorrect = 0;
    int errors = 0;
    final messages = <String>[];

    try {
      // Get ALL suppliers
      final allSuppliers = await _suppliers.get();
      Log.d('📊 Total suppliers found: ${allSuppliers.docs.length}');

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in allSuppliers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final accountStatus = data['accountStatus'] as String?;
        final isActive = data['isActive'] as bool?;
        final businessName = data['businessName'] as String? ?? 'Unknown';

        // Determine what isActive should be based on accountStatus
        final shouldBeActive = accountStatus == 'active';

        // Check if isActive field is missing or incorrect
        if (isActive == null) {
          // Field is missing entirely - set it based on accountStatus
          batch.update(doc.reference, {
            'isActive': shouldBeActive,
          });
          batchCount++;
          fixed++;
          messages.add('Fixed missing isActive for "$businessName" -> $shouldBeActive');
          Log.d('  🔧 Fixed missing isActive for "$businessName" (accountStatus: $accountStatus) -> $shouldBeActive');
        } else if (isActive != shouldBeActive) {
          // Field exists but is incorrect - sync with accountStatus
          batch.update(doc.reference, {
            'isActive': shouldBeActive,
          });
          batchCount++;
          fixed++;
          messages.add('Synced isActive for "$businessName": $isActive -> $shouldBeActive');
          Log.d('  🔧 Synced isActive for "$businessName": $isActive -> $shouldBeActive');
        } else {
          alreadyCorrect++;
        }

        // Commit batch every 400 operations (Firestore limit is 500)
        if (batchCount >= 400) {
          await batch.commit();
          batchCount = 0;
          Log.d('  💾 Committed batch of 400 updates');
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
        Log.d('  💾 Committed final batch of $batchCount updates');
      }

      Log.d('✅ Migration complete: $fixed fixed, $alreadyCorrect already correct');

      return MigrationResult(
        success: true,
        totalProcessed: allSuppliers.docs.length,
        fixed: fixed,
        alreadyCorrect: alreadyCorrect,
        errors: errors,
        messages: messages,
      );
    } catch (e) {
      Log.d('❌ Migration error: $e');
      return MigrationResult(
        success: false,
        totalProcessed: 0,
        fixed: fixed,
        alreadyCorrect: alreadyCorrect,
        errors: errors + 1,
        messages: [...messages, 'Error: $e'],
      );
    }
  }

  /// Fix a specific supplier's visibility
  Future<bool> fixSupplierVisibility(String supplierId) async {
    try {
      final doc = await _suppliers.doc(supplierId).get();
      if (!doc.exists) {
        Log.d('❌ Supplier $supplierId not found');
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final accountStatus = data['accountStatus'] as String?;

      // Only make active if accountStatus is active
      if (accountStatus == 'active') {
        await _suppliers.doc(supplierId).update({
          'isActive': true,
        });
        Log.d('✅ Fixed supplier $supplierId visibility');
        return true;
      } else {
        Log.d('⚠️ Supplier $supplierId accountStatus is "$accountStatus", not activating');
        return false;
      }
    } catch (e) {
      Log.d('❌ Error fixing supplier visibility: $e');
      return false;
    }
  }

  /// Get diagnostic info about supplier visibility
  Future<SupplierDiagnostics> getDiagnostics() async {
    try {
      final allSuppliers = await _suppliers.get();

      int total = allSuppliers.docs.length;
      int activeStatus = 0;
      int isActiveTrue = 0;
      int mismatch = 0;
      int missingIsActive = 0;

      for (final doc in allSuppliers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final accountStatus = data['accountStatus'] as String?;
        final isActive = data['isActive'];

        if (accountStatus == 'active') activeStatus++;
        if (isActive == true) isActiveTrue++;

        if (isActive == null) {
          missingIsActive++;
        } else if ((accountStatus == 'active') != (isActive == true)) {
          mismatch++;
        }
      }

      return SupplierDiagnostics(
        total: total,
        withActiveStatus: activeStatus,
        withIsActiveTrue: isActiveTrue,
        mismatchedVisibility: mismatch,
        missingIsActiveField: missingIsActive,
      );
    } catch (e) {
      Log.d('❌ Error getting diagnostics: $e');
      return SupplierDiagnostics.empty();
    }
  }

  /// Ensure all approved suppliers are visible in search
  /// Call this after admin approves suppliers
  Future<void> syncApprovedSuppliers() async {
    try {
      // Find suppliers with accountStatus: active but isActive != true
      final activeButHidden = await _suppliers
          .where('accountStatus', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();
      int count = 0;

      for (final doc in activeButHidden.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['isActive'] != true) {
          batch.update(doc.reference, {'isActive': true});
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
        Log.d('✅ Synced $count approved suppliers to be visible');
      }
    } catch (e) {
      Log.d('❌ Error syncing approved suppliers: $e');
    }
  }
}

/// Result of running migration
class MigrationResult {
  final bool success;
  final int totalProcessed;
  final int fixed;
  final int alreadyCorrect;
  final int errors;
  final List<String> messages;

  const MigrationResult({
    required this.success,
    required this.totalProcessed,
    required this.fixed,
    required this.alreadyCorrect,
    required this.errors,
    required this.messages,
  });

  bool get needsFixes => fixed > 0 || errors > 0;
}

/// Diagnostics about supplier visibility
class SupplierDiagnostics {
  final int total;
  final int withActiveStatus;
  final int withIsActiveTrue;
  final int mismatchedVisibility;
  final int missingIsActiveField;

  const SupplierDiagnostics({
    required this.total,
    required this.withActiveStatus,
    required this.withIsActiveTrue,
    required this.mismatchedVisibility,
    required this.missingIsActiveField,
  });

  factory SupplierDiagnostics.empty() => const SupplierDiagnostics(
    total: 0,
    withActiveStatus: 0,
    withIsActiveTrue: 0,
    mismatchedVisibility: 0,
    missingIsActiveField: 0,
  );

  bool get hasProblems => mismatchedVisibility > 0 || missingIsActiveField > 0;

  @override
  String toString() => '''
Supplier Diagnostics:
  Total suppliers: $total
  With accountStatus=active: $withActiveStatus
  With isActive=true: $withIsActiveTrue
  Mismatched visibility: $mismatchedVisibility
  Missing isActive field: $missingIsActiveField
  Has problems: $hasProblems
''';
}
