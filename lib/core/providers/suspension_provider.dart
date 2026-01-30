import 'package:boda_connect/core/services/suspension_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for SuspensionService
final suspensionServiceProvider = Provider<SuspensionService>((ref) {
  return SuspensionService();
});

/// Provider for checking if a user should be suspended
final shouldSuspendUserProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final service = ref.watch(suspensionServiceProvider);
  return await service.shouldSuspendUser(userId);
});

/// Provider for getting user's warning level
final warningLevelProvider = FutureProvider.family<WarningLevel, String>((ref, userId) async {
  final service = ref.watch(suspensionServiceProvider);
  return await service.getWarningLevel(userId);
});

/// Provider for getting user's violations
final userViolationsProvider = FutureProvider.family<List<PolicyViolation>, String>((ref, userId) async {
  final service = ref.watch(suspensionServiceProvider);
  return await service.getUserViolations(userId);
});

/// Provider for checking if user can appeal
final canAppealProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final service = ref.watch(suspensionServiceProvider);
  return await service.canAppeal(userId);
});
