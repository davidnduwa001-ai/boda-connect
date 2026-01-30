/**
 * Escrow Service - Server-Side Financial Authority
 *
 * This module handles ALL escrow operations. The client MUST NOT
 * create, fund, release, or refund escrow directly.
 *
 * Escrow Lifecycle:
 * 1. pending_payment - Escrow created when payment intent is created
 * 2. funded - Payment confirmed (via webhook or confirmPayment)
 * 3. service_completed - Booking marked completed, waiting for release
 * 4. released - Funds released to supplier (auto or manual)
 * 5. disputed - Client opened dispute, release frozen
 * 6. refunded - Funds returned to client
 *
 * Platform Fee Calculation (SERVER-ONLY):
 * - Default: 10% platform fee
 * - Tiered suppliers may have reduced fees
 * - Fee calculated on server, never trusted from client
 */

import * as admin from "firebase-admin";

const db = admin.firestore();

// ==================== PLATFORM FEE CONSTANTS (SERVER-ONLY) ====================

/**
 * Default platform fee percentage
 * This is the AUTHORITATIVE source for platform fees
 */
export const DEFAULT_PLATFORM_FEE_PERCENT = 10.0;

/**
 * Tiered platform fees based on supplier tier
 * Lower fees for higher-tier suppliers
 */
export const TIER_PLATFORM_FEES: Record<string, number> = {
  bronze: 10.0,   // Default tier
  silver: 8.0,    // 8% fee
  gold: 6.0,      // 6% fee
  platinum: 4.0,  // 4% fee
};

/**
 * Minimum and maximum allowed platform fees
 */
export const MIN_PLATFORM_FEE_PERCENT = 0;
export const MAX_PLATFORM_FEE_PERCENT = 30;

// ==================== ESCROW STATUS TYPES ====================

export type EscrowStatus =
  | "pending_payment"
  | "funded"
  | "service_completed"
  | "released"
  | "disputed"
  | "refunded";

export interface EscrowRecord {
  id: string;
  bookingId: string;
  paymentId?: string;
  clientId: string;
  supplierId: string;
  totalAmount: number;
  platformFee: number;
  platformFeePercent: number;
  supplierPayout: number;
  currency: string;
  status: EscrowStatus;
  createdAt: FirebaseFirestore.FieldValue;
  updatedAt: FirebaseFirestore.FieldValue;
  fundedAt?: FirebaseFirestore.FieldValue;
  serviceCompletedAt?: FirebaseFirestore.FieldValue;
  releasedAt?: FirebaseFirestore.FieldValue;
  releasedBy?: string;
  disputedAt?: FirebaseFirestore.FieldValue;
  disputeReason?: string;
  refundedAt?: FirebaseFirestore.FieldValue;
  refundReason?: string;
  autoReleaseAt?: FirebaseFirestore.Timestamp;
}

// ==================== PLATFORM FEE CALCULATION ====================

/**
 * Get platform fee percentage for a supplier
 * This is the AUTHORITATIVE calculation - never trust client values
 *
 * @param supplierId - Supplier ID
 * @returns Platform fee percentage (e.g., 10 for 10%)
 */
export async function getPlatformFeePercent(supplierId: string): Promise<number> {
  try {
    // Check for custom fee in platform settings
    const settingsDoc = await db.collection("settings").doc("platform").get();
    if (settingsDoc.exists) {
      const customFee = settingsDoc.data()?.customSupplierFees?.[supplierId];
      if (typeof customFee === "number") {
        return Math.min(Math.max(customFee, MIN_PLATFORM_FEE_PERCENT), MAX_PLATFORM_FEE_PERCENT);
      }
    }

    // Check supplier tier
    const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
    if (supplierDoc.exists) {
      const tier = supplierDoc.data()?.tier as string | undefined;
      if (tier && TIER_PLATFORM_FEES[tier] !== undefined) {
        return TIER_PLATFORM_FEES[tier];
      }
    }

    // Return default fee
    return DEFAULT_PLATFORM_FEE_PERCENT;
  } catch (error) {
    console.error("Error getting platform fee:", error);
    return DEFAULT_PLATFORM_FEE_PERCENT;
  }
}

/**
 * Calculate platform fee and supplier payout
 * This is the AUTHORITATIVE calculation
 *
 * @param totalAmount - Total payment amount
 * @param platformFeePercent - Fee percentage
 * @returns Object with platformFee and supplierPayout
 */
