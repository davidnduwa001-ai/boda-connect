import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Booking status types
 */
export type BookingStatus =
  | "pending"
  | "confirmed"
  | "partially_paid"
  | "paid"
  | "completed"
  | "cancelled"
  | "rejected";

/**
 * Active booking statuses that count as "occupied"
 */
export const ACTIVE_BOOKING_STATUSES: BookingStatus[] = [
  "pending",
  "confirmed",
  "partially_paid",
  "paid",
];

/**
 * Booking statuses that allow payment
 */
export const PAYABLE_BOOKING_STATUSES: BookingStatus[] = [
  "pending",
  "confirmed",
  "partially_paid",
];

/**
 * Check if a supplier has a booking conflict on a given date
 * @param supplierId - The supplier's ID
 * @param eventDate - The event date (YYYY-MM-DD format)
 * @param excludeBookingId - Optional booking ID to exclude from check
 * @returns true if there's a conflict, false otherwise
 */
export async function hasBookingConflict(
    supplierId: string,
    eventDate: string,
    excludeBookingId?: string
): Promise<boolean> {
  const conflictQuery = db
      .collection("bookings")
      .where("supplierId", "==", supplierId)
      .where("eventDate", "==", eventDate)
      .where("status", "in", ACTIVE_BOOKING_STATUSES);

  const conflictSnapshot = await conflictQuery.get();

  if (excludeBookingId) {
    return conflictSnapshot.docs.some((doc) => doc.id !== excludeBookingId);
  }

  return !conflictSnapshot.empty;
}

/**
 * Check if a date is blocked by the supplier
 * @param supplierId - The supplier's ID
 * @param eventDate - The event date (YYYY-MM-DD format)
 * @returns true if the date is blocked, false otherwise
 */
export async function isDateBlocked(
    supplierId: string,
    eventDate: string
): Promise<boolean> {
  const blockedDoc = await db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blockedDates")
      .doc(eventDate)
      .get();

  return blockedDoc.exists;
}

/**
 * Check if a date is available for booking
 * Combines blocked date check and conflict check
 * @param supplierId - The supplier's ID
 * @param eventDate - The event date (YYYY-MM-DD format)
 * @param excludeBookingId - Optional booking ID to exclude
 * @returns Object with availability info
 */
export async function checkDateAvailability(
    supplierId: string,
    eventDate: string,
    excludeBookingId?: string
): Promise<{
  available: boolean;
  reason?: string;
}> {
  // Check if date is blocked
  const blocked = await isDateBlocked(supplierId, eventDate);
  if (blocked) {
    return {
      available: false,
      reason: "Esta data está bloqueada pelo fornecedor",
    };
  }

  // Check for existing bookings
  const hasConflict = await hasBookingConflict(
      supplierId,
      eventDate,
      excludeBookingId
  );

  if (hasConflict) {
    return {
      available: false,
      reason: "Já existe uma reserva para esta data",
    };
  }

  return {available: true};
}

/**
 * Get all booked dates for a supplier within a date range
 * @param supplierId - The supplier's ID
 * @param startDate - Start of the range (YYYY-MM-DD)
 * @param endDate - End of the range (YYYY-MM-DD)
 * @returns Array of booked dates
 */
export async function getBookedDates(
    supplierId: string,
    startDate: string,
    endDate: string
): Promise<string[]> {
  const bookingsQuery = db
      .collection("bookings")
      .where("supplierId", "==", supplierId)
      .where("eventDate", ">=", startDate)
      .where("eventDate", "<=", endDate)
      .where("status", "in", ACTIVE_BOOKING_STATUSES);

  const snapshot = await bookingsQuery.get();

  const bookedDates: string[] = [];
  snapshot.docs.forEach((doc) => {
    const booking = doc.data();
    if (booking.eventDate) {
      bookedDates.push(booking.eventDate);
    }
  });

  return bookedDates;
}

/**
 * Get all blocked dates for a supplier within a date range
 * @param supplierId - The supplier's ID
 * @param startDate - Start of the range (YYYY-MM-DD)
 * @param endDate - End of the range (YYYY-MM-DD)
 * @returns Array of blocked dates
 */
export async function getBlockedDates(
    supplierId: string,
    startDate: string,
    endDate: string
): Promise<string[]> {
  const blockedQuery = db
      .collection("suppliers")
      .doc(supplierId)
      .collection("blockedDates")
      .where(admin.firestore.FieldPath.documentId(), ">=", startDate)
      .where(admin.firestore.FieldPath.documentId(), "<=", endDate);

  const snapshot = await blockedQuery.get();

  return snapshot.docs.map((doc) => doc.id);
}

/**
 * Get all unavailable dates (booked + blocked) for a supplier
 * @param supplierId - The supplier's ID
 * @param startDate - Start of the range (YYYY-MM-DD)
 * @param endDate - End of the range (YYYY-MM-DD)
 * @returns Object with booked and blocked dates
 */
export async function getUnavailableDates(
    supplierId: string,
    startDate: string,
    endDate: string
): Promise<{
  bookedDates: string[];
  blockedDates: string[];
  allUnavailable: string[];
}> {
  const [bookedDates, blockedDates] = await Promise.all([
    getBookedDates(supplierId, startDate, endDate),
    getBlockedDates(supplierId, startDate, endDate),
  ]);

  const allUnavailable = [...new Set([...bookedDates, ...blockedDates])].sort();

  return {
    bookedDates,
    blockedDates,
    allUnavailable,
  };
}

/**
 * Validate booking can be modified (for updates)
 * @param bookingId - The booking ID
 * @param callerId - The user attempting the modification
 * @param requiredRole - "client" | "supplier" | "either"
 * @returns Validation result with booking data
 */
export async function validateBookingModification(
    bookingId: string,
    callerId: string,
    requiredRole: "client" | "supplier" | "either" = "either"
): Promise<{
  valid: boolean;
  error?: string;
  booking?: FirebaseFirestore.DocumentData;
}> {
  const bookingDoc = await db.collection("bookings").doc(bookingId).get();

  if (!bookingDoc.exists) {
    return {valid: false, error: "Reserva não encontrada"};
  }

  const booking = bookingDoc.data()!;

  // Check role
  const isClient = booking.clientId === callerId;
  const isSupplier = booking.supplierId === callerId;

  if (requiredRole === "client" && !isClient) {
    return {valid: false, error: "Apenas o cliente pode realizar esta ação"};
  }

  if (requiredRole === "supplier" && !isSupplier) {
    return {
      valid: false,
      error: "Apenas o fornecedor pode realizar esta ação",
    };
  }

  if (requiredRole === "either" && !isClient && !isSupplier) {
    return {
      valid: false,
      error: "Você não tem permissão para modificar esta reserva",
    };
  }

  return {valid: true, booking};
}
