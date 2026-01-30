# Production-Ready Implementation Plan

**Date**: 2026-01-21
**Status**: 📋 Planning Phase
**Priority**: 🔴 Critical for Production

---

## Overview

This document outlines the implementation plan for making Boda Connect production-ready with all critical safety, security, and user experience features.

---

## 1. Settings Screen Enhancements

### 1.1 Region Detection (Auto-match phone settings)
**Status**: 📋 To Implement
**File**: `lib/features/common/presentation/screens/settings_screen.dart`

**Implementation**:
```dart
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

// Get device locale
final String deviceLocale = Platform.localeName; // e.g., "pt_AO", "en_US"
final String country = deviceLocale.split('_').last; // "AO", "US"
```

**Firestore Structure**:
```javascript
users/{userId}/settings {
  region: "Angola",
  countryCode: "AO",
  detectedAutomatically: true,
  lastUpdated: Timestamp
}
```

### 1.2 Theme Detection (Auto-match phone settings)
**Status**: 📋 To Implement

**Implementation**:
```dart
// Detect system theme
final Brightness brightness = MediaQuery.of(context).platformBrightness;
final bool isDarkMode = brightness == Brightness.dark;
```

**Firestore Structure**:
```javascript
users/{userId}/settings {
  theme: "auto", // "light", "dark", "auto"
  followSystem: true
}
```

### 1.3 Font Size (Auto-match phone settings)
**Status**: 📋 To Implement

**Implementation**:
```dart
// Detect system font scale
final double textScaleFactor = MediaQuery.of(context).textScaleFactor;

// Apply globally
MaterialApp(
  builder: (context, child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: savedTextScale ?? textScaleFactor,
      ),
      child: child!,
    );
  },
)
```

**Firestore Structure**:
```javascript
users/{userId}/settings {
  fontSize: "medium", // "small", "medium", "large", "extra-large"
  textScale: 1.0, // 0.85, 1.0, 1.15, 1.3
  followSystem: true
}
```

---

## 2. Notifications System

### 2.1 Functional Notification Toggles
**Status**: 📋 To Implement
**Files**:
- `lib/core/services/notification_preferences_service.dart` (NEW)
- `lib/core/providers/notification_preferences_provider.dart` (NEW)

**Firestore Structure**:
```javascript
users/{userId}/notificationPreferences {
  enabled: true,
  pushNotifications: true,
  emailNotifications: true,
  smsNotifications: false,
  marketingEmails: false,

  // Granular controls
  newBookings: true,
  bookingUpdates: true,
  messages: true,
  reviews: true,
  promotions: false,

  updatedAt: Timestamp
}
```

**Implementation**:
- Save preferences to Firestore
- Subscribe/unsubscribe from FCM topics
- Update email marketing list
- Respect user preferences in notification sending logic

### 2.2 FCM Topic Management
```dart
// Subscribe to relevant topics
if (pushNotifications && newBookings) {
  await FirebaseMessaging.instance.subscribeToTopic('bookings_$userId');
}

// Unsubscribe when disabled
if (!pushNotifications || !newBookings) {
  await FirebaseMessaging.instance.unsubscribeFromTopic('bookings_$userId');
}
```

---

## 3. Security & Privacy

### 3.1 Contact Information Removal
**Status**: 🔴 CRITICAL - Must be implemented

**Files to Update**:
- `lib/features/supplier/presentation/screens/supplier_detail_screen.dart`
- `lib/features/client/presentation/screens/client_profile_screen.dart`
- `lib/core/models/supplier_model.dart`
- `lib/core/models/user_model.dart`

**Changes Required**:
```dart
// REMOVE from UI:
- Phone number display
- Email display
- WhatsApp link
- Direct call buttons
- External contact buttons

// KEEP only:
- In-app messaging button
- "Enviar Mensagem" (Send Message)
```

**Firestore Security Rules**:
```javascript
// Hide contact info from other users
match /suppliers/{supplierId} {
  allow read: if request.auth != null;
  // Don't allow reading sensitive fields
  allow get: if request.auth != null &&
    !request.resource.data.keys().hasAny(['phoneNumber', 'email', 'whatsapp']);
}
```

