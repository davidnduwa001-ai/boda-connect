import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';

/// UI-First Architecture: Supplier View Provider
///
/// This provider reads ONLY from the `supplier_views/{supplierId}` projection.
/// NEVER reads directly from bookings, payments, escrow, or conversations.
///
/// The backend maintains this projection via Cloud Functions triggers.

// ==================== MODELS ====================

class SupplierBookingSummary {
  final String bookingId;
  final String clientId;
  final String clientName;
  final String? clientPhotoUrl;
  final String eventName;
  final DateTime eventDate;
  final String? eventLocation;
  final String status;
  final double totalAmount;
  final String currency;
  final SupplierBookingUIFlags uiFlags;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const SupplierBookingSummary({
    required this.bookingId,
    required this.clientId,
    required this.clientName,
    this.clientPhotoUrl,
    required this.eventName,
    required this.eventDate,
    this.eventLocation,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.uiFlags,
    required this.createdAt,
    this.expiresAt,
  });

  factory SupplierBookingSummary.fromMap(Map<String, dynamic> data) {
    return SupplierBookingSummary(
      bookingId: data['bookingId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String? ?? 'Cliente',
      clientPhotoUrl: data['clientPhotoUrl'] as String?,
      eventName: data['eventName'] as String? ?? 'Evento',
      eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventLocation: data['eventLocation'] as String?,
      status: data['status'] as String? ?? 'pending',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
      uiFlags: SupplierBookingUIFlags.fromMap(
        data['uiFlags'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SupplierBookingUIFlags {
  final bool canAccept;
  final bool canDecline;
  final bool canComplete;
  final bool canCancel;
  final bool canMessage;
  final bool canViewDetails;
  final bool showExpiringSoon;
  final bool showPaymentReceived;

  const SupplierBookingUIFlags({
    this.canAccept = false,
    this.canDecline = false,
    this.canComplete = false,
    this.canCancel = false,
    this.canMessage = true,
    this.canViewDetails = true,
    this.showExpiringSoon = false,
    this.showPaymentReceived = false,
  });

  factory SupplierBookingUIFlags.fromMap(Map<String, dynamic> data) {
    return SupplierBookingUIFlags(
      canAccept: data['canAccept'] as bool? ?? false,
      canDecline: data['canDecline'] as bool? ?? false,
      canComplete: data['canComplete'] as bool? ?? false,
      canCancel: data['canCancel'] as bool? ?? false,
      canMessage: data['canMessage'] as bool? ?? true,
      canViewDetails: data['canViewDetails'] as bool? ?? true,
      showExpiringSoon: data['showExpiringSoon'] as bool? ?? false,
      showPaymentReceived: data['showPaymentReceived'] as bool? ?? false,
    );
  }
}

class SupplierEventSummary {
  final String bookingId;
  final String clientName;
  final String? clientPhotoUrl;
  final String eventName;
  final DateTime eventDate;
  final String? eventTime;
  final String? eventLocation;
  final String status;

  const SupplierEventSummary({
    required this.bookingId,
    required this.clientName,
    this.clientPhotoUrl,
    required this.eventName,
    required this.eventDate,
    this.eventTime,
    this.eventLocation,
    required this.status,
  });

  factory SupplierEventSummary.fromMap(Map<String, dynamic> data) {
    return SupplierEventSummary(
      bookingId: data['bookingId'] as String? ?? '',
      clientName: data['clientName'] as String? ?? 'Cliente',
      clientPhotoUrl: data['clientPhotoUrl'] as String?,
      eventName: data['eventName'] as String? ?? 'Evento',
      eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventTime: data['eventTime'] as String?,
      eventLocation: data['eventLocation'] as String?,
      status: data['status'] as String? ?? 'pending',
    );
  }
}

class SupplierBlockedDateSummary {
  final String id;
  final DateTime date;
  final String type;
  final String reason;
  final String? bookingId;
  final bool canUnblock;

  const SupplierBlockedDateSummary({
    required this.id,
    required this.date,
    required this.type,
    required this.reason,
    this.bookingId,
    required this.canUnblock,
  });

  factory SupplierBlockedDateSummary.fromMap(Map<String, dynamic> data) {
    return SupplierBlockedDateSummary(
      id: data['id'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] as String? ?? 'blocked',
      reason: data['reason'] as String? ?? '',
      bookingId: data['bookingId'] as String?,
      canUnblock: data['canUnblock'] as bool? ?? false,
    );
  }
}

class SupplierDashboardStats {
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double averageRating;
  final int totalReviews;
  final double responseRate;
  final int responseTimeMinutes;

  const SupplierDashboardStats({
    this.totalBookings = 0,
    this.completedBookings = 0,
    this.cancelledBookings = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.responseRate = 0,
    this.responseTimeMinutes = 0,
  });

  factory SupplierDashboardStats.fromMap(Map<String, dynamic> data) {
    return SupplierDashboardStats(
      totalBookings: data['totalBookings'] as int? ?? 0,
      completedBookings: data['completedBookings'] as int? ?? 0,
      cancelledBookings: data['cancelledBookings'] as int? ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
      totalReviews: data['totalReviews'] as int? ?? 0,
      responseRate: (data['responseRate'] as num?)?.toDouble() ?? 0,
      responseTimeMinutes: data['responseTimeMinutes'] as int? ?? 0,
    );
  }
}

class SupplierAccountFlags {
  final bool isActive;
  final bool isVerified;
  final bool isBookable;
  final bool isPaused;
  final bool hasPayoutSetup;
  final bool showVerificationNeeded;
  final bool showPayoutSetupNeeded;
  final bool showRateLimitWarning;

  const SupplierAccountFlags({
    this.isActive = false,
    this.isVerified = false,
    this.isBookable = false,
    this.isPaused = false,
    this.hasPayoutSetup = false,
    this.showVerificationNeeded = true,
    this.showPayoutSetupNeeded = true,
    this.showRateLimitWarning = false,
  });

  factory SupplierAccountFlags.fromMap(Map<String, dynamic> data) {
    return SupplierAccountFlags(
      isActive: data['isActive'] as bool? ?? false,
      isVerified: data['isVerified'] as bool? ?? false,
      isBookable: data['isBookable'] as bool? ?? false,
      isPaused: data['isPaused'] as bool? ?? false,
      hasPayoutSetup: data['hasPayoutSetup'] as bool? ?? false,
      showVerificationNeeded: data['showVerificationNeeded'] as bool? ?? true,
      showPayoutSetupNeeded: data['showPayoutSetupNeeded'] as bool? ?? true,
      showRateLimitWarning: data['showRateLimitWarning'] as bool? ?? false,
    );
  }
}

class SupplierAvailabilitySummary {
  final int availableThisMonth;
  final int reservedThisMonth;
  final int blockedThisMonth;
  final int requestedThisMonth;

  const SupplierAvailabilitySummary({
    this.availableThisMonth = 0,
    this.reservedThisMonth = 0,
    this.blockedThisMonth = 0,
    this.requestedThisMonth = 0,
  });

  factory SupplierAvailabilitySummary.fromMap(Map<String, dynamic> data) {
    return SupplierAvailabilitySummary(
      availableThisMonth: data['availableThisMonth'] as int? ?? 0,
      reservedThisMonth: data['reservedThisMonth'] as int? ?? 0,
      blockedThisMonth: data['blockedThisMonth'] as int? ?? 0,
      requestedThisMonth: data['requestedThisMonth'] as int? ?? 0,
    );
  }
}

class SupplierEarningsSummary {
  final double thisMonth;
  final double pendingPayout;
  final double totalEarned;
  final String currency;

  const SupplierEarningsSummary({
    this.thisMonth = 0,
    this.pendingPayout = 0,
    this.totalEarned = 0,
    this.currency = 'AOA',
  });

  factory SupplierEarningsSummary.fromMap(Map<String, dynamic> data) {
    return SupplierEarningsSummary(
      thisMonth: (data['thisMonth'] as num?)?.toDouble() ?? 0,
      pendingPayout: (data['pendingPayout'] as num?)?.toDouble() ?? 0,
      totalEarned: (data['totalEarned'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'AOA',
    );
  }
}

class SupplierView {
  final String supplierId;
  final String businessName;
  final String email;
  final String? photoUrl;
  final String? phone;
  final SupplierDashboardStats dashboardStats;
  final List<SupplierBookingSummary> pendingBookings;
  final List<SupplierBookingSummary> confirmedBookings;
  final List<SupplierBookingSummary> recentBookings;
  final List<SupplierEventSummary> upcomingEvents;
  final int unreadMessages;
  final int unreadNotifications;
  final int pendingBookingsCount;
  final SupplierEarningsSummary earningsSummary;
  final SupplierAvailabilitySummary availabilitySummary;
  final List<SupplierBlockedDateSummary> blockedDates;
  final SupplierAccountFlags accountFlags;
  final DateTime updatedAt;

  const SupplierView({
    required this.supplierId,
    required this.businessName,
    required this.email,
    this.photoUrl,
    this.phone,
    required this.dashboardStats,
    this.pendingBookings = const [],
    this.confirmedBookings = const [],
    this.recentBookings = const [],
    this.upcomingEvents = const [],
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.pendingBookingsCount = 0,
    required this.earningsSummary,
    required this.availabilitySummary,
    this.blockedDates = const [],
    required this.accountFlags,
    required this.updatedAt,
  });

  factory SupplierView.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final pendingBookingsList = (data['pendingBookings'] as List<dynamic>?)
            ?.map((e) => SupplierBookingSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final confirmedBookingsList = (data['confirmedBookings'] as List<dynamic>?)
            ?.map((e) => SupplierBookingSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final recentBookingsList = (data['recentBookings'] as List<dynamic>?)
            ?.map((e) => SupplierBookingSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final upcomingEventsList = (data['upcomingEvents'] as List<dynamic>?)
            ?.map((e) => SupplierEventSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final blockedDatesList = (data['blockedDates'] as List<dynamic>?)
            ?.map((e) => SupplierBlockedDateSummary.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final unreadCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};

    return SupplierView(
      supplierId: doc.id,
      businessName: data['businessName'] as String? ?? 'Fornecedor',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String?,
      dashboardStats: SupplierDashboardStats.fromMap(
        data['dashboardStats'] as Map<String, dynamic>? ?? {},
      ),
      pendingBookings: pendingBookingsList,
      confirmedBookings: confirmedBookingsList,
      recentBookings: recentBookingsList,
      upcomingEvents: upcomingEventsList,
      unreadMessages: unreadCounts['messages'] as int? ?? 0,
      unreadNotifications: unreadCounts['notifications'] as int? ?? 0,
      pendingBookingsCount: unreadCounts['pendingBookings'] as int? ?? 0,
      earningsSummary: SupplierEarningsSummary.fromMap(
        data['earningsSummary'] as Map<String, dynamic>? ?? {},
      ),
      availabilitySummary: SupplierAvailabilitySummary.fromMap(
        data['availabilitySummary'] as Map<String, dynamic>? ?? {},
      ),
      blockedDates: blockedDatesList,
      accountFlags: SupplierAccountFlags.fromMap(
        data['accountFlags'] as Map<String, dynamic>? ?? {},
      ),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory SupplierView.empty(String supplierId) {
    return SupplierView(
      supplierId: supplierId,
      businessName: 'Fornecedor',
      email: '',
      dashboardStats: const SupplierDashboardStats(),
      earningsSummary: const SupplierEarningsSummary(),
      availabilitySummary: const SupplierAvailabilitySummary(),
      accountFlags: const SupplierAccountFlags(),
      updatedAt: DateTime.now(),
    );
  }
}

// ==================== STATE ====================

class SupplierViewState {
  final SupplierView? view;
  final bool isLoading;
  final String? error;

  const SupplierViewState({
    this.view,
    this.isLoading = false,
    this.error,
  });

  SupplierViewState copyWith({
    SupplierView? view,
    bool? isLoading,
    String? error,
  }) {
    return SupplierViewState(
      view: view ?? this.view,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ==================== NOTIFIER ====================

class SupplierViewNotifier extends StateNotifier<SupplierViewState> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SupplierViewNotifier(this._ref) : super(const SupplierViewState(isLoading: true)) {
    _loadSupplierView();
  }

  Future<void> _loadSupplierView() async {
    try {
      final supplierState = _ref.read(supplierProvider);
      final supplierId = supplierState.currentSupplier?.id;

      if (supplierId == null) {
        state = state.copyWith(isLoading: false, error: 'Fornecedor não encontrado');
        return;
      }

      final doc = await _firestore.collection('supplier_views').doc(supplierId).get();

      if (doc.exists) {
        state = state.copyWith(
          view: SupplierView.fromFirestore(doc),
          isLoading: false,
        );
      } else {
        // View doesn't exist yet - will be created on first booking
        state = state.copyWith(
          view: SupplierView.empty(supplierId),
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erro ao carregar dados');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadSupplierView();
  }
}

// ==================== PROVIDERS ====================

/// Main supplier view provider - reads from supplier_views/{supplierId}
final supplierViewProvider = StateNotifierProvider<SupplierViewNotifier, SupplierViewState>((ref) {
  return SupplierViewNotifier(ref);
});

/// Stream provider for real-time supplier view updates
final supplierViewStreamProvider = StreamProvider<SupplierView?>((ref) {
  final supplierState = ref.watch(supplierProvider);
  final supplierId = supplierState.currentSupplier?.id;

  if (supplierId == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('supplier_views')
      .doc(supplierId)
      .snapshots()
      .map((doc) => doc.exists ? SupplierView.fromFirestore(doc) : null);
});

/// Pending bookings from projection (for "Pedidos Pendentes")
/// Filters out invalid bookings (totalAmount = 0 or empty bookingId)
final supplierPendingBookingsProvider = Provider<List<SupplierBookingSummary>>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  final bookings = viewState.view?.pendingBookings ?? [];
  // Filter out invalid/corrupted bookings (only check for valid bookingId)
  return bookings.where((b) => b.bookingId.isNotEmpty).toList();
});

/// Confirmed bookings from projection
/// Filters out invalid bookings (totalAmount = 0 or empty bookingId)
final supplierConfirmedBookingsProvider = Provider<List<SupplierBookingSummary>>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  final bookings = viewState.view?.confirmedBookings ?? [];
  // Filter out invalid/corrupted bookings (only check for valid bookingId)
  return bookings.where((b) => b.bookingId.isNotEmpty).toList();
});

/// Recent bookings from projection (for "Pedidos Recentes")
/// Filters out invalid bookings (totalAmount = 0 or empty bookingId)
final supplierRecentBookingsProvider = Provider<List<SupplierBookingSummary>>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  final bookings = viewState.view?.recentBookings ?? [];
  // Filter out invalid/corrupted bookings (only check for valid bookingId)
  return bookings.where((b) => b.bookingId.isNotEmpty).toList();
});

/// Upcoming events from projection (for "Próximos Eventos")
/// Filters out invalid events (empty bookingId)
final supplierUpcomingEventsProvider = Provider<List<SupplierEventSummary>>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  final events = viewState.view?.upcomingEvents ?? [];
  // Filter out invalid/corrupted events that failed to create properly
  return events.where((e) => e.bookingId.isNotEmpty).toList();
});

/// Dashboard stats from projection
final supplierDashboardStatsProvider = Provider<SupplierDashboardStats>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.dashboardStats ?? const SupplierDashboardStats();
});

/// Unread message count from projection (for badges)
final supplierUnreadMessagesProvider = Provider<int>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.unreadMessages ?? 0;
});

/// Unread notification count from projection (for badges)
/// UI-FIRST: Uses projection instead of direct Firestore query
final supplierUnreadNotificationsProvider = Provider<int>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.unreadNotifications ?? 0;
});

/// Pending bookings count from projection (for badges)
final supplierPendingCountProvider = Provider<int>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.pendingBookingsCount ?? 0;
});

/// Earnings summary from projection
final supplierEarningsSummaryProvider = Provider<SupplierEarningsSummary>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.earningsSummary ?? const SupplierEarningsSummary();
});

/// Availability summary from projection
final supplierAvailabilitySummaryProvider = Provider<SupplierAvailabilitySummary>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.availabilitySummary ?? const SupplierAvailabilitySummary();
});

