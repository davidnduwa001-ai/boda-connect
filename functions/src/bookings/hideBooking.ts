import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const REGION = "us-central1";

interface HideBookingRequest {
  bookingId: string;
}

interface HideBookingResponse {
  success: boolean;
  bookingId?: string;
  error?: string;
}

/**
 * Hide Booking from Client View - Callable Cloud Function
 *
 * Allows clients to hide old/cancelled/completed bookings from their view.
 * Only the booking's client can hide it from their view.
 * Hidden bookings are not deleted - they're just excluded from the client projection.
 *
 * Bookings can only be hidden if they are:
 * - cancelled
 * - rejected
 * - completed
 * - refunded
 */
export const hideBookingFromView = functions
    .region(REGION)
    .https.onCall(async (data: HideBookingRequest, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado"
        );
      }

      const callerId = context.auth.uid;

      // 2. Validate required fields
      if (!data.bookingId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "bookingId é obrigatório"
        );
      }

      try {
        // 3. Get the booking
        const bookingRef = db.collection("bookings").doc(data.bookingId);
        const bookingDoc = await bookingRef.get();

        if (!bookingDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Reserva não encontrada"
          );
        }

        const booking = bookingDoc.data()!;

        // 4. Check if caller is the client
        if (booking.clientId !== callerId) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Você não tem permissão para ocultar esta reserva"
          );
        }

        // 5. Check if booking can be hidden (only finished bookings)
        const hidableStatuses = ["cancelled", "rejected", "completed", "refunded"];
        if (!hidableStatuses.includes(booking.status)) {
          throw new functions.https.HttpsError(
              "failed-precondition",
              "Apenas reservas canceladas, recusadas ou concluídas podem ser ocultadas"
          );
        }

        // 6. Mark booking as hidden by client
        await bookingRef.update({
          hiddenByClient: true,
          hiddenByClientAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Booking ${data.bookingId} hidden by client ${callerId}`);

        return {
          success: true,
          bookingId: data.bookingId,
        } as HideBookingResponse;
      } catch (error) {
        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        console.error("Error hiding booking:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Erro ao ocultar reserva"
        );
      }
    });
