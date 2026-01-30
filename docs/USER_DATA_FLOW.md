# User Data Flow - Complete Profile Consistency

## Overview

This document explains how user data flows through registration, profile completion, and display across the app to ensure consistency.

---

## Complete User Data Structure

### Firestore `users/{userId}` Document:

```javascript
{
  // Basic Info (from Google Auth or filled in details screen)
  name: "John Doe",
  email: "user@example.com",
  phone: "+244 912 345 678",  // Required - filled in details screen
  photoUrl: "https://...",

  // Location (required - filled in details screen)
  location: {
    province: "Luanda",        // ✅ From AngolaLocations
    city: "Talatona",          // ✅ From AngolaLocations
    country: "Angola",
    address: null,             // Optional - for future use
    geopoint: GeoPoint(lat, lng)  // Optional - from location service
  },

  // Preferences (filled in preferences screen)
  preferences: {
    categories: ["photography", "catering"],  // ✅ Selected category IDs
    completedOnboarding: true
  },

  // System Fields
  userType: "client",          // or "supplier"
  authMethod: "google",        // or "phone", "whatsapp"
  emailVerified: true,
  isActive: true,
  fcmToken: null,              // For push notifications
  createdAt: timestamp,
  updatedAt: timestamp
}
```

---

## Registration Flow - Data Collection Points

### 1. Google Sign-In (Initial)

