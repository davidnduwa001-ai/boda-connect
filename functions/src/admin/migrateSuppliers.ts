/**
 * Supplier Auto-Migration Script - ONE-TIME MIGRATION
 *
 * Safely migrates existing suppliers to the new authoritative model.
 *
 * POLICY:
 * - Never overwrite existing authoritative fields
 * - Support dry-run mode
 * - Rollback-safe (writes backup before migration)
 * - Extensive logging per supplier
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
  LifecycleState,
  KycStatus,
  SupplierCompliance,
  SupplierVisibility,
  SupplierBlocks,
  SupplierRateLimit,
} from "../suppliers/supplierEligibility";

const db = admin.firestore();
const REGION = "us-central1";
const FUNCTION_NAME = "migrateSuppliers";

// Migration version for tracking
const MIGRATION_VERSION = "2026-01-28-v1";

// ==================== TYPES ====================

interface MigrationRequest {
  dryRun: boolean;
  limit?: number; // For testing, limit suppliers to process
  supplierIds?: string[]; // Specific suppliers to migrate (for targeted fixes)
  skipEligibilityCheck?: boolean; // Skip post-migration eligibility check (faster)
}

interface SupplierMigrationResult {
  supplierId: string;
  status: "migrated" | "skipped" | "already_migrated" | "error";
  legacy_state: {
    status?: string;
    isActive?: boolean;
    acceptingBookings?: boolean;
    availabilityEnabled?: boolean;
  };
  computed_lifecycle_state: LifecycleState | null;
  fields_added: string[];
  fields_skipped: string[]; // Fields that already existed
  eligible_before: boolean | null;
  eligible_after: boolean | null;
  error?: string;
}

interface MigrationSummary {
  migration_version: string;
  dry_run: boolean;
  started_at: string;
  completed_at: string;
  execution_time_ms: number;
  total_suppliers: number;
  migrated: number;
  skipped: number;
  already_migrated: number;
  errors: number;
  eligibility_improved: number;
  eligibility_unchanged: number;
  eligibility_worsened: number; // Should be 0 if migration is correct
  fields_added_counts: {
    lifecycle_state: number;
    compliance: number;
    visibility: number;
    blocks: number;
    rate_limit: number;
  };
  error_details: Array<{supplierId: string; error: string}>;
  sample_results: SupplierMigrationResult[];
}

// ==================== ADMIN VERIFICATION ====================

async function verifyAdminAccess(uid: string): Promise<boolean> {
  try {
    const userRecord = await admin.auth().getUser(uid);
    if (userRecord.customClaims?.admin === true) {
      return true;
    }
  } catch {
    // Continue
  }

  const adminDoc = await db.collection("admins").doc(uid).get();
  if (adminDoc.exists) return true;

  const userDoc = await db.collection("users").doc(uid).get();
  if (userDoc.exists && userDoc.data()?.isAdmin === true) return true;

  return false;
}

// ==================== MIGRATION LOGIC ====================

/**
 * Compute lifecycle_state from legacy fields
 *
 * Migration mapping:
 * - isActive=false (any status) → "paused_by_supplier"
 * - status="active" OR "approved" → "active"
 * - status="pending" → "pending_review"
 * - status="suspended" → "suspended"
 * - status="disabled" → "disabled"
 * - Default → "draft"
 */
