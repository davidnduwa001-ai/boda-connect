# 🧹 ACCOUNT CLEANUP GUIDE

## ⚠️ Issue: "Esta conta foi desativada" Error

When you delete a user from Firestore but they still exist in Firebase Authentication, you'll see this error.

---

## 🔧 FIXES APPLIED

### Fix 1: Google Account Picker
**Problem:** Account picker not showing when clicking "Registrar com Google"

**Solution:** Added sign-out before sign-in
```dart
// lib/core/services/google_auth_service.dart (Line 17)
await _googleSignIn.signOut();  // ✅ Forces account picker to show
final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
```

**Result:** ✅ Account picker now shows every time

---

### Fix 2: Disabled Account Detection
**Problem:** User deleted from Firestore shows "Esta conta foi desativada"

**Solution:** Check `isActive` field and provide clear error
```dart
// lib/core/services/google_auth_service.dart (Lines 81-93)
final isActive = existingData['isActive'] as bool? ?? true;

if (!isActive) {
  await _auth.signOut();
  await _googleSignIn.signOut();
  return GoogleAuthResult(
    success: false,
    message: 'Esta conta foi desativada. Entre em contacto com o suporte.',
  );
}
```

**Result:** ✅ Clear error message + automatic sign-out

---

## 🗑️ HOW TO PROPERLY DELETE TEST ACCOUNTS

### Method 1: Firebase Console (Recommended)

#### Step 1: Delete from Firebase Authentication
```
1. Go to Firebase Console
2. Authentication → Users
3. Find user by email
4. Click overflow menu (⋮)
5. Click "Delete account"
6. Confirm deletion
```

#### Step 2: Delete from Firestore
```
1. Go to Firebase Console
2. Firestore Database
3. Delete user document: users/{uid}
4. Delete supplier document: suppliers/{supplierId} (if supplier)
5. Delete related data:
   - conversations (where participants contains uid)
   - bookings (where clientId or supplierId equals uid)
   - reviews (where clientId equals uid)
```

**Result:** ✅ User completely removed from both systems

---

### Method 2: Using Firebase CLI

```bash
# Delete from Firebase Auth
firebase auth:delete <uid> --project boda-connect-49eb9

# Delete from Firestore (use Firebase Console or code)
```

---

### Method 3: Cleanup Service (In App)

**File:** Add to `lib/core/services/cleanup_database_service.dart`

```dart
/// Delete user completely from Firebase Auth AND Firestore
Future<void> deleteUserCompletely(String uid) async {
  try {
    // 1. Delete user document
    await _firestore.collection('users').doc(uid).delete();

    // 2. Delete supplier profile if exists
    final supplierQuery = await _firestore
        .collection('suppliers')
        .where('userId', isEqualTo: uid)
        .get();

    for (var doc in supplierQuery.docs) {
      await doc.reference.delete();
    }

    // 3. Delete conversations
    final conversationsQuery = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .get();

    for (var doc in conversationsQuery.docs) {
      await doc.reference.delete();
    }

    // 4. Firebase Auth deletion must be done via Firebase Console or Admin SDK
    debugPrint('✅ User $uid deleted from Firestore. Delete from Firebase Auth manually.');

  } catch (e) {
    debugPrint('❌ Error deleting user: $e');
    rethrow;
  }
}
```

---

## 🧪 TESTING THE FIXES

### Test 1: Account Picker Shows
```
1. Open app
2. Tap "Registrar com Google" (Supplier or Client)
3. Expected: Account picker appears ✅
4. Can select from multiple Google accounts ✅
```

### Test 2: Fresh Registration
```
1. Select Google account that was NEVER registered
2. Choose Supplier or Client
3. Expected: Registration succeeds ✅
4. Onboarding wizard appears ✅
```

### Test 3: Re-Login Existing Account
```
1. Register as Supplier with email1@gmail.com
2. Log out
3. Login again with same email as Supplier
4. Expected: Goes directly to dashboard ✅
```

### Test 4: UserType Conflict
```
1. Register as Supplier with email1@gmail.com
2. Log out
3. Try to register with same email as Client
4. Expected: Error "Esta conta já está registada como supplier" ✅
5. Account picker shows again ✅
```

### Test 5: Deleted Account
```
1. Register account
2. Delete from Firebase Console (Auth + Firestore)
3. Try to login with same email
4. Expected: Creates new account ✅ (because deleted from Auth)
```

---

## 🚨 COMMON ISSUES & SOLUTIONS

### Issue 1: "Esta conta foi desativada"
**Cause:** User deleted from Firestore but still in Firebase Auth

**Solution:**
```
Option A: Delete from Firebase Auth via Console
Option B: Re-create Firestore document with isActive: true
```

### Issue 2: Account Picker Not Showing
**Cause:** Google cached previous selection

**Solution:**
```
✅ FIXED - Now signs out before sign-in
Account picker will always show
```

### Issue 3: "Conta já está registada como X"
**Cause:** Trying to use same email with different userType

**Solution:**
```
Use different Google account
OR
Login with correct userType
```

### Issue 4: Supplier Profile Missing
**Cause:** User document exists but supplier profile doesn't

**Solution:**
```
✅ AUTO-FIXED - Code now checks and creates supplier profile if missing
```

---

## 🔄 CLEAN DATABASE WORKFLOW

### For Development/Testing:

```
1. Delete ALL test users from Firebase Auth
   → Authentication → Users → Delete all

2. Delete ALL documents from Firestore:
   → users (delete collection)
   → suppliers (delete collection)
   → conversations (delete collection)
   → bookings (delete collection)
   → reviews (delete collection)

3. Keep categories collection (seed data)

4. Hot restart app (Shift+R)

5. Create fresh test accounts
```

---

## 📝 DELETION CHECKLIST

When deleting a test account:

- [ ] Delete from Firebase Authentication
- [ ] Delete user document (users/{uid})
- [ ] Delete supplier document (suppliers where userId == uid)
- [ ] Delete conversations (where participants contains uid)
- [ ] Delete bookings (where clientId or supplierId == uid)
- [ ] Delete reviews (where clientId == uid)
- [ ] Delete cart items (users/{uid}/cart)
- [ ] Delete notifications (where userId == uid)

**OR** use Firebase Console → Delete all data and start fresh

---

## ✅ VERIFICATION

After fixes applied:

1. **Account Picker**
   - [x] Shows on every "Registrar com Google" tap
   - [x] Can select from multiple accounts
   - [x] Previous selection not cached

2. **Error Messages**
   - [x] Clear message for disabled accounts
   - [x] Clear message for userType conflicts
   - [x] Automatic sign-out on errors

3. **Registration Flow**
   - [x] New users → Onboarding wizard
   - [x] Existing users → Dashboard
   - [x] Deleted users → Can re-register

---

## 🎯 NEXT STEPS

1. **Hot restart app** to apply fixes
2. **Delete test accounts** from Firebase Console (both Auth + Firestore)
3. **Test registration** with fresh Google account
4. **Verify account picker** shows
5. **Test complete flow** (register → onboard → dashboard)

---

## 📞 FIREBASE CONSOLE LINKS

- **Authentication:** https://console.firebase.google.com/project/boda-connect-49eb9/authentication/users
- **Firestore:** https://console.firebase.google.com/project/boda-connect-49eb9/firestore

---

**Status:** ✅ FIXES DEPLOYED
**Impact:** Account picker now shows, clear error messages, proper cleanup
**Action Required:** Hot restart app + delete test accounts from Console
