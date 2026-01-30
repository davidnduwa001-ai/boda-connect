/**
 * Centralized Error Handling - Production Safeguards
 *
 * This module provides:
 * - Normalized error codes for consistent client handling
 * - Error context enrichment (requestId, uid, functionName)
 * - Safe error messages (no stack traces leak to clients)
 * - Error classification for monitoring
 */

import * as functions from "firebase-functions/v1";
import {v4 as uuidv4} from "uuid";

// ==================== ERROR CODES ====================

/**
 * Standardized error codes mapped to Firebase HttpsError codes
 */
export type AppErrorCode =
  | "unauthenticated"      // Not logged in
  | "permission-denied"    // Logged in but not authorized
  | "not-found"            // Resource doesn't exist
  | "already-exists"       // Duplicate resource
  | "invalid-argument"     // Bad input data
  | "failed-precondition"  // State doesn't allow operation
  | "resource-exhausted"   // Rate limit / quota exceeded
  | "unavailable"          // Service temporarily unavailable
  | "internal";            // Unexpected server error

/**
 * User-friendly error messages (Portuguese)
 * These are safe to show to end users
 */
const USER_MESSAGES: Record<AppErrorCode, string> = {
  "unauthenticated": "Você precisa estar autenticado",
  "permission-denied": "Você não tem permissão para esta ação",
  "not-found": "Recurso não encontrado",
  "already-exists": "Este recurso já existe",
  "invalid-argument": "Dados inválidos",
  "failed-precondition": "Operação não permitida no estado atual",
  "resource-exhausted": "Muitas tentativas. Tente novamente mais tarde",
  "unavailable": "Serviço temporariamente indisponível",
  "internal": "Erro interno. Tente novamente",
};

// ==================== ERROR CONTEXT ====================

/**
 * Error context for logging and debugging
 */
export interface ErrorContext {
  requestId: string;
  functionName: string;
  uid?: string;
  resourceId?: string;
  resourceType?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Generate a unique request ID for correlation
 */
export function generateRequestId(): string {
  return uuidv4().substring(0, 8);
}

/**
 * Create error context from Cloud Function context
 */
export function createErrorContext(
    functionName: string,
    context: functions.https.CallableContext,
    resourceId?: string,
    resourceType?: string
): ErrorContext {
  return {
    requestId: generateRequestId(),
    functionName,
    uid: context.auth?.uid,
    resourceId,
    resourceType,
  };
}

// ==================== APP ERROR CLASS ====================

/**
 * Application error with context and safe messaging
 */
export class AppError extends Error {
  public readonly code: AppErrorCode;
  public readonly context: ErrorContext;
  public readonly userMessage: string;
  public readonly internalMessage: string;
  public readonly originalError?: Error;

  constructor(
      code: AppErrorCode,
      context: ErrorContext,
      internalMessage: string,
      userMessage?: string,
      originalError?: Error
  ) {
    super(internalMessage);
    this.name = "AppError";
    this.code = code;
    this.context = context;
    this.internalMessage = internalMessage;
    this.userMessage = userMessage || USER_MESSAGES[code];
    this.originalError = originalError;
  }

  /**
   * Convert to Firebase HttpsError (safe for client)
   */
  toHttpsError(): functions.https.HttpsError {
    // NEVER include stack traces or internal details
    return new functions.https.HttpsError(
        this.code,
        this.userMessage,
        {
          requestId: this.context.requestId,
          code: this.code,
        }
    );
  }