### 3.2 Contact Detection in Messages
**Status**: 🔴 CRITICAL
**File**: `lib/core/services/contact_detection_service.dart` (NEW)

**Patterns to Detect**:
```dart
final List<RegExp> contactPatterns = [
  // Phone numbers
  RegExp(r'\+?\d{9,15}'),
  RegExp(r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{3,4}\b'),

  // Email addresses
  RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),

  // Social media
  RegExp(r'@\w+'),
  RegExp(r'whatsapp', caseSensitive: false),
  RegExp(r'telegram', caseSensitive: false),
  RegExp(r'instagram', caseSensitive: false),
  RegExp(r'facebook', caseSensitive: false),

  // URLs
  RegExp(r'https?://\S+'),
  RegExp(r'www\.\S+'),
];
```

**Action on Detection**:
1. **Warning** (1st offense): "Atenção: Não partilhe informações de contacto. Use apenas as mensagens do app."
2. **Block Message** (2nd offense): Message not sent, user warned
3. **Report** (3rd offense): Flag user account for review
4. **Suspension** (4th offense): Temporary 7-day suspension

**Firestore Structure**:
```javascript
users/{userId}/policyViolations {
  contactSharingAttempts: 3,
  lastViolation: Timestamp,
  warnings: [
    {
      type: "contact_sharing",
      message: "Attempted to share phone number",
      timestamp: Timestamp,
      severity: "medium"
    }
  ]
}
```

---

## 4. Rating System (5-Star Start)

### 4.1 Initial Rating Implementation
**Status**: 🔴 CRITICAL
**Files**:
- `lib/core/services/user_creation_service.dart` (UPDATE)
- `lib/core/models/supplier_model.dart` (UPDATE)
- `lib/core/models/user_model.dart` (UPDATE)

**On User/Supplier Creation**:
```dart
// For new users
users/{userId} {
  rating: 5.0,
  reviewCount: 0,
  ratingHistory: [
    {
      rating: 5.0,
      timestamp: Timestamp.now(),
      reason: "initial_rating"
    }
  ]
}

// For new suppliers
suppliers/{supplierId} {
  rating: 5.0,
  reviewCount: 0,
  ratingHistory: []
}
```

### 4.2 Rating Calculation (Like Uber/Lyft)
**File**: `lib/core/services/rating_service.dart` (NEW)

**Weighted Rating System**:
```dart
double calculateRating({
  required double currentRating,
  required int totalReviews,
  required double newReviewRating,
}) {
  // Weighted average: gives more weight to recent reviews
  final double totalScore = currentRating * totalReviews;
  final double newTotalScore = totalScore + newReviewRating;
  final double newAverageRating = newTotalScore / (totalReviews + 1);

  return double.parse(newAverageRating.toStringAsFixed(2));
}
```

**Rating Decay** (for inactive users):
```dart
// After 6 months of inactivity, rating slowly decays
if (monthsSinceLastActivity > 6) {
  final decayFactor = 0.95; // 5% decay every 6 months
  rating = rating * decayFactor;
}
```

---

## 5. Automatic Suspension System

### 5.1 Suspension Triggers
**File**: `lib/core/services/suspension_service.dart` (NEW)

**Trigger Conditions**:
```dart
class SuspensionTriggers {
  // Rating-based
  static const double minRatingBeforeSuspension = 3.0;
  static const int minReviewsForRatingSuspension = 5; // Need at least 5 reviews

  // Policy violation-based
  static const int maxContactSharingAttempts = 3;
  static const int maxCancellations = 5; // Within 30 days
  static const int maxNoShows = 2; // Within 90 days
  static const int maxReports = 3; // From different users

  // Fraud indicators
  static const int maxFailedPayments = 3;
  static const int maxRefundRequests = 5; // Within 30 days
}
```

**Suspension Types**:
```dart
enum SuspensionType {
  temporary_7days,
  temporary_30days,
  permanent,
  under_review
}

enum SuspensionReason {
  low_rating,
  contact_sharing,
  excessive_cancellations,
  no_show,
  user_reports,
  fraud_suspected,
  payment_issues,
  policy_violation
}
```

