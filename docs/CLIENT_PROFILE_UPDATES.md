# Client Profile - Dynamic Implementation

## Status: ✅ Complete - All Features Now Dynamic

All hardcoded data in client profile has been removed and replaced with dynamic data from Firestore.

---

## Changes Made

### 1. Location Display - Now Dynamic ✅

**Problem**: Location was hardcoded fallback to `'Luanda, Angola'`

**Solution**: Now displays actual province and city from user's location data

**File Modified**: [lib/features/client/presentation/screens/client_profile_screen.dart](../lib/features/client/presentation/screens/client_profile_screen.dart:57-63)

**Before**:
```dart
final userLocation = currentUser?.location?.city ?? 'Luanda, Angola';
```

**After**:
```dart
// Build location string from province and city
final location = currentUser?.location;
final userLocation = location != null && location.city != null
    ? location.province != null
        ? '${location.city}, ${location.province}'
        : location.city!
    : 'Angola';
```

**Display Format**:
- Full location: "Talatona, Luanda"
- City only: "Luanda"
- No location: "Angola"

---

### 2. Messages Badge - Now Dynamic ✅

**Problem**: Messages had hardcoded badge count of `'2'`

**Solution**: Now shows real unread message count from chat provider

**File Modified**: [lib/features/client/presentation/screens/client_profile_screen.dart](../lib/features/client/presentation/screens/client_profile_screen.dart:184-212)

**Before**:
```dart
_buildMenuItem(
  context,
  icon: Icons.chat_bubble_outline,
  title: 'Mensagens',
  badge: '2',  // ❌ Hardcoded
  onTap: () => context.push(Routes.chatList),
),
```

**After**:
```dart
// Get unread messages count
final unreadCount = ref.watch(chat.totalUnreadProvider);

_buildMenuItem(
  context,
  icon: Icons.chat_bubble_outline,
  title: 'Mensagens',
  badge: unreadCount > 0 ? '$unreadCount' : null,  // ✅ Dynamic
  onTap: () => context.push(Routes.chatList),
),
```

**Behavior**:
- Shows badge with count when there are unread messages
- Hides badge when no unread messages (count = 0)
- Updates in real-time as messages arrive

---

## Already Dynamic Features (From Previous Work)

### 3. Profile Stats ✅
- **Reservas**: Real count from `clientBookingsProvider` (non-cancelled bookings)
- **Favoritos**: Real count from `favoritesProvider.favoriteSuppliers`
- **Avaliações**: Real count from completed bookings

### 4. User Information ✅
- **Name**: From `currentUser?.name`
- **Phone**: From `currentUser?.phone`
- **Profile Photo**: Initials generated from name

---

## Menu Items Status

| Menu Item | Data Source | Status |
|-----------|-------------|--------|
| **Minhas Reservas** | Dynamic from Firestore | ✅ Dynamic |
| **Favoritos** | Dynamic from Firestore | ✅ Dynamic |
| **Mensagens** | Real-time unread count | ✅ Dynamic |
| **Métodos de Pagamento** | Routes to payment screen | ✅ Functional |
| **Histórico** | Empty handler (TODO) | ⚠️ Needs implementation |
| **Notificações** | Routes to notifications screen | ✅ Functional |
| **Ajuda & Suporte** | Routes to help center | ✅ Functional |
| **Segurança & Privacidade** | Routes to security screen | ✅ Functional |
| **Termos de Uso** | Routes to terms screen | ✅ Functional |

---

## Location-Based Supplier Detection

### Current Implementation:
The app currently shows suppliers based on:
1. **Active status**: `isActive: true`
2. **Rating**: Sorted by rating (highest first)
3. **Featured status**: For "Destaques" section

### Nearby Suppliers ("Perto de si"):
Currently loads first 20 suppliers sorted by rating, not actual proximity.

**To implement true proximity detection**, you need:

#### Option 1: GeoPoint-Based Distance Calculation

**Update User Model** to store GeoPoint:
```dart
// Already supported in LocationData class
final geopoint = GeoPoint(latitude, longitude);
```

**Get User Location**:
```dart
import 'package:geolocator/geolocator.dart';

Future<Position?> getUserLocation() async {
  // Request permission
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    return null;
  }

  // Get current position
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
```

**Save to Firestore**:
```dart
final position = await getUserLocation();
if (position != null) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .update({
    'location.geopoint': GeoPoint(
      position.latitude,
      position.longitude,
    ),
  });
}
```

**Calculate Distance**:
```dart
import 'package:geolocator/geolocator.dart';

double calculateDistance(GeoPoint point1, GeoPoint point2) {
  return Geolocator.distanceBetween(
    point1.latitude,
    point1.longitude,
    point2.latitude,
    point2.longitude,
  );
}

// Filter suppliers by distance
final nearbySuppliers = allSuppliers.where((supplier) {
  if (supplier.location?.geopoint == null || userLocation == null) {
    return false;
  }

  final distance = calculateDistance(
    userLocation,
    supplier.location!.geopoint!,
  );

  // Within 50km radius
  return distance <= 50000;
}).toList();

// Sort by distance
nearbySuppliers.sort((a, b) {
  final distA = calculateDistance(userLocation, a.location!.geopoint!);
  final distB = calculateDistance(userLocation, b.location!.geopoint!);
  return distA.compareTo(distB);
});
```