function computeLifecycleState(supplier: SupplierDocument): LifecycleState {
  const status = supplier.status?.toLowerCase();
  const isActive = supplier.isActive;

  // isActive=false takes precedence
  if (isActive === false) {
    return "paused_by_supplier";
  }

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

/**
 * Compute compliance from legacy state
 *
 * If supplier was active, assume they were compliant.
 * Otherwise, set to pending state.
 */
function computeCompliance(supplier: SupplierDocument): SupplierCompliance {
  const wasActive = (supplier.status === "active" || supplier.status === "approved") &&
                    supplier.isActive !== false;

  return {
    payouts_ready: wasActive,
    kyc_status: wasActive ? "verified" as KycStatus : "pending" as KycStatus,
  };
}

/**
 * Compute visibility from legacy state
 */
function computeVisibility(supplier: SupplierDocument): SupplierVisibility {
  return {
    is_listed: supplier.availabilityEnabled !== false,
  };
}

/**
 * Compute blocks from legacy state
 */
function computeBlocks(supplier: SupplierDocument): SupplierBlocks {
  return {
    bookings_globally: supplier.acceptingBookings === false,
    scheduled_blocks: [],
  };
}

/**
 * Compute rate_limit (always start fresh)
 */
function computeRateLimit(): SupplierRateLimit {
  return {
    exceeded: false,
  };
}

/**
 * Migrate a single supplier
 */
async function migrateSupplier(
    supplierId: string,
    supplier: SupplierDocument,
    dryRun: boolean,
    skipEligibilityCheck: boolean,
    adminUid: string,
    errorContext: ErrorContext
): Promise<SupplierMigrationResult> {
  const fieldsAdded: string[] = [];
  const fieldsSkipped: string[] = [];
  const updates: Record<string, unknown> = {};

  // Capture legacy state for logging
  const legacyState = {
    status: supplier.status,
    isActive: supplier.isActive,
    acceptingBookings: supplier.acceptingBookings,
    availabilityEnabled: supplier.availabilityEnabled,
  };

  // Check eligibility BEFORE migration
  let eligibleBefore: boolean | null = null;
  if (!skipEligibilityCheck) {
    try {
      const today = formatDateString(new Date());
      const result = await isSupplierBookable(supplierId, today, errorContext);
      eligibleBefore = result.eligible;
    } catch {
      eligibleBefore = null;
    }
  }

  // Already fully migrated?
  if (supplier.lifecycle_state &&
      supplier.compliance &&
      supplier.visibility &&
      supplier.blocks &&
      supplier.rate_limit) {
    return {
      supplierId,
      status: "already_migrated",
      legacy_state: legacyState,
      computed_lifecycle_state: supplier.lifecycle_state,
      fields_added: [],
      fields_skipped: ["lifecycle_state", "compliance", "visibility", "blocks", "rate_limit"],
      eligible_before: eligibleBefore,
      eligible_after: eligibleBefore, // No change
    };
  }

  // Compute lifecycle_state if missing
  let computedLifecycleState: LifecycleState | null = null;
  if (!supplier.lifecycle_state) {
    computedLifecycleState = computeLifecycleState(supplier);
    updates.lifecycle_state = computedLifecycleState;
    fieldsAdded.push("lifecycle_state");
  } else {
    computedLifecycleState = supplier.lifecycle_state;
    fieldsSkipped.push("lifecycle_state");
  }

  // Initialize compliance if missing
  if (!supplier.compliance) {
    updates.compliance = computeCompliance(supplier);
    fieldsAdded.push("compliance");
  } else {
    fieldsSkipped.push("compliance");
  }

  // Initialize visibility if missing
  if (!supplier.visibility) {
    updates.visibility = computeVisibility(supplier);
    fieldsAdded.push("visibility");
  } else {
    fieldsSkipped.push("visibility");
  }

  // Initialize blocks if missing
  if (!supplier.blocks) {
    updates.blocks = computeBlocks(supplier);
    fieldsAdded.push("blocks");
  } else {
    fieldsSkipped.push("blocks");
  }

  // Initialize rate_limit if missing
  if (!supplier.rate_limit) {
    updates.rate_limit = computeRateLimit();
    fieldsAdded.push("rate_limit");
  } else {
    fieldsSkipped.push("rate_limit");
  }

  // Nothing to migrate?
  if (fieldsAdded.length === 0) {
    return {
      supplierId,
      status: "skipped",
      legacy_state: legacyState,
      computed_lifecycle_state: computedLifecycleState,
      fields_added: [],
      fields_skipped: fieldsSkipped,
      eligible_before: eligibleBefore,
      eligible_after: eligibleBefore,
    };
  }

  // Add migration metadata (format per spec)
  updates._migration = {
    version: MIGRATION_VERSION,
    migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    migratedBy: adminUid,
    legacySnapshot: legacyState,
    fields_added: fieldsAdded,
  };

  // Write if not dry run
  if (!dryRun) {
    await db.collection("suppliers").doc(supplierId).update(updates);
  }

  // Check eligibility AFTER migration
  let eligibleAfter: boolean | null = null;
  if (!skipEligibilityCheck && !dryRun) {
    try {
      const today = formatDateString(new Date());
      const result = await isSupplierBookable(supplierId, today, errorContext);
      eligibleAfter = result.eligible;
    } catch {
      eligibleAfter = null;
    }
  } else if (!skipEligibilityCheck && dryRun) {
    // In dry-run, simulate post-migration eligibility
    // by checking what the eligibility would be with computed fields
    eligibleAfter = simulateEligibility(supplier, updates);
  }

  return {
    supplierId,
    status: "migrated",
    legacy_state: legacyState,
    computed_lifecycle_state: computedLifecycleState,
    fields_added: fieldsAdded,
    fields_skipped: fieldsSkipped,
    eligible_before: eligibleBefore,
    eligible_after: eligibleAfter,
  };
}

/**
 * Simulate eligibility for dry-run mode
 */
function simulateEligibility(
    supplier: SupplierDocument,
    updates: Record<string, unknown>
): boolean {
  const lifecycleState = (updates.lifecycle_state as LifecycleState) || supplier.lifecycle_state;
  const compliance = (updates.compliance as SupplierCompliance) || supplier.compliance;
  const visibility = (updates.visibility as SupplierVisibility) || supplier.visibility;
  const blocks = (updates.blocks as SupplierBlocks) || supplier.blocks;
  const rateLimit = (updates.rate_limit as SupplierRateLimit) || supplier.rate_limit;

  if (lifecycleState !== "active") return false;
  if (!compliance?.payouts_ready) return false;
  if (compliance?.kyc_status !== "verified") return false;
  if (!visibility?.is_listed) return false;
  if (blocks?.bookings_globally) return false;
  if (rateLimit?.exceeded) return false;

  return true;
}

// ==================== MAIN FUNCTION ====================

export const migrateSuppliers = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 540, // 9 minutes
      memory: "1GB",
    })
    .https.onCall(
        wrapHandler(
            FUNCTION_NAME,
            async (
                data: MigrationRequest,
                context: functions.https.CallableContext,
                errorContext: ErrorContext
            ): Promise<MigrationSummary> => {
              const startTime = Date.now();
              const startedAt = new Date().toISOString();
              const logger = SupplierLogger(FUNCTION_NAME).setContext(errorContext);

              const dryRun = data.dryRun !== false; // Default to dry-run for safety
              const skipEligibilityCheck = data.skipEligibilityCheck === true;

              logger.info("migration_started", {
                requestId: errorContext.requestId,
                dryRun,
                limit: data.limit,
                supplierIds: data.supplierIds?.length,
                skipEligibilityCheck,
                migrationVersion: MIGRATION_VERSION,
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
                  action: "migrate_suppliers",
                });
                throw Errors.permissionDenied(
                    errorContext,
                    "Admin access required",
                    "Acesso restrito a administradores"
                );
              }

              // 3. Fetch suppliers
              let suppliersQuery: admin.firestore.Query = db.collection("suppliers");

              if (data.supplierIds && data.supplierIds.length > 0) {
                // Targeted migration - fetch specific suppliers
                // Firestore doesn't support whereIn with more than 10, so we fetch individually
                const supplierDocs: admin.firestore.DocumentSnapshot[] = [];
                for (const id of data.supplierIds) {
                  const doc = await db.collection("suppliers").doc(id).get();
                  if (doc.exists) {
                    supplierDocs.push(doc);
                  }
                }
                return await processMigration(
                    supplierDocs,
                    dryRun,
                    skipEligibilityCheck,
                    context.auth.uid,
                    errorContext,
                    logger,
                    startTime,
                    startedAt
                );
              }

              if (data.limit && data.limit > 0) {
                suppliersQuery = suppliersQuery.limit(data.limit);
              }

              const suppliersSnapshot = await suppliersQuery.get();

              return await processMigration(
                  suppliersSnapshot.docs,
                  dryRun,
                  skipEligibilityCheck,
                  context.auth.uid,
                  errorContext,
                  logger,
                  startTime,
                  startedAt
              );
            }
        )
    );