**Firestore Structure**:
```javascript
users/{userId}/suspensionStatus {
  isSuspended: true,
  suspensionType: "temporary_7days",
  reason: "low_rating",
  startDate: Timestamp,
  endDate: Timestamp,
  appealable: true,
  appealSubmitted: false,

  history: [
    {
      type: "temporary_7days",
      reason: "contact_sharing",
      startDate: Timestamp,
      endDate: Timestamp,
      resolved: true
    }
  ]
}
```

### 5.2 Automatic Suspension Logic
```dart
Future<void> checkAndApplySuspension(String userId) async {
  final user = await getUserData(userId);
  final violations = await getPolicyViolations(userId);

  // Check rating
  if (user.rating < 3.0 && user.reviewCount >= 5) {
    await suspendUser(
      userId: userId,
      type: SuspensionType.under_review,
      reason: SuspensionReason.low_rating,
      duration: Duration(days: 30),
    );
  }

  // Check contact sharing
  if (violations.contactSharingAttempts >= 3) {
    await suspendUser(
      userId: userId,
      type: SuspensionType.temporary_7days,
      reason: SuspensionReason.contact_sharing,
    );
  }

  // Check reports
  final reports = await getUserReports(userId);
  if (reports.length >= 3) {
    await suspendUser(
      userId: userId,
      type: SuspensionType.under_review,
      reason: SuspensionReason.user_reports,
    );
  }
}
```

### 5.3 Suspension UI
**File**: `lib/features/common/presentation/screens/account_suspended_screen.dart` (NEW)

**Display**:
- Clear explanation of suspension reason
- Duration (if temporary)
- Steps to appeal
- Contact support button
- Policy link

---

## 6. Policy Violation Warning System

### 6.1 Warning Levels
**File**: `lib/core/services/warning_service.dart` (NEW)

```dart
enum WarningLevel {
  info,      // Just information, no penalty
  low,       // First offense warning
  medium,    // Second offense, stricter warning
  high,      // Third offense, suspension warning
  critical   // Fourth offense, suspension applied
}
```

### 6.2 Warning Delivery
```dart
Future<void> issueWarning({
  required String userId,
  required String violationType,
  required WarningLevel level,
  required String message,
}) async {
  // Save to Firestore
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('warnings')
      .add({
    'type': violationType,
    'level': level.toString(),
    'message': message,
    'timestamp': FieldValue.serverTimestamp(),
    'acknowledged': false,
  });

  // Send push notification
  await sendWarningNotification(userId, message);

  // Show in-app dialog on next app open
  await setWarningFlag(userId);
}
```

### 6.3 Warning Display
**File**: `lib/features/common/presentation/widgets/warning_dialog.dart` (NEW)

```dart
// Show modal that must be acknowledged
showDialog(
  context: context,
  barrierDismissible: false, // Cannot dismiss
  builder: (context) => AlertDialog(
    title: Row(
      children: [
        Icon(Icons.warning, color: warningColor),
        SizedBox(width: 8),
        Text('Aviso Importante'),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(warningMessage),
        if (level == WarningLevel.high) ...[
          SizedBox(height: 16),
          Container(
            color: Colors.red.shade50,
            padding: EdgeInsets.all(12),
            child: Text(
              'Próxima violação resultará em suspensão da conta',
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    ),
    actions: [
      ElevatedButton(
        onPressed: () {
          acknowledgeWarning(warningId);
          Navigator.pop(context);
        },
        child: Text('Entendi'),
      ),
    ],
  ),
);
```

---

## 7. Implementation Priority

### Phase 1: CRITICAL (Week 1)
1. ✅ Remove all contact information from UI
2. ✅ Implement contact detection in messages
3. ✅ Set initial 5.0 rating for new users
4. ✅ Implement automatic suspension for low ratings

### Phase 2: HIGH PRIORITY (Week 2)
5. ✅ Implement policy violation tracking
6. ✅ Implement warning system
7. ✅ Create suspension UI screens
8. ✅ Implement appeal system