export function calculateFees(
    totalAmount: number,
    platformFeePercent: number
): { platformFee: number; supplierPayout: number } {
  const platformFee = Math.round(totalAmount * platformFeePercent / 100);
  const supplierPayout = totalAmount - platformFee;

  return {platformFee, supplierPayout};
}

// ==================== ESCROW OPERATIONS ====================

/**
 * Create a new escrow record
 * Called ONLY by Cloud Functions when payment intent is created
 *
 * @param data - Escrow creation data
 * @returns Created escrow ID
 */
export async function createEscrow(data: {
  bookingId: string;
  clientId: string;
  supplierId: string;
  totalAmount: number;
  currency?: string;
}): Promise<string> {
  const {bookingId, clientId, supplierId, totalAmount, currency = "AOA"} = data;

  // Get platform fee for this supplier (server-calculated)
  const platformFeePercent = await getPlatformFeePercent(supplierId);
  const {platformFee, supplierPayout} = calculateFees(totalAmount, platformFeePercent);

  const escrowRef = db.collection("escrow").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const escrowData: EscrowRecord = {
    id: escrowRef.id,
    bookingId,
    clientId,
    supplierId,
    totalAmount,
    platformFee,
    platformFeePercent,
    supplierPayout,
    currency,
    status: "pending_payment",
    createdAt: now,
    updatedAt: now,
  };

  await escrowRef.set(escrowData);

  console.log(`Escrow created: ${escrowRef.id} for booking ${bookingId}`);
  console.log(`  Total: ${totalAmount}, Fee: ${platformFee} (${platformFeePercent}%), Payout: ${supplierPayout}`);

  return escrowRef.id;
}

/**
 * Mark escrow as funded when payment is confirmed
 * Called ONLY by confirmPayment CF or webhook handler
 *
 * @param escrowId - Escrow ID to fund
 * @param paymentId - Associated payment ID
 */
export async function fundEscrow(
    escrowId: string,
    paymentId: string
): Promise<void> {
  const escrowRef = db.collection("escrow").doc(escrowId);
  const escrowDoc = await escrowRef.get();

  if (!escrowDoc.exists) {
    throw new Error(`Escrow not found: ${escrowId}`);
  }

  const currentStatus = escrowDoc.data()?.status;
  if (currentStatus !== "pending_payment") {
    console.log(`Escrow ${escrowId} already funded (status: ${currentStatus})`);
    return; // Idempotent
  }

  const now = admin.firestore.FieldValue.serverTimestamp();

  await escrowRef.update({
    status: "funded",
    paymentId,
    fundedAt: now,
    updatedAt: now,
  });

  // Update booking
  const bookingId = escrowDoc.data()?.bookingId;
  if (bookingId) {
    await db.collection("bookings").doc(bookingId).update({
      paymentStatus: "escrow_funded",
      escrowId,
      updatedAt: now,
    });
  }

  // Notify supplier
  const supplierId = escrowDoc.data()?.supplierId;
  const totalAmount = escrowDoc.data()?.totalAmount || 0;

  if (supplierId) {
    const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
    const supplierUserId = supplierDoc.data()?.userId;

    if (supplierUserId) {
      await db.collection("notifications").add({
        userId: supplierUserId,
        type: "escrow_funded",
        title: "Pagamento Garantido 🔒",
        body: `Cliente pagou ${formatCurrency(totalAmount)}. Valor será liberado após conclusão do serviço.`,
        data: {escrowId, bookingId: bookingId || ""},
        isRead: false,
        createdAt: now,
      });
    }
  }

  console.log(`Escrow funded: ${escrowId}`);
}

/**
 * Mark service as completed and start auto-release timer
 * Called when booking status changes to completed
 *
 * @param escrowId - Escrow ID
 * @param autoReleaseHours - Hours until auto-release (default 48)
 */
