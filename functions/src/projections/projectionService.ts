/**
 * Projection Service - Maintains UI Views
 *
 * HARDENED: Idempotent, Ordered, Debuggable
 *
 * This service keeps client_views and supplier_views in sync with source data.
 * All updates are triggered by Firestore events (onCreate, onUpdate, onDelete).
 *
 * UI Contract: Flutter reads ONLY from these projections, never from source collections.
 *
 * INVARIANTS:
 * 1. Projections are rebuilt from scratch (no incremental appends)
 * 2. Uses set() with merge:false for idempotent writes
 * 3. All arrays are pre-sorted by backend (UI must not sort)
 * 4. Metadata tracks rebuild reason for debugging
 */

import * as admin from "firebase-admin";
import {
  ClientView,
  ClientBookingSummary,
  ClientEventSummary,
  ClientBookingUIFlags,
  SupplierView,
  SupplierBookingSummary,
  SupplierEventSummary,
  SupplierBlockedDateSummary,
  SupplierBookingUIFlags,
  SupplierDashboardStats,
  SupplierAccountFlags,
  mapToUIStatus,
  BookingStatusForUI,
} from "./projectionSchemas";

const db = admin.firestore();

// Projection version for debugging and migration tracking
const PROJECTION_VERSION = "v1";

// Rebuild reason types for metadata
export type RebuildReason = "trigger" | "backfill" | "manual";

// Projection metadata interface
interface ProjectionMeta {
  rebuiltAt: admin.firestore.Timestamp;
  sourceVersion: string;
  reason: RebuildReason;
}

// ==================== CLIENT VIEW UPDATES ====================

/**
 * Rebuild entire client view from scratch (IDEMPOTENT)
 *
 * INVARIANTS:
 * - Recomputes from source data, never appends to existing projection
 * - Uses set() with merge:false to guarantee clean state
 * - All arrays are deterministically ordered by backend
 *
 * @param clientId - The client's user ID
 * @param reason - Why this rebuild was triggered (for debugging)
 */
