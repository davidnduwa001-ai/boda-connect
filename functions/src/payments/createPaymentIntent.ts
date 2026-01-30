import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {enforceRateLimit} from "../rateLimit/checkRateLimit";
import {createEscrow} from "../finance/escrowService";
import {
  wrapHandler,
  Errors,
  ErrorContext,
} from "../common/errors";
import {PaymentLogger} from "../common/logger";
import {requireFeatureEnabled} from "../common/killSwitch";
import {
  getPaymentProvider,
  mapPaymentMethodToProvider,
  PaymentProviderType,
  CreatePaymentParams,
} from "./providers";

const db = admin.firestore();
const REGION = "us-central1";
const FUNCTION_NAME = "createPaymentIntent";

// Entity ID for RPS responses (backward compatibility)
const PROXYPAY_ENTITY_ID = process.env.PROXYPAY_ENTITY_ID || "";

interface PaymentIntentRequest {
  bookingId: string;
  amount: number;
  currency?: string;
  paymentMethod: "opg" | "rps" | "stripe";
  customerPhone?: string;
  customerEmail?: string;
  customerName?: string;
  description?: string;
  /** Success redirect URL for hosted checkout (Stripe) */
  successUrl?: string;
  /** Cancel redirect URL for hosted checkout (Stripe) */
  cancelUrl?: string;
}

interface PaymentIntentResponse {
  success: boolean;
  paymentId?: string;
  reference?: string;
  entityId?: string;
  paymentUrl?: string;
  /** Stripe Checkout URL - client redirects here */
  checkoutUrl?: string;
  expiresAt?: string;
  error?: string;
}

/**
 * Validate booking and check if payment is allowed
 */
async function validateBookingForPayment(
    bookingId: string,
    callerId: string
): Promise<{
  valid: boolean;
  error?: string;
  booking?: FirebaseFirestore.DocumentData;
}> {
  const bookingDoc = await db.collection("bookings").doc(bookingId).get();

  if (!bookingDoc.exists) {
    return {valid: false, error: "Reserva não encontrada"};
  }

  const booking = bookingDoc.data()!;

  // Verify caller is the client
  if (booking.clientId !== callerId) {
    return {valid: false, error: "Você não tem permissão para pagar esta reserva"};
  }

  // Check booking status allows payment
  const allowedStatuses = ["pending", "confirmed", "partially_paid"];
  if (!allowedStatuses.includes(booking.status)) {
    return {
      valid: false,
      error: `Não é possível pagar reserva com status: ${booking.status}`,
    };
  }

  // Check if already fully paid
  const paidAmount = booking.paidAmount || 0;
  const totalAmount = booking.totalAmount || 0;
  if (paidAmount >= totalAmount && totalAmount > 0) {
    return {valid: false, error: "Esta reserva já foi paga integralmente"};
  }

  return {valid: true, booking};
}

/**
 * Generate unique reference for payment
 */
function generateReference(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `BC${timestamp}${random}`.toUpperCase().substring(0, 12);
}

/**
 * Create Payment Intent - Callable Cloud Function
 *
 * Supports multiple payment providers:
 * - ProxyPay OPG (mobile payments)
 * - ProxyPay RPS (ATM/reference payments)
 * - Stripe (test mode - hosted checkout)
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates the caller is the booking's client
 * 3. Validates the booking status allows payment
 * 4. Creates payment intent with the appropriate provider
 * 5. Creates escrow record (server-side)
 * 6. Writes payment record to /payments collection
 */
