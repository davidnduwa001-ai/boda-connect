import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize Firebase Admin only if not already initialized
// (whatsapp_auth.ts and other modules may initialize it first)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();


// WhatsApp Auth exports
export {
  sendWhatsAppOTP,
  verifyWhatsAppOTP,
  resendWhatsAppOTP
} from "./whatsapp_auth";

// Payment Cloud Functions exports
export {
  createPaymentIntent
} from "./payments/createPaymentIntent";

export {
  confirmPayment,
  cancelPayment
} from "./payments/confirmPayment";

export {
  proxyPayWebhook,
  acknowledgeRPSPayment
} from "./webhooks/proxyPayWebhook";

export {
  stripeWebhook
} from "./payments/stripeWebhook";

// Booking Cloud Functions exports
export {
  createBooking
} from "./bookings/createBooking";

export {
  updateBookingStatus
} from "./bookings/updateBookingStatus";

export {
  cancelBooking
} from "./bookings/cancelBooking";

// Supplier Booking Data Access (SECURE - validates ownership)
export {
  getSupplierBookings,
  getSupplierBookingDetails,
  getSupplierAgenda,
  getSupplierPedidos,
  respondToBooking,
} from "./bookings/getSupplierBookings";

// Client Booking Data Access (SECURE - validates ownership)
export {
  getClientBookings,
  getClientBookingDetails,
} from "./bookings/getClientBookings";

// Chat/Messaging Cloud Functions (SECURE - validates participant access)
export {
  sendMessage,
  getOrCreateConversation,
  markConversationAsRead,
} from "./chat/sendMessage";

// Admin Functions (READ-ONLY)
export {
  inspectSupplierEligibility
} from "./admin/inspectSupplierEligibility";

export {
  exportMigrationMetrics,
  exportMigrationMetricsHttp
} from "./admin/exportMigrationMetrics";

export {
  exportRateLimitMetrics
} from "./admin/exportRateLimitMetrics";

// Admin Migration Functions (ONE-TIME USE)
export {
  migrateSuppliers,
  rollbackMigration
} from "./admin/migrateSuppliers";

// Review Cloud Functions exports
export {
  createReview
} from "./reviews/createReview";

// Finance/Escrow Cloud Functions exports
export {
  releaseEscrowFunction as releaseEscrow
} from "./finance/releaseEscrow";

export {
  refundEscrowFunction as refundEscrow
} from "./finance/refundEscrow";

// UI-First Projection Triggers (maintain client_views and supplier_views)
// Note: Renamed to avoid conflicts with notification triggers
export {
  onBookingCreated as projectionOnBookingCreated,
  onBookingUpdated as projectionOnBookingUpdated,
  onPaymentUpdated as projectionOnPaymentUpdated,
  onEscrowUpdated as projectionOnEscrowUpdated,
  onMessageCreated as projectionOnMessageCreated,
  onBlockedDateCreated as projectionOnBlockedDateCreated,
  onBlockedDateDeleted as projectionOnBlockedDateDeleted,
  onReviewCreated as projectionOnReviewCreated,
  onSupplierUpdated as projectionOnSupplierUpdated,
  onCartItemCreated as projectionOnCartItemCreated,
  onCartItemDeleted as projectionOnCartItemDeleted,
} from "./projections/projectionTriggers";

// Projection Backfill & Maintenance (admin only)
export {
  runBackfillProjections,
  backfillSingleClient,
  backfillSingleSupplier,
  verifyProjectionFreshness,
} from "./projections/backfillProjections";

// Region: us-central1 (default, most reliable)
// Data still in africa-south1, functions run globally
const REGION = "us-central1";
const region = functions.region(REGION);

interface NotificationData {
  userId: string;
  title: string;
  body: string;
  type: string;
  data?: Record<string, string>;
}

/**
 * Send push notification to user
 * Handles both regular users and suppliers (where document ID may differ from auth UID)
 * @param {NotificationData} notification - Notification data
 */