**What Gets Saved** ([google_auth_service.dart:51-63](../lib/core/services/google_auth_service.dart)):
```javascript
{
  email: "user@gmail.com",        // ✅ From Google
  name: "John Doe",               // ✅ From Google displayName
  phone: "",                      // ❌ Empty - needs to be filled
  photoUrl: "https://...",        // ✅ From Google
  userType: "client",
  authMethod: "google",
  emailVerified: true,
  isActive: true,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

**Missing Fields**:
- ❌ `phone` - empty
- ❌ `location` - not set
- ❌ `preferences` - not set

### 2. Client Details Screen

**User is redirected here** ([client_register_screen.dart:38-40](../lib/features/auth/presentation/screens/client_register_screen.dart))

**Fields Pre-filled** ([client_details_screen.dart:31-60](../lib/features/client/presentation/screens/client_details_screen.dart)):
- ✅ `name` - from Google displayName
- ✅ `email` - from Google email
- ✅ `location` - from Firestore if already exists

**What User Enters**:
- Name (can edit if needed)
- Email (can edit if needed)
- Province (dropdown from AngolaLocations)
- City (dropdown from selected province)

**What Gets Saved** ([client_details_screen.dart:57-66](../lib/features/client/presentation/screens/client_details_screen.dart)):
```javascript
{
  name: "John Doe",              // ✅ Confirmed or edited
  email: "user@gmail.com",       // ✅ Confirmed or edited
  location: {
    province: "Luanda",          // ✅ User selected
    city: "Talatona",            // ✅ User selected
    country: "Angola"
  },
  updatedAt: timestamp
}
```

**Still Missing**:
- ❌ `phone` - **NOTE: Currently not collected in this screen!**
- ❌ `preferences` - filled in next screen

### 3. Client Preferences Screen

**User is redirected here** ([client_details_screen.dart:73](../lib/features/client/presentation/screens/client_details_screen.dart))

**What User Selects**:
- Preferred service categories (multi-select grid)

**What Gets Saved** ([client_preferences_screen.dart:43-49](../lib/features/client/presentation/screens/client_preferences_screen.dart)):
```javascript
{
  preferences: {
    categories: ["photography", "catering"],
    completedOnboarding: true
  },
  updatedAt: timestamp
}
```

### 4. Complete User Document After Registration

```javascript
{
  // ✅ Complete fields
  name: "John Doe",
  email: "user@gmail.com",
  photoUrl: "https://...",
  location: {
    province: "Luanda",
    city: "Talatona",
    country: "Angola"
  },
  preferences: {
    categories: ["photography", "catering"],
    completedOnboarding: true
  },

  // ⚠️ ISSUE: Phone still empty!
  phone: "",

  // System fields
  userType: "client",
  authMethod: "google",
  emailVerified: true,
  isActive: true,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

---

## 🚨 ISSUE IDENTIFIED: Phone Number Not Collected!

The client details screen does NOT collect the phone number, but it's displayed in the profile!

### Where Phone Appears:

1. **Client Profile Screen** ([client_profile_screen.dart:55](../lib/features/client/presentation/screens/client_profile_screen.dart)):
   ```dart
   final userPhone = currentUser?.phone ?? 'Sem telefone';
   ```
   Shows: "Sem telefone" if phone is empty ❌

### Solutions:

**Option 1: Add Phone Field to Client Details Screen** ✅ RECOMMENDED
- Add phone input field to client_details_screen.dart
- Validate phone number format
- Save to Firestore along with other details

**Option 2: Add Separate Phone Screen**
- Create new screen between details and preferences
- Dedicated phone number collection

**Option 3: Make Phone Optional**
- Allow users to skip phone during registration
- Add option to add phone later in settings

---

## Data Display Consistency

### Profile Screen Shows:

**From UserModel** ([client_profile_screen.dart:53-63](../lib/features/client/presentation/screens/client_profile_screen.dart)):

1. **Name**: `currentUser?.name ?? 'Cliente'`
   - Source: `users/{uid}/name`
   - Set in: Google Auth OR Client Details Screen

2. **Phone**: `currentUser?.phone ?? 'Sem telefone'`
   - Source: `users/{uid}/phone`
   - Set in: **NOT COLLECTED YET** ❌

3. **Location**:
   ```dart
   '${location.city}, ${location.province}'
   // OR 'Angola' if null
   ```
   - Source: `users/{uid}/location/{city,province}`
   - Set in: Client Details Screen ✅

4. **Profile Stats**:
   - Reservas: From `clientBookingsProvider` ✅
   - Favoritos: From `favoritesProvider` ✅
   - Avaliações: From completed bookings ✅

5. **Preferences**:
   - Source: `users/{uid}/preferences/categories`
   - Set in: Client Preferences Screen ✅

### Settings Should Pre-fill:

When user opens settings to edit profile:

**Personal Info Section**:
- Name: From `currentUser.name`
- Email: From `currentUser.email`
- Phone: From `currentUser.phone` (currently empty)
- Photo: From `currentUser.photoUrl`

**Location Section**:
- Province: From `currentUser.location.province`
- City: From `currentUser.location.city`

**Preferences Section**:
- Categories: From `currentUser.preferences.categories`

---

## Fix Required: Add Phone to Client Details Screen

### 1. Update client_details_screen.dart

Add phone field controller:
```dart
final _phoneController = TextEditingController();
```

Add phone input field in UI:
```dart
TextFormField(
  controller: _phoneController,
  decoration: InputDecoration(
    labelText: 'Telefone *',
    hintText: '+244 912 345 678',
    prefixIcon: Icon(Icons.phone),
  ),
  keyboardType: TextInputType.phone,
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefone é obrigatório';
    }
    return null;
  },
),
```

Update save method:
```dart
await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
  'name': _nameController.text.trim(),
  'email': _emailController.text.trim(),
  'phone': _phoneController.text.trim(),  // ✅ Add this
  'location': {
    'province': _selectedProvince ?? 'Luanda',
    'city': _selectedCity ?? 'Luanda',
    'country': 'Angola',
  },
  'updatedAt': FieldValue.serverTimestamp(),
});
```

### 2. Pre-fill Phone if Available

In initState / _loadExistingUserData:
```dart
// Pre-fill phone if available
if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
  _phoneController.text = user.phoneNumber!;
}

// Or from Firestore
if (data['phone'] != null) {
  _phoneController.text = data['phone'];
}
```

---

## User Model Updates

**Updated** ([user_model.dart](../lib/core/models/user_model.dart)):

Added `UserPreferences` class:
```dart
class UserPreferences {
  final List<String>? categories;
  final bool? completedOnboarding;

  // fromMap, toMap, copyWith methods
}
```

Added to UserModel:
```dart
final UserPreferences? preferences;
```

This ensures:
- ✅ Preferences are properly parsed from Firestore
- ✅ Preferences can be displayed in profile/settings
- ✅ Preferences can be updated

---

## Testing Checklist

### Test Google Registration Flow:

- [ ] Register with Google
- [ ] **Verify**: Redirected to Client Details Screen
- [ ] **Verify**: Name pre-filled from Google
- [ ] **Verify**: Email pre-filled from Google
- [ ] **Add**: Phone field should be visible
- [ ] Fill in: Phone number
- [ ] Select: Province and City
- [ ] Click: Continue
- [ ] **Verify**: Redirected to Preferences Screen
- [ ] Select: Preferred categories
- [ ] Click: Complete
- [ ] **Verify**: Redirected to Client Home
- [ ] Go to: Profile
- [ ] **Verify**: Name matches what was entered
- [ ] **Verify**: Phone displays correctly (NOT "Sem telefone")
- [ ] **Verify**: Location shows "City, Province"
- [ ] Go to: Settings
- [ ] **Verify**: All fields pre-filled correctly

### Test Profile Consistency:

- [ ] Change name in profile
- [ ] **Verify**: Name updates in Firestore
- [ ] **Verify**: Name shows updated in profile header
- [ ] Change location in profile
- [ ] **Verify**: Location updates in Firestore
- [ ] **Verify**: Location shows updated in profile
- [ ] Add/change phone in profile
- [ ] **Verify**: Phone updates in Firestore
- [ ] **Verify**: Phone shows updated in profile

---

## Summary of Changes Made

### ✅ Completed:

1. **UserModel Updated**:
   - Added `UserPreferences` class
   - Added `preferences` field to UserModel
   - Updated fromFirestore, toFirestore, copyWith

2. **Google Auth Service Updated**:
   - Added `phone` field to initial user creation (empty string)

3. **Client Details Screen Updated**:
   - Added `_loadExistingUserData()` method
   - Pre-fills name from Google displayName
   - Pre-fills email from Google email
   - Pre-fills location if exists in Firestore

4. **Registration Flow Fixed**:
   - New Google users → Client Details → Preferences → Home
   - All data properly saved and flows through

### ⚠️ Still Needs Fix:

1. **Add Phone Field to Client Details Screen**:
   - Add phone input field
   - Validate phone number
   - Save phone to Firestore
   - Pre-fill phone if available

2. **Create Profile Edit Screen** (if doesn't exist):
   - Allow editing name, phone, location
   - Pre-fill all fields from currentUser
   - Update Firestore on save

---

## Files Modified

1. [user_model.dart](../lib/core/models/user_model.dart) - Added UserPreferences class ✅
2. [google_auth_service.dart](../lib/core/services/google_auth_service.dart) - Added phone field ✅
3. [client_details_screen.dart](../lib/features/client/presentation/screens/client_details_screen.dart) - Pre-fill data ✅
4. [client_register_screen.dart](../lib/features/auth/presentation/screens/client_register_screen.dart) - Route to details ✅
5. [login_screen.dart](../lib/features/auth/presentation/screens/login_screen.dart) - Route to details ✅

### Files That Need Updates:

1. [client_details_screen.dart](../lib/features/client/presentation/screens/client_details_screen.dart) - **Add phone field** ⚠️

---

**Last Updated**: 2026-01-21
**Status**:
- ✅ Data structure complete
- ✅ Pre-filling working
- ⚠️ Phone field needs to be added to details screen
