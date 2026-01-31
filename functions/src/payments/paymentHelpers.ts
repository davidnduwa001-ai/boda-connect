/**
 * Payment Helpers - Idempotent Operations
 *
 * This module provides idempotent helpers for payment-related operations.
 * All functions here are designed to be safely called multiple times
 * without causing duplicate effects (double-funding, double-increment, etc.)
 *
 * KEY PRINCIPLE: Each payment can only affect booking.paidAmount ONCE.
 * This is enforced by tracking `appliedPaymentIds` on the booking document.
 */

import * as admin from "firebase-admin";
import {createLogger} from "../common/logger";

const db = admin.firestore();
const logger = createLogger("payment", "helpers");

/**
 * Result of applying a payment to a booking
 */
export interface ApplyPaymentResult {
  success: boolean;
  alreadyApplied: boolean;
  newPaidAmount?: number;
  newPaymentStatus?: string;
}

/**
 * Idempotently apply a payment to a booking's paidAmount
 *
 * This function uses a Firestore transaction to atomically:
 * 1. Check if this paymentId has already been applied
 * 2. If not, increment paidAmount and record the paymentId
 * 3. Update paymentStatus based on new paidAmount vs totalAmount
 *
 * Safe to call multiple times - will only increment once per paymentId.
 *
 * @param bookingId - The booking to update
 * @param paymentId - The payment being applied (used as idempotency key)
 * @param amount - The amount to add to paidAmount
 * @param additionalUpdates - Optional additional fields to update on first application
 * @returns Result indicating if payment was applied or was already applied
 */
export async function applyPaymentToBooking(
    bookingId: string,
    paymentId: string,
    amount: number,
    additionalUpdates: Record<string, unknown> = {}
): Promise<ApplyPaymentResult> {
  const bookingRef = db.collection("bookings").doc(bookingId);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const bookingDoc = await transaction.get(bookingRef);

      if (!bookingDoc.exists) {
        throw new Error(`Booking not found: ${bookingId}`);
      }

      const booking = bookingDoc.data()!;
      const appliedPaymentIds: string[] = booking.appliedPaymentIds || [];

      // IDEMPOTENCY CHECK: Has this payment already been applied?
      if (appliedPaymentIds.includes(paymentId)) {
        logger.info("payment_already_applied", {
          bookingId,
          paymentId,
          currentPaidAmount: booking.paidAmount || 0,
        });
        return {
          success: true,
          alreadyApplied: true,
          newPaidAmount: booking.paidAmount || 0,
          newPaymentStatus: booking.paymentStatus || "unpaid",
        };
      }

      // Calculate new amounts
      const currentPaidAmount = booking.paidAmount || 0;
      const newPaidAmount = currentPaidAmount + amount;
      const totalAmount = booking.totalAmount || booking.totalPrice || 0;

      // Determine new payment status
      let newPaymentStatus: string;
      if (newPaidAmount <= 0) {
        newPaymentStatus = "unpaid";
      } else if (newPaidAmount >= totalAmount) {
        newPaymentStatus = "paid";
      } else {
        newPaymentStatus = "partially_paid";
      }

      // Update booking atomically
      const updateData: Record<string, unknown> = {
        paidAmount: newPaidAmount,
        paymentStatus: newPaymentStatus,
        appliedPaymentIds: admin.firestore.FieldValue.arrayUnion(paymentId),
        lastPaymentId: paymentId,
        lastPaymentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...additionalUpdates,
      };

      transaction.update(bookingRef, updateData);

      logger.info("payment_applied_to_booking", {
        bookingId,
        paymentId,
        amount,
        previousPaidAmount: currentPaidAmount,
        newPaidAmount,
        newPaymentStatus,
      });

      return {
        success: true,
        alreadyApplied: false,
        newPaidAmount,
        newPaymentStatus,
      };
    });

    return result;
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : "unknown";
    logger.error("apply_payment_failed", errorMsg, {
      bookingId,
      paymentId,
      amount,
    });
    throw error;
  }
}

/**
 * Check if a payment has been applied to a booking
 *
 * @param bookingId - The booking to check
 * @param paymentId - The payment to check
 * @returns true if payment has already been applied
 */
export async function isPaymentApplied(
    bookingId: string,
    paymentId: string
): Promise<boolean> {
  const bookingDoc = await db.collection("bookings").doc(bookingId).get();

  if (!bookingDoc.exists) {
    return false;
  }

  const appliedPaymentIds: string[] = bookingDoc.data()?.appliedPaymentIds || [];
  return appliedPaymentIds.includes(paymentId);
}

/**
 * Derive paymentStatus from paidAmount and totalAmount
 *
 * This is the AUTHORITATIVE calculation for payment status.
 * Should be used when rebuilding/fixing booking state.
 *
 * @param paidAmount - Amount paid so far
 * @param totalAmount - Total amount due
 * @returns The derived payment status
 */
export function derivePaymentStatus(
    paidAmount: number,
    totalAmount: number
): "unpaid" | "partially_paid" | "paid" {
  if (paidAmount <= 0) {
    return "unpaid";
  }
  if (paidAmount >= totalAmount) {
    return "paid";
  }
  return "partially_paid";
}

/**
 * Safe increment that returns 0 for undefined/null
 */
export function safeIncrement(
    currentValue: number | undefined | null,
    increment: number
): number {
  return (currentValue || 0) + increment;
}
