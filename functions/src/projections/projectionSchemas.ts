/**
 * UI-First Projection Schemas
 *
 * These schemas define the structure of client_views and supplier_views collections.
 * UI reads ONLY from these projections - never directly from bookings, payments, escrow, or conversations.
 *
 * Backend maintains these projections on every relevant event via Cloud Functions triggers.
 *
 * INVARIANTS:
 * 1. All arrays are pre-sorted by backend (UI must not sort)
 * 2. All writes use merge:false for idempotency
 * 3. Meta field tracks rebuild reason for debugging
 */

// ==================== PROJECTION METADATA ====================

/**
 * Metadata for debugging and QA verification
 * Included in every projection document
 */
export interface ProjectionMeta {
  rebuiltAt: FirebaseFirestore.Timestamp;
  sourceVersion: string;
  reason: "trigger" | "backfill" | "manual";
}

// ==================== CLIENT VIEW SCHEMA ====================

/**
 * Collection: client_views/{clientId}
 *
 * Single document per client containing all UI-relevant data.
 * Updated by Cloud Functions on booking/payment/message events.
 */
export interface ClientView {
  // Client identity
  clientId: string;
  displayName: string;
  email: string;
  photoUrl: string | null;
  phone: string | null;

  // Active bookings summary (for dashboard)
  activeBookings: ClientBookingSummary[];

  // Recent bookings (last 10, for "Pedidos Recentes")
  recentBookings: ClientBookingSummary[];

  // Upcoming events (next 5, for "Pr imos Eventos")
  upcomingEvents: ClientEventSummary[];

  // Unread counts (for badges)
  unreadCounts: {
    messages: number;
    notifications: number;
  };

  // Payment summary
  paymentSummary: {
    pendingPayments: number;
    totalSpent: number;
    escrowHeld: number;
  };

  // Cart state (denormalized)
  cartItemCount: number;

  // Last updated timestamp
  updatedAt: FirebaseFirestore.Timestamp;

  // Projection metadata (for debugging/QA)
  meta?: ProjectionMeta;
}

/**
 * Booking summary for client view (minimal fields for UI)
 */
export interface ClientBookingSummary {
  bookingId: string;
  supplierId: string;
  supplierName: string;
  supplierPhotoUrl: string | null;
  categoryName: string;
  eventName: string;
  eventDate: FirebaseFirestore.Timestamp;
  status: BookingStatusForUI;
  totalAmount: number;
  currency: string;

  // UI Flags - buttons map 1:1 to these
  uiFlags: ClientBookingUIFlags;

  createdAt: FirebaseFirestore.Timestamp;
}

/**
 * Event summary for "Pr imos Eventos" widget
 */
export interface ClientEventSummary {
  bookingId: string;
  supplierName: string;
  supplierPhotoUrl: string | null;
  eventName: string;
  eventDate: FirebaseFirestore.Timestamp;
  eventLocation: string | null;
  status: BookingStatusForUI;
}

/**
 * UI Flags for client booking actions
 * Each flag maps 1:1 to a button in the UI
 */
export interface ClientBookingUIFlags {
  canCancel: boolean;
  canPay: boolean;
  canReview: boolean;
  canMessage: boolean;
  canViewDetails: boolean;
  canRequestRefund: boolean;
  showPaymentPending: boolean;
  showEscrowHeld: boolean;
}

// ==================== SUPPLIER VIEW SCHEMA ====================

/**
 * Collection: supplier_views/{supplierId}
 *
 * Single document per supplier containing all UI-relevant data.
 * Updated by Cloud Functions on booking/payment/review events.
 */
export interface SupplierView {
  // Supplier identity
  supplierId: string;
  businessName: string;
  email: string;
  photoUrl: string | null;
  phone: string | null;

  // Dashboard stats (real-time)
  dashboardStats: SupplierDashboardStats;

  // Active bookings (pending action)
  pendingBookings: SupplierBookingSummary[];

  // Confirmed bookings (upcoming work)
  confirmedBookings: SupplierBookingSummary[];

  // Recent bookings (last 10, for "Pedidos Recentes")
  recentBookings: SupplierBookingSummary[];

  // Upcoming events (next 5, for "Pr imos Eventos")
  upcomingEvents: SupplierEventSummary[];

  // Unread counts (for badges)
  unreadCounts: {
    messages: number;
    notifications: number;
    pendingBookings: number;
  };

  // Earnings summary
  earningsSummary: {
    thisMonth: number;
    pendingPayout: number;
    totalEarned: number;
    currency: string;
  };

  // Availability summary (for quick view)
  availabilitySummary: {
    availableThisMonth: number;
    reservedThisMonth: number;
    blockedThisMonth: number;
    requestedThisMonth: number;
  };

