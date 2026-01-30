import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Booking statuses that allow reviews
 */
export const REVIEWABLE_BOOKING_STATUSES = ["completed"];

/**
 * Review window: Maximum days after completion to leave a review
 */
export const REVIEW_WINDOW_DAYS = 90;

/**
 * Validate that a booking can be reviewed by the caller
 * @param bookingId - The booking ID
 * @param callerId - The user attempting to leave the review
 * @returns Validation result with booking data
 */
export async function validateBookingForReview(
    bookingId: string,
    callerId: string
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

  // Check caller is the client of this booking
  if (booking.clientId !== callerId) {
    return {
      valid: false,
      error: "Você só pode avaliar reservas das quais você é o cliente",
    };
  }

  // Check booking status is completed
  if (!REVIEWABLE_BOOKING_STATUSES.includes(booking.status)) {
    return {
      valid: false,
      error: "Avaliações só podem ser feitas após a conclusão do serviço",
    };
  }

  // Check review window (optional - just log warning)
  if (booking.completedAt) {
    const completedAt = booking.completedAt.toDate
        ? booking.completedAt.toDate()
        : new Date(booking.completedAt);
    const daysSinceCompletion = Math.floor(
        (Date.now() - completedAt.getTime()) / (1000 * 60 * 60 * 24)
    );

    if (daysSinceCompletion > REVIEW_WINDOW_DAYS) {
      console.log(
          `Late review warning: ${daysSinceCompletion} days after completion for booking ${bookingId}`
      );
      // Still allow the review, but log it
    }
  }

  return {valid: true, booking};
}

/**
 * Check if a user has already reviewed a booking
 * @param bookingId - The booking ID
 * @param reviewerId - The user ID
 * @returns The existing review ID if found, null otherwise
 */
export async function hasExistingReview(
    bookingId: string,
    reviewerId: string
): Promise<string | null> {
  const existingQuery = db
      .collection("reviews")
      .where("bookingId", "==", bookingId)
      .where("reviewerId", "==", reviewerId)
      .limit(1);

  const existingSnapshot = await existingQuery.get();

  if (!existingSnapshot.empty) {
    return existingSnapshot.docs[0].id;
  }

  return null;
}

/**
 * Update supplier statistics after a review
 * @param supplierId - The supplier ID
 */
export async function updateSupplierStats(supplierId: string): Promise<void> {
  try {
    // Get all approved reviews for this supplier
    const reviewsQuery = db
        .collection("reviews")
        .where("reviewedId", "==", supplierId)
        .where("reviewedType", "==", "supplier")
        .where("status", "in", ["approved", "pending"]);

    const reviewsSnapshot = await reviewsQuery.get();

    if (reviewsSnapshot.empty) {
      // No reviews, set default values
      await db.collection("suppliers").doc(supplierId).update({
        rating: 5.0, // Default rating
        reviewCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    // Calculate average rating
    let totalRating = 0;
    let reviewCount = 0;

    reviewsSnapshot.docs.forEach((doc) => {
      const review = doc.data();
      if (typeof review.rating === "number") {
        totalRating += review.rating;
        reviewCount++;
      }
    });

    const averageRating = reviewCount > 0
        ? Math.round((totalRating / reviewCount) * 10) / 10 // Round to 1 decimal
        : 5.0;

    // Update supplier document
    await db.collection("suppliers").doc(supplierId).update({
      rating: averageRating,
      reviewCount: reviewCount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(
        `Supplier ${supplierId} stats updated: rating=${averageRating}, reviewCount=${reviewCount}`
    );
  } catch (error) {
    console.error(`Error updating supplier stats for ${supplierId}:`, error);
    // Don't throw - stats update is not critical
  }
}

/**
 * Get review statistics for a supplier
 * @param supplierId - The supplier ID
 * @returns Review statistics
 */
export async function getSupplierReviewStats(supplierId: string): Promise<{
  averageRating: number;
  reviewCount: number;
  ratingDistribution: Record<number, number>;
}> {
  const reviewsQuery = db
      .collection("reviews")
      .where("reviewedId", "==", supplierId)
      .where("reviewedType", "==", "supplier")
      .where("status", "==", "approved");

  const reviewsSnapshot = await reviewsQuery.get();

  if (reviewsSnapshot.empty) {
    return {
      averageRating: 0,
      reviewCount: 0,
      ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    };
  }

  let totalRating = 0;
  const distribution: Record<number, number> = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

  reviewsSnapshot.docs.forEach((doc) => {
    const review = doc.data();
    if (typeof review.rating === "number") {
      totalRating += review.rating;
      const roundedRating = Math.round(review.rating);
      if (roundedRating >= 1 && roundedRating <= 5) {
        distribution[roundedRating]++;
      }
    }
  });

  const reviewCount = reviewsSnapshot.docs.length;
  const averageRating = reviewCount > 0
      ? Math.round((totalRating / reviewCount) * 10) / 10
      : 0;

  return {
    averageRating,
    reviewCount,
    ratingDistribution: distribution,
  };
}

/**
 * Check if a booking can be reviewed
 * @param bookingId - The booking ID
 * @param userId - The user attempting to review
 * @returns Whether the booking can be reviewed
 */
export async function canReviewBooking(
    bookingId: string,
    userId: string
): Promise<{
  canReview: boolean;
  reason?: string;
}> {
  // Validate booking
  const validation = await validateBookingForReview(bookingId, userId);
  if (!validation.valid) {
    return {canReview: false, reason: validation.error};
  }

  // Check for existing review
  const existingReviewId = await hasExistingReview(bookingId, userId);
  if (existingReviewId) {
    return {canReview: false, reason: "Você já avaliou esta reserva"};
  }

  return {canReview: true};
}
