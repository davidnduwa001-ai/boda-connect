import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/safety_score_model.dart';
import '../repositories/safety_score_repository.dart';

// ==================== REPOSITORY PROVIDER ====================

final safetyScoreRepositoryProvider = Provider<SafetyScoreRepository>((ref) {
  return SafetyScoreRepository();
});

// ==================== SAFETY SCORE STATE ====================

class SafetyScoreState {
  final SafetyScoreModel? score;
  final bool isLoading;
  final String? error;

  const SafetyScoreState({
    this.score,
    this.isLoading = false,
    this.error,
  });

  SafetyScoreState copyWith({
    SafetyScoreModel? score,
    bool? isLoading,
    String? error,
  }) {
    return SafetyScoreState(
      score: score ?? this.score,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ==================== SAFETY SCORE NOTIFIER ====================

class SafetyScoreNotifier extends StateNotifier<SafetyScoreState> {
  final SafetyScoreRepository _repository;

  SafetyScoreNotifier(this._repository) : super(const SafetyScoreState());

  /// Calculate safety score for a user
  Future<SafetyScoreModel?> calculateSafetyScore(String userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final score = await _repository.calculateSafetyScore(userId);

      if (score != null) {
        state = state.copyWith(score: score, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Erro ao calcular pontuação de segurança',
        );
      }

      return score;
    } catch (e) {
      debugPrint('❌ Error calculating safety score: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao calcular pontuação de segurança',
      );
      return null;
    }
  }

  /// Load safety score for a user
  Future<void> loadSafetyScore(String userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final score = await _repository.getSafetyScore(userId);

      state = state.copyWith(
        score: score,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading safety score: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar pontuação de segurança',
      );
    }
  }

  /// Check thresholds and trigger automated actions
  Future<List<String>> checkThresholdsAndTriggerActions(String userId) async {
    try {
      final actions = await _repository.checkThresholdsAndTriggerActions(userId);

      // Reload score after actions
      if (actions.isNotEmpty) {
        await loadSafetyScore(userId);
      }

      return actions;
    } catch (e) {
      debugPrint('❌ Error checking thresholds: $e');
      return [];
    }
  }

  /// Award a badge to a user
  Future<void> awardBadge(String userId, BadgeType badgeType) async {
    try {
      await _repository.awardBadge(userId, badgeType);

      // Reload score after awarding badge
      await loadSafetyScore(userId);
    } catch (e) {
      debugPrint('❌ Error awarding badge: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ==================== PROVIDERS ====================

final safetyScoreProvider = StateNotifierProvider<SafetyScoreNotifier, SafetyScoreState>((ref) {
  final repository = ref.watch(safetyScoreRepositoryProvider);
  return SafetyScoreNotifier(repository);
});

/// Provider for a specific user's safety score
///
/// @deprecated UI-FIRST VIOLATION: safetyScores collection is ADMIN/BACKEND-ONLY.
/// Client/Supplier UI should NOT read safety scores directly.
/// Returns null to avoid PERMISSION_DENIED errors.
@Deprecated('safetyScores is admin-only. Do not use in client/supplier UI.')
final userSafetyScoreProvider = FutureProvider.family<SafetyScoreModel?, String>((ref, userId) async {
  // UI-FIRST: safetyScores is admin-only, return null to avoid permission errors
  debugPrint('⚠️ userSafetyScoreProvider is deprecated - safetyScores is admin-only');
  return null;
});

/// Provider to check if user is in good standing
///
/// @deprecated UI-FIRST VIOLATION: safetyScores collection is ADMIN/BACKEND-ONLY.
/// Returns true (good standing) as safe default.
@Deprecated('safetyScores is admin-only. Assume good standing in UI.')
final isInGoodStandingProvider = FutureProvider.family<bool, String>((ref, userId) async {
  // UI-FIRST: Assume user is in good standing (backend will enforce if not)
  return true;
});

/// Provider to check if user is suspended
///
/// @deprecated UI-FIRST VIOLATION: safetyScores collection is ADMIN/BACKEND-ONLY.
/// Returns false as safe default. Backend enforces suspension via eligibility.
@Deprecated('safetyScores is admin-only. Check supplierAccountFlagsProvider.isActive instead.')
final isSuspendedProvider = FutureProvider.family<bool, String>((ref, userId) async {
  // UI-FIRST: Return false. Backend enforces suspension via Cloud Functions
  return false;
});

/// Provider to check if user is on probation
///
/// @deprecated UI-FIRST VIOLATION: safetyScores collection is ADMIN/BACKEND-ONLY.
/// Returns false as safe default.
@Deprecated('safetyScores is admin-only. Do not use in client/supplier UI.')
final isOnProbationProvider = FutureProvider.family<bool, String>((ref, userId) async {
  // UI-FIRST: Return false. Backend handles probation internally
  return false;
});