  // Blocked dates (for calendar, max 60 days ahead)
  blockedDates: SupplierBlockedDateSummary[];

  // Account status flags
  accountFlags: SupplierAccountFlags;

  // Last updated timestamp
  updatedAt: FirebaseFirestore.Timestamp;

  // Projection metadata (for debugging/QA)
  meta?: ProjectionMeta;
}

/**
 * Dashboard stats for supplier home screen
 */
export interface SupplierDashboardStats {
  totalBookings: number;
  completedBookings: number;
  cancelledBookings: number;
  averageRating: number;
  totalReviews: number;
  responseRate: number;
  responseTimeMinutes: number;
}

/**
 * Booking summary for supplier view
 */
export interface SupplierBookingSummary {
  bookingId: string;
  clientId: string;
  clientName: string;
  clientPhotoUrl: string | null;
  eventName: string;
  eventDate: FirebaseFirestore.Timestamp;
  eventLocation: string | null;
  status: BookingStatusForUI;
  totalAmount: number;
  currency: string;

  // UI Flags - buttons map 1:1 to these
  uiFlags: SupplierBookingUIFlags;

  // Timing info
  createdAt: FirebaseFirestore.Timestamp;
  expiresAt: FirebaseFirestore.Timestamp | null; // For pending bookings
}

/**
 * Event summary for supplier "Pr imos Eventos"
 */
export interface SupplierEventSummary {
  bookingId: string;
  clientName: string;
  clientPhotoUrl: string | null;
  eventName: string;
  eventDate: FirebaseFirestore.Timestamp;
  eventLocation: string | null;
  status: BookingStatusForUI;
}

/**
 * Blocked date for supplier calendar
 */
export interface SupplierBlockedDateSummary {
  id: string;
  date: FirebaseFirestore.Timestamp;
  type: "reserved" | "blocked" | "unavailable" | "requested";
  reason: string;
  bookingId: string | null;
  canUnblock: boolean;
}

/**
 * UI Flags for supplier booking actions
 * Each flag maps 1:1 to a button in the UI
 */
export interface SupplierBookingUIFlags {
  canAccept: boolean;
  canDecline: boolean;
  canComplete: boolean;
  canCancel: boolean;
  canMessage: boolean;
  canViewDetails: boolean;
  showExpiringSoon: boolean; // < 24h to respond
  showPaymentReceived: boolean;
}

/**
 * Account status flags for supplier
 */
export interface SupplierAccountFlags {
  isActive: boolean;
  isVerified: boolean;
  isBookable: boolean; // From backend eligibility gate
  isPaused: boolean;
  hasPayoutSetup: boolean;

  // Warnings/alerts
  showVerificationNeeded: boolean;
  showPayoutSetupNeeded: boolean;
  showRateLimitWarning: boolean;
}

// ==================== SHARED TYPES ====================

/**
 * Booking status as seen by UI
 * Simplified from internal status for display
 */
export type BookingStatusForUI =
  | "pending"      // Awaiting supplier response
  | "confirmed"    // Accepted, upcoming
  | "inProgress"   // Event day
  | "completed"    // Successfully finished
  | "cancelled"    // Cancelled by either party
  | "expired"      // Auto-expired (no response)
  | "disputed";    // Under dispute

/**
 * Maps internal booking status to UI status
 */
export function mapToUIStatus(internalStatus: string): BookingStatusForUI {
  switch (internalStatus) {
    case "pending":
      return "pending";
    case "confirmed":
      return "confirmed";
    case "inProgress":
      return "inProgress";
    case "completed":
      return "completed";
    case "cancelled":
      return "cancelled";
    case "expired":
      return "expired";
    case "disputed":
      return "disputed";
    default:
      return "pending";
  }
}

// ==================== PROJECTION UPDATE TRIGGERS ====================

/**
 * Events that trigger client_view updates:
 * - Booking created
 * - Booking status changed
 * - Payment status changed
 * - Message received (unread count)
 * - Review submitted
 */
export const CLIENT_VIEW_TRIGGERS = [
  "bookings.onCreate",
  "bookings.onUpdate",
  "payments.onUpdate",
  "conversations.messages.onCreate",
  "reviews.onCreate",
] as const;

/**
 * Events that trigger supplier_view updates:
 * - Booking created (new request)
 * - Booking status changed
 * - Payment received
 * - Message received (unread count)
 * - Review received
 * - Blocked date changed
 */
export const SUPPLIER_VIEW_TRIGGERS = [
  "bookings.onCreate",
  "bookings.onUpdate",
  "payments.onUpdate",
  "conversations.messages.onCreate",
  "reviews.onCreate",
  "suppliers.blocked_dates.onCreate",
  "suppliers.blocked_dates.onDelete",
] as const;
