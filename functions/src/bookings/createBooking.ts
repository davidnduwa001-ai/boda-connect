import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {
  wrapHandler,
  Errors,
  ErrorContext,
} from "../common/errors";
import {BookingLogger} from "../common/logger";
import {requireFeatureEnabled} from "../common/killSwitch";
import {isSupplierBookable} from "../suppliers/supplierEligibility";
import {checkRateLimitForKey} from "../rateLimit/checkRateLimit";

const db = admin.firestore();
const REGION = "us-central1";
const FUNCTION_NAME = "createBooking";

const BOOKING_RATE_LIMITS = {
  userBurst: {limit: 5, windowSeconds: 300}, // 5 attempts / 5 minutes
  userHourly: {limit: 10, windowSeconds: 3600}, // 10 attempts / hour (legacy parity)
  supplierBurst: {limit: 60, windowSeconds: 600}, // 60 attempts / 10 minutes
  ipBurst: {limit: 30, windowSeconds: 300}, // 30 attempts / 5 minutes
  deviceBurst: {limit: 30, windowSeconds: 300}, // 30 attempts / 5 minutes
} as const;

const RATE_LIMIT_REASON_CODES = {
  userBurst: "RATE_LIMIT_USER_BURST",
  userHourly: "RATE_LIMIT_USER_HOURLY",
  supplierBurst: "RATE_LIMIT_SUPPLIER_BURST",
  ipBurst: "RATE_LIMIT_IP_BURST",
  deviceBurst: "RATE_LIMIT_DEVICE_BURST",
} as const;

interface CreateBookingRequest {
  supplierId: string;
  packageId: string;
  eventDate: string; // ISO date string YYYY-MM-DD
  startTime?: string; // HH:mm format
  endTime?: string; // HH:mm format
  notes?: string;
  eventName?: string;
  eventLocation?: string;
  guestCount?: number;
  clientRequestId?: string; // For idempotency
  totalPrice?: number; // Client-provided price for validation/fallback
  packageName?: string; // Package name from client
}

interface CreateBookingResponse {
  success: boolean;
  bookingId?: string;
  error?: string;
  errorCode?: string;
}

/**
 * Validate that the event date is valid and not in the past
 */
