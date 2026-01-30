# Final Fixes Needed - Boda Connect

## Issues Identified

### 1. ❌ Métodos de Pagamento (Client Side) - Showing Placeholder
### 2. ❌ Histórico - Empty Handler
### 3. ⚠️ Categories Dashboard - May Be Empty
### 4. ⏳ Real-Time Location - Needs Implementation

---

## 1. Métodos de Pagamento (Payment Methods) - Client Side

### Current State:
- Shows placeholder screen
- Route: `Routes.paymentMethod`
- Located in: [app_router.dart:291-293](../lib/core/routing/app_router.dart)

### Solution:

**Option A: Use Existing Payment Methods Screen (Supplier)**
The payment methods screen already exists for suppliers. We can reuse it for clients by making it role-agnostic.

**Option B: Create Client-Specific Payment Screen**
Create a simpler version for clients that only allows viewing saved payment methods.

### Recommended Implementation:

**Since clients need payment methods for bookings**, create a client payment methods screen:

**File**: `lib/features/client/presentation/screens/client_payment_methods_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClientPaymentMethodsScreen extends ConsumerWidget {
  const ClientPaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métodos de Pagamento'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildPaymentOption(
            icon: Icons.account_balance,
            title: 'Transferência Bancária',
            subtitle: 'Pague diretamente ao fornecedor',
          ),
          const Divider(),
          _buildPaymentOption(
            icon: Icons.money,
            title: 'Pagamento em Dinheiro',
            subtitle: 'Pague em dinheiro no local',
          ),
          const Divider(),
          _buildPaymentOption(
            icon: Icons.payment,
            title: 'Multicaixa Express',
            subtitle: 'Pagamento móvel',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Como Funciona',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Os pagamentos são feitos diretamente ao fornecedor. '
              'Escolha o método de pagamento ao fazer a reserva.',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, size: 32, color: Colors.orange),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }
}
```

**Update Router** ([app_router.dart:291-293](../lib/core/routing/app_router.dart)):
```dart
GoRoute(
  path: Routes.paymentMethod,
  builder: (context, state) => const ClientPaymentMethodsScreen(),
),
```

---

## 2. Histórico (History) Screen

### Current State:
- Empty handler: `onTap: () {}`
- Located in: [client_profile_screen.dart:215](../lib/features/client/presentation/screens/client_profile_screen.dart)

### Solution:

Create a history screen showing past bookings:

**File**: `lib/features/client/presentation/screens/client_history_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boda_connect/core/providers/booking_provider.dart';
import 'package:boda_connect/core/models/booking_model.dart';
import 'package:boda_connect/core/constants/colors.dart';

class ClientHistoryScreen extends ConsumerWidget {
  const ClientHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(clientBookingsProvider);

    // Filter for completed and cancelled bookings (history)
    final historyBookings = bookings.where((b) =>
      b.status == BookingStatus.completed ||
      b.status == BookingStatus.cancelled
    ).toList();

    // Sort by date (most recent first)
    historyBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        backgroundColor: AppColors.white,
      ),
      body: historyBookings.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: historyBookings.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final booking = historyBookings[index];
                return _buildHistoryCard(booking);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Nenhum histórico ainda',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Suas reservas concluídas aparecerão aqui',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BookingModel booking) {
    final isCompleted = booking.status == BookingStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.cancel,
                  color: isCompleted ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.supplierName ?? 'Fornecedor',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  isCompleted ? 'Concluído' : 'Cancelado',
                  style: TextStyle(
                    color: isCompleted ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _formatDate(booking.eventDate),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${booking.totalAmount} Kz',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Data não disponível';
    return '${date.day}/${date.month}/${date.year}';
  }
}
```

**Add Route** to `app_router.dart`:
```dart
GoRoute(
  path: Routes.history,
  builder: (context, state) => const ClientHistoryScreen(),
),
```

**Add Route Constant** to `route_names.dart`:
```dart
static const String history = '/history';
```

**Update Profile Screen** ([client_profile_screen.dart:211-215](../lib/features/client/presentation/screens/client_profile_screen.dart)):
```dart
_buildMenuItem(
  context,
  icon: Icons.history_outlined,
  title: 'Histórico',
  onTap: () => context.push(Routes.history),
),
```

---

## 3. Empty Categories Dashboard

### Issue:
Categories may appear empty because Firestore `categories` collection is not seeded.

### Solution:

**The app already has a fallback** to default categories when Firestore is empty (this is CORRECT behavior).

However, to populate Firestore with categories, use the seed script:

**Created**: [lib/scripts/seed_categories.dart](../lib/scripts/seed_categories.dart)

### How to Use:

**Option A: Add a Debug Button (Recommended for Development)**

In your debug/settings screen, add:
```dart
ElevatedButton(
  onPressed: () async {
    final exist = await SeedCategories.categoriesExist();
    if (!exist) {
      await SeedCategories.seedToFirestore();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Categories seeded to Firestore!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categories already exist')),
      );
    }
  },
  child: Text('Seed Categories to Firestore'),
)
```

**Option B: Run Once in main.dart**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Seed categories on first run (optional)
  final exist = await SeedCategories.categoriesExist();
  if (!exist) {
    await SeedCategories.seedToFirestore();
  }

  runApp(const MyApp());
}
```

**Option C: Firebase Console**

Manually add categories to Firestore using the [seed_categories.dart](../lib/scripts/seed_categories.dart) data structure.

### Why Categories Might Appear Empty:

1. **Firestore Empty** - No categories in database yet → Use seed script
2. **No Internet** - Can't fetch from Firestore → Falls back to defaults ✅
3. **Firestore Rules** - Permission denied → Check firestore.rules

**The fallback system is already working correctly!**

---

## 4. Real-Time Location Updates

### Current State:
- Location is set during registration
- Not updated in real-time
- No GPS tracking

### Solution: Add Location Update Functionality

### 4.1. Add Dependencies

**pubspec.yaml**:
```yaml
dependencies:
  geolocator: ^11.0.0  # For GPS location
  permission_handler: ^11.0.0  # For permissions