### Phase 3: MEDIUM PRIORITY (Week 3)
9. ✅ Functional notification toggles
10. ✅ Auto-detect region/theme/font from phone
11. ✅ Save all settings to Firestore
12. ✅ FCM topic management

### Phase 4: POLISH (Week 4)
13. ✅ Admin dashboard for reviewing suspensions
14. ✅ Analytics for policy violations
15. ✅ User education (tooltips, help screens)
16. ✅ Testing all scenarios

---

## 8. Testing Checklist

### Contact Blocking
- [ ] Phone numbers not visible on supplier profiles
- [ ] Email addresses not visible
- [ ] Only "Send Message" button available
- [ ] Message detection catches phone numbers
- [ ] Message detection catches emails
- [ ] Message detection catches social media handles
- [ ] Warning shown on first detection
- [ ] Message blocked on second detection
- [ ] User reported on third detection

### Rating System
- [ ] New users start at 5.0 rating
- [ ] New suppliers start at 5.0 rating
- [ ] Rating decreases after bad review
- [ ] Rating calculation correct (weighted average)
- [ ] Rating displayed everywhere correctly

### Suspension System
- [ ] User suspended when rating < 3.0 (with 5+ reviews)
- [ ] User suspended after 3 contact sharing attempts
- [ ] User suspended after 3 reports from different users
- [ ] Suspension screen shown when suspended
- [ ] User cannot make bookings when suspended
- [ ] Temporary suspension lifts automatically
- [ ] Appeal process works

### Settings
- [ ] Theme follows phone settings by default
- [ ] Region detected from phone locale
- [ ] Font size follows phone settings
- [ ] All notification toggles save to Firestore
- [ ] FCM topics updated when toggles change
- [ ] Settings persist across app restarts

---

## 9. Database Migrations

### Required Firestore Updates

**Update existing users**:
```javascript
// Run once to add rating field to existing users
users.forEach(user => {
  if (!user.rating) {
    user.rating = 5.0;
    user.reviewCount = 0;
    user.ratingHistory = [{
      rating: 5.0,
      timestamp: new Date(),
      reason: "initial_rating"
    }];
  }
});
```

**Update existing suppliers**:
```javascript
suppliers.forEach(supplier => {
  if (!supplier.rating) {
    supplier.rating = 5.0;
    supplier.reviewCount = 0;
    supplier.ratingHistory = [];
  }
});
```

---

## 10. Security Rules Updates

### Hide Contact Info
```javascript
match /users/{userId} {
  allow read: if request.auth != null;

  // Hide sensitive fields from other users
  function sanitizeUser(data) {
    return data.keys().hasAny([
      'phoneNumber',
      'email',
      'whatsapp',
      'address',
      'taxId'
    ]) ? null : data;
  }

  allow get: if request.auth != null &&
    (request.auth.uid == userId ||
     sanitizeUser(resource.data) != null);
}
```

### Suspension Check
```javascript
match /bookings/{bookingId} {
  function isSuspended(userId) {
    return exists(/databases/$(database)/documents/users/$(userId)/suspensionStatus) &&
           get(/databases/$(database)/documents/users/$(userId)/suspensionStatus).data.isSuspended == true;
  }

  allow create: if request.auth != null &&
    !isSuspended(request.auth.uid);
}
```

---

## 11. Documentation for Users

### User Education (In-App)

**On First Message**:
"⚠️ Lembre-se: Nunca partilhe informações de contacto pessoal. Todas as comunicações devem ser feitas através do app para sua segurança."

**On Profile Screen**:
Tooltip: "Seu contacto está oculto por segurança. Use as mensagens do app para comunicar."

**On Low Rating**:
"Sua avaliação está baixa. Continue prestando serviços de qualidade para melhorar sua pontuação."

---

## Status Summary

**Total Tasks**: 50+
**Completed**: 0
**In Progress**: 1
**Remaining**: 49+

**Estimated Time**: 4 weeks (1 month)
**Priority**: 🔴 CRITICAL - Required for production launch

