/**
 * Common Utilities - Production Safeguards
 *
 * This module exports all common utilities for Cloud Functions:
 * - Centralized error handling
 * - Structured logging
 * - Kill-switches
 * - Idempotency guards
 */

// Error handling
export {
  AppError,
  AppErrorCode,
  ErrorContext,
  Errors,
  createErrorContext,
  generateRequestId,
  toSafeHttpsError,
  wrapHandler,
} from "./errors";

// Structured logging
export {
  Logger,
  LogCategory,
  LogLevel,
  createLogger,
  PaymentLogger,
  BookingLogger,
  ReviewLogger,
  EscrowLogger,
  AuthLogger,
  RateLimitLogger,
  WebhookLogger,
  SecurityLogger,
} from "./logger";

// Kill-switches
export {
  FeatureFlag,
  isFeatureEnabled,
  requireFeatureEnabled,
  withFeatureFlag,
  clearFeatureFlagsCache,
  setFeatureFlag,
  getAllFeatureFlags,
} from "./killSwitch";

// Idempotency
export {
  checkIdempotency,
  markOperationStarted,
  markOperationCompleted,
  markOperationFailed,
  executeIdempotent,
  webhookIdempotencyKey,
  isWebhookProcessed,
  markWebhookProcessed,
  isValidStateTransition,
  stateTransitionKey,
  cleanupExpiredKeys,
} from "./idempotency";
