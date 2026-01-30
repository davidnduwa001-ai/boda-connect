/**
 * Payment Provider Interface
 *
 * Abstracts payment processing to support multiple providers:
 * - ProxyPay (production - Angola)
 * - Stripe (test - international)
 *
 * All providers implement this interface for consistent handling.
 */

/**
 * Parameters for creating a payment intent
 */
export interface CreatePaymentParams {
  /** Internal reference ID */
  reference: string;
  /** Amount in smallest currency unit (e.g., cents for USD, kwanzas for AOA) */
  amount: number;
  /** ISO 4217 currency code */
  currency: string;
  /** Payment method type */
  paymentMethod: string;
  /** Customer phone (required for some providers) */
  customerPhone?: string;
  /** Customer email */
  customerEmail?: string;
  /** Customer name */
  customerName?: string;
  /** Payment description */
  description: string;
  /** Booking ID for reference */
  bookingId: string;
  /** User/client ID */
  userId: string;
  /** When the payment expires */
  expiresAt: Date;
  /** URL to redirect after successful payment (for hosted checkout) */
  successUrl?: string;
  /** URL to redirect after cancelled payment (for hosted checkout) */
  cancelUrl?: string;
  /** Additional metadata */
  metadata?: Record<string, string>;
}

/**
 * Result of creating a payment intent
 */
export interface CreatePaymentResult {
  /** Provider's payment/session ID */
  providerPaymentId: string;
  /** URL for hosted checkout (Stripe) */
  checkoutUrl?: string;
  /** URL for mobile payment (ProxyPay OPG) */
  paymentUrl?: string;
  /** Reference number for ATM/bank payment (ProxyPay RPS) */
  referenceNumber?: string;
  /** Entity ID for ATM payment */
  entityId?: string;
  /** Additional provider-specific data */
  providerData?: Record<string, unknown>;
}

/**
 * Parameters for confirming a payment
 */
export interface ConfirmPaymentParams {
  /** Provider's payment ID */
  providerPaymentId: string;
  /** Our internal payment ID */
  paymentId: string;
  /** Amount that was paid */
  amount: number;
  /** Currency */
  currency: string;
}

/**
 * Parameters for refunding a payment
 */
export interface RefundPaymentParams {
  /** Provider's payment ID */
  providerPaymentId: string;
  /** Our internal payment ID */
  paymentId: string;
  /** Amount to refund (partial refunds supported) */
  amount: number;
  /** Currency */
  currency: string;
  /** Reason for refund */
  reason?: string;
}

/**
 * Result of a refund operation
 */
export interface RefundResult {
  /** Provider's refund ID */
  providerRefundId: string;
  /** Refund status */
  status: "succeeded" | "pending" | "failed";
  /** Amount refunded */
  amount: number;
}

/**
 * Webhook event types we handle
 */
export type WebhookEventType =
  | "payment.confirmed"
  | "payment.failed"
  | "payment.expired"
  | "refund.succeeded"
  | "refund.failed";

/**
 * Parsed webhook event
 */
export interface WebhookEvent {
  /** Event type */
  type: WebhookEventType;
  /** Provider's event ID (for idempotency) */
  eventId: string;
  /** Provider's payment ID */
  providerPaymentId: string;
  /** Our internal reference */
  reference: string;
  /** Amount involved */
  amount: number;
  /** Currency */
  currency: string;
  /** Raw event data for logging */
  rawData: unknown;
  /** Timestamp of the event */
  timestamp: Date;
}

/**
 * Request object for webhook parsing
 */
export interface WebhookRequest {
  body: unknown;
  headers: Record<string, string | string[] | undefined>;
  rawBody?: Buffer | string;
}

/**
 * Payment Provider Interface
 *
 * All payment providers must implement this interface.
 */
export interface PaymentProvider {
  /** Provider name identifier */
  readonly name: string;

  /**
   * Create a payment intent/session
   */
  createPaymentIntent(params: CreatePaymentParams): Promise<CreatePaymentResult>;

  /**
   * Confirm a payment was successful (manual confirmation if needed)
   */
  confirmPayment(params: ConfirmPaymentParams): Promise<void>;

  /**
   * Refund a payment (full or partial)
   */
  refundPayment(params: RefundPaymentParams): Promise<RefundResult>;

  /**
   * Parse and validate incoming webhook
   */
  parseWebhook(req: WebhookRequest): Promise<WebhookEvent>;

  /**
   * Verify webhook signature (called before parseWebhook)
   */
  verifyWebhookSignature(req: WebhookRequest): Promise<boolean>;
}

/**
 * Available payment providers
 */
export type PaymentProviderType = "proxypay_opg" | "proxypay_rps" | "stripe";

/**
 * Check if a provider type is valid
 */
export function isValidProviderType(type: string): type is PaymentProviderType {
  return ["proxypay_opg", "proxypay_rps", "stripe"].includes(type);
}
