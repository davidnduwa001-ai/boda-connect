import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();
const REGION = "us-central1";

// ==================== TYPES ====================

interface SendMessageRequest {
  conversationId: string;
  text?: string;
  type?: "text" | "image" | "quote" | "file";
  imageUrl?: string;
  quoteData?: {
    description: string;
    amount: number;
    currency: string;
    validUntil?: string;
  };
  fileUrl?: string;
  fileName?: string;
}

interface MessageResponse {
  success: boolean;
  messageId?: string;
  error?: string;
}

interface GetOrCreateConversationRequest {
  otherUserId: string;
  otherUserName?: string;
  otherUserPhoto?: string;
}

interface ConversationResponse {
  success: boolean;
  conversationId?: string;
  isNew?: boolean;
  error?: string;
}

// ==================== HELPER FUNCTIONS ====================

/**
 * Get supplier document ID from auth UID (if user is a supplier)
 * Suppliers may have their document ID different from their auth UID
 */
async function getSupplierDocumentId(authUid: string): Promise<string | null> {
  // First check if there's a supplier document with this ID directly
  const directDoc = await db.collection("suppliers").doc(authUid).get();
  if (directDoc.exists) {
    return authUid;
  }

  // Check if there's a supplier document where userId matches auth UID
  const supplierQuery = await db.collection("suppliers")
      .where("userId", "==", authUid)
      .limit(1)
      .get();

  if (!supplierQuery.empty) {
    return supplierQuery.docs[0].id;
  }

  return null;
}

/**
 * Check if user is participant in conversation
 * Handles the case where suppliers may have document ID != auth UID
 */
async function isParticipant(
    conversationId: string,
    userId: string
): Promise<boolean> {
  // Get all possible IDs for this user (auth UID and possibly supplier document ID)
  const userIds = new Set<string>([userId]);

  // Check if user is a supplier with a different document ID
  const supplierDocId = await getSupplierDocumentId(userId);
  if (supplierDocId && supplierDocId !== userId) {
    userIds.add(supplierDocId);
    console.log(`isParticipant: User ${userId} is supplier with document ID ${supplierDocId}`);
  }

  // Try conversations collection first
  let doc = await db.collection("conversations").doc(conversationId).get();
  if (doc.exists) {
    const participants = doc.data()?.participants as string[] || [];
    const clientId = doc.data()?.clientId as string | undefined;
    const supplierId = doc.data()?.supplierId as string | undefined;

    // Check if any of the user's IDs match participants, clientId, or supplierId
    for (const id of userIds) {
      if (participants.includes(id) || clientId === id || supplierId === id) {
        return true;
      }
    }
  }

  // Fallback to chats collection (legacy)
  doc = await db.collection("chats").doc(conversationId).get();
  if (doc.exists) {
    const participants = doc.data()?.participants as string[] || [];
    const clientId = doc.data()?.clientId as string | undefined;
    const supplierId = doc.data()?.supplierId as string | undefined;

    // Check if any of the user's IDs match
    for (const id of userIds) {
      if (participants.includes(id) || clientId === id || supplierId === id) {
        return true;
      }
    }
  }

  console.log(`isParticipant: User ${userId} (IDs: ${[...userIds].join(", ")}) not found in conversation ${conversationId}`);
  return false;
}

/**
 * Get user display info
 * Handles the case where suppliers may have document ID != auth UID
 */
