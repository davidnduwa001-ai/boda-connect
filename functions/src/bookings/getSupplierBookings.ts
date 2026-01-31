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
  packageId: string;
  packageName: string;
  eventName: string;
  eventDate: string; // ISO string
  eventTime?: string;
  eventLocation?: string;
  totalPrice: number;
  paidAmount: number;
  remainingAmount: number;
  status: string;
  paymentStatus: string;
  notes?: string;
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
 * Get supplier ID from auth UID
 * Validates that the caller owns the supplier profile
 */
async function getSupplierIdFromAuth(authUid: string): Promise<string | null> {
  // First check if auth UID is directly a supplier ID
  const directSupplier = await db.collection("suppliers").doc(authUid).get();
  if (directSupplier.exists && directSupplier.data()?.userId === authUid) {
    return authUid;
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

  return supplierQuery.docs[0].id;
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

/**
 * Calculate UI flags based on booking state
 * Determines which actions are available to the supplier
 */
function calculateUIFlags(
    status: string,
    paidAmount: number,
    totalPrice: number
): SupplierBookingUIFlags {
  const isPaid = paidAmount > 0;
  const isFullyPaid = paidAmount >= totalPrice;

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

    // Show expiring soon if pending and older than 48h
    showExpiringSoon: false, // Requires createdAt comparison

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
  // Support both totalPrice and totalAmount (booking creation uses totalAmount)
  const totalPrice = data.totalPrice || data.totalAmount || 0;
  const paidAmount = data.paidAmount || 0;

  return {
    id: doc.id,
    clientId: data.clientId,
    clientName: clientInfo.name || "Cliente",
    clientPhoto: clientInfo.photo,
    packageId: data.packageId || "",
    packageName: data.packageName || "",
    eventName: data.eventName || "",
    eventDate: data.eventDate?.toDate?.()?.toISOString() || new Date().toISOString(),
    eventTime: data.eventTime,
    eventLocation: data.eventLocation,
    totalPrice,
    paidAmount,
    remainingAmount: totalPrice - paidAmount,
    status,
    paymentStatus: data.paymentStatus || "unpaid",
    notes: data.notes,
    createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    updatedAt: data.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    uiFlags: calculateUIFlags(status, paidAmount, totalPrice),
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
        // 3. Get supplier ID from auth
        const supplierId = await getSupplierIdFromAuth(context.auth.uid);

        if (!supplierId) {
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

        // 5. Validate ownership
        const bookingData = bookingDoc.data()!;
        if (bookingData.supplierId !== supplierId) {
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
        // 3. Get supplier ID from auth (outside transaction - won't change during request)
        const supplierId = await getSupplierIdFromAuth(context.auth.uid);

        if (!supplierId) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Perfil de fornecedor não encontrado"
          );
        }

        const bookingRef = db.collection("bookings").doc(data.bookingId);
        const newStatus = data.action === "confirm" ? "confirmed" : "rejected";
        const callerId = context.auth!.uid;

        // Use transaction for atomic read-check-write to prevent race conditions
        const result = await db.runTransaction(async (transaction) => {
          // 4. Get the booking inside transaction
          const bookingDoc = await transaction.get(bookingRef);

          if (!bookingDoc.exists) {
            throw new functions.https.HttpsError(
                "not-found",
                "Reserva não encontrada"
            );
          }

          const booking = bookingDoc.data()!;
          const currentStatus = booking.status as string;

          // 5. Validate ownership
          if (booking.supplierId !== supplierId) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Esta reserva não pertence ao seu perfil"
            );
          }

          // 6. Check idempotency - if already in target status, return success
          if (currentStatus === newStatus) {
            console.log(
                `Idempotent response for booking ${data.bookingId}: already ${currentStatus}`
            );
            return {
              idempotent: true,
              newStatus: currentStatus,
              booking,
            };
          }

          // 7. Validate current status allows this transition
          if (currentStatus !== "pending") {
            throw new functions.https.HttpsError(
                "failed-precondition",
                `Não é possível responder: reserva está '${currentStatus}'`
            );
          }

          // 8. Payment gate enforcement for confirmation
          if (data.action === "confirm") {
            const paidAmount = booking.paidAmount || 0;

            // Check if payment is required (at least signal/deposit)
            if (paidAmount <= 0) {
              throw new functions.https.HttpsError(
                  "failed-precondition",
                  "Pagamento necessário: O cliente precisa pagar o sinal antes da confirmação"
              );
            }
          }

          // 9. Build and apply update atomically
          const now = admin.firestore.FieldValue.serverTimestamp();
          const updates: Record<string, unknown> = {
            status: newStatus,
            updatedAt: now,
            respondedAt: now,
            respondedBy: callerId,
          };

          if (data.action === "confirm") {
            updates.confirmedAt = now;
          } else {
            updates.rejectedAt = now;
            updates.rejectionReason = data.reason || "Fornecedor rejeitou o pedido";
          }

          transaction.update(bookingRef, updates);

          console.log(
              `Booking ${data.bookingId} status updated: ${currentStatus} → ${newStatus} by supplier ${supplierId}`
          );

          return {
            idempotent: false,
            newStatus,
            booking,
          };
        });

        // Handle idempotent case - return success without side effects
        if (result.idempotent) {
          return {
            success: true,
            bookingId: data.bookingId,
            newStatus: result.newStatus,
          };
        }

        // Post-transaction side effects (outside transaction)
        const booking = result.booking;
        const now = admin.firestore.FieldValue.serverTimestamp();

        // 10. Create audit log
        await db.collection("audit_logs").add({
          category: "booking",
          eventType: data.action === "confirm" ? "confirmed" : "rejected",
          userId: callerId,
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
