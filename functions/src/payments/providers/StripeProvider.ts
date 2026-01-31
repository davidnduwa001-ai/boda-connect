/**
 * Stripe Payment Provider
 *
 * Test payment provider using Stripe Hosted Checkout.
 * This is for development/testing only - ProxyPay is the production provider.
 *
 * Features:
 * - Stripe Checkout Sessions (hosted payment page)
 * - No raw card handling (PCI compliant)
 * - Webhook verification
 * - Refund support
 *
 * Required Environment Variables:
 * - STRIPE_SECRET_KEY: Stripe API secret key
 * - STRIPE_WEBHOOK_SECRET: Webhook endpoint signing secret
 *
 * Note: Stripe amounts are in cents (smallest currency unit)
 */

import Stripe from "stripe";
import {
  PaymentProvider,
  CreatePaymentParams,
  CreatePaymentResult,
  ConfirmPaymentParams,
  RefundPaymentParams,
  RefundResult,
  WebhookRequest,
  WebhookEvent,
  WebhookEventType,
} from "./PaymentProvider";
import {createLogger} from "../../common/logger";

const logger = createLogger("payment", "StripeProvider");

// Stripe configuration from environment variables (.env file)
// Firebase Functions automatically loads .env files during deployment
const STRIPE_CONFIG = {
  secretKey: process.env.STRIPE_SECRET_KEY || "",
  webhookSecret: process.env.STRIPE_WEBHOOK_SECRET || "",
};

/**
 * Stripe Payment Provider Implementation
 */
export class StripeProvider implements PaymentProvider {
  readonly name = "stripe";
  private stripe: Stripe;

  constructor() {
    if (!STRIPE_CONFIG.secretKey) {
      throw new Error("STRIPE_SECRET_KEY environment variable is required");
    }

    this.stripe = new Stripe(STRIPE_CONFIG.secretKey);
  }

