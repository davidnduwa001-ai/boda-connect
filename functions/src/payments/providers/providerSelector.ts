/**
 * Payment Provider Selector
 *
 * Determines which payment provider to use based on:
 * - Requested payment method
 * - Environment configuration
 * - Kill-switch status
 *
 * Provider selection logic:
 * 1. "stripe" method -> StripeProvider (test only)
 * 2. "opg" method -> ProxyPayOPGProvider
 * 3. "rps" method -> ProxyPayRPSProvider
 */

import {PaymentProvider, PaymentProviderType} from "./PaymentProvider";
import {getStripeProvider} from "./StripeProvider";
import {getProxyPayOPGProvider, getProxyPayRPSProvider} from "./ProxyPayProvider";
import {createLogger} from "../../common/logger";

const logger = createLogger("payment", "providerSelector");

/**
 * Payment method types accepted from client
 */
export type PaymentMethodInput = "opg" | "rps" | "stripe";

/**
 * Check if Stripe is enabled (test mode only)
 */
function isStripeEnabled(): boolean {
  const enabled = process.env.STRIPE_ENABLED === "true";
  const hasKey = !!process.env.STRIPE_SECRET_KEY;

  return enabled && hasKey;
}

/**
 * Map client payment method to provider type
 */
export function mapPaymentMethodToProvider(method: PaymentMethodInput): PaymentProviderType {
  switch (method) {
  case "stripe":
    return "stripe";
  case "opg":
    return "proxypay_opg";
  case "rps":
    return "proxypay_rps";
  default:
    throw new Error(`Unknown payment method: ${method}`);
  }
}

/**
 * Get payment provider by type
 *
 * @param providerType - The provider type to get
 * @returns The payment provider instance
 * @throws Error if provider is not available or disabled
 */
export function getPaymentProvider(providerType: PaymentProviderType): PaymentProvider {
  logger.debug("selecting_provider", {providerType});

  switch (providerType) {
  case "stripe":
    if (!isStripeEnabled()) {
      logger.warn("stripe_not_enabled");
      throw new Error("Stripe payments are not enabled");
    }
    return getStripeProvider();

  case "proxypay_opg":
    return getProxyPayOPGProvider();

  case "proxypay_rps":
    return getProxyPayRPSProvider();

  default:
    throw new Error(`Unknown provider type: ${providerType}`);
  }
}

/**
 * Get provider for a payment method (convenience function)
 *
 * @param method - The payment method from client
 * @returns The payment provider instance
 */
export function getProviderForMethod(method: PaymentMethodInput): PaymentProvider {
  const providerType = mapPaymentMethodToProvider(method);
  return getPaymentProvider(providerType);
}

/**
 * Get provider by name (for webhook handling)
 *
 * @param providerName - The provider name stored in payment record
 * @returns The payment provider instance
 */
export function getProviderByName(providerName: string): PaymentProvider {
  // Normalize provider name
  const normalized = providerName.toLowerCase().replace(/-/g, "_");

  switch (normalized) {
  case "stripe":
    return getStripeProvider();
  case "proxypay_opg":
  case "proxypay-opg":
    return getProxyPayOPGProvider();
  case "proxypay_rps":
  case "proxypay-rps":
    return getProxyPayRPSProvider();
  default:
    throw new Error(`Unknown provider name: ${providerName}`);
  }
}

/**
 * List available payment methods for the current environment
 *
 * @returns Array of available payment methods
 */
export function getAvailablePaymentMethods(): PaymentMethodInput[] {
  const methods: PaymentMethodInput[] = ["opg", "rps"];

  if (isStripeEnabled()) {
    methods.push("stripe");
  }

  return methods;
}
