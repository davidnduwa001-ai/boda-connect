/**
 * Admin Supplier Eligibility Inspector - READ-ONLY
 *
 * Provides detailed diagnostic information about supplier booking eligibility.
 * Reuses the SAME eligibility logic as createBooking - no duplication.
 *
 * POLICY: This function NEVER mutates data.
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  wrapHandler,
  Errors,
  ErrorContext,
} from "../common/errors";
import {SupplierLogger} from "../common/logger";
import {
  isSupplierBookable,
  SupplierDocument,
  migrateLifecycleState,
  LifecycleState,
} from "../suppliers/supplierEligibility";

const db = admin.firestore();
const REGION = "us-central1";
const FUNCTION_NAME = "inspectSupplierEligibility";

// ==================== TYPES ====================

interface InspectRequest {
  supplierId: string;
  eventDate?: string; // Optional: YYYY-MM-DD
}

interface RawFieldPresence {
  has_lifecycle_state: boolean;
  has_compliance: boolean;
  has_visibility: boolean;
  has_blocks: boolean;
  has_rate_limit: boolean;
}

interface InspectResponse {
  eligible: boolean;
  lifecycle_state: LifecycleState | null;
  failedChecks: string[];
  reasonCodes: string[];
  rawFields: RawFieldPresence;
  usedLegacyFallback: boolean;
}

// ==================== ADMIN VERIFICATION ====================

async function verifyAdminAccess(uid: string): Promise<boolean> {
  // Check custom claims first (most secure)
  try {
    const userRecord = await admin.auth().getUser(uid);
    if (userRecord.customClaims?.admin === true) {
      return true;
    }
  } catch {
    // Continue to other checks
  }

  // Check admins collection
  const adminDoc = await db.collection("admins").doc(uid).get();
  if (adminDoc.exists) {
    return true;
  }

  // Check user document isAdmin flag
  const userDoc = await db.collection("users").doc(uid).get();
  if (userDoc.exists && userDoc.data()?.isAdmin === true) {
    return true;
  }

  return false;
}

// ==================== DATE FORMATTING ====================

function formatDateString(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

// ==================== MAIN FUNCTION ====================

/**
 * Inspect Supplier Eligibility - Admin-Only Callable Function
 *
 * Returns detailed eligibility breakdown for diagnostic purposes.
 * Reuses the SAME isSupplierBookable() logic used by createBooking.
 *
 * This function NEVER throws for eligibility issues - it reports them.
 * It only throws for:
 * - Authentication failures
 * - Authorization failures (non-admin)
 * - Supplier not found
 */
export const inspectSupplierEligibility = functions
    .region(REGION)
    .https.onCall(
        wrapHandler(
            FUNCTION_NAME,
            async (
                data: InspectRequest,
                context: functions.https.CallableContext,
                errorContext: ErrorContext
            ): Promise<InspectResponse> => {
              const logger = SupplierLogger(FUNCTION_NAME).setContext(errorContext);

              logger.info("inspect_started", {
                requestId: errorContext.requestId,
                supplierId: data.supplierId,
                eventDate: data.eventDate,
              });

              // 1. Require authentication
              if (!context.auth) {
                throw Errors.unauthenticated(errorContext);
              }

              // 2. Verify admin privileges
              const isAdmin = await verifyAdminAccess(context.auth.uid);
              if (!isAdmin) {
                logger.warn("admin_access_denied", {
                  uid: context.auth.uid,
                  action: "inspect_supplier_eligibility",
                });
                throw Errors.permissionDenied(
                    errorContext,
                    "Admin access required",
                    "Acesso restrito a administradores"
                );
              }

              // 3. Validate input
              if (!data.supplierId || typeof data.supplierId !== "string") {
                throw Errors.invalidArgument(
                    errorContext,
                    "supplierId",
                    "Required string field"
                );
              }

              // Use today's date if not specified
              const eventDate = data.eventDate || formatDateString(new Date());

              // 4. Fetch supplier document (throws if not found)
              const supplierDoc = await db
                  .collection("suppliers")
                  .doc(data.supplierId)
                  .get();

              if (!supplierDoc.exists) {
                throw Errors.notFound(errorContext, "Supplier", data.supplierId);
              }

              const supplier = supplierDoc.data() as SupplierDocument;

              // 5. Run the CANONICAL eligibility check (same as createBooking)
              const eligibility = await isSupplierBookable(
                  data.supplierId,
                  eventDate,
                  errorContext
              );

              // 6. Build diagnostic response (read-only)
              const usedLegacyFallback = !supplier.lifecycle_state;
              const resolvedLifecycleState = supplier.lifecycle_state ||
                  migrateLifecycleState(supplier);

              // Raw field presence
              const rawFields: RawFieldPresence = {
                has_lifecycle_state: !!supplier.lifecycle_state,
                has_compliance: !!supplier.compliance,
                has_visibility: !!supplier.visibility,
                has_blocks: !!supplier.blocks,
                has_rate_limit: !!supplier.rate_limit,
              };

              // Build failure details from canonical debugInfo
              const {failedChecks, reasonCodes} = buildFailureDetails(
                  eligibility.debugInfo
              );

              // Log when eligibility fails (include missing authoritative fields)
              if (!eligibility.eligible) {
                const missingAuthoritativeFields = getMissingAuthoritativeFields(supplier);
                logger.warn("eligibility_failed", {
                  requestId: errorContext.requestId,
                  supplierId: data.supplierId,
                  eventDate,
                  failedChecks,
                  reasonCodes,
                  missingAuthoritativeFields,
                });
              }

              const response: InspectResponse = {
                eligible: eligibility.eligible,
                lifecycle_state: resolvedLifecycleState,
                failedChecks,
                reasonCodes,
                rawFields,
                usedLegacyFallback,
              };

              logger.info("inspect_completed", {
                requestId: errorContext.requestId,
                supplierId: data.supplierId,
                eligible: response.eligible,
                failedCheckCount: failedChecks.length,
                usedLegacyFallback,
              });

              return response;
            }
        )
    );