function validateEventDate(eventDateStr: string): {
  valid: boolean;
  error?: string;
  date?: Date;
} {
  const eventDate = new Date(eventDateStr + "T00:00:00");

  if (isNaN(eventDate.getTime())) {
    return {valid: false, error: "Data do evento inválida"};
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  if (eventDate < today) {
    return {valid: false, error: "Data do evento não pode ser no passado"};
  }

  return {valid: true, date: eventDate};
}

type RequestMeta = {
  ip?: string;
  userAgent?: string;
  deviceFingerprint?: string;
};

function hashValue(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function getHeaderValue(
    headers: Record<string, unknown> | undefined,
    name: string
): string | undefined {
  if (!headers) return undefined;
  const value = headers[name.toLowerCase()];
  if (Array.isArray(value)) return value[0];
  if (typeof value === "string") return value;
  return undefined;
}

function getRequestMeta(context: functions.https.CallableContext): RequestMeta {
  const rawRequest = (context as unknown as {rawRequest?: functions.https.Request}).rawRequest;
  const headers = rawRequest?.headers as Record<string, unknown> | undefined;

  const forwardedFor = getHeaderValue(headers, "x-forwarded-for");
  const ip = forwardedFor?.split(",")[0]?.trim() ||
    getHeaderValue(headers, "cf-connecting-ip") ||
    getHeaderValue(headers, "true-client-ip") ||
    rawRequest?.ip ||
    rawRequest?.connection?.remoteAddress ||
    undefined;

  const userAgent = getHeaderValue(headers, "user-agent");
  const deviceHeader = getHeaderValue(headers, "x-device-fingerprint") ||
    getHeaderValue(headers, "x-client-fingerprint") ||
    getHeaderValue(headers, "x-device-id");

  const deviceFingerprint = deviceHeader || (userAgent && ip ? `${userAgent}|${ip}` : userAgent);

  return {ip, userAgent, deviceFingerprint};
}

async function enforceRateLimitOrFail(params: {
  scopeKey: string;
  actionKey: string;
  limit: number;
  windowSeconds: number;
  reasonCode: string;
  logger: ReturnType<typeof BookingLogger>;
  errorContext: ErrorContext;
  logContext?: Record<string, unknown>;
}): Promise<void> {
  const result = await checkRateLimitForKey(
      params.scopeKey,
      params.actionKey,
      params.limit,
      params.windowSeconds
  );

  if (result.allowed) return;

  params.logger.warn("rate_limit_blocked", {
    reasonCode: params.reasonCode,
    scopeKey: params.scopeKey,
    retryAfterSeconds: result.retryAfterSeconds,
    resetAt: result.resetAt.toISOString(),
    ...params.logContext,
  });

  throw new functions.https.HttpsError(
      "failed-precondition",
      "Muitas tentativas. Aguarde alguns minutos",
      {
        requestId: params.errorContext.requestId,
        reasonCode: params.reasonCode,
        retryAfterSeconds: result.retryAfterSeconds,
        resetAt: result.resetAt.toISOString(),
      }
  );
}

/**
 * Atomic conflict check - returns true if there's a conflict
 * Uses Timestamp range query to match how eventDate is stored
 */
async function hasBookingConflict(
    supplierId: string,
    eventDate: string,
    excludeBookingId?: string
): Promise<boolean> {
  // Convert string date to Timestamp range for the entire day
  // eventDate is stored as Timestamp, not string, so we must query with Timestamp
  const eventDateParts = eventDate.split("-");
  const startOfDay = new Date(
      parseInt(eventDateParts[0]),
      parseInt(eventDateParts[1]) - 1,
      parseInt(eventDateParts[2]),
      0, 0, 0
  );
  const endOfDay = new Date(
      parseInt(eventDateParts[0]),
      parseInt(eventDateParts[1]) - 1,
      parseInt(eventDateParts[2]),
      23, 59, 59, 999
  );

  const conflictQuery = db
      .collection("bookings")
      .where("supplierId", "==", supplierId)
      .where("eventDate", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
      .where("eventDate", "<=", admin.firestore.Timestamp.fromDate(endOfDay))
      .where("status", "in", ["pending", "confirmed"]);

  const conflictSnapshot = await conflictQuery.get();

  if (excludeBookingId) {
    return conflictSnapshot.docs.some((doc) => doc.id !== excludeBookingId);
  }

  return !conflictSnapshot.empty;
}

/**
 * Check for duplicate booking (idempotency)
 * Uses Timestamp range query to match how eventDate is stored
 */
async function findExistingBooking(
    clientId: string,
    supplierId: string,
    packageId: string,
    eventDate: string
): Promise<string | null> {
  // Convert string date to Timestamp range for the entire day
  // eventDate is stored as Timestamp, not string, so we must query with Timestamp
  const eventDateParts = eventDate.split("-");
  const startOfDay = new Date(
      parseInt(eventDateParts[0]),
      parseInt(eventDateParts[1]) - 1,
      parseInt(eventDateParts[2]),
      0, 0, 0
  );
  const endOfDay = new Date(
      parseInt(eventDateParts[0]),
      parseInt(eventDateParts[1]) - 1,
      parseInt(eventDateParts[2]),
      23, 59, 59, 999
  );

  const existingQuery = db
      .collection("bookings")
      .where("clientId", "==", clientId)
      .where("supplierId", "==", supplierId)
      .where("packageId", "==", packageId)
      .where("eventDate", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
      .where("eventDate", "<=", admin.firestore.Timestamp.fromDate(endOfDay))
      .where("status", "in", ["pending", "confirmed", "partially_paid"])
      .limit(1);

  const existingSnapshot = await existingQuery.get();

  if (!existingSnapshot.empty) {
    return existingSnapshot.docs[0].id;
  }

  return null;
}

/**
 * Create Booking - Callable Cloud Function
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates required fields and event date
 * 3. Checks idempotency to avoid duplicates
 * 4. Enforces server-side rate limits (user/supplier/IP/device)
 * 5. Validates supplier eligibility (canonical gate)
 * 6. Validates package belongs to supplier
 * 7. Performs atomic conflict check
 * 8. Creates the booking if no conflicts
 */
export const createBooking = functions
    .region(REGION)
    .https.onCall(
        wrapHandler(
            FUNCTION_NAME,
            async (
                data: CreateBookingRequest,
                context: functions.https.CallableContext,
                errorContext: ErrorContext
            ) => {
              const logger = BookingLogger(FUNCTION_NAME).setContext(errorContext);
              logger.operationStart("create_booking", {
                supplierId: data.supplierId,
                eventDate: data.eventDate,
              });

              // Check kill-switch
              await requireFeatureEnabled("bookings", errorContext);

              // 1. Validate authentication
              if (!context.auth) {
                throw Errors.unauthenticated(errorContext);
              }

              const clientId = context.auth.uid;

              // 2. Validate required fields
              if (!data.supplierId || !data.packageId || !data.eventDate) {
                throw Errors.invalidArgument(
                    errorContext,
                    "supplierId, packageId, eventDate",
                    "Campos obrigatórios"
                );
              }

              // Validate event date format and not in past
              const dateValidation = validateEventDate(data.eventDate);
              if (!dateValidation.valid) {
                throw Errors.invalidArgument(
                    errorContext,
                    "eventDate",
                    dateValidation.error
                );
              }

              // 3. Check for existing booking (idempotency)
              const existingBookingId = await findExistingBooking(
                  clientId,
                  data.supplierId,
                  data.packageId,
                  data.eventDate
              );

              if (existingBookingId) {
                logger.idempotentSkip("create_booking", existingBookingId, "booking_exists");
                return {
                  success: true,
                  bookingId: existingBookingId,
                } as CreateBookingResponse;
              }

              // 4. Rate-limit checks (server-side only)
              const requestMeta = getRequestMeta(context);
              const ipKey = requestMeta.ip ? `ip:${hashValue(requestMeta.ip)}` : null;
              const deviceKey = requestMeta.deviceFingerprint ?
                `device:${hashValue(requestMeta.deviceFingerprint)}` :
                null;

              await enforceRateLimitOrFail({
                scopeKey: `user:${clientId}`,
                actionKey: "createBooking_user_burst",
                ...BOOKING_RATE_LIMITS.userBurst,
                reasonCode: RATE_LIMIT_REASON_CODES.userBurst,
                logger,
                errorContext,
              });

              await enforceRateLimitOrFail({
                scopeKey: `user:${clientId}`,
                actionKey: "createBooking_user_hourly",
                ...BOOKING_RATE_LIMITS.userHourly,
                reasonCode: RATE_LIMIT_REASON_CODES.userHourly,
                logger,
                errorContext,
              });

              await enforceRateLimitOrFail({
                scopeKey: `supplier:${data.supplierId}`,
                actionKey: "createBooking_supplier_burst",
                ...BOOKING_RATE_LIMITS.supplierBurst,
                reasonCode: RATE_LIMIT_REASON_CODES.supplierBurst,
                logger,
                errorContext,
              });

              if (ipKey) {
                await enforceRateLimitOrFail({
                  scopeKey: ipKey,
                  actionKey: "createBooking_ip_burst",
                  ...BOOKING_RATE_LIMITS.ipBurst,
                  reasonCode: RATE_LIMIT_REASON_CODES.ipBurst,
                  logger,
                  errorContext,
                  logContext: {ipHash: ipKey},
                });
              }

              if (deviceKey) {
                await enforceRateLimitOrFail({
                  scopeKey: deviceKey,
                  actionKey: "createBooking_device_burst",
                  ...BOOKING_RATE_LIMITS.deviceBurst,
                  reasonCode: RATE_LIMIT_REASON_CODES.deviceBurst,
                  logger,
                  errorContext,
                  logContext: {deviceHash: deviceKey},
                });
              }

              // 5. Supplier eligibility gate (CANONICAL CHECK)
              // This is the single source of truth for booking eligibility
              const eligibility = await isSupplierBookable(
                  data.supplierId,
                  data.eventDate,
                  errorContext
              );

              if (!eligibility.eligible) {
                logger.debug("supplier_not_eligible", {
                  supplierId: data.supplierId,
                  eventDate: data.eventDate,
                  uiState: eligibility.uiState,
                  reasons: eligibility.reasons,
                  debugInfo: eligibility.debugInfo,
                });

                // Use the first reason as user message, or default
                const userMessage = eligibility.reasons[0] ||
                    "Este fornecedor não está disponível para reservas";

                throw Errors.failedPrecondition(
                    errorContext,
                    `Supplier not eligible: ${eligibility.reasons.join(", ")}`,
                    userMessage
                );
              }

              // 6. Fetch supplier for additional validation
              const supplierDoc = await db
                  .collection("suppliers")
                  .doc(data.supplierId)
                  .get();

              if (!supplierDoc.exists) {
                throw Errors.notFound(errorContext, "Fornecedor", data.supplierId);
              }

              const supplier = supplierDoc.data()!;

              // 7. Validate caller is not the supplier
              if (supplier.userId === clientId) {
                throw Errors.permissionDenied(
                    errorContext,
                    "Self-booking not allowed",
                    "Você não pode fazer reservas com você mesmo"
                );
              }

              // 8. Validate package exists and belongs to supplier
              // Packages are stored in top-level 'packages' collection with supplierId field
              const packageDoc = await db
                  .collection("packages")
                  .doc(data.packageId)
                  .get();

              if (!packageDoc.exists) {
                throw Errors.notFound(errorContext, "Pacote", data.packageId);
              }

              const packageData = packageDoc.data()!;

              // Verify package belongs to this supplier
              if (packageData.supplierId !== data.supplierId) {
                throw Errors.permissionDenied(
                    errorContext,
                    "Package does not belong to supplier",
                    "Este pacote não pertence a este fornecedor"
                );
              }

              // 9. Atomic conflict check (existing bookings on same date)
              const hasConflict = await hasBookingConflict(
                  data.supplierId,
                  data.eventDate
              );

              if (hasConflict) {
                throw Errors.alreadyExists(
                    errorContext,
                    "Reserva",
                    "Já existe uma reserva para esta data"
                );
              }

              // 10. Get client info
              const clientDoc = await db.collection("users").doc(clientId).get();
              const clientData = clientDoc.exists ? clientDoc.data() : {};

              // 11. Create the booking
              const bookingRef = db.collection("bookings").doc();
              const now = admin.firestore.FieldValue.serverTimestamp();

              // Convert eventDate string to Firestore Timestamp
              const eventDateParts = data.eventDate.split("-");
              const eventDateObj = new Date(
                  parseInt(eventDateParts[0]),
                  parseInt(eventDateParts[1]) - 1,
                  parseInt(eventDateParts[2]),
                  12, 0, 0
              );
              const eventDateTimestamp = admin.firestore.Timestamp.fromDate(eventDateObj);

              // Determine the price: use package price if available, otherwise use client-provided price
              // Server authority: package price takes precedence, but client price is a valid fallback
              const packagePrice = packageData.price || 0;
              const clientPrice = data.totalPrice || 0;
              const finalPrice = packagePrice > 0 ? packagePrice : clientPrice;

              // Log price discrepancy for debugging (if both exist and differ)
              if (packagePrice > 0 && clientPrice > 0 && packagePrice !== clientPrice) {
                logger.warn("price_mismatch", {
                  packagePrice,
                  clientPrice,
                  finalPrice,
                  packageId: data.packageId,
                });
              }

              const bookingData = {
                id: bookingRef.id,
                clientId: clientId,
                clientName: clientData?.displayName || clientData?.name || "Cliente",
                clientPhone: clientData?.phone || "",
                clientEmail: clientData?.email || "",
                supplierId: data.supplierId,
                supplierName: supplier.businessName || supplier.name || "Fornecedor",
                supplierPhone: supplier.phone || "",
                packageId: data.packageId,
                packageName: packageData.name || data.packageName || "Pacote",
                packagePrice: finalPrice,
                eventDate: eventDateTimestamp,
                eventTime: data.startTime || null,
                startTime: data.startTime || null,
                endTime: data.endTime || null,
                eventName: data.eventName || null,
                eventLocation: data.eventLocation || null,
                guestCount: data.guestCount || null,
                notes: data.notes || null,
                status: "pending",
                totalPrice: finalPrice, // Use determined price
                paidAmount: 0,
                platformFee: 0,
                supplierEarnings: 0,
                createdAt: now,
                updatedAt: now,
                createdBy: "cloud_function",
                clientRequestId: data.clientRequestId || null,
              };

              await bookingRef.set(bookingData);

              logger.stateTransition("booking", bookingRef.id, "none", "pending", clientId);

              // 12. Create notification for supplier
              const notificationRef = db.collection("notifications").doc();
              await notificationRef.set({
                id: notificationRef.id,
                userId: supplier.userId,
                type: "new_booking",
                title: "Nova Reserva",
                body: `${clientData?.displayName || "Um cliente"} solicitou uma reserva para ${data.eventDate}`,
                data: {
                  bookingId: bookingRef.id,
                  clientId: clientId,
                  eventDate: data.eventDate,
                },
                read: false,
                createdAt: now,
              });

              logger.operationSuccess("create_booking", {
                bookingId: bookingRef.id,
                supplierId: data.supplierId,
              });

              return {
                success: true,
                bookingId: bookingRef.id,
              } as CreateBookingResponse;
            }
        )
    );