async function getUserInfo(userId: string): Promise<{
  name: string;
  photo?: string;
  isSupplier: boolean;
}> {
  // Check if user is a supplier by document ID
  const supplierDoc = await db.collection("suppliers").doc(userId).get();
  if (supplierDoc.exists) {
    const data = supplierDoc.data()!;
    return {
      name: data.businessName || "Fornecedor",
      photo: data.logoUrl || data.profileImageUrl,
      isSupplier: true,
    };
  }

  // Check if user is a supplier by userId field (auth UID != document ID case)
  const supplierQuery = await db.collection("suppliers")
      .where("userId", "==", userId)
      .limit(1)
      .get();
  if (!supplierQuery.empty) {
    const data = supplierQuery.docs[0].data();
    return {
      name: data.businessName || "Fornecedor",
      photo: data.logoUrl || data.profileImageUrl,
      isSupplier: true,
    };
  }

  // Check users collection
  const userDoc = await db.collection("users").doc(userId).get();
  if (userDoc.exists) {
    const data = userDoc.data()!;
    return {
      name: data.name || data.displayName || "Utilizador",
      photo: data.photoUrl || data.photoURL,
      isSupplier: false,
    };
  }

  return {name: "Utilizador", isSupplier: false};
}

/**
 * Get the other participant in a conversation
 * Handles the case where suppliers may have document ID != auth UID
 */
async function getOtherParticipant(
    conversationId: string,
    currentUserId: string
): Promise<string | null> {
  // Get all possible IDs for current user
  const currentUserIds = new Set<string>([currentUserId]);
  const supplierDocId = await getSupplierDocumentId(currentUserId);
  if (supplierDocId && supplierDocId !== currentUserId) {
    currentUserIds.add(supplierDocId);
  }

  // Try conversations collection first
  let doc = await db.collection("conversations").doc(conversationId).get();
  if (!doc.exists) {
    doc = await db.collection("chats").doc(conversationId).get();
  }

  if (!doc.exists) return null;

  const data = doc.data()!;
  const participants = data.participants as string[] || [];
  const clientId = data.clientId as string | undefined;
  const supplierId = data.supplierId as string | undefined;

  // If we can identify clientId and supplierId, use those for more reliable matching
  // Check if current user is the client
  if (clientId && currentUserIds.has(clientId)) {
    return supplierId || participants.find((p) => !currentUserIds.has(p)) || null;
  }

  // Check if current user is the supplier
  if (supplierId && currentUserIds.has(supplierId)) {
    return clientId || participants.find((p) => !currentUserIds.has(p)) || null;
  }

  // Fallback: find participant that doesn't match any of current user's IDs
  return participants.find((p) => !currentUserIds.has(p)) || null;
}

// ==================== CLOUD FUNCTIONS ====================

/**
 * Send a message in a conversation
 *
 * Security: Validates that sender is a participant in the conversation
 */
