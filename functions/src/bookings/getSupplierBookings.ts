import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const REGION = "us-central1";

// ==================== TYPES ====================

interface SupplierBookingUIFlags {
  canAccept: boolean;
  canDecline: boolean;
  canComplete: boolean;
  canCancel: boolean;
  canMessage: boolean;
  canViewDetails: boolean;
  showExpiringSoon: boolean;
  showPaymentReceived: boolean;
}

interface SupplierBooking {
  id: string;
  clientId: string;
  clientName?: string;
  clientPhoto?: string;
  supplierId: string;
  supplierName?: string;
  packageId: string;
  packageName: string;
  eventName: string;
  eventType?: string;
  eventDate: string; // ISO string
  eventTime?: string;
  eventLocation?: string;
  guestCount?: number;
  totalPrice: number;
  paidAmount: number;
  remainingAmount: number;
  currency: string;
  status: string;
  paymentStatus: string;
  payments: unknown[];
  notes?: string;
  clientNotes?: string;
  supplierNotes?: string;
  selectedCustomizations: string[];
  createdAt: string;
  updatedAt: string;
  uiFlags: SupplierBookingUIFlags;
}

interface GetSupplierBookingsResponse {
  success: boolean;
  bookings?: SupplierBooking[];
  error?: string;
}

interface GetSupplierBookingDetailsResponse {
  success: boolean;
  booking?: SupplierBooking;
  error?: string;
}

interface GetSupplierAgendaResponse {
  success: boolean;
  events?: SupplierBooking[];
  error?: string;
}

// ==================== HELPER FUNCTIONS ====================

/**
 * Get supplier info from auth UID
 * Returns both the supplier document ID and all valid IDs for booking ownership
 */
interface SupplierAuthInfo {
  supplierId: string;
  validSupplierIds: string[]; // All IDs that can appear in booking.supplierId
}

async function getSupplierAuthInfo(authUid: string): Promise<SupplierAuthInfo | null> {
  // First check if auth UID is directly a supplier ID
  const directSupplier = await db.collection("suppliers").doc(authUid).get();
  if (directSupplier.exists) {
    const data = directSupplier.data()!;
    const userId = data.userId || data.authUid;
    // Valid IDs: document ID, userId, and authUid (for legacy bookings)
    const validIds = new Set([authUid]);
    if (userId) validIds.add(userId);
    if (data.authUid) validIds.add(data.authUid);
    return {
      supplierId: authUid,
      validSupplierIds: Array.from(validIds),
    };
  }

  // Otherwise, search for supplier by userId
  const supplierQuery = await db
      .collection("suppliers")
      .where("userId", "==", authUid)
      .limit(1)
      .get();

  if (supplierQuery.empty) {
    return null;
  }

  const supplierDoc = supplierQuery.docs[0];
  const data = supplierDoc.data();
  // Valid IDs: document ID, userId/authUid, and the auth UID
  const validIds = new Set([supplierDoc.id, authUid]);
  if (data.userId) validIds.add(data.userId);
  if (data.authUid) validIds.add(data.authUid);

  return {
    supplierId: supplierDoc.id,
    validSupplierIds: Array.from(validIds),
  };
}

/**
 * Get supplier ID from auth UID (backwards compatible)
 */
async function getSupplierIdFromAuth(authUid: string): Promise<string | null> {
  const info = await getSupplierAuthInfo(authUid);
  return info?.supplierId || null;
}

/**
 * Get client info for display (sanitized)
 */
async function getClientInfo(clientId: string): Promise<{name?: string; photo?: string}> {
  try {
    const userDoc = await db.collection("users").doc(clientId).get();
    if (!userDoc.exists) return {};

    const data = userDoc.data()!;
    return {
      name: data.name || "Cliente",
      photo: data.photoUrl,
    };
  } catch {
    return {};
  }
}

// Expiration configuration
const EXPIRE_DAYS = 7; // Total days before auto-expiration
const EXPIRING_SOON_HOURS = 48; // Show warning when this many hours left

/**
 * Calculate UI flags based on booking state
 * Determines which actions are available to the supplier
 */
