import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/services/blocked_dates_service.dart';

/// Provider for BlockedDatesService
final blockedDatesServiceProvider = Provider<BlockedDatesService>((ref) {
  return BlockedDatesService();
});

// Note: supplierBlockedDatesProvider is defined in availability_provider.dart
// Use that provider for client-facing blocked dates queries

/// State notifier for managing blocked dates
class BlockedDatesNotifier extends StateNotifier<BlockedDatesState> {
  final BlockedDatesService _service;
  final String supplierId;

  BlockedDatesNotifier(this._service, this.supplierId) : super(const BlockedDatesState()) {
    _loadBlockedDates();
  }

  Future<void> _loadBlockedDates() async {
    state = state.copyWith(isLoading: true);
    try {
      final dates = await _service.getBlockedDates(supplierId);
      state = state.copyWith(
        blockedDates: dates,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> toggleDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final isCurrentlyBlocked = state.blockedDates.any(
      (d) => d.year == normalizedDate.year &&
             d.month == normalizedDate.month &&
             d.day == normalizedDate.day,
    );

    // Optimistic update
    if (isCurrentlyBlocked) {
      state = state.copyWith(
        blockedDates: state.blockedDates.where((d) =>
          !(d.year == normalizedDate.year &&
            d.month == normalizedDate.month &&
            d.day == normalizedDate.day)
        ).toList(),
      );
    } else {
      state = state.copyWith(
        blockedDates: [...state.blockedDates, normalizedDate],
      );
    }

    // Persist to Firestore
    await _service.toggleBlockedDate(supplierId, date);
  }

  Future<void> addDateRange(DateTime startDate, DateTime endDate) async {
    state = state.copyWith(isLoading: true);
    final success = await _service.addBlockedDateRange(supplierId, startDate, endDate);
    if (success) {
      await _loadBlockedDates();
    } else {
      state = state.copyWith(isLoading: false, error: 'Failed to add date range');
    }
  }

  Future<void> clearAllDates() async {
    state = state.copyWith(isLoading: true);
    final success = await _service.clearAllBlockedDates(supplierId);
    if (success) {
      state = state.copyWith(blockedDates: [], isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, error: 'Failed to clear dates');
    }
  }

  bool isDateBlocked(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return state.blockedDates.any(
      (d) => d.year == normalizedDate.year &&
             d.month == normalizedDate.month &&
             d.day == normalizedDate.day,
    );
  }

  void refresh() {
    _loadBlockedDates();
  }
}

/// State for blocked dates
class BlockedDatesState {
  final List<DateTime> blockedDates;
  final bool isLoading;
  final String? error;

  const BlockedDatesState({
    this.blockedDates = const [],
    this.isLoading = false,
    this.error,
  });

  BlockedDatesState copyWith({
    List<DateTime>? blockedDates,
    bool? isLoading,
    String? error,
  }) {
    return BlockedDatesState(
      blockedDates: blockedDates ?? this.blockedDates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider family for blocked dates notifier
final blockedDatesNotifierProvider = StateNotifierProvider.family<BlockedDatesNotifier, BlockedDatesState, String>(
  (ref, supplierId) {
    final service = ref.watch(blockedDatesServiceProvider);
    return BlockedDatesNotifier(service, supplierId);
  },
);
