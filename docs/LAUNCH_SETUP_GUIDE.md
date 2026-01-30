# BODA CONNECT - Launch Setup Guide

This guide covers the configuration steps needed before launching BODA CONNECT.

---

## 📋 Table of Contents

1. [Multicaixa Express Setup](#1-multicaixa-express-setup)
2. [Firebase Configuration](#2-firebase-configuration)
3. [Deep Links Configuration](#3-deep-links-configuration)
4. [App Store / Play Store Setup](#4-app-store--play-store-setup)

---

## 1. ProxyPay / Multicaixa Express Setup

BODA CONNECT uses **ProxyPay** to integrate with Multicaixa Express, Angola's national payment network.

ProxyPay provides two payment methods:
- **OPG (Online Payment Gateway)**: Customer receives push notification on Multicaixa Express app
- **RPS (Reference Payment System)**: Customer pays at ATM or home banking using Entity + Reference

### Step 1: Register with ProxyPay

1. Visit [https://proxypay.co.ao](https://proxypay.co.ao)
2. Contact TimeBoxed (the company behind ProxyPay) to request merchant access
3. Requirements:
   - Angolan business registration (NIF)
   - Business bank account with a participating Angolan bank (BFA, BAI, BIC, etc.)
   - Signed merchant agreement

### Step 2: Get API Credentials

Once approved, you will receive:
- **API Key**: For authentication with ProxyPay API
- **Entity ID**: Your assigned entity number for reference payments (RPS)

Documentation: [https://developer.proxypay.co.ao/](https://developer.proxypay.co.ao/)

### Step 3: Configure in App

Edit `lib/core/config/app_config.dart`:

```dart
// Sandbox (for testing)
static const String proxyPaySandboxApiKey = 'YOUR_SANDBOX_API_KEY';
static const String proxyPaySandboxUrl = 'https://api.sandbox.proxypay.co.ao';

// Production (for live payments)
static const String proxyPayProdApiKey = 'YOUR_PRODUCTION_API_KEY';
static const String proxyPayProdUrl = 'https://api.proxypay.co.ao';

// Entity ID for reference payments
static const String proxyPayEntityId = 'YOUR_ENTITY_ID'; // e.g., "12345"
```

### Step 4: Set Up Webhook (Firebase Cloud Function)

Create Cloud Functions to receive payment notifications from ProxyPay:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

/**
 * ProxyPay Webhook Handler
 * Receives notifications for both OPG and RPS payments
 *
 * OPG format: { "id": "...", "reference_id": "...", "status": "accepted" }
 * RPS format: { "reference": "...", "amount": ..., "datetime": "..." }
 */
exports.proxyPayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const data = req.body;
    console.log('ProxyPay webhook received:', JSON.stringify(data));

    let reference;
    let paymentStatus;

    // Determine webhook type
    if (data.reference_id) {
      // OPG payment callback
      reference = data.reference_id;
      paymentStatus = data.status === 'accepted' ? 'completed' : 'failed';
    } else if (data.reference) {
      // RPS payment notification (payment received at ATM/bank)
      reference = data.reference;
      paymentStatus = 'completed'; // RPS webhooks only fire on successful payment
    } else {
      console.log('Unknown webhook format');
      return res.status(400).send('Unknown format');
    }

    // Find payment by reference
    const paymentsRef = db.collection('payments');
    const query = await paymentsRef.where('reference', '==', reference).limit(1).get();

    if (query.empty) {
      console.log('Payment not found for reference:', reference);
      return res.status(404).send('Payment not found');
    }

    const paymentDoc = query.docs[0];
    const paymentData = paymentDoc.data();

    // Update payment status
    await paymentDoc.ref.update({
      status: paymentStatus,
      providerResponse: data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(paymentStatus === 'completed' && { completedAt: admin.firestore.FieldValue.serverTimestamp() })
    });

    // If payment completed, handle escrow funding
    if (paymentStatus === 'completed') {
      const escrowId = paymentData.metadata?.escrowId;
      const bookingId = paymentData.bookingId;

      // Update escrow to funded
      if (escrowId) {
        await db.collection('escrow').doc(escrowId).update({
          status: 'funded',
          fundedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      // Update booking payment status
      if (bookingId) {
        await db.collection('bookings').doc(bookingId).update({
          paymentStatus: escrowId ? 'escrow_funded' : 'paid',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      // Notify supplier
      if (paymentData.metadata?.supplierId) {
        await db.collection('notifications').add({
          userId: paymentData.metadata.supplierId,
          type: 'payment_received',
          title: 'Pagamento Recebido',
          message: `Pagamento de ${paymentData.amount} Kz foi confirmado.`,
          data: { bookingId, paymentId: paymentDoc.id },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    }

    console.log(`Payment ${reference} updated to ${paymentStatus}`);
    res.status(200).send('OK');
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).send('Error');
  }
});
```

Deploy with:
```bash
cd functions
npm install
firebase deploy --only functions
```

### Step 5: Configure Webhook URL in ProxyPay

After deploying, configure your webhook URL in the ProxyPay dashboard:

```
https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/proxyPayWebhook
```

### Step 6: Test Payments

**Testing OPG (Mobile Payments):**
1. Use sandbox API credentials
2. Create a payment with a test phone number
3. The sandbox simulates the push notification flow
4. Check Firestore for payment status updates

**Testing RPS (Reference Payments):**
1. Generate a reference using the sandbox API
2. Simulate a payment via ProxyPay sandbox tools
3. Verify webhook receives the notification
4. Check Firestore for payment completion

### Payment Flow Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                     OPG (Mobile Payment)                        │
├─────────────────────────────────────────────────────────────────┤
│ 1. App calls createPayment() with customer phone               │
│ 2. ProxyPay sends push notification to MCX Express app         │
│ 3. Customer approves payment in 90 seconds                     │
│ 4. ProxyPay calls webhook with status                          │
│ 5. App updates payment & escrow status                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   RPS (Reference Payment)                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. App calls createReferencePayment()                          │
│ 2. Customer sees Entity + Reference + Amount                   │
│ 3. Customer pays at ATM or via home banking                    │
│ 4. ProxyPay calls webhook when payment received                │
│ 5. App updates payment & escrow status                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Firebase Configuration

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: `boda-connect`
3. Enable Google Analytics

### Step 2: Add Apps

**Android:**
1. Click "Add App" > Android
2. Package name: `ao.bodaconnect.app`
3. Download `google-services.json`
4. Place in `android/app/`

**iOS:**
1. Click "Add App" > iOS
2. Bundle ID: `ao.bodaconnect.app`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/`

### Step 3: Enable Services

**Authentication:**
1. Go to Authentication > Sign-in method
2. Enable:
   - Phone (for OTP)
   - Email/Password (optional)

**Firestore:**
1. Go to Firestore Database
2. Create database (start in production mode)
3. Add security rules (see below)

**Storage:**
1. Go to Storage
2. Get started
3. Set security rules

**Cloud Messaging:**
1. Go to Cloud Messaging
2. Note your Server Key (for backend)

### Step 4: Security Rules

**Firestore Rules (`firestore.rules`):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Suppliers can be read by anyone, written by owner
    match /suppliers/{supplierId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == supplierId;
    }

    // Bookings can be read/written by client or supplier
    match /bookings/{bookingId} {
      allow read, write: if request.auth != null &&
        (resource.data.clientId == request.auth.uid ||
         resource.data.supplierId == request.auth.uid);
    }

    // Payments are read-only for users, write by server
    match /payments/{paymentId} {
      allow read: if request.auth != null &&
        resource.data.userId == request.auth.uid;
    }

    // Settings readable by all, writable by admins
    match /settings/{doc} {
      allow read: if true;
      allow write: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## 3. Deep Links Configuration

### Android App Links

1. **Get SHA256 Fingerprint:**
```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android

# Release
keytool -list -v -keystore your-release-key.keystore -alias your-alias
```

2. **Host assetlinks.json:**
Upload `docs/deep_links/assetlinks.json` to:
```
https://bodaconnect.ao/.well-known/assetlinks.json
```

Update the SHA256 fingerprint in the file.

### iOS Universal Links

1. **Get Team ID:**
   - Go to [Apple Developer Account](https://developer.apple.com)
   - Find Team ID in Membership section

2. **Update apple-app-site-association:**
Edit `docs/deep_links/apple-app-site-association`:
```json
{
  "applinks": {
    "details": [{
      "appID": "TEAM_ID.ao.bodaconnect.app",
      ...
    }]
  }
}
```

3. **Host the file:**
Upload to:
```
https://bodaconnect.ao/.well-known/apple-app-site-association
```
(No file extension, serve as `application/json`)

4. **Configure in Xcode:**
   - Open `ios/Runner.xcworkspace`
   - Go to Signing & Capabilities
   - Add "Associated Domains"
   - Add: `applinks:bodaconnect.ao`
   - Add: `applinks:bodaconnect.page.link`

### Firebase Dynamic Links

1. Go to Firebase Console > Dynamic Links
2. Add domain: `bodaconnect.page.link`
3. Verify ownership if using custom domain

---

## 4. App Store / Play Store Setup

### Google Play Store

1. **Create Developer Account:**
   - [Play Console](https://play.google.com/console)
   - Pay $25 registration fee

2. **Create App Listing:**
   - App name: BODA CONNECT
   - Default language: Portuguese
   - Category: Lifestyle or Business

3. **Prepare Assets:**
   - App icon: 512x512 PNG
   - Feature graphic: 1024x500 PNG
   - Screenshots: At least 2 per device type
   - Privacy policy URL

4. **Build Release APK:**
```bash
flutter build appbundle --release
```

5. **Upload to Play Console:**
   - Go to Production > Create new release
   - Upload the `.aab` file
   - Submit for review

### Apple App Store

1. **Create Developer Account:**
   - [Apple Developer Program](https://developer.apple.com/programs/)
   - Pay $99/year

2. **Create App in App Store Connect:**
   - [App Store Connect](https://appstoreconnect.apple.com)
   - New App > iOS
   - Bundle ID: `ao.bodaconnect.app`

3. **Prepare Assets:**
   - App icon: 1024x1024 PNG
   - Screenshots for iPhone and iPad
   - Privacy policy URL

4. **Build Release IPA:**
```bash
flutter build ipa --release
```

5. **Upload via Transporter or Xcode:**
   - Open `build/ios/ipa/` folder
   - Use Transporter app to upload

6. **Submit for Review:**
   - Fill in app information
   - Submit for review (1-7 days typically)

---

## ✅ Pre-Launch Checklist

- [ ] Multicaixa Express merchant account approved
- [ ] API credentials configured in app_config.dart
- [ ] Webhook Cloud Function deployed
- [ ] Firebase project created with all services
- [ ] Security rules deployed
- [ ] Deep links tested (Android & iOS)
- [ ] assetlinks.json hosted on domain
- [ ] apple-app-site-association hosted on domain
- [ ] Play Store listing created
- [ ] App Store listing created
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Test payment flow end-to-end
- [ ] Test notifications on real devices

---

## 📞 Support Contacts

- **Multicaixa/EMIS Support:** Contact via developer portal
- **Firebase Support:** [firebase.google.com/support](https://firebase.google.com/support)
- **Apple Developer Support:** [developer.apple.com/support](https://developer.apple.com/support)
- **Google Play Support:** [support.google.com/googleplay/android-developer](https://support.google.com/googleplay/android-developer)

---

## 🔐 Security Reminders

1. **Never commit credentials to git**
   - Use environment variables or secure storage
   - Add `app_config.dart` to `.gitignore` if it contains secrets

2. **Enable App Check in Firebase**
   - Protects your backend from abuse

3. **Review Firestore Security Rules**
   - Test with the Security Rules Simulator

4. **Use HTTPS everywhere**
   - All API calls should be HTTPS only
