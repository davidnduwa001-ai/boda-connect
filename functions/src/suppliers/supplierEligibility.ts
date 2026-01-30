/**
 * Supplier Eligibility Gate - Server-Side Booking Validation
 *
 * This module implements the canonical booking eligibility check.
 * It is the SINGLE SOURCE OF TRUTH for determining if a supplier
 * can accept bookings.
 *
 * Authoritative Rule:
 * eligible_to_accept_booking =
 *   supplier.lifecycle_state == "active"
 *   AND supplier.compliance.payouts_ready == true
 *   AND supplier.compliance.kyc_status == "verified"
 *   AND supplier.visibility.is_listed == true
 *   AND supplier.blocks.bookings_globally != true
 *   AND supplier.blocks.by_schedule(eventDate) == false
 *   AND supplier.rate_limit.exceeded != true
 */

import * as admin from "firebase-admin";
import {ErrorContext} from "../common/errors";
import {createLogger} from "../common/logger";

// ==================== TYPES ====================

/**
 * Supplier lifecycle states
 */
export type LifecycleState =
  | "draft"              // Incomplete profile
  | "pending_review"     // Awaiting admin approval
  | "active"             // Can accept bookings
  | "paused_by_supplier" // Supplier-initiated pause
  | "suspended"          // Admin-initiated temporary block
  | "disabled"           // Admin-initiated permanent block
  | "archived";          // Soft-deleted

/**
 * KYC verification status
 */
export type KycStatus =
  | "not_started"
  | "pending"
  | "verified"
  | "rejected";

/**
 * Compliance fields - financial/legal requirements
 */
export interface SupplierCompliance {
  payouts_ready: boolean;
  kyc_status: KycStatus;
}

/**
 * Visibility fields - listing and discoverability
 */
export interface SupplierVisibility {
  is_listed: boolean;
}

/**
 * Block fields - temporary/permanent restrictions
 */
export interface SupplierBlocks {
  bookings_globally: boolean;
  scheduled_blocks?: string[]; // Array of YYYY-MM-DD date strings
}

/**
 * Rate limiting fields
 */
export interface SupplierRateLimit {
  exceeded: boolean;
}

/**
 * Identity verification status (NEW - separate from KYC)
 * This is the Flutter-side field that tracks identity document verification
 */
export type IdentityVerificationStatus =
  | "pending"
  | "verified"
  | "rejected";

/**
 * Full supplier document with new schema fields
 */
export interface SupplierDocument {
  // New authoritative fields
  lifecycle_state?: LifecycleState;
  compliance?: SupplierCompliance;
  visibility?: SupplierVisibility;
  blocks?: SupplierBlocks;
  rate_limit?: SupplierRateLimit;

  // Identity Verification (NEW - Flutter field)
  // This is SEPARATE from compliance.kyc_status and tracks identity document verification
  identityVerificationStatus?: IdentityVerificationStatus;

  // Onboarding status (Flutter accountStatus field)
  accountStatus?: string;

  // Legacy fields (for migration compatibility)
  status?: string;
  isActive?: boolean;
  acceptingBookings?: boolean;
  availabilityEnabled?: boolean;
  userId?: string;

  // Other fields
  businessName?: string;
  name?: string;
  phone?: string;
}

/**
 * Result of eligibility check with detailed rejection reasons
 */
export interface EligibilityResult {
  eligible: boolean;
  reasons: string[];
  uiState: "bookable" | "not_bookable" | "date_unavailable";
  debugInfo?: {
    lifecycle_state: LifecycleState | null;
    compliance_payouts_ready: boolean;
    compliance_kyc_status: KycStatus | null;
    identity_verification_status: IdentityVerificationStatus | null;
    account_status: string | null;
    visibility_is_listed: boolean;
    blocks_globally: boolean;
    blocks_by_date: boolean;
    rate_limit_exceeded: boolean;
    used_migration: boolean;
  };
}

// ==================== MIGRATION LOGIC ====================

/**
 * Map legacy supplier fields to new lifecycle_state
 *
 * Migration mapping:
 * - status="active" OR status="approved" + isActive=true → "active"
 * - status="pending" → "pending_review"
 * - status="suspended" → "suspended"
 * - status="disabled" → "disabled"
 * - isActive=false (any status) → "paused_by_supplier"
 * - Default/unknown → "draft"
 */