export const sendMessage = functions
    .region(REGION)
    .https.onCall(async (data: SendMessageRequest, context): Promise<MessageResponse> => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      // 2. Validate input
      if (!data.conversationId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "conversationId é obrigatório"
        );
      }

      const messageType = data.type || "text";
      if (messageType === "text" && !data.text) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Mensagem não pode estar vazia"
        );
      }

      if (messageType === "image" && !data.imageUrl) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "URL da imagem é obrigatório"
        );
      }

      try {
        const senderId = context.auth.uid;

        // 3. Validate sender is participant
        const canSend = await isParticipant(data.conversationId, senderId);
        if (!canSend) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Não tem permissão para enviar mensagens nesta conversa"
          );
        }

        // 4. Get sender info
        const senderInfo = await getUserInfo(senderId);

        // 5. Get receiver ID
        const receiverId = await getOtherParticipant(data.conversationId, senderId);
        if (!receiverId) {
          throw new functions.https.HttpsError(
              "not-found",
              "Destinatário não encontrado"
          );
        }

        // 6. Create message document
        const now = admin.firestore.FieldValue.serverTimestamp();
        const messageData: Record<string, unknown> = {
          senderId,
          senderName: senderInfo.name,
          senderPhoto: senderInfo.photo,
          receiverId,
          type: messageType,
          timestamp: now,
          createdAt: now,
          isRead: false,
          readBy: [senderId],
        };

        // Add type-specific fields
        if (messageType === "text") {
          messageData.text = data.text;
        } else if (messageType === "image") {
          messageData.imageUrl = data.imageUrl;
          messageData.text = data.text || "";
        } else if (messageType === "quote" && data.quoteData) {
          messageData.quoteData = {
            description: data.quoteData.description,
            amount: data.quoteData.amount,
            currency: data.quoteData.currency || "AOA",
            validUntil: data.quoteData.validUntil,
          };
          messageData.text = data.text || "";
        } else if (messageType === "file") {
          messageData.fileUrl = data.fileUrl;
          messageData.fileName = data.fileName;
          messageData.text = data.text || "";
        }

        // 7. Write message - try conversations first, fallback to chats
        let messagesRef: FirebaseFirestore.CollectionReference;
        let conversationRef: FirebaseFirestore.DocumentReference;

        const convDoc = await db
            .collection("conversations")
            .doc(data.conversationId)
            .get();

        if (convDoc.exists) {
          conversationRef = db.collection("conversations").doc(data.conversationId);
          messagesRef = conversationRef.collection("messages");
        } else {
          conversationRef = db.collection("chats").doc(data.conversationId);
          messagesRef = conversationRef.collection("messages");
        }

        // Add the message
        const messageRef = await messagesRef.add(messageData);

        // 8. Update conversation with last message
        const lastMessagePreview = messageType === "text" ?
          (data.text || "").substring(0, 100) :
          messageType === "image" ? "📷 Imagem" :
          messageType === "quote" ? "💰 Orçamento" :
          messageType === "file" ? "📎 Arquivo" : "";

        await conversationRef.update({
          lastMessage: lastMessagePreview,
          lastMessageAt: now,
          lastMessageSenderId: senderId,
          updatedAt: now,
          // Increment unread count for receiver
          [`unreadCount.${receiverId}`]: admin.firestore.FieldValue.increment(1),
        });

        console.log(
            `sendMessage: Message ${messageRef.id} sent in conversation ${data.conversationId}`
        );

        return {
          success: true,
          messageId: messageRef.id,
        };
      } catch (error) {
        console.error("Error in sendMessage:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao enviar mensagem"
        );
      }
    });

/**
 * Get or create a conversation between two users
 *
 * Security: Any authenticated user can start a conversation
 */