function calculateUIFlags(
    status: string,
    paidAmount: number,
    totalPrice: number,
    createdAt?: FirebaseFirestore.Timestamp
): SupplierBookingUIFlags {
  const isPaid = paidAmount > 0;
  const isFullyPaid = paidAmount >= totalPrice;

  // Calculate if expiring soon (within 48 hours of 7-day deadline)
  let isExpiringSoon = false;
  if (status === "pending" && createdAt) {
    const createdDate = createdAt.toDate();
    const now = new Date();
    const hoursElapsed = (now.getTime() - createdDate.getTime()) / (1000 * 60 * 60);
    const totalHours = EXPIRE_DAYS * 24;
    const hoursRemaining = totalHours - hoursElapsed;
    isExpiringSoon = hoursRemaining <= EXPIRING_SOON_HOURS && hoursRemaining > 0;
  }

  return {
    // Can accept if pending and paid
    canAccept: status === "pending" && isPaid,

    // Can decline if pending
    canDecline: status === "pending",

    // Can complete if in progress
    canComplete: status === "inProgress",

    // Can cancel if pending or confirmed (not yet started)
    canCancel: status === "pending" || status === "confirmed",

    // Can always message
    canMessage: true,

    // Can always view details
    canViewDetails: true,

    // Show expiring soon if pending and within 48h of expiration
    showExpiringSoon: isExpiringSoon,

    // Show payment received if paid but not fully paid
    showPaymentReceived: isPaid && !isFullyPaid,
  };
}

/**
 * Sanitize booking for supplier view
 * Removes sensitive fields that suppliers shouldn't see
 */
function sanitizeBookingForSupplier(
    doc: FirebaseFirestore.DocumentSnapshot,
    clientInfo: {name?: string; photo?: string}
): SupplierBooking {
  const data = doc.data()!;
  const status = data.status || "pending";
  const totalPrice = data.totalPrice || 0;
  const paidAmount = data.paidAmount || 0;

  return {
    id: doc.id,
    clientId: data.clientId,
    clientName: clientInfo.name || "Cliente",
    clientPhoto: clientInfo.photo,
    supplierId: data.supplierId || "",
    supplierName: data.supplierName || "",
    packageId: data.packageId || "",
    packageName: data.packageName || "",
    eventName: data.eventName || "",
    eventType: data.eventType,
    eventDate: data.eventDate?.toDate?.()?.toISOString() || new Date().toISOString(),
    eventTime: data.eventTime,
    eventLocation: data.eventLocation,
    guestCount: data.guestCount,
    totalPrice,
    paidAmount,
    remainingAmount: totalPrice - paidAmount,
    currency: data.currency || "AOA",
    status,
    paymentStatus: data.paymentStatus || "unpaid",
    payments: data.payments || [],
    notes: data.notes,
    clientNotes: data.clientNotes,
    supplierNotes: data.supplierNotes,
    selectedCustomizations: data.selectedCustomizations || [],
    createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    updatedAt: data.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    uiFlags: calculateUIFlags(status, paidAmount, totalPrice, data.createdAt),
  };
}

// ==================== CLOUD FUNCTIONS ====================

/**
 * Get all bookings for the authenticated supplier
 *
 * Security: Only returns bookings where supplierId matches
 * the supplier profile owned by the authenticated user
 */
export const getSupplierBookings = functions
    .region(REGION)
    .https.onCall(async (data, context): Promise<GetSupplierBookingsResponse> => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      try {
        // 2. Get supplier ID from auth
        const supplierId = await getSupplierIdFromAuth(context.auth.uid);

        if (!supplierId) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Perfil de fornecedor não encontrado"
          );
        }

        // 3. Query bookings for this supplier
        const bookingsQuery = await db
            .collection("bookings")
            .where("supplierId", "==", supplierId)
            .orderBy("createdAt", "desc")
            .limit(100)
            .get();

        // 4. Sanitize and enrich bookings
        const bookings: SupplierBooking[] = [];

        for (const doc of bookingsQuery.docs) {
          const clientInfo = await getClientInfo(doc.data().clientId);
          bookings.push(sanitizeBookingForSupplier(doc, clientInfo));
        }

        console.log(
            `getSupplierBookings: Returned ${bookings.length} bookings for supplier ${supplierId}`
        );

        return {
          success: true,
          bookings,
        };
      } catch (error) {
        console.error("Error in getSupplierBookings:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao carregar reservas"
        );
      }
    });