export function migrateLifecycleState(supplier: SupplierDocument): LifecycleState {
  // If new field exists, use it
  if (supplier.lifecycle_state) {
    return supplier.lifecycle_state;
  }

  const status = supplier.status?.toLowerCase();
  const isActive = supplier.isActive;

  // isActive=false takes precedence (supplier chose to pause)
  if (isActive === false) {
    return "paused_by_supplier";
  }

  // Map legacy status to lifecycle_state
  switch (status) {
  case "active":
  case "approved":
    return "active";
  case "pending":
  case "pending_review":
    return "pending_review";
  case "suspended":
    return "suspended";
  case "disabled":
    return "disabled";
  case "draft":
    return "draft";
  default:
    return "draft";
  }
}

// Legacy fallback removed — eligibility is authoritative once lifecycle_state exists

/**
 * Get compliance fields
 *
 * POLICY: If lifecycle_state exists, compliance MUST exist.
 * Legacy fallback is ONLY allowed when lifecycle_state is completely absent.
 */
function getCompliance(supplier: SupplierDocument): SupplierCompliance {
  // Authoritative: use compliance if present
  if (supplier.compliance) {
    return supplier.compliance;
  }

  // HARD DENY: lifecycle_state exists but compliance missing
  if (supplier.lifecycle_state) {
    return {
      payouts_ready: false,
      kyc_status: "not_started",
    };
  }

  // LEGACY FALLBACK: Only when lifecycle_state is completely absent
  const wasActive = (supplier.status === "active" || supplier.status === "approved") &&
                    supplier.isActive !== false;

  return {
    payouts_ready: wasActive,
    kyc_status: wasActive ? "verified" : "not_started",
  };
}

/**
 * Get visibility fields
 *
 * POLICY: If lifecycle_state exists, visibility MUST exist.
 * Legacy fallback is ONLY allowed when lifecycle_state is completely absent.
 */
function getVisibility(supplier: SupplierDocument): SupplierVisibility {
  // Authoritative: use visibility if present
  if (supplier.visibility) {
    return supplier.visibility;
  }

  // HARD DENY: lifecycle_state exists but visibility missing
  if (supplier.lifecycle_state) {
    return {
      is_listed: false,
    };
  }

  // LEGACY FALLBACK: Only when lifecycle_state is completely absent
  return {
    is_listed: supplier.availabilityEnabled !== false,
  };
}

/**
 * Get block fields
 *
 * POLICY: If lifecycle_state exists, blocks MUST exist.
 * Legacy fallback is ONLY allowed when lifecycle_state is completely absent.
 */
function getBlocks(supplier: SupplierDocument): SupplierBlocks {
  // Authoritative: use blocks if present
  if (supplier.blocks) {
    return supplier.blocks;
  }

  // HARD DENY: lifecycle_state exists but blocks missing
  // Default to globally blocked for safety
  if (supplier.lifecycle_state) {
    return {
      bookings_globally: true,
      scheduled_blocks: [],
    };
  }

  // LEGACY FALLBACK: Only when lifecycle_state is completely absent
  return {
    bookings_globally: supplier.acceptingBookings === false,
    scheduled_blocks: [],
  };
}

/**
 * Get rate limit fields
 *
 * POLICY: If lifecycle_state exists, rate_limit MUST exist.
 * Legacy fallback is ONLY allowed when lifecycle_state is completely absent.
 */
function getRateLimit(supplier: SupplierDocument): SupplierRateLimit {
  // Authoritative: use rate_limit if present
  if (supplier.rate_limit) {
    return supplier.rate_limit;
  }

  // HARD DENY: lifecycle_state exists but rate_limit missing
  if (supplier.lifecycle_state) {
    return {
      exceeded: true,
    };
  }

  // LEGACY FALLBACK: Only when lifecycle_state is completely absent
  return {
    exceeded: false,
  };
}

// ==================== MAIN ELIGIBILITY FUNCTION ====================

const db = admin.firestore();

/**
 * Check if a supplier is eligible to accept a booking on a given date
 *
 * This is the CANONICAL booking eligibility check.
 * All booking creation MUST go through this gate.
 *
 * @param supplierId - The supplier's document ID
 * @param eventDate - The requested booking date (YYYY-MM-DD string)
 * @param errorContext - Error context for logging
 * @returns EligibilityResult with eligible status and reasons
 */