export const getOrCreateConversation = functions
    .region(REGION)
    .https.onCall(async (
        data: GetOrCreateConversationRequest,
        context
    ): Promise<ConversationResponse> => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      // 2. Validate input
      if (!data.otherUserId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "otherUserId é obrigatório"
        );
      }

      try {
        const currentUserId = context.auth.uid;

        // Can't message yourself
        if (currentUserId === data.otherUserId) {
          throw new functions.https.HttpsError(
              "invalid-argument",
              "Não pode iniciar uma conversa consigo mesmo"
          );
        }

        // 3. Check for existing conversation
        const participants = [currentUserId, data.otherUserId].sort();

        // Try conversations collection first
        let existingQuery = await db
            .collection("conversations")
            .where("participants", "==", participants)
            .limit(1)
            .get();

        if (!existingQuery.empty) {
          return {
            success: true,
            conversationId: existingQuery.docs[0].id,
            isNew: false,
          };
        }

        // Try chats collection (legacy)
        existingQuery = await db
            .collection("chats")
            .where("participants", "==", participants)
            .limit(1)
            .get();

        if (!existingQuery.empty) {
          return {
            success: true,
            conversationId: existingQuery.docs[0].id,
            isNew: false,
          };
        }

        // Also check with array-contains (different order)
        existingQuery = await db
            .collection("conversations")
            .where("participants", "array-contains", currentUserId)
            .get();

        for (const doc of existingQuery.docs) {
          const docParticipants = doc.data().participants as string[];
          if (docParticipants.includes(data.otherUserId)) {
            return {
              success: true,
              conversationId: doc.id,
              isNew: false,
            };
          }
        }

        // 4. Create new conversation
        const currentUserInfo = await getUserInfo(currentUserId);
        const otherUserInfo = await getUserInfo(data.otherUserId);

        const now = admin.firestore.FieldValue.serverTimestamp();

        // Determine client/supplier roles
        const isCurrentUserSupplier = currentUserInfo.isSupplier;
        const isOtherUserSupplier = otherUserInfo.isSupplier;

        let clientId: string;
        let clientName: string;
        let supplierId: string;
        let supplierName: string;

        if (isCurrentUserSupplier && !isOtherUserSupplier) {
          // Current user is supplier, other is client
          supplierId = currentUserId;
          supplierName = currentUserInfo.name;
          clientId = data.otherUserId;
          clientName = otherUserInfo.name;
        } else if (!isCurrentUserSupplier && isOtherUserSupplier) {
          // Current user is client, other is supplier
          clientId = currentUserId;
          clientName = currentUserInfo.name;
          supplierId = data.otherUserId;
          supplierName = otherUserInfo.name;
        } else {
          // Both same type - use alphabetical order
          if (currentUserId < data.otherUserId) {
            clientId = currentUserId;
            clientName = currentUserInfo.name;
            supplierId = data.otherUserId;
            supplierName = otherUserInfo.name;
          } else {
            clientId = data.otherUserId;
            clientName = otherUserInfo.name;
            supplierId = currentUserId;
            supplierName = currentUserInfo.name;
          }
        }

        const conversationData = {
          participants,
          clientId,
          clientName,
          clientPhoto: isCurrentUserSupplier ?
            otherUserInfo.photo : currentUserInfo.photo,
          supplierId,
          supplierName,
          supplierPhoto: isCurrentUserSupplier ?
            currentUserInfo.photo : otherUserInfo.photo,
          lastMessage: "",
          lastMessageAt: now,
          createdAt: now,
          updatedAt: now,
          unreadCount: {
            [currentUserId]: 0,
            [data.otherUserId]: 0,
          },
        };

        // Create in conversations collection (new structure)
        const conversationRef = await db
            .collection("conversations")
            .add(conversationData);

        console.log(
            `getOrCreateConversation: Created new conversation ${conversationRef.id}`
        );

        return {
          success: true,
          conversationId: conversationRef.id,
          isNew: true,
        };
      } catch (error) {
        console.error("Error in getOrCreateConversation:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao criar conversa"
        );
      }
    });

/**
 * Mark messages as read in a conversation
 *
 * Security: Only participants can mark messages as read
 */
export const markConversationAsRead = functions
    .region(REGION)
    .https.onCall(async (
        data: {conversationId: string},
        context
    ) => {
      // 1. Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Autenticação necessária"
        );
      }

      // 2. Validate input
      if (!data.conversationId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "conversationId é obrigatório"
        );
      }

      try {
        const userId = context.auth.uid;

        // 3. Validate participant
        const canAccess = await isParticipant(data.conversationId, userId);
        if (!canAccess) {
          throw new functions.https.HttpsError(
              "permission-denied",
              "Não tem acesso a esta conversa"
          );
        }

        // 4. Find conversation reference
        let conversationRef: FirebaseFirestore.DocumentReference;
        const convDoc = await db
            .collection("conversations")
            .doc(data.conversationId)
            .get();

        if (convDoc.exists) {
          conversationRef = db.collection("conversations").doc(data.conversationId);
        } else {
          conversationRef = db.collection("chats").doc(data.conversationId);
        }

        // 5. Reset unread count for this user
        await conversationRef.update({
          [`unreadCount.${userId}`]: 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 6. Mark unread messages as read (batch update)
        const messagesRef = conversationRef.collection("messages");
        const unreadMessages = await messagesRef
            .where("receiverId", "==", userId)
            .where("isRead", "==", false)
            .get();

        if (!unreadMessages.empty) {
          const batch = db.batch();
          for (const doc of unreadMessages.docs) {
            batch.update(doc.ref, {
              isRead: true,
              readAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }

        console.log(
            `markConversationAsRead: Marked ${unreadMessages.docs.length} messages as read`
        );

        return {
          success: true,
          markedCount: unreadMessages.docs.length,
        };
      } catch (error) {
        console.error("Error in markConversationAsRead:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao marcar mensagens como lidas"
        );
      }
    });
