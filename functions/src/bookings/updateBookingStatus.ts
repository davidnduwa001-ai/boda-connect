import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {validateTransition} from "./bookingStateMachine";
import {
  getEscrowByBookingId,
  markServiceCompleted,
} from "../finance/escrowService";
import {isAdminUser, isSupplierUser} from "../common/adminAuth";

const db = admin.firestore();
const REGION = "us-central1";

interface UpdateBookingStatusRequest {
  bookingId: string;
  newStatus: string;
}

interface UpdateBookingStatusResponse {
  success: boolean;
  bookingId?: string;
  previousStatus?: string;
  newStatus?: string;
  error?: string;
  errorCode?: string;
}

/**
 * Update Booking Status - Callable Cloud Function
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates the booking exists
 * 3. Validates the caller is a participant (client, supplier) or admin
 * 4. Validates the status transition using the state machine
 * 5. Updates the booking status atomically with transaction
 *
 * CONCURRENCY: Uses Firestore transaction to prevent race conditions
 * where concurrent calls could cause invalid state transitions.
 */
export const updateBookingStatus = functions
    .region(REGION)
    .https.onCall(async (data: UpdateBookingStatusRequest, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado para atualizar o estado da reserva"
        );
      }

      const callerId = context.auth.uid;

      // 2. Validate required fields
      if (!data.bookingId || !data.newStatus) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "bookingId e newStatus são obrigatórios"
        );
      }

      try {
        const bookingRef = db.collection("bookings").doc(data.bookingId);

        // Pre-fetch authorization data (outside transaction for efficiency)
        // These don't change during the transaction
        const isAdmin = await isAdminUser(callerId);

        // Use transaction for atomic read-check-write
        const result = await db.runTransaction(async (transaction) => {
          // 3. Get the booking (inside transaction for consistency)
          const bookingDoc = await transaction.get(bookingRef);

          if (!bookingDoc.exists) {
            throw new functions.https.HttpsError(
                "not-found",
                "Reserva não encontrada"
            );
          }

          const booking = bookingDoc.data()!;
          const currentStatus = booking.status as string;

          // 4. Check if caller is authorized
          const isClient = booking.clientId === callerId;
          const isSupplier = await isSupplierUser(booking.supplierId, callerId);

          if (!isClient && !isSupplier && !isAdmin) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Você não tem permissão para atualizar esta reserva"
            );
          }

          // 5. Additional authorization based on transition type
          // Only suppliers/admins can confirm bookings
          if (data.newStatus === "confirmed" && !isSupplier && !isAdmin) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Apenas o fornecedor pode confirmar a reserva"
            );
          }

          // Only suppliers/admins can mark bookings as completed
          if (data.newStatus === "completed" && !isSupplier && !isAdmin) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Apenas o fornecedor pode marcar a reserva como concluída"
            );
          }

          // 6. Validate the status transition using state machine
          const validation = validateTransition(currentStatus, data.newStatus);

          if (!validation.allowed) {
            throw new functions.https.HttpsError(
                "failed-precondition",
                validation.error || "Transição de estado inválida"
            );
          }

          // If same status, return success without update (idempotent)
          if (currentStatus === data.newStatus) {
            console.log(
                `Idempotent status update for booking ${data.bookingId}: already ${currentStatus}`
            );
            return {
              idempotent: true,
              previousStatus: currentStatus,
              newStatus: data.newStatus,
              booking,
            };
          }

          // 7. Build the update
          const now = admin.firestore.FieldValue.serverTimestamp();
          const updates: Record<string, unknown> = {
            status: data.newStatus,
            updatedAt: now,
            updatedBy: callerId,
          };

          // Add status-specific timestamps
          switch (data.newStatus) {
            case "confirmed":
              updates.confirmedAt = now;
              updates.confirmedBy = callerId;
              break;
            case "completed":
              updates.completedAt = now;
              updates.completedBy = callerId;
              break;
            case "cancelled":
              updates.cancelledAt = now;
              updates.cancelledBy = callerId;
              break;
          }

          // 8. Update the booking atomically
          transaction.update(bookingRef, updates);

          console.log(
              `Booking ${data.bookingId} status updated: ${currentStatus} → ${data.newStatus} by ${callerId}`
          );

          return {
            idempotent: false,
            previousStatus: currentStatus,
            newStatus: data.newStatus,
            booking,
            isAdmin,
          };
        });

        // Handle idempotent case
        if (result.idempotent) {
          return {
            success: true,
            bookingId: data.bookingId,
            previousStatus: result.previousStatus,
            newStatus: result.newStatus,
          } as UpdateBookingStatusResponse;
        }

        // Post-transaction side effects (outside transaction)
        const booking = result.booking;

        // 9. Block date in supplier's calendar when confirmed
        if (data.newStatus === "confirmed") {
          try {
            await blockDateForBooking(
                booking.supplierId,
                data.bookingId,
                booking.eventDate,
                booking.eventName || "Reserva confirmada"
            );
            console.log(
                `Blocked date for booking ${data.bookingId} on supplier ${booking.supplierId}`
            );
          } catch (blockError) {
            // Log error but don't fail the booking confirmation
            console.error(
                `Error blocking date for booking ${data.bookingId}:`,
                blockError
            );
          }
        }

        // 10. Handle escrow operations based on new status
        if (data.newStatus === "completed") {
          // When booking is completed, mark escrow service as completed
          // This starts the auto-release timer (48 hours by default)
          const escrow = await getEscrowByBookingId(data.bookingId);
          if (escrow && escrow.status === "funded") {
            try {
              await markServiceCompleted(escrow.id);
              console.log(
                  `Escrow ${escrow.id} marked as service_completed for booking ${data.bookingId}`
              );
            } catch (escrowError) {
              // Log error but don't fail the booking status update
              console.error(
                  `Error marking escrow service completed for booking ${data.bookingId}:`,
                  escrowError
              );
            }
          }
        }

        // 11. Create audit log entry
        const now = admin.firestore.FieldValue.serverTimestamp();
        await db.collection("audit_logs").add({
          category: "booking",
          eventType: "statusChanged",
          userId: callerId,
          resourceId: data.bookingId,
          resourceType: "booking",
          previousValue: result.previousStatus,
          newValue: result.newStatus,
          description: `Booking status changed from ${result.previousStatus} to ${result.newStatus}`,
          metadata: {
            bookingId: data.bookingId,
            clientId: booking.clientId,
            supplierId: booking.supplierId,
            isAdmin: result.isAdmin,
          },
          timestamp: now,
        });

        return {
          success: true,
          bookingId: data.bookingId,
          previousStatus: result.previousStatus,
          newStatus: result.newStatus,
        } as UpdateBookingStatusResponse;
      } catch (error) {
        console.error("Error updating booking status:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao atualizar estado da reserva. Tente novamente."
        );
      }
    });

/**
 * Block a date in supplier's calendar when booking is confirmed
 * Creates an entry in the supplier's blocked_dates subcollection
 */
async function blockDateForBooking(
    supplierId: string,
    bookingId: string,
    eventDate: admin.firestore.Timestamp | Date,
    eventName: string
): Promise<void> {
  // Check if this booking already has a blocked date entry
  const existingQuery = await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blocked_dates")
      .where("bookingId", "==", bookingId)
      .limit(1)
      .get();

  if (!existingQuery.empty) {
    console.log(`Blocked date already exists for booking ${bookingId}`);
    return;
  }

  // Convert eventDate to proper format if needed
  let dateTimestamp: admin.firestore.Timestamp;
  if (eventDate instanceof admin.firestore.Timestamp) {
    dateTimestamp = eventDate;
  } else if (eventDate instanceof Date) {
    dateTimestamp = admin.firestore.Timestamp.fromDate(eventDate);
  } else {
    // Handle case where eventDate might be a Firestore timestamp object
    dateTimestamp = eventDate as admin.firestore.Timestamp;
  }

  // Create blocked date entry
  await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blocked_dates")
      .add({
        date: dateTimestamp,
        reason: eventName,
        type: "reserved",
        bookingId: bookingId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
}