```

### 4.2. Create Location Service

**File**: `lib/core/services/location_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  static Future<void> updateUserLocation() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final position = await getCurrentLocation();
    if (position == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'location.geopoint': GeoPoint(
        position.latitude,
        position.longitude,
      ),
      'location.lastUpdated': FieldValue.serverTimestamp(),
    });

    print('✅ Location updated: ${position.latitude}, ${position.longitude}');
  }

  static Future<void> updateSupplierLocation(String supplierId) async {
    final position = await getCurrentLocation();
    if (position == null) return;

    await FirebaseFirestore.instance
        .collection('suppliers')
        .doc(supplierId)
        .update({
      'location.geopoint': GeoPoint(
        position.latitude,
        position.longitude,
      ),
      'location.lastUpdated': FieldValue.serverTimestamp(),
    });

    print('✅ Supplier location updated');
  }
}
```

### 4.3. Add Location Update to Client Home

**In client_home_screen.dart initState**:
```dart
@override
void initState() {
  super.initState();

  Future.microtask(() {
    ref.read(browseSuppliersProvider.notifier).loadSuppliers();

    // Update location on app open (optional)
    LocationService.updateUserLocation();
  });
}
```

### 4.4. Add Location Settings to Profile

Add a menu item in client profile:

```dart
_buildMenuItem(
  context,
  icon: Icons.my_location,
  title: 'Atualizar Localização',
  onTap: () async {
    await LocationService.updateUserLocation();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Localização atualizada')),
    );
  },
),
```

### 4.5. Platform Configuration

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para encontrar fornecedores perto de si.</string>
```

---

## Implementation Priority

### High Priority (Fix Now):
1. ✅ Create `ClientPaymentMethodsScreen` for payment methods
2. ✅ Create `ClientHistoryScreen` for history
3. ✅ Update routes in `app_router.dart`
4. ✅ Update profile screen handlers

### Medium Priority (Before Production):
5. ⏳ Seed categories to Firestore (use seed script)
6. ⏳ Add location service with GPS
7. ⏳ Add location update option in profile
8. ⏳ Configure platform permissions

### Low Priority (Future Enhancement):
9. Background location updates
10. Proximity-based "Perto de si" filtering
11. Map view for suppliers

---

## Quick Implementation Guide

### Step 1: Create Missing Screens

Create these files:
- `lib/features/client/presentation/screens/client_payment_methods_screen.dart`
- `lib/features/client/presentation/screens/client_history_screen.dart`
- `lib/core/services/location_service.dart` (if implementing location)

### Step 2: Update Router

Update `lib/core/routing/app_router.dart`:
```dart
// Add import
import 'package:boda_connect/features/client/presentation/screens/client_payment_methods_screen.dart';
import 'package:boda_connect/features/client/presentation/screens/client_history_screen.dart';

// Update routes
GoRoute(
  path: Routes.paymentMethod,
  builder: (context, state) => const ClientPaymentMethodsScreen(),
),

// Add new route
GoRoute(
  path: Routes.history,
  builder: (context, state) => const ClientHistoryScreen(),
),
```

### Step 3: Update Route Names

Add to `lib/core/routing/route_names.dart`:
```dart
static const String history = '/history';
```

### Step 4: Update Profile Screen

Update `lib/features/client/presentation/screens/client_profile_screen.dart`:
```dart
_buildMenuItem(
  context,
  icon: Icons.history_outlined,
  title: 'Histórico',
  onTap: () => context.push(Routes.history),
),
```

### Step 5: Seed Categories (Optional)

Run the seed script or add to your app initialization.

---

## Testing Checklist

### Payment Methods:
- [ ] Navigate to "Métodos de Pagamento" from profile
- [ ] Screen shows payment options
- [ ] No placeholder screen shown

### History:
- [ ] Navigate to "Histórico" from profile
- [ ] Shows empty state if no history
- [ ] Shows completed/cancelled bookings when available
- [ ] Sorted by most recent first

### Categories:
- [ ] Categories display on home screen (either from Firestore or defaults)
- [ ] Tapping category navigates correctly
- [ ] Subcategories expand and show items

### Location (if implemented):
- [ ] Location permission requested
- [ ] GPS coordinates saved to Firestore
- [ ] Location updates when requested
- [ ] Works on both Android and iOS

---

## Files to Create/Modify

### Create:
1. `lib/features/client/presentation/screens/client_payment_methods_screen.dart`
2. `lib/features/client/presentation/screens/client_history_screen.dart`
3. `lib/core/services/location_service.dart` (optional)
4. ✅ `lib/scripts/seed_categories.dart` (already created)

### Modify:
1. `lib/core/routing/app_router.dart`
2. `lib/core/routing/route_names.dart`
3. `lib/features/client/presentation/screens/client_profile_screen.dart`
4. `pubspec.yaml` (if adding location services)
5. `android/app/src/main/AndroidManifest.xml` (if adding location)
6. `ios/Runner/Info.plist` (if adding location)

---

**Last Updated**: 2026-01-21
**Status**: Ready to implement - Clear action items provided
