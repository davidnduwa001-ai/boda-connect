/**
 * Structured Logging - Production Safeguards
 *
 * This module provides:
 * - Structured log entries for monitoring/alerting
 * - State transition logging
 * - Correlation IDs for multi-step flows
 * - Sensitive data redaction
 */

import {ErrorContext} from "./errors";

// ==================== LOG LEVELS ====================

export type LogLevel = "debug" | "info" | "warn" | "error";

// ==================== LOG CATEGORIES ====================

export type LogCategory =
  | "payment"
  | "booking"
  | "review"
  | "escrow"
  | "auth"
  | "rate-limit"
  | "webhook"
  | "notification"
  | "security"
  | "supplier"
  | "system";

// ==================== LOG ENTRY ====================

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  category: LogCategory;
  event: string;
  requestId?: string;
  correlationId?: string;
  functionName?: string;
  uid?: string;
  resourceId?: string;
  resourceType?: string;
  data?: Record<string, unknown>;
  duration?: number;
  error?: {
    code?: string;
    message: string;
  };
}

// ==================== SENSITIVE DATA REDACTION ====================

/**
 * Fields that should be redacted from logs
 */
const SENSITIVE_FIELDS = [
  "password",
  "token",
  "apiKey",
  "secret",
  "authorization",
  "phone",
  "email",
  "cpf",
  "nif",
  "cardNumber",
  "cvv",
  "pin",
];

/**
 * Redact sensitive fields from an object
 */
function redactSensitive(obj: Record<string, unknown>): Record<string, unknown> {
  const redacted: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase();

    // Check if field is sensitive
    const isSensitive = SENSITIVE_FIELDS.some((field) =>
      lowerKey.includes(field.toLowerCase())
    );

    if (isSensitive) {
      redacted[key] = "[REDACTED]";
    } else if (value && typeof value === "object" && !Array.isArray(value)) {
      redacted[key] = redactSensitive(value as Record<string, unknown>);
    } else {
      redacted[key] = value;
    }
  }

  return redacted;
}

// ==================== LOGGER CLASS ====================

/**
 * Structured logger with correlation support
 */
export class Logger {
  private readonly category: LogCategory;
  private readonly functionName: string;
  private correlationId?: string;
  private requestId?: string;
  private uid?: string;
  private startTime?: number;

  constructor(category: LogCategory, functionName: string) {
    this.category = category;
    this.functionName = functionName;
  }

  /**
   * Set context from ErrorContext
   */
  setContext(ctx: ErrorContext): Logger {
    this.requestId = ctx.requestId;
    this.uid = ctx.uid;
    return this;
  }

  /**
   * Set correlation ID for multi-step flows
   */
  setCorrelationId(id: string): Logger {
    this.correlationId = id;
    return this;
  }

  /**
   * Start timing for duration measurement
   */
  startTimer(): Logger {
    this.startTime = Date.now();
    return this;
  }

  /**
   * Create a log entry
   */
  private createEntry(
      level: LogLevel,
      event: string,
      data?: Record<string, unknown>,
      error?: {code?: string; message: string}
  ): LogEntry {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      category: this.category,
      event,
      functionName: this.functionName,
    };

    if (this.requestId) entry.requestId = this.requestId;
    if (this.correlationId) entry.correlationId = this.correlationId;
    if (this.uid) entry.uid = this.uid;
    if (data) entry.data = redactSensitive(data);
    if (error) entry.error = error;

    if (this.startTime) {
      entry.duration = Date.now() - this.startTime;
    }

    return entry;
  }

  /**
   * Output log entry
   */
  private output(entry: LogEntry): void {
    const prefix = `[${entry.category.toUpperCase()}]`;
    const requestInfo = entry.requestId ? `[${entry.requestId}]` : "";
    const correlationInfo = entry.correlationId ? `[corr:${entry.correlationId}]` : "";

    const logLine = `${prefix}${requestInfo}${correlationInfo} ${entry.event}`;

    switch (entry.level) {
      case "debug":
        console.debug(logLine, JSON.stringify(entry));
        break;
      case "info":
        console.info(logLine, JSON.stringify(entry));
        break;
      case "warn":
        console.warn(logLine, JSON.stringify(entry));
        break;
      case "error":
        console.error(logLine, JSON.stringify(entry));
        break;
    }
  }

  // ==================== LOG METHODS ====================

  debug(event: string, data?: Record<string, unknown>): void {
    this.output(this.createEntry("debug", event, data));
  }

  info(event: string, data?: Record<string, unknown>): void {
    this.output(this.createEntry("info", event, data));
  }

  warn(event: string, data?: Record<string, unknown>): void {
    this.output(this.createEntry("warn", event, data));
  }

  error(event: string, error: Error | string, data?: Record<string, unknown>): void {
    const errorObj = typeof error === "string"
      ? {message: error}
      : {code: error.name, message: error.message};

    this.output(this.createEntry("error", event, data, errorObj));
  }

  // ==================== SPECIALIZED LOG METHODS ====================

  /**
   * Log a state transition
   */
  stateTransition(
      resourceType: string,
      resourceId: string,
      fromState: string,
      toState: string,
      triggeredBy?: string
  ): void {
    this.info("state_transition", {
      resourceType,
      resourceId,
      fromState,
      toState,
      triggeredBy,
    });
  }

  /**
   * Log operation start
   */
  operationStart(operation: string, data?: Record<string, unknown>): void {
    this.startTimer();
    this.info(`${operation}_started`, data);
  }

  /**
   * Log operation success
   */
  operationSuccess(operation: string, data?: Record<string, unknown>): void {
    this.info(`${operation}_completed`, {
      ...data,
      durationMs: this.startTime ? Date.now() - this.startTime : undefined,
    });
  }

  /**
   * Log operation failure
   */
  operationFailed(operation: string, error: Error | string, data?: Record<string, unknown>): void {
    this.error(`${operation}_failed`, error, {
      ...data,
      durationMs: this.startTime ? Date.now() - this.startTime : undefined,
    });
  }

  /**
   * Log idempotent skip (duplicate request)
   */
  idempotentSkip(operation: string, resourceId: string, reason: string): void {
    this.info("idempotent_skip", {
      operation,
      resourceId,
      reason,
    });
  }

  /**
   * Log rate limit hit
   */
  rateLimitHit(userId: string, operation: string, limit: number): void {
    this.warn("rate_limit_exceeded", {
      userId,
      operation,
      limit,
    });
  }

  /**
   * Log kill-switch activation
   */
  killSwitchActive(feature: string): void {
    this.warn("kill_switch_active", {
      feature,
      action: "operation_blocked",
    });
  }
}

// ==================== LOGGER FACTORY ====================

/**
 * Create a logger for a specific category and function
 */
export function createLogger(category: LogCategory, functionName: string): Logger {
  return new Logger(category, functionName);
}

// ==================== CONVENIENCE LOGGERS ====================

export const PaymentLogger = (fn: string) => createLogger("payment", fn);
export const BookingLogger = (fn: string) => createLogger("booking", fn);
export const ReviewLogger = (fn: string) => createLogger("review", fn);
export const EscrowLogger = (fn: string) => createLogger("escrow", fn);
export const AuthLogger = (fn: string) => createLogger("auth", fn);
export const RateLimitLogger = (fn: string) => createLogger("rate-limit", fn);
export const WebhookLogger = (fn: string) => createLogger("webhook", fn);
export const SecurityLogger = (fn: string) => createLogger("security", fn);
export const SupplierLogger = (fn: string) => createLogger("supplier", fn);
