import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report_model.dart';
import '../repositories/report_repository.dart';

// ==================== REPOSITORY PROVIDER ====================

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

// ==================== REPORT STATE ====================

class ReportState {
  final List<ReportModel> reports;
  final bool isLoading;
  final String? error;

  const ReportState({
    this.reports = const [],
    this.isLoading = false,
    this.error,
  });

  ReportState copyWith({
    List<ReportModel>? reports,
    bool? isLoading,
    String? error,
  }) {
    return ReportState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ==================== REPORT NOTIFIER ====================

class ReportNotifier extends StateNotifier<ReportState> {
  final ReportRepository _repository;

  ReportNotifier(this._repository) : super(const ReportState());

  /// Submit a new report
  Future<String?> submitReport({
    required String reporterId,
    required String reporterType,
    required String reportedId,
    required String reportedType,
    String? bookingId,
    String? reviewId,
    String? chatId,
    required ReportCategory category,
    required String reason,
    List<XFile>? evidenceFiles,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final reportId = await _repository.submitReport(
        reporterId: reporterId,
        reporterType: reporterType,
        reportedId: reportedId,
        reportedType: reportedType,
        bookingId: bookingId,
        reviewId: reviewId,
        chatId: chatId,
        category: category,
        reason: reason,
        evidenceFiles: evidenceFiles,
      );

      state = state.copyWith(isLoading: false);
      return reportId;
    } catch (e) {
      debugPrint('❌ Error submitting report: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao submeter denúncia',
      );
      return null;
    }
  }

  /// Load reports submitted by user
  Future<void> loadUserReports(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final reports = await _repository.getReportsByUser(userId: userId);
      state = state.copyWith(
        reports: reports,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading user reports: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar denúncias',
      );
    }
  }

  /// Load reports against a user
  Future<void> loadReportsAgainstUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final reports = await _repository.getReportsAgainstUser(userId: userId);
      state = state.copyWith(
        reports: reports,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading reports against user: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar denúncias',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ==================== PROVIDERS ====================

final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>((ref) {
  final repository = ref.watch(reportRepositoryProvider);
  return ReportNotifier(repository);
});

/// Provider for reports submitted by a user
final reportsByUserProvider = FutureProvider.family<List<ReportModel>, String>((ref, userId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportsByUser(userId: userId);
});

/// Provider for reports against a user
final reportsAgainstUserProvider = FutureProvider.family<List<ReportModel>, String>((ref, userId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportsAgainstUser(userId: userId);
});

/// Provider for reports for a booking
final reportsForBookingProvider = FutureProvider.family<List<ReportModel>, String>((ref, bookingId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportsForBooking(bookingId);
});

/// Provider for pending reports (admin)
final pendingReportsProvider = FutureProvider<List<ReportModel>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getPendingReports();
});

/// Provider for reports by status
final reportsByStatusProvider = FutureProvider.family<List<ReportModel>, ReportStatus>((ref, status) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportsByStatus(status: status);
});

/// Provider for a specific report
final reportProvider_single = FutureProvider.family<ReportModel?, String>((ref, reportId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReport(reportId);
});

/// Provider for user report statistics
final userReportStatsProvider = FutureProvider.family<ReportStats, String>((ref, userId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getUserReportStats(userId);
});

/// Provider to check if user has active reports
final hasActiveReportsProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.hasActiveReports(userId);
});

/// Provider for critical report count
final criticalReportCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getCriticalReportCount(userId);
});
