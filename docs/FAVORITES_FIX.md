# Favorites/Like Feature Fix

## Problem Identified

When trying to like/favorite a supplier, the feature was not working due to a **mismatch between the code implementation and Firestore security rules**.

### Root Cause

**Code Implementation:**
- `favorites_provider.dart` was trying to store favorites as an array field in the `users/{userId}` document
- Used: `users.doc(userId).update({ 'favorites': FieldValue.arrayUnion([supplierId]) })`

**Firestore Security Rules:**
- Expected a separate `favorites` collection
- Documents formatted as: `favorites/{userId_supplierId}`
- Contains: `{ userId, supplierId, createdAt }`

This mismatch caused permission denied errors when trying to add/remove favorites.

---

## Solution Applied

Updated [`lib/core/providers/favorites_provider.dart`](../lib/core/providers/favorites_provider.dart) to match the Firestore security rules:

### Changes Made

#### 1. Load Favorites (lines 48-100)
**Before:**
```dart
// Tried to read from users document
final userDoc = await _firestore.collection('users').doc(userId).get();
final favoriteIds = List<String>.from(userDoc.data()?['favorites'] ?? []);
```

**After:**
```dart
// Query favorites collection
final favoritesSnapshot = await _firestore
    .collection('favorites')
    .where('userId', isEqualTo: userId)
    .get();

final favoriteIds = favoritesSnapshot.docs
    .map((doc) => doc.data()['supplierId'] as String)
    .toList();
```

#### 2. Add Favorite (lines 102-132)
**Before:**
```dart
// Tried to update users document array
await _firestore.collection('users').doc(userId).update({
  'favorites': FieldValue.arrayUnion([supplierId]),
});
```

**After:**
```dart
// Create document in favorites collection
final favoriteId = '${userId}_$supplierId';
await _firestore.collection('favorites').doc(favoriteId).set({
  'userId': userId,
  'supplierId': supplierId,
  'createdAt': FieldValue.serverTimestamp(),
});
```

#### 3. Remove Favorite (lines 134-152)
**Before:**
```dart
// Tried to update users document array
await _firestore.collection('users').doc(userId).update({
  'favorites': FieldValue.arrayRemove([supplierId]),
});
```

**After:**
```dart
// Delete document from favorites collection
final favoriteId = '${userId}_$supplierId';
await _firestore.collection('favorites').doc(favoriteId).delete();
```

#### 4. Clear All Favorites (lines 157-181)
**Before:**
```dart
// Tried to clear array in users document
await _firestore.collection('users').doc(userId).update({
  'favorites': [],
});
```

**After:**
```dart
// Query and batch delete all favorites
final favoritesSnapshot = await _firestore
    .collection('favorites')
    .where('userId', isEqualTo: userId)
    .get();

final batch = _firestore.batch();
for (final doc in favoritesSnapshot.docs) {
  batch.delete(doc.reference);
}
await batch.commit();
```

---

## Testing the Fix

### Prerequisites
1. Ensure app is running
2. Logged in as a **Client** user
3. Firebase/Firestore is properly configured

### Test Steps

#### Test 1: Add a Favorite
1. Navigate to any supplier detail screen
2. Look for the heart icon (❤️ outline) in the app bar
3. Tap the heart icon
4. ✅ **Expected Result:**
   - Heart icon becomes filled (❤️ solid)
   - Icon turns red
   - No error messages appear

5. **Verify in Firebase Console:**
   - Go to Firestore Database → `favorites` collection
   - You should see a new document with ID: `{yourUserId}_{supplierId}`
   - Document should contain:
     ```json
     {
       "userId": "your-user-id",
       "supplierId": "supplier-id",
       "createdAt": "2025-01-21T..."
     }
     ```

#### Test 2: Remove a Favorite
1. On the same supplier detail screen (with filled heart)
2. Tap the heart icon again
3. ✅ **Expected Result:**
   - Heart icon becomes outline (❤️ outline)
   - Icon turns gray/black
   - No error messages appear

4. **Verify in Firebase Console:**
   - Go to Firestore Database → `favorites` collection
   - The document `{yourUserId}_{supplierId}` should be deleted

#### Test 3: View Favorites Screen
1. Navigate to "Favoritos" screen from main menu
2. Add 2-3 suppliers to favorites first
3. Open "Favoritos" screen
4. ✅ **Expected Result:**
   - All favorited suppliers are displayed
   - Supplier cards show correct information
   - Tapping a card navigates to supplier detail

