import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {validateTransition} from "./bookingStateMachine";
import {
  getEscrowByBookingId,
  markServiceCompleted,
} from "../finance/escrowService";

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
 * 5. Updates the booking status with audit trail
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
        const currentStatus = booking.status as string;

        // 4. Check if caller is authorized
        const isClient = booking.clientId === callerId;
        const isSupplierUser = await checkIsSupplierUser(
            booking.supplierId,
            callerId
        );
        const isAdmin = await checkIsAdmin(callerId);

        if (!isClient && !isSupplierUser && !isAdmin) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Você não tem permissão para atualizar esta reserva"
          );
        }

        // 5. Additional authorization based on transition type
        // Only suppliers/admins can confirm bookings
        if (data.newStatus === "confirmed" && !isSupplierUser && !isAdmin) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Apenas o fornecedor pode confirmar a reserva"
          );
        }

        // Only suppliers/admins can mark bookings as completed
        if (data.newStatus === "completed" && !isSupplierUser && !isAdmin) {
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
            success: true,
            bookingId: data.bookingId,
            previousStatus: currentStatus,
            newStatus: data.newStatus,
          } as UpdateBookingStatusResponse;
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

        // 8. Update the booking
        await bookingRef.update(updates);

        console.log(
            `Booking ${data.bookingId} status updated: ${currentStatus} → ${data.newStatus} by ${callerId}`
        );

        // 9. Update blocked date in supplier's calendar based on status
        try {
          await updateBlockedDateForBooking(
              booking.supplierId,
              data.bookingId,
              booking.eventDate,
              data.newStatus,
              booking.clientName || "Cliente"
          );
          console.log(
              `Updated blocked date for booking ${data.bookingId}, status: ${data.newStatus}`
          );
        } catch (blockError) {
          // Log error but don't fail the booking status update
          console.error(
              `Error updating blocked date for booking ${data.bookingId}:`,
              blockError
          );
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
        await db.collection("audit_logs").add({
          category: "booking",
          eventType: "statusChanged",
          userId: callerId,
          resourceId: data.bookingId,
          resourceType: "booking",
          previousValue: currentStatus,
          newValue: data.newStatus,
          description: `Booking status changed from ${currentStatus} to ${data.newStatus}`,
          metadata: {
            bookingId: data.bookingId,
            clientId: booking.clientId,
            supplierId: booking.supplierId,
            isAdmin,
          },
          timestamp: now,
        });

        return {
          success: true,
          bookingId: data.bookingId,
          previousStatus: currentStatus,
          newStatus: data.newStatus,
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
 * Check if a user is the supplier (or owns the supplier profile)
 */
async function checkIsSupplierUser(
    supplierId: string,
    userId: string
): Promise<boolean> {
  const supplierDoc = await db.collection("suppliers").doc(supplierId).get();

  if (!supplierDoc.exists) {
    return false;
  }

  const supplier = supplierDoc.data()!;
  return supplier.userId === userId;
}

/**
 * Check if a user is an admin
 */
async function checkIsAdmin(userId: string): Promise<boolean> {
  const userDoc = await db.collection("users").doc(userId).get();

  if (!userDoc.exists) {
    return false;
  }

  const user = userDoc.data()!;
  return user.role === "admin";
}

/**
 * Update blocked date in supplier's calendar based on booking status
 * - pending: type='requested' (created in createBooking)
 * - confirmed: type='reserved'
 * - completed: type='reserved' (keep blocked)
 * - cancelled: DELETE the blocked date
 */
async function updateBlockedDateForBooking(
    supplierId: string,
    bookingId: string,
    eventDate: admin.firestore.Timestamp | Date,
    newStatus: string,
    clientName: string
): Promise<void> {
  const blockedDatesRef = db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blocked_dates");

  // Use booking ID as doc ID (set in createBooking)
  const blockedDateRef = blockedDatesRef.doc(bookingId);
  const blockedDateDoc = await blockedDateRef.get();

  // Handle cancellation - remove the blocked date
  if (newStatus === "cancelled") {
    if (blockedDateDoc.exists) {
      await blockedDateRef.delete();
      console.log(`Deleted blocked date for cancelled booking ${bookingId}`);
    }
    return;
  }

  // Convert eventDate to proper format if needed
  let dateTimestamp: admin.firestore.Timestamp;
  if (eventDate instanceof admin.firestore.Timestamp) {
    dateTimestamp = eventDate;
  } else if (eventDate instanceof Date) {
    dateTimestamp = admin.firestore.Timestamp.fromDate(eventDate);
  } else {
    dateTimestamp = eventDate as admin.firestore.Timestamp;
  }

  // Determine the type based on status
  let blockedType: "requested" | "reserved" = "requested";
  let reason = `Pedido de ${clientName}`;

  if (newStatus === "confirmed" || newStatus === "completed" || newStatus === "inProgress") {
    blockedType = "reserved";
    reason = `Reserva confirmada - ${clientName}`;
  }

  // Update or create the blocked date
  await blockedDateRef.set({
    date: dateTimestamp,
    type: blockedType,
    reason: reason,
    bookingId: bookingId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}