async function processMigration(
    docs: admin.firestore.DocumentSnapshot[],
    dryRun: boolean,
    skipEligibilityCheck: boolean,
    adminUid: string,
    errorContext: ErrorContext,
    logger: ReturnType<typeof SupplierLogger>,
    startTime: number,
    startedAt: string
): Promise<MigrationSummary> {
  logger.info("suppliers_fetched", {count: docs.length});

  // Initialize counters
  const results: SupplierMigrationResult[] = [];
  const errorDetails: Array<{supplierId: string; error: string}> = [];
  const fieldsAddedCounts = {
    lifecycle_state: 0,
    compliance: 0,
    visibility: 0,
    blocks: 0,
    rate_limit: 0,
  };

  let migrated = 0;
  let skipped = 0;
  let alreadyMigrated = 0;
  let errors = 0;
  let eligibilityImproved = 0;
  let eligibilityUnchanged = 0;
  let eligibilityWorsened = 0;

  // Process in batches
  const BATCH_SIZE = 20;

  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = docs.slice(i, i + BATCH_SIZE);

    const batchResults = await Promise.all(
        batch.map(async (doc) => {
          try {
            const supplier = doc.data() as SupplierDocument;
            return await migrateSupplier(
                doc.id,
                supplier,
                dryRun,
                skipEligibilityCheck,
                adminUid,
                errorContext
            );
          } catch (error) {
            return {
              supplierId: doc.id,
              status: "error" as const,
              legacy_state: {},
              computed_lifecycle_state: null,
              fields_added: [],
              fields_skipped: [],
              eligible_before: null,
              eligible_after: null,
              error: error instanceof Error ? error.message : String(error),
            };
          }
        })
    );

    for (const result of batchResults) {
      results.push(result);

      // Count by status
      switch (result.status) {
      case "migrated":
        migrated++;
        break;
      case "skipped":
        skipped++;
        break;
      case "already_migrated":
        alreadyMigrated++;
        break;
      case "error":
        errors++;
        errorDetails.push({
          supplierId: result.supplierId,
          error: result.error || "Unknown error",
        });
        break;
      }

      // Count fields added
      for (const field of result.fields_added) {
        if (field in fieldsAddedCounts) {
          fieldsAddedCounts[field as keyof typeof fieldsAddedCounts]++;
        }
      }

      // Track eligibility changes
      if (result.eligible_before !== null && result.eligible_after !== null) {
        if (!result.eligible_before && result.eligible_after) {
          eligibilityImproved++;
        } else if (result.eligible_before && !result.eligible_after) {
          eligibilityWorsened++;
        } else {
          eligibilityUnchanged++;
        }
      }

      // Log each supplier migration
      logger.info("supplier_migrated", {
        supplierId: result.supplierId,
        status: result.status,
        computed_lifecycle_state: result.computed_lifecycle_state,
        fields_added: result.fields_added,
        eligible_before: result.eligible_before,
        eligible_after: result.eligible_after,
        dryRun,
      });
    }

    // Progress log for large migrations
    if (docs.length > 100 && (i + BATCH_SIZE) % 100 === 0) {
      logger.info("migration_progress", {
        processed: Math.min(i + BATCH_SIZE, docs.length),
        total: docs.length,
        migrated,
        errors,
      });
    }
  }

  const completedAt = new Date().toISOString();
  const executionTimeMs = Date.now() - startTime;

  // Build summary
  const summary: MigrationSummary = {
    migration_version: MIGRATION_VERSION,
    dry_run: dryRun,
    started_at: startedAt,
    completed_at: completedAt,
    execution_time_ms: executionTimeMs,
    total_suppliers: docs.length,
    migrated,
    skipped,
    already_migrated: alreadyMigrated,
    errors,
    eligibility_improved: eligibilityImproved,
    eligibility_unchanged: eligibilityUnchanged,
    eligibility_worsened: eligibilityWorsened,
    fields_added_counts: fieldsAddedCounts,
    error_details: errorDetails.slice(0, 20), // Limit error details
    sample_results: results.slice(0, 10), // Sample of results
  };

  logger.info("migration_completed", {
    ...summary,
    sample_results: undefined, // Don't log full sample
    error_details: undefined,
  });

  // Warn if eligibility worsened
  if (eligibilityWorsened > 0) {
    logger.warn("migration_eligibility_worsened", {
      count: eligibilityWorsened,
      message: "Some suppliers became ineligible after migration - investigate!",
    });
  }

  return summary;
}

