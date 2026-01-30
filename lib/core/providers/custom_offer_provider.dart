import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/models/custom_offer_model.dart';
import 'package:boda_connect/core/repositories/custom_offer_repository.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';

// ==================== REPOSITORY PROVIDER ====================

final customOfferRepositoryProvider = Provider<CustomOfferRepository>((ref) {
  return CustomOfferRepository();
});

// ==================== CHAT OFFERS STATE ====================

/// State for offers within a specific chat
class ChatOffersState {
  final List<CustomOfferModel> offers;
  final bool isLoading;
  final bool isCreating;
  final bool isProcessing;
  final String? error;
  final String? successMessage;

  const ChatOffersState({
    this.offers = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.isProcessing = false,
    this.error,
    this.successMessage,
  });

  ChatOffersState copyWith({
    List<CustomOfferModel>? offers,
    bool? isLoading,
    bool? isCreating,
    bool? isProcessing,
    String? error,
    String? successMessage,
  }) {
    return ChatOffersState(
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      successMessage: successMessage,
    );
  }

  /// Get pending offers
  List<CustomOfferModel> get pendingOffers =>
      offers.where((o) => o.status == OfferStatus.pending && o.isValid).toList();

  /// Get the latest pending offer (if any)
  CustomOfferModel? get latestPendingOffer =>
      pendingOffers.isNotEmpty ? pendingOffers.first : null;
}

/// Notifier for managing offers within a chat
class ChatOffersNotifier extends StateNotifier<ChatOffersState> {
  final CustomOfferRepository _repository;
  final Ref _ref;
  final String chatId;
  StreamSubscription? _offersSubscription;

  ChatOffersNotifier(this._repository, this._ref, this.chatId)
      : super(const ChatOffersState()) {
    _startListening();
  }

  /// Start listening to offers for this chat
  void _startListening() {
    state = state.copyWith(isLoading: true);

    _offersSubscription?.cancel();
    _offersSubscription = _repository.streamChatOffers(chatId).listen(
      (offers) {
        state = state.copyWith(
          offers: offers,
          isLoading: false,
        );
      },
      onError: (e) {
        state = state.copyWith(
          isLoading: false,
          error: 'Erro ao carregar ofertas',
        );
      },
    );
  }

