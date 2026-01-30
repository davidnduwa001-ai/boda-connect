import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/payment_method_model.dart';

/// Payment Method Repository
///
/// UI-FIRST WARNING: Direct Firestore queries to paymentMethods collection
/// cause FAILED_PRECONDITION errors (missing index) and should be avoided.
/// Payment methods should be managed via Cloud Functions.
class PaymentMethodRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all payment methods for a supplier
  ///
  /// @deprecated UI-FIRST VIOLATION: Direct Firestore query causes index errors.
  /// Payment methods should be fetched via Cloud Function or projection.
  @Deprecated('Use Cloud Function to fetch payment methods. Direct queries cause index errors.')
  Future<List<PaymentMethodModel>> getPaymentMethods(String supplierId) async {
    try {
      // Simplified query without orderBy to avoid index requirement
      final snapshot = await _firestore
          .collection('paymentMethods')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      final methods = snapshot.docs
          .map((doc) => PaymentMethodModel.fromFirestore(doc))
          .toList();

      // Sort in memory instead of requiring index
      methods.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return methods;
    } catch (e) {
      // Gracefully handle permission/index errors
      debugPrint('⚠️ Error fetching payment methods (may require Cloud Function): $e');
      return [];
    }
  }

  // Get payment methods stream
  ///
  /// @deprecated UI-FIRST VIOLATION: Direct Firestore stream causes index errors.
  /// Payment methods should be fetched via Cloud Function or projection.
  @Deprecated('Use Cloud Function to fetch payment methods. Direct queries cause index errors.')
  Stream<List<PaymentMethodModel>> getPaymentMethodsStream(String supplierId) {
    // Simplified query without orderBy to avoid index requirement
    return _firestore
        .collection('paymentMethods')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snapshot) {
      final methods = snapshot.docs
          .map((doc) => PaymentMethodModel.fromFirestore(doc))
          .toList();

      // Sort in memory instead of requiring index
      methods.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return methods;
    }).handleError((e) {
      debugPrint('⚠️ Payment methods stream error: $e');
      return <PaymentMethodModel>[];
    });
  }

  // Add payment method
  Future<String?> addPaymentMethod(PaymentMethodModel paymentMethod) async {
    try {
      final docRef = await _firestore
          .collection('paymentMethods')
          .add(paymentMethod.toFirestore());

      debugPrint('✅ Payment method added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error adding payment method: $e');
      return null;
    }
  }

  // Update payment method
  Future<bool> updatePaymentMethod(
    String paymentMethodId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection('paymentMethods')
          .doc(paymentMethodId)
          .update(updates);

      debugPrint('✅ Payment method updated: $paymentMethodId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating payment method: $e');
      return false;
    }
  }

  // Delete payment method
  Future<bool> deletePaymentMethod(String paymentMethodId) async {
    try {
      await _firestore
          .collection('paymentMethods')
          .doc(paymentMethodId)
          .delete();

      debugPrint('✅ Payment method deleted: $paymentMethodId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting payment method: $e');
      return false;
    }
  }

  // Set default payment method
  ///
  /// @deprecated UI-FIRST: Consider using Cloud Function for payment method management.
  @Deprecated('Consider using Cloud Function for payment method management.')
  Future<bool> setDefaultPaymentMethod(
    String supplierId,
    String paymentMethodId,
  ) async {
    try {
      final batch = _firestore.batch();

      // Simplified: get all payment methods and filter in memory
      final allMethods = await _firestore
          .collection('paymentMethods')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      // Filter for default methods in memory to avoid index requirement
      final defaultMethods = allMethods.docs.where((doc) {
        final data = doc.data();
        return data['isDefault'] == true;
      });

      for (final doc in defaultMethods) {
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Set the selected payment method as default
      batch.update(
        _firestore.collection('paymentMethods').doc(paymentMethodId),
        {
          'isDefault': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      debugPrint('✅ Default payment method set: $paymentMethodId');
      return true;
    } catch (e) {
      debugPrint('❌ Error setting default payment method: $e');
      return false;
    }
  }

  // Get default payment method
  ///
  /// @deprecated UI-FIRST: Consider using Cloud Function for payment method management.
  @Deprecated('Consider using Cloud Function for payment method management.')
  Future<PaymentMethodModel?> getDefaultPaymentMethod(String supplierId) async {
    try {
      // Single where clause to avoid index requirement
      final allMethods = await _firestore
          .collection('paymentMethods')
          .where('supplierId', isEqualTo: supplierId)
          .get();

      // Filter for default in memory
      final defaultMethod = allMethods.docs.where((doc) {
        final data = doc.data();
        return data['isDefault'] == true;
      }).firstOrNull;

      if (defaultMethod != null) {
        return PaymentMethodModel.fromFirestore(defaultMethod);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error fetching default payment method: $e');
      return null;
    }
  }
}
