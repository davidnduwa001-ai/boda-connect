import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/verification_document_model.dart';
import '../services/verification_service.dart';

/// Provider for the VerificationService
final verificationServiceProvider = Provider<VerificationService>((ref) {
  return VerificationService();
});

/// State class for verification management
class VerificationState {
  final VerificationSummary? summary;
  final bool isLoading;
  final bool isUploading;
  final String? error;
  final double uploadProgress;

  const VerificationState({
    this.summary,
    this.isLoading = false,
    this.isUploading = false,
    this.error,
    this.uploadProgress = 0.0,
  });

  VerificationState copyWith({
    VerificationSummary? summary,
    bool? isLoading,
    bool? isUploading,
    String? error,
    double? uploadProgress,
  }) {
    return VerificationState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      error: error,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}

/// Provider for supplier verification state
final verificationProvider = StateNotifierProvider.family<
    VerificationNotifier, VerificationState, String>(
  (ref, supplierId) => VerificationNotifier(ref, supplierId),
);

/// Notifier for managing verification state
class VerificationNotifier extends StateNotifier<VerificationState> {
  final Ref _ref;
  final String _supplierId;

  VerificationNotifier(this._ref, this._supplierId)
      : super(const VerificationState(isLoading: true)) {
    _loadSummary();
  }

  VerificationService get _service => _ref.read(verificationServiceProvider);

  Future<void> _loadSummary() async {
    try {
      final summary = await _service.getVerificationSummary(_supplierId);
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Refresh verification summary
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadSummary();
  }

  /// Upload a document (XFile-based, cross-platform)
  Future<VerificationDocument?> uploadDocument({
    required DocumentType type,
    required XFile file,
    required String fileName,
    required String mimeType,
  }) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0.0, error: null);

    try {
      final document = await _service.uploadDocument(
        supplierId: _supplierId,
        type: type,
        file: file,
        fileName: fileName,
        mimeType: mimeType,
      );

      // Refresh summary
      await _loadSummary();

      state = state.copyWith(isUploading: false, uploadProgress: 1.0);
      return document;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString(),
        uploadProgress: 0.0,
      );
      return null;
    }
  }

  /// Upload a document (bytes-based for web)
  Future<VerificationDocument?> uploadDocumentBytes({
    required DocumentType type,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0.0, error: null);

    try {
      final document = await _service.uploadDocumentBytes(
        supplierId: _supplierId,
        type: type,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );

      // Refresh summary
      await _loadSummary();

      state = state.copyWith(isUploading: false, uploadProgress: 1.0);
      return document;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString(),
        uploadProgress: 0.0,
      );
      return null;
    }
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.deleteDocument(documentId, _supplierId);
      await _loadSummary();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Stream provider for real-time verification updates
final verificationStreamProvider =
    StreamProvider.family<VerificationSummary, String>((ref, supplierId) {
  final service = ref.read(verificationServiceProvider);
  return service.streamVerificationSummary(supplierId);
});

/// Stream provider for supplier documents
final verificationDocumentsStreamProvider =
    StreamProvider.family<List<VerificationDocument>, String>((ref, supplierId) {
  final service = ref.read(verificationServiceProvider);
  return service.streamSupplierDocuments(supplierId);
});

// ==================== ADMIN PROVIDERS ====================

/// State class for admin verification queue
class AdminVerificationState {
  final List<Map<String, dynamic>> pendingSuppliers;
  final List<VerificationDocument> pendingDocuments;
  final Map<String, int> stats;
  final bool isLoading;
  final String? error;
  final String? processingDocumentId;

  const AdminVerificationState({
    this.pendingSuppliers = const [],
    this.pendingDocuments = const [],
    this.stats = const {},
    this.isLoading = false,
    this.error,
    this.processingDocumentId,
  });

  AdminVerificationState copyWith({
    List<Map<String, dynamic>>? pendingSuppliers,
    List<VerificationDocument>? pendingDocuments,
    Map<String, int>? stats,
    bool? isLoading,
    String? error,
    String? processingDocumentId,
  }) {
    return AdminVerificationState(
      pendingSuppliers: pendingSuppliers ?? this.pendingSuppliers,
      pendingDocuments: pendingDocuments ?? this.pendingDocuments,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      processingDocumentId: processingDocumentId,
    );
  }
}

/// Provider for admin verification queue
final adminVerificationProvider =
    StateNotifierProvider<AdminVerificationNotifier, AdminVerificationState>(
  (ref) => AdminVerificationNotifier(ref),
);

/// Notifier for admin verification operations
class AdminVerificationNotifier extends StateNotifier<AdminVerificationState> {
  final Ref _ref;

  AdminVerificationNotifier(this._ref)
      : super(const AdminVerificationState(isLoading: true)) {
    _loadData();
  }

  VerificationService get _service => _ref.read(verificationServiceProvider);

  Future<void> _loadData() async {
    try {
      final pendingSuppliers = await _service.getPendingSuppliers();
      final pendingDocuments = await _service.getPendingDocuments();
      final stats = await _service.getVerificationStats();

      state = state.copyWith(
        pendingSuppliers: pendingSuppliers,
        pendingDocuments: pendingDocuments,
        stats: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadData();
  }

  /// Approve a document
  Future<void> approveDocument({
    required String documentId,
    required String adminId,
  }) async {
    state = state.copyWith(processingDocumentId: documentId, error: null);

    try {
      await _service.approveDocument(
        documentId: documentId,
        adminId: adminId,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(processingDocumentId: null);
    }
  }

  /// Reject a document
  Future<void> rejectDocument({
    required String documentId,
    required String adminId,
    required String reason,
  }) async {
    state = state.copyWith(processingDocumentId: documentId, error: null);

    try {
      await _service.rejectDocument(
        documentId: documentId,
        adminId: adminId,
        reason: reason,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(processingDocumentId: null);
    }
  }

  /// Approve all documents for a supplier
  Future<void> approveAllDocuments({
    required String supplierId,
    required String adminId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.approveAllDocuments(
        supplierId: supplierId,
        adminId: adminId,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Suspend a supplier
  Future<void> suspendSupplier({
    required String supplierId,
    required String adminId,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.suspendSupplier(
        supplierId: supplierId,
        adminId: adminId,
        reason: reason,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Reinstate a supplier
  Future<void> reinstateSupplier({
    required String supplierId,
    required String adminId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.reinstateSupplier(
        supplierId: supplierId,
        adminId: adminId,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
