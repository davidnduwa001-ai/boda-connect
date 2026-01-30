import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cancellation_service.dart';

/// Provider for the CancellationService
final cancellationServiceProvider = Provider<CancellationService>((ref) {
  return CancellationService();
});

/// State for cancellation preview
class CancellationPreviewState {
  final CancellationResult? preview;
  final bool isLoading;
  final String? error;

  const CancellationPreviewState({
    this.preview,
    this.isLoading = false,
    this.error,
  });

  CancellationPreviewState copyWith({
    CancellationResult? preview,
    bool? isLoading,
    String? error,
  }) {
    return CancellationPreviewState(
      preview: preview ?? this.preview,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for cancellation preview
final cancellationPreviewProvider = StateNotifierProvider.family<
    CancellationPreviewNotifier, CancellationPreviewState, String>(
  (ref, bookingId) => CancellationPreviewNotifier(ref, bookingId),
);

class CancellationPreviewNotifier
    extends StateNotifier<CancellationPreviewState> {
  final Ref _ref;
  final String _bookingId;

  CancellationPreviewNotifier(this._ref, this._bookingId)
      : super(const CancellationPreviewState());

  CancellationService get _service => _ref.read(cancellationServiceProvider);

  /// Load cancellation preview
  Future<void> loadPreview({required String requestedByRole}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final preview = await _service.previewCancellation(
        bookingId: _bookingId,
        requestedByRole: requestedByRole,
      );
      state = state.copyWith(preview: preview, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Process the actual cancellation
  Future<bool> processCancellation({
    required String cancelledBy,
    required String cancelledByRole,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _service.processBookingCancellation(
        bookingId: _bookingId,
        cancelledBy: cancelledBy,
        cancelledByRole: cancelledByRole,
        reason: reason,
      );
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for cancellation history
final cancellationHistoryProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String userId, String role})>(
  (ref, params) async {
    final service = ref.read(cancellationServiceProvider);
    return service.getCancellationHistory(
      userId: params.userId,
      role: params.role,
    );
  },
);

/// Provider for cancellation statistics (admin)
final cancellationStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(cancellationServiceProvider);
  return service.getCancellationStats();
});

/// Helper provider to calculate preview without API call
final instantCancellationPreviewProvider =
    Provider.family<CancellationResult, ({DateTime eventDate, double totalAmount, bool isClient})>(
  (ref, params) {
    final service = ref.read(cancellationServiceProvider);
    return service.calculateCancellation(
      eventDate: params.eventDate,
      totalAmount: params.totalAmount,
      isClientCancelling: params.isClient,
    );
  },
);