export async function markServiceCompleted(
    escrowId: string,
    autoReleaseHours = 48
): Promise<void> {
  const escrowRef = db.collection("escrow").doc(escrowId);
  const escrowDoc = await escrowRef.get();

  if (!escrowDoc.exists) {
    throw new Error(`Escrow not found: ${escrowId}`);
  }

  const currentStatus = escrowDoc.data()?.status;
  if (currentStatus !== "funded") {
    console.log(`Escrow ${escrowId} cannot be marked completed (status: ${currentStatus})`);
    return;
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const autoReleaseAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + autoReleaseHours * 60 * 60 * 1000)
  );

  await escrowRef.update({
    status: "service_completed",
    serviceCompletedAt: now,
    autoReleaseAt,
    updatedAt: now,
  });

  // Notify client to confirm or dispute
  const clientId = escrowDoc.data()?.clientId;
  const bookingId = escrowDoc.data()?.bookingId;

  if (clientId) {
    await db.collection("notifications").add({
      userId: clientId,
      type: "service_completed",
      title: "Serviço Concluído",
      body: `Por favor, confirme a conclusão do serviço. O pagamento será liberado automaticamente em ${autoReleaseHours} horas.`,
      data: {escrowId, bookingId: bookingId || ""},
      isRead: false,
      createdAt: now,
    });
  }

  console.log(`Escrow service completed: ${escrowId}, auto-release at ${autoReleaseAt.toDate()}`);
}

/**
 * Release escrow funds to supplier
 * Called by admin, system auto-release, or client confirmation
 *
 * @param escrowId - Escrow ID to release
 * @param releasedBy - Who initiated release (userId, 'system', 'auto')
 * @param notes - Optional release notes
 */
export async function releaseEscrow(
    escrowId: string,
    releasedBy: string,
    notes?: string
): Promise<{success: boolean; supplierPayout: number; platformFee: number}> {
  const escrowRef = db.collection("escrow").doc(escrowId);
  const escrowDoc = await escrowRef.get();

  if (!escrowDoc.exists) {
    throw new Error(`Escrow not found: ${escrowId}`);
  }

  const escrowData = escrowDoc.data()!;
  const currentStatus = escrowData.status as EscrowStatus;

  // Validate status allows release
  if (currentStatus !== "funded" && currentStatus !== "service_completed") {
    throw new Error(`Escrow cannot be released: status is ${currentStatus}`);
  }

  const {
    supplierId,
    supplierPayout,
    platformFee,
    totalAmount,
    bookingId,
  } = escrowData;

  const now = admin.firestore.FieldValue.serverTimestamp();

  // Update escrow status
  await escrowRef.update({
    status: "released",
    releasedAt: now,
    releasedBy,
    releaseNotes: notes || null,
    updatedAt: now,
  });

  // Create payout record for supplier
  const payoutRef = db.collection("payouts").doc();
  await payoutRef.set({
    id: payoutRef.id,
    escrowId,
    bookingId: bookingId || null,
    supplierId,
    amount: supplierPayout,
    platformFee,
    totalAmount,
    currency: escrowData.currency || "AOA",
    status: "pending", // Would become "completed" after actual bank transfer
    createdAt: now,
  });

  // Update booking payment status
  if (bookingId) {
    await db.collection("bookings").doc(bookingId).update({
      paymentStatus: "released",
      supplierPaid: true,
      supplierPaidAmount: supplierPayout,
      platformFee,
      updatedAt: now,
    });
  }

  // Notify supplier of payout
  if (supplierId) {
    const supplierDoc = await db.collection("suppliers").doc(supplierId).get();
    const supplierUserId = supplierDoc.data()?.userId;

    if (supplierUserId) {
      await db.collection("notifications").add({
        userId: supplierUserId,
        type: "payout_released",
        title: "Pagamento Liberado! 💰",
        body: `${formatCurrency(supplierPayout)} foi liberado para sua conta.`,
        data: {
          escrowId,
          bookingId: bookingId || "",
          amount: supplierPayout.toString(),
        },
        isRead: false,
        createdAt: now,
      });
    }
  }

  // Create audit log
  await db.collection("audit_logs").add({
    category: "finance",
    eventType: "escrowReleased",
    userId: releasedBy,
    resourceId: escrowId,
    resourceType: "escrow",
    previousValue: currentStatus,
    newValue: "released",
    description: `Escrow released: ${formatCurrency(supplierPayout)} to supplier, ${formatCurrency(platformFee)} platform fee`,
    metadata: {
      escrowId,
      bookingId: bookingId || null,
      supplierId,
      supplierPayout,
      platformFee,
      totalAmount,
    },
    timestamp: now,
  });

  console.log(`Escrow released: ${escrowId}`);
  console.log(`  Supplier payout: ${supplierPayout}, Platform fee: ${platformFee}`);

  return {success: true, supplierPayout, platformFee};
}

/**
 * Refund escrow to client
 * Called for cancellations or disputes resolved in client's favor
 *
 * @param escrowId - Escrow ID to refund
 * @param refundedBy - Who initiated refund (userId, 'system', 'auto')
 * @param reason - Refund reason
 */
