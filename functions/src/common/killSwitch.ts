/**
 * Kill-Switches - Production Safeguards
 *
 * This module provides:
 * - Config-based feature flags
 * - Graceful degradation without code redeploy
 * - Clear error messages when features are disabled
 *
 * Configuration:
 * Use environment variables:
 *   FEATURE_PAYMENTS_ENABLED=false
 *   FEATURE_BOOKINGS_ENABLED=false
 *
 * Or via Firestore (real-time updates):
 *   /settings/features document
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {ErrorContext, AppError} from "./errors";
import {createLogger} from "./logger";

const db = admin.firestore();
const logger = createLogger("system", "killSwitch");

// ==================== FEATURE FLAGS ====================

/**
 * Available feature flags
 */
export type FeatureFlag =
  | "payments"
  | "bookings"
  | "reviews"
  | "escrow"
  | "escrow_auto_release"
  | "notifications"
  | "webhooks";

/**
 * User-friendly messages when features are disabled
 */
const DISABLED_MESSAGES: Record<FeatureFlag, string> = {
  payments: "Pagamentos temporariamente indisponíveis. Tente novamente mais tarde.",
  bookings: "Sistema de reservas temporariamente indisponível. Tente novamente mais tarde.",
  reviews: "Avaliações temporariamente indisponíveis. Tente novamente mais tarde.",
  escrow: "Sistema de pagamentos temporariamente indisponível. Tente novamente mais tarde.",
  escrow_auto_release: "Liberação automática temporariamente suspensa. Aguarde processamento manual.",
  notifications: "Notificações temporariamente indisponíveis.",
  webhooks: "Processamento de webhooks temporariamente suspenso.",
};

// ==================== CONFIG CACHE ====================

/**
 * In-memory cache for feature flags (to avoid repeated Firestore reads)
 */
let featureFlagsCache: Record<FeatureFlag, boolean> | null = null;
let cacheTimestamp = 0;
const CACHE_TTL_MS = 60000; // 1 minute cache

/**
 * Load feature flags from configuration sources
 * Priority: Firestore > Functions config > defaults (all enabled)
 */
async function loadFeatureFlags(): Promise<Record<FeatureFlag, boolean>> {
  // Check cache
  if (featureFlagsCache && Date.now() - cacheTimestamp < CACHE_TTL_MS) {
    return featureFlagsCache;
  }

  // Default: all features enabled
  const flags: Record<FeatureFlag, boolean> = {
    payments: true,
    bookings: true,
    reviews: true,
    escrow: true,
    escrow_auto_release: true,
    notifications: true,
    webhooks: true,
  };

  try {
    // Try Firestore first (allows real-time updates)
    const featuresDoc = await db.collection("settings").doc("features").get();

    if (featuresDoc.exists) {
      const data = featuresDoc.data()!;

      // Override with Firestore values
      for (const key of Object.keys(flags) as FeatureFlag[]) {
        const firestoreKey = `${key}_enabled`;
        if (typeof data[firestoreKey] === "boolean") {
          flags[key] = data[firestoreKey];
        }
      }

      logger.debug("feature_flags_loaded_from_firestore", {flags});
    }
  } catch (error) {
    // Firestore failed, try Functions config
    logger.warn("firestore_config_failed", {
      error: error instanceof Error ? error.message : "unknown",
    });
  }

  // Override with environment variables (for v2 functions compatibility)
  // Note: functions.config() is deprecated, using env vars instead
  try {
    for (const key of Object.keys(flags) as FeatureFlag[]) {
      const envKey = `FEATURE_${key.toUpperCase()}_ENABLED`;
      const envValue = process.env[envKey];

      if (envValue !== undefined) {
        flags[key] = envValue === "true" || envValue === "1";
      }
    }
  } catch (configError) {
    // Environment config not available
    console.debug("env_config_not_available", configError);
  }

  // Update cache
  featureFlagsCache = flags;
  cacheTimestamp = Date.now();

  return flags;
}

// ==================== PUBLIC API ====================

/**
 * Check if a feature is enabled
 */
export async function isFeatureEnabled(feature: FeatureFlag): Promise<boolean> {
  const flags = await loadFeatureFlags();
  return flags[feature];
}

/**
 * Require a feature to be enabled, throw if not
 * Use this at the start of Cloud Functions
 */
export async function requireFeatureEnabled(
    feature: FeatureFlag,
    errorContext: ErrorContext
): Promise<void> {
  const enabled = await isFeatureEnabled(feature);

  if (!enabled) {
    logger.setContext(errorContext).killSwitchActive(feature);

    throw new AppError(
        "unavailable",
        errorContext,
        `Feature disabled: ${feature}`,
        DISABLED_MESSAGES[feature]
    );
  }
}

/**
 * Guard function - wraps a handler with feature flag check
 */
export function withFeatureFlag<T, R>(
    feature: FeatureFlag,
    handler: (data: T, context: functions.https.CallableContext, errorContext: ErrorContext) => Promise<R>
): (data: T, context: functions.https.CallableContext, errorContext: ErrorContext) => Promise<R> {
  return async (data, context, errorContext) => {
    await requireFeatureEnabled(feature, errorContext);
    return handler(data, context, errorContext);
  };
}

/**
 * Clear the feature flags cache (for testing or manual refresh)
 */
export function clearFeatureFlagsCache(): void {
  featureFlagsCache = null;
  cacheTimestamp = 0;
}

// ==================== ADMIN FUNCTIONS ====================

/**
 * Set a feature flag (admin only)
 * This updates Firestore for real-time propagation
 */
export async function setFeatureFlag(
    feature: FeatureFlag,
    enabled: boolean,
    reason?: string
): Promise<void> {
  const firestoreKey = `${feature}_enabled`;

  await db.collection("settings").doc("features").set({
    [firestoreKey]: enabled,
    [`${feature}_updated_at`]: admin.firestore.FieldValue.serverTimestamp(),
    [`${feature}_reason`]: reason || null,
  }, {merge: true});

  // Clear cache to force reload
  clearFeatureFlagsCache();

  // Log the change
  logger.info("feature_flag_changed", {
    feature,
    enabled,
    reason,
  });

  // Create audit log
  await db.collection("audit_logs").add({
    category: "system",
    eventType: "featureFlagChanged",
    feature,
    previousValue: !enabled, // Approximate
    newValue: enabled,
    reason,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Get all feature flags status (for admin dashboard)
 */
export async function getAllFeatureFlags(): Promise<Record<FeatureFlag, {
  enabled: boolean;
  updatedAt?: Date;
  reason?: string;
}>> {
  const flags = await loadFeatureFlags();
  const result: Record<FeatureFlag, {enabled: boolean; updatedAt?: Date; reason?: string}> = {} as any;

  // Get additional metadata from Firestore
  try {
    const featuresDoc = await db.collection("settings").doc("features").get();
    const data = featuresDoc.exists ? featuresDoc.data()! : {};

    for (const key of Object.keys(flags) as FeatureFlag[]) {
      result[key] = {
        enabled: flags[key],
        updatedAt: data[`${key}_updated_at`]?.toDate(),
        reason: data[`${key}_reason`],
      };
    }
  } catch {
    // Firestore unavailable, return basic info
    for (const key of Object.keys(flags) as FeatureFlag[]) {
      result[key] = {enabled: flags[key]};
    }
  }

  return result;
}
