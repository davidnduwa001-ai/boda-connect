/**
 * Rate Limit Metrics Export - READ-ONLY Admin Function
 *
 * Provides aggregated rate limit metrics for admin dashboard.
 * This function NEVER mutates data.
 *
 * Returns:
 * - Total rate-limited users (last 24h)
 * - Actions breakdown (which actions hit limits)
 * - Top offenders (users with most rate limit hits)
 * - Hourly trend data
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  wrapHandler,
  Errors,
  ErrorContext,
} from "../common/errors";
import {createLogger} from "../common/logger";
import {RATE_LIMITS, RateLimitAction} from "../rateLimit/checkRateLimit";

const db = admin.firestore();
const REGION = "us-central1";
const FUNCTION_NAME = "exportRateLimitMetrics";

// ==================== TYPES ====================

interface RateLimitMetricsRequest {
  hoursBack?: number; // Default 24
}

interface ActionBreakdown {
  action: string;
  hitCount: number;
  uniqueUsers: number;
  configuredLimit: number;
  windowSeconds: number;
}

interface TopOffender {
  userId: string;
  totalHits: number;
  actions: string[];
  lastHit: string; // ISO timestamp
}

interface HourlyTrend {
  hour: string; // ISO hour string
  hitCount: number;
}

interface RateLimitMetrics {
  generatedAt: string;
  hoursBack: number;
  totals: {
    uniqueUsersLimited: number;
    totalHits: number;
    activeRateLimits: number;
  };
  actionBreakdown: ActionBreakdown[];
  topOffenders: TopOffender[];
  hourlyTrend: HourlyTrend[];
  configuredLimits: Array<{
    action: string;
    limit: number;
    windowSeconds: number;
    windowDescription: string;
  }>;
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

// ==================== MAIN FUNCTION ====================

export const exportRateLimitMetrics = functions
    .region(REGION)
    .runWith({
      timeoutSeconds: 120,
      memory: "512MB",
    })
    .https.onCall(
        wrapHandler(
            FUNCTION_NAME,
            async (
                data: RateLimitMetricsRequest,
                context: functions.https.CallableContext,
                errorContext: ErrorContext
            ): Promise<RateLimitMetrics> => {
              const logger = createLogger("rate-limit", FUNCTION_NAME);
              logger.setContext(errorContext);

              const hoursBack = Math.min(data.hoursBack || 24, 168); // Max 7 days
              const cutoffTime = new Date(Date.now() - hoursBack * 60 * 60 * 1000);
              const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffTime);

              logger.info("metrics_export_started", {
                requestId: errorContext.requestId,
                hoursBack,
                cutoffTime: cutoffTime.toISOString(),
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
                  action: "export_rate_limit_metrics",
                });
                throw Errors.permissionDenied(
                    errorContext,
                    "Admin access required",
                    "Acesso restrito a administradores"
                );
              }

              // 3. Aggregate metrics
              const actionCounts: Map<string, {hits: number; users: Set<string>}> = new Map();
              const userHits: Map<string, {total: number; actions: Set<string>; lastHit: Date}> =
                new Map();
              const hourlyHits: Map<string, number> = new Map();
              let activeRateLimits = 0;

              // Query all rate_limits documents
              const rateLimitsSnapshot = await db.collection("rate_limits").get();

              for (const userDoc of rateLimitsSnapshot.docs) {
                const userId = userDoc.id;

                // Get actions subcollection
                const actionsSnapshot = await userDoc.ref
                    .collection("actions")
                    .where("lastRequest", ">=", cutoffTimestamp)
                    .get();

                for (const actionDoc of actionsSnapshot.docs) {
                  const actionKey = actionDoc.id;
                  const data = actionDoc.data();
                  const count = data.count || 0;
                  const lastRequest = data.lastRequest?.toDate() || new Date();

                  // Check if this is an active rate limit (hit the limit)
                  const config = RATE_LIMITS[actionKey as RateLimitAction] || RATE_LIMITS.default;
                  if (count >= config.limit) {
                    activeRateLimits++;

                    // Track action breakdown
                    if (!actionCounts.has(actionKey)) {
                      actionCounts.set(actionKey, {hits: 0, users: new Set()});
                    }
                    const actionData = actionCounts.get(actionKey)!;
                    actionData.hits += count;
                    actionData.users.add(userId);

                    // Track user hits
                    if (!userHits.has(userId)) {
                      userHits.set(userId, {total: 0, actions: new Set(), lastHit: lastRequest});
                    }
                    const userData = userHits.get(userId)!;
                    userData.total += count;
                    userData.actions.add(actionKey);
                    if (lastRequest > userData.lastHit) {
                      userData.lastHit = lastRequest;
                    }

                    // Track hourly trend
                    const hourKey = lastRequest.toISOString().substring(0, 13) + ":00:00.000Z";
                    hourlyHits.set(hourKey, (hourlyHits.get(hourKey) || 0) + 1);
                  }
                }
              }

              // Build action breakdown
              const actionBreakdown: ActionBreakdown[] = Array.from(actionCounts.entries())
                  .map(([action, data]) => {
                    const config = RATE_LIMITS[action as RateLimitAction] || RATE_LIMITS.default;
                    return {
                      action,
                      hitCount: data.hits,
                      uniqueUsers: data.users.size,
                      configuredLimit: config.limit,
                      windowSeconds: config.windowSeconds,
                    };
                  })
                  .sort((a, b) => b.hitCount - a.hitCount);

              // Build top offenders (limit to 10)
              const topOffenders: TopOffender[] = Array.from(userHits.entries())
                  .map(([userId, data]) => ({
                    userId,
                    totalHits: data.total,
                    actions: Array.from(data.actions),
                    lastHit: data.lastHit.toISOString(),
                  }))
                  .sort((a, b) => b.totalHits - a.totalHits)
                  .slice(0, 10);

              // Build hourly trend (last 24 hours)
              const hourlyTrend: HourlyTrend[] = Array.from(hourlyHits.entries())
                  .map(([hour, count]) => ({hour, hitCount: count}))
                  .sort((a, b) => a.hour.localeCompare(b.hour));

              // Build configured limits reference
              const configuredLimits = Object.entries(RATE_LIMITS).map(([action, config]) => ({
                action,
                limit: config.limit,
                windowSeconds: config.windowSeconds,
                windowDescription: formatWindowDescription(config.windowSeconds),
              }));

              const metrics: RateLimitMetrics = {
                generatedAt: new Date().toISOString(),
                hoursBack,
                totals: {
                  uniqueUsersLimited: userHits.size,
                  totalHits: Array.from(userHits.values()).reduce((sum, u) => sum + u.total, 0),
                  activeRateLimits,
                },
                actionBreakdown,
                topOffenders,
                hourlyTrend,
                configuredLimits,
              };

              logger.info("metrics_export_completed", {
                requestId: errorContext.requestId,
                uniqueUsersLimited: metrics.totals.uniqueUsersLimited,
                totalHits: metrics.totals.totalHits,
                activeRateLimits: metrics.totals.activeRateLimits,
                actionCount: actionBreakdown.length,
              });

              return metrics;
            }
        )
    );

// ==================== HELPERS ====================

function formatWindowDescription(seconds: number): string {
  if (seconds < 60) return `${seconds} segundos`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)} minutos`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)} hora(s)`;
  return `${Math.floor(seconds / 86400)} dia(s)`;
}
