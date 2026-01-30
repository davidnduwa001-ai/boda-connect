# UI-First Architecture Migration Guide

## Overview

This document lists all direct Firestore reads that violate the UI contract and their projection-based replacements.

**Rule**: Flutter UI must ONLY read from `client_views/{clientId}` and `supplier_views/{supplierId}` projections. All other data access must go through Cloud Functions.

---

## Migration Status

| Category | Legacy Location | Replacement | Status |
|----------|-----------------|-------------|--------|
| Client Bookings | `booking_repository.streamClientBookings()` | `clientViewStreamProvider` | PENDING |
| Client Recent | `booking_provider.clientBookingsStreamProvider` | `clientRecentBookingsProvider` | PENDING |
| Client Upcoming | Direct computation | `clientUpcomingEventsProvider` | PENDING |
| Supplier Bookings | `SupplierBookingsNotifier` | `supplierViewStreamProvider` | USES CF (OK) |
| Supplier Pending | `pendingBookingsCountProvider` | `supplierPendingCountProvider` | PENDING |
| Supplier Upcoming | `upcomingEventsStreamProvider` | `supplierUpcomingEventsProvider` | PENDING |
| Supplier Recent | `recentOrdersStreamProvider` | `supplierRecentBookingsProvider` | PENDING |
| Availability Stats | `availability_provider.dart` | `supplierAvailabilitySummaryProvider` | PENDING |
| Unread Messages | Direct conversation query | `clientUnreadMessagesProvider` / `supplierUnreadMessagesProvider` | PENDING |
| Dashboard Stats | `supplierBookingStatsProvider` | `supplierDashboardStatsProvider` | PENDING |
| Earnings | `supplier_stats_service.dart` | `supplierEarningsSummaryProvider` | PENDING |

---

## Files to Update

### 1. Client Dashboard

**File**: `lib/features/client/presentation/screens/client_home_screen.dart`

Replace:
```dart
// OLD - Direct Firestore read
final bookings = ref.watch(clientBookingsStreamProvider);
```

With:
```dart
// NEW - Projection read
final clientView = ref.watch(clientViewStreamProvider);
final recentBookings = clientView.value?.recentBookings ?? [];
```

### 2. Supplier Dashboard

**File**: `lib/features/supplier/presentation/screens/supplier_dashboard_screen.dart`

Replace:
```dart
// OLD - Uses notifier that calls CF (acceptable but can optimize)
final bookings = ref.watch(supplierBookingsStreamProvider);
final pending = ref.watch(pendingBookingsCountProvider);
final upcoming = ref.watch(upcomingEventsStreamProvider);
```

With:
```dart
// NEW - Single projection read
final supplierView = ref.watch(supplierViewStreamProvider);
final pending = supplierView.value?.pendingBookings ?? [];
final upcoming = supplierView.value?.upcomingEvents ?? [];
final stats = supplierView.value?.dashboardStats;
```

### 3. Availability Calendar

**File**: `lib/core/providers/availability_provider.dart`

Replace:
```dart
// OLD - Direct subcollection read
final snapshot = await _firestore
    .collection('suppliers')
    .doc(supplierId)
    .collection('blocked_dates')
    .get();
```

With:
```dart
// NEW - Projection read
final blockedDates = ref.watch(supplierBlockedDatesFromViewProvider);
```

### 4. Message Badges

**File**: Various navigation/badge widgets

Replace:
```dart
// OLD - Direct conversation query
final unread = await getUnreadMessageCount(userId);
```

With:
```dart
// NEW - Projection read
final unread = ref.watch(clientUnreadMessagesProvider); // or supplierUnreadMessagesProvider
```

---

## Provider Mappings

### Client View Providers (lib/core/providers/client_view_provider.dart)