export async function rebuildClientView(
  clientId: string,
  reason: RebuildReason = "trigger"
): Promise<void> {
  console.log(`[${reason}] Rebuilding client view for: ${clientId}`);

  try {
    // Get client profile
    const clientDoc = await db.collection("users").doc(clientId).get();
    const clientData = clientDoc.data() || {};

    // Get all client bookings
    const bookingsSnapshot = await db
      .collection("bookings")
      .where("clientId", "==", clientId)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    const allBookings: ClientBookingSummary[] = [];
    const supplierCache = new Map<string, admin.firestore.DocumentData>();

    for (const doc of bookingsSnapshot.docs) {
      const booking = doc.data();
      const supplierId = booking.supplierId as string;

      // Get supplier info (cached)
      if (!supplierCache.has(supplierId)) {
        const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
        if (supplierDoc.exists) {
          supplierCache.set(supplierId, supplierDoc.data()!);
        }
      }
      const supplier = supplierCache.get(supplierId) || {};

      allBookings.push(buildClientBookingSummary(doc.id, booking, supplier));
    }

    // ========== DETERMINISTIC ORDERING (Backend guarantees, UI must not sort) ==========
    const now = admin.firestore.Timestamp.now();
    const activeStatuses: BookingStatusForUI[] = ["pending", "confirmed", "inProgress"];

    // activeBookings: createdAt DESC (most recent first)
    const activeBookings = allBookings
      .filter((b) => activeStatuses.includes(b.status))
      .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
      .slice(0, 10);

    // recentBookings: createdAt DESC (most recent first)
    const recentBookings = allBookings
      .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
      .slice(0, 10);

    // upcomingEvents: eventDate ASC (soonest first)
    const upcomingEvents: ClientEventSummary[] = allBookings
      .filter((b) => b.status === "confirmed" && b.eventDate.toMillis() > now.toMillis())
      .sort((a, b) => a.eventDate.toMillis() - b.eventDate.toMillis())
      .slice(0, 5)
      .map((b) => ({
        bookingId: b.bookingId,
        supplierName: b.supplierName,
        supplierPhotoUrl: b.supplierPhotoUrl,
        eventName: b.eventName,
        eventDate: b.eventDate,
        eventLocation: null,
        status: b.status,
      }));

    // Get unread message count
    const unreadMessages = await getUnreadMessageCount(clientId, "client");

    // Get unread notification count
    const unreadNotifications = await getUnreadNotificationCount(clientId);

    // Get payment summary
    const paymentSummary = await getClientPaymentSummary(clientId);

    // Get cart count
    const cartSnapshot = await db
      .collection("users")
      .doc(clientId)
      .collection("cart")
      .get();

    // ========== BUILD PROJECTION WITH METADATA ==========
    const meta: ProjectionMeta = {
      rebuiltAt: admin.firestore.Timestamp.now(),
      sourceVersion: PROJECTION_VERSION,
      reason,
    };

    const clientView: ClientView = {
      clientId,
      displayName: clientData.displayName || clientData.name || "Cliente",
      email: clientData.email || "",
      photoUrl: clientData.photoUrl || null,
      phone: clientData.phone || null,
      activeBookings,
      recentBookings,
      upcomingEvents,
      unreadCounts: {
        messages: unreadMessages,
        notifications: unreadNotifications,
      },
      paymentSummary,
      cartItemCount: cartSnapshot.size,
      updatedAt: admin.firestore.Timestamp.now(),
    };

    // ========== IDEMPOTENT WRITE: merge:false guarantees clean state ==========
    await db.collection("client_views").doc(clientId).set(
      {...clientView, meta},
      {merge: false}
    );
    console.log(`[${reason}] Client view rebuilt for: ${clientId}`);
  } catch (error) {
    console.error(`Error rebuilding client view for ${clientId}:`, error);
    throw error;
  }
}

/**
 * Build booking summary for client view
 */
function buildClientBookingSummary(
  bookingId: string,
  booking: admin.firestore.DocumentData,
  supplier: admin.firestore.DocumentData
): ClientBookingSummary {
  const status = mapToUIStatus(booking.status || "pending");

  return {
    bookingId,
    supplierId: booking.supplierId || "",
    supplierName: supplier.businessName || supplier.name || "Fornecedor",
    supplierPhotoUrl: supplier.photoUrl || supplier.profileImage || null,
    categoryName: booking.categoryName || booking.category || "",
    eventName: booking.eventName || "Evento",
    eventDate: booking.eventDate || admin.firestore.Timestamp.now(),
    status,
    totalAmount: booking.totalAmount || booking.price || 0,
    currency: booking.currency || "AOA",
    uiFlags: buildClientUIFlags(status, booking),
    createdAt: booking.createdAt || admin.firestore.Timestamp.now(),
  };
}

/**
 * Build UI flags for client booking actions
 */
function buildClientUIFlags(
  status: BookingStatusForUI,
  booking: admin.firestore.DocumentData
): ClientBookingUIFlags {
  const paymentStatus = booking.paymentStatus || "pending";
  const paidAmount = booking.paidAmount || 0;
  // Use totalAmount (new field) with fallback to totalPrice (legacy)
  const totalPrice = booking.totalAmount || booking.totalPrice || 0;
  const isUnpaid = paidAmount === 0;
  const isPartiallyPaid = paidAmount > 0 && paidAmount < totalPrice;

  return {
    canCancel: status === "pending" || status === "confirmed",
    // Client can pay if booking is pending AND hasn't paid yet (or partially paid)
    // This allows clients to pay BEFORE supplier confirms
    canPay: status === "pending" && (isUnpaid || isPartiallyPaid),
    canReview: status === "completed" && !booking.hasReview,
    canMessage: status !== "cancelled" && status !== "expired",
    canViewDetails: true,
    canRequestRefund: status === "cancelled" && paymentStatus === "paid",
    showPaymentPending: status === "pending" && isUnpaid,
    showEscrowHeld: paymentStatus === "escrow",
  };
}

