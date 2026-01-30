import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore();

/**
 * Rate limit configuration for different actions
 */
export const RATE_LIMITS = {
  // Booking operations
  createBooking: {limit: 10, windowSeconds: 3600}, // 10 per hour
  // Payment operations
  createPaymentIntent: {limit: 20, windowSeconds: 3600}, // 20 per hour
  confirmPayment: {limit: 30, windowSeconds: 3600}, // 30 per hour
  // Review operations
  createReview: {limit: 10, windowSeconds: 86400}, // 10 per day
  // Message operations
  sendMessage: {limit: 100, windowSeconds: 3600}, // 100 per hour
  // Support operations
  createSupportTicket: {limit: 5, windowSeconds: 3600}, // 5 per hour
  // Admin operations (stricter)
  adminBroadcast: {limit: 10, windowSeconds: 86400}, // 10 per day
  // General fallback
  default: {limit: 60, windowSeconds: 3600}, // 60 per hour
} as const;

export type RateLimitAction = keyof typeof RATE_LIMITS;

interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
  retryAfterSeconds?: number;
}

interface RateLimitRecord {
  count: number;
  windowStart: admin.firestore.Timestamp;
  lastRequest: admin.firestore.Timestamp;
  expiresAt?: admin.firestore.Timestamp;
}

/**
 * Check if an action is rate limited for a user
 *
 * Uses a sliding window approach with Firestore transactions
 * for concurrency safety.
 *
 * @param uid - User ID
 * @param actionKey - The action being rate limited
 * @param customLimit - Optional custom limit (overrides default)
 * @param customWindowSeconds - Optional custom window (overrides default)
 * @returns Rate limit result
 */
export async function checkRateLimitForKey(
    scopeKey: string,
    actionKey: RateLimitAction | string,
    customLimit?: number,
    customWindowSeconds?: number
): Promise<RateLimitResult> {
  // Get rate limit config
  const config = RATE_LIMITS[actionKey as RateLimitAction] || RATE_LIMITS.default;
  const limit = customLimit ?? config.limit;
  const windowSeconds = customWindowSeconds ?? config.windowSeconds;

  const rateLimitRef = db
      .collection("rate_limits")
      .doc(scopeKey)
      .collection("actions")
      .doc(actionKey);

  const now = admin.firestore.Timestamp.now();
  const windowStart = new Date(now.toDate().getTime() - windowSeconds * 1000);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);

      let currentCount = 0;
      let recordWindowStart = now;

      if (doc.exists) {
        const data = doc.data() as RateLimitRecord;

        // Check if we're still in the same window
        if (data.windowStart.toDate() > windowStart) {
          // Same window - use existing count
          currentCount = data.count;
          recordWindowStart = data.windowStart;
        }
        // If window has passed, we start fresh (count = 0)
      }

      // Calculate reset time
      const resetAt = new Date(
          recordWindowStart.toDate().getTime() + windowSeconds * 1000
      );
      const expiresAt = admin.firestore.Timestamp.fromDate(resetAt);

      // Check if limit exceeded
      if (currentCount >= limit) {
        const retryAfterSeconds = Math.ceil(
            (resetAt.getTime() - now.toDate().getTime()) / 1000
        );

        return {
          allowed: false,
          remaining: 0,
          resetAt,
          retryAfterSeconds: Math.max(1, retryAfterSeconds),
        };
      }

      // Increment counter
      const newCount = currentCount + 1;
      const remaining = limit - newCount;

      // Update or create the rate limit record
      if (currentCount === 0) {
        // New window - reset
        transaction.set(rateLimitRef, {
          count: 1,
          windowStart: now,
          lastRequest: now,
          expiresAt,
        });
      } else {
        // Same window - increment
        transaction.update(rateLimitRef, {
          count: admin.firestore.FieldValue.increment(1),
          lastRequest: now,
          expiresAt,
        });
      }

      return {
        allowed: true,
        remaining,
        resetAt,
      };
    });

    return result;
  } catch (error) {
    console.error(`Rate limit check failed for ${scopeKey}/${actionKey}:`, error);
    // On error, allow the request but log it
    // This prevents rate limiting from blocking legitimate users
    // due to transient Firestore errors
    return {
      allowed: true,
      remaining: limit,
      resetAt: new Date(Date.now() + windowSeconds * 1000),
    };
  }
}

