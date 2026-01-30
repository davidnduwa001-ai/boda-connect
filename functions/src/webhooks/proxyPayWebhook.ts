import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {fundEscrow} from "../finance/escrowService";

const db = admin.firestore();
const messaging = admin.messaging();
const REGION = "us-central1";

// Webhook secret for verification (set in Firebase environment config)
const WEBHOOK_SECRET = process.env.PROXYPAY_WEBHOOK_SECRET || "";

interface OPGWebhookPayload {
  id: string;
  reference_id: string;
  status: string;
  amount?: string;
  mobile?: string;
  message?: string;
  transaction_id?: string;
  failure_reason?: string;
}

interface RPSWebhookPayload {
  reference: string;
  amount: number;
  datetime: string;
  terminal_id?: string;
  terminal_location?: string;
  transaction_id?: string;
}

/**
 * Map ProxyPay status to internal status
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
 * Send push notification
 */
async function sendNotification(
    userId: string,
    title: string,
    body: string,
    type: string,
    data: Record<string, string> = {}
): Promise<void> {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${userId}`);
      return;
    }

    await messaging.send({
      token: fcmToken,
      notification: {title, body},
      data: {type, ...data},
      android: {
        priority: "high",
        notification: {
          channelId: "boda_connect_channel",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    // Store in notifications collection
    await db.collection("notifications").add({
      userId,
      title,
      body,
      type,
      data,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Notification sent to ${userId}: ${title}`);
  } catch (error) {
    console.error("Error sending notification:", error);
  }
}

/**
 * Format currency for display
 */
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("pt-AO", {
    style: "currency",
    currency: "AOA",
  }).format(amount);
}

/**
 * Update booking with payment info
 */
