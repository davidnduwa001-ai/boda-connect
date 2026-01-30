# Debug: Projections Exist But App Shows 0

## Step 1: Verify User Authentication

Open Flutter DevTools console and check:

```dart
// In supplier_dashboard_screen.dart or client_home_screen.dart
// Add this temporarily in build():

print('🔍 Current User ID: ${FirebaseAuth.instance.currentUser?.uid}');
print('🔍 Current User Email: ${FirebaseAuth.instance.currentUser?.email}');
```

**Check**: Does this UID match the document ID in `client_views/` or `supplier_views/`?

If the UIDs don't match, the provider is trying to load data for a different user.

---

## Step 2: Check Provider Loading State

Add debug logging to the provider:

### For Supplier Dashboard

```dart
// In supplier_dashboard_screen.dart, in build():
final viewState = ref.watch(supplierViewProvider);

print('🔍 SupplierView isLoading: ${viewState.isLoading}');
print('🔍 SupplierView error: ${viewState.error}');
print('🔍 SupplierView has data: ${viewState.view != null}');
if (viewState.view != null) {
  print('🔍 Pending bookings: ${viewState.view!.pendingBookings.length}');
  print('🔍 Recent bookings: ${viewState.view!.recentBookings.length}');
  print('🔍 Upcoming events: ${viewState.view!.upcomingEvents.length}');
}
```

### For Client Home

```dart
// In client_home_screen.dart, in build():
final viewState = ref.watch(clientViewProvider);

print('🔍 ClientView isLoading: ${viewState.isLoading}');
print('🔍 ClientView error: ${viewState.error}');
print('🔍 ClientView has data: ${viewState.view != null}');
if (viewState.view != null) {
  print('🔍 Active bookings: ${viewState.view!.activeBookings.length}');
  print('🔍 Recent bookings: ${viewState.view!.recentBookings.length}');
}
```

**Expected output**:
```
🔍 SupplierView isLoading: false
🔍 SupplierView error: null
🔍 SupplierView has data: true
🔍 Pending bookings: 3
🔍 Recent bookings: 5
```

**If you see**:
- `isLoading: true` forever → Provider stuck loading
- `error: "permission-denied"` → Security rules issue
- `error: "Usuário não autenticado"` → User not logged in
- `has data: false` → Document doesn't exist for this user

---

## Step 3: Check Firestore Security Rules

The provider might be blocked by security rules.

### Test direct Firestore read (temporary):

```dart
// Add this as a button action temporarily:
Future<void> testDirectRead() async {
  final user = FirebaseAuth.instance.currentUser;
  print('🔍 Testing direct read for user: ${user?.uid}');

  try {
    // For supplier
    final supplierState = ref.read(supplierProvider);
    final supplierId = supplierState.currentSupplier?.id;

    if (supplierId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('supplier_views')
          .doc(supplierId)
          .get();

      print('🔍 Document exists: ${doc.exists}');
      print('🔍 Document data: ${doc.data()}');
    }
  } catch (e) {
    print('❌ Error reading: $e');
  }
}
```

**If you get**:
- `permission-denied` → Security rules are blocking access
- `Document exists: false` → The projection doesn't exist for this supplier
- Document data shows up → Provider issue, not Firestore issue

---

## Step 4: Check Provider Initialization Timing

The provider might not be initializing on app start.

### Verify initialization in main.dart:

```dart
// In your app's main widget, ensure ProviderScope wraps everything:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ProviderScope(  // ← Must be here
      child: MyApp(),
    ),
  );
}
```

### Force provider refresh on screen load:

```dart
// In initState() of supplier_dashboard_screen.dart:
@override
void initState() {
  super.initState();
  Future.microtask(() async {
    print('🔍 Force refreshing supplier view...');
    await ref.read(supplierViewProvider.notifier).refresh();
    print('🔍 Refresh complete');
  });
}
```

---

## Step 5: Check if Old State is Cached

The app might be showing cached empty state.

**Solution**: Full app restart (not hot reload)

```bash
# Stop the app completely
# Then:
flutter clean
flutter pub get
flutter run
```

**Then**:
1. Log out from the app
2. Log back in
3. Check if data appears

---

## Step 6: Verify Firestore Document Structure

The projection might exist but have wrong structure.

Go to Firebase Console → Firestore → `supplier_views/{YOUR_SUPPLIER_ID}`

**Expected structure**:
```json
{
  "supplierId": "abc123",
  "businessName": "My Business",
  "pendingBookings": [
    {
      "bookingId": "book1",
      "clientName": "João",
      "eventName": "Casamento",
      "eventDate": "2026-02-15T10:00:00Z",
      "status": "pending",
      "totalAmount": 5000,
      "uiFlags": {
        "canAccept": true,
        "canDecline": true
      }
    }
  ],
  "recentBookings": [...],
  "upcomingEvents": [...],
  "unreadCounts": {
    "messages": 0,
    "notifications": 0,
    "pendingBookings": 1
  },
  "updatedAt": "2026-01-30T..."
}
```

**If structure is different** (e.g., missing fields, wrong types), the `fromFirestore()` parser might be failing silently.

---

## Common Issues & Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `isLoading: true` forever | Provider not initialized | Add debug logs in `_loadSupplierView()` |
| `error: "permission-denied"` | Security rules block access | Check Firestore rules |
| `has data: false` | Document doesn't exist for this user | Check document ID matches user/supplier ID |
| Data shows in logs but not UI | UI not reacting to provider | Ensure using `ref.watch()` not `ref.read()` |
| Works after hot reload | Provider initialization timing | Add `refresh()` call in `initState()` |

---

## Quick Test

Run this in your Flutter console:

```bash
# Watch for provider errors
flutter run --verbose 2>&1 | grep -E "SupplierView|ClientView|projection|permission"
```

Look for:
- ❌ "Error loading supplier view: permission-denied"
- ❌ "Error loading client view: document not found"
- ✅ "Loaded supplier view with X bookings"

---

## What to Check Next

Tell me which output you see:

**A)** `isLoading: true` (never becomes false)
**B)** `error: "permission-denied"`
**C)** `error: "Usuário não autenticado"`
**D)** `has data: true` but UI still shows 0
**E)** Something else (paste the console output)
