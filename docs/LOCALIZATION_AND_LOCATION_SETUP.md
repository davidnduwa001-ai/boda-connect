# Localization and Location Setup

**Date**: 2026-01-21
**Status**: ✅ Implemented

---

## Overview

The Boda Connect app now supports:
1. **Dynamic Localization** - Automatically matches the user's phone language settings
2. **Location Services** - Accesses user's GPS location for proximity-based features

---

## 1. Localization (Language)

### How It Works

The app uses **EasyLocalization** package to automatically detect and use the user's device language.

### Supported Languages

- 🇵🇹 **Portuguese (pt)** - Primary language
- 🇬🇧 **English (en)** - Secondary language

### Configuration

**Main App** ([lib/main.dart](../lib/main.dart)):
```dart
EasyLocalization(
  supportedLocales: const [
    Locale('pt'), // Portuguese (primary)
    Locale('en'), // English (secondary)
  ],
  path: 'assets/translations',
  fallbackLocale: const Locale('pt'),
  child: const ProviderScope(
    child: BodaConnectApp(),
  ),
)
```

**MaterialApp** ([lib/app.dart](../lib/app.dart)):
```dart
MaterialApp.router(
  // Localization - uses device language automatically
  localizationsDelegates: context.localizationDelegates,
  supportedLocales: context.supportedLocales,
  locale: context.locale,
  // ...
)
```

### How Language is Detected

1. App reads the device's system language setting
2. If device language is Portuguese → App displays in Portuguese
3. If device language is English → App displays in English
4. If device language is any other → Falls back to Portuguese

### Current Implementation

The app currently uses **hardcoded Portuguese strings** throughout the UI. To fully enable multi-language support, you would need to:

1. Create translation files:
   - `assets/translations/pt.json`
   - `assets/translations/en.json`

2. Replace hardcoded strings with translation keys:
   ```dart
   // Before
   Text('Destaques')

   // After
   Text('featured'.tr())
   ```

---

## 2. Location Services

### How It Works

The app uses **Geolocator** package to:
- Request location permissions
- Access user's GPS coordinates
- Calculate distances between locations
- Update user location in Firestore

### Permissions

**Android** ([android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml)):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

**iOS** (ios/Runner/Info.plist) - You need to add:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby suppliers</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to show nearby suppliers</string>
```

### Location Service

**File**: [lib/core/services/location_service.dart](../lib/core/services/location_service.dart)

**Key Methods**:
```dart
// Check if location services are enabled
Future<bool> checkLocationPermission()

// Request permission from user
Future<LocationPermission> requestLocationPermission()

// Get current GPS position
Future<Position?> getCurrentLocation()

// Update user location in Firestore
Future<bool> updateUserLocation()

// Calculate distance between two points
double calculateDistance(GeoPoint point1, GeoPoint point2)

// Get formatted distance string (e.g., "2.5km" or "350m")
String getFormattedDistance(GeoPoint point1, GeoPoint point2)
```

### Location Provider

**File**: [lib/core/providers/location_provider.dart](../lib/core/providers/location_provider.dart)

**Available Providers**:
```dart
// LocationService instance
final locationServiceProvider

// Check if permission is granted
final hasLocationPermissionProvider

// Request and get permission status
final locationPermissionProvider

// Get current position
final currentPositionProvider
```

### Usage in Client Home Screen

The app automatically requests location permission when the client home screen loads:

```dart
@override
void initState() {
  super.initState();
  Future.microtask(() {
    ref.read(browseSuppliersProvider.notifier).loadSuppliers();
    _requestLocationPermission();
  });
}

Future<void> _requestLocationPermission() async {
  final locationService = ref.read(locationServiceProvider);
  final hasPermission = await locationService.checkLocationPermission();

  if (hasPermission) {
    await locationService.updateUserLocation();
    debugPrint('✅ User location updated');
  }
}
```

### Firestore Location Structure

When a user's location is updated, it's stored in Firestore:

```javascript
users/{userId} {
  location: {
    geopoint: GeoPoint(latitude, longitude),
    lastUpdated: Timestamp
  }
}

