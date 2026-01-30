# CLIENT REGISTRATION - FINAL FIX

## Date: 2026-01-22

---

## Issue Summary

Client registration was failing with permission denied error:
```
W/Firestore: Write failed at users/jOeZPrVxdpYifxCS6M4pj0e7pcl2
Status{code=PERMISSION_DENIED}
❌ Error saving client details: [cloud_firestore/permission-denied]
```

---

## Root Cause Analysis

### Problem 1: Null Values Not Allowed

**Firestore Rule (Before):**
```javascript
allow create: if request.auth != null && request.auth.uid == userId &&
  request.resource.data.keys().hasAll(['userType']) &&
  (!request.resource.data.keys().hasAny(['phone']) || request.resource.data.phone is string) &&
  request.resource.data.userType in ['client', 'supplier'];
```

**What We Were Sending:**
```dart
{
  'userType': 'client',
  'name': 'David Nduwa',
  'email': null,  // ❌ Field exists but value is null
  'phone': null,  // ❌ Field exists but value is null
  // ...
}
```

**Why It Failed:**
- Rule checked: `(!hasAny(['phone']) || phone is string)`
- We sent: `'phone': null`
- Evaluation:
  - `hasAny(['phone'])` = **TRUE** (key exists)
  - `phone is string` = **FALSE** (null is not a string)
  - Result: **FALSE** → **PERMISSION DENIED**

---

## Fix Applied

### 1. Updated Firestore Rules

**File:** `firestore.rules` (lines 18-30)

**Before:**
```javascript
allow create: if request.auth != null && request.auth.uid == userId &&
  request.resource.data.keys().hasAll(['userType']) &&
  (!request.resource.data.keys().hasAny(['phone']) || request.resource.data.phone is string) &&
  request.resource.data.userType in ['client', 'supplier'];
```

**After:**
```javascript
allow create: if request.auth != null && request.auth.uid == userId &&
  request.resource.data.keys().hasAll(['userType']) &&
  // Phone can be null for Google sign-in, but must be string if provided
  (!request.resource.data.keys().hasAny(['phone']) ||
   request.resource.data.phone == null ||
   request.resource.data.phone is string) &&
  // Email can be null, but must be string if provided
  (!request.resource.data.keys().hasAny(['email']) ||
   request.resource.data.email == null ||
   request.resource.data.email is string) &&
  // UserType must be either 'client' or 'supplier'
  request.resource.data.userType in ['client', 'supplier'];
```

**What Changed:**
- Added `request.resource.data.phone == null` to allow null phone values
- Added `request.resource.data.email == null` to allow null email values
- Now accepts: field missing OR field is null OR field is string

---

### 2. Updated Client Details Screen

**File:** `lib/features/client/presentation/screens/client_details_screen.dart` (lines 111-127)

**Before:**
```dart
await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  'userType': 'client',
  'name': _nameController.text.trim(),
  'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
  'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
  // ...
}, SetOptions(merge: true));
```

**After:**
```dart
final dataToSave = {
  'userType': 'client',
  'name': _nameController.text.trim(),
  'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : user.email,
  'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
  'photo': user.photoURL,
  'location': {
    'province': _selectedProvince ?? 'Luanda',
    'city': _selectedCity ?? 'Luanda',
    'country': 'Angola',
  },
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

debugPrint('🔍 Saving client data: ...');

await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
  dataToSave,
  SetOptions(merge: true),
);
```

**What Changed:**
- Email now uses `user.email` from Firebase Auth if form field is empty
- Added debug logging to see what data is being saved
- Ensures Google Sign-In users always have an email

---

### 3. Updated Update Rules for Merge Operations

**File:** `firestore.rules` (lines 32-46)

**Issue:** When using `.set()` with `SetOptions(merge: true)` on a non-existent document, Firestore treats it as an UPDATE operation. The update rule was checking `resource.data` which is null for new documents.

**Fix:**
```javascript
allow update: if request.auth != null && request.auth.uid == userId &&
  // ... existing validations ...
  // Allow adding phone if it doesn't exist, but prevent changing if it does (only check if document exists)
  (!exists(/databases/$(database)/documents/users/$(userId)) ||
   !resource.data.keys().hasAny(['phone']) ||
   !request.resource.data.keys().hasAny(['phone']) ||
   request.resource.data.phone == resource.data.phone) &&
  // Allow adding email if it doesn't exist, but prevent changing if it does (only check if document exists)
  (!exists(/databases/$(database)/documents/users/$(userId)) ||
   !resource.data.keys().hasAny(['email']) ||
   !request.resource.data.keys().hasAny(['email']) ||
   request.resource.data.email == resource.data.email ||
   (request.resource.data.email == null && resource.data.email == null));
```