#### Test 4: Persistence Test
1. Add a supplier to favorites
2. Close the app completely
3. Reopen the app and log in
4. Navigate to the same supplier detail screen
5. ✅ **Expected Result:**
   - Heart icon is still filled (favorite persisted)
   - Favorites screen still shows the supplier

#### Test 5: Multi-Device Sync
1. **Device 1:** Log in as client, add supplier to favorites
2. **Device 2:** Log in with the same client account
3. Navigate to "Favoritos" screen
4. ✅ **Expected Result:**
   - Favorite added from Device 1 appears on Device 2
   - May need to reload/refresh the favorites screen

---

## Error Handling

The provider now includes better error messages with details:

- **Before:** `'Erro ao adicionar favorito'`
- **After:** `'Erro ao adicionar favorito: {actual error message}'`

This helps debug any remaining issues.

### Common Errors

#### "Permission denied"
- **Cause:** Firestore rules not deployed or user not authenticated
- **Fix:** Run `firebase deploy --only firestore:rules`

#### "Document not found"
- **Cause:** Trying to remove a favorite that doesn't exist
- **Fix:** This is handled gracefully, no action needed

#### "Failed to load favorites"
- **Cause:** Network issue or Firestore not configured
- **Fix:** Check internet connection and Firebase configuration

---

## Database Structure

### Favorites Collection Schema

```
favorites (collection)
├── {userId}_{supplierId} (document)
│   ├── userId: string (required)
│   ├── supplierId: string (required)
│   └── createdAt: timestamp (required)
└── ...
```

### Example Document

```json
{
  "userId": "abc123def456",
  "supplierId": "supplier789xyz",
  "createdAt": {
    "_seconds": 1737462000,
    "_nanoseconds": 123456000
  }
}
```

### Document ID Format

- Format: `{userId}_{supplierId}`
- Example: `abc123def456_supplier789xyz`
- This format allows:
  - Easy lookups by userId (query where)
  - Direct access by document ID
  - Prevents duplicate favorites (same ID = same favorite)

---

## Security Rules

The relevant Firestore security rules (already deployed):

```javascript
// Favorites collection - user can only access their own
match /favorites/{favoriteId} {
  allow read: if request.auth != null &&
    request.auth.uid == favoriteId.split('_')[0]; // Format: userId_supplierId

  allow create: if request.auth != null &&
    request.auth.uid == request.resource.data.userId;

  allow update, delete: if request.auth != null &&
    (favoriteId.split('_')[0] == request.auth.uid ||
     (exists(/databases/$(database)/documents/favorites/$(favoriteId)) &&
      get(/databases/$(database)/documents/favorites/$(favoriteId)).data.userId == request.auth.uid));
}
```

These rules ensure:
- Users can only read their own favorites
- Users can only create favorites for themselves
- Users can only delete their own favorites
- Document ID format is enforced: `userId_supplierId`

---

## Files Modified

1. **[lib/core/providers/favorites_provider.dart](../lib/core/providers/favorites_provider.dart)**
   - Updated all CRUD operations to use `favorites` collection
   - Added better error messages with details
   - Changed from array-based to document-based storage

---

## Quick Verification Checklist

Use this checklist to quickly verify the fix:

- [ ] Heart icon appears on supplier detail screen
- [ ] Tapping heart toggles between filled/outline
- [ ] No error messages when tapping heart
- [ ] Favorites persist after app restart
- [ ] Favoritos screen shows all favorited suppliers
- [ ] Firebase Console shows documents in `favorites` collection
- [ ] Document IDs follow format: `userId_supplierId`
- [ ] Can remove favorites by tapping heart again
- [ ] Document is deleted from Firebase when unfavoriting

---

## Before vs After

### Before (Broken)
```
User taps heart → Code tries to update users/{userId} document
→ Firestore rules reject (no 'favorites' field allowed)
→ Permission denied error → Heart doesn't fill → Feature broken
```

### After (Fixed)
```
User taps heart → Code creates favorites/{userId_supplierId} document
→ Firestore rules allow (matches expected structure)
→ Success → Heart fills red → Feature works! ✅
```

---

## Next Steps

If the favorites feature still doesn't work after this fix:

1. **Check Flutter Console** for error messages
2. **Check Firebase Console** → Firestore → Check if documents are being created
3. **Verify Authentication** - User must be logged in
4. **Verify Security Rules** - Rules must be deployed
5. **Try Hot Restart** - Sometimes hot reload isn't enough

If you see any errors, copy the exact error message for debugging.
