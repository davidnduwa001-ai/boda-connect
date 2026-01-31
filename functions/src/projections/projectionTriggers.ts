/**
 * Projection Triggers - Firestore Event Handlers
 *
 * These Cloud Functions listen to source collection changes and update projections.
 * This ensures client_views and supplier_views stay in sync with source data.
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  rebuildClientView,
  rebuildSupplierView,
  updateViewsOnMessage,
} from "./projectionService";

// ==================== BOOKING TRIGGERS ====================

/**
 * Trigger: Booking created
 * Updates both client and supplier views
 */
export const onBookingCreated = functions.firestore
  .document("bookings/{bookingId}")
  .onCreate(async (snapshot, context) => {
    const booking = snapshot.data();
    const bookingId = context.params.bookingId;

    console.log(`Booking created: ${bookingId}`);

    const clientId = booking.clientId as string;
    const supplierId = booking.supplierId as string;

    if (!clientId || !supplierId) {
      console.error(`Missing clientId or supplierId for booking ${bookingId}`);
      return;
    }

    try {
      // Update both views in parallel
      await Promise.all([
        rebuildClientView(clientId),
        rebuildSupplierView(supplierId),
      ]);

      console.log(`Views updated for booking ${bookingId}`);
    } catch (error) {
      console.error(`Error updating views for booking ${bookingId}:`, error);
    }
  });

/**
 * Trigger: Booking updated
 * Updates both client and supplier views on status change
 */
export const onBookingUpdated = functions.firestore
  .document("bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const bookingId = context.params.bookingId;

    // Check if relevant fields changed
    const statusChanged = before.status !== after.status;
    const paymentStatusChanged = before.paymentStatus !== after.paymentStatus;
    const hasReviewChanged = before.hasReview !== after.hasReview;
    const paidAmountChanged = before.paidAmount !== after.paidAmount;
    const hiddenByClientChanged = before.hiddenByClient !== after.hiddenByClient;

    if (!statusChanged && !paymentStatusChanged && !hasReviewChanged && !paidAmountChanged && !hiddenByClientChanged) {
      console.log(`No relevant changes for booking ${bookingId}, skipping`);
      return;
    }

    console.log(`Booking updated: ${bookingId}, status: ${before.status} -> ${after.status}, paidAmount: ${before.paidAmount} -> ${after.paidAmount}`);

    const clientId = after.clientId as string;
    const supplierId = after.supplierId as string;

    if (!clientId || !supplierId) {
      console.error(`Missing clientId or supplierId for booking ${bookingId}`);
      return;
    }

    try {
      await Promise.all([
        rebuildClientView(clientId),
        rebuildSupplierView(supplierId),
      ]);

      console.log(`Views updated for booking ${bookingId}`);
    } catch (error) {
      console.error(`Error updating views for booking ${bookingId}:`, error);
    }
  });

// ==================== PAYMENT TRIGGERS ====================

/**
 * Trigger: Payment updated
 * Updates client and supplier views on payment status change
 */
export const onPaymentUpdated = functions.firestore
  .document("payments/{paymentId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const paymentId = context.params.paymentId;

    if (before.status === after.status) {
      return;
    }

    console.log(`Payment updated: ${paymentId}, status: ${before.status} -> ${after.status}`);

    const clientId = after.clientId as string;
    const supplierId = after.supplierId as string;

    if (!clientId || !supplierId) {
      console.error(`Missing clientId or supplierId for payment ${paymentId}`);
      return;
    }

    try {
      await Promise.all([
        rebuildClientView(clientId),
        rebuildSupplierView(supplierId),
      ]);

      console.log(`Views updated for payment ${paymentId}`);
    } catch (error) {
      console.error(`Error updating views for payment ${paymentId}:`, error);
    }
  });

// ==================== ESCROW TRIGGERS ====================

/**
 * Trigger: Escrow updated
 * Updates client and supplier views on escrow status change
 */
export const onEscrowUpdated = functions.firestore
  .document("escrow/{escrowId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const escrowId = context.params.escrowId;

    if (before.status === after.status) {
      return;
    }

    console.log(`Escrow updated: ${escrowId}, status: ${before.status} -> ${after.status}`);

    const clientId = after.clientId as string;
    const supplierId = after.supplierId as string;

    if (!clientId || !supplierId) {
      console.error(`Missing clientId or supplierId for escrow ${escrowId}`);
      return;
    }

    try {
      await Promise.all([
        rebuildClientView(clientId),
        rebuildSupplierView(supplierId),
      ]);

      console.log(`Views updated for escrow ${escrowId}`);
    } catch (error) {
      console.error(`Error updating views for escrow ${escrowId}:`, error);
    }
  });