// ==================== ROLLBACK FUNCTION ====================

interface RollbackRequest {
  supplierIds: string[];
  dryRun: boolean;
}

interface RollbackResult {
  supplierId: string;
  status: "rolled_back" | "no_migration_data" | "error";
  restored_fields: string[];
  error?: string;
}

interface RollbackSummary {
  dry_run: boolean;
  total: number;
  rolled_back: number;
  no_migration_data: number;
  errors: number;
  results: RollbackResult[];
}

/**
 * Rollback migration for specific suppliers
 *
 * Uses the _migration.legacy_state to restore original values
 */
export const rollbackMigration = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 300,
      memory: "512MB",
    })
    .https.onCall(
        wrapHandler(
            "rollbackMigration",
            async (
                data: RollbackRequest,
                context: functions.https.CallableContext,
                errorContext: ErrorContext
            ): Promise<RollbackSummary> => {
              const logger = SupplierLogger("rollbackMigration").setContext(errorContext);
              const dryRun = data.dryRun !== false;

              logger.info("rollback_started", {
                supplierIds: data.supplierIds,
                dryRun,
              });

              // Auth check
              if (!context.auth) {
                throw Errors.unauthenticated(errorContext);
              }

              const isAdmin = await verifyAdminAccess(context.auth.uid);
              if (!isAdmin) {
                throw Errors.permissionDenied(
                    errorContext,
                    "Admin access required",
                    "Acesso restrito a administradores"
                );
              }

              if (!data.supplierIds || data.supplierIds.length === 0) {
                throw Errors.invalidArgument(
                    errorContext,
                    "supplierIds",
                    "Required array of supplier IDs"
                );
              }

              const results: RollbackResult[] = [];
              let rolledBack = 0;
              let noMigrationData = 0;
              let errors = 0;

              for (const supplierId of data.supplierIds) {
                try {
                  const doc = await db.collection("suppliers").doc(supplierId).get();

                  if (!doc.exists) {
                    results.push({
                      supplierId,
                      status: "error",
                      restored_fields: [],
                      error: "Supplier not found",
                    });
                    errors++;
                    continue;
                  }

                  const supplier = doc.data() as SupplierDocument & {
                    _migration?: {
                      fields_added: string[];
                      legacySnapshot: Record<string, unknown>;
                      migratedBy: string;
                    };
                  };

                  if (!supplier._migration) {
                    results.push({
                      supplierId,
                      status: "no_migration_data",
                      restored_fields: [],
                    });
                    noMigrationData++;
                    continue;
                  }

                  // Remove migrated fields
                  const updates: Record<string, admin.firestore.FieldValue> = {};
                  const restoredFields: string[] = [];

                  for (const field of supplier._migration.fields_added) {
                    updates[field] = admin.firestore.FieldValue.delete();
                    restoredFields.push(field);
                  }

                  // Remove migration metadata
                  updates._migration = admin.firestore.FieldValue.delete();

                  if (!dryRun) {
                    await db.collection("suppliers").doc(supplierId).update(updates);
                  }

                  results.push({
                    supplierId,
                    status: "rolled_back",
                    restored_fields: restoredFields,
                  });
                  rolledBack++;

                  logger.info("supplier_rolled_back", {
                    supplierId,
                    restored_fields: restoredFields,
                    dryRun,
                  });
                } catch (error) {
                  results.push({
                    supplierId,
                    status: "error",
                    restored_fields: [],
                    error: error instanceof Error ? error.message : String(error),
                  });
                  errors++;
                }
              }

              logger.info("rollback_completed", {
                total: data.supplierIds.length,
                rolled_back: rolledBack,
                no_migration_data: noMigrationData,
                errors,
                dryRun,
              });

              return {
                dry_run: dryRun,
                total: data.supplierIds.length,
                rolled_back: rolledBack,
                no_migration_data: noMigrationData,
                errors,
                results,
              };
            }
        )
    );

// ==================== HELPERS ====================

function formatDateString(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}
