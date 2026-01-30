import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';
import '../services/dispute_service.dart';

/// Provider for the DisputeService
final disputeServiceProvider = Provider<DisputeService>((ref) {
  return DisputeService();
});

/// State class for dispute management
class DisputeState {
  final List<ReportModel> userDisputes;
  final ReportModel? currentDispute;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  const DisputeState({
    this.userDisputes = const [],
    this.currentDispute,
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  DisputeState copyWith({
    List<ReportModel>? userDisputes,
    ReportModel? currentDispute,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    String? successMessage,
  }) {
    return DisputeState(
      userDisputes: userDisputes ?? this.userDisputes,
      currentDispute: currentDispute ?? this.currentDispute,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Parameters for user dispute provider
class UserDisputeParams {
  final String userId;
  final String userType;

  const UserDisputeParams({
    required this.userId,
    required this.userType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDisputeParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          userType == other.userType;

  @override
  int get hashCode => userId.hashCode ^ userType.hashCode;
}

/// Provider for user disputes
final userDisputesProvider = StateNotifierProvider.family<
    UserDisputeNotifier, DisputeState, UserDisputeParams>(
  (ref, params) => UserDisputeNotifier(ref, params),
);

/// Notifier for managing user disputes
class UserDisputeNotifier extends StateNotifier<DisputeState> {
  final Ref _ref;
  final UserDisputeParams _params;

  UserDisputeNotifier(this._ref, this._params)
      : super(const DisputeState(isLoading: true)) {
    _loadDisputes();
  }

  DisputeService get _service => _ref.read(disputeServiceProvider);

  Future<void> _loadDisputes() async {
    try {
      final disputes = await _service.getUserDisputes(
        userId: _params.userId,
        userType: _params.userType,
        asReporter: true,
      );

      // Also get disputes where user is reported
      final disputesAsReported = await _service.getUserDisputes(
        userId: _params.userId,
        userType: _params.userType,
        asReporter: false,
      );

      // Merge and sort by date
      final allDisputes = [...disputes, ...disputesAsReported];
      allDisputes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        userDisputes: allDisputes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Refresh disputes
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadDisputes();
  }

  /// File a new dispute
  Future<String?> fileDispute({
    required String bookingId,
    required ReportCategory category,
    required String reason,
    List<String>? evidenceUrls,
    List<String>? messageIds,
    ReportSeverity severity = ReportSeverity.medium,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final disputeId = await _service.fileDispute(
        bookingId: bookingId,
        reporterId: _params.userId,
        reporterType: _params.userType,
        category: category,
        reason: reason,
        evidenceUrls: evidenceUrls,
        messageIds: messageIds,
        severity: severity,
      );

      await _loadDisputes();

      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Disputa registrada com sucesso',
      );

      return disputeId;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Add evidence to dispute
  Future<bool> addEvidence({
    required String disputeId,
    required List<String> evidenceUrls,
    String? description,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      await _service.addEvidence(
        disputeId: disputeId,
        userId: _params.userId,
        evidenceUrls: evidenceUrls,
        description: description,
      );

      await _loadDisputes();

      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Evidência adicionada com sucesso',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Submit response to dispute
  Future<bool> submitResponse({
    required String disputeId,
    required String response,
    List<String>? evidenceUrls,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      await _service.submitResponse(
        disputeId: disputeId,
        userId: _params.userId,
        response: response,
        evidenceUrls: evidenceUrls,
      );

      await _loadDisputes();

      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Resposta enviada com sucesso',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// File an appeal
  Future<bool> fileAppeal({
    required String disputeId,
    required String reason,
    List<String>? newEvidenceUrls,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      await _service.fileAppeal(
        disputeId: disputeId,
        userId: _params.userId,
        reason: reason,
        newEvidenceUrls: newEvidenceUrls,
      );

      await _loadDisputes();

      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Apelação registrada com sucesso',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(successMessage: null);
  }
}

/// Stream provider for a single dispute
final disputeStreamProvider =
    StreamProvider.family<ReportModel?, String>((ref, disputeId) {
  final service = ref.read(disputeServiceProvider);
  return service.streamDispute(disputeId);
});

/// Future provider for booking dispute
final bookingDisputeProvider =
    FutureProvider.family<ReportModel?, String>((ref, bookingId) async {
  final service = ref.read(disputeServiceProvider);
  return service.getBookingDispute(bookingId);
});

// ==================== ADMIN PROVIDERS ====================

/// State class for admin dispute management
class AdminDisputeState {
  final List<ReportModel> openDisputes;
  final List<ReportModel> escalatedDisputes;
  final Map<String, dynamic> stats;
  final bool isLoading;
  final String? error;
  final String? processingDisputeId;

  const AdminDisputeState({
    this.openDisputes = const [],
    this.escalatedDisputes = const [],
    this.stats = const {},
    this.isLoading = false,
    this.error,
    this.processingDisputeId,
  });

  AdminDisputeState copyWith({
    List<ReportModel>? openDisputes,
    List<ReportModel>? escalatedDisputes,
    Map<String, dynamic>? stats,
    bool? isLoading,
    String? error,
    String? processingDisputeId,
  }) {
    return AdminDisputeState(
      openDisputes: openDisputes ?? this.openDisputes,
      escalatedDisputes: escalatedDisputes ?? this.escalatedDisputes,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      processingDisputeId: processingDisputeId,
    );
  }
}

/// Provider for admin dispute management
final adminDisputeProvider =
    StateNotifierProvider<AdminDisputeNotifier, AdminDisputeState>(
  (ref) => AdminDisputeNotifier(ref),
);

/// Notifier for admin dispute operations
class AdminDisputeNotifier extends StateNotifier<AdminDisputeState> {
  final Ref _ref;

  AdminDisputeNotifier(this._ref)
      : super(const AdminDisputeState(isLoading: true)) {
    _loadData();
  }

  DisputeService get _service => _ref.read(disputeServiceProvider);

  Future<void> _loadData() async {
    try {
      final openDisputes = await _service.getOpenDisputes();
      final escalatedDisputes = await _service.getEscalatedDisputes();
      final stats = await _service.getDisputeStats();

      state = state.copyWith(
        openDisputes: openDisputes,
        escalatedDisputes: escalatedDisputes,
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

  /// Assign dispute to admin
  Future<void> assignDispute({
    required String disputeId,
    required String adminId,
    required String adminName,
  }) async {
    state = state.copyWith(processingDisputeId: disputeId, error: null);

    try {
      await _service.assignDispute(
        disputeId: disputeId,
        adminId: adminId,
        adminName: adminName,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(processingDisputeId: null);
    }
  }

  /// Add admin note
  Future<void> addNote({
    required String disputeId,
    required String adminId,
    required String adminName,
    required String content,
    bool isInternal = true,
  }) async {
    try {
      await _service.addAdminNote(
        disputeId: disputeId,
        adminId: adminId,
        adminName: adminName,
        content: content,
        isInternal: isInternal,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Resolve dispute
  Future<void> resolveDispute({
    required String disputeId,
    required String adminId,
    required DisputeOutcome outcome,
    required String resolution,
    double? refundAmount,
    bool suspendReportedAccount = false,
  }) async {
    state = state.copyWith(processingDisputeId: disputeId, error: null);

    try {
      await _service.resolveDispute(
        disputeId: disputeId,
        adminId: adminId,
        outcome: outcome,
        resolution: resolution,
        refundAmount: refundAmount,
        suspendReportedAccount: suspendReportedAccount,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(processingDisputeId: null);
    }
  }

  /// Escalate dispute
  Future<void> escalateDispute({
    required String disputeId,
    required String adminId,
    required String reason,
  }) async {
    state = state.copyWith(processingDisputeId: disputeId, error: null);

    try {
      await _service.escalateDispute(
        disputeId: disputeId,
        adminId: adminId,
        reason: reason,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(processingDisputeId: null);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for dispute statistics
final disputeStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(disputeServiceProvider);
  return service.getDisputeStats();
});