/**
 * Get details of a specific booking for the authenticated supplier
 *
 * Security: Validates that the booking belongs to the supplier
 * Handles legacy bookings where supplierId might be userId instead of doc ID
 */
export const getSupplierBookingDetails = functions
    .region(REGION)
    .https.onCall(async (data, context): Promise<GetSupplierBookingDetailsResponse> => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      // 2. Validate input
      if (!data.bookingId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "bookingId é obrigatório"
        );
      }

      try {
        // 3. Get supplier auth info (includes all valid IDs)
        const supplierInfo = await getSupplierAuthInfo(context.auth.uid);

        if (!supplierInfo) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Perfil de fornecedor não encontrado"
          );
        }

        // 4. Get the booking
        const bookingDoc = await db.collection("bookings").doc(data.bookingId).get();

        if (!bookingDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Reserva não encontrada"
          );
        }

        // 5. Validate ownership - check against ALL valid supplier IDs
        const bookingData = bookingDoc.data()!;
        const bookingSupplierId = bookingData.supplierId as string;

        if (!supplierInfo.validSupplierIds.includes(bookingSupplierId)) {
          console.log(
              `Ownership check failed: booking.supplierId=${bookingSupplierId}, ` +
              `validIds=${supplierInfo.validSupplierIds.join(",")}`
          );
          throw new functions.https.HttpsError(
              "permission-denied",
              "Esta reserva não pertence ao seu perfil"
          );
        }

        // 6. Sanitize and return
        const clientInfo = await getClientInfo(bookingData.clientId);
        const booking = sanitizeBookingForSupplier(bookingDoc, clientInfo);

        return {
          success: true,
          booking,
        };
      } catch (error) {
        console.error("Error in getSupplierBookingDetails:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao carregar detalhes da reserva"
        );
      }
    });

/**
 * Get supplier's agenda (confirmed and in-progress bookings)
 *
 * Returns only bookings that should appear on the calendar
 */
export const getSupplierAgenda = functions
    .region(REGION)
    .https.onCall(async (data, context): Promise<GetSupplierAgendaResponse> => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      try {
        // 2. Get supplier ID from auth
        const supplierId = await getSupplierIdFromAuth(context.auth.uid);

        if (!supplierId) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Perfil de fornecedor não encontrado"
          );
        }

        // 3. Query confirmed and in-progress bookings
        // Note: Firestore doesn't support OR queries, so we do two queries
        const [confirmedQuery, inProgressQuery] = await Promise.all([
          db
              .collection("bookings")
              .where("supplierId", "==", supplierId)
              .where("status", "==", "confirmed")
              .orderBy("eventDate", "asc")
              .get(),
          db
              .collection("bookings")
              .where("supplierId", "==", supplierId)
              .where("status", "==", "inProgress")
              .orderBy("eventDate", "asc")
              .get(),
        ]);

        // 4. Merge and deduplicate results
        const seenIds = new Set<string>();
        const events: SupplierBooking[] = [];

        for (const doc of [...confirmedQuery.docs, ...inProgressQuery.docs]) {
          if (seenIds.has(doc.id)) continue;
          seenIds.add(doc.id);

          const clientInfo = await getClientInfo(doc.data().clientId);
          events.push(sanitizeBookingForSupplier(doc, clientInfo));
        }

        // 5. Sort by event date
        events.sort((a, b) =>
          new Date(a.eventDate).getTime() - new Date(b.eventDate).getTime()
        );

        console.log(
            `getSupplierAgenda: Returned ${events.length} events for supplier ${supplierId}`
        );

        return {
          success: true,
          events,
        };
      } catch (error) {
        console.error("Error in getSupplierAgenda:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao carregar agenda"
        );
      }
    });

/**
 * Get supplier's pending orders (pedidos)
 *
 * Returns bookings with status 'pending' that require supplier action
 */