/// Blocked dates from projection (for calendar)
final supplierBlockedDatesFromViewProvider = Provider<List<SupplierBlockedDateSummary>>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.blockedDates ?? [];
});

/// Account flags from projection (for alerts/warnings)
final supplierAccountFlagsProvider = Provider<SupplierAccountFlags>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  return viewState.view?.accountFlags ?? const SupplierAccountFlags();
});

/// Is supplier bookable (from projection account flags)
final isSupplierBookableFromViewProvider = Provider<bool>((ref) {
  final flags = ref.watch(supplierAccountFlagsProvider);
  return flags.isBookable;
});

/// History bookings from projection (completed, cancelled, disputed)
/// Combines all booking sources to provide complete history view
final supplierHistoryBookingsProvider = Provider<List<SupplierBookingSummary>>((ref) {
  final viewState = ref.watch(supplierViewProvider);
  if (viewState.view == null) return [];

  // Combine all booking sources
  final allBookings = <SupplierBookingSummary>{};

  // Add from all available lists
  allBookings.addAll(viewState.view!.pendingBookings);
  allBookings.addAll(viewState.view!.confirmedBookings);
  allBookings.addAll(viewState.view!.recentBookings);

  // Filter for history statuses only
  final historyStatuses = {'completed', 'cancelled', 'disputed', 'refunded'};
  final historyBookings = allBookings
      .where((b) => historyStatuses.contains(b.status) && b.bookingId.isNotEmpty)
      .toList();

  // Sort by event date descending (most recent first)
  historyBookings.sort((a, b) => b.eventDate.compareTo(a.eventDate));

  return historyBookings;
});
