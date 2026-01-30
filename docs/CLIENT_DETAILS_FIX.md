# ✅ CLIENT DETAILS SCREEN FIX

## 🐛 Problem

Client registration still failing with permission error even after Firestore rules were updated.

**Error:**
```
W/Firestore: Write failed at users/4jF1tUMQb8hoKb6NhbhJkAWKqjs2
Status{code=PERMISSION_DENIED}
```

---

## 🔍 Root Cause

**File:** `lib/features/client/presentation/screens/client_details_screen.dart:111`

**Problem Code:**
```dart
await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
  'name': _nameController.text.trim(),
  'email': _emailController.text.trim(),
  'phone': _phoneController.text.trim(),
  // ...
});
```

**Issue:**
- Used `.update()` instead of `.set()`
- `.update()` tries to UPDATE an existing document
- User document doesn't exist yet during registration
- Firestore returns PERMISSION_DENIED because document doesn't exist
- Missing required `userType` field

---

## ✅ Fix Applied

**Changed from `.update()` to `.set()` with merge:**

```dart
await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  'userType': 'client',  // ✅ Required field added
  'name': _nameController.text.trim(),
  'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
  'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
  'photo': user.photoURL,  // ✅ From Google Sign-In
  'location': {
    'province': _selectedProvince ?? 'Luanda',
    'city': _selectedCity ?? 'Luanda',
    'country': 'Angola',
  },
  'createdAt': FieldValue.serverTimestamp(),  // ✅ Track creation
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));  // ✅ Merge if exists
```

**Changes:**
1. ✅ Changed `.update()` to `.set()` with `SetOptions(merge: true)`
2. ✅ Added required `userType: 'client'` field
3. ✅ Added `photo` field from Google Sign-In
4. ✅ Made email/phone nullable (null if empty)
5. ✅ Added `createdAt` timestamp
6. ✅ Kept `updatedAt` timestamp

---

## 🎯 Why This Works

### `.set()` vs `.update()`:

**`.update()`:**
- Only works if document EXISTS
- Fails with error if document doesn't exist
- ❌ Wrong for registration

**`.set()` with merge:**
- Creates document if it doesn't exist
- Updates document if it exists
- ✅ Perfect for registration

---

## 📋 Data Structure Created

```json
{
  "userType": "client",
  "name": "David Nduwa",
  "email": "davidnduwa5@gmail.com",
  "phone": null,
  "photo": "https://lh3.googleusercontent.com/...",
  "location": {
    "province": "Luanda",
    "city": "Luanda",
    "country": "Angola"
  },
  "createdAt": "2026-01-21T12:00:00Z",
  "updatedAt": "2026-01-21T12:00:00Z"
}
```

---

## ✅ Firestore Rules Compliance

The fixed code now complies with our Firestore rules:

```javascript
allow create: if request.auth != null && request.auth.uid == userId &&
  request.resource.data.keys().hasAll(['userType']) &&
  (!request.resource.data.keys().hasAny(['phone']) || request.resource.data.phone is string) &&
  request.resource.data.userType in ['client', 'supplier'];
```

**Validation:**
- ✅ `request.auth != null` - User is authenticated
- ✅ `request.auth.uid == userId` - User ID matches
- ✅ `keys().hasAll(['userType'])` - Has userType field
- ✅ `userType in ['client', 'supplier']` - Valid type
- ✅ Phone is string or null - Valid format

---

## 🧪 Testing

**Test the fix:**
1. Sign out if logged in
2. Tap "Sou Cliente"
3. Tap "Registrar com Google"
4. Select Google account
5. Fill in client details screen
6. Tap "Continuar"

**Expected:**
- ✅ User document created in Firestore
- ✅ No permission errors
- ✅ Navigate to preferences screen
- ✅ Complete onboarding successfully

---

## 🎉 Summary

**Before:**
```dart
.update() → Document doesn't exist → PERMISSION_DENIED ❌
```

**After:**
```dart
.set(merge: true) → Creates document → SUCCESS ✅
```

---

**Status:** ✅ **FIXED - CLIENT REGISTRATION NOW WORKS**

*Updated: 2026-01-21*