async function updateBookingPayment(
    bookingId: string,
    paymentId: string,
    amount: number
): Promise<void> {
  await db.collection("bookings").doc(bookingId).update({
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
}

/**
 * Handle escrow funding
 * Uses escrowService for server-side authority
 */
async function handleEscrowFunding(
    paymentData: FirebaseFirestore.DocumentData,
    paymentId: string
): Promise<void> {
  const escrowId = paymentData.metadata?.escrowId;
  if (!escrowId) return;

  // Use server-side escrow service (handles all updates and notifications)
  await fundEscrow(escrowId, paymentId);

  console.log(`Escrow funded via webhook (escrowService): ${escrowId}`);
}

/**
 * Process OPG (mobile payment) webhook
 */
async function processOPGWebhook(payload: OPGWebhookPayload): Promise<void> {
  const {reference_id: reference, status, id: providerPaymentId} = payload;

  if (!reference) {
    console.warn("OPG webhook missing reference_id");
    return;
  }

  // Find payment by reference
  const paymentQuery = await db
      .collection("payments")
      .where("reference", "==", reference)
      .limit(1)
      .get();

  if (paymentQuery.empty) {
    console.warn(`Payment not found for reference: ${reference}`);
    return;
  }

  const paymentDoc = paymentQuery.docs[0];
  const paymentData = paymentDoc.data();
  const paymentId = paymentDoc.id;

  const newStatus = mapProxyPayStatus(status);

  // Update payment record
  const updateData: Record<string, unknown> = {
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
    providerPaymentId: providerPaymentId,
    webhookPayload: payload,
  };

  if (newStatus === "completed") {
    updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
    if (payload.transaction_id) {
      updateData.transactionId = payload.transaction_id;
    }
  } else if (newStatus === "failed") {
    updateData.failedAt = admin.firestore.FieldValue.serverTimestamp();
    updateData.failureReason = payload.failure_reason;
  }

  await db.collection("payments").doc(paymentId).update(updateData);

  // Handle completion
  if (newStatus === "completed") {
    const bookingId = paymentData.bookingId;
    const amount = paymentData.amount || 0;

    if (bookingId) {
      await updateBookingPayment(bookingId, paymentId, amount);
    }

    // Handle escrow if applicable
    await handleEscrowFunding(paymentData, paymentId);

    // Notify supplier of payment
    const supplierId = paymentData.supplierId;
    if (supplierId) {
      const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
      const supplierUserId = supplierDoc.data()?.userId;

      if (supplierUserId) {
        await sendNotification(
            supplierUserId,
            "Pagamento Recebido! 💰",
            `Você recebeu ${formatCurrency(amount)}`,
            "payment_received",
            {bookingId: bookingId || "", paymentId, amount: amount.toString()}
        );
      }
    }

    // Notify client
    const clientId = paymentData.userId;
    if (clientId) {
      await sendNotification(
          clientId,
          "Pagamento Confirmado ✅",
          `Seu pagamento de ${formatCurrency(amount)} foi confirmado`,
          "payment_confirmed",
          {bookingId: bookingId || "", paymentId}
      );
    }
  } else if (newStatus === "failed") {
    // Notify client of failure
    const clientId = paymentData.userId;
    if (clientId) {
      await sendNotification(
          clientId,
          "Pagamento Falhou ❌",
          payload.failure_reason || "Ocorreu um erro no pagamento",
          "payment_failed",
          {paymentId, reason: payload.failure_reason || ""}
      );
    }
  }

  console.log(`OPG webhook processed: ${reference} -> ${newStatus}`);
}

/**
 * Process RPS (reference/ATM payment) webhook
 */
async function processRPSWebhook(payload: RPSWebhookPayload): Promise<void> {
  const {reference, amount} = payload;

  if (!reference) {
    console.warn("RPS webhook missing reference");
    return;
  }

  // Find payment by reference number
  const paymentQuery = await db
      .collection("payments")
      .where("referenceNumber", "==", reference)
      .limit(1)
      .get();

  if (paymentQuery.empty) {
    // Try by internal reference
    const altQuery = await db
        .collection("payments")
        .where("reference", "==", reference)
        .limit(1)
        .get();

    if (altQuery.empty) {
      console.warn(`Payment not found for RPS reference: ${reference}`);
      return;
    }
  }

  const paymentDoc = paymentQuery.empty ?
    (await db.collection("payments").where("reference", "==", reference).limit(1).get()).docs[0] :
    paymentQuery.docs[0];

  const paymentData = paymentDoc.data();
  const paymentId = paymentDoc.id;

  // RPS webhooks are only sent when payment is completed
  const updateData: Record<string, unknown> = {
    status: "completed",
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
    paidAmount: amount,
    webhookPayload: payload,
  };

  if (payload.transaction_id) {
    updateData.transactionId = payload.transaction_id;
  }
  if (payload.terminal_id) {
    updateData.terminalId = payload.terminal_id;
    updateData.terminalLocation = payload.terminal_location;
  }

  await db.collection("payments").doc(paymentId).update(updateData);

  // Update booking
  const bookingId = paymentData.bookingId;
  const paymentAmount = paymentData.amount || amount;

  if (bookingId) {
    await updateBookingPayment(bookingId, paymentId, paymentAmount);
  }

  // Handle escrow
  await handleEscrowFunding(paymentData, paymentId);

  // Notify supplier
  const supplierId = paymentData.supplierId;
  if (supplierId) {
    const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
    const supplierUserId = supplierDoc.data()?.userId;

    if (supplierUserId) {
      await sendNotification(
          supplierUserId,
          "Pagamento Recebido! 💰",
          `Pagamento de ${formatCurrency(paymentAmount)} via ATM/referência`,
          "payment_received",
          {bookingId: bookingId || "", paymentId, amount: paymentAmount.toString()}
      );
    }
  }

  // Notify client
  const clientId = paymentData.userId;
  if (clientId) {
    await sendNotification(
        clientId,
        "Pagamento Confirmado ✅",
        `Seu pagamento de ${formatCurrency(paymentAmount)} foi confirmado`,
        "payment_confirmed",
        {bookingId: bookingId || "", paymentId}
    );
  }

  console.log(`RPS webhook processed: ${reference} -> completed`);
}

/**
 * ProxyPay Webhook Handler - HTTPS Function
 *
 * Receives payment notifications from ProxyPay for both:
 * - OPG (Online Payment Gateway): Mobile payments
 * - RPS (Reference Payment System): ATM/home banking payments
 *
 * Webhook types:
 * - OPG: POST with { id, reference_id, status, amount, mobile, message }
 * - RPS: POST with { reference, amount, datetime, terminal_id, terminal_location }
 */
export const proxyPayWebhook = functions
    .region(REGION)
    .https.onRequest(async (req, res) => {
      // Only accept POST
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      // Verify webhook secret if configured
      if (WEBHOOK_SECRET) {
        const providedSecret = req.headers["x-proxypay-signature"] ||
          req.headers["authorization"];

        if (providedSecret !== WEBHOOK_SECRET &&
            providedSecret !== `Bearer ${WEBHOOK_SECRET}`) {
          console.warn("Invalid webhook signature");
          res.status(401).send("Unauthorized");
          return;
        }
      }

      try {
        const payload = req.body;

        console.log("ProxyPay webhook received:", JSON.stringify(payload));

        // Determine webhook type and process
        if (payload.reference_id || payload.id) {
          // OPG payment callback
          await processOPGWebhook(payload as OPGWebhookPayload);
        } else if (payload.reference && payload.datetime) {
          // RPS payment notification
          await processRPSWebhook(payload as RPSWebhookPayload);
        } else {
          console.warn("Unknown webhook format:", payload);
          res.status(400).send("Unknown webhook format");
          return;
        }

        // Acknowledge webhook
        res.status(200).json({success: true, message: "Webhook processed"});
      } catch (error) {
        console.error("Error processing webhook:", error);
        // Return 200 to prevent retries for processing errors
        // ProxyPay will retry on 4xx/5xx
        res.status(200).json({
          success: false,
          error: "Processing error - logged for investigation",
        });
      }
    });

/**
 * Acknowledge RPS payment (call after processing)
 * This clears the payment from ProxyPay's pending list
 */
export const acknowledgeRPSPayment = functions
    .region(REGION)
    .https.onCall(async (data: {referenceId: string}, context) => {
      // Admin only
      if (!context.auth?.token.admin) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Admin access required"
        );
      }

      const {referenceId} = data;
      if (!referenceId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "referenceId required"
        );
      }

      const baseUrl = process.env.NODE_ENV === "production" ?
        "https://api.proxypay.co.ao" :
        "https://api.sandbox.proxypay.co.ao";

      const apiKey = process.env.PROXYPAY_API_KEY || "";
      const basicAuth = Buffer.from(`:${apiKey}`).toString("base64");

      try {
        const response = await fetch(
            `${baseUrl}/references/${referenceId}/payments`,
            {
              method: "DELETE",
              headers: {
                "Accept": "application/vnd.proxypay.v2+json",
                "Authorization": `Basic ${basicAuth}`,
              },
            }
        );

        if (!response.ok) {
          throw new Error(`Failed to acknowledge: ${response.status}`);
        }

        console.log(`RPS payment acknowledged: ${referenceId}`);
        return {success: true};
      } catch (error) {
        console.error("Error acknowledging RPS payment:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to acknowledge payment"
        );
      }
    });