export async function isSupplierBookable(
    supplierId: string,
    eventDate: string,
    errorContext?: ErrorContext
): Promise<EligibilityResult> {
  const logger = createLogger("booking", "isSupplierBookable");
  if (errorContext) {
    logger.setContext(errorContext);
  }

  logger.info("eligibility_check_started", {supplierId, eventDate});

  const reasons: string[] = [];
  let usedMigration = false;

  // Fetch supplier document
  const supplierDoc = await db.collection("suppliers").doc(supplierId).get();

  if (!supplierDoc.exists) {
    logger.warn("supplier_not_found", {supplierId});
    return {
      eligible: false,
      reasons: ["Fornecedor não encontrado"],
      uiState: "not_bookable",
    };
  }

  const supplier = supplierDoc.data() as SupplierDocument;

  // Check if we need migration (no new fields present)
  if (!supplier.lifecycle_state) {
    usedMigration = true;
    logger.info("using_migration_mapping", {
      supplierId,
      legacyStatus: supplier.status,
      legacyIsActive: supplier.isActive,
    });
  } else {
    // POLICY CHECK: lifecycle_state exists - all authoritative fields MUST exist
    // Missing any field triggers HARD DENY (no legacy fallback allowed)
    const missingFields: string[] = [];
    if (!supplier.compliance) missingFields.push("compliance");
    if (!supplier.visibility) missingFields.push("visibility");
    if (!supplier.blocks) missingFields.push("blocks");
    if (!supplier.rate_limit) missingFields.push("rate_limit");

    if (missingFields.length > 0) {
      logger.warn("authoritative_fields_missing_hard_deny", {
        supplierId,
        lifecycle_state: supplier.lifecycle_state,
        missingFields,
        policy: "lifecycle_state present requires all authoritative fields - no legacy fallback",
      });
    }
  }

  // Get fields (hard deny if lifecycle_state exists but fields missing)
  const lifecycleState = migrateLifecycleState(supplier);
  const compliance = getCompliance(supplier);
  const visibility = getVisibility(supplier);
  const blocks = getBlocks(supplier);
  const rateLimit = getRateLimit(supplier);

  // Check blocked dates from subcollection
  const isDateBlocked = await checkDateBlocked(supplierId, eventDate);

  // ==================== ELIGIBILITY CHECKS ====================

  // 1. Lifecycle state must be "active"
  if (lifecycleState !== "active") {
    reasons.push(getLifecycleStateReason(lifecycleState));
  }

  // 2. Compliance: payouts_ready must be true
  if (!compliance.payouts_ready) {
    reasons.push("Fornecedor não configurou recebimentos");
  }

  // 3. Compliance: kyc_status must be "verified"
  if (compliance.kyc_status !== "verified") {
    reasons.push("Verificação de identidade pendente");
  }

  // 3.5 Identity Verification: MUST be "verified" (NEW Flutter field)
  // This is SEPARATE from compliance.kyc_status and is the authoritative check
  // for the new identity verification workflow
  const identityVerificationStatus = supplier.identityVerificationStatus;
  if (identityVerificationStatus && identityVerificationStatus !== "verified") {
    // Only add reason if not already covered by kyc_status check
    if (compliance.kyc_status === "verified") {
      reasons.push("Verificação de identidade pendente");
    }
  }

  // 3.6 Account Status: MUST be "active" (NEW Flutter field)
  // This ensures onboarding is complete
  const accountStatus = supplier.accountStatus;
  if (accountStatus && accountStatus !== "active") {
    reasons.push("Aprovação de cadastro pendente");
  }

  // 4. Visibility: is_listed must be true
  if (!visibility.is_listed) {
    reasons.push("Fornecedor não está listado");
  }

  // 5. Blocks: bookings_globally must not be true
  if (blocks.bookings_globally) {
    reasons.push("Fornecedor pausou reservas temporariamente");
  }

  // 6. Rate limit: exceeded must not be true
  if (rateLimit.exceeded) {
    reasons.push("Limite de reservas atingido");
  }

  // 7. Date-specific blocks (from subcollection or scheduled_blocks)
  const dateBlockedBySchedule = blocks.scheduled_blocks?.includes(eventDate) || false;
  if (isDateBlocked || dateBlockedBySchedule) {
    reasons.push("Esta data não está disponível");
  }

  // Determine eligible status
  const eligible = reasons.length === 0;

  // Determine UI state
  let uiState: "bookable" | "not_bookable" | "date_unavailable";
  if (eligible) {
    uiState = "bookable";
  } else if (isDateBlocked || dateBlockedBySchedule) {
    uiState = "date_unavailable";
  } else {
    uiState = "not_bookable";
  }

  // Build debug info
  const debugInfo = {
    lifecycle_state: lifecycleState,
    compliance_payouts_ready: compliance.payouts_ready,
    compliance_kyc_status: compliance.kyc_status,
    identity_verification_status: identityVerificationStatus || null,
    account_status: accountStatus || null,
    visibility_is_listed: visibility.is_listed,
    blocks_globally: blocks.bookings_globally,
    blocks_by_date: isDateBlocked || dateBlockedBySchedule,
    rate_limit_exceeded: rateLimit.exceeded,
    used_migration: usedMigration,
  };

  logger.info("eligibility_check_completed", {
    supplierId,
    eventDate,
    eligible,
    uiState,
    reasonCount: reasons.length,
    ...debugInfo,
  });

  return {
    eligible,
    reasons,
    uiState,
    debugInfo,
  };
}

