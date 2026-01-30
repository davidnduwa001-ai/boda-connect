# Boda Connect - Troubleshooting Guide

## Issue: App Not Working After Projection Migration

### Quick Fix Checklist

Follow these steps **in order**:

#### 1. Stop the App Completely
```bash
# Stop the running Flutter app (Ctrl+C or stop from IDE)
# DO NOT use hot reload - it won't pick up projection changes
```

#### 2. Clean and Rebuild
```bash
cd c:\Users\admin\Desktop\boda_connect_flutter_full_starter
flutter clean
flutter pub get
flutter run
```

#### 3. Log Out and Log Back In
- Open the app
- Go to Settings/Profile
- **Log Out**
- **Log Back In** (this reinitializes the projection providers)

#### 4. Check if Projections Exist

Run the backfill again to ensure data exists:
```bash
curl -X POST "https://us-central1-boda-connect-49eb9.cloudfunctions.net/runBackfillProjections" -H "Content-Type: application/json" -d "{}"
```

Expected response:
```json
{
  "success": true,
  "clientsProcessed": 1,
  "clientsFailed": 0,
  "suppliersProcessed": 1,
  "suppliersFailed": 0
}
```

---

## Common Issues & Solutions

### Issue 1: "No data showing in dashboard"

**Cause**: Projections are empty or not loaded

**Solution**:
1. Log out and log back in
2. Pull down to refresh the dashboard
3. Check Firebase Console → Firestore → `client_views` or `supplier_views` collections

### Issue 2: "Permission denied" errors

**Cause**: Security rules blocking access

**Check**:
1. Go to Firebase Console → Firestore → Rules
2. Verify these rules exist:

```javascript
// Client views
match /client_views/{clientId} {
  allow read: if request.auth != null && request.auth.uid == clientId;
  allow create, update, delete: if false;
}

// Supplier views
match /supplier_views/{supplierId} {
  allow read: if request.auth != null && isSupplierOwner(supplierId);
  allow create, update, delete: if false;
}
```

3. If rules are missing, deploy them:
```bash
firebase deploy --only firestore:rules
```

### Issue 3: "Unread notification badge shows 0"

**Cause**: Projection not updated or provider not watching

**Solution**:
1. Verify `clientUnreadNotificationsProvider` or `supplierUnreadNotificationsProvider` is imported
2. Check the provider is watching:
   ```dart
   final unreadCount = ref.watch(clientUnreadNotificationsProvider);
   ```
3. Trigger a notification to test:
   - Create a new booking
   - Check if badge updates

### Issue 4: "Messages not sending"

**Cause**: Cloud Function `sendMessage` not deployed or permission denied

**Check**:
1. Verify function is deployed:
   ```bash
   firebase functions:list | grep sendMessage
   ```
2. Check Flutter console for errors
3. Ensure you're a participant in the conversation

### Issue 5: "Booking details not loading"

**Cause**: Cloud Function `getClientBookingDetails` or `getSupplierBookingDetails` not working

**Check**:
1. Verify functions are deployed:
   ```bash
   firebase functions:list | grep BookingDetails
   ```
2. Check Firebase Console → Functions → Logs for errors
3. Verify you have permission to view the booking

---

## Debug Mode

### Enable Debug Logging

Add this to your `main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Firestore debug logging
  FirebaseFirestore.setLoggingEnabled(true);

  await Firebase.initializeApp(/* ... */);
  runApp(MyApp());
}
```

### Check Flutter Console

Look for these messages:
- ✅ `Loading client view for: {userId}`
- ✅ `Loaded client view with X bookings`
- ❌ `Error loading client view: permission-denied`
- ❌ `Error loading client view: document not found`

---

## Manual Verification

### 1. Check Firestore Console

**Client View Example** (`client_views/{userId}`):
```json
{
  "clientId": "abc123",
  "displayName": "João Silva",
  "email": "joao@example.com",
  "activeBookings": [],
  "recentBookings": [],
  "upcomingEvents": [],
  "unreadCounts": {
    "messages": 0,
    "notifications": 0
  },
  "paymentSummary": {
    "pendingPayments": 0,
    "totalSpent": 0,
    "escrowHeld": 0
  },
  "cartItemCount": 0,
  "updatedAt": "2026-01-30T..."
}
```

**Supplier View Example** (`supplier_views/{supplierId}`):
```json
{
  "supplierId": "xyz789",
  "businessName": "Fotografia Elegante",
  "categoryName": "Fotografia",
  "pendingBookings": [],
  "confirmedBookings": [],
  "recentBookings": [],
  "upcomingEvents": [],
  "unreadCounts": {
    "messages": 0,
    "notifications": 0
  },
  "stats": {
    "totalBookings": 0,
    "pendingCount": 0,
    "confirmedCount": 0
  },
  "updatedAt": "2026-01-30T..."
}
```

### 2. Test Cloud Functions Manually

**Test sendMessage**:
```bash
curl -X POST \
  "https://us-central1-boda-connect-49eb9.cloudfunctions.net/sendMessage" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {YOUR_TOKEN}" \
  -d '{
    "conversationId": "conv123",
    "senderId": "user1",
    "receiverId": "user2",
    "messageText": "Test message"
  }'
```

---

## Still Not Working?

### Check Firebase Console Logs

1. Go to Firebase Console → Functions → Logs
2. Look for errors in the last hour
3. Common errors:
   - `permission-denied`: Security rules blocking access
   - `not-found`: Document doesn't exist
   - `failed-precondition`: Business logic rejection

### Re-deploy Everything

```bash
# Re-deploy Cloud Functions
cd functions
npm run build
firebase deploy --only functions

# Re-deploy Firestore Rules
firebase deploy --only firestore:rules

# Clean and rebuild Flutter
cd ..
flutter clean
flutter pub get
flutter run
```

### Contact Support

If none of the above work, provide:
1. Flutter console logs
2. Firebase Console → Functions → Logs (last 1 hour)
3. Screenshot of error
4. User ID you're testing with

---

## Architecture Reference

```
┌─────────────────────────────────────────┐
│          Flutter UI Layer               │
│  client_home_screen                     │
│  supplier_dashboard                     │
│          ↓                              │
├─────────────────────────────────────────┤
│     Projection Providers                │
│  clientViewProvider                     │
│  supplierViewProvider                   │
│  clientUnreadNotificationsProvider      │
│          ↓                              │
├─────────────────────────────────────────┤
│     Firestore Projections               │
│  client_views/{userId}                  │
│  supplier_views/{supplierId}            │
│          ↓                              │
├─────────────────────────────────────────┤
│     Cloud Functions (Triggers)          │
│  projectionOnBookingCreated             │
│  projectionOnMessageCreated             │
│  projectionOnPaymentUpdated             │
└─────────────────────────────────────────┘
```

**Key Concept**: The UI only reads from projections. Cloud Functions update projections automatically when source data changes.
