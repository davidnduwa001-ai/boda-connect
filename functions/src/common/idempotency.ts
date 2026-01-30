/**
 * Idempotency Guards - Production Safeguards
 *
 * This module provides:
 * - Idempotency key management
 * - Duplicate request detection
 * - Safe retry handling for webhooks and critical operations
 */

import * as admin from "firebase-admin";
import {ErrorContext} from "./errors";
import {createLogger} from "./logger";

const db = admin.firestore();

// ==================== IDEMPOTENCY KEY STORE ====================

/**
 * TTL for idempotency keys (24 hours)
 */
const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;

/**
 * Idempotency record structure
 */
interface IdempotencyRecord {
  key: string;
  operation: string;
  resourceId?: string;
  status: "processing" | "completed" | "failed";
  result?: unknown;
  createdAt: FirebaseFirestore.FieldValue;
  completedAt?: FirebaseFirestore.FieldValue;
  expiresAt: FirebaseFirestore.Timestamp;
}

// ==================== IDEMPOTENCY GUARD ====================

/**
 * Result of idempotency check
 */
export type IdempotencyCheckResult<T> =
  | {isDuplicate: false}
  | {isDuplicate: true; previousResult: T};

/**
 * Check if an operation has already been processed
 * Returns the previous result if it has
 */
export async function checkIdempotency<T>(
    idempotencyKey: string,
    operation: string,
    errorContext: ErrorContext
): Promise<IdempotencyCheckResult<T>> {
  const logger = createLogger("system", "idempotency").setContext(errorContext);

  try {
    const doc = await db.collection("idempotency_keys").doc(idempotencyKey).get();

    if (!doc.exists) {
      return {isDuplicate: false};
    }

    const data = doc.data() as IdempotencyRecord;

    // Check if expired
    if (data.expiresAt.toDate() < new Date()) {
      // Expired, allow retry
      logger.debug("idempotency_key_expired", {
        key: idempotencyKey,
        operation,
      });
      return {isDuplicate: false};
    }

    // Check status
    if (data.status === "completed") {
      logger.idempotentSkip(operation, idempotencyKey, "already_completed");
      return {
        isDuplicate: true,
        previousResult: data.result as T,
      };
    }

    if (data.status === "processing") {
      // Still processing - could be a retry during slow operation
      // Log and treat as duplicate to prevent double-execution
      logger.idempotentSkip(operation, idempotencyKey, "still_processing");
      return {
        isDuplicate: true,
        previousResult: undefined as T, // No result yet
      };
    }

    // Failed status - allow retry
    return {isDuplicate: false};
  } catch (error) {
    // Error checking idempotency - log and allow operation to proceed
    // Better to risk duplicate than to block legitimate requests
    logger.warn("idempotency_check_failed", {
      key: idempotencyKey,
      error: error instanceof Error ? error.message : "unknown",
    });
    return {isDuplicate: false};
  }
}

/**
 * Mark operation as started (processing)
 */
export async function markOperationStarted(
    idempotencyKey: string,
    operation: string,
    resourceId?: string
): Promise<void> {
  const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + IDEMPOTENCY_TTL_MS)
  );

  const record: IdempotencyRecord = {
    key: idempotencyKey,
    operation,
    resourceId,
    status: "processing",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  };

  await db.collection("idempotency_keys").doc(idempotencyKey).set(record);
}

/**
 * Mark operation as completed with result
 */
export async function markOperationCompleted<T>(
    idempotencyKey: string,
    result: T
): Promise<void> {
  await db.collection("idempotency_keys").doc(idempotencyKey).update({
    status: "completed",
    result,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Mark operation as failed (allows retry)
 */
export async function markOperationFailed(
    idempotencyKey: string,
    error?: string
): Promise<void> {
  await db.collection("idempotency_keys").doc(idempotencyKey).update({
    status: "failed",
    error,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ==================== IDEMPOTENT OPERATION WRAPPER ====================

/**
 * Execute an operation with idempotency protection
 */
export async function executeIdempotent<T>(
    idempotencyKey: string,
    operation: string,
    errorContext: ErrorContext,
    executor: () => Promise<T>
): Promise<T> {
  const logger = createLogger("system", "idempotency").setContext(errorContext);

  // Check for duplicate
  const check = await checkIdempotency<T>(idempotencyKey, operation, errorContext);

  if (check.isDuplicate) {
    logger.info("returning_cached_result", {
      key: idempotencyKey,
      operation,
    });
    return check.previousResult;
  }

  // Mark as started
  await markOperationStarted(idempotencyKey, operation, errorContext.resourceId);

  try {
    // Execute the operation
    const result = await executor();

    // Mark as completed
    await markOperationCompleted(idempotencyKey, result);

    return result;
  } catch (error) {
    // Mark as failed
    await markOperationFailed(
        idempotencyKey,
        error instanceof Error ? error.message : "unknown error"
    );
    throw error;
  }
}

// ==================== WEBHOOK IDEMPOTENCY ====================

/**
 * Generate idempotency key for webhook
 */
export function webhookIdempotencyKey(
    provider: string,
    eventType: string,
    eventId: string
): string {
  return `webhook:${provider}:${eventType}:${eventId}`;
}

/**
 * Check if webhook has already been processed
 */
export async function isWebhookProcessed(
    provider: string,
    eventType: string,
    eventId: string,
    errorContext: ErrorContext
): Promise<boolean> {
  const key = webhookIdempotencyKey(provider, eventType, eventId);
  const check = await checkIdempotency(key, `webhook_${eventType}`, errorContext);
  return check.isDuplicate;
}

/**
 * Mark webhook as processed
 */
export async function markWebhookProcessed(
    provider: string,
    eventType: string,
    eventId: string,
    _errorContext: ErrorContext,
    result?: unknown
): Promise<void> {
  const key = webhookIdempotencyKey(provider, eventType, eventId);
  await markOperationStarted(key, `webhook_${eventType}`);
  await markOperationCompleted(key, result || {processed: true});
}

// ==================== STATE TRANSITION GUARDS ====================

/**
 * Check if a state transition is valid and not a duplicate
 * Returns true if transition should proceed
 */
export function isValidStateTransition(
    currentState: string,
    targetState: string,
    allowedTransitions: Record<string, string[]>
): boolean {
  // Same state = idempotent, allow but skip processing
  if (currentState === targetState) {
    return false; // Signal: already in target state
  }

  const allowed = allowedTransitions[currentState];
  return allowed ? allowed.includes(targetState) : false;
}

/**
 * Generate idempotency key for state transition
 */
export function stateTransitionKey(
    resourceType: string,
    resourceId: string,
    targetState: string
): string {
  return `state:${resourceType}:${resourceId}:to:${targetState}`;
}

// ==================== CLEANUP ====================

/**
 * Clean up expired idempotency keys
 * Should be run periodically (e.g., daily scheduled function)
 */
export async function cleanupExpiredKeys(): Promise<number> {
  const now = admin.firestore.Timestamp.now();

  const expiredDocs = await db
      .collection("idempotency_keys")
      .where("expiresAt", "<", now)
      .limit(500) // Batch limit
      .get();

  if (expiredDocs.empty) {
    return 0;
  }

  const batch = db.batch();
  expiredDocs.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  return expiredDocs.docs.length;
}