// ==================== HELPER FUNCTIONS ====================

/**
 * Check if a date is blocked in the supplier's blockedDates subcollection
 *
 * Canonical identity: document ID = YYYY-MM-DD date string
 * Legacy fallback: query by date field for auto-ID documents
 */
async function checkDateBlocked(
    supplierId: string,
    eventDate: string
): Promise<boolean> {
  // ==================== CANONICAL CHECK ====================
  // Check by document ID (YYYY-MM-DD) - this is the authoritative method

  // Check blockedDates/{YYYY-MM-DD}
  const blockedDoc = await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blockedDates")
      .doc(eventDate)
      .get();

  if (blockedDoc.exists) {
    return true;
  }

  // Check blocked_dates/{YYYY-MM-DD} (alternative naming used by Flutter service)
  const altBlockedDoc = await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blocked_dates")
      .doc(eventDate)
      .get();

  if (altBlockedDoc.exists) {
    return true;
  }

  // ==================== LEGACY FALLBACK ====================
  // TEMPORARY: legacy auto-ID fallback — remove after migration
  // Some blocked dates were created with auto-generated IDs and store
  // the date in a field. Query to catch these during migration period.

  // Parse eventDate to create date range for query
  const requestedDate = new Date(eventDate + "T00:00:00");
  const nextDay = new Date(eventDate + "T00:00:00");
  nextDay.setDate(nextDay.getDate() + 1);

  // Query blockedDates collection by date field
  const legacyQuery1 = await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blockedDates")
      .where("date", ">=", admin.firestore.Timestamp.fromDate(requestedDate))
      .where("date", "<", admin.firestore.Timestamp.fromDate(nextDay))
      .limit(1)
      .get();

  if (!legacyQuery1.empty) {
    return true;
  }

  // Query blocked_dates collection by date field
  const legacyQuery2 = await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blocked_dates")
      .where("date", ">=", admin.firestore.Timestamp.fromDate(requestedDate))
      .where("date", "<", admin.firestore.Timestamp.fromDate(nextDay))
      .limit(1)
      .get();

  if (!legacyQuery2.empty) {
    return true;
  }

  return false;
}

/**
 * Get user-friendly reason for lifecycle state
 */
function getLifecycleStateReason(state: LifecycleState): string {
  switch (state) {
  case "draft":
    return "Fornecedor ainda não completou o cadastro";
  case "pending_review":
    return "Fornecedor aguardando aprovação";
  case "paused_by_supplier":
    return "Fornecedor pausou as reservas";
  case "suspended":
    return "Fornecedor temporariamente suspenso";
  case "disabled":
    return "Fornecedor desativado";
  case "archived":
    return "Fornecedor não está mais disponível";
  default:
    return "Fornecedor não disponível para reservas";
  }
}

// ==================== EXPORTS FOR TESTING ====================

export {
  getCompliance,
  getVisibility,
  getBlocks,
  getRateLimit,
  checkDateBlocked,
  getLifecycleStateReason,
};
