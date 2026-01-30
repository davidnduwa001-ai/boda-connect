# Deployment Guide - Phase 1 & 2 Security Features

**Date**: 2026-01-21
**Status**: Ready for Deployment

---

## Overview

This guide covers deploying the Phase 1 and Phase 2 security features to production. Follow these steps carefully to ensure a smooth deployment.

---

## Pre-Deployment Checklist

### 1. Code Review
- [ ] All Phase 1 files reviewed and tested
- [ ] All Phase 2 files reviewed and tested
- [ ] No compilation errors
- [ ] All imports correct

### 2. Testing
- [ ] Contact detection service tested
- [ ] Suspension service tested
- [ ] Violations screen tested
- [ ] Suspension screen tested
- [ ] Warning banners tested
- [ ] Chat integration tested

### 3. Firebase Project Ready
- [ ] Firebase project created
- [ ] Firebase CLI installed: `npm install -g firebase-tools`
- [ ] Logged in: `firebase login`
- [ ] Project initialized: `firebase init firestore`

---

## Step 1: Deploy Firestore Security Rules

### Check Current Rules

Before deploying, review the rules file:

```bash
cat firestore.rules
```

### Validate Rules Locally

```bash
firebase firestore:rules:get > current_rules.txt
```

### Deploy Rules

```bash
firebase deploy --only firestore:rules
```

**Expected Output**:
```
=== Deploying to 'boda-connect-project'...

i  deploying firestore
i  firestore: checking firestore.rules for compilation errors...
✔  firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore

✔  Deploy complete!
```

### Verify Deployment

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Rules**
4. Verify the rules match your local `firestore.rules` file

---

## Step 2: Update Existing User Documents

Since we added the `rating` field to UserModel and SupplierModel, we need to update existing users in Firestore.

### Option A: Firebase Console (Manual - Small Projects)

1. Go to Firebase Console → Firestore
2. Open `users` collection
3. For each user document:
   - Click Edit
   - Add field: `rating` (number) = `5.0`
   - Save

4. Open `suppliers` collection
5. For each supplier document:
   - Click Edit
   - Update field: `rating` (number) = `5.0`
   - Save

### Option B: Cloud Function (Recommended - Large Projects)

Create a one-time migration function:

**File**: `functions/src/migrateUsers.ts`
```typescript
import * as admin from 'firebase-admin';

admin.initializeApp();

async function migrateUsers() {
  const db = admin.firestore();

  // Migrate users
  const usersSnapshot = await db.collection('users').get();
  const userBatch = db.batch();

  usersSnapshot.docs.forEach(doc => {
    if (!doc.data().rating) {
      userBatch.update(doc.ref, { rating: 5.0 });
    }
  });

  await userBatch.commit();
  console.log(`✅ Migrated ${usersSnapshot.size} users`);

  // Migrate suppliers
  const suppliersSnapshot = await db.collection('suppliers').get();
  const supplierBatch = db.batch();

  suppliersSnapshot.docs.forEach(doc => {
    if (!doc.data().rating || doc.data().rating === 0) {
      supplierBatch.update(doc.ref, { rating: 5.0 });
    }
  });

  await supplierBatch.commit();
  console.log(`✅ Migrated ${suppliersSnapshot.size} suppliers`);
}

migrateUsers()
  .then(() => {
    console.log('✅ Migration complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  });
```

**Deploy and Run**:
```bash
cd functions
npm install
npm run build
node lib/migrateUsers.js
```

---

## Step 3: Test Security Rules in Production

### Test 1: User Cannot Manipulate Rating

Try this from the app (should FAIL):
```dart
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .update({'rating': 5.0});
// Should throw permission denied error
```

### Test 2: User Cannot Bypass Suspension

Try this from the app (should FAIL):
```dart
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .update({'isActive': true, 'suspension': null});
// Should throw permission denied error
```

### Test 3: User Cannot Write Violations

Try this from the app (should FAIL):
```dart
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .collection('violations')
  .add({...});
// Should throw permission denied error
```

### Test 4: User Can Read Their Own Violations

Try this from the app (should SUCCEED):
```dart
final violations = await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .collection('violations')
  .get();
// Should work
```

### Test 5: User Can Submit Appeal

Try this from the app (should SUCCEED):
```dart
await FirebaseFirestore.instance
  .collection('appeals')
  .add({
    'userId': userId,
    'message': 'Test appeal',
    'submittedAt': FieldValue.serverTimestamp(),
    'status': 'pending',
  });
// Should work
```

---

## Step 4: Monitor Production

### Set Up Firestore Monitoring

1. Go to Firebase Console → Firestore
2. Enable **Firestore Usage** monitoring
3. Set up alerts for:
   - High read/write operations
   - Security rule denials
   - Error rates

### Set Up Cloud Logging

Filter for security events:
```
resource.type="cloud_firestore_database"
protoPayload.status.code=7
```

This shows all permission denied errors.

### Create Dashboard

Monitor key metrics:
- Total violations created (per day)
- Suspension count (per day)
- Appeal submissions (per day)
- Contact detection blocks (per day)

---

## Step 5: Create Cloud Functions (Backend Logic)

Since violations can only be written by backend, create Cloud Functions:

### Function 1: Record Violation on Contact Sharing