/**
 * Get client payment summary
 */
async function getClientPaymentSummary(clientId: string): Promise<{
  pendingPayments: number;
  totalSpent: number;
  escrowHeld: number;
}> {
  try {
    const paymentsSnapshot = await db
      .collection("payments")
      .where("clientId", "==", clientId)
      .get();

    let pendingPayments = 0;
    let totalSpent = 0;
    let escrowHeld = 0;

    for (const doc of paymentsSnapshot.docs) {
      const payment = doc.data();
      const amount = payment.amount || 0;

      if (payment.status === "pending") {
        pendingPayments += amount;
      } else if (payment.status === "completed" || payment.status === "paid") {
        totalSpent += amount;
      } else if (payment.status === "escrow") {
        escrowHeld += amount;
      }
    }

    return {pendingPayments, totalSpent, escrowHeld};
  } catch (error) {
    console.error(`Error getting payment summary for ${clientId}:`, error);
    return {pendingPayments: 0, totalSpent: 0, escrowHeld: 0};
  }
}

// ==================== SUPPLIER VIEW UPDATES ====================

/**
 * Rebuild entire supplier view from scratch (IDEMPOTENT)
 *
 * INVARIANTS:
 * - Recomputes from source data, never appends to existing projection
 * - Uses set() with merge:false to guarantee clean state
 * - All arrays are deterministically ordered by backend
 *
 * @param supplierId - The supplier document ID
 * @param reason - Why this rebuild was triggered (for debugging)
 */
