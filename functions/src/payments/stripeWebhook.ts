/**
 * Stripe Webhook Handler
 *
 * Handles webhook events from Stripe for payment confirmation.
 * Uses the provider abstraction for consistent webhook processing.
 *
 * SECURITY CRITICAL: Raw Body Requirement
 * ----------------------------------------
 * Stripe webhook signature verification REQUIRES the raw request body.
 * Firebase Functions v1 `https.onRequest` automatically provides `req.rawBody`.
 * DO NOT:
 * - Add JSON body-parsing middleware before this handler
 * - Use `req.body` for signature verification
 * - Fall back to JSON.stringify() as it produces different bytes
 *
 * Supported events:
 * - checkout.session.completed -> payment confirmed
 * - checkout.session.expired -> payment expired
 * - checkout.session.async_payment_failed -> payment failed
 * - charge.refunded -> refund completed
 *
 * Required Environment Variables:
 * - STRIPE_SECRET_KEY: Stripe API secret key
 * - STRIPE_WEBHOOK_SECRET: Webhook endpoint signing secret
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {getStripeProvider} from "./providers";
import {fundEscrow} from "../finance/escrowService";
import {wrapHttpHandler} from "../common/errors";
import {PaymentLogger} from "../common/logger";
import {requireFeatureEnabled} from "../common/killSwitch";
import {isWebhookProcessed, markWebhookProcessed} from "../common/idempotency";

const db = admin.firestore();
const REGION = "us-central1";
const FUNCTION_NAME = "stripeWebhook";

/**
 * Update payment status in Firestore
 */
