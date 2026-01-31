/**
 * Refund Escrow - Callable Cloud Function
 *
 * Refunds escrow funds to client after cancellation or dispute resolution.
 * Only authorized users (admin or system) can trigger refunds.
 *
 * Security:
 * - Only admins can manually refund
 * - System can auto-refund on booking cancellation
 * - Creates full audit trail
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {refundEscrow as refundEscrowService} from "./escrowService";
import {isAdminUser} from "../common/adminAuth";

const db = admin.firestore();
const REGION = "us-central1";

interface RefundEscrowRequest {
  escrowId: string;
  reason?: string;
}

interface RefundEscrowResponse {
  success: boolean;
  escrowId?: string;
  refundAmount?: number;
  error?: string;
  errorCode?: string;
}

/**
 * Refund Escrow - Callable Cloud Function
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates the escrow exists
 * 3. Validates the caller is authorized (admin only for manual refunds)
 * 4. Validates the escrow can be refunded
 * 5. Refunds funds to client with full audit trail
 */
export const refundEscrowFunction = functions
    .region(REGION)
    .https.onCall(async (data: RefundEscrowRequest, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado para reembolsar o escrow"
        );
      }

      const callerId = context.auth.uid;

      // 2. Validate required fields
      if (!data.escrowId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "escrowId é obrigatório"
        );
      }

      try {
        // 3. Get the escrow
        const escrowDoc = await db.collection("escrow").doc(data.escrowId).get();

        if (!escrowDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Escrow não encontrado"
          );
        }

        const escrowData = escrowDoc.data()!;
        const currentStatus = escrowData.status as string;

        // 4. Check if caller is admin (only admins can manually refund)
        const isAdmin = await isAdminUser(callerId);

        if (!isAdmin) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Apenas administradores podem processar reembolsos"
          );
        }

        // 5. Check if already refunded (idempotent)
        if (currentStatus === "refunded") {
          console.log(`Idempotent refund for escrow ${data.escrowId}: already refunded`);
          return {
            success: true,
            escrowId: data.escrowId,
            refundAmount: escrowData.totalAmount,
          } as RefundEscrowResponse;
        }

        // 6. Validate the escrow can be refunded
        const refundableStatuses = ["funded", "service_completed", "disputed"];
        if (!refundableStatuses.includes(currentStatus)) {
          throw new functions.https.HttpsError(
              "failed-precondition",
              `Escrow não pode ser reembolsado: status atual é "${currentStatus}"`
          );
        }

        // 7. Refund the escrow
        const result = await refundEscrowService(
            data.escrowId,
            `admin:${callerId}`,
            data.reason
        );

        console.log(
            `Escrow ${data.escrowId} refunded by admin ${callerId}: ` +
            `amount ${result.refundAmount}`
        );

        return {
          success: true,
          escrowId: data.escrowId,
          refundAmount: result.refundAmount,
        } as RefundEscrowResponse;
      } catch (error) {
        console.error("Error refunding escrow:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao reembolsar escrow. Tente novamente."
        );
      }
    });
