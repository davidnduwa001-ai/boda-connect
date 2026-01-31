import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {fundEscrow} from "../finance/escrowService";

const db = admin.firestore();
const REGION = "us-central1";

// ProxyPay configuration
const PROXYPAY_CONFIG = {
  sandboxUrl: "https://api.sandbox.proxypay.co.ao",
  prodUrl: "https://api.proxypay.co.ao",
  apiKey: process.env.PROXYPAY_API_KEY || "",
  useSandbox: process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.NODE_ENV !== "production",
};

interface ConfirmPaymentRequest {
  paymentId: string;
}

interface ConfirmPaymentResponse {
  success: boolean;
  status: string;
  paidAmount?: number;
  error?: string;
}

/**
 * Check payment status with ProxyPay API
 */
async function checkProxyPayStatus(
    providerPaymentId: string,
    provider: string
): Promise<{status: string; paidAmount?: number}> {
  const baseUrl = PROXYPAY_CONFIG.useSandbox ?
    PROXYPAY_CONFIG.sandboxUrl :
    PROXYPAY_CONFIG.prodUrl;

  const basicAuth = Buffer.from(`:${PROXYPAY_CONFIG.apiKey}`).toString("base64");

  let endpoint: string;
  if (provider === "proxypay_opg") {
    endpoint = `/opg/v1/payments/${providerPaymentId}`;
  } else {
    endpoint = `/references/${providerPaymentId}`;
  }

  const response = await fetch(`${baseUrl}${endpoint}`, {
    method: "GET",
    headers: {
      "Accept": "application/vnd.proxypay.v2+json",
      "Authorization": `Basic ${basicAuth}`,
    },
  });

  if (!response.ok) {
    console.error(`ProxyPay status check failed: ${response.status}`);
    throw new Error("Failed to check payment status");
  }

  const data = await response.json() as {status?: string; amount?: string};

  return {
    status: data.status || "pending",
    paidAmount: data.amount ? parseInt(data.amount, 10) : undefined,
  };
}

/**
 * Map ProxyPay status to our internal status
 */
function mapProxyPayStatus(apiStatus: string): string {
  switch (apiStatus.toLowerCase()) {
    case "accepted":
    case "completed":
    case "paid":
      return "completed";
    case "rejected":
    case "failed":
    case "error":
      return "failed";
    case "cancelled":
    case "canceled":
      return "cancelled";
    case "expired":
      return "expired";
    case "pending":
    case "active":
    default:
      return "pending";
  }
}

/**
 * Update booking with payment info
 */
