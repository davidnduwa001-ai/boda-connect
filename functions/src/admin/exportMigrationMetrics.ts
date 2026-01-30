/**
 * Supplier Migration Metrics Export - READ-ONLY
 *
 * Scans all suppliers and classifies them by migration status.
 * Safe to run repeatedly - no data mutation.
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
} from "../suppliers/supplierEligibility";

const db = admin.firestore();
const REGION = "us-central1";
const FUNCTION_NAME = "exportMigrationMetrics";

// Metrics version for tracking
const METRICS_VERSION = "2026-01-28-v1";

// ==================== TYPES ====================

type MigrationStatus = "legacy" | "partial" | "compliant" | "blocked";

interface SupplierClassification {
  supplierId: string;
  status: MigrationStatus;
  lifecycle_state: LifecycleState | null;
  missingFields: string[];
  eligible: boolean;
  blockingReasons: string[];
}

interface MissingFieldsBreakdown {
  missing_compliance: number;
  missing_visibility: number;
  missing_blocks: number;
  missing_rate_limit: number;
}

interface Totals {
  total_suppliers: number;
  legacy_only: number;         // No lifecycle_state
  partially_migrated: number;  // Has lifecycle_state but missing some fields
  fully_migrated: number;      // All authoritative fields present
  eligible: number;            // Currently bookable
  blocked: number;             // Not bookable (any reason)
}

interface BlockingBreakdown {
  blocked_by_lifecycle: number;   // lifecycle_state != "active"
  blocked_by_compliance: number;  // payouts or kyc issues
  blocked_by_visibility: number;  // not listed
  blocked_by_blocks: number;      // globally blocked or date blocked
  blocked_by_rate_limit: number;  // rate limit exceeded
}

interface MigrationMetricsResponse {
  version: string;
  totals: Totals;
  missingFieldsBreakdown: MissingFieldsBreakdown;
  blockingBreakdown: BlockingBreakdown;
  blockedReasonCounts: Record<string, number>;
  sampleSuppliers: {
    legacy: string[];
    partial: string[];
    blocked: string[];
    eligible: string[];
  };
  notes: string[];
  generatedAt: string;
  executionTimeMs: number;
}

interface ExportRequest {
  format?: "json" | "csv";
  includeDetails?: boolean;
  limit?: number; // For testing, limit number of suppliers to scan
}

// ==================== ADMIN VERIFICATION ====================

async function verifyAdminAccess(uid: string): Promise<boolean> {
  try {
    const userRecord = await admin.auth().getUser(uid);
    if (userRecord.customClaims?.admin === true) {
      return true;
    }
  } catch {
    // Continue to other checks
  }

  const adminDoc = await db.collection("admins").doc(uid).get();
  if (adminDoc.exists) {
    return true;
  }

  const userDoc = await db.collection("users").doc(uid).get();
  if (userDoc.exists && userDoc.data()?.isAdmin === true) {
    return true;
  }

  return false;
}

// ==================== CLASSIFICATION LOGIC ====================

/**
 * Classify a single supplier by migration status
 */
async function classifySupplier(
    supplierId: string,
    supplier: SupplierDocument,
    errorContext: ErrorContext
): Promise<SupplierClassification> {
  const missingFields: string[] = [];

  // Check for missing authoritative fields
  if (!supplier.compliance) missingFields.push("compliance");
  if (!supplier.visibility) missingFields.push("visibility");
  if (!supplier.blocks) missingFields.push("blocks");
  if (!supplier.rate_limit) missingFields.push("rate_limit");

  // Determine migration status
  let status: MigrationStatus;

  if (!supplier.lifecycle_state) {
    // No lifecycle_state = legacy supplier
    status = "legacy";
  } else if (missingFields.length > 0) {
    // Has lifecycle_state but missing some fields = partial migration
    status = "partial";
  } else {
    // Fully migrated
    status = "compliant";
  }

  // Check eligibility using canonical function
  const today = new Date();
  const eventDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

  const eligibility = await isSupplierBookable(supplierId, eventDate, errorContext);

  // Override status to blocked if not eligible (regardless of migration status)
  if (!eligibility.eligible && status === "compliant") {
    status = "blocked";
  }

  return {
    supplierId,
    status,
    lifecycle_state: supplier.lifecycle_state || null,
    missingFields,
    eligible: eligibility.eligible,
    blockingReasons: eligibility.reasons,
  };
}

// ==================== CSV GENERATION ====================