export async function rebuildSupplierView(
  supplierId: string,
  reason: RebuildReason = "trigger"
): Promise<void> {
  console.log(`[${reason}] Rebuilding supplier view for: ${supplierId}`);

  try {
    // Get supplier profile
    const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
    if (!supplierDoc.exists) {
      console.log(`Supplier not found: ${supplierId}`);
      return;
    }
    const supplierData = supplierDoc.data()!;

    // Also check by userId for legacy bookings
    const supplierAuthUid = supplierData.userId || supplierData.authUid || "";
    const supplierIdsToSearch = [supplierId];
    if (supplierAuthUid && supplierAuthUid !== supplierId) {
      supplierIdsToSearch.push(supplierAuthUid);
    }

    // Get all supplier bookings (from both IDs)
    const allBookings: SupplierBookingSummary[] = [];
    const clientCache = new Map<string, admin.firestore.DocumentData>();

    for (const searchId of supplierIdsToSearch) {
      const bookingsSnapshot = await db
        .collection("bookings")
        .where("supplierId", "==", searchId)
        .orderBy("createdAt", "desc")
        .limit(50)
        .get();

      for (const doc of bookingsSnapshot.docs) {
        // Skip duplicates
        if (allBookings.some((b) => b.bookingId === doc.id)) continue;

        const booking = doc.data();
        const clientId = booking.clientId as string;

        // Get client info (cached)
        if (!clientCache.has(clientId)) {
          const clientDoc = await db.collection("users").doc(clientId).get();
          if (clientDoc.exists) {
            clientCache.set(clientId, clientDoc.data()!);
          }
        }
        const client = clientCache.get(clientId) || {};

        allBookings.push(buildSupplierBookingSummary(doc.id, booking, client));
      }
    }

    // ========== DETERMINISTIC ORDERING (Backend guarantees, UI must not sort) ==========
    const now = admin.firestore.Timestamp.now();

    // pendingBookings: createdAt DESC (most recent first)
    const pendingBookings = allBookings
      .filter((b) => b.status === "pending")
      .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
      .slice(0, 20);

    // confirmedBookings: eventDate ASC (soonest first)
    const confirmedBookings = allBookings
      .filter((b) => b.status === "confirmed" || b.status === "inProgress")
      .sort((a, b) => a.eventDate.toMillis() - b.eventDate.toMillis())
      .slice(0, 20);

    // recentBookings: createdAt DESC (most recent first)
    const recentBookings = allBookings
      .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
      .slice(0, 10);

    // upcomingEvents: eventDate ASC (soonest first) - agenda view
    const upcomingEvents: SupplierEventSummary[] = allBookings
      .filter((b) =>
        (b.status === "confirmed" || b.status === "inProgress") &&
        b.eventDate.toMillis() > now.toMillis()
      )
      .sort((a, b) => a.eventDate.toMillis() - b.eventDate.toMillis())
      .slice(0, 5)
      .map((b) => ({
        bookingId: b.bookingId,
        clientName: b.clientName,
        clientPhotoUrl: b.clientPhotoUrl,
        eventName: b.eventName,
        eventDate: b.eventDate,
        eventLocation: b.eventLocation,
        status: b.status,
      }));

    // Get dashboard stats
    const dashboardStats = buildDashboardStats(allBookings, supplierData);

    // Get unread message count (check both supplierId formats)
    let unreadMessages = await getUnreadMessageCount(supplierId, "supplier");
    if (supplierAuthUid && supplierAuthUid !== supplierId) {
      unreadMessages += await getUnreadMessageCount(supplierAuthUid, "supplier");
    }

    // Get unread notification count (notifications are sent to auth UID)
    const unreadNotifications = supplierAuthUid
      ? await getUnreadNotificationCount(supplierAuthUid)
      : 0;

    // Get earnings summary
    const earningsSummary = await getSupplierEarningsSummary(supplierId);

    // Get blocked dates (already ordered by date ASC from query)
    const blockedDates = await getSupplierBlockedDates(supplierId);

    // Build availability summary
    const availabilitySummary = buildAvailabilitySummary(blockedDates);

    // Build account flags
    const accountFlags = buildAccountFlags(supplierData);

    // ========== BUILD PROJECTION WITH METADATA ==========
    const meta: ProjectionMeta = {
      rebuiltAt: admin.firestore.Timestamp.now(),
      sourceVersion: PROJECTION_VERSION,
      reason,
    };

    const supplierView: SupplierView = {
      supplierId,
      businessName: supplierData.businessName || supplierData.name || "Fornecedor",
      email: supplierData.email || "",
      photoUrl: supplierData.photoUrl || supplierData.profileImage || null,
      phone: supplierData.phone || null,
      dashboardStats,
      pendingBookings,
      confirmedBookings,
      recentBookings,
      upcomingEvents,
      unreadCounts: {
        messages: unreadMessages,
        notifications: unreadNotifications,
        pendingBookings: pendingBookings.length,
      },
      earningsSummary,
      availabilitySummary,
      blockedDates,
      accountFlags,
      updatedAt: admin.firestore.Timestamp.now(),
    };

    // ========== IDEMPOTENT WRITE: merge:false guarantees clean state ==========
    await db.collection("supplier_views").doc(supplierId).set(
      {...supplierView, meta},
      {merge: false}
    );
    console.log(`[${reason}] Supplier view rebuilt for: ${supplierId}`);
  } catch (error) {
    console.error(`Error rebuilding supplier view for ${supplierId}:`, error);
    throw error;
  }
}

/**
 * Build booking summary for supplier view
 */
