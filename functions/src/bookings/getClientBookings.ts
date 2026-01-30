import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const REGION = "us-central1";

// ==================== TYPES ====================

interface ClientBooking {
  id: string;
  supplierId: string;
  supplierName?: string;
  supplierPhoto?: string;
  categoryName?: string;
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
  notes?: string;
  clientNotes?: string;
  selectedCustomizations: string[];
  payments: PaymentInfo[];
  createdAt: string;
  updatedAt: string;
  confirmedAt?: string;
  completedAt?: string;
  cancelledAt?: string;
  cancellationReason?: string;
}

interface PaymentInfo {
  id: string;
  amount: number;
  method: string;
  reference?: string;
  paidAt: string;
  notes?: string;
}

interface GetClientBookingDetailsResponse {
  success: boolean;
  booking?: ClientBooking;
  error?: string;
}

// ==================== HELPER FUNCTIONS ====================

/**
 * Get supplier info for display (sanitized for client view)
 */
async function getSupplierInfo(supplierId: string): Promise<{
  name?: string;
  photo?: string;
  category?: string;
}> {
  try {
    const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
    if (!supplierDoc.exists) return {};

    const data = supplierDoc.data()!;
    return {
      name: data.businessName || "Fornecedor",
      photo: data.logoUrl || data.profileImageUrl,
      category: data.category,
    };
  } catch {
    return {};
  }
}

/**
 * Sanitize booking for client view
 * Removes sensitive fields that clients shouldn't see (e.g., supplier notes)
 */
function sanitizeBookingForClient(
    doc: FirebaseFirestore.DocumentSnapshot,
    supplierInfo: {name?: string; photo?: string; category?: string}
): ClientBooking {
  const data = doc.data()!;

  // Parse payments
  const payments: PaymentInfo[] = [];
  if (Array.isArray(data.payments)) {
    for (const p of data.payments) {
      payments.push({
        id: p.id || "",
        amount: p.amount || 0,
        method: p.method || "",
        reference: p.reference,
        paidAt: p.paidAt?.toDate?.()?.toISOString() || new Date().toISOString(),
        notes: p.notes,
      });
    }
  }

  // Parse customizations
  const customizations: string[] = [];
  if (Array.isArray(data.selectedCustomizations)) {
    for (const c of data.selectedCustomizations) {
      if (typeof c === "string") {
        customizations.push(c);
      }
    }
  }

  return {
    id: doc.id,
    supplierId: data.supplierId,
    supplierName: supplierInfo.name || data.supplierName || "Fornecedor",
    supplierPhoto: supplierInfo.photo,
    categoryName: supplierInfo.category || data.categoryName,
    packageId: data.packageId || "",
    packageName: data.packageName || "",
    eventName: data.eventName || "",
    eventType: data.eventType,
    eventDate: data.eventDate?.toDate?.()?.toISOString() || new Date().toISOString(),
    eventTime: data.eventTime,
    eventLocation: data.eventLocation,
    guestCount: data.guestCount,
    totalPrice: data.totalPrice || 0,
    paidAmount: data.paidAmount || 0,
    remainingAmount: (data.totalPrice || 0) - (data.paidAmount || 0),
    currency: data.currency || "AOA",
    status: data.status || "pending",
    paymentStatus: data.paymentStatus || "unpaid",
    notes: data.notes,
    clientNotes: data.clientNotes,
    // supplierNotes intentionally omitted - private to supplier
    selectedCustomizations: customizations,
    payments,
    createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    updatedAt: data.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    confirmedAt: data.confirmedAt?.toDate?.()?.toISOString(),
    completedAt: data.completedAt?.toDate?.()?.toISOString(),
    cancelledAt: data.cancelledAt?.toDate?.()?.toISOString(),
    cancellationReason: data.cancellationReason,
  };
}

// ==================== CLOUD FUNCTIONS ====================

/**
 * Get details of a specific booking for the authenticated client
 *
 * Security: Validates that the booking belongs to the client
 */
export const getClientBookingDetails = functions
    .region(REGION)
    .https.onCall(async (data, context): Promise<GetClientBookingDetailsResponse> => {
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
        const clientId = context.auth.uid;

        // 3. Get the booking
        const bookingDoc = await db.collection("bookings").doc(data.bookingId).get();

        if (!bookingDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Reserva não encontrada"
          );
        }

        // 4. Validate ownership - client must own this booking
        const bookingData = bookingDoc.data()!;
        if (bookingData.clientId !== clientId) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Esta reserva não lhe pertence"
          );
        }

        // 5. Get supplier info for display
        const supplierInfo = await getSupplierInfo(bookingData.supplierId);

        // 6. Sanitize and return
        const booking = sanitizeBookingForClient(bookingDoc, supplierInfo);

        console.log(
            `getClientBookingDetails: Returned booking ${data.bookingId} for client ${clientId}`
        );

        return {
          success: true,
          booking,
        };
      } catch (error) {
        console.error("Error in getClientBookingDetails:", error);

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
 * Get all bookings for the authenticated client
 *
 * Security: Only returns bookings where clientId matches authenticated user
 */
export const getClientBookings = functions
    .region(REGION)
    .https.onCall(async (data, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      try {
        const clientId = context.auth.uid;

        // 2. Query bookings for this client
        const bookingsQuery = await db
            .collection("bookings")
            .where("clientId", "==", clientId)
            .orderBy("createdAt", "desc")
            .limit(100)
            .get();

        // 3. Sanitize and enrich bookings
        const bookings: ClientBooking[] = [];

        for (const doc of bookingsQuery.docs) {
          const supplierInfo = await getSupplierInfo(doc.data().supplierId);
          bookings.push(sanitizeBookingForClient(doc, supplierInfo));
        }

        console.log(
            `getClientBookings: Returned ${bookings.length} bookings for client ${clientId}`
        );

        return {
          success: true,
          bookings,
        };
      } catch (error) {
        console.error("Error in getClientBookings:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao carregar reservas"
        );
      }
    });