  /// Create a new custom offer or price proposal
  /// Can be created by supplier (offer) or client (price proposal)
  Future<({String offerId, String messageId})?> createOffer({
    required String sellerId,
    required String buyerId,
    required String sellerName,
    String? buyerName,
    required int customPrice,
    required String description,
    String? basePackageId,
    String? basePackageName,
    String? deliveryTime,
    DateTime? eventDate,
    String? eventName,
    DateTime? validUntil,
    String? initiatedBy, // 'seller' or 'buyer'
  }) async {
    state = state.copyWith(isCreating: true, error: null);

    try {
      final result = await _repository.createOffer(
        chatId: chatId,
        sellerId: sellerId,
        buyerId: buyerId,
        sellerName: sellerName,
        buyerName: buyerName,
        customPrice: customPrice,
        description: description,
        basePackageId: basePackageId,
        basePackageName: basePackageName,
        deliveryTime: deliveryTime,
        eventDate: eventDate,
        eventName: eventName,
        validUntil: validUntil,
        initiatedBy: initiatedBy,
      );

      state = state.copyWith(
        isCreating: false,
        successMessage: 'Proposta enviada com sucesso!',
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  /// Accept an offer (buyer only)
  Future<String?> acceptOffer({
    required String offerId,
    required String eventName,
    required DateTime eventDate,
    String? eventLocation,
    String? notes,
  }) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) {
      state = state.copyWith(error: 'Usuário não autenticado');
      return null;
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final bookingId = await _repository.acceptOffer(
        offerId: offerId,
        buyerId: userId,
        eventName: eventName,
        eventDate: eventDate,
        eventLocation: eventLocation,
        notes: notes,
      );

      state = state.copyWith(
        isProcessing: false,
        successMessage: 'Proposta aceite! Reserva criada.',
      );

      return bookingId;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  /// Reject an offer (buyer only)
  Future<bool> rejectOffer({
    required String offerId,
    String? reason,
  }) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) {
      state = state.copyWith(error: 'Usuário não autenticado');
      return false;
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      await _repository.rejectOffer(
        offerId: offerId,
        buyerId: userId,
        reason: reason,
      );

      state = state.copyWith(
        isProcessing: false,
        successMessage: 'Proposta rejeitada.',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Cancel an offer (seller only)
  Future<bool> cancelOffer(String offerId) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) {
      state = state.copyWith(error: 'Usuário não autenticado');
      return false;
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      await _repository.cancelOffer(
        offerId: offerId,
        sellerId: userId,
      );

      state = state.copyWith(
        isProcessing: false,
        successMessage: 'Proposta cancelada.',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Clear messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }

  @override
  void dispose() {
    _offersSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for offers in a specific chat
final chatOffersProvider = StateNotifierProvider.family<ChatOffersNotifier, ChatOffersState, String>((ref, chatId) {
  final repository = ref.watch(customOfferRepositoryProvider);
  return ChatOffersNotifier(repository, ref, chatId);
});

// ==================== BUYER PENDING OFFERS ====================

/// State for all pending offers for a buyer
class BuyerPendingOffersState {
  final List<CustomOfferModel> offers;
  final bool isLoading;
  final String? error;

  const BuyerPendingOffersState({
    this.offers = const [],
    this.isLoading = false,
    this.error,
  });

  BuyerPendingOffersState copyWith({
    List<CustomOfferModel>? offers,
    bool? isLoading,
    String? error,
  }) {
    return BuyerPendingOffersState(
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get count => offers.length;
}

class BuyerPendingOffersNotifier extends StateNotifier<BuyerPendingOffersState> {
  final CustomOfferRepository _repository;
  final Ref _ref;

  BuyerPendingOffersNotifier(this._repository, this._ref)
      : super(const BuyerPendingOffersState());

  /// Load pending offers for the current user (buyer)
  Future<void> loadPendingOffers() async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final offers = await _repository.getPendingOffersForBuyer(userId);
      state = state.copyWith(
        offers: offers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar propostas',
      );
    }
  }

  /// Refresh offers
  Future<void> refresh() => loadPendingOffers();
}

final buyerPendingOffersProvider = StateNotifierProvider<BuyerPendingOffersNotifier, BuyerPendingOffersState>((ref) {
  final repository = ref.watch(customOfferRepositoryProvider);
  return BuyerPendingOffersNotifier(repository, ref);
});

/// Count of pending offers for the buyer (useful for badges)
final pendingOffersCountProvider = Provider<int>((ref) {
  return ref.watch(buyerPendingOffersProvider).count;
});

// ==================== SELLER OFFERS ====================

/// State for offers created by a seller
class SellerOffersState {
  final List<CustomOfferModel> offers;
  final bool isLoading;
  final String? error;

  const SellerOffersState({
    this.offers = const [],
    this.isLoading = false,
    this.error,
  });

  SellerOffersState copyWith({
    List<CustomOfferModel>? offers,
    bool? isLoading,
    String? error,
  }) {
    return SellerOffersState(
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get offers by status
  List<CustomOfferModel> getByStatus(OfferStatus status) =>
      offers.where((o) => o.status == status).toList();

  int get pendingCount => getByStatus(OfferStatus.pending).length;
  int get acceptedCount => getByStatus(OfferStatus.accepted).length;
  int get rejectedCount => getByStatus(OfferStatus.rejected).length;
}

class SellerOffersNotifier extends StateNotifier<SellerOffersState> {
  final CustomOfferRepository _repository;
  final Ref _ref;

  SellerOffersNotifier(this._repository, this._ref)
      : super(const SellerOffersState());

  /// Load offers for the current user (seller)
  Future<void> loadOffers({OfferStatus? status}) async {
    final userId = _ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final offers = await _repository.getSellerOffers(userId, status: status);
      state = state.copyWith(
        offers: offers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao carregar propostas',
      );
    }
  }

  /// Refresh offers
  Future<void> refresh() => loadOffers();
}

final sellerOffersProvider = StateNotifierProvider<SellerOffersNotifier, SellerOffersState>((ref) {
  final repository = ref.watch(customOfferRepositoryProvider);
  return SellerOffersNotifier(repository, ref);
});

// ==================== SINGLE OFFER PROVIDER ====================

/// Provider to get a specific offer by ID
final offerByIdProvider = FutureProvider.family<CustomOfferModel?, String>((ref, offerId) async {
  final repository = ref.watch(customOfferRepositoryProvider);
  return repository.getOffer(offerId);
});