export async function checkRateLimit(
    uid: string,
    actionKey: RateLimitAction | string,
    customLimit?: number,
    customWindowSeconds?: number
): Promise<RateLimitResult> {
  return checkRateLimitForKey(uid, actionKey, customLimit, customWindowSeconds);
}

/**
 * Enforce rate limit - throws HttpsError if exceeded
 *
 * Use this in Cloud Functions to enforce rate limits
 *
 * @param uid - User ID
 * @param actionKey - The action being rate limited
 * @param customLimit - Optional custom limit
 * @param customWindowSeconds - Optional custom window
 * @throws functions.https.HttpsError if rate limited
 */
export async function enforceRateLimit(
    uid: string,
    actionKey: RateLimitAction | string,
    customLimit?: number,
    customWindowSeconds?: number
): Promise<void> {
  const result = await checkRateLimit(
      uid,
      actionKey,
      customLimit,
      customWindowSeconds
  );

  if (!result.allowed) {
    console.warn(
        `Rate limit exceeded: ${uid}/${actionKey} - retry after ${result.retryAfterSeconds}s`
    );

    throw new functions.https.HttpsError(
        "resource-exhausted",
        `Limite de requisições excedido. Tente novamente em ${result.retryAfterSeconds} segundos.`,
        {
          retryAfterSeconds: result.retryAfterSeconds,
          resetAt: result.resetAt.toISOString(),
        }
    );
  }
}

/**
 * Get current rate limit status for a user/action
 * (without incrementing the counter)
 *
 * @param uid - User ID
 * @param actionKey - The action to check
 * @returns Current rate limit status
 */
export async function getRateLimitStatus(
    uid: string,
    actionKey: RateLimitAction | string
): Promise<{
  count: number;
  limit: number;
  remaining: number;
  windowSeconds: number;
  resetAt: Date | null;
}> {
  const config = RATE_LIMITS[actionKey as RateLimitAction] || RATE_LIMITS.default;
  const {limit, windowSeconds} = config;

  const rateLimitRef = db
      .collection("rate_limits")
      .doc(uid)
      .collection("actions")
      .doc(actionKey);

  const doc = await rateLimitRef.get();

  if (!doc.exists) {
    return {
      count: 0,
      limit,
      remaining: limit,
      windowSeconds,
      resetAt: null,
    };
  }

  const data = doc.data() as RateLimitRecord;
  const now = new Date();
  const windowStart = new Date(now.getTime() - windowSeconds * 1000);

  // Check if window has expired
  if (data.windowStart.toDate() <= windowStart) {
    return {
      count: 0,
      limit,
      remaining: limit,
      windowSeconds,
      resetAt: null,
    };
  }

  const resetAt = new Date(
      data.windowStart.toDate().getTime() + windowSeconds * 1000
  );

  return {
    count: data.count,
    limit,
    remaining: Math.max(0, limit - data.count),
    windowSeconds,
    resetAt,
  };
}

/**
 * Reset rate limit for a user/action
 * (Admin use only)
 *
 * @param uid - User ID
 * @param actionKey - The action to reset
 */
export async function resetRateLimit(
    uid: string,
    actionKey: RateLimitAction | string
): Promise<void> {
  const rateLimitRef = db
      .collection("rate_limits")
      .doc(uid)
      .collection("actions")
      .doc(actionKey);

  await rateLimitRef.delete();
  console.log(`Rate limit reset: ${uid}/${actionKey}`);
}

/**
 * Clean up expired rate limit records
 * (Run periodically via scheduled function)
 *
 * @param olderThanHours - Delete records older than this many hours
 */
export async function cleanupExpiredRateLimits(
    olderThanHours = 24
): Promise<number> {
  const cutoff = new Date(Date.now() - olderThanHours * 60 * 60 * 1000);
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoff);

  let deletedCount = 0;

  // Get all user rate limit documents
  const usersSnapshot = await db.collection("rate_limits").get();

  for (const userDoc of usersSnapshot.docs) {
    const actionsSnapshot = await userDoc.ref
        .collection("actions")
        .where("lastRequest", "<", cutoffTimestamp)
        .get();

    const batch = db.batch();
    actionsSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    if (actionsSnapshot.docs.length > 0) {
      await batch.commit();
    }
  }

  console.log(`Cleaned up ${deletedCount} expired rate limit records`);
  return deletedCount;
}