export const createPaymentIntent = functions
    .region(REGION)
    .https.onCall(
        wrapHandler(
            FUNCTION_NAME,
            async (
                data: PaymentIntentRequest,
                context: functions.https.CallableContext,
                errorContext: ErrorContext
            ) => {
              const logger = PaymentLogger(FUNCTION_NAME).setContext(errorContext);
              logger.operationStart("create_payment_intent", {
                bookingId: data.bookingId,
                amount: data.amount,
                method: data.paymentMethod,
              });

              // Check kill-switch
              await requireFeatureEnabled("payments", errorContext);

              // Validate authentication
              if (!context.auth) {
                throw Errors.unauthenticated(errorContext);
              }

              const callerId = context.auth.uid;

              // Enforce rate limit (20 payment intents per hour)
              await enforceRateLimit(callerId, FUNCTION_NAME);

              // Validate required fields
              if (!data.bookingId || !data.amount || !data.paymentMethod) {
                throw Errors.invalidArgument(
                    errorContext,
                    "bookingId, amount, paymentMethod",
                    "Campos obrigatórios"
                );
              }

              // Validate payment method
              const validMethods = ["opg", "rps", "stripe"];
              if (!validMethods.includes(data.paymentMethod)) {
                throw Errors.invalidArgument(
                    errorContext,
                    "paymentMethod",
                    "Método de pagamento inválido"
                );
              }

              // Validate amount
              if (data.amount < 100) {
                throw Errors.invalidArgument(
                    errorContext,
                    "amount",
                    "Valor mínimo de pagamento é 100 AOA"
                );
              }

              // For OPG, phone is required
              if (data.paymentMethod === "opg" && !data.customerPhone) {
                throw Errors.invalidArgument(
                    errorContext,
                    "customerPhone",
                    "Número de telefone é obrigatório para pagamento mobile"
                );
              }

              // Validate booking
              const validation = await validateBookingForPayment(
                  data.bookingId,
                  callerId
              );

              if (!validation.valid) {
                throw Errors.failedPrecondition(
                    errorContext,
                    validation.error || "Booking validation failed",
                    validation.error || "Reserva inválida"
                );
              }

              const booking = validation.booking!;
              const reference = generateReference();
              const description = data.description ||
                `BODA CONNECT - ${booking.eventName || "Reserva"}`;
              const expiresAt = new Date();
              expiresAt.setMinutes(expiresAt.getMinutes() + 30);

              // Get the appropriate payment provider
              const providerType: PaymentProviderType = mapPaymentMethodToProvider(
                  data.paymentMethod
              );

              let provider;
              try {
                provider = getPaymentProvider(providerType);
              } catch (providerError) {
                const errorMsg = providerError instanceof Error ?
                  providerError.message : "unknown";
                logger.error("provider_not_available", errorMsg, {providerType});
                throw Errors.unavailable(
                    errorContext,
                    `Payment provider ${providerType} not available`,
                    "Método de pagamento temporariamente indisponível"
                );
              }

              logger.info("creating_provider_payment", {
                provider: provider.name,
                method: data.paymentMethod,
              });

              // Build provider params
              const providerParams: CreatePaymentParams = {
                reference,
                amount: data.amount,
                currency: data.currency || "AOA",
                paymentMethod: data.paymentMethod,
                customerPhone: data.customerPhone,
                customerEmail: data.customerEmail,
                customerName: data.customerName,
                description,
                bookingId: data.bookingId,
                userId: callerId,
                expiresAt,
                successUrl: data.successUrl,
                cancelUrl: data.cancelUrl,
                metadata: {
                  supplierId: booking.supplierId,
                },
              };

              // Create payment with provider
              const providerResult = await provider.createPaymentIntent(providerParams);

              logger.info("provider_payment_created", {
                provider: provider.name,
                providerPaymentId: providerResult.providerPaymentId,
              });

              // Create escrow record (SERVER-SIDE)
              const escrowId = await createEscrow({
                bookingId: data.bookingId,
                clientId: callerId,
                supplierId: booking.supplierId,
                totalAmount: data.amount,
                currency: data.currency || "AOA",
              });

              logger.info("escrow_created", {escrowId, bookingId: data.bookingId});

              // Create payment record in Firestore with escrow link
              const paymentRef = db.collection("payments").doc();
              const paymentData = {
                id: paymentRef.id,
                bookingId: data.bookingId,
                userId: callerId,
                supplierId: booking.supplierId,
                amount: data.amount,
                currency: data.currency || "AOA",
                reference: reference,
                referenceNumber: providerResult.referenceNumber,
                provider: provider.name,
                providerPaymentId: providerResult.providerPaymentId,
                status: "pending",
                description: description,
                paymentMethod: data.paymentMethod,
                customerPhone: data.customerPhone,
                customerEmail: data.customerEmail,
                customerName: data.customerName,
                paymentUrl: providerResult.paymentUrl,
                checkoutUrl: providerResult.checkoutUrl,
                expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
                metadata: {
                  escrowId,
                  ...providerResult.providerData,
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              };

              await paymentRef.set(paymentData);

              // Update escrow with payment ID
              await db.collection("escrow").doc(escrowId).update({
                paymentId: paymentRef.id,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              logger.operationSuccess("create_payment_intent", {
                paymentId: paymentRef.id,
                escrowId,
                bookingId: data.bookingId,
                provider: provider.name,
              });

              // Build response
              const response: PaymentIntentResponse = {
                success: true,
                paymentId: paymentRef.id,
                reference: reference,
                expiresAt: expiresAt.toISOString(),
              };

              // Add provider-specific response fields
              if (data.paymentMethod === "stripe") {
                response.checkoutUrl = providerResult.checkoutUrl;
              } else if (data.paymentMethod === "opg") {
                response.paymentUrl = providerResult.paymentUrl;
              } else if (data.paymentMethod === "rps") {
                response.entityId = providerResult.entityId || PROXYPAY_ENTITY_ID;
                response.reference = providerResult.referenceNumber;
              }

              return response;
            }
        )
    );