  /**
   * Create a Stripe Checkout Session
   *
   * Returns a checkoutUrl that the client redirects to.
   * Stripe handles the entire payment UI.
   */
  async createPaymentIntent(params: CreatePaymentParams): Promise<CreatePaymentResult> {
    logger.info("creating_stripe_checkout", {
      reference: params.reference,
      amount: params.amount,
      currency: params.currency,
    });

    // Stripe requires amounts in smallest currency unit
    // For AOA (kwanzas), this is already the case
    // For USD/EUR, amount should be in cents
    const stripeAmount = params.amount;

    // Build line items for checkout
    const lineItems: Stripe.Checkout.SessionCreateParams.LineItem[] = [
      {
        price_data: {
          currency: params.currency.toLowerCase(),
          product_data: {
            name: params.description || "Boda Connect Payment",
            description: `Booking: ${params.bookingId}`,
          },
          unit_amount: stripeAmount,
        },
        quantity: 1,
      },
    ];

    // Create Checkout Session
    const session = await this.stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      line_items: lineItems,
      success_url: params.successUrl || `${this.getBaseUrl()}/payment/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: params.cancelUrl || `${this.getBaseUrl()}/payment/cancelled`,
      client_reference_id: params.reference,
      customer_email: params.customerEmail,
      expires_at: Math.floor(params.expiresAt.getTime() / 1000),
      metadata: {
        reference: params.reference,
        bookingId: params.bookingId,
        userId: params.userId,
        ...params.metadata,
      },
    });

    logger.info("stripe_checkout_created", {
      sessionId: session.id,
      reference: params.reference,
      checkoutUrl: session.url,
    });

    return {
      providerPaymentId: session.id,
      checkoutUrl: session.url || undefined,
      providerData: {
        sessionId: session.id,
        paymentIntent: session.payment_intent,
      },
    };
  }

  /**
   * Confirm payment - Stripe handles this via webhooks
   * This method is a no-op for Stripe as confirmation happens via webhook
   */
  async confirmPayment(params: ConfirmPaymentParams): Promise<void> {
    logger.info("stripe_confirm_payment_called", {
      providerPaymentId: params.providerPaymentId,
      paymentId: params.paymentId,
    });

    // Stripe payments are confirmed via webhook
    // This is called for manual verification if needed
    const session = await this.stripe.checkout.sessions.retrieve(params.providerPaymentId);

    if (session.payment_status !== "paid") {
      throw new Error(`Payment not confirmed. Status: ${session.payment_status}`);
    }

    logger.info("stripe_payment_verified", {
      sessionId: session.id,
      paymentStatus: session.payment_status,
    });
  }

  /**
   * Refund a Stripe payment
   */
  async refundPayment(params: RefundPaymentParams): Promise<RefundResult> {
    logger.info("stripe_refund_requested", {
      providerPaymentId: params.providerPaymentId,
      amount: params.amount,
      reason: params.reason,
    });

    // Get the checkout session to find the payment intent
    const session = await this.stripe.checkout.sessions.retrieve(params.providerPaymentId);

    if (!session.payment_intent) {
      throw new Error("No payment intent found for this session");
    }

    const paymentIntentId = typeof session.payment_intent === "string" ?
      session.payment_intent :
      session.payment_intent.id;

    // Create refund
    const refund = await this.stripe.refunds.create({
      payment_intent: paymentIntentId,
      amount: params.amount,
      reason: this.mapRefundReason(params.reason),
      metadata: {
        paymentId: params.paymentId,
        originalReason: params.reason || "none",
      },
    });

    logger.info("stripe_refund_created", {
      refundId: refund.id,
      status: refund.status,
      amount: refund.amount,
    });

    return {
      providerRefundId: refund.id,
      status: refund.status === "succeeded" ? "succeeded" :
        refund.status === "pending" ? "pending" : "failed",
      amount: refund.amount,
    };
  }

  /**
   * Verify Stripe webhook signature
   *
   * CRITICAL: This method MUST receive the raw request body (req.rawBody).
   * Stripe signature verification requires the exact bytes sent by Stripe.
   * Using JSON.stringify(req.body) will fail because:
   * - Key ordering may differ
   * - Whitespace may differ
   * - Numeric precision may differ
   *
   * Firebase Functions v1 automatically provides req.rawBody for onRequest handlers.
   * DO NOT wrap this endpoint with JSON body-parsing middleware.
   */
  async verifyWebhookSignature(req: WebhookRequest): Promise<boolean> {
    const signature = req.headers["stripe-signature"];

    if (!signature || !STRIPE_CONFIG.webhookSecret) {
      logger.warn("stripe_webhook_missing_signature");
      return false;
    }

    // SECURITY: rawBody is REQUIRED - do not fall back to JSON.stringify
    if (!req.rawBody) {
      logger.warn("stripe_webhook_missing_raw_body");
      return false;
    }

    try {
      const bodyBuffer = typeof req.rawBody === "string" ?
        req.rawBody : req.rawBody.toString();

      this.stripe.webhooks.constructEvent(
          bodyBuffer,
          Array.isArray(signature) ? signature[0] : signature,
          STRIPE_CONFIG.webhookSecret
      );

      return true;
    } catch (error) {
      logger.warn("stripe_webhook_signature_invalid", {
        error: error instanceof Error ? error.message : "unknown",
      });
      return false;
    }
  }

  /**
   * Parse Stripe webhook event
   *
   * CRITICAL: Requires raw body for signature verification.
   * See verifyWebhookSignature() for security constraints.
   */
  async parseWebhook(req: WebhookRequest): Promise<WebhookEvent> {
    const signature = req.headers["stripe-signature"];

    if (!signature || !STRIPE_CONFIG.webhookSecret) {
      throw new Error("Missing webhook signature or secret");
    }

    // SECURITY: rawBody is REQUIRED - do not fall back to JSON.stringify
    if (!req.rawBody) {
      throw new Error("Missing raw body - cannot verify webhook signature");
    }

    const bodyBuffer = typeof req.rawBody === "string" ?
      req.rawBody : req.rawBody.toString();

    const event = this.stripe.webhooks.constructEvent(
        bodyBuffer,
        Array.isArray(signature) ? signature[0] : signature,
        STRIPE_CONFIG.webhookSecret
    );

    logger.info("stripe_webhook_received", {
      eventId: event.id,
      eventType: event.type,
    });

    // Map Stripe event types to our event types
    const webhookEventType = this.mapEventType(event.type);

    if (!webhookEventType) {
      throw new Error(`Unhandled Stripe event type: ${event.type}`);
    }

    // Extract data based on event type
    const eventData = event.data.object as Stripe.Checkout.Session | Stripe.Refund;

    // For checkout.session events
    if ("client_reference_id" in eventData) {
      const session = eventData as Stripe.Checkout.Session;
      return {
        type: webhookEventType,
        eventId: event.id,
        providerPaymentId: session.id,
        reference: session.client_reference_id || session.metadata?.reference || "",
        amount: session.amount_total || 0,
        currency: session.currency?.toUpperCase() || "USD",
        rawData: event,
        timestamp: new Date(event.created * 1000),
      };
    }

    // For refund events
    if ("payment_intent" in eventData && event.type.startsWith("charge.refund")) {
      const refund = eventData as Stripe.Refund;
      return {
        type: webhookEventType,
        eventId: event.id,
        providerPaymentId: typeof refund.payment_intent === "string" ?
          refund.payment_intent : refund.payment_intent?.id || "",
        reference: refund.metadata?.reference || "",
        amount: refund.amount,
        currency: refund.currency.toUpperCase(),
        rawData: event,
        timestamp: new Date(event.created * 1000),
      };
    }

    throw new Error(`Unable to parse event data for type: ${event.type}`);
  }

  /**
   * Map Stripe event type to our webhook event type
   */
  private mapEventType(stripeType: string): WebhookEventType | null {
    const mapping: Record<string, WebhookEventType> = {
      "checkout.session.completed": "payment.confirmed",
      "checkout.session.expired": "payment.expired",
      "checkout.session.async_payment_failed": "payment.failed",
      "charge.refunded": "refund.succeeded",
      "charge.refund.updated": "refund.succeeded",
    };

    return mapping[stripeType] || null;
  }

  /**
   * Map our refund reason to Stripe's reason enum
   */
  private mapRefundReason(reason?: string): Stripe.RefundCreateParams.Reason | undefined {
    if (!reason) return undefined;

    const lowerReason = reason.toLowerCase();
    if (lowerReason.includes("duplicate")) return "duplicate";
    if (lowerReason.includes("fraud")) return "fraudulent";
    return "requested_by_customer";
  }

  /**
   * Get base URL for redirects
   */
  private getBaseUrl(): string {
    // Use environment variable or default to production URL
    return process.env.APP_BASE_URL || "https://boda-connect-49eb9.web.app";
  }
}

/**
 * Singleton instance
 */
let stripeProviderInstance: StripeProvider | null = null;

/**
 * Get Stripe provider instance (lazy initialization)
 */
export function getStripeProvider(): StripeProvider {
  if (!stripeProviderInstance) {
    stripeProviderInstance = new StripeProvider();
  }
  return stripeProviderInstance;
}