function buildSupplierBookingSummary(
  bookingId: string,
  booking: admin.firestore.DocumentData,
  client: admin.firestore.DocumentData
): SupplierBookingSummary {
  const status = mapToUIStatus(booking.status || "pending");

  // Calculate expiry for pending bookings (7 days from creation)
  let expiresAt: admin.firestore.Timestamp | null = null;
  if (status === "pending" && booking.createdAt) {
    const createdMs = booking.createdAt.toMillis();
    const expiryMs = createdMs + 7 * 24 * 60 * 60 * 1000; // 7 days
    expiresAt = admin.firestore.Timestamp.fromMillis(expiryMs);
  }

  return {
    bookingId,
    clientId: booking.clientId || "",
    clientName: client.displayName || client.name || "Cliente",
    clientPhotoUrl: client.photoUrl || null,
    eventName: booking.eventName || "Evento",
    eventDate: booking.eventDate || admin.firestore.Timestamp.now(),
    eventLocation: booking.eventLocation || booking.location || null,
    status,
    totalAmount: booking.totalAmount || booking.price || 0,
    currency: booking.currency || "AOA",
    uiFlags: buildSupplierUIFlags(status, booking, expiresAt),
    createdAt: booking.createdAt || admin.firestore.Timestamp.now(),
    expiresAt,
  };
}

/**
 * Build UI flags for supplier booking actions
 */
function buildSupplierUIFlags(
  status: BookingStatusForUI,
  booking: admin.firestore.DocumentData,
  expiresAt: admin.firestore.Timestamp | null
): SupplierBookingUIFlags {
  const paymentStatus = booking.paymentStatus || "pending";

  // Check if expiring soon (< 24h)
  let showExpiringSoon = false;
  if (status === "pending" && expiresAt) {
    const nowMs = Date.now();
    const expiryMs = expiresAt.toMillis();
    const hoursUntilExpiry = (expiryMs - nowMs) / (1000 * 60 * 60);
    showExpiringSoon = hoursUntilExpiry < 24 && hoursUntilExpiry > 0;
  }

  return {
    canAccept: status === "pending",
    canDecline: status === "pending",
    canComplete: status === "confirmed" || status === "inProgress",
    canCancel: status === "pending" || status === "confirmed",
    canMessage: status !== "cancelled" && status !== "expired",
    canViewDetails: true,
    showExpiringSoon,
    showPaymentReceived: paymentStatus === "paid" || paymentStatus === "escrow",
  };
}

/**
 * Build dashboard stats for supplier
 */
function buildDashboardStats(
  bookings: SupplierBookingSummary[],
  supplierData: admin.firestore.DocumentData
): SupplierDashboardStats {
  const totalBookings = bookings.length;
  const completedBookings = bookings.filter((b) => b.status === "completed").length;
  const cancelledBookings = bookings.filter((b) => b.status === "cancelled").length;

  return {
    totalBookings,
    completedBookings,
    cancelledBookings,
    averageRating: supplierData.averageRating || supplierData.rating || 0,
    totalReviews: supplierData.totalReviews || supplierData.reviewCount || 0,
    responseRate: supplierData.responseRate || 0,
    responseTimeMinutes: supplierData.responseTimeMinutes || supplierData.avgResponseTime || 0,
  };
}

/**
 * Get supplier earnings summary
 */
async function getSupplierEarningsSummary(supplierId: string): Promise<{
  thisMonth: number;
  pendingPayout: number;
  totalEarned: number;
  currency: string;
}> {
  try {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const paymentsSnapshot = await db
      .collection("payments")
      .where("supplierId", "==", supplierId)
      .where("status", "in", ["completed", "paid", "released"])
      .get();

    let thisMonth = 0;
    let totalEarned = 0;

    for (const doc of paymentsSnapshot.docs) {
      const payment = doc.data();
      const amount = payment.supplierAmount || payment.amount || 0;
      const paidAt = payment.paidAt || payment.completedAt;

      totalEarned += amount;

      if (paidAt && paidAt.toDate() >= startOfMonth) {
        thisMonth += amount;
      }
    }

    // Get pending payout from escrow
    const escrowSnapshot = await db
      .collection("escrow")
      .where("supplierId", "==", supplierId)
      .where("status", "==", "held")
      .get();

    let pendingPayout = 0;
    for (const doc of escrowSnapshot.docs) {
      const escrow = doc.data();
      pendingPayout += escrow.supplierAmount || escrow.amount || 0;
    }

    return {thisMonth, pendingPayout, totalEarned, currency: "AOA"};
  } catch (error) {
    console.error(`Error getting earnings for ${supplierId}:`, error);
    return {thisMonth: 0, pendingPayout: 0, totalEarned: 0, currency: "AOA"};
  }
}