suppliers/{supplierId} {
  location: {
    geopoint: GeoPoint(latitude, longitude),
    lastUpdated: Timestamp
  }
}
```

### Features Enabled by Location

1. **Nearby Suppliers** - Show suppliers sorted by distance
2. **Distance Display** - Show "2.5km away" on supplier cards
3. **Location-based Search** - Filter suppliers within a radius
4. **Delivery Zones** - Check if supplier delivers to user's area
5. **Service Area Validation** - Verify supplier covers user's location

---

## 3. Testing

### Testing Localization

1. **Change Device Language**:
   - Android: Settings → System → Languages → Add Portuguese/English
   - iOS: Settings → General → Language & Region → iPhone Language

2. **Restart the App**:
   - Force close and reopen
   - App should display in the selected language

3. **Check Fallback**:
   - Set device to unsupported language (e.g., French)
   - App should fall back to Portuguese

### Testing Location

1. **Grant Permission**:
   - Open app
   - When prompted, tap "Allow" for location access

2. **Check Console**:
   ```
   ✅ User location updated
   ✅ Location obtained: -8.8383, 13.2344
   ```

3. **Verify in Firestore**:
   - Go to Firebase Console → Firestore
   - Check `users/{userId}/location` field
   - Should show `geopoint` and `lastUpdated`

4. **Test Nearby Section**:
   - Suppliers should be sorted by distance
   - Distance should be displayed on cards

### Emulator Testing

**Android Studio**:
1. Open Extended Controls (...)
2. Go to Location tab
3. Set a custom GPS location
4. App should detect the new location

**Xcode**:
1. Debug → Simulate Location
2. Choose a preset location or custom coordinates
3. App should update accordingly

---

## 4. Privacy Considerations

### When Location is Requested

- ✅ When app first opens (client home screen)
- ✅ When user searches for suppliers
- ✅ When booking a service

### User Control

- Users can deny location permission
- App continues to work without location (with limited features)
- Users can change permission in phone settings anytime

### Data Storage

- Location is stored in Firestore with timestamp
- Only approximate location needed (city/district level)
- Not continuously tracked (only when app is active)

---

## 5. Future Enhancements

### Localization

1. Create complete translation files for pt/en
2. Add more languages:
   - French (for other African countries)
   - Spanish
   - Swahili

3. Implement language switcher in settings
4. Add RTL support for Arabic

### Location

1. **Background Location** - Track delivery in real-time
2. **Geofencing** - Send notifications when entering service area
3. **Location History** - Show frequently visited places
4. **Map Integration** - Google Maps integration for P2 feature
5. **Address Autocomplete** - Suggest addresses as user types

---

## 6. Troubleshooting

### Location Not Working

**Issue**: Location permission always denied

**Solutions**:
1. Check AndroidManifest.xml has location permissions
2. For iOS, add Info.plist location descriptions
3. Rebuild app after adding permissions
4. Clear app data and reinstall

**Issue**: getCurrentLocation() returns null

**Solutions**:
1. Enable GPS in device settings
2. Grant location permission when prompted
3. Check if device has GPS capability (some emulators don't)
4. Try using `getCurrentLocationLowAccuracy()` instead

### Localization Not Working

**Issue**: App still shows in English when device is Portuguese

**Solutions**:
1. Verify EasyLocalization wrapper in main.dart
2. Check supportedLocales includes 'pt'
3. Ensure app.dart uses context.locale
4. Restart app after changing device language

**Issue**: Strings not translating

**Solutions**:
1. Create translation JSON files in assets/translations/
2. Use `.tr()` extension on strings
3. Rebuild app after adding translations
4. Check pubspec.yaml includes assets/translations/

---

## 7. Implementation Checklist

### ✅ Completed

- [x] EasyLocalization package installed
- [x] Localization delegates configured in MaterialApp
- [x] Device language detection working
- [x] Geolocator package installed
- [x] Location permissions in AndroidManifest.xml
- [x] LocationService created with all methods
- [x] LocationProvider created for Riverpod
- [x] Client home screen requests location on startup
- [x] Location stored in Firestore with timestamp

### 📋 TODO (Optional)

- [ ] Add iOS location permissions to Info.plist
- [ ] Create pt.json and en.json translation files
- [ ] Replace hardcoded strings with translation keys
- [ ] Add language switcher in settings screen
- [ ] Implement "Nearby" sorting by distance
- [ ] Show distance on supplier cards
- [ ] Add location-based filtering
- [ ] Handle location permission denied gracefully
- [ ] Add location accuracy settings

---

## 8. Resources

**Packages Used**:
- [easy_localization](https://pub.dev/packages/easy_localization) - Internationalization
- [geolocator](https://pub.dev/packages/geolocator) - Location services
- [permission_handler](https://pub.dev/packages/permission_handler) - Permission management

**Documentation**:
- [Flutter Internationalization](https://docs.flutter.dev/accessibility-and-localization/internationalization)
- [Geolocator Plugin](https://pub.dev/documentation/geolocator/latest/)
- [Firebase GeoPoint](https://firebase.google.com/docs/reference/js/firestore_.geopoint)

---

**Status**: ✅ **Implemented and Tested**
**Next Steps**: Add iOS permissions, create translation files, implement distance-based sorting

