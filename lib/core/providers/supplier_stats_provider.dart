import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_stats_model.dart';
import '../services/supplier_stats_service.dart';

/// State class for supplier statistics
class SupplierStatsState {
  final SupplierStatsModel? stats;
  final StatsTimePeriod? viewStats;
  final StatsTimePeriod? leadStats;
  final bool isLoading;
  final String? error;

  const SupplierStatsState({
    this.stats,
    this.viewStats,
    this.leadStats,
    this.isLoading = false,
    this.error,
  });

  SupplierStatsState copyWith({
    SupplierStatsModel? stats,
    StatsTimePeriod? viewStats,
    StatsTimePeriod? leadStats,
    bool? isLoading,
    String? error,
  }) {
    return SupplierStatsState(
      stats: stats ?? this.stats,
      viewStats: viewStats ?? this.viewStats,
      leadStats: leadStats ?? this.leadStats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for the SupplierStatsService
final supplierStatsServiceProvider = Provider<SupplierStatsService>((ref) {
  return SupplierStatsService();
});

/// Provider for supplier stats by supplier ID
final supplierStatsProvider = StateNotifierProvider.family<
    SupplierStatsNotifier, SupplierStatsState, String>(
  (ref, supplierId) => SupplierStatsNotifier(ref, supplierId),
);

/// Notifier for managing supplier stats state
class SupplierStatsNotifier extends StateNotifier<SupplierStatsState> {
  final Ref _ref;
  final String _supplierId;
  StreamSubscription? _statsSubscription;

  SupplierStatsNotifier(this._ref, this._supplierId)
      : super(const SupplierStatsState(isLoading: true)) {
    _initStats();
  }

  SupplierStatsService get _service => _ref.read(supplierStatsServiceProvider);

  void _initStats() {
    // Start listening to real-time stats updates
    _statsSubscription = _service.streamSupplierStats(_supplierId).listen(
      (stats) {
        state = state.copyWith(stats: stats, isLoading: false, error: null);
      },
      onError: (e) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      },
    );

    // Load detailed stats
    _loadDetailedStats();
  }

  Future<void> _loadDetailedStats() async {
    try {
      final viewStats = await _service.getViewStats(_supplierId);
      final leadStats = await _service.getLeadStats(_supplierId);
      state = state.copyWith(viewStats: viewStats, leadStats: leadStats);
    } catch (e) {
      // Non-critical, don't update error state
    }
  }

  /// Refresh all stats
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final stats = await _service.getSupplierStats(_supplierId);
      final viewStats = await _service.getViewStats(_supplierId);
      final leadStats = await _service.getLeadStats(_supplierId);
      state = state.copyWith(
        stats: stats,
        viewStats: viewStats,
        leadStats: leadStats,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Sync all stats from source data
  Future<void> syncStats() async {
    state = state.copyWith(isLoading: true);
    try {
      final stats = await _service.syncAllStats(_supplierId);
      state = state.copyWith(stats: stats, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Track a profile view
  Future<void> trackView(String viewerId, {String? source}) async {
    await _service.trackProfileView(
      supplierId: _supplierId,
      viewerId: viewerId,
      source: source,
    );
  }

  /// Track a contact button click
  Future<void> trackContactClick(String viewerId) async {
    await _service.trackContactClick(
      supplierId: _supplierId,
      viewerId: viewerId,
    );
  }

  /// Track a first message
  Future<void> trackFirstMessage(String viewerId) async {
    await _service.trackFirstMessage(
      supplierId: _supplierId,
      viewerId: viewerId,
    );
  }

  /// Track a WhatsApp click
  Future<void> trackWhatsAppClick(String viewerId) async {
    await _service.trackWhatsAppClick(
      supplierId: _supplierId,
      viewerId: viewerId,
    );
  }

  /// Track a call click
  Future<void> trackCallClick(String viewerId) async {
    await _service.trackCallClick(
      supplierId: _supplierId,
      viewerId: viewerId,
    );
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for tracking favorites (with automatic count update)
final favoriteActionProvider = Provider<FavoriteActionNotifier>((ref) {
  return FavoriteActionNotifier(ref);
});

class FavoriteActionNotifier {
  final Ref _ref;

  FavoriteActionNotifier(this._ref);

  SupplierStatsService get _service => _ref.read(supplierStatsServiceProvider);

  /// Add to favorites
  Future<bool> addToFavorites({
    required String supplierId,
    required String userId,
  }) async {
    return await _service.addToFavorites(
      supplierId: supplierId,
      userId: userId,
    );
  }

  /// Remove from favorites
  Future<bool> removeFromFavorites({
    required String supplierId,
    required String userId,
  }) async {
    return await _service.removeFromFavorites(
      supplierId: supplierId,
      userId: userId,
    );
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite({
    required String supplierId,
    required String userId,
    required bool currentlyFavorite,
  }) async {
    if (currentlyFavorite) {
      return await removeFromFavorites(supplierId: supplierId, userId: userId);
    } else {
      return await addToFavorites(supplierId: supplierId, userId: userId);
    }
  }
}

/// Provider for booking status changes (updates stats automatically)
final bookingStatsUpdateProvider = Provider<BookingStatsUpdateNotifier>((ref) {
  return BookingStatsUpdateNotifier(ref);
});

class BookingStatsUpdateNotifier {
  final Ref _ref;

  BookingStatsUpdateNotifier(this._ref);

  SupplierStatsService get _service => _ref.read(supplierStatsServiceProvider);

  /// Call when a booking is confirmed/paid
  Future<void> onBookingConfirmed(String supplierId) async {
    await _service.onBookingConfirmed(supplierId);
  }

  /// Call when a booking is completed
  Future<void> onBookingCompleted(String supplierId) async {
    await _service.onBookingCompleted(supplierId);
  }

  /// Recalculate all booking stats
  Future<Map<String, int>> recalculateStats(String supplierId) async {
    return await _service.recalculateBookingStats(supplierId);
  }
}

/// Simple provider for getting favorite count
final favoriteCountProvider = FutureProvider.family<int, String>((ref, supplierId) async {
  final service = ref.read(supplierStatsServiceProvider);
  return await service.getFavoriteCount(supplierId);
});

/// Stream provider for real-time stats
final supplierStatsStreamProvider = StreamProvider.family<SupplierStatsModel, String>((ref, supplierId) {
  final service = ref.read(supplierStatsServiceProvider);
  return service.streamSupplierStats(supplierId);
});