async function updatePaymentStatus(
    paymentId: string,
    status: string,
    additionalData: Record<string, unknown> = {}
): Promise<void> {
  await db.collection("payments").doc(paymentId).update({
    status,
    ...additionalData,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Find payment by provider payment ID
 */
async function findPaymentByProviderPaymentId(
    providerPaymentId: string
): Promise<{id: string; data: FirebaseFirestore.DocumentData} | null> {
  const snapshot = await db.collection("payments")
      .where("providerPaymentId", "==", providerPaymentId)
      .limit(1)
      .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return {id: doc.id, data: doc.data()};
}

/**
 * Find payment by reference
 */
async function findPaymentByReference(
    reference: string
): Promise<{id: string; data: FirebaseFirestore.DocumentData} | null> {
  const snapshot = await db.collection("payments")
      .where("reference", "==", reference)
      .limit(1)
      .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return {id: doc.id, data: doc.data()};
}

/**
 * Stripe Webhook - HTTP Cloud Function
 *
 * This function:
 * 1. Verifies webhook signature (provider handles this)
 * 2. Parses the webhook event
 * 3. Checks idempotency (skip if already processed)
 * 4. Updates payment status
 * 5. Triggers escrow funding on payment confirmation
 */
export const stripeWebhook = functions
    .region(REGION)
    .runWith({
      // Stripe webhooks need raw body for signature verification
      // This is handled via the rawBody property
      timeoutSeconds: 60,
    })
    .https.onRequest(
        wrapHttpHandler(
            FUNCTION_NAME,
            async (req, res, errorContext) => {
              const logger = PaymentLogger(FUNCTION_NAME).setContext(errorContext);

              // Only accept POST
              if (req.method !== "POST") {
                logger.warn("invalid_method", {method: req.method});
                res.status(405).send("Method Not Allowed");
                return;
              }

              // Check kill-switch
              try {
                await requireFeatureEnabled("payments", errorContext);
                await requireFeatureEnabled("webhooks", errorContext);
              } catch (killSwitchError) {
                logger.killSwitchActive("payments");
                // Still return 200 to prevent Stripe from retrying
                res.status(200).json({received: true, skipped: true, reason: "kill_switch"});
                return;
              }

              // Get the Stripe provider
              let provider;
              try {
                provider = getStripeProvider();
              } catch (providerError) {
                const errorMsg = providerError instanceof Error ?
                  providerError.message : "unknown";
                logger.error("stripe_provider_not_available", errorMsg);
                // Return 200 to prevent retries
                res.status(200).json({received: true, skipped: true, reason: "provider_unavailable"});
                return;
              }

              // Verify webhook signature
              const isValid = await provider.verifyWebhookSignature({
                body: req.body,
                headers: req.headers as Record<string, string | string[] | undefined>,
                rawBody: req.rawBody,
              });

              if (!isValid) {
                logger.error("webhook_signature_invalid", "Invalid webhook signature");
                res.status(400).send("Invalid signature");
                return;
              }

              // Parse the webhook event
              let event;
              try {
                event = await provider.parseWebhook({
                  body: req.body,
                  headers: req.headers as Record<string, string | string[] | undefined>,
                  rawBody: req.rawBody,
                });
              } catch (parseError) {
                logger.warn("webhook_parse_error", {
                  error: parseError instanceof Error ? parseError.message : "unknown",
                });
                // Return 200 for unhandled event types
                res.status(200).json({received: true, skipped: true, reason: "unhandled_event_type"});
                return;
              }

              logger.info("stripe_webhook_received", {
                eventType: event.type,
                eventId: event.eventId,
                reference: event.reference,
              });

              // Check idempotency
              const alreadyProcessed = await isWebhookProcessed(
                  "stripe",
                  event.type,
                  event.eventId,
                  errorContext
              );

              if (alreadyProcessed) {
                logger.idempotentSkip("webhook", event.eventId, "already_processed");
                res.status(200).json({received: true, skipped: true, reason: "already_processed"});
                return;
              }

              // Find the payment record
              let payment = await findPaymentByProviderPaymentId(event.providerPaymentId);
              if (!payment && event.reference) {
                payment = await findPaymentByReference(event.reference);
              }

              if (!payment) {
                logger.warn("payment_not_found", {
                  providerPaymentId: event.providerPaymentId,
                  reference: event.reference,
                });
                // Return 200 - payment might have been deleted or not yet created
                res.status(200).json({received: true, skipped: true, reason: "payment_not_found"});
                return;
              }

              logger.info("payment_found", {
                paymentId: payment.id,
                currentStatus: payment.data.status,
                eventType: event.type,
              });

              // Process based on event type
              switch (event.type) {
              case "payment.confirmed": {
                // Skip if already confirmed
                if (payment.data.status === "confirmed") {
                  logger.idempotentSkip("payment_confirmation", payment.id, "already_confirmed");
                  break;
                }

                logger.stateTransition("payment", payment.id, payment.data.status, "confirmed");

                // Update payment status
                await updatePaymentStatus(payment.id, "confirmed", {
                  confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
                  stripeEventId: event.eventId,
                });

                // Fund escrow
                const escrowId = payment.data.metadata?.escrowId;
                if (escrowId) {
                  try {
                    await fundEscrow(escrowId, payment.id);
                    logger.info("escrow_funded", {escrowId, paymentId: payment.id});
                  } catch (escrowError) {
                    const errorMsg = escrowError instanceof Error ?
                      escrowError.message : "unknown";
                    logger.error("escrow_funding_failed", errorMsg, {
                      escrowId,
                      paymentId: payment.id,
                    });
                  }
                }

                // Update booking status to paid
                try {
                  await db.collection("bookings").doc(payment.data.bookingId).update({
                    status: "paid",
                    paidAmount: admin.firestore.FieldValue.increment(event.amount),
                    paymentId: payment.id,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                  logger.info("booking_updated", {bookingId: payment.data.bookingId});
                } catch (bookingError) {
                  const errorMsg = bookingError instanceof Error ?
                    bookingError.message : "unknown";
                  logger.error("booking_update_failed", errorMsg, {
                    bookingId: payment.data.bookingId,
                  });
                }

                break;
              }

              case "payment.failed": {
                logger.stateTransition("payment", payment.id, payment.data.status, "failed");

                await updatePaymentStatus(payment.id, "failed", {
                  failedAt: admin.firestore.FieldValue.serverTimestamp(),
                  stripeEventId: event.eventId,
                });
                break;
              }

              case "payment.expired": {
                logger.stateTransition("payment", payment.id, payment.data.status, "expired");

                await updatePaymentStatus(payment.id, "expired", {
                  expiredAt: admin.firestore.FieldValue.serverTimestamp(),
                  stripeEventId: event.eventId,
                });
                break;
              }

              case "refund.succeeded": {
                logger.stateTransition("payment", payment.id, payment.data.status, "refunded");

                await updatePaymentStatus(payment.id, "refunded", {
                  refundedAt: admin.firestore.FieldValue.serverTimestamp(),
                  refundedAmount: event.amount,
                  stripeEventId: event.eventId,
                });
                break;
              }

              case "refund.failed": {
                logger.warn("refund_failed", {
                  paymentId: payment.id,
                  eventId: event.eventId,
                });
                break;
              }

              default:
                logger.warn("unhandled_event_type", {eventType: event.type});
              }

              // Mark webhook as processed
              await markWebhookProcessed("stripe", event.type, event.eventId, errorContext);

              res.status(200).json({received: true, success: true});
            }
        )
    );
