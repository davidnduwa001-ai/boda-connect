/**
 * Payment Providers Module
 *
 * Exports payment provider interface and implementations.
 * Use getPaymentProvider() to get the appropriate provider.
 */

// Interface and types
export {
  PaymentProvider,
  CreatePaymentParams,
  CreatePaymentResult,
  ConfirmPaymentParams,
  RefundPaymentParams,
  RefundResult,
  WebhookRequest,
  WebhookEvent,
  WebhookEventType,
  PaymentProviderType,
  isValidProviderType,
} from "./PaymentProvider";

// Provider implementations
export {getStripeProvider, StripeProvider} from "./StripeProvider";
export {
  getProxyPayOPGProvider,
  getProxyPayRPSProvider,
  ProxyPayOPGProvider,
  ProxyPayRPSProvider,
} from "./ProxyPayProvider";

// Provider selector
export {getPaymentProvider, mapPaymentMethodToProvider} from "./providerSelector";
