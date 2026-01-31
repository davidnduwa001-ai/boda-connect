import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI-First Architecture: Client View Provider
///
/// This provider reads ONLY from the `client_views/{clientId}` projection.
/// NEVER reads directly from bookings, payments, escrow, or conversations.
///
/// The backend maintains this projection via Cloud Functions triggers.

// ==================== MODELS ====================

class ClientBookingSummary {
  final String bookingId;
  final String supplierId;
  final String supplierName;
  final String? supplierPhotoUrl;
  final String categoryName;
  final String eventName;
  final DateTime eventDate;
  final String status;
  final double totalAmount;
  final String currency;
  final ClientBookingUIFlags uiFlags;
  final DateTime createdAt;

  const ClientBookingSummary({
    required this.bookingId,
    required this.supplierId,
    required this.supplierName,
    this.supplierPhotoUrl,
    required this.categoryName,
    required this.eventName,
    required this.eventDate,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.uiFlags,
    required this.createdAt,
  });

  factory ClientBookingSummary.fromMap(Map<String, dynamic> data) {
    return ClientBookingSummary(
      bookingId: data['bookingId'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      supplierName: data['supplierName'] as String? ?? 'Fornecedor',
      supplierPhotoUrl: data['supplierPhotoUrl'] as String?,
      categoryName: data['categoryName'] as String? ?? '',
      eventName: data['eventName'] as String? ?? 'Evento',
      eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
      uiFlags: ClientBookingUIFlags.fromMap(
        data['uiFlags'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ClientBookingUIFlags {
  final bool canCancel;
  final bool canPay;
  final bool canReview;
  final bool canMessage;
  final bool canViewDetails;
  final bool canRequestRefund;
  final bool showPaymentPending;
  final bool showEscrowHeld;

  const ClientBookingUIFlags({
    this.canCancel = false,
    this.canPay = false,
    this.canReview = false,
    this.canMessage = true,
    this.canViewDetails = true,
    this.canRequestRefund = false,
    this.showPaymentPending = false,
    this.showEscrowHeld = false,
  });

  factory ClientBookingUIFlags.fromMap(Map<String, dynamic> data) {
    return ClientBookingUIFlags(
      canCancel: data['canCancel'] as bool? ?? false,
      canPay: data['canPay'] as bool? ?? false,
      canReview: data['canReview'] as bool? ?? false,
      canMessage: data['canMessage'] as bool? ?? true,
      canViewDetails: data['canViewDetails'] as bool? ?? true,
      canRequestRefund: data['canRequestRefund'] as bool? ?? false,
      showPaymentPending: data['showPaymentPending'] as bool? ?? false,
      showEscrowHeld: data['showEscrowHeld'] as bool? ?? false,
    );
  }
}

class ClientEventSummary {
  final String bookingId;
  final String supplierName;
  final String? supplierPhotoUrl;
  final String eventName;
  final DateTime eventDate;
  final String? eventLocation;
  final String status;

  const ClientEventSummary({
    required this.bookingId,
    required this.supplierName,
    this.supplierPhotoUrl,
    required this.eventName,
    required this.eventDate,
    this.eventLocation,
    required this.status,
  });

  factory ClientEventSummary.fromMap(Map<String, dynamic> data) {
    return ClientEventSummary(
      bookingId: data['bookingId'] as String? ?? '',
      supplierName: data['supplierName'] as String? ?? 'Fornecedor',
      supplierPhotoUrl: data['supplierPhotoUrl'] as String?,
      eventName: data['eventName'] as String? ?? 'Evento',
      eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventLocation: data['eventLocation'] as String?,
      status: data['status'] as String? ?? 'pending',
    );
  }
}

class ClientView {
  final String clientId;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? phone;
  final List<ClientBookingSummary> activeBookings;
  final List<ClientBookingSummary> recentBookings;
  final List<ClientEventSummary> upcomingEvents;
  final int unreadMessages;
  final int unreadNotifications;
  final double pendingPayments;
  final double totalSpent;
  final double escrowHeld;
  final int cartItemCount;
  final DateTime updatedAt;

  const ClientView({
    required this.clientId,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.phone,
    this.activeBookings = const [],
    this.recentBookings = const [],
    this.upcomingEvents = const [],
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.pendingPayments = 0,
    this.totalSpent = 0,
    this.escrowHeld = 0,
    this.cartItemCount = 0,
    required this.updatedAt,
  });

  factory ClientView.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final activeBookingsList = (data['activeBookings'] as List<dynamic>?)
            ?.map((e) => ClientBookingSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final recentBookingsList = (data['recentBookings'] as List<dynamic>?)
            ?.map((e) => ClientBookingSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final upcomingEventsList = (data['upcomingEvents'] as List<dynamic>?)
            ?.map((e) => ClientEventSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final unreadCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    final paymentSummary = data['paymentSummary'] as Map<String, dynamic>? ?? {};

    return ClientView(
      clientId: doc.id,
      displayName: data['displayName'] as String? ?? 'Cliente',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
      activeBookings: activeBookingsList,
      recentBookings: recentBookingsList,
      upcomingEvents: upcomingEventsList,
      unreadMessages: unreadCounts['messages'] as int? ?? 0,
      unreadNotifications: unreadCounts['notifications'] as int? ?? 0,
      pendingPayments: (paymentSummary['pendingPayments'] as num?)?.toDouble() ?? 0,
      totalSpent: (paymentSummary['totalSpent'] as num?)?.toDouble() ?? 0,
      escrowHeld: (paymentSummary['escrowHeld'] as num?)?.toDouble() ?? 0,
      cartItemCount: data['cartItemCount'] as int? ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ClientView.empty(String clientId) {
    return ClientView(
      clientId: clientId,
      displayName: 'Cliente',
      email: '',
      updatedAt: DateTime.now(),
    );
  }
}

// ==================== STATE ====================

class ClientViewState {
  final ClientView? view;
  final bool isLoading;
  final String? error;

  const ClientViewState({
    this.view,
    this.isLoading = false,
    this.error,
  });

  ClientViewState copyWith({
    ClientView? view,
    bool? isLoading,
    String? error,
  }) {
    return ClientViewState(
      view: view ?? this.view,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ==================== NOTIFIER ====================

class ClientViewNotifier extends StateNotifier<ClientViewState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ClientViewNotifier() : super(const ClientViewState(isLoading: true)) {
    _loadClientView();
  }

  Future<void> _loadClientView() async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false, error: 'Usuário não autenticado');
      return;
    }

    try {
      final doc = await _firestore.collection('client_views').doc(user.uid).get();

      if (doc.exists) {
        state = state.copyWith(
          view: ClientView.fromFirestore(doc),
          isLoading: false,
        );
      } else {
        // View doesn't exist yet - will be created on first booking
        state = state.copyWith(
          view: ClientView.empty(user.uid),
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erro ao carregar dados');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadClientView();
  }
}

// ==================== PROVIDERS ====================

/// Main client view provider - reads from client_views/{clientId}
final clientViewProvider = StateNotifierProvider<ClientViewNotifier, ClientViewState>((ref) {
  return ClientViewNotifier();
});

/// Stream provider for real-time client view updates
final clientViewStreamProvider = StreamProvider<ClientView?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('client_views')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? ClientView.fromFirestore(doc) : null);
});

// ==================== REAL-TIME DERIVED PROVIDERS ====================
// All providers below use clientViewStreamProvider for real-time updates

/// Active bookings from projection (for dashboard)
/// REAL-TIME: Updates automatically when projection changes
final clientActiveBookingsProvider = Provider<List<ClientBookingSummary>>((ref) {
  final view = ref.watch(clientViewStreamProvider).valueOrNull;
  return view?.activeBookings ?? [];
});

/// Recent bookings from projection (for "Pedidos Recentes")
/// REAL-TIME: Updates automatically when projection changes
final clientRecentBookingsProvider = Provider<List<ClientBookingSummary>>((ref) {
  final view = ref.watch(clientViewStreamProvider).valueOrNull;
  return view?.recentBookings ?? [];
});

/// Upcoming events from projection (for "Próximos Eventos")
/// REAL-TIME: Updates automatically when projection changes
final clientUpcomingEventsProvider = Provider<List<ClientEventSummary>>((ref) {
  final view = ref.watch(clientViewStreamProvider).valueOrNull;
  return view?.upcomingEvents ?? [];
});

/// Unread message count from projection (for badges)
/// REAL-TIME: Updates automatically when projection changes
final clientUnreadMessagesProvider = Provider<int>((ref) {
  final view = ref.watch(clientViewStreamProvider).valueOrNull;
  return view?.unreadMessages ?? 0;
});

/// Unread notification count from projection (for badges)
/// REAL-TIME: Updates automatically when projection changes
final clientUnreadNotificationsProvider = Provider<int>((ref) {
  final view = ref.watch(clientViewStreamProvider).valueOrNull;
  return view?.unreadNotifications ?? 0;
});

/// Cart item count from projection
/// REAL-TIME: Updates automatically when projection changes
final clientCartCountProvider = Provider<int>((ref) {
  final view = ref.watch(clientViewStreamProvider).valueOrNull;
  return view?.cartItemCount ?? 0;
});

/// Payment summary from projection
/// REAL-TIME: Updates automatically when projection changes
final clientPaymentSummaryProvider = Provider<Map<String, double>>((ref) {
  final view = ref.watch(clientViewStreamProvider).valueOrNull;
  return {
    'pending': view?.pendingPayments ?? 0,
    'spent': view?.totalSpent ?? 0,
    'escrow': view?.escrowHeld ?? 0,
  };
});
