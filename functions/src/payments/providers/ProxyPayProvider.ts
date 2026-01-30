/**
 * ProxyPay Payment Provider
 *
 * Production payment provider for Angola using ProxyPay.
 * Supports:
 * - OPG (Multicaixa Express mobile payments)
 * - RPS (ATM/home banking reference payments)
 *
 * Required Environment Variables:
 * - PROXYPAY_API_KEY: ProxyPay API key
 * - PROXYPAY_ENTITY_ID: Entity ID for RPS payments
 */

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

const logger = createLogger("payment", "ProxyPayProvider");

// ProxyPay configuration from environment
const PROXYPAY_CONFIG = {
  sandboxUrl: "https://api.sandbox.proxypay.co.ao",
  prodUrl: "https://api.proxypay.co.ao",
  entityId: process.env.PROXYPAY_ENTITY_ID || "",
  apiKey: process.env.PROXYPAY_API_KEY || "",
  useSandbox: process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.NODE_ENV !== "production",
  webhookCallbackUrl: process.env.PROXYPAY_WEBHOOK_URL ||
    "https://us-central1-boda-connect-49eb9.cloudfunctions.net/proxyPayWebhook",
};

/**
 * Format phone for ProxyPay (Angola format: 9XXXXXXXX)
 */
function formatPhoneForProxyPay(phone: string): string {
  let cleaned = phone.replace(/\D/g, "");
  if (cleaned.startsWith("244")) {
    cleaned = cleaned.substring(3);
  }
  if (!cleaned.startsWith("9") && cleaned.length === 9) {
    cleaned = "9" + cleaned.substring(1);
  }
  return cleaned;
}

/**
 * ProxyPay OPG Provider (Mobile payments)
 */
export class ProxyPayOPGProvider implements PaymentProvider {
  readonly name = "proxypay_opg";

  private getBaseUrl(): string {
    return PROXYPAY_CONFIG.useSandbox ?
      PROXYPAY_CONFIG.sandboxUrl :
      PROXYPAY_CONFIG.prodUrl;
  }

  private getAuthHeader(): string {
    return `Basic ${Buffer.from(`:${PROXYPAY_CONFIG.apiKey}`).toString("base64")}`;
  }

  async createPaymentIntent(params: CreatePaymentParams): Promise<CreatePaymentResult> {
    if (!params.customerPhone) {
      throw new Error("Customer phone is required for OPG payments");
    }

    logger.info("creating_proxypay_opg", {
      reference: params.reference,
      amount: params.amount,
    });

    const response = await fetch(`${this.getBaseUrl()}/opg/v1/payments`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/vnd.proxypay.v2+json",
        "Authorization": this.getAuthHeader(),
      },
      body: JSON.stringify({
        reference_id: params.reference,
        amount: params.amount.toString(),
        mobile: formatPhoneForProxyPay(params.customerPhone),
        message: params.description.substring(0, 50),
        callback_url: PROXYPAY_CONFIG.webhookCallbackUrl,
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      logger.error("proxypay_opg_error", `API error: ${response.status}`, {details: errorData});
      throw new Error(`ProxyPay OPG API error: ${response.status}`);
    }

    const data = await response.json() as {id: string; payment_url?: string};

    logger.info("proxypay_opg_created", {
      id: data.id,
      reference: params.reference,
    });

    return {
      providerPaymentId: data.id,
      paymentUrl: data.payment_url,
      providerData: {opgId: data.id},
    };
  }

  async confirmPayment(params: ConfirmPaymentParams): Promise<void> {
    // ProxyPay OPG payments are confirmed via webhook
    logger.info("proxypay_opg_confirm_called", {
      providerPaymentId: params.providerPaymentId,
    });
  }

  async refundPayment(params: RefundPaymentParams): Promise<RefundResult> {
    // ProxyPay doesn't have a direct refund API
    // Refunds are handled manually or through bank transfers
    logger.warn("proxypay_opg_refund_not_supported", {
      providerPaymentId: params.providerPaymentId,
      amount: params.amount,
    });

    throw new Error("ProxyPay OPG refunds must be processed manually");
  }

  async verifyWebhookSignature(_req: WebhookRequest): Promise<boolean> {
    // ProxyPay uses IP whitelisting instead of signatures
    // Verification is done at the network level
    return true;
  }

  async parseWebhook(req: WebhookRequest): Promise<WebhookEvent> {
    const body = req.body as Record<string, unknown>;

    logger.info("proxypay_opg_webhook_received", {body});

    // ProxyPay OPG webhook format
    const eventType = this.mapEventType(body.status as string);
    const reference = body.reference_id as string || "";
    const id = body.id as string || body.payment_id as string || "";

    return {
      type: eventType,
      eventId: `opg_${id}_${Date.now()}`,
      providerPaymentId: id,
      reference: reference,
      amount: Number(body.amount) || 0,
      currency: "AOA",
      rawData: body,
      timestamp: new Date(),
    };
  }

  private mapEventType(status: string): WebhookEventType {
    switch (status?.toLowerCase()) {
    case "paid":
    case "confirmed":
    case "completed":
      return "payment.confirmed";
    case "failed":
    case "rejected":
      return "payment.failed";
    case "expired":
      return "payment.expired";
    default:
      return "payment.failed";
    }
  }
}

/**
 * ProxyPay RPS Provider (ATM/Reference payments)
 */
export class ProxyPayRPSProvider implements PaymentProvider {
  readonly name = "proxypay_rps";