function generateCSV(classifications: SupplierClassification[]): string {
  const headers = [
    "supplierId",
    "status",
    "lifecycle_state",
    "eligible",
    "missingFields",
    "blockingReasons",
  ];

  const rows = classifications.map((c) => [
    c.supplierId,
    c.status,
    c.lifecycle_state || "null",
    c.eligible.toString(),
    c.missingFields.join(";") || "none",
    c.blockingReasons.join(";") || "none",
  ]);

  const csvContent = [
    headers.join(","),
    ...rows.map((row) => row.map((cell) => `"${cell}"`).join(",")),
  ].join("\n");

  return csvContent;
}

// ==================== MAIN FUNCTION ====================

export const exportMigrationMetrics = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 540, // 9 minutes for large datasets
      memory: "1GB",
    })
    .https.onCall(
        wrapHandler(
            FUNCTION_NAME,
            async (
                data: ExportRequest,
                context: functions.https.CallableContext,
                errorContext: ErrorContext
            ): Promise<MigrationMetricsResponse | {csv: string}> => {
              const startTime = Date.now();
              const logger = SupplierLogger(FUNCTION_NAME).setContext(errorContext);

              logger.info("export_started", {
                requestId: errorContext.requestId,
                format: data.format || "json",
                limit: data.limit,
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
                  action: "export_migration_metrics",
                });
                throw Errors.permissionDenied(
                    errorContext,
                    "Admin access required",
                    "Acesso restrito a administradores"
                );
              }

              // 3. Fetch all suppliers
              let suppliersQuery: admin.firestore.Query = db.collection("suppliers");

              if (data.limit && data.limit > 0) {
                suppliersQuery = suppliersQuery.limit(data.limit);
              }

              const suppliersSnapshot = await suppliersQuery.get();

              logger.info("suppliers_fetched", {
                count: suppliersSnapshot.docs.length,
              });

              // 4. Classify each supplier
              const classifications: SupplierClassification[] = [];
              const totals: Totals = {
                total_suppliers: 0,
                legacy_only: 0,
                partially_migrated: 0,
                fully_migrated: 0,
                eligible: 0,
                blocked: 0,
              };
              const missingFieldsBreakdown: MissingFieldsBreakdown = {
                missing_compliance: 0,
                missing_visibility: 0,
                missing_blocks: 0,
                missing_rate_limit: 0,
              };
              const blockingBreakdown: BlockingBreakdown = {
                blocked_by_lifecycle: 0,
                blocked_by_compliance: 0,
                blocked_by_visibility: 0,
                blocked_by_blocks: 0,
                blocked_by_rate_limit: 0,
              };
              const blockedReasonCounts: Record<string, number> = {};
              const sampleSuppliers = {
                legacy: [] as string[],
                partial: [] as string[],
                blocked: [] as string[],
                eligible: [] as string[],
              };
              const notes: string[] = [];

              // Process in batches to avoid memory issues
              const BATCH_SIZE = 50;
              const docs = suppliersSnapshot.docs;

              for (let i = 0; i < docs.length; i += BATCH_SIZE) {
                const batch = docs.slice(i, i + BATCH_SIZE);

                const batchResults = await Promise.all(
                    batch.map(async (doc) => {
                      const supplier = doc.data() as SupplierDocument;
                      return classifySupplier(doc.id, supplier, errorContext);
                    })
                );

                for (const classification of batchResults) {
                  classifications.push(classification);
                  totals.total_suppliers++;

                  // Count by migration status
                  switch (classification.status) {
                  case "legacy":
                    totals.legacy_only++;
                    break;
                  case "partial":
                    totals.partially_migrated++;
                    break;
                  case "compliant":
                    totals.fully_migrated++;
                    break;
                  case "blocked":
                    totals.fully_migrated++; // Still migrated, just blocked
                    break;
                  }

                  // Count eligible vs blocked
                  if (classification.eligible) {
                    totals.eligible++;
                  } else {
                    totals.blocked++;
                  }

                  // Track missing fields
                  for (const field of classification.missingFields) {
                    const key = `missing_${field}` as keyof MissingFieldsBreakdown;
                    if (key in missingFieldsBreakdown) {
                      missingFieldsBreakdown[key]++;
                    }
                  }

                  // Track blocking reasons by category
                  for (const reason of classification.blockingReasons) {
                    const reasonKey = normalizeReasonKey(reason);
                    blockedReasonCounts[reasonKey] = (blockedReasonCounts[reasonKey] || 0) + 1;

                    // Categorize into blocking breakdown
                    if (reason.includes("lifecycle_state")) {
                      blockingBreakdown.blocked_by_lifecycle++;
                    } else if (reason.includes("payouts_ready") || reason.includes("kyc_status")) {
                      blockingBreakdown.blocked_by_compliance++;
                    } else if (reason.includes("is_listed")) {
                      blockingBreakdown.blocked_by_visibility++;
                    } else if (reason.includes("bookings_globally") || reason.includes("date_blocked")) {
                      blockingBreakdown.blocked_by_blocks++;
                    } else if (reason.includes("rate_limit")) {
                      blockingBreakdown.blocked_by_rate_limit++;
                    }
                  }

                  // Collect sample supplier IDs (max 5 each)
                  if (classification.status === "legacy" && sampleSuppliers.legacy.length < 5) {
                    sampleSuppliers.legacy.push(classification.supplierId);
                  } else if (classification.status === "partial" && sampleSuppliers.partial.length < 5) {
                    sampleSuppliers.partial.push(classification.supplierId);
                  } else if (classification.status === "blocked" && sampleSuppliers.blocked.length < 5) {
                    sampleSuppliers.blocked.push(classification.supplierId);
                  } else if (classification.eligible && sampleSuppliers.eligible.length < 5) {
                    sampleSuppliers.eligible.push(classification.supplierId);
                  }
                }

                // Log progress for large datasets
                if (docs.length > 100 && (i + BATCH_SIZE) % 200 === 0) {
                  logger.info("export_progress", {
                    processed: Math.min(i + BATCH_SIZE, docs.length),
                    total: docs.length,
                  });
                }
              }

              const executionTimeMs = Date.now() - startTime;
              const generatedAt = new Date().toISOString();

              // Add notes about legacy fallback status
              if (totals.legacy_only > 0) {
                notes.push(`LEGACY_FALLBACK_ACTIVE: ${totals.legacy_only} suppliers still using legacy eligibility mapping`);
              }
              if (totals.partially_migrated > 0) {
                notes.push(`PARTIAL_MIGRATION: ${totals.partially_migrated} suppliers have lifecycle_state but missing authoritative fields`);
              }
              if (totals.legacy_only === 0 && totals.partially_migrated === 0) {
                notes.push("MIGRATION_COMPLETE: All suppliers fully migrated to authoritative model");
              }

              logger.info("export_completed", {
                requestId: errorContext.requestId,
                totals,
                executionTimeMs,
              });

              // 5. Return in requested format
              if (data.format === "csv") {
                return {
                  csv: generateCSV(classifications),
                };
              }

              return {
                version: METRICS_VERSION,
                totals,
                missingFieldsBreakdown,
                blockingBreakdown,
                blockedReasonCounts,
                sampleSuppliers,
                notes,
                generatedAt,
                executionTimeMs,
              };
            }
        )
    );

