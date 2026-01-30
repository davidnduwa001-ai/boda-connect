import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/payment_service.dart';

// ==================== PAYMENT SERVICE PROVIDER ====================

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

// ==================== PAYMENT STATE ====================

class PaymentState {
  final bool isInitialized;
  final bool isProcessing;
  final PaymentResult? currentPayment;
  final List<PaymentRecord> paymentHistory;
  final String? error;
  final String? successMessage;

  const PaymentState({
    this.isInitialized = false,
    this.isProcessing = false,
    this.currentPayment,
    this.paymentHistory = const [],
    this.error,
    this.successMessage,
  });

  PaymentState copyWith({
    bool? isInitialized,
    bool? isProcessing,
    PaymentResult? currentPayment,
    List<PaymentRecord>? paymentHistory,
    String? error,
    String? successMessage,
  }) {
    return PaymentState(
      isInitialized: isInitialized ?? this.isInitialized,
      isProcessing: isProcessing ?? this.isProcessing,
      currentPayment: currentPayment ?? this.currentPayment,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      error: error,
      successMessage: successMessage,
    );
  }
}

// ==================== PAYMENT NOTIFIER ====================

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentService _paymentService;

  PaymentNotifier(this._paymentService) : super(const PaymentState());

  /// Initialize payment service
  /// Uses credentials from AppConfig
  Future<void> initialize() async {
    try {
      await _paymentService.initialize();
      state = state.copyWith(isInitialized: true);
    } catch (e) {
      debugPrint('❌ Failed to initialize payment service: $e');
      state = state.copyWith(
        error: 'Falha ao inicializar pagamentos: $e',
      );
    }
  }

  /// Create a new payment for a booking
  Future<PaymentResult?> createPayment({
    required String bookingId,
    required int amount,
    required String description,
    required String customerPhone,
    String? customerEmail,
    String? customerName,
    Map<String, dynamic>? metadata,
  }) async {
    state = state.copyWith(
      isProcessing: true,
      error: null,
      successMessage: null,
    );

    try {
      final result = await _paymentService.createPayment(
        bookingId: bookingId,
        amount: amount,
        description: description,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerName: customerName,
        metadata: metadata,
      );

      state = state.copyWith(
        isProcessing: false,
        currentPayment: result,
        successMessage: 'Pagamento criado com sucesso',
      );

      return result;
    } on PaymentException catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Erro ao criar pagamento: $e',
      );
      return null;
    }
  }

  /// Check status of a payment
  Future<PaymentStatus?> checkPaymentStatus(String paymentId) async {
    try {
      final status = await _paymentService.checkPaymentStatus(paymentId);
      return status;
    } catch (e) {
      debugPrint('❌ Error checking payment status: $e');
      return null;
    }
  }

  /// Load payment history
  Future<void> loadPaymentHistory({int limit = 20}) async {
    try {
      final history = await _paymentService.getPaymentHistory(limit: limit);
      state = state.copyWith(paymentHistory: history);
    } catch (e) {
      debugPrint('❌ Error loading payment history: $e');
    }
  }

  /// Request refund for a payment
  Future<bool> requestRefund({
    required String paymentId,
    int? amount,
    String? reason,
  }) async {
    state = state.copyWith(
      isProcessing: true,
      error: null,
      successMessage: null,
    );

    try {
      final success = await _paymentService.refundPayment(
        paymentId: paymentId,
        amount: amount,
        reason: reason,
      );

      if (success) {
        state = state.copyWith(
          isProcessing: false,
          successMessage: 'Reembolso solicitado com sucesso',
        );
        // Reload payment history to reflect changes
        await loadPaymentHistory();
      } else {
        state = state.copyWith(
          isProcessing: false,
          error: 'Falha ao solicitar reembolso',
        );
      }

      return success;
    } on PaymentException catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Erro ao solicitar reembolso: $e',
      );
      return false;
    }
  }

  /// Clear current payment
  void clearCurrentPayment() {
    state = state.copyWith(currentPayment: null);
  }

  /// Clear messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ==================== PROVIDER ====================

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final paymentService = ref.watch(paymentServiceProvider);
  return PaymentNotifier(paymentService);
});

// ==================== PAYMENT STATUS STREAM PROVIDER ====================

/// Provider to watch payment status changes in real-time
final paymentStatusProvider =
    FutureProvider.family<PaymentStatus?, String>((ref, paymentId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return await paymentService.checkPaymentStatus(paymentId);
});

// ==================== PAYMENT HISTORY PROVIDER ====================

final paymentHistoryProvider =
    FutureProvider<List<PaymentRecord>>((ref) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return await paymentService.getPaymentHistory();
});