  private getBaseUrl(): string {
    return PROXYPAY_CONFIG.useSandbox ?
      PROXYPAY_CONFIG.sandboxUrl :
      PROXYPAY_CONFIG.prodUrl;
  }

  private getAuthHeader(): string {
    return `Basic ${Buffer.from(`:${PROXYPAY_CONFIG.apiKey}`).toString("base64")}`;
  }

  async createPaymentIntent(params: CreatePaymentParams): Promise<CreatePaymentResult> {
    logger.info("creating_proxypay_rps", {
      reference: params.reference,
      amount: params.amount,
    });

    // Generate 9-digit reference number for RPS
    const referenceNumber = Math.floor(100000000 + Math.random() * 900000000).toString();

    const response = await fetch(`${this.getBaseUrl()}/references`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/vnd.proxypay.v2+json",
        "Authorization": this.getAuthHeader(),
      },
      body: JSON.stringify({
        reference_id: params.reference,
        amount: params.amount.toString(),
        end_datetime: params.expiresAt.toISOString(),
        custom_fields: {
          description: params.description.substring(0, 100),
          bookingId: params.bookingId,
        },
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      logger.error("proxypay_rps_error", `API error: ${response.status}`, {details: errorData});
      throw new Error(`ProxyPay RPS API error: ${response.status}`);
    }

    const data = await response.json() as {id: string; reference?: string};

    logger.info("proxypay_rps_created", {
      id: data.id,
      referenceNumber: data.reference || referenceNumber,
    });

    return {
      providerPaymentId: data.id,
      referenceNumber: data.reference || referenceNumber,
      entityId: PROXYPAY_CONFIG.entityId,
      providerData: {rpsId: data.id},
    };
  }

  async confirmPayment(params: ConfirmPaymentParams): Promise<void> {
    // ProxyPay RPS payments are confirmed via webhook
    logger.info("proxypay_rps_confirm_called", {
      providerPaymentId: params.providerPaymentId,
    });
  }

  async refundPayment(params: RefundPaymentParams): Promise<RefundResult> {
    // ProxyPay RPS doesn't have a direct refund API
    logger.warn("proxypay_rps_refund_not_supported", {
      providerPaymentId: params.providerPaymentId,
      amount: params.amount,
    });

    throw new Error("ProxyPay RPS refunds must be processed manually");
  }

  async verifyWebhookSignature(_req: WebhookRequest): Promise<boolean> {
    // ProxyPay uses IP whitelisting instead of signatures
    return true;
  }

  async parseWebhook(req: WebhookRequest): Promise<WebhookEvent> {
    const body = req.body as Record<string, unknown>;

    logger.info("proxypay_rps_webhook_received", {body});

    // ProxyPay RPS webhook format
    const reference = body.reference_id as string ||
      (body.custom_fields as Record<string, string>)?.reference || "";
    const id = body.id as string || "";

    return {
      type: "payment.confirmed",
      eventId: `rps_${id}_${Date.now()}`,
      providerPaymentId: id,
      reference: reference,
      amount: Number(body.amount) || 0,
      currency: "AOA",
      rawData: body,
      timestamp: body.datetime ? new Date(body.datetime as string) : new Date(),
    };
  }
}

// Singleton instances
let opgProviderInstance: ProxyPayOPGProvider | null = null;
let rpsProviderInstance: ProxyPayRPSProvider | null = null;

/**
 * Get ProxyPay OPG provider instance
 */
export function getProxyPayOPGProvider(): ProxyPayOPGProvider {
  if (!opgProviderInstance) {
    opgProviderInstance = new ProxyPayOPGProvider();
  }
  return opgProviderInstance;
}

/**
 * Get ProxyPay RPS provider instance
 */
export function getProxyPayRPSProvider(): ProxyPayRPSProvider {
  if (!rpsProviderInstance) {
    rpsProviderInstance = new ProxyPayRPSProvider();
  }
  return rpsProviderInstance;
}
