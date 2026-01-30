import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  hasExistingReview,
  validateBookingForReview,
  updateSupplierStats,
} from "./reviewUtils";
import {enforceRateLimit} from "../rateLimit/checkRateLimit";

const db = admin.firestore();
const REGION = "us-central1";

interface CreateReviewRequest {
  bookingId: string;
  rating: number; // 1-5
  comment?: string;
  tags?: string[];
}

interface CreateReviewResponse {
  success: boolean;
  reviewId?: string;
  error?: string;
  errorCode?: string;
}

/**
 * Create Review - Callable Cloud Function
 *
 * This function:
 * 1. Validates the caller is authenticated
 * 2. Validates the booking exists
 * 3. Validates the caller is the booking's client
 * 4. Validates the booking status is 'completed'
 * 5. Validates no existing review for this booking by this user
 * 6. Validates rating is within bounds (1-5)
 * 7. Creates the review
 * 8. Updates supplier stats (averageRating, reviewCount)
 */
export const createReview = functions
    .region(REGION)
    .https.onCall(async (data: CreateReviewRequest, context) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado para deixar uma avaliação"
        );
      }

      const callerId = context.auth.uid;

      // 2. Enforce rate limit (10 reviews per day)
      await enforceRateLimit(callerId, "createReview");

      // 3. Validate required fields
      if (!data.bookingId || data.rating === undefined) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "bookingId e rating são obrigatórios"
        );
      }

      // 3. Validate rating bounds
      if (data.rating < 1 || data.rating > 5) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Rating deve ser entre 1 e 5"
        );
      }

      // Round rating to nearest 0.5
      const normalizedRating = Math.round(data.rating * 2) / 2;

      try {
        // 4. Validate booking for review eligibility
        const bookingValidation = await validateBookingForReview(
            data.bookingId,
            callerId
        );

        if (!bookingValidation.valid) {
          throw new functions.https.HttpsError(
              "failed-precondition",
              bookingValidation.error || "Reserva inválida para avaliação"
          );
        }

        const booking = bookingValidation.booking!;

        // 5. Check for existing review (idempotency)
        const existingReviewId = await hasExistingReview(
            data.bookingId,
            callerId
        );

        if (existingReviewId) {
          // Return existing review ID for idempotency
          console.log(
              `Existing review found: ${existingReviewId} for booking ${data.bookingId}`
          );
          return {
            success: true,
            reviewId: existingReviewId,
          } as CreateReviewResponse;
        }

        // 6. Get client info for the review
        const clientDoc = await db.collection("users").doc(callerId).get();
        const clientData = clientDoc.exists ? clientDoc.data() : {};

        // 7. Get supplier info
        const supplierDoc = await db
            .collection("suppliers")
            .doc(booking.supplierId)
            .get();
        const supplierData = supplierDoc.exists ? supplierDoc.data() : {};

        // 8. Create the review
        const reviewRef = db.collection("reviews").doc();
        const now = admin.firestore.FieldValue.serverTimestamp();

        // Parse event date for service date
        let serviceDate = now;
        if (booking.eventDate) {
          if (booking.eventDate.toDate) {
            serviceDate = booking.eventDate;
          } else if (typeof booking.eventDate === "string") {
            const dateParts = booking.eventDate.split("-");
            const dateObj = new Date(
                parseInt(dateParts[0]),
                parseInt(dateParts[1]) - 1,
                parseInt(dateParts[2])
            );
            serviceDate = admin.firestore.Timestamp.fromDate(dateObj);
          }
        }

        const reviewData = {
          id: reviewRef.id,
          bookingId: data.bookingId,
          // Reviewer info (the client)
          reviewerId: callerId,
          reviewerType: "client",
          reviewerName: clientData?.displayName || clientData?.name || "Cliente",
          // Reviewed entity (the supplier)
          reviewedId: booking.supplierId,
          reviewedType: "supplier",
          reviewedName: supplierData?.businessName ||
            supplierData?.name ||
            "Fornecedor",
          // Review content
          rating: normalizedRating,
          comment: data.comment || null,
          tags: data.tags || [],
          photos: null,
          // Context
          serviceCategory: booking.packageName || "Serviço",
          serviceDate: serviceDate,
          // Status
          isPublic: true,
          isFlagged: false,
          flagReason: null,
          status: "approved", // Auto-approve for now
          // Timestamps
          createdAt: now,
          updatedAt: now,
          respondedAt: null,
          response: null,
          // Track creation source
          createdBy: "cloud_function",
        };

        await reviewRef.set(reviewData);

        console.log(
            `Review created: ${reviewRef.id} for booking ${data.bookingId} by ${callerId}`
        );

        // 9. Update supplier stats
        await updateSupplierStats(booking.supplierId);

        // 10. Create notification for supplier
        const notificationRef = db.collection("notifications").doc();
        await notificationRef.set({
          id: notificationRef.id,
          userId: supplierData?.userId || booking.supplierId,
          type: "new_review",
          title: "Nova Avaliação",
          body: `${clientData?.displayName || "Um cliente"} deixou uma avaliação de ${normalizedRating} estrelas`,
          data: {
            reviewId: reviewRef.id,
            bookingId: data.bookingId,
            rating: normalizedRating.toString(),
          },
          read: false,
          createdAt: now,
        });

        return {
          success: true,
          reviewId: reviewRef.id,
        } as CreateReviewResponse;
      } catch (error) {
        console.error("Error creating review:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao criar avaliação. Tente novamente."
        );
      }
    });
