import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_method_model.dart';
import '../repositories/payment_method_repository.dart';
import 'supplier_provider.dart';

// ==================== REPOSITORY PROVIDER ====================

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>((ref) {
  return PaymentMethodRepository();
});

// ==================== PAYMENT METHOD STATE ====================

class PaymentMethodState {
  final List<PaymentMethodModel> paymentMethods;
  final bool isLoading;
  final String? error;

  const PaymentMethodState({
    this.paymentMethods = const [],
    this.isLoading = false,
    this.error,
  });

  PaymentMethodState copyWith({
    List<PaymentMethodModel>? paymentMethods,
    bool? isLoading,
    String? error,
  }) {
    return PaymentMethodState(
      paymentMethods: paymentMethods ?? this.paymentMethods,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  PaymentMethodModel? get defaultPaymentMethod {
    try {
      return paymentMethods.firstWhere((pm) => pm.isDefault);
    } catch (e) {
      return null;
    }
  }
}

// ==================== PAYMENT METHOD NOTIFIER ====================

class PaymentMethodNotifier extends StateNotifier<PaymentMethodState> {
  final PaymentMethodRepository _repository;
  final Ref _ref;

  PaymentMethodNotifier(this._repository, this._ref)
      : super(const PaymentMethodState());

  // Load payment methods
  Future<void> loadPaymentMethods() async {
    final supplierId = _ref.read(supplierProvider).currentSupplier?.id;
    if (supplierId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final paymentMethods = await _repository.getPaymentMethods(supplierId);
      state = state.copyWith(
        paymentMethods: paymentMethods,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading payment methods: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar métodos de pagamento',
      );
    }
  }

  // Add payment method
  Future<String?> addPaymentMethod(PaymentMethodModel paymentMethod) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final id = await _repository.addPaymentMethod(paymentMethod);

      if (id != null) {
        // Reload payment methods
        await loadPaymentMethods();
        return id;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao adicionar método de pagamento',
      );
      return null;
    } catch (e) {
      debugPrint('❌ Error adding payment method: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao adicionar método de pagamento',
      );
      return null;
    }
  }

  // Update payment method
  Future<bool> updatePaymentMethod(
    String paymentMethodId,
    Map<String, dynamic> updates,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final success = await _repository.updatePaymentMethod(
        paymentMethodId,
        updates,
      );

      if (success) {
        // Reload payment methods
        await loadPaymentMethods();
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao atualizar método de pagamento',
      );
      return false;
    } catch (e) {
      debugPrint('❌ Error updating payment method: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao atualizar método de pagamento',
      );
      return false;
    }
  }

  // Delete payment method
  Future<bool> deletePaymentMethod(String paymentMethodId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final success = await _repository.deletePaymentMethod(paymentMethodId);

      if (success) {
        // Remove from local state
        final updatedMethods = state.paymentMethods
            .where((pm) => pm.id != paymentMethodId)
            .toList();

        state = state.copyWith(
          paymentMethods: updatedMethods,
          isLoading: false,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao eliminar método de pagamento',
      );
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting payment method: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao eliminar método de pagamento',
      );
      return false;
    }
  }

  // Set default payment method
  Future<bool> setDefaultPaymentMethod(String paymentMethodId) async {
    final supplierId = _ref.read(supplierProvider).currentSupplier?.id;
    if (supplierId == null) return false;

    try {
      state = state.copyWith(isLoading: true, error: null);

      final success = await _repository.setDefaultPaymentMethod(
        supplierId,
        paymentMethodId,
      );

      if (success) {
        // Reload payment methods
        await loadPaymentMethods();
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao definir método padrão',
      );
      return false;
    } catch (e) {
      debugPrint('❌ Error setting default payment method: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao definir método padrão',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ==================== PROVIDERS ====================

final paymentMethodProvider =
    StateNotifierProvider<PaymentMethodNotifier, PaymentMethodState>((ref) {
  final repository = ref.watch(paymentMethodRepositoryProvider);
  return PaymentMethodNotifier(repository, ref);
});

// Stream provider for real-time updates
final paymentMethodsStreamProvider =
    StreamProvider<List<PaymentMethodModel>>((ref) {
  final supplierId = ref.watch(supplierProvider).currentSupplier?.id;
  if (supplierId == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(paymentMethodRepositoryProvider);
  return repository.getPaymentMethodsStream(supplierId);
});