// ==================== HTTP ENDPOINT (for CSV download) ====================

export const exportMigrationMetricsHttp = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 540,
      memory: "1GB",
    })
    .https.onRequest(async (req, res) => {
      const startTime = Date.now();
      const logger = SupplierLogger(FUNCTION_NAME + "_http");

      try {
        // Verify admin via Authorization header (Bearer token)
        const authHeader = req.headers.authorization;
        if (!authHeader?.startsWith("Bearer ")) {
          res.status(401).json({error: "Missing or invalid Authorization header"});
          return;
        }

        const idToken = authHeader.substring(7);
        let decodedToken: admin.auth.DecodedIdToken;

        try {
          decodedToken = await admin.auth().verifyIdToken(idToken);
        } catch {
          res.status(401).json({error: "Invalid token"});
          return;
        }

        const isAdmin = await verifyAdminAccess(decodedToken.uid);
        if (!isAdmin) {
          res.status(403).json({error: "Admin access required"});
          return;
        }

        // Parse query params
        const format = req.query.format === "csv" ? "csv" : "json";
        const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;

        logger.info("http_export_started", {format, limit});

        // Fetch suppliers
        let suppliersQuery: admin.firestore.Query = db.collection("suppliers");
        if (limit && limit > 0) {
          suppliersQuery = suppliersQuery.limit(limit);
        }

        const suppliersSnapshot = await suppliersQuery.get();
        const classifications: SupplierClassification[] = [];

        // Create a minimal error context for classification
        const errorContext: ErrorContext = {
          requestId: `http-${Date.now()}`,
          functionName: FUNCTION_NAME,
          uid: decodedToken.uid,
        };

        for (const doc of suppliersSnapshot.docs) {
          const supplier = doc.data() as SupplierDocument;
          const classification = await classifySupplier(doc.id, supplier, errorContext);
          classifications.push(classification);
        }

        // Generate response
        if (format === "csv") {
          const csv = generateCSV(classifications);
          res.setHeader("Content-Type", "text/csv");
          res.setHeader("Content-Disposition", `attachment; filename="migration-metrics-${Date.now()}.csv"`);
          res.send(csv);
          return;
        }

        // JSON response with full metrics
        const totals: Totals = {
          total_suppliers: 0,
          legacy_only: 0,
          partially_migrated: 0,
          fully_migrated: 0,
          eligible: 0,
          blocked: 0,
        };
        const missingFieldsBreakdown: MissingFieldsBreakdown = {
          missing_compliance: 0,
          missing_visibility: 0,
          missing_blocks: 0,
          missing_rate_limit: 0,
        };
        const blockingBreakdown: BlockingBreakdown = {
          blocked_by_lifecycle: 0,
          blocked_by_compliance: 0,
          blocked_by_visibility: 0,
          blocked_by_blocks: 0,
          blocked_by_rate_limit: 0,
        };
        const notes: string[] = [];

        for (const c of classifications) {
          totals.total_suppliers++;

          // Migration status
          switch (c.status) {
          case "legacy":
            totals.legacy_only++;
            break;
          case "partial":
            totals.partially_migrated++;
            break;
          case "compliant":
          case "blocked":
            totals.fully_migrated++;
            break;
          }

          // Eligibility
          if (c.eligible) {
            totals.eligible++;
          } else {
            totals.blocked++;
          }

          // Missing fields
          for (const field of c.missingFields) {
            const key = `missing_${field}` as keyof MissingFieldsBreakdown;
            if (key in missingFieldsBreakdown) missingFieldsBreakdown[key]++;
          }

          // Blocking reasons
          for (const reason of c.blockingReasons) {
            if (reason.includes("lifecycle_state")) {
              blockingBreakdown.blocked_by_lifecycle++;
            } else if (reason.includes("payouts_ready") || reason.includes("kyc_status")) {
              blockingBreakdown.blocked_by_compliance++;
            } else if (reason.includes("is_listed")) {
              blockingBreakdown.blocked_by_visibility++;
            } else if (reason.includes("bookings_globally") || reason.includes("date_blocked")) {
              blockingBreakdown.blocked_by_blocks++;
            } else if (reason.includes("rate_limit")) {
              blockingBreakdown.blocked_by_rate_limit++;
            }
          }
        }

        // Add notes
        if (totals.legacy_only > 0) {
          notes.push(`LEGACY_FALLBACK_ACTIVE: ${totals.legacy_only} suppliers still using legacy mapping`);
        }
        if (totals.legacy_only === 0 && totals.partially_migrated === 0) {
          notes.push("MIGRATION_COMPLETE: All suppliers fully migrated");
        }

        res.json({
          version: METRICS_VERSION,
          totals,
          missingFieldsBreakdown,
          blockingBreakdown,
          notes,
          generatedAt: new Date().toISOString(),
          executionTimeMs: Date.now() - startTime,
        });
      } catch (error) {
        logger.error("http_export_failed", error instanceof Error ? error : new Error(String(error)));
        res.status(500).json({error: "Internal server error"});
      }
    });

// ==================== HELPERS ====================

/**
 * Normalize a blocking reason to a countable key
 */
function normalizeReasonKey(reason: string): string {
  // Extract the first meaningful part of the reason
  if (reason.includes("lifecycle_state")) return "lifecycle_not_active";
  if (reason.includes("payouts_ready")) return "payouts_not_ready";
  if (reason.includes("kyc_status")) return "kyc_not_verified";
  if (reason.includes("is_listed")) return "not_listed";
  if (reason.includes("bookings_globally")) return "globally_blocked";
  if (reason.includes("date_blocked")) return "date_blocked";
  if (reason.includes("rate_limit")) return "rate_limited";
  if (reason.includes("POLICY_VIOLATION")) return "policy_violation";

  // Fallback: use first 30 chars
  return reason.substring(0, 30).replace(/[^a-zA-Z0-9_]/g, "_");
}