async function updateBookingPayment(
    bookingId: string,
    paymentId: string,
    amount: number
): Promise<void> {
  const bookingRef = db.collection("bookings").doc(bookingId);

  await bookingRef.update({
    paymentStatus: "paid",
    paidAmount: admin.firestore.FieldValue.increment(amount),
    payments: admin.firestore.FieldValue.arrayUnion({
      paymentId: paymentId,
      amount: amount,
      method: "multicaixa_express",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Notify supplier
  const bookingDoc = await bookingRef.get();
  if (!bookingDoc.exists) {
    console.warn(`Booking ${bookingId} not found for payment notification`);
    return;
  }

  const booking = bookingDoc.data()!;
  const supplierId = booking.supplierId;

  if (!supplierId) {
    console.warn(`Booking ${bookingId} missing supplierId`);
    return;
  }

  // Get supplier's userId
  const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
  if (!supplierDoc.exists) {
    console.warn(`Supplier ${supplierId} not found for payment notification`);
    return;
  }

  const supplierUserId = supplierDoc.data()?.userId;
  if (!supplierUserId) {
    console.warn(`Supplier ${supplierId} missing userId`);
    return;
  }

  // Validate amount before formatting
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    console.warn(`Invalid payment amount: ${amount}`);
    return;
  }

  const formatted = new Intl.NumberFormat("pt-AO", {
    style: "currency",
    currency: "AOA",
  }).format(amount);

  await db.collection("notifications").add({
    userId: supplierUserId,
    type: "payment_received",
    title: "Pagamento Recebido! 💰",
    body: `Você recebeu um pagamento de ${formatted}`,
    data: {bookingId, paymentId, amount: amount.toString()},
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Payment notification sent to supplier ${supplierId}`);
}

/**
 * Handle escrow funding if applicable
 * Uses escrowService for server-side authority
 */
async function handleEscrowFunding(
    paymentId: string,
    paymentData: FirebaseFirestore.DocumentData
): Promise<void> {
  const escrowId = paymentData.metadata?.escrowId;
  if (!escrowId) return;

  // Use server-side escrow service (handles all updates and notifications)
  await fundEscrow(escrowId, paymentId);

  console.log(`Escrow funded via escrowService: ${escrowId}`);
}

/**
 * Confirm Payment - Callable Cloud Function
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates the caller owns the payment or is admin
 * 3. Checks payment status with ProxyPay API
 * 4. Updates payment record in Firestore
 * 5. Updates booking if payment is completed
 * 6. Handles escrow funding if applicable
 */
export const confirmPayment = functions
    .region(REGION)
    .https.onCall(async (data: ConfirmPaymentRequest, context) => {
      // Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado"
        );
      }

      const callerId = context.auth.uid;

      // Validate required fields
      if (!data.paymentId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "paymentId é obrigatório"
        );
      }

      try {
        // Get payment record
        const paymentDoc = await db.collection("payments").doc(data.paymentId).get();

        if (!paymentDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Pagamento não encontrado"
          );
        }

        const payment = paymentDoc.data()!;

        // Verify caller owns this payment or is admin
        const isAdmin = context.auth.token.admin === true;
        if (payment.userId !== callerId && !isAdmin) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Você não tem permissão para verificar este pagamento"
          );
        }

        // If payment is already completed/failed, just return status
        if (["completed", "failed", "refunded", "cancelled"].includes(payment.status)) {
          return {
            success: true,
            status: payment.status,
            paidAmount: payment.status === "completed" ? payment.amount : 0,
          } as ConfirmPaymentResponse;
        }

        // Check with ProxyPay API
        const providerStatus = await checkProxyPayStatus(
            payment.providerPaymentId,
            payment.provider
        );

        const newStatus = mapProxyPayStatus(providerStatus.status);

        // Update payment record
        const updateData: Record<string, unknown> = {
          status: newStatus,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (newStatus === "completed") {
          updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
        } else if (newStatus === "failed") {
          updateData.failedAt = admin.firestore.FieldValue.serverTimestamp();
        }

        await db.collection("payments").doc(data.paymentId).update(updateData);

        // If payment completed, update booking
        if (newStatus === "completed" && payment.bookingId) {
          await updateBookingPayment(
              payment.bookingId,
              data.paymentId,
              payment.amount
          );

          // Handle escrow if applicable
          await handleEscrowFunding(data.paymentId, payment);
        }

        console.log(`Payment ${data.paymentId} status: ${newStatus}`);

        return {
          success: true,
          status: newStatus,
          paidAmount: newStatus === "completed" ? payment.amount : 0,
        } as ConfirmPaymentResponse;
      } catch (error) {
        console.error("Error confirming payment:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao verificar pagamento. Tente novamente."
        );
      }
    });

/**
 * Cancel Payment - Callable Cloud Function
 *
 * Allows client to cancel a pending payment
 */
export const cancelPayment = functions
    .region(REGION)
    .https.onCall(async (data: {paymentId: string}, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado"
        );
      }

      const callerId = context.auth.uid;

      if (!data.paymentId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "paymentId é obrigatório"
        );
      }

      try {
        const paymentDoc = await db.collection("payments").doc(data.paymentId).get();

        if (!paymentDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Pagamento não encontrado"
          );
        }

        const payment = paymentDoc.data()!;

        // Verify ownership
        if (payment.userId !== callerId) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Você não tem permissão para cancelar este pagamento"
          );
        }

        // Can only cancel pending payments
        if (payment.status !== "pending") {
          throw new functions.https.HttpsError(
              "failed-precondition",
              "Só é possível cancelar pagamentos pendentes"
          );
        }

        await db.collection("payments").doc(data.paymentId).update({
          status: "cancelled",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledBy: callerId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Payment cancelled: ${data.paymentId}`);

        return {success: true, status: "cancelled"};
      } catch (error) {
        console.error("Error cancelling payment:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao cancelar pagamento. Tente novamente."
        );
      }
    });