export const getSupplierPedidos = functions
    .region(REGION)
    .https.onCall(async (data, context): Promise<GetSupplierBookingsResponse> => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      try {
        // 2. Get supplier ID from auth
        const supplierId = await getSupplierIdFromAuth(context.auth.uid);

        if (!supplierId) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Perfil de fornecedor não encontrado"
          );
        }

        // 3. Query pending bookings
        const pendingQuery = await db
            .collection("bookings")
            .where("supplierId", "==", supplierId)
            .where("status", "==", "pending")
            .orderBy("createdAt", "desc")
            .get();

        // 4. Sanitize and enrich bookings
        const bookings: SupplierBooking[] = [];

        for (const doc of pendingQuery.docs) {
          const clientInfo = await getClientInfo(doc.data().clientId);
          bookings.push(sanitizeBookingForSupplier(doc, clientInfo));
        }

        console.log(
            `getSupplierPedidos: Returned ${bookings.length} pending orders for supplier ${supplierId}`
        );

        return {
          success: true,
          bookings,
        };
      } catch (error) {
        console.error("Error in getSupplierPedidos:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao carregar pedidos"
        );
      }
    });

/**
 * Respond to a booking (confirm or reject)
 *
 * Supplier can only respond to their own pending bookings
 * Confirmation requires payment (if payment gate is enabled)
 */
export const respondToBooking = functions
    .region(REGION)
    .https.onCall(async (data, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      // 2. Validate input
      if (!data.bookingId || !data.action) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "bookingId e action são obrigatórios"
        );
      }

      const validActions = ["confirm", "reject"];
      if (!validActions.includes(data.action)) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "action deve ser 'confirm' ou 'reject'"
        );
      }

      try {
        // 3. Get supplier auth info (includes all valid IDs)
        const supplierInfo = await getSupplierAuthInfo(context.auth.uid);

        if (!supplierInfo) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Perfil de fornecedor não encontrado"
          );
        }

        // 4. Get the booking
        const bookingRef = db.collection("bookings").doc(data.bookingId);
        const bookingDoc = await bookingRef.get();

        if (!bookingDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Reserva não encontrada"
          );
        }

        const booking = bookingDoc.data()!;
        const bookingSupplierId = booking.supplierId as string;

        // 5. Validate ownership - check against ALL valid supplier IDs
        if (!supplierInfo.validSupplierIds.includes(bookingSupplierId)) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Esta reserva não pertence ao seu perfil"
          );
        }

        const supplierId = supplierInfo.supplierId;

        // 6. Validate current status
        if (booking.status !== "pending") {
          throw new functions.https.HttpsError(
              "failed-precondition",
              `Não é possível responder: reserva está '${booking.status}'`
          );
        }

        // 7. Payment gate enforcement for confirmation
        if (data.action === "confirm") {
          const paidAmount = booking.paidAmount || 0;
          // totalPrice available for future percentage-based payment validation
          const _totalPrice = booking.totalPrice || 0;
          void _totalPrice; // Marked for future use

          // Check if payment is required (configurable - at least signal/deposit)
          // For now, we require at least some payment before confirmation
          if (paidAmount <= 0) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                "Pagamento necessário: O cliente precisa pagar o sinal antes da confirmação"
            );
          }
        }

        // 8. Update booking status
        const now = admin.firestore.FieldValue.serverTimestamp();
        const newStatus = data.action === "confirm" ? "confirmed" : "rejected";

        const updates: Record<string, unknown> = {
          status: newStatus,
          updatedAt: now,
          respondedAt: now,
          respondedBy: context.auth.uid,
        };

        if (data.action === "confirm") {
          updates.confirmedAt = now;
        } else {
          updates.rejectedAt = now;
          updates.rejectionReason = data.reason || "Fornecedor rejeitou o pedido";
        }

        await bookingRef.update(updates);

        // 9. Create audit log
        await db.collection("audit_logs").add({
          category: "booking",
          eventType: data.action === "confirm" ? "confirmed" : "rejected",
          userId: context.auth.uid,
          resourceId: data.bookingId,
          resourceType: "booking",
          previousValue: "pending",
          newValue: newStatus,
          description: `Supplier ${data.action === "confirm" ? "confirmed" : "rejected"} booking`,
          metadata: {
            supplierId,
            clientId: booking.clientId,
            action: data.action,
          },
          timestamp: now,
        });

        console.log(
            `respondToBooking: Supplier ${supplierId} ${data.action}ed booking ${data.bookingId}`
        );

        return {
          success: true,
          bookingId: data.bookingId,
          newStatus,
        };
      } catch (error) {
        console.error("Error in respondToBooking:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao responder ao pedido"
        );
      }
    });
