import 'package:boda_connect/core/services/file_upload/file_upload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../models/verification_document_model.dart';

/// Service for managing supplier verification documents and status
class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection references
  CollectionReference get _suppliersRef => _firestore.collection('suppliers');
  CollectionReference get _documentsRef =>
      _firestore.collection('verification_documents');

  /// Upload a verification document (cross-platform using XFile)
  Future<VerificationDocument?> uploadDocument({
    required String supplierId,
    required DocumentType type,
    required XFile file,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      // Read file as bytes (works on all platforms)
      final bytes = await fileUploadHelper.readAsBytes(file);
      final fileSize = bytes.length;

      // Validate file size
      if (fileSize > VerificationRequirements.maxFileSize) {
        throw Exception(
            'Arquivo muito grande. Máximo ${VerificationRequirements.maxFileSize ~/ (1024 * 1024)}MB');
      }

      // Validate mime type
      if (!VerificationRequirements.allowedMimeTypes.contains(mimeType)) {
        throw Exception(
            'Tipo de arquivo não permitido. Use JPG, PNG, WEBP ou PDF.');
      }

      // Generate unique file path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(fileName);
      final storagePath =
          'verification/$supplierId/${type.name}_$timestamp$extension';

      // Upload to Firebase Storage using bytes (works on web)
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType,
          customMetadata: {
            'supplierId': supplierId,
            'documentType': type.name,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create document record in Firestore
      final docRef = await _documentsRef.add({
        'supplierId': supplierId,
        'type': type.name,
        'fileName': fileName,
        'fileUrl': downloadUrl,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'status': DocumentStatus.pending.name,
        'uploadedAt': Timestamp.now(),
      });

      // Update supplier verification status
      await _updateSupplierVerificationStatus(supplierId);

      debugPrint('Document uploaded: ${docRef.id}');

      return VerificationDocument(
        id: docRef.id,
        supplierId: supplierId,
        type: type,
        fileName: fileName,
        fileUrl: downloadUrl,
        fileSize: fileSize,
        mimeType: mimeType,
        status: DocumentStatus.pending,
        uploadedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error uploading document: $e');
      rethrow;
    }
  }

  /// Upload document from bytes (for web)
  Future<VerificationDocument?> uploadDocumentBytes({
    required String supplierId,
    required DocumentType type,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      // Validate file size
      if (bytes.length > VerificationRequirements.maxFileSize) {
        throw Exception(
            'Arquivo muito grande. Máximo ${VerificationRequirements.maxFileSize ~/ (1024 * 1024)}MB');
      }

      // Validate mime type
      if (!VerificationRequirements.allowedMimeTypes.contains(mimeType)) {
        throw Exception(
            'Tipo de arquivo não permitido. Use JPG, PNG, WEBP ou PDF.');
      }

      // Generate unique file path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(fileName);
      final storagePath =
          'verification/$supplierId/${type.name}_$timestamp$extension';

      // Upload to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType,
          customMetadata: {
            'supplierId': supplierId,
            'documentType': type.name,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create document record in Firestore
      final docRef = await _documentsRef.add({
        'supplierId': supplierId,
        'type': type.name,
        'fileName': fileName,
        'fileUrl': downloadUrl,
        'fileSize': bytes.length,
        'mimeType': mimeType,
        'status': DocumentStatus.pending.name,
        'uploadedAt': Timestamp.now(),
      });

      // Update supplier verification status
      await _updateSupplierVerificationStatus(supplierId);

      return VerificationDocument(
        id: docRef.id,
        supplierId: supplierId,
        type: type,
        fileName: fileName,
        fileUrl: downloadUrl,
        fileSize: bytes.length,
        mimeType: mimeType,
        status: DocumentStatus.pending,
        uploadedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error uploading document bytes: $e');
      rethrow;
    }
  }

  /// Delete a verification document
  Future<void> deleteDocument(String documentId, String supplierId) async {
    try {
      final doc = await _documentsRef.doc(documentId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final fileUrl = data['fileUrl'] as String?;

      // Delete from Storage
      if (fileUrl != null && fileUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(fileUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting file from storage: $e');
        }
      }

      // Delete from Firestore
      await _documentsRef.doc(documentId).delete();

      // Update supplier verification status
      await _updateSupplierVerificationStatus(supplierId);
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  /// Get all documents for a supplier
  Future<List<VerificationDocument>> getSupplierDocuments(
      String supplierId) async {
    try {
      final snapshot = await _documentsRef
          .where('supplierId', isEqualTo: supplierId)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => VerificationDocument.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting supplier documents: $e');
      return [];
    }
  }

  /// Stream documents for a supplier
  Stream<List<VerificationDocument>> streamSupplierDocuments(
      String supplierId) {
    return _documentsRef
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VerificationDocument.fromFirestore(doc))
            .toList());
  }

  /// Get verification summary for a supplier
  Future<VerificationSummary> getVerificationSummary(String supplierId) async {
    try {
      final documents = await getSupplierDocuments(supplierId);
      final supplierDoc = await _suppliersRef.doc(supplierId).get();
      final supplierData = supplierDoc.data() as Map<String, dynamic>? ?? {};

      final statusString =
          supplierData['verificationStatus'] as String? ?? 'notStarted';
      final status = VerificationStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => VerificationStatus.notStarted,
      );

      return VerificationSummary(
        supplierId: supplierId,
        status: status,
        documents: documents,
        lastUpdated: _parseTimestamp(supplierData['verificationUpdatedAt']),
        adminNote: supplierData['verificationNote'] as String?,
      );
    } catch (e) {
      debugPrint('Error getting verification summary: $e');
      return VerificationSummary.empty(supplierId);
    }
  }

  /// Stream verification summary
  Stream<VerificationSummary> streamVerificationSummary(String supplierId) {
    return _documentsRef
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .asyncMap((snapshot) async {
      final documents = snapshot.docs
          .map((doc) => VerificationDocument.fromFirestore(doc))
          .toList();

      final supplierDoc = await _suppliersRef.doc(supplierId).get();
      final supplierData = supplierDoc.data() as Map<String, dynamic>? ?? {};

      final statusString =
          supplierData['verificationStatus'] as String? ?? 'notStarted';
      final status = VerificationStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => VerificationStatus.notStarted,
      );

      return VerificationSummary(
        supplierId: supplierId,
        status: status,
        documents: documents,
        lastUpdated: _parseTimestamp(supplierData['verificationUpdatedAt']),
        adminNote: supplierData['verificationNote'] as String?,
      );
    });
  }

  /// Update supplier verification status based on documents
  Future<void> _updateSupplierVerificationStatus(String supplierId) async {
    try {
      final documents = await getSupplierDocuments(supplierId);

      VerificationStatus newStatus;

      if (documents.isEmpty) {
        newStatus = VerificationStatus.notStarted;
      } else {
        // Check if any required documents are rejected
        final hasRejected = documents.any(
          (d) =>
              d.status == DocumentStatus.rejected &&
              VerificationRequirements.isRequired(d.type),
        );

        if (hasRejected) {
          newStatus = VerificationStatus.rejected;
        } else {
          // Check if all required documents are approved
          final allRequiredApproved =
              VerificationRequirements.requiredDocuments.every((type) {
            return documents.any(
              (d) => d.type == type && d.status == DocumentStatus.approved,
            );
          });

          if (allRequiredApproved) {
            newStatus = VerificationStatus.verified;
          } else {
            newStatus = VerificationStatus.pendingReview;
          }
        }
      }

      // Update supplier document
      await _suppliersRef.doc(supplierId).update({
        'verificationStatus': newStatus.name,
        'verificationUpdatedAt': Timestamp.now(),
        'isVerified': newStatus == VerificationStatus.verified,
      });
    } catch (e) {
      debugPrint('Error updating verification status: $e');
    }
  }

  // ==================== ADMIN FUNCTIONS ====================

  /// Get all pending verification documents (for admin)
  Future<List<VerificationDocument>> getPendingDocuments() async {
    try {
      final snapshot = await _documentsRef
          .where('status', isEqualTo: DocumentStatus.pending.name)
          .orderBy('uploadedAt', descending: false) // Oldest first
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => VerificationDocument.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending documents: $e');
      return [];
    }
  }

  /// Get suppliers pending verification (for admin)
  Future<List<Map<String, dynamic>>> getPendingSuppliers() async {
    try {
      final snapshot = await _suppliersRef
          .where('verificationStatus',
              isEqualTo: VerificationStatus.pendingReview.name)
          .orderBy('verificationUpdatedAt', descending: false)
          .limit(50)
          .get();

      List<Map<String, dynamic>> results = [];

      for (final doc in snapshot.docs) {
        final supplierData = doc.data() as Map<String, dynamic>;
        final documents = await getSupplierDocuments(doc.id);

        results.add({
          'supplierId': doc.id,
          'businessName': supplierData['businessName'] ?? 'Sem Nome',
          'category': supplierData['category'],
          'city': supplierData['city'],
          'submittedAt': supplierData['verificationUpdatedAt'],
          'documents': documents,
          'documentsCount': documents.length,
          'pendingCount':
              documents.where((d) => d.status == DocumentStatus.pending).length,
        });
      }

      return results;
    } catch (e) {
      debugPrint('Error getting pending suppliers: $e');
      return [];
    }
  }

  /// Approve a document (admin only)
  Future<void> approveDocument({
    required String documentId,
    required String adminId,
  }) async {
    try {
      final doc = await _documentsRef.doc(documentId).get();
      if (!doc.exists) throw Exception('Documento não encontrado');

      final data = doc.data() as Map<String, dynamic>;
      final supplierId = data['supplierId'] as String;

      await _documentsRef.doc(documentId).update({
        'status': DocumentStatus.approved.name,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'rejectionReason': null,
      });

      // Update supplier verification status
      await _updateSupplierVerificationStatus(supplierId);

      debugPrint('Document $documentId approved by $adminId');
    } catch (e) {
      debugPrint('Error approving document: $e');
      rethrow;
    }
  }

  /// Reject a document (admin only)
  Future<void> rejectDocument({
    required String documentId,
    required String adminId,
    required String reason,
  }) async {
    try {
      final doc = await _documentsRef.doc(documentId).get();
      if (!doc.exists) throw Exception('Documento não encontrado');

      final data = doc.data() as Map<String, dynamic>;
      final supplierId = data['supplierId'] as String;

      await _documentsRef.doc(documentId).update({
        'status': DocumentStatus.rejected.name,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'rejectionReason': reason,
      });

      // Update supplier verification status
      await _updateSupplierVerificationStatus(supplierId);

      debugPrint('Document $documentId rejected by $adminId: $reason');
    } catch (e) {
      debugPrint('Error rejecting document: $e');
      rethrow;
    }
  }

  /// Approve all pending documents for a supplier (batch)
  Future<void> approveAllDocuments({
    required String supplierId,
    required String adminId,
  }) async {
    try {
      final documents = await getSupplierDocuments(supplierId);
      final pendingDocs =
          documents.where((d) => d.status == DocumentStatus.pending);

      final batch = _firestore.batch();

      for (final doc in pendingDocs) {
        batch.update(_documentsRef.doc(doc.id), {
          'status': DocumentStatus.approved.name,
          'reviewedAt': Timestamp.now(),
          'reviewedBy': adminId,
        });
      }

      await batch.commit();

      // Update supplier verification status
      await _updateSupplierVerificationStatus(supplierId);

      debugPrint('All documents approved for supplier $supplierId');
    } catch (e) {
      debugPrint('Error batch approving documents: $e');
      rethrow;
    }
  }

  /// Suspend a verified supplier (admin only)
  Future<void> suspendSupplier({
    required String supplierId,
    required String adminId,
    required String reason,
  }) async {
    try {
      await _suppliersRef.doc(supplierId).update({
        'verificationStatus': VerificationStatus.suspended.name,
        'verificationUpdatedAt': Timestamp.now(),
        'verificationNote': reason,
        'isVerified': false,
        'suspendedBy': adminId,
        'suspendedAt': Timestamp.now(),
      });

      debugPrint('Supplier $supplierId suspended by $adminId: $reason');
    } catch (e) {
      debugPrint('Error suspending supplier: $e');
      rethrow;
    }
  }

  /// Reinstate a suspended supplier (admin only)
  Future<void> reinstateSupplier({
    required String supplierId,
    required String adminId,
  }) async {
    try {
      // Check if all required documents are still approved
      final documents = await getSupplierDocuments(supplierId);
      final allRequiredApproved =
          VerificationRequirements.requiredDocuments.every((type) {
        return documents.any(
          (d) => d.type == type && d.status == DocumentStatus.approved,
        );
      });

      await _suppliersRef.doc(supplierId).update({
        'verificationStatus': allRequiredApproved
            ? VerificationStatus.verified.name
            : VerificationStatus.pendingReview.name,
        'verificationUpdatedAt': Timestamp.now(),
        'verificationNote': null,
        'isVerified': allRequiredApproved,
        'suspendedBy': null,
        'suspendedAt': null,
        'reinstatedBy': adminId,
        'reinstatedAt': Timestamp.now(),
      });

      debugPrint('Supplier $supplierId reinstated by $adminId');
    } catch (e) {
      debugPrint('Error reinstating supplier: $e');
      rethrow;
    }
  }

  /// Get verification statistics (for admin dashboard)
  Future<Map<String, int>> getVerificationStats() async {
    try {
      final pendingDocs = await _documentsRef
          .where('status', isEqualTo: DocumentStatus.pending.name)
          .count()
          .get();

      final pendingSuppliers = await _suppliersRef
          .where('verificationStatus',
              isEqualTo: VerificationStatus.pendingReview.name)
          .count()
          .get();

      final verifiedSuppliers = await _suppliersRef
          .where('verificationStatus',
              isEqualTo: VerificationStatus.verified.name)
          .count()
          .get();

      final suspendedSuppliers = await _suppliersRef
          .where('verificationStatus',
              isEqualTo: VerificationStatus.suspended.name)
          .count()
          .get();

      return {
        'pendingDocuments': pendingDocs.count ?? 0,
        'pendingSuppliers': pendingSuppliers.count ?? 0,
        'verifiedSuppliers': verifiedSuppliers.count ?? 0,
        'suspendedSuppliers': suspendedSuppliers.count ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting verification stats: $e');
      return {
        'pendingDocuments': 0,
        'pendingSuppliers': 0,
        'verifiedSuppliers': 0,
        'suspendedSuppliers': 0,
      };
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