/**
 * Get supplier blocked dates
 */
async function getSupplierBlockedDates(
  supplierId: string
): Promise<SupplierBlockedDateSummary[]> {
  try {
    const now = admin.firestore.Timestamp.now();
    const sixtyDaysLater = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 60 * 24 * 60 * 60 * 1000
    );

    const snapshot = await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blocked_dates")
      .where("date", ">=", now)
      .where("date", "<=", sixtyDaysLater)
      .orderBy("date")
      .get();

    return snapshot.docs.map((doc) => {
      const data = doc.data();
      const type = data.type || "blocked";

      return {
        id: doc.id,
        date: data.date,
        type: type as "reserved" | "blocked" | "unavailable" | "requested",
        reason: data.reason || "",
        bookingId: data.bookingId || null,
        canUnblock: type === "blocked" || type === "unavailable",
      };
    });
  } catch (error) {
    console.error(`Error getting blocked dates for ${supplierId}:`, error);
    return [];
  }
}

/**
 * Build availability summary from blocked dates
 */
function buildAvailabilitySummary(
  blockedDates: SupplierBlockedDateSummary[]
): {
  availableThisMonth: number;
  reservedThisMonth: number;
  blockedThisMonth: number;
  requestedThisMonth: number;
} {
  const now = new Date();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

  const thisMonthDates = blockedDates.filter((bd) => {
    const date = bd.date.toDate();
    return date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear();
  });

  const reservedThisMonth = thisMonthDates.filter((bd) => bd.type === "reserved").length;
  const requestedThisMonth = thisMonthDates.filter((bd) => bd.type === "requested").length;
  const blockedThisMonth = thisMonthDates.filter(
    (bd) => bd.type === "blocked" || bd.type === "unavailable"
  ).length;
  const availableThisMonth = daysInMonth - reservedThisMonth - requestedThisMonth - blockedThisMonth;

  return {
    availableThisMonth: Math.max(0, availableThisMonth),
    reservedThisMonth,
    blockedThisMonth,
    requestedThisMonth,
  };
}

/**
 * Build account flags for supplier
 */
function buildAccountFlags(
  supplierData: admin.firestore.DocumentData
): SupplierAccountFlags {
  // Check verification status
  const accountStatus = supplierData.accountStatus || "pending";
  const identityStatus = supplierData.identityVerificationStatus || "pending";
  const lifecycleState = supplierData.lifecycle_state || "pending";
  const compliance = supplierData.compliance || {};
  const visibility = supplierData.visibility || {};
  const blocks = supplierData.blocks || {};
  const rateLimit = supplierData.rate_limit || {};

  // Determine if supplier is bookable (matches backend eligibility)
  const isBookable =
    lifecycleState === "active" &&
    compliance.payouts_ready === true &&
    compliance.kyc_status === "verified" &&
    visibility.is_listed !== false &&
    blocks.bookings_globally !== true &&
    rateLimit.exceeded !== true;

  return {
    isActive: accountStatus === "active",
    isVerified: identityStatus === "verified",
    isBookable,
    isPaused: visibility.is_listed === false,
    hasPayoutSetup: compliance.payouts_ready === true,
    showVerificationNeeded: identityStatus !== "verified",
    showPayoutSetupNeeded: compliance.payouts_ready !== true,
    showRateLimitWarning: rateLimit.exceeded === true,
  };
}

// ==================== SHARED UTILITIES ====================