| Provider | Data |
|----------|------|
| `clientViewProvider` | Full client view state |
| `clientViewStreamProvider` | Real-time stream of client view |
| `clientActiveBookingsProvider` | Active bookings list |
| `clientRecentBookingsProvider` | Recent 10 bookings |
| `clientUpcomingEventsProvider` | Next 5 upcoming events |
| `clientUnreadMessagesProvider` | Unread message count |
| `clientCartCountProvider` | Cart item count |
| `clientPaymentSummaryProvider` | Payment totals |

### Supplier View Providers (lib/core/providers/supplier_view_provider.dart)

| Provider | Data |
|----------|------|
| `supplierViewProvider` | Full supplier view state |
| `supplierViewStreamProvider` | Real-time stream of supplier view |
| `supplierPendingBookingsProvider` | Pending bookings list |
| `supplierConfirmedBookingsProvider` | Confirmed bookings list |
| `supplierRecentBookingsProvider` | Recent 10 bookings |
| `supplierUpcomingEventsProvider` | Next 5 upcoming events |
| `supplierDashboardStatsProvider` | Dashboard statistics |
| `supplierUnreadMessagesProvider` | Unread message count |
| `supplierPendingCountProvider` | Pending booking count (for badge) |
| `supplierEarningsSummaryProvider` | Earnings data |
| `supplierAvailabilitySummaryProvider` | Availability stats |
| `supplierBlockedDatesFromViewProvider` | Blocked dates for calendar |
| `supplierAccountFlagsProvider` | Account status flags |
| `isSupplierBookableFromViewProvider` | Bookability status |

---

## UI Flags for Buttons

Each booking in the projection includes `uiFlags` that map 1:1 to UI buttons:

### Client Booking UI Flags
```dart
class ClientBookingUIFlags {
  final bool canCancel;      // Show "Cancelar" button
  final bool canPay;         // Show "Pagar" button
  final bool canReview;      // Show "Avaliar" button
  final bool canMessage;     // Show "Mensagem" button
  final bool canViewDetails; // Show "Ver Detalhes" button
  final bool canRequestRefund; // Show "Pedir Reembolso" button
  final bool showPaymentPending; // Show payment warning badge
  final bool showEscrowHeld;     // Show escrow indicator
}
```

### Supplier Booking UI Flags
```dart
class SupplierBookingUIFlags {
  final bool canAccept;      // Show "Aceitar" button
  final bool canDecline;     // Show "Recusar" button
  final bool canComplete;    // Show "Concluir" button
  final bool canCancel;      // Show "Cancelar" button
  final bool canMessage;     // Show "Mensagem" button
  final bool canViewDetails; // Show "Ver Detalhes" button
  final bool showExpiringSoon;    // Show urgent badge (< 24h)
  final bool showPaymentReceived; // Show payment confirmed badge
}
```

**Rule**: If `uiFlags.canAccept` is false, the "Aceitar" button must not be shown. The backend has already validated this - UI must not second-guess.

---

## Deployment Order

1. **Deploy Cloud Functions** (with projection triggers)
   ```bash
   firebase deploy --only functions
   ```

2. **Verify triggers fire** on new events (check logs)

3. **Run backfill** for existing data
   ```bash
   curl -X POST https://us-central1-YOUR_PROJECT.cloudfunctions.net/runBackfillProjections
   ```

4. **Verify projections** are populated in Firestore Console

5. **Deploy Flutter app** with updated providers

---

## Verification Checklist

After migration, verify:

- [ ] No `collection('bookings')` reads in client/supplier UI code
- [ ] No `collection('payments')` reads in UI code
- [ ] No `collection('escrow')` reads in UI code
- [ ] No `collection('conversations')` reads for unread counts
- [ ] All booking lists come from projections
- [ ] All stats come from projections
- [ ] UI buttons respect `uiFlags` without additional logic
- [ ] No PERMISSION_DENIED errors in logs

---

## Emergency Rollback

If projections fail:

1. The old providers still work (just deprecated)
2. Cloud Functions can be disabled individually
3. Backfill can be re-run safely (idempotent)

The architecture allows gradual migration - both old and new providers can coexist during transition.
