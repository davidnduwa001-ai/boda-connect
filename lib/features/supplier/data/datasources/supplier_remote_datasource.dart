import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boda_connect/features/supplier/data/models/supplier_model.dart';
import 'package:boda_connect/features/supplier/data/models/package_model.dart';
import 'package:boda_connect/core/utils/typedefs.dart';

/// Remote data source for Supplier operations with Firebase Firestore
/// Handles all direct interactions with Firebase for supplier and package data
class SupplierRemoteDataSource {
  SupplierRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  // Collection references
  CollectionReference<DataMap> get _suppliersCollection =>
      _firestore.collection('suppliers').withConverter<DataMap>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );

  CollectionReference<DataMap> get _packagesCollection =>
      _firestore.collection('packages').withConverter<DataMap>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );

  // ==================== SUPPLIER OPERATIONS ====================

  /// Get a supplier by ID from Firestore
  Future<SupplierModel> getSupplierById(String supplierId) async {
    final doc = await _suppliersCollection.doc(supplierId).get();

    if (!doc.exists) {
      throw Exception('Supplier not found');
    }

    return SupplierModel.fromMap(doc.data()!, doc.id);
  }

  /// Get suppliers by category from Firestore
  Future<List<SupplierModel>> getSuppliersByCategory({
    required String category,
    String? subcategory,
    int? limit,
  }) async {
    Query<DataMap> query = _suppliersCollection
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true);

    if (subcategory != null) {
      query = query.where('subcategories', arrayContains: subcategory);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => SupplierModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Search suppliers by query
  Future<List<SupplierModel>> searchSuppliers({
    required String query,
    String? category,
    String? city,
    int? limit,
  }) async {
    Query<DataMap> firestoreQuery =
        _suppliersCollection.where('isActive', isEqualTo: true);

    if (category != null) {
      firestoreQuery = firestoreQuery.where('category', isEqualTo: category);
    }

    if (city != null) {
      firestoreQuery =
          firestoreQuery.where('location.city', isEqualTo: city);
    }

    if (limit != null) {
      firestoreQuery = firestoreQuery.limit(limit);
    }

    final snapshot = await firestoreQuery.get();

    // Filter results by search query
    final suppliers = snapshot.docs
        .map((doc) => SupplierModel.fromMap(doc.data(), doc.id))
        .toList();

    // Client-side filtering for search query
    final searchLower = query.toLowerCase();
    return suppliers.where((supplier) {
      return supplier.businessName.toLowerCase().contains(searchLower) ||
          supplier.description.toLowerCase().contains(searchLower) ||
          supplier.subcategories
              .any((sub) => sub.toLowerCase().contains(searchLower));
    }).toList();
  }

  /// Get featured suppliers
  Future<List<SupplierModel>> getFeaturedSuppliers({int? limit}) async {
    Query<DataMap> query = _suppliersCollection
        .where('isFeatured', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => SupplierModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get verified suppliers
  Future<List<SupplierModel>> getVerifiedSuppliers({
    String? category,
    int? limit,
  }) async {
    Query<DataMap> query = _suppliersCollection
        .where('isVerified', isEqualTo: true)
        .where('isActive', isEqualTo: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.orderBy('rating', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => SupplierModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Update supplier profile
  Future<SupplierModel> updateSupplierProfile({
    required String supplierId,
    required DataMap updates,
  }) async {
    // Add updated timestamp
    updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

    await _suppliersCollection.doc(supplierId).update(updates);

    // Get and return updated supplier
    return getSupplierById(supplierId);
  }

  /// Toggle supplier active status
  Future<SupplierModel> toggleSupplierStatus({
    required String supplierId,
    required bool isActive,
  }) async {
    await _suppliersCollection.doc(supplierId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return getSupplierById(supplierId);
  }

  // ==================== PACKAGE OPERATIONS ====================

  /// Get all packages for a specific supplier
  Future<List<PackageModel>> getSupplierPackages(String supplierId) async {
    final snapshot = await _packagesCollection
        .where('supplierId', isEqualTo: supplierId)
        .get();

    // Sort in memory to avoid index requirement
    final packages = snapshot.docs
        .map((doc) => PackageModel.fromMap(doc.data(), doc.id))
        .toList();

    packages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return packages;
  }

  /// Get a specific package by ID
  Future<PackageModel> getPackageById(String packageId) async {
    final doc = await _packagesCollection.doc(packageId).get();

    if (!doc.exists) {
      throw Exception('Package not found');
    }

    return PackageModel.fromMap(doc.data()!, doc.id);
  }

  /// Create a new package
  Future<PackageModel> createPackage(DataMap packageData) async {
    // Add timestamps
    packageData['createdAt'] = Timestamp.fromDate(DateTime.now());
    packageData['updatedAt'] = Timestamp.fromDate(DateTime.now());

    // Create the package document
    final docRef = await _packagesCollection.add(packageData);

    // Get and return the created package
    return getPackageById(docRef.id);
  }

  /// Update an existing package
  Future<PackageModel> updatePackage({
    required String packageId,
    required DataMap updates,
  }) async {
    // Add updated timestamp
    updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

    await _packagesCollection.doc(packageId).update(updates);

    // Get and return updated package
    return getPackageById(packageId);
  }

  /// Delete a package
  Future<void> deletePackage(String packageId) async {
    await _packagesCollection.doc(packageId).delete();
  }

  /// Toggle package active status
  Future<PackageModel> togglePackageStatus({
    required String packageId,
    required bool isActive,
  }) async {
    await _packagesCollection.doc(packageId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return getPackageById(packageId);
  }

  // ==================== STREAM OPERATIONS ====================

  /// Stream supplier data
  Stream<SupplierModel> streamSupplier(String supplierId) {
    return _suppliersCollection
        .doc(supplierId)
        .snapshots()
        .map((doc) => SupplierModel.fromMap(doc.data()!, doc.id));
  }

  /// Stream supplier packages
  Stream<List<PackageModel>> streamSupplierPackages(String supplierId) {
    return _packagesCollection
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snapshot) {
          // Sort in memory to avoid index requirement
          final packages = snapshot.docs
              .map((doc) => PackageModel.fromMap(doc.data(), doc.id))
              .toList();
          packages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return packages;
        });
  }

  /// Stream featured suppliers
  Stream<List<SupplierModel>> streamFeaturedSuppliers({int? limit}) {
    Query<DataMap> query = _suppliersCollection
        .where('isFeatured', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => SupplierModel.fromMap(doc.data(), doc.id))
        .toList());
  }
}