/**
 * Get unread message count for user
 */
async function getUnreadMessageCount(
  userId: string,
  userType: "client" | "supplier"
): Promise<number> {
  try {
    const fieldToCheck = userType === "client" ? "clientId" : "supplierId";

    // Query conversations collection
    const conversationsSnapshot = await db
      .collection("conversations")
      .where(fieldToCheck, "==", userId)
      .get();

    // Also check chats collection (legacy)
    const chatsSnapshot = await db
      .collection("chats")
      .where(fieldToCheck, "==", userId)
      .get();

    let totalUnread = 0;

    // Process conversations
    for (const doc of conversationsSnapshot.docs) {
      const conv = doc.data();
      // Unread counts are stored as a map: unreadCount[userId] = count
      const unreadCount = conv.unreadCount as Record<string, number> | undefined;
      if (unreadCount && unreadCount[userId]) {
        totalUnread += unreadCount[userId];
      }
    }

    // Process chats (legacy)
    for (const doc of chatsSnapshot.docs) {
      const chat = doc.data();
      const unreadCount = chat.unreadCount as Record<string, number> | undefined;
      if (unreadCount && unreadCount[userId]) {
        totalUnread += unreadCount[userId];
      }
    }

    return totalUnread;
  } catch (error) {
    console.error(`Error getting unread count for ${userId}:`, error);
    return 0;
  }
}

/**
 * Get unread notification count for user
 */
async function getUnreadNotificationCount(userId: string): Promise<number> {
  try {
    const notificationsSnapshot = await db
      .collection("notifications")
      .where("userId", "==", userId)
      .where("read", "==", false)
      .get();

    return notificationsSnapshot.size;
  } catch (error) {
    console.error(`Error getting notification count for ${userId}:`, error);
    return 0;
  }
}

// ==================== TRIGGER WRAPPERS (delegate to full rebuild) ====================

/**
 * Update client view when booking changes
 * IMPORTANT: Always does full rebuild to maintain idempotency
 */
export async function updateClientViewOnBookingChange(
  bookingId: string,
  booking: admin.firestore.DocumentData,
  clientId: string
): Promise<void> {
  // Full rebuild ensures idempotency - no incremental updates
  await rebuildClientView(clientId, "trigger");
}

/**
 * Update supplier view when booking changes
 * IMPORTANT: Always does full rebuild to maintain idempotency
 */
export async function updateSupplierViewOnBookingChange(
  bookingId: string,
  booking: admin.firestore.DocumentData,
  supplierId: string
): Promise<void> {
  // Full rebuild ensures idempotency - no incremental updates
  await rebuildSupplierView(supplierId, "trigger");
}

/**
 * Update views when message is received
 * For messaging, we do a lightweight update for unread counts only
 * This is safe because unread counts are computed fresh each time
 */
export async function updateViewsOnMessage(
  conversationId: string,
  message: admin.firestore.DocumentData,
  clientId: string,
  supplierId: string
): Promise<void> {
  // Compute fresh unread counts (idempotent)
  const clientUnread = await getUnreadMessageCount(clientId, "client");
  const supplierUnread = await getUnreadMessageCount(supplierId, "supplier");
  const now = admin.firestore.Timestamp.now();

  const batch = db.batch();

  // Update client unread count
  const clientViewRef = db.collection("client_views").doc(clientId);
  batch.update(clientViewRef, {
    "unreadCounts.messages": clientUnread,
    "meta.rebuiltAt": now,
    "meta.reason": "trigger",
    updatedAt: now,
  });

  // Update supplier unread count
  const supplierViewRef = db.collection("supplier_views").doc(supplierId);
  batch.update(supplierViewRef, {
    "unreadCounts.messages": supplierUnread,
    "meta.rebuiltAt": now,
    "meta.reason": "trigger",
    updatedAt: now,
  });

  await batch.commit();
}