  /**
   * Get log-safe representation (for structured logging)
   */
  toLogObject(): Record<string, unknown> {
    return {
      errorType: "AppError",
      code: this.code,
      message: this.internalMessage,
      context: this.context,
      // Include original error info but NOT full stack
      originalError: this.originalError ? {
        name: this.originalError.name,
        message: this.originalError.message,
      } : undefined,
    };
  }
}

// ==================== ERROR FACTORY ====================

/**
 * Create standard errors with proper context
 */
export const Errors = {
  unauthenticated: (ctx: ErrorContext, message?: string) =>
    new AppError("unauthenticated", ctx, message || "User not authenticated"),

  permissionDenied: (ctx: ErrorContext, message?: string, userMessage?: string) =>
    new AppError("permission-denied", ctx, message || "Permission denied", userMessage),

  notFound: (ctx: ErrorContext, resourceType: string, resourceId?: string) =>
    new AppError(
        "not-found",
        {...ctx, resourceType, resourceId},
        `${resourceType} not found: ${resourceId || "unknown"}`,
        `${resourceType} não encontrado`
    ),

  alreadyExists: (ctx: ErrorContext, resourceType: string, message?: string) =>
    new AppError(
        "already-exists",
        {...ctx, resourceType},
        message || `${resourceType} already exists`,
        `${resourceType} já existe`
    ),

  invalidArgument: (ctx: ErrorContext, field: string, reason?: string) =>
    new AppError(
        "invalid-argument",
        {...ctx, metadata: {field, reason}},
        `Invalid argument: ${field}${reason ? ` - ${reason}` : ""}`,
        `Campo inválido: ${field}`
    ),

  failedPrecondition: (ctx: ErrorContext, message: string, userMessage?: string) =>
    new AppError("failed-precondition", ctx, message, userMessage),

  rateLimitExceeded: (ctx: ErrorContext, operation: string) =>
    new AppError(
        "resource-exhausted",
        {...ctx, metadata: {operation}},
        `Rate limit exceeded for operation: ${operation}`,
        "Muitas tentativas. Aguarde alguns minutos"
    ),

  serviceUnavailable: (ctx: ErrorContext, service: string, userMessage?: string) =>
    new AppError(
        "unavailable",
        {...ctx, metadata: {service}},
        `Service unavailable: ${service}`,
        userMessage || "Serviço temporariamente indisponível"
    ),

  unavailable: (ctx: ErrorContext, internalMessage: string, userMessage?: string) =>
    new AppError(
        "unavailable",
        ctx,
        internalMessage,
        userMessage || "Serviço temporariamente indisponível"
    ),

  internal: (ctx: ErrorContext, message: string, originalError?: Error) =>
    new AppError(
        "internal",
        ctx,
        message,
        "Erro interno. Tente novamente",
        originalError
    ),
};

// ==================== ERROR WRAPPER ====================

/**
 * Wrap a Cloud Function handler with error handling
 * Ensures all errors are properly normalized and logged
 */
export function wrapHandler<T, R>(
    functionName: string,
    handler: (
      data: T,
      context: functions.https.CallableContext,
      errorContext: ErrorContext
    ) => Promise<R>
): (data: T, context: functions.https.CallableContext) => Promise<R> {
  return async (data: T, context: functions.https.CallableContext): Promise<R> => {
    const errorContext = createErrorContext(functionName, context);

    try {
      return await handler(data, context, errorContext);
    } catch (error) {
      // If already an AppError, convert and throw
      if (error instanceof AppError) {
        console.error(`[${errorContext.requestId}] AppError in ${functionName}:`, error.toLogObject());
        throw error.toHttpsError();
      }

      // If already a Firebase HttpsError, preserve it
      if (error instanceof functions.https.HttpsError) {
        console.error(`[${errorContext.requestId}] HttpsError in ${functionName}:`, {
          code: error.code,
          message: error.message,
        });
        throw error;
      }

      // Unknown error - wrap as internal
      const unknownError = error instanceof Error ? error : new Error(String(error));
      const appError = Errors.internal(errorContext, unknownError.message, unknownError);

      console.error(`[${errorContext.requestId}] Unexpected error in ${functionName}:`, {
        error: unknownError.message,
        stack: unknownError.stack, // Log stack server-side only
      });

      throw appError.toHttpsError();
    }
  };
}

// ==================== SAFE ERROR CONVERSION ====================

/**
 * Convert any error to a safe HttpsError
 * Use this when you catch errors and need to rethrow
 */
export function toSafeHttpsError(
    error: unknown,
    context: ErrorContext,
    defaultMessage = "Erro interno. Tente novamente"
): functions.https.HttpsError {
  if (error instanceof AppError) {
    return error.toHttpsError();
  }

  if (error instanceof functions.https.HttpsError) {
    return error;
  }

  // Log the real error server-side
  const realError = error instanceof Error ? error : new Error(String(error));
  console.error(`[${context.requestId}] Converting error to safe HttpsError:`, {
    functionName: context.functionName,
    error: realError.message,
  });

  // Return safe error to client
  return new functions.https.HttpsError(
      "internal",
      defaultMessage,
      {requestId: context.requestId}
  );
}

// ==================== HTTP HANDLER WRAPPER ====================

/**
 * Create error context for HTTP requests (non-callable functions)
 */
export function createHttpErrorContext(
    functionName: string,
    req: functions.https.Request
): ErrorContext {
  return {
    requestId: generateRequestId(),
    functionName,
    // Try to extract user info from headers if available
    uid: req.headers["x-user-id"] as string | undefined,
  };
}

/**
 * Wrap an HTTP handler (onRequest) with error handling
 * Used for webhooks and other HTTP endpoints
 */
export function wrapHttpHandler(
    functionName: string,
    handler: (
      req: functions.https.Request,
      res: functions.Response,
      errorContext: ErrorContext
    ) => Promise<void>
): (req: functions.https.Request, res: functions.Response) => Promise<void> {
  return async (req: functions.https.Request, res: functions.Response): Promise<void> => {
    const errorContext = createHttpErrorContext(functionName, req);

    try {
      await handler(req, res, errorContext);
    } catch (error) {
      // Log the error
      console.error(`[${errorContext.requestId}] Error in ${functionName}:`, {
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });

      // Send error response if not already sent
      if (!res.headersSent) {
        if (error instanceof AppError) {
          res.status(getHttpStatusForCode(error.code)).json({
            error: error.userMessage,
            requestId: errorContext.requestId,
            code: error.code,
          });
        } else {
          res.status(500).json({
            error: "Internal server error",
            requestId: errorContext.requestId,
          });
        }
      }
    }
  };
}

/**
 * Map AppErrorCode to HTTP status code
 */
function getHttpStatusForCode(code: AppErrorCode): number {
  switch (code) {
  case "unauthenticated":
    return 401;
  case "permission-denied":
    return 403;
  case "not-found":
    return 404;
  case "already-exists":
    return 409;
  case "invalid-argument":
    return 400;
  case "failed-precondition":
    return 412;
  case "resource-exhausted":
    return 429;
  case "unavailable":
    return 503;
  case "internal":
  default:
    return 500;
  }
}
