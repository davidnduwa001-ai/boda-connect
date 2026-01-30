/**
 * Booking State Machine - Server-Side Authority
 *
 * This file defines the authoritative state machine for booking status transitions.
 * ALL status changes MUST go through this validation.
 *
 * State Diagram:
 * pending → confirmed → completed
 *    ↓         ↓
 * cancelled  cancelled
 *    ↓
 * expired (auto after 7 days)
 *
 * Terminal states: cancelled, completed, expired
 */

export type BookingStatus =
  | "pending"
  | "confirmed"
  | "completed"
  | "cancelled"
  | "expired";

/**
 * Allowed status transitions (AUTHORITATIVE)
 *
 * This is the single source of truth for booking state transitions.
 * The client MUST NOT define or validate transitions locally.
 */
const ALLOWED_TRANSITIONS: Record<BookingStatus, BookingStatus[]> = {
  pending: ["confirmed", "cancelled", "expired"],
  confirmed: ["completed", "cancelled"],
  completed: [], // Terminal state
  cancelled: [], // Terminal state
  expired: [], // Terminal state (auto-expired due to no response)
};

/**
 * Status descriptions for error messages
 */
const STATUS_LABELS: Record<BookingStatus, string> = {
  pending: "pendente",
  confirmed: "confirmada",
  completed: "concluída",
  cancelled: "cancelada",
  expired: "expirada",
};

/**
 * Validate if a status transition is allowed
 *
 * @param currentStatus - Current booking status
 * @param newStatus - Desired new status
 * @returns Validation result with allowed flag and error message
 */
export function validateTransition(
    currentStatus: string,
    newStatus: string
): { allowed: boolean; error?: string } {
  // Validate current status is known
  if (!isValidStatus(currentStatus)) {
    return {
      allowed: false,
      error: `Estado atual inválido: ${currentStatus}`,
    };
  }

  // Validate new status is known
  if (!isValidStatus(newStatus)) {
    return {
      allowed: false,
      error: `Estado desejado inválido: ${newStatus}`,
    };
  }

  // Same status transition is allowed (idempotent)
  if (currentStatus === newStatus) {
    return {allowed: true};
  }

  const allowed = ALLOWED_TRANSITIONS[currentStatus as BookingStatus];
  const isAllowed = allowed.includes(newStatus as BookingStatus);

  if (!isAllowed) {
    const currentLabel = STATUS_LABELS[currentStatus as BookingStatus];
    const newLabel = STATUS_LABELS[newStatus as BookingStatus];

    return {
      allowed: false,
      error: `Não é possível alterar o estado de "${currentLabel}" para "${newLabel}"`,
    };
  }

  return {allowed: true};
}

/**
 * Check if a status string is a valid BookingStatus
 */
export function isValidStatus(status: string): status is BookingStatus {
  return ["pending", "confirmed", "completed", "cancelled", "expired"].includes(status);
}

/**
 * Check if a booking can be cancelled
 *
 * A booking can only be cancelled if it's in a non-terminal state
 *
 * @param currentStatus - Current booking status
 * @returns Whether the booking can be cancelled
 */
export function canCancel(currentStatus: string): boolean {
  if (!isValidStatus(currentStatus)) {
    return false;
  }

  return ALLOWED_TRANSITIONS[currentStatus].includes("cancelled");
}

/**
 * Get all allowed transitions from a given status
 *
 * @param currentStatus - Current booking status
 * @returns Array of allowed next statuses
 */
export function getAllowedTransitions(currentStatus: string): BookingStatus[] {
  if (!isValidStatus(currentStatus)) {
    return [];
  }

  return [...ALLOWED_TRANSITIONS[currentStatus]];
}

/**
 * Check if a status is terminal (no further transitions allowed)
 *
 * @param status - Status to check
 * @returns Whether the status is terminal
 */
export function isTerminalStatus(status: string): boolean {
  if (!isValidStatus(status)) {
    return false;
  }

  return ALLOWED_TRANSITIONS[status].length === 0;
}