#### Option 2: City/Province Matching (Simpler)

**Filter by Same City**:
```dart
final userCity = currentUser?.location?.city;

final nearbySuppliers = allSuppliers.where((supplier) {
  return supplier.location?.city == userCity;
}).toList();
```

**Filter by Same Province**:
```dart
final userProvince = currentUser?.location?.province;

final nearbySuppliers = allSuppliers.where((supplier) {
  return supplier.location?.province == userProvince;
}).toList();
```

---

## Dependencies Needed

To implement location services, add to `pubspec.yaml`:

```yaml
dependencies:
  geolocator: ^11.0.0  # For getting device location
  geocoding: ^3.0.0    # For address lookup (optional)
  permission_handler: ^11.0.0  # For managing permissions
```

---

## Location Permission Flow

### 1. Request Permission on First Use

Add to client onboarding or settings:

```dart
Future<void> requestLocationPermission(BuildContext context) async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    // Show dialog to open app settings
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permissão de Localização'),
        content: Text(
          'Para encontrar fornecedores perto de si, precisamos da sua localização. '
          'Por favor, ative nas configurações do aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: Text('Abrir Configurações'),
          ),
        ],
      ),
    );
    return;
  }

  if (permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always) {
    // Get and save location
    final position = await Geolocator.getCurrentPosition();
    await _saveUserLocation(position);
  }
}

Future<void> _saveUserLocation(Position position) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return;

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
}
```

### 2. Update Location Periodically

```dart
// Update location when app opens
@override
void initState() {
  super.initState();
  _updateLocationIfNeeded();
}

Future<void> _updateLocationIfNeeded() async {
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always) {
    final position = await Geolocator.getCurrentPosition();
    await _saveUserLocation(position);
  }
}
```

---

## Platform-Specific Configuration

### Android (android/app/src/main/AndroidManifest.xml)

```xml
<manifest>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application>
        ...
    </application>
</manifest>
```

### iOS (ios/Runner/Info.plist)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para encontrar fornecedores perto de si.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para encontrar fornecedores perto de si.</string>
```

---

## Testing Checklist

### ✅ Profile Display:
- [ ] User name displays correctly
- [ ] Phone number displays correctly
- [ ] Location shows "City, Province" format
- [ ] Location shows "Angola" when no location set
- [ ] Profile initials generate correctly

### ✅ Stats Section:
- [ ] Reservas count shows real bookings
- [ ] Favoritos count shows real favorites
- [ ] Avaliações count shows completed bookings
- [ ] All counts update when data changes

### ✅ Messages Badge:
- [ ] Badge shows when there are unread messages
- [ ] Badge hidden when no unread messages
- [ ] Badge count updates in real-time
- [ ] Clicking navigates to chat list

### ✅ Menu Items:
- [ ] All menu items navigate correctly
- [ ] Icons display properly
- [ ] Métodos de Pagamento opens payment screen
- [ ] Notificações opens notifications screen

### ⚠️ Location Services (To Implement):
- [ ] Location permission requested on first use
- [ ] User can grant/deny location access
- [ ] Location updates in Firestore
- [ ] Nearby suppliers filter by location
- [ ] Distance calculation works correctly

---

## Related Files

**Modified**:
- [client_profile_screen.dart](../lib/features/client/presentation/screens/client_profile_screen.dart)

**Data Models**:
- [user_model.dart](../lib/core/models/user_model.dart) - LocationData class
- [supplier_model.dart](../lib/core/models/supplier_model.dart) - Supplier location

**Providers**:
- [auth_provider.dart](../lib/core/providers/auth_provider.dart) - currentUserProvider
- [chat_provider.dart](../lib/core/providers/chat_provider.dart) - totalUnreadProvider
- [booking_provider.dart](../lib/core/providers/booking_provider.dart) - clientBookingsProvider
- [favorites_provider.dart](../lib/core/providers/favorites_provider.dart) - favoritesProvider

---

## Next Steps

### High Priority:
1. ✅ ~~Make location display dynamic~~ - DONE
2. ✅ ~~Make messages badge dynamic~~ - DONE
3. ⏳ Implement location permission request flow
4. ⏳ Add GeoPoint to user location on registration
5. ⏳ Update "Perto de si" to filter by actual proximity

### Medium Priority:
6. Implement "Histórico" screen functionality
7. Add location update button in settings
8. Show distance to suppliers in UI
9. Add map view for nearby suppliers

### Low Priority:
10. Add location accuracy indicator
11. Implement background location updates
12. Add location history tracking

---

**Last Updated**: 2026-01-21
**Status**: ✅ Profile fully dynamic, location services ready to implement
**Client Profile**: 100% dynamic from Firestore