// ==================== FAILURE DETAILS ====================

function buildFailureDetails(
    debugInfo?: {
      lifecycle_state: LifecycleState | null;
      compliance_payouts_ready: boolean;
      compliance_kyc_status: "verified" | string | null;
      visibility_is_listed: boolean;
      blocks_globally: boolean;
      blocks_by_date: boolean;
      rate_limit_exceeded: boolean;
      used_migration: boolean;
    }
): {failedChecks: string[]; reasonCodes: string[]} {
  const failedChecks: string[] = [];
  const reasonCodes: string[] = [];

  if (!debugInfo) {
    failedChecks.push("unknown");
    reasonCodes.push("UNKNOWN");
    return {failedChecks, reasonCodes};
  }

  if (debugInfo.lifecycle_state !== "active") {
    failedChecks.push("lifecycle_state_active");
    reasonCodes.push("LIFECYCLE_NOT_ACTIVE");
  }

  if (!debugInfo.compliance_payouts_ready) {
    failedChecks.push("compliance_payouts_ready");
    reasonCodes.push("PAYOUTS_NOT_READY");
  }

  if (debugInfo.compliance_kyc_status !== "verified") {
    failedChecks.push("compliance_kyc_verified");
    reasonCodes.push("KYC_NOT_VERIFIED");
  }

  if (!debugInfo.visibility_is_listed) {
    failedChecks.push("visibility_is_listed");
    reasonCodes.push("NOT_LISTED");
  }

  if (debugInfo.blocks_globally) {
    failedChecks.push("blocks_globally_off");
    reasonCodes.push("BOOKINGS_GLOBALLY_BLOCKED");
  }

  if (debugInfo.blocks_by_date) {
    failedChecks.push("date_available");
    reasonCodes.push("DATE_BLOCKED");
  }

  if (debugInfo.rate_limit_exceeded) {
    failedChecks.push("rate_limit_not_exceeded");
    reasonCodes.push("RATE_LIMIT_EXCEEDED");
  }

  return {
    failedChecks: Array.from(new Set(failedChecks)),
    reasonCodes: Array.from(new Set(reasonCodes)),
  };
}

function getMissingAuthoritativeFields(
    supplier: SupplierDocument
): string[] {
  if (!supplier.lifecycle_state) {
    return [];
  }

  const missing: string[] = [];
  if (!supplier.compliance) missing.push("compliance");
  if (!supplier.visibility) missing.push("visibility");
  if (!supplier.blocks) missing.push("blocks");
  if (!supplier.rate_limit) missing.push("rate_limit");

  return missing;
}
