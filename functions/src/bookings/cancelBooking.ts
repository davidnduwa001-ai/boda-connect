import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {canCancel} from "./bookingStateMachine";
import {
  getEscrowByBookingId,
  refundEscrow,
} from "../finance/escrowService";
import {isAdminUser, isSupplier} from "../common/adminAuth";

const db = admin.firestore();
const REGION = "us-central1";

interface CancelBookingRequest {
  bookingId: string;
  reason?: string;
}

interface CancelBookingResponse {
  success: boolean;
  bookingId?: string;
  previousStatus?: string;
  error?: string;
  errorCode?: string;
}

/**
 * Cancel Booking - Callable Cloud Function
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates the booking exists
 * 3. Validates the caller is a participant (client, supplier) or admin
 * 4. Validates the booking can be cancelled (using state machine)
 * 5. Updates the booking status to cancelled with audit trail
 *
 * NOTE: This function does NOT handle refunds. Refund logic will be
 * implemented in Phase 2.3B (Escrow/Refund Authority).
 */
export const cancelBooking = functions
    .region(REGION)
    .https.onCall(async (data: CancelBookingRequest, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado para cancelar a reserva"
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
        const currentStatus = booking.status as string;

        // 4. Check if caller is authorized
        const isClient = booking.clientId === callerId;
        const isSupplier = await isSupplier(
            booking.supplierId,
            callerId
        );
        const isAdmin = await isAdminUser(callerId);

        if (!isClient && !isSupplier && !isAdmin) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Você não tem permissão para cancelar esta reserva"
          );
        }

        // 5. Check if already cancelled (idempotent)
        if (currentStatus === "cancelled") {
          console.log(
              `Idempotent cancellation for booking ${data.bookingId}: already cancelled`
          );
          return {
            success: true,
            bookingId: data.bookingId,
            previousStatus: currentStatus,
          } as CancelBookingResponse;
        }

        // 6. Validate the booking can be cancelled using state machine
        if (!canCancel(currentStatus)) {
          const statusLabels: Record<string, string> = {
            pending: "pendente",
            confirmed: "confirmada",
            completed: "concluída",
            cancelled: "cancelada",
          };
          const label = statusLabels[currentStatus] || currentStatus;

          throw new functions.https.HttpsError(
              "failed-precondition",
              `Não é possível cancelar uma reserva ${label}`
          );
        }

        // 7. Build the update
        const now = admin.firestore.FieldValue.serverTimestamp();
        const updates: Record<string, unknown> = {
          status: "cancelled",
          cancelledAt: now,
          cancelledBy: callerId,
          updatedAt: now,
          updatedBy: callerId,
        };

        // Add cancellation reason if provided
        if (data.reason) {
          updates.cancellationReason = data.reason;
        }

        // Determine canceller role for tracking
        if (isClient) {
          updates.cancelledByRole = "client";
        } else if (isSupplier) {
          updates.cancelledByRole = "supplier";
        } else if (isAdmin) {
          updates.cancelledByRole = "admin";
        }

        // 8. Update the booking
        await bookingRef.update(updates);

        console.log(
            `Booking ${data.bookingId} cancelled: ${currentStatus} → cancelled by ${callerId}`
        );

        // 9. Handle escrow refund if applicable
        // When a booking is cancelled, any funded escrow should be refunded to the client
        const escrow = await getEscrowByBookingId(data.bookingId);
        if (escrow) {
          const refundableStatuses = ["funded", "service_completed", "disputed"];
          if (refundableStatuses.includes(escrow.status)) {
            try {
              const cancelledByRole = isClient ? "client" : isSupplier ? "supplier" : "admin";
              const refundReason = data.reason ||
                `Booking cancelled by ${cancelledByRole}`;

              await refundEscrow(escrow.id, `${cancelledByRole}:${callerId}`, refundReason);

              console.log(
                  `Escrow ${escrow.id} refunded for cancelled booking ${data.bookingId}`
              );
            } catch (escrowError) {
              // Log error but don't fail the cancellation
              // Admin will need to manually process the refund
              console.error(
                  `Error refunding escrow for cancelled booking ${data.bookingId}:`,
                  escrowError
              );
            }
          } else {
            console.log(
                `Escrow ${escrow.id} not refundable (status: ${escrow.status})`
            );
          }
        }

        // 10. Create audit log entry
        await db.collection("audit_logs").add({
          category: "booking",
          eventType: "bookingCancelled",
          userId: callerId,
          resourceId: data.bookingId,
          resourceType: "booking",
          previousValue: currentStatus,
          newValue: "cancelled",
          description: `Booking cancelled by ${isClient ? "client" : isSupplier ? "supplier" : "admin"}`,
          metadata: {
            bookingId: data.bookingId,
            clientId: booking.clientId,
            supplierId: booking.supplierId,
            reason: data.reason || null,
            cancelledByRole: isClient ? "client" : isSupplier ? "supplier" : "admin",
            isAdmin,
          },
          timestamp: now,
        });

        // 11. Create notification for the other party
        const notifyUserId = isClient
          ? await getSupplierUserId(booking.supplierId)
          : booking.clientId;

        if (notifyUserId) {
          const notificationRef = db.collection("notifications").doc();
          await notificationRef.set({
            id: notificationRef.id,
            userId: notifyUserId,
            type: "booking_cancelled",
            title: "Reserva Cancelada",
            body: data.reason
              ? `A reserva foi cancelada: ${data.reason}`
              : "A reserva foi cancelada",
            data: {
              bookingId: data.bookingId,
              eventDate: booking.eventDate,
            },
            read: false,
            createdAt: now,
          });
        }

        return {
          success: true,
          bookingId: data.bookingId,
          previousStatus: currentStatus,
        } as CancelBookingResponse;
      } catch (error) {
        console.error("Error cancelling booking:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao cancelar reserva. Tente novamente."
        );
      }
    });

/**
 * Get the user ID associated with a supplier
 */
async function getSupplierUserId(supplierId: string): Promise<string | null> {
  const supplierDoc = await db.collection("suppliers").doc(supplierId).get();

  if (!supplierDoc.exists) {
    return null;
  }

  const supplier = supplierDoc.data()!;
  return supplier.userId || null;
}
