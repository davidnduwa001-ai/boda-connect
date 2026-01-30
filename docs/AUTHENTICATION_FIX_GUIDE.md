# 🔧 Authentication Fix Guide - Boda Connect

## ⚠️ Critical Issues Found

### 1. Firebase Authentication Not Working
**Error**: `This app is not authorized to use Firebase Authentication`

**Root Cause**: SHA-1 and SHA-256 fingerprints not registered in Firebase Console

**Your Fingerprints**:
```
SHA-1:   D2:89:07:5C:CB:E1:7E:4E:21:6B:36:14:F5:EB:3B:C6:1F:25:4B:A7
SHA-256: 9B:2C:56:72:02:A8:6A:04:FD:55:41:93:38:12:F8:CF:94:DD:03:9A:AF:2C:20:16:74:DE:D2:1B:39:08:EA:3C
```

### 2. User Profile Not Created After Registration
**Issue**: After registration, user data is not saved to Firestore
**Result**: "Perfil não encontrado" appears on profile screen

### 3. OTP Not Sent
**Issue**: Phone verification requires Firebase configuration
**Current Status**: Phone auth will not work until SHA fingerprints are added

### 4. Two Profile Types Needed
**Issue**: Supplier needs:
- **Public Profile** - What clients see when browsing
- **Own Profile** - What supplier sees/edits in dashboard

---

## ✅ SOLUTION 1: Fix Firebase Configuration (Recommended)

### Step 1: Add SHA Fingerprints to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **Boda Connect** project
3. Click ⚙️ (Settings) → **Project Settings**
4. Scroll to **Your apps** section
5. Click on your Android app (`com.example.boda_connect`)
6. Scroll to **SHA certificate fingerprints**
7. Click **Add fingerprint** and add BOTH:
   ```
   D2:89:07:5C:CB:E1:7E:4E:21:6B:36:14:F5:EB:3B:C6:1F:25:4B:A7
   9B:2C:56:72:02:A8:6A:04:FD:55:41:93:38:12:F8:CF:94:DD:03:9A:AF:2C:20:16:74:DE:D2:1B:39:08:EA:3C
   ```
8. **Download new `google-services.json`**
9. Replace `android/app/google-services.json` with the new file

### Step 2: Enable Authentication Methods

1. In Firebase Console → **Authentication** → **Sign-in method**
2. Enable:
   - ✅ Email/Password
   - ✅ Phone (for WhatsApp/SMS)
3. Save changes

### Step 3: Restart App
```bash
flutter run
```

---

## ✅ SOLUTION 2: Use Email Authentication (Quick Fix)

This works immediately without Firebase configuration changes.

**Files that need updating**:
1. `lib/core/providers/auth_provider.dart` - Fix user creation
2. `lib/features/auth/presentation/screens/email_auth_screen.dart` - Fix email registration
3. `lib/features/supplier/presentation/screens/supplier_profile_screen.dart` - Add public vs private view

---

## 🔨 Key Fixes Needed

### Fix 1: Save User Data After Registration

Currently, when a user registers:
1. Firebase Auth creates the account ✅
2. But user data is NOT saved to Firestore ❌

**Need to add**:
```dart
// After successful registration
await FirebaseFirestore.instance.collection('users').doc(userId).set({
  'name': name,
  'email': email,
  'phone': phone,
  'userType': 'client', // or 'supplier'
  'createdAt': FieldValue.serverTimestamp(),
});

// For suppliers, also create supplier profile
if (userType == 'supplier') {
  await FirebaseFirestore.instance.collection('suppliers').doc(userId).set({
    'userId': userId,
    'businessName': businessName,
    'category': category,
    // ... other fields
  });
}
```

### Fix 2: Create OTP Flow

After phone number input, app should:
1. Send OTP to phone
2. Navigate to OTP verification screen
3. Verify code
4. Create user account
5. Navigate to appropriate screen (client preferences or supplier setup)

### Fix 3: Implement Two Profile Views

**Public Profile** (ClientSupplierDetailScreen):
- Shows supplier info to clients
- Read-only
- Displays packages, reviews, contact info

**Own Profile** (SupplierProfileScreen):
- Shows supplier their own data
- Editable
- Shows statistics, earnings, settings

---

## 📋 Registration Flow (Should Be)

### Client Registration:
1. Choose method (WhatsApp/Phone/Email)
2. Enter credentials
3. Verify (OTP for phone, email link for email)
4. Create user in Firestore `users` collection
5. Navigate to **Client Preferences** screen
6. Save preferences
7. Navigate to **Client Home** screen

### Supplier Registration:
1. Choose method (WhatsApp/Phone/Email)
2. Enter credentials
3. Verify (OTP for phone, email link for email)
4. Create user in Firestore `users` collection
5. Navigate to **Supplier Setup** screens:
   - Basic info (name, category)
   - Contact details
   - Business description
   - Upload photos
6. Create supplier in Firestore `suppliers` collection
7. Navigate to **Supplier Dashboard**

---

## 🎯 What Needs to Happen

1. **Fix Firebase Config** - Add SHA fingerprints (5 minutes)
2. **Fix Registration Flow** - Save user data to Firestore (30 minutes)
3. **Fix OTP Flow** - Implement proper verification (20 minutes)
4. **Fix Profile Views** - Separate public/private views (15 minutes)
5. **Test End-to-End** - Register → Verify → View Profile (10 minutes)

**Total Time**: ~80 minutes to full working authentication

---

## 🚀 Next Steps

Choose one:
1. **Option A**: I'll implement Solution 2 (Email Auth) right now - works immediately
2. **Option B**: You configure Firebase first, then I'll fix everything
3. **Option C**: I'll do both - fix email auth now, and prepare phone auth for when you configure Firebase

Which would you like me to do?