**File**: `functions/src/recordViolation.ts`
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const recordViolation = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, violationType, description, relatedMessageId } = data;

  // Validate userId matches authenticated user (cannot report others)
  if (userId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot create violations for other users');
  }

  const db = admin.firestore();

  // Record violation
  await db.collection('users').doc(userId).collection('violations').add({
    type: violationType,
    description: description,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    relatedMessageId: relatedMessageId || null,
    reportedBy: 'system',
  });

  // Update violation count
  await db.collection('users').doc(userId).update({
    violationCount: admin.firestore.FieldValue.increment(1),
    lastViolation: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Apply rating penalty
  const violationWeights = {
    contactSharing: 0.5,
    spam: 0.3,
    inappropriate: 0.4,
    noShow: 0.2,
  };

  const penalty = violationWeights[violationType as keyof typeof violationWeights] || 0.3;

  const userDoc = await db.collection('users').doc(userId).get();
  const currentRating = userDoc.data()?.rating || 5.0;
  const newRating = Math.max(0, currentRating - penalty);

  await db.collection('users').doc(userId).update({
    rating: newRating,
  });

  // Check if suspension is needed
  if (newRating < 2.5) {
    await db.collection('users').doc(userId).update({
      isActive: false,
      suspension: {
        userId: userId,
        reason: 'lowRating',
        details: `Rating fell below 2.5 (${newRating.toFixed(1)}) due to policy violations`,
        suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
        canAppeal: true,
      },
    });
  }

  return { success: true, newRating };
});
```

### Function 2: Monitor Message for Contact Info

**File**: `functions/src/monitorMessages.ts`
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onMessageCreated = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const text = message.text || '';

    // Contact detection patterns
    const phonePattern = /(?:\+?244[\s-]?)?[9][1-9][0-9][\s-]?[0-9]{3}[\s-]?[0-9]{3}/i;
    const emailPattern = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/;

    if (phonePattern.test(text) || emailPattern.test(text)) {
      // High severity - record violation
      await admin.firestore()
        .collection('users')
        .doc(message.senderId)
        .collection('violations')
        .add({
          type: 'contactSharing',
          description: 'Shared contact information in chat',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          relatedMessageId: snap.id,
          reportedBy: 'system',
        });

      // Flag message
      await snap.ref.update({
        flagged: true,
        flagReason: 'contact_sharing',
      });

      console.log(`🚨 Contact sharing detected in message ${snap.id}`);
    }
  });
```

### Deploy Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Step 6: Update App to Call Cloud Functions

### In Chat Screen

After contact detection, record violation:

```dart
if (detectionResult.severity == ContactSeverity.high) {
  // Block message locally
  showError(detectionResult.getWarningMessage());

  // Record violation via Cloud Function
  final callable = FirebaseFunctions.instance.httpsCallable('recordViolation');
  try {
    await callable.call({
      'userId': currentUser.uid,
      'violationType': 'contactSharing',
      'description': 'Attempted to share contact information in chat',
      'relatedMessageId': null,
    });
  } catch (e) {
    debugPrint('Error recording violation: $e');
  }

  return; // Don't send message
}
```

---

## Step 7: Post-Deployment Verification

### Checklist

- [ ] Firestore rules deployed successfully
- [ ] Existing users migrated (all have rating: 5.0)
- [ ] Cloud Functions deployed
- [ ] Security rules tested in production
- [ ] Contact detection works end-to-end
- [ ] Violations recorded correctly
- [ ] Suspensions triggered automatically
- [ ] Appeals can be submitted
- [ ] Monitoring dashboards created

### Test End-to-End Flow

1. **Create test user**
2. **Send message with phone number** → Should be blocked
3. **Check Firestore** → Violation should be recorded
4. **Check user rating** → Should drop from 5.0
5. **Repeat 6 times** → Rating should hit < 2.5
6. **User should be suspended** → isActive: false
7. **Try to login** → Should see suspension screen
8. **Submit appeal** → Should appear in appeals collection

---

## Rollback Plan

If something goes wrong:

### 1. Rollback Firestore Rules

```bash
# Get previous rules
firebase firestore:rules:get --version <previous-version> > rollback.rules

# Deploy previous rules
firebase deploy --only firestore:rules
```

### 2. Rollback Cloud Functions

```bash
# List function versions
firebase functions:list

# Rollback specific function
firebase functions:delete recordViolation
firebase functions:delete onMessageCreated
```

### 3. Rollback User Ratings

If migration went wrong:
```typescript
// Reset all ratings to 5.0
const snapshot = await db.collection('users').get();
const batch = db.batch();
snapshot.docs.forEach(doc => {
  batch.update(doc.ref, { rating: 5.0 });
});
await batch.commit();
```

---

## Support & Monitoring

### Monitor These Metrics

1. **Violation Rate**
   - Normal: < 5% of users per day
   - High: > 10% indicates issue

2. **Suspension Rate**
   - Normal: < 1% of users per month
   - High: > 5% indicates too strict

3. **Appeal Rate**
   - Normal: 50% of suspended users appeal
   - Low: < 20% indicates unclear process

4. **False Positive Rate**
   - Target: < 2% of blocked messages
   - Measure via user reports

### Adjust Thresholds if Needed

If too many false positives:
- Adjust contact detection patterns
- Lower violation weights
- Lower suspension threshold

If too lenient:
- Add more detection patterns
- Increase violation weights
- Raise suspension threshold

---

## Deployment Checklist

```
Pre-Deployment:
[ ] Code reviewed
[ ] Tests passing
[ ] Firebase project ready
[ ] Backup created

Deployment:
[ ] Firestore rules deployed
[ ] Users migrated
[ ] Cloud Functions deployed
[ ] Monitoring set up

Post-Deployment:
[ ] End-to-end test passed
[ ] Security rules verified
[ ] Monitoring dashboards checked
[ ] Team notified

Rollback Ready:
[ ] Previous rules backed up
[ ] Rollback plan tested
[ ] Support team briefed
```

---

**Deployment Status**: ✅ Ready for Production

**Next**: Run through checklist and deploy when ready!
