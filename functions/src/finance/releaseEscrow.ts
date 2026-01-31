/**
 * Release Escrow - Callable Cloud Function
 *
 * Releases escrow funds to supplier after service completion.
 * Only authorized users (admin, supplier, or auto-release) can trigger this.
 *
 * Security:
 * - Validates caller is admin OR supplier for this booking
 * - Validates escrow is in releasable state
 * - Creates full audit trail
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {releaseEscrow as releaseEscrowService} from "./escrowService";
import {isAdminUser} from "../common/adminAuth";

const db = admin.firestore();
const REGION = "us-central1";

interface ReleaseEscrowRequest {
  escrowId: string;
  notes?: string;
}

interface ReleaseEscrowResponse {
  success: boolean;
  escrowId?: string;
  supplierPayout?: number;
  platformFee?: number;
  error?: string;
  errorCode?: string;
}

/**
 * Check if caller is the client for this escrow
 */
async function checkIsClient(
    escrowData: FirebaseFirestore.DocumentData,
    userId: string
): Promise<boolean> {
  return escrowData.clientId === userId;
}

/**
 * Release Escrow - Callable Cloud Function
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates the escrow exists
 * 3. Validates the caller is authorized (client who confirms, or admin)
 * 4. Validates the escrow can be released
 * 5. Releases funds to supplier with full audit trail
 */
export const releaseEscrowFunction = functions
    .region(REGION)
    .https.onCall(async (data: ReleaseEscrowRequest, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado para liberar o escrow"
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

        // 4. Check if caller is authorized
        const isAdmin = await isAdminUser(callerId);
        const isClient = await checkIsClient(escrowData, callerId);

        // Only admin or the client (confirming service) can release
        if (!isAdmin && !isClient) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Você não tem permissão para liberar este escrow"
          );
        }

        // 5. Check if already released (idempotent)
        if (currentStatus === "released") {
          console.log(`Idempotent release for escrow ${data.escrowId}: already released`);
          return {
            success: true,
            escrowId: data.escrowId,
            supplierPayout: escrowData.supplierPayout,
            platformFee: escrowData.platformFee,
          } as ReleaseEscrowResponse;
        }

        // 6. Validate the escrow can be released
        const releasableStatuses = ["funded", "service_completed"];
        if (!releasableStatuses.includes(currentStatus)) {
          throw new functions.https.HttpsError(
              "failed-precondition",
              `Escrow não pode ser liberado: status atual é "${currentStatus}"`
          );
        }

        // 7. Determine releaser identity
        let releasedBy = callerId;
        if (isClient) {
          releasedBy = `client:${callerId}`;
        } else if (isAdmin) {
          releasedBy = `admin:${callerId}`;
        }

        // 8. Release the escrow
        const result = await releaseEscrowService(
            data.escrowId,
            releasedBy,
            data.notes
        );

        console.log(
            `Escrow ${data.escrowId} released by ${releasedBy}: ` +
            `supplier payout ${result.supplierPayout}, platform fee ${result.platformFee}`
        );

        return {
          success: true,
          escrowId: data.escrowId,
          supplierPayout: result.supplierPayout,
          platformFee: result.platformFee,
        } as ReleaseEscrowResponse;
      } catch (error) {
        console.error("Error releasing escrow:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao liberar escrow. Tente novamente."
        );
      }
    });