**What Changed:**
- Added `!exists(...)` checks before accessing `resource.data`
- If document doesn't exist, skip validations that reference existing data
- Allows `.set()` with merge to work for both creating and updating

---

## Validation Logic

### Create Rule Now Accepts:

**Phone Field:**
- ✅ Field doesn't exist: `{ userType: 'client', name: 'John' }`
- ✅ Field is null: `{ userType: 'client', phone: null }`
- ✅ Field is string: `{ userType: 'client', phone: '+244...' }`
- ❌ Field is number: `{ userType: 'client', phone: 123456 }` → DENIED
- ❌ Field is object: `{ userType: 'client', phone: {} }` → DENIED

**Email Field:**
- ✅ Field doesn't exist: `{ userType: 'client', name: 'John' }`
- ✅ Field is null: `{ userType: 'client', email: null }`
- ✅ Field is string: `{ userType: 'client', email: 'john@example.com' }`
- ❌ Field is number: `{ userType: 'client', email: 123 }` → DENIED

**Required Fields:**
- ✅ Must have `userType`
- ✅ Must be 'client' or 'supplier'
- ✅ User must be authenticated
- ✅ UID must match document ID

---

## Testing

### Test Case 1: Google Sign-In (No Phone)
```dart
{
  'userType': 'client',
  'name': 'David Nduwa',
  'email': 'davidnduwa5@gmail.com',  // From Google
  'phone': null,                      // Not provided
  'photo': 'https://...',            // From Google
  'location': { ... },
}
```
**Result:** ✅ Should work

### Test Case 2: Google Sign-In (With Phone)
```dart
{
  'userType': 'client',
  'name': 'Maria Silva',
  'email': 'maria@gmail.com',
  'phone': '+244923456789',  // User entered
  'photo': 'https://...',
  'location': { ... },
}
```
**Result:** ✅ Should work

### Test Case 3: Phone Sign-In
```dart
{
  'userType': 'client',
  'name': 'João Costa',
  'email': null,                    // Not from phone auth
  'phone': '+244912345678',         // From phone auth
  'photo': null,
  'location': { ... },
}
```
**Result:** ✅ Should work

---

## Security Maintained

### What's Still Protected:

1. **User ID Validation** ✅
   - Users can ONLY create documents with their own UID
   - Cannot create documents for other users

2. **User Type Validation** ✅
   - Only 'client' or 'supplier' allowed
   - Cannot set invalid types like 'admin', 'moderator', etc.

3. **Data Type Validation** ✅
   - Phone must be null OR string (not number, object, etc.)
   - Email must be null OR string
   - Prevents injection attacks

4. **Authentication Required** ✅
   - Must be logged in via Firebase Auth
   - Anonymous users cannot create documents

5. **Update Protection** ✅
   - Phone/email cannot be changed once set
   - Prevents bypassing duplicate checks
   - Rating cannot be manually inflated
   - Suspension cannot be bypassed

---

## Deployment

```bash
firebase deploy --only firestore:rules
```

**Output:**
```
✅ cloud.firestore: rules file compiled successfully
✅ firestore: released rules to cloud.firestore
✅ Deploy complete!
```

---

## Next Steps

1. **Try client registration again:**
   - Sign out if logged in
   - Tap "Sou Cliente"
   - Tap "Registrar com Google"
   - Select Google account
   - Fill in client details (name, phone, city)
   - Tap "Continuar"

2. **Check debug logs:**
   - Look for: `🔍 Saving client data: ...`
   - Verify email is populated from Google account
   - Confirm no permission errors

3. **Verify Firestore:**
   - Open Firebase Console
   - Check `users` collection
   - Confirm user document was created
   - Verify all fields are present

---

## Summary

**Problems Fixed:**
1. ✅ Firestore rules now accept null phone/email values
2. ✅ Email falls back to `user.email` from Firebase Auth
3. ✅ Update rule handles merge operations on new documents
4. ✅ Added debug logging for troubleshooting

**Security:**
- ✅ All validations still in place
- ✅ User ID matching enforced
- ✅ Data type validation maintained
- ✅ Authentication required

**Status:** ✅ **READY FOR TESTING**

---

*Updated: 2026-01-22*
*All fixes deployed to Firebase*
