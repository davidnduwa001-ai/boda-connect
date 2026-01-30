import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_availability_model.dart';

// Provider for supplier availability for a specific month
final supplierAvailabilityProvider = FutureProvider.family<SupplierAvailabilityCollection, SupplierAvailabilityParams>(
  (ref, params) async {
    final startOfMonth = DateTime(params.year, params.month, 1);
    final endOfMonth = DateTime(params.year, params.month + 1, 0, 23, 59, 59);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('suppliers')
        .doc(params.supplierId)
        .collection('availability')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    final availabilities = querySnapshot.docs
        .map((doc) => SupplierAvailabilityModel.fromFirestore(doc))
        .toList();

    return SupplierAvailabilityCollection(availabilities);
  },
);

class SupplierAvailabilityParams {
  final String supplierId;
  final int year;
  final int month;

  const SupplierAvailabilityParams({
    required this.supplierId,
    required this.year,
    required this.month,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierAvailabilityParams &&
          runtimeType == other.runtimeType &&
          supplierId == other.supplierId &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => supplierId.hashCode ^ year.hashCode ^ month.hashCode;
}
