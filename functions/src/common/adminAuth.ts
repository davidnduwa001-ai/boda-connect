import * as admin from "firebase-admin";

/**
 * Canonical admin check utility
 *
 * This is the SINGLE SOURCE OF TRUTH for admin verification across all Cloud Functions.
 * Uses the same combined check pattern as the admin/ functions.
 *
 * Check order:
 * 1. Custom claims (preferred, most secure - set via Firebase Admin SDK)
 * 2. Firestore user.role field (legacy support)
 * 3. Firestore user.isAdmin field (legacy support)
 *
 * This ensures consistency with:
 * - Firestore rules (which use custom claims only for maximum security)
 * - Admin Cloud Functions (which use the combined check for backwards compatibility)
 */
export async function isAdminUser(uid: string): Promise<boolean> {
  // 1. Check custom claims first (preferred, most secure)
  try {
    const userRecord = await admin.auth().getUser(uid);
    if (userRecord.customClaims?.admin === true) {
      return true;
    }
  } catch (e) {
    // User may not exist in Auth, continue to Firestore check
    // This can happen in rare edge cases during user deletion
  }

  // 2. Fallback to Firestore fields (legacy support)
  // This ensures existing admins set via Firestore continue to work
  // until they are migrated to custom claims
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      // Check both role === "admin" and isAdmin === true for backwards compatibility
      if (data?.role === "admin" || data?.isAdmin === true) {
        return true;
      }
    }
  } catch (e) {
    // Firestore read failed, user is not admin
  }

  return false;
}

/**
 * Check if user is a supplier (owns a supplier profile)
 * Used for authorization in booking/escrow operations
 */
export async function isSupplierUser(
  supplierId: string,
  userId: string
): Promise<boolean> {
  try {
    const supplierDoc = await admin
      .firestore()
      .collection("suppliers")
      .doc(supplierId)
      .get();

    if (!supplierDoc.exists) {
      return false;
    }

    const supplier = supplierDoc.data();
    return supplier?.userId === userId;
  } catch (e) {
    return false;
  }
}