export async function refundEscrow(
    escrowId: string,
    refundedBy: string,
    reason?: string
): Promise<{success: boolean; refundAmount: number}> {
  const escrowRef = db.collection("escrow").doc(escrowId);
  const escrowDoc = await escrowRef.get();

  if (!escrowDoc.exists) {
    throw new Error(`Escrow not found: ${escrowId}`);
  }

  const escrowData = escrowDoc.data()!;
  const currentStatus = escrowData.status as EscrowStatus;

  // Validate status allows refund
  const refundableStatuses: EscrowStatus[] = ["funded", "service_completed", "disputed"];
  if (!refundableStatuses.includes(currentStatus)) {
    throw new Error(`Escrow cannot be refunded: status is ${currentStatus}`);
  }

  const {
    clientId,
    supplierId,
    totalAmount,
    bookingId,
    paymentId,
  } = escrowData;

  const now = admin.firestore.FieldValue.serverTimestamp();

  // Update escrow status
  await escrowRef.update({
    status: "refunded",
    refundedAt: now,
    refundedBy,
    refundReason: reason || "Booking cancelled",
    updatedAt: now,
  });

  // Create refund record
  const refundRef = db.collection("refunds").doc();
  await refundRef.set({
    id: refundRef.id,
    escrowId,
    bookingId: bookingId || null,
    paymentId: paymentId || null,
    clientId,
    supplierId,
    amount: totalAmount,
    currency: escrowData.currency || "AOA",
    reason: reason || "Booking cancelled",
    status: "pending", // Would become "completed" after actual refund processed
    createdAt: now,
  });

  // Update booking payment status
  if (bookingId) {
    await db.collection("bookings").doc(bookingId).update({
      paymentStatus: "refunded",
      refundedAmount: totalAmount,
      updatedAt: now,
    });
  }

  // Notify client of refund
  if (clientId) {
    await db.collection("notifications").add({
      userId: clientId,
      type: "escrow_refunded",
      title: "Reembolso Processado",
      body: `${formatCurrency(totalAmount)} será devolvido à sua conta.`,
      data: {
        escrowId,
        bookingId: bookingId || "",
        amount: totalAmount.toString(),
      },
      isRead: false,
      createdAt: now,
    });
  }

  // Create audit log
  await db.collection("audit_logs").add({
    category: "finance",
    eventType: "escrowRefunded",
    userId: refundedBy,
    resourceId: escrowId,
    resourceType: "escrow",
    previousValue: currentStatus,
    newValue: "refunded",
    description: `Escrow refunded: ${formatCurrency(totalAmount)} to client`,
    metadata: {
      escrowId,
      bookingId: bookingId || null,
      clientId,
      refundAmount: totalAmount,
      reason: reason || null,
    },
    timestamp: now,
  });

  console.log(`Escrow refunded: ${escrowId}, amount: ${totalAmount}`);

  return {success: true, refundAmount: totalAmount};
}

/**
 * Get escrow by booking ID
 *
 * @param bookingId - Booking ID
 * @returns Escrow document data or null
 */
export async function getEscrowByBookingId(
    bookingId: string
): Promise<FirebaseFirestore.DocumentData | null> {
  const escrowQuery = await db
      .collection("escrow")
      .where("bookingId", "==", bookingId)
      .limit(1)
      .get();

  if (escrowQuery.empty) {
    return null;
  }

  return {id: escrowQuery.docs[0].id, ...escrowQuery.docs[0].data()};
}

/**
 * Process auto-release for completed escrows
 * Should be called by a scheduled Cloud Function
 */
export async function processAutoReleases(): Promise<number> {
  const now = admin.firestore.Timestamp.now();

  const pendingReleases = await db
      .collection("escrow")
      .where("status", "==", "service_completed")
      .where("autoReleaseAt", "<=", now)
      .get();

  let releasedCount = 0;

  for (const doc of pendingReleases.docs) {
    try {
      await releaseEscrow(doc.id, "auto", "Auto-release after dispute window");
      releasedCount++;
    } catch (error) {
      console.error(`Failed to auto-release escrow ${doc.id}:`, error);
    }
  }

  if (releasedCount > 0) {
    console.log(`Auto-released ${releasedCount} escrows`);
  }

  return releasedCount;
}

// ==================== UTILITY FUNCTIONS ====================

/**
 * Format currency for display
 */
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("pt-AO", {
    style: "currency",
    currency: "AOA",
  }).format(amount);
}