// ==================== MESSAGE TRIGGERS ====================

/**
 * Trigger: Message created in conversation
 * Updates unread counts in both views
 */
export const onMessageCreated = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const conversationId = context.params.conversationId;

    console.log(`Message created in conversation: ${conversationId}`);

    try {
      // Get conversation to find client and supplier
      const conversationDoc = await admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.error(`Conversation not found: ${conversationId}`);
        return;
      }

      const conversation = conversationDoc.data()!;
      const clientId = conversation.clientId as string;
      const supplierId = conversation.supplierId as string;

      if (!clientId || !supplierId) {
        console.error(`Missing clientId or supplierId for conversation ${conversationId}`);
        return;
      }

      await updateViewsOnMessage(conversationId, message, clientId, supplierId);

      console.log(`Unread counts updated for conversation ${conversationId}`);
    } catch (error) {
      console.error("Error updating views for message:", error);
    }
  });

// ==================== BLOCKED DATE TRIGGERS ====================

/**
 * Trigger: Blocked date created
 * Updates supplier availability summary
 */
export const onBlockedDateCreated = functions.firestore
  .document("suppliers/{supplierId}/blocked_dates/{dateId}")
  .onCreate(async (snapshot, context) => {
    const supplierId = context.params.supplierId;

    console.log(`Blocked date created for supplier: ${supplierId}`);

    try {
      await rebuildSupplierView(supplierId);
      console.log("Supplier view updated for blocked date creation");
    } catch (error) {
      console.error("Error updating supplier view:", error);
    }
  });

/**
 * Trigger: Blocked date deleted
 * Updates supplier availability summary
 */
export const onBlockedDateDeleted = functions.firestore
  .document("suppliers/{supplierId}/blocked_dates/{dateId}")
  .onDelete(async (snapshot, context) => {
    const supplierId = context.params.supplierId;

    console.log(`Blocked date deleted for supplier: ${supplierId}`);

    try {
      await rebuildSupplierView(supplierId);
      console.log("Supplier view updated for blocked date deletion");
    } catch (error) {
      console.error("Error updating supplier view:", error);
    }
  });

// ==================== REVIEW TRIGGERS ====================

/**
 * Trigger: Review created
 * Updates supplier dashboard stats
 */
export const onReviewCreated = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snapshot, _context) => {
    const review = snapshot.data();
    const supplierId = review.supplierId as string;
    const clientId = review.clientId as string;

    console.log(`Review created for supplier: ${supplierId}`);

    try {
      const updates: Promise<void>[] = [rebuildSupplierView(supplierId)];

      if (clientId) {
        updates.push(rebuildClientView(clientId));
      }

      await Promise.all(updates);
      console.log("Views updated for review");
    } catch (error) {
      console.error("Error updating views for review:", error);
    }
  });

// ==================== SUPPLIER PROFILE TRIGGERS ====================

/**
 * Trigger: Supplier profile updated
 * Updates supplier view account flags
 */
export const onSupplierUpdated = functions.firestore
  .document("suppliers/{supplierId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const supplierId = context.params.supplierId;

    // Check if account-related fields changed
    const relevantFieldsChanged =
      before.accountStatus !== after.accountStatus ||
      before.identityVerificationStatus !== after.identityVerificationStatus ||
      before.lifecycle_state !== after.lifecycle_state ||
      JSON.stringify(before.compliance) !== JSON.stringify(after.compliance) ||
      JSON.stringify(before.visibility) !== JSON.stringify(after.visibility) ||
      JSON.stringify(before.blocks) !== JSON.stringify(after.blocks);

    if (!relevantFieldsChanged) {
      return;
    }

    console.log(`Supplier profile updated: ${supplierId}`);

    try {
      await rebuildSupplierView(supplierId);
      console.log("Supplier view updated for profile change");
    } catch (error) {
      console.error("Error updating supplier view:", error);
    }
  });

// ==================== CART TRIGGERS ====================

/**
 * Trigger: Cart item added
 * Updates client view cart count
 */
export const onCartItemCreated = functions.firestore
  .document("users/{userId}/cart/{itemId}")
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;

    console.log(`Cart item added for user: ${userId}`);

    try {
      await rebuildClientView(userId);
    } catch (error) {
      console.error("Error updating client view:", error);
    }
  });

/**
 * Trigger: Cart item removed
 * Updates client view cart count
 */
export const onCartItemDeleted = functions.firestore
  .document("users/{userId}/cart/{itemId}")
  .onDelete(async (snapshot, context) => {
    const userId = context.params.userId;

    console.log(`Cart item removed for user: ${userId}`);

    try {
      await rebuildClientView(userId);
    } catch (error) {
      console.error("Error updating client view:", error);
    }
  });