async function sendPushNotification(
    notification: NotificationData
): Promise<void> {
  try {
    let fcmToken: string | undefined;
    let actualUserId = notification.userId;

    // Try to get FCM token from users collection
    const userDoc = await db
        .collection("users")
        .doc(notification.userId)
        .get();
    fcmToken = userDoc.data()?.fcmToken;

    // If no token found, check if this is a supplier document ID
    // Suppliers may have document ID != auth UID
    if (!fcmToken) {
      const supplierDoc = await db
          .collection("suppliers")
          .doc(notification.userId)
          .get();

      if (supplierDoc.exists) {
        const supplierAuthUid = supplierDoc.data()?.userId;
        if (supplierAuthUid && supplierAuthUid !== notification.userId) {
          // This is a supplier with different document ID, get token from actual user doc
          const supplierUserDoc = await db
              .collection("users")
              .doc(supplierAuthUid)
              .get();
          fcmToken = supplierUserDoc.data()?.fcmToken;
          actualUserId = supplierAuthUid;
          console.log(`Resolved supplier ${notification.userId} -> auth UID ${actualUserId}`);
        }
      }
    }

    if (!fcmToken) {
      console.log(`No FCM token for user ${notification.userId} (resolved: ${actualUserId})`);
      return;
    }

    await messaging.send({
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: notification.type,
        ...notification.data,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "boda_connect_channel",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    // Store notification with the resolved user ID (auth UID)
    // This ensures the notification is found when the client queries
    await db.collection("notifications").add({
      userId: actualUserId,
      title: notification.title,
      body: notification.body,
      type: notification.type,
      data: notification.data || {},
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Notification sent to ${actualUserId}`);
  } catch (error) {
    console.error("Error sending notification:", error);
  }
}

/**
 * Get supplier's user ID from supplier document
 * @param {string} supplierId - Supplier ID
 * @return {Promise<string | null>} User ID or null
 */
async function getSupplierUserId(supplierId: string): Promise<string | null> {
  const doc = await db.collection("suppliers").doc(supplierId).get();
  return doc.data()?.userId || null;
}

/**
 * Get user name from user document
 * @param {string} userId - User ID
 * @return {Promise<string>} User name
 */
async function getUserName(userId: string): Promise<string> {
  const doc = await db.collection("users").doc(userId).get();
  return doc.data()?.name || "Cliente";
}

/**
 * Get supplier business name
 * @param {string} supplierId - Supplier ID
 * @return {Promise<string>} Supplier name
 */
async function getSupplierName(supplierId: string): Promise<string> {
  const doc = await db.collection("suppliers").doc(supplierId).get();
  return doc.data()?.businessName || "Fornecedor";
}

// ==================== BOOKING NOTIFICATIONS ====================

export const onBookingCreated = region.firestore
    .document("bookings/{bookingId}")
    .onCreate(async (snap, context) => {
      const booking = snap.data();
      const bookingId = context.params.bookingId;

      const supplierUserId = await getSupplierUserId(booking.supplierId);
      if (supplierUserId) {
        const clientName = await getUserName(booking.clientId);
        // Get event name with fallback
        const eventName = booking.eventName || booking.packageName || "seu evento";

        await sendPushNotification({
          userId: supplierUserId,
          title: "Nova Reserva! 🎉",
          body: `${clientName} fez uma reserva para ${eventName}`,
          type: "new_booking",
          data: {
            bookingId: bookingId,
            eventDate: booking.eventDate?.toDate?.()?.toISOString() || "",
            eventName: eventName,
            clientName: clientName,
          },
        });
      }

      console.log(`Booking created: ${bookingId}`);
      return null;
    });

export const onBookingUpdated = region.firestore
    .document("bookings/{bookingId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      const bookingId = context.params.bookingId;

      if (before.status === after.status) {
        return null;
      }

      console.log(`Booking ${bookingId}: ${before.status} → ${after.status}`);

      const supplierName = await getSupplierName(after.supplierId);

      // Get event name with fallback
      const eventNameForUpdate = after.eventName || after.packageName || "seu evento";

      switch (after.status) {
        case "confirmed":
          await sendPushNotification({
            userId: after.clientId,
            title: "Reserva Confirmada! ✅",
            body: `${supplierName} confirmou a reserva para ${eventNameForUpdate}`,
            type: "booking_confirmed",
            data: {bookingId, supplierName, eventName: eventNameForUpdate},
          });
          break;

        case "cancelled": {
          const cancelledBy = after.cancelledBy;
          const suppUserId = await getSupplierUserId(after.supplierId);
          const notifyId = cancelledBy === after.clientId ?
            suppUserId : after.clientId;
          // Get event name with fallback
          const cancelledEventName = after.eventName || after.packageName || "o evento";

          if (notifyId) {
            await sendPushNotification({
              userId: notifyId,
              title: "Reserva Cancelada",
              body: `A reserva para ${cancelledEventName} foi cancelada`,
              type: "booking_cancelled",
              data: {bookingId, eventName: cancelledEventName},
            });
          }
          break;
        }

        case "completed":
          await sendPushNotification({
            userId: after.clientId,
            title: "Como foi o serviço? ⭐",
            body: `Deixe uma avaliação para ${supplierName} - ${eventNameForUpdate}`,
            type: "request_review",
            data: {bookingId, supplierId: after.supplierId, supplierName, eventName: eventNameForUpdate},
          });
          break;
      }

      return null;
    });

// ==================== PAYMENT NOTIFICATIONS ====================

export const onPaymentReceived = region.firestore
    .document("bookings/{bookingId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      const bookingId = context.params.bookingId;

      if (before.paidAmount === after.paidAmount) {
        return null;
      }

      const paymentDiff = after.paidAmount - before.paidAmount;
      if (paymentDiff <= 0) return null;

      console.log(`Payment: ${paymentDiff} AOA for ${bookingId}`);

      const supplierUserId = await getSupplierUserId(after.supplierId);
      if (supplierUserId) {
        const clientName = await getUserName(after.clientId);
        const formatted = new Intl.NumberFormat("pt-AO", {
          style: "currency",
          currency: after.currency || "AOA",
        }).format(paymentDiff);

        await sendPushNotification({
          userId: supplierUserId,
          title: "Pagamento Recebido! 💰",
          body: `${clientName} pagou ${formatted}`,
          type: "payment_received",
          data: {bookingId, amount: paymentDiff.toString()},
        });
      }

      return null;
    });

// ==================== CHAT NOTIFICATIONS ====================

// Legacy chats collection trigger (for backward compatibility)
export const onMessageCreated = region.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      const message = snap.data();
      const chatId = context.params.chatId;

      const chatDoc = await db.collection("chats").doc(chatId).get();
      const chat = chatDoc.data();
      if (!chat) return null;

      const recipientId = chat.participants.find(
          (id: string) => id !== message.senderId
      );
      if (!recipientId) return null;

      let senderName = message.senderName;
      if (!senderName) {
        if (message.senderId === chat.clientId) {
          senderName = chat.clientName || await getUserName(message.senderId);
        } else {
          senderName = chat.supplierName ||
            await getSupplierName(chat.supplierId);
        }
      }

      let preview = message.text || "";
      if (message.type === "image") {
        preview = "📷 Enviou uma imagem";
      } else if (message.type === "quote") {
        preview = "💰 Enviou um orçamento";
      }

      await sendPushNotification({
        userId: recipientId,
        title: senderName,
        body: preview,
        type: "new_message",
        data: {chatId},
      });

      return null;
    });

// New conversations collection trigger (primary)
export const onConversationMessageCreated = region.firestore
    .document("conversations/{conversationId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      const message = snap.data();
      const conversationId = context.params.conversationId;

      const convDoc = await db
          .collection("conversations")
          .doc(conversationId)
          .get();
      const conversation = convDoc.data();
      if (!conversation) return null;

      // Find the recipient (the other participant)
      const recipientId = conversation.participants.find(
          (id: string) => id !== message.senderId
      );
      if (!recipientId) return null;

      // Get sender name
      let senderName = message.senderName;
      if (!senderName) {
        if (message.senderId === conversation.clientId) {
          senderName = conversation.clientName ||
            await getUserName(message.senderId);
        } else {
          senderName = conversation.supplierName || "Fornecedor";
        }
      }

      // Build message preview
      let preview = message.text || "";
      if (message.type === "image") {
        preview = "📷 Enviou uma imagem";
      } else if (message.type === "quote") {
        preview = "💰 Enviou um orçamento";
      } else if (message.type === "file") {
        preview = "📎 Enviou um arquivo";
      } else if (message.type === "booking") {
        preview = "📅 Enviou uma referência de reserva";
      }

      // Truncate long messages
      if (preview.length > 100) {
        preview = preview.substring(0, 97) + "...";
      }

      await sendPushNotification({
        userId: recipientId,
        title: senderName,
        body: preview,
        type: "new_message",
        data: {
          chatId: conversationId,
          senderId: message.senderId,
          senderName: senderName,
        },
      });

      console.log(
          `Message notification sent: ${conversationId} -> ${recipientId}`
      );
      return null;
    });

// ==================== REVIEW NOTIFICATIONS ====================

export const onReviewCreated = region.firestore
    .document("reviews/{reviewId}")
    .onCreate(async (snap, context) => {
      const review = snap.data();

      const supplierUserId = await getSupplierUserId(review.supplierId);
      if (supplierUserId) {
        const clientName = await getUserName(review.clientId);
        const stars = "⭐".repeat(Math.min(review.rating, 5));

        await sendPushNotification({
          userId: supplierUserId,
          title: `Nova Avaliação! ${stars}`,
          body: `${clientName} deixou uma avaliação`,
          type: "new_review",
          data: {reviewId: context.params.reviewId},
        });
      }

      console.log(`Review: ${context.params.reviewId} - ${review.rating}`);
      return null;
    });

// ==================== CATEGORY SUPPLIER COUNT TRIGGERS ====================

/**
 * Update category supplier count when a new supplier is created
 */
export const onSupplierCreated = region.firestore
    .document("suppliers/{supplierId}")
    .onCreate(async (snap) => {
      const supplier = snap.data();
      const category = supplier.category;

      if (!category) {
        console.log("Supplier created without category");
        return null;
      }

      try {
        // Find the category document by name
        const categoryQuery = await db
            .collection("categories")
            .where("name", "==", category)
            .limit(1)
            .get();

        if (!categoryQuery.empty) {
          const categoryDoc = categoryQuery.docs[0];
          await categoryDoc.ref.update({
            supplierCount: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`Incremented supplier count for category: ${category}`);
        } else {
          console.log(`Category not found: ${category}`);
        }
      } catch (error) {
        console.error("Error updating category count on create:", error);
      }

      return null;
    });

/**
 * Update category supplier count when a supplier is deleted
 */
export const onSupplierDeleted = region.firestore
    .document("suppliers/{supplierId}")
    .onDelete(async (snap) => {
      const supplier = snap.data();
      const category = supplier.category;

      if (!category) {
        return null;
      }

      try {
        const categoryQuery = await db
            .collection("categories")
            .where("name", "==", category)
            .limit(1)
            .get();

        if (!categoryQuery.empty) {
          const categoryDoc = categoryQuery.docs[0];
          const currentCount = categoryDoc.data().supplierCount || 0;
          await categoryDoc.ref.update({
            supplierCount: currentCount > 0 ?
              admin.firestore.FieldValue.increment(-1) : 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`Decremented supplier count for category: ${category}`);
        }
      } catch (error) {
        console.error("Error updating category count on delete:", error);
      }

      return null;
    });

/**
 * Handle category change when supplier is updated
 */
export const onSupplierUpdated = region.firestore
    .document("suppliers/{supplierId}")
    .onUpdate(async (change) => {
      const before = change.before.data();
      const after = change.after.data();

      const oldCategory = before.category;
      const newCategory = after.category;
      const wasActive = before.isActive;
      const isActive = after.isActive;

      // Handle category change
      if (oldCategory !== newCategory && oldCategory && newCategory) {
        try {
          // Decrement old category
          const oldCategoryQuery = await db
              .collection("categories")
              .where("name", "==", oldCategory)
              .limit(1)
              .get();

          if (!oldCategoryQuery.empty) {
            const oldDoc = oldCategoryQuery.docs[0];
            const currentCount = oldDoc.data().supplierCount || 0;
            await oldDoc.ref.update({
              supplierCount: currentCount > 0 ?
                admin.firestore.FieldValue.increment(-1) : 0,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          // Increment new category
          const newCategoryQuery = await db
              .collection("categories")
              .where("name", "==", newCategory)
              .limit(1)
              .get();

          if (!newCategoryQuery.empty) {
            await newCategoryQuery.docs[0].ref.update({
              supplierCount: admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          console.log(`Supplier moved: ${oldCategory} -> ${newCategory}`);
        } catch (error) {
          console.error("Error handling category change:", error);
        }
      }

      // Handle activation/deactivation
      if (wasActive !== isActive && newCategory) {
        try {
          const categoryQuery = await db
              .collection("categories")
              .where("name", "==", newCategory)
              .limit(1)
              .get();

          if (!categoryQuery.empty) {
            const categoryDoc = categoryQuery.docs[0];
            const currentCount = categoryDoc.data().supplierCount || 0;

            if (isActive) {
              // Supplier activated - increment
              await categoryDoc.ref.update({
                supplierCount: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              console.log(`Supplier activated in ${newCategory}`);
            } else {
              // Supplier deactivated - decrement
              await categoryDoc.ref.update({
                supplierCount: currentCount > 0 ?
                  admin.firestore.FieldValue.increment(-1) : 0,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              console.log(`Supplier deactivated in ${newCategory}`);
            }
          }
        } catch (error) {
          console.error("Error handling activation change:", error);
        }
      }

      return null;
    });

// ==================== SCHEDULED FUNCTIONS ====================

export const sendEventReminders = region.pubsub
    .schedule("0 9 * * *")
    .timeZone("Africa/Luanda")
    .onRun(async () => {
      const now = new Date();
      const tomorrow = new Date(now);
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);

      const dayAfter = new Date(tomorrow);
      dayAfter.setDate(dayAfter.getDate() + 1);

      const bookings = await db
          .collection("bookings")
          .where("status", "==", "confirmed")
          .where("eventDate", ">=",
              admin.firestore.Timestamp.fromDate(tomorrow))
          .where("eventDate", "<",
              admin.firestore.Timestamp.fromDate(dayAfter))
          .get();

      for (const doc of bookings.docs) {
        const booking = doc.data();

        await sendPushNotification({
          userId: booking.clientId,
          title: "Lembrete: Evento Amanhã! 📅",
          body: `${booking.eventName} é amanhã!`,
          type: "reminder_event",
          data: {bookingId: doc.id},
        });

        const supplierUserId = await getSupplierUserId(booking.supplierId);
        if (supplierUserId) {
          await sendPushNotification({
            userId: supplierUserId,
            title: "Lembrete: Serviço Amanhã! 📅",
            body: `${booking.eventName} é amanhã!`,
            type: "reminder_event",
            data: {bookingId: doc.id},
          });
        }
      }

      console.log(`Sent reminders for ${bookings.docs.length} events`);
      return null;
    });

export const updateSupplierStats = region.pubsub
    .schedule("0 0 * * 0")
    .timeZone("Africa/Luanda")
    .onRun(async () => {
      const suppliers = await db.collection("suppliers").get();

      for (const supplierDoc of suppliers.docs) {
        const supplierId = supplierDoc.id;

        const bookings = await db
            .collection("bookings")
            .where("supplierId", "==", supplierId)
            .where("status", "==", "completed")
            .get();

        const chats = await db
            .collection("chats")
            .where("supplierId", "==", supplierId)
            .get();

        const totalChats = chats.docs.length;
        let respondedChats = 0;

        for (const chatDoc of chats.docs) {
          const messages = await db
              .collection("chats")
              .doc(chatDoc.id)
              .collection("messages")
              .where("senderId", "==", supplierDoc.data().userId)
              .limit(1)
              .get();

          if (!messages.empty) {
            respondedChats++;
          }
        }

        const responseRate = totalChats > 0 ?
          (respondedChats / totalChats) * 100 : 0;

        await db.collection("suppliers").doc(supplierId).update({
          completedBookings: bookings.docs.length,
          responseRate: Math.round(responseRate),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      console.log(`Updated stats for ${suppliers.docs.length} suppliers`);
      return null;
    });

export const cleanupInactiveUsers = region.pubsub
    .schedule("0 0 1 * *")
    .timeZone("Africa/Luanda")
    .onRun(async () => {
      const sixMonthsAgo = new Date();
      sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

      const users = await db
          .collection("users")
          .where("updatedAt", "<",
              admin.firestore.Timestamp.fromDate(sixMonthsAgo))
          .where("isActive", "==", true)
          .get();

      for (const userDoc of users.docs) {
        await userDoc.ref.update({
          isActive: false,
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deactivationReason: "inactivity_6_months",
        });
      }

      console.log(`Deactivated ${users.docs.length} inactive users`);
      return null;
    });

/**
 * Auto-expire pending bookings that haven't been responded to
 * Runs daily at midnight, expires bookings pending for more than 7 days
 */
export const expirePendingBookings = region.pubsub
    .schedule("0 0 * * *") // Midnight daily
    .timeZone("Africa/Luanda")
    .onRun(async () => {
      const EXPIRE_DAYS = 7;
      const expireCutoff = new Date();
      expireCutoff.setDate(expireCutoff.getDate() - EXPIRE_DAYS);

      // Find all pending bookings older than EXPIRE_DAYS
      const pendingBookings = await db
          .collection("bookings")
          .where("status", "==", "pending")
          .where("createdAt", "<",
              admin.firestore.Timestamp.fromDate(expireCutoff))
          .get();

      let expiredCount = 0;
      const now = admin.firestore.FieldValue.serverTimestamp();

      for (const bookingDoc of pendingBookings.docs) {
        const booking = bookingDoc.data();

        try {
          // Update booking to expired status
          await bookingDoc.ref.update({
            status: "expired",
            expiredAt: now,
            updatedAt: now,
            expirationReason: `Auto-expired: No response for ${EXPIRE_DAYS} days`,
          });

          // Notify client that booking expired
          await sendPushNotification({
            userId: booking.clientId,
            title: "Pedido Expirado",
            body: `O pedido para ${booking.eventName || "seu evento"} expirou sem resposta`,
            type: "booking_expired",
            data: {bookingId: bookingDoc.id},
          });

          // Notify supplier about expired booking
          const supplierUserId = await getSupplierUserId(booking.supplierId);
          if (supplierUserId) {
            await sendPushNotification({
              userId: supplierUserId,
              title: "Pedido Expirou ⏰",
              body: "Um pedido expirou por falta de resposta",
              type: "booking_expired",
              data: {bookingId: bookingDoc.id},
            });
          }

          // Create audit log
          await db.collection("audit_logs").add({
            category: "booking",
            eventType: "autoExpired",
            userId: "system",
            resourceId: bookingDoc.id,
            resourceType: "booking",
            previousValue: "pending",
            newValue: "expired",
            description: `Booking auto-expired after ${EXPIRE_DAYS} days without response`,
            metadata: {
              bookingId: bookingDoc.id,
              clientId: booking.clientId,
              supplierId: booking.supplierId,
              daysWaiting: EXPIRE_DAYS,
            },
            timestamp: now,
          });

          expiredCount++;
        } catch (error) {
          console.error(`Error expiring booking ${bookingDoc.id}:`, error);
        }
      }

      console.log(`Auto-expired ${expiredCount} pending bookings`);
      return null;
    });

// ==================== HTTP FUNCTIONS ====================

export const healthCheck = region.https.onRequest((req, res) => {
  res.status(200).json({
    status: "healthy",
    region: REGION,
    timestamp: new Date().toISOString(),
    version: "1.0.0",
  });
});

export const sendPromoNotification = region.https.onCall(
    async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Must be authenticated"
        );
      }

      const userDoc = await db.collection("users").doc(context.auth.uid).get();
      const isAdmin = userDoc.data()?.role === "admin";
      if (!isAdmin) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Admin access required"
        );
      }

      const {title, body, targetType} = data;

      if (!title || !body) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Title and body are required"
        );
      }

      let usersQuery: admin.firestore.Query = db
          .collection("users")
          .where("isActive", "==", true);

      if (targetType === "suppliers") {
        usersQuery = usersQuery.where("userType", "==", "supplier");
      } else if (targetType === "clients") {
        usersQuery = usersQuery.where("userType", "==", "client");
      }

      const users = await usersQuery.get();
      let sentCount = 0;

      for (const userDoc of users.docs) {
        try {
          await sendPushNotification({
            userId: userDoc.id,
            title,
            body,
            type: "promotional",
          });
          sentCount++;
        } catch (error) {
          console.error(`Failed to notify ${userDoc.id}:`, error);
        }
      }

      console.log(`Promo sent to ${sentCount} users`);
      return {success: true, sentCount};
    }
);

export const generateSupplierReport = region.https.onCall(
    async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Must be authenticated"
        );
      }

      const {supplierId, startDate, endDate} = data;

      const supplierDoc = await db
          .collection("suppliers")
          .doc(supplierId)
          .get();
      if (supplierDoc.data()?.userId !== context.auth.uid) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Not authorized"
        );
      }

      const start = new Date(startDate);
      const end = new Date(endDate);

      const bookings = await db
          .collection("bookings")
          .where("supplierId", "==", supplierId)
          .where("createdAt", ">=",
              admin.firestore.Timestamp.fromDate(start))
          .where("createdAt", "<=",
              admin.firestore.Timestamp.fromDate(end))
          .get();

      let totalRevenue = 0;
      let completedCount = 0;
      let cancelledCount = 0;
      const bookingsByStatus: Record<string, number> = {};

      for (const doc of bookings.docs) {
        const booking = doc.data();

        bookingsByStatus[booking.status] =
          (bookingsByStatus[booking.status] || 0) + 1;

        if (booking.status === "completed") {
          totalRevenue += booking.paidAmount || 0;
          completedCount++;
        } else if (booking.status === "cancelled") {
          cancelledCount++;
        }
      }

      const reviews = await db
          .collection("reviews")
          .where("supplierId", "==", supplierId)
          .where("createdAt", ">=",
              admin.firestore.Timestamp.fromDate(start))
          .where("createdAt", "<=",
              admin.firestore.Timestamp.fromDate(end))
          .get();

      let totalRating = 0;
      for (const doc of reviews.docs) {
        totalRating += doc.data().rating;
      }

      const avgRating = reviews.docs.length > 0 ?
        totalRating / reviews.docs.length : 0;

      return {
        period: {start: startDate, end: endDate},
        bookings: {
          total: bookings.docs.length,
          completed: completedCount,
          cancelled: cancelledCount,
          byStatus: bookingsByStatus,
        },
        revenue: {
          total: totalRevenue,
          currency: "AOA",
        },
        reviews: {
          count: reviews.docs.length,
          averageRating: Math.round(avgRating * 10) / 10,
        },
      };
    }
);

// ==================== GDPR COMPLIANCE ====================

export const deleteUserData = region.https.onCall(
    async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Must be authenticated"
        );
      }

      if (context.auth.uid !== data.userId) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Can only delete your own data"
        );
      }

      const userId = data.userId;
      const batch = db.batch();

      try {
        const userRef = db.collection("users").doc(userId);
        batch.update(userRef, {
          name: "Utilizador Removido",
          email: null,
          phone: null,
          photoUrl: null,
          fcmToken: null,
          location: null,
          isDeleted: true,
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const chats = await db
            .collection("chats")
            .where("participants", "array-contains", userId)
            .get();

        for (const chatDoc of chats.docs) {
          const chatData = chatDoc.data();
          if (chatData.clientId === userId) {
            batch.update(chatDoc.ref, {clientName: "Utilizador Removido"});
          } else if (chatData.supplierId === userId) {
            batch.update(chatDoc.ref, {supplierName: "Utilizador Removido"});
          }
        }

        const notifications = await db
            .collection("notifications")
            .where("userId", "==", userId)
            .get();

        for (const doc of notifications.docs) {
          batch.delete(doc.ref);
        }

        const favorites = await db
            .collection("favorites")
            .where("clientId", "==", userId)
            .get();

        for (const doc of favorites.docs) {
          batch.delete(doc.ref);
        }

        await batch.commit();

        console.log(`User data deleted for: ${userId}`);
        return {success: true, message: "Dados removidos com sucesso"};
      } catch (error) {
        console.error(`Error deleting user data: ${error}`);
        throw new functions.https.HttpsError(
            "internal",
            "Erro ao remover dados"
        );
      }
    }
);

export const exportUserData = region.https.onCall(
    async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Must be authenticated"
        );
      }

      if (context.auth.uid !== data.userId) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Can only export your own data"
        );
      }

      const userId = data.userId;

      try {
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();

        const bookingsSnap = await db
            .collection("bookings")
            .where("clientId", "==", userId)
            .get();
        const bookings = bookingsSnap.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        const reviewsSnap = await db
            .collection("reviews")
            .where("clientId", "==", userId)
            .get();
        const reviews = reviewsSnap.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        const favoritesSnap = await db
            .collection("favorites")
            .where("clientId", "==", userId)
            .get();
        const favorites = favoritesSnap.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        console.log(`User data exported for: ${userId}`);
        return {
          success: true,
          exportDate: new Date().toISOString(),
          data: {
            profile: userData,
            bookings,
            reviews,
            favorites,
          },
        };
      } catch (error) {
        console.error(`Error exporting user data: ${error}`);
        throw new functions.https.HttpsError(
            "internal",
            "Erro ao exportar dados"
        );
      }
    }
);

// ==================== SECURITY ALERTING ====================

/**
 * Monitor audit logs for critical security events and send alerts
 */
export const onSecurityEvent = region.firestore
    .document("audit_logs/{logId}")
    .onCreate(async (snap) => {
      const log = snap.data();

      // Only alert on security category events
      if (log.category !== "security") {
        return null;
      }

      const severity = log.severity as string;
      const eventType = log.eventType as string;

      // Critical events that require immediate attention
      const criticalEvents = [
        "bruteForceAttempt",
        "accountTakeover",
        "suspiciousLogin",
        "unauthorizedAccess",
        "dataExfiltration",
        "privilegeEscalation",
      ];

      if (severity === "critical" || criticalEvents.includes(eventType)) {
        // Create admin notification
        await db.collection("admin_notifications").add({
          type: "security_alert",
          priority: "high",
          title: `🚨 Security Alert: ${eventType}`,
          body: log.description || `Critical security event detected for user ${log.userId}`,
          userId: log.userId,
          eventType: eventType,
          metadata: log.metadata || {},
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Send push notification to all admins
        const admins = await db
            .collection("users")
            .where("role", "==", "admin")
            .get();

        for (const adminDoc of admins.docs) {
          const fcmToken = adminDoc.data()?.fcmToken;
          if (fcmToken) {
            try {
              await messaging.send({
                token: fcmToken,
                notification: {
                  title: "🚨 Security Alert",
                  body: `${eventType}: ${log.description || "Critical event detected"}`,
                },
                data: {
                  type: "security_alert",
                  eventType: eventType,
                  userId: log.userId || "",
                },
                android: {
                  priority: "high",
                  notification: {
                    channelId: "security_alerts",
                    sound: "default",
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                      badge: 1,
                      "content-available": 1,
                    },
                  },
                },
              });
            } catch (error) {
              console.error(`Failed to send alert to admin ${adminDoc.id}:`, error);
            }
          }
        }

        console.log(`🚨 Security alert sent: ${eventType} for user ${log.userId}`);
      }

      return null;
    });

/**
 * Monitor failed login attempts and detect brute force
 */
export const onFailedLogin = region.firestore
    .document("audit_logs/{logId}")
    .onCreate(async (snap) => {
      const log = snap.data();

      // Only process failed login events
      if (log.category !== "authentication" ||
          log.eventType !== "loginFailed") {
        return null;
      }

      const userId = log.userId as string;
      const fiveMinutesAgo = new Date();
      fiveMinutesAgo.setMinutes(fiveMinutesAgo.getMinutes() - 5);

      // Count failed attempts in last 5 minutes
      const failedAttempts = await db
          .collection("audit_logs")
          .where("userId", "==", userId)
          .where("category", "==", "authentication")
          .where("eventType", "==", "loginFailed")
          .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(fiveMinutesAgo))
          .count()
          .get();

      const count = failedAttempts.data().count;

      if (count >= 5) {
        // Potential brute force attack
        await db.collection("audit_logs").add({
          category: "security",
          eventType: "bruteForceAttempt",
          userId: userId,
          description: `${count} failed login attempts in 5 minutes`,
          severity: "critical",
          metadata: {
            failedAttempts: count,
            windowMinutes: 5,
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Lock the account temporarily
        await db.collection("users").doc(userId).update({
          isLocked: true,
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
          lockReason: "brute_force_protection",
          lockUntil: admin.firestore.Timestamp.fromDate(
              new Date(Date.now() + 15 * 60 * 1000) // 15 minutes
          ),
        });

        console.log(`🔒 Account locked due to brute force: ${userId}`);
      }

      return null;
    });

/**
 * Monitor for suspicious location changes (impossible travel)
 */
export const onLocationAnomalyDetected = region.firestore
    .document("login_locations/{locationId}")
    .onCreate(async (snap) => {
      const location = snap.data();
      const userId = location.userId as string;

      // Get previous login location
      const previousLocations = await db
          .collection("login_locations")
          .where("userId", "==", userId)
          .where("latitude", "!=", null)
          .orderBy("latitude")
          .orderBy("timestamp", "desc")
          .limit(2)
          .get();

      if (previousLocations.docs.length < 2) {
        return null;
      }

      const current = previousLocations.docs[0].data();
      const previous = previousLocations.docs[1].data();

      if (!current.latitude || !previous.latitude) {
        return null;
      }

      // Calculate distance (simplified)
      const distance = calculateDistance(
          current.latitude,
          current.longitude,
          previous.latitude,
          previous.longitude
      );

      const currentTime = current.timestamp.toDate();
      const previousTime = previous.timestamp.toDate();
      const hoursDiff = (currentTime.getTime() - previousTime.getTime()) / (1000 * 60 * 60);

      // Max realistic speed: 900 km/h (airplane)
      const requiredSpeed = hoursDiff > 0 ? distance / hoursDiff : 0;

      if (requiredSpeed > 900) {
        // Impossible travel detected
        await db.collection("audit_logs").add({
          category: "security",
          eventType: "suspiciousLogin",
          userId: userId,
          description: `Impossible travel: ${Math.round(distance)}km in ${hoursDiff.toFixed(1)}h`,
          severity: "critical",
          metadata: {
            distanceKm: distance,
            hoursDiff: hoursDiff,
            requiredSpeedKmh: requiredSpeed,
            currentCity: current.city,
            previousCity: previous.city,
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`⚠️ Impossible travel detected for ${userId}`);
      }

      return null;
    });

/**
 * Calculate distance between two coordinates using Haversine formula
 */
function calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Daily security report generation
 */
export const generateDailySecurityReport = region.pubsub
    .schedule("0 8 * * *") // 8 AM daily
    .timeZone("Africa/Luanda")
    .onRun(async () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const yesterdayTs = admin.firestore.Timestamp.fromDate(yesterday);
      const todayTs = admin.firestore.Timestamp.fromDate(today);

      // Gather metrics
      const failedLogins = await db
          .collection("audit_logs")
          .where("category", "==", "authentication")
          .where("success", "==", false)
          .where("timestamp", ">=", yesterdayTs)
          .where("timestamp", "<", todayTs)
          .count()
          .get();

      const securityEvents = await db
          .collection("audit_logs")
          .where("category", "==", "security")
          .where("timestamp", ">=", yesterdayTs)
          .where("timestamp", "<", todayTs)
          .count()
          .get();

      const criticalEvents = await db
          .collection("audit_logs")
          .where("category", "==", "security")
          .where("severity", "==", "critical")
          .where("timestamp", ">=", yesterdayTs)
          .where("timestamp", "<", todayTs)
          .count()
          .get();

      const lockedAccounts = await db
          .collection("users")
          .where("isLocked", "==", true)
          .count()
          .get();

      const newUsers = await db
          .collection("users")
          .where("createdAt", ">=", yesterdayTs)
          .where("createdAt", "<", todayTs)
          .count()
          .get();

      // Create report
      const report = {
        date: yesterday.toISOString().split("T")[0],
        generatedAt: new Date().toISOString(),
        metrics: {
          failedLogins: failedLogins.data().count,
          securityEvents: securityEvents.data().count,
          criticalEvents: criticalEvents.data().count,
          lockedAccounts: lockedAccounts.data().count,
          newUsers: newUsers.data().count,
        },
        status: criticalEvents.data().count > 0 ? "attention_required" : "healthy",
      };

      await db.collection("security_reports").add(report);

      // Notify admins if there were critical events
      if (criticalEvents.data().count > 0) {
        const admins = await db
            .collection("users")
            .where("role", "==", "admin")
            .get();

        for (const adminDoc of admins.docs) {
          await db.collection("notifications").add({
            userId: adminDoc.id,
            title: "📊 Daily Security Report",
            body: `${criticalEvents.data().count} critical security events detected yesterday`,
            type: "security_report",
            data: report,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      console.log(`📊 Daily security report generated: ${JSON.stringify(report.metrics)}`);
      return null;
    });