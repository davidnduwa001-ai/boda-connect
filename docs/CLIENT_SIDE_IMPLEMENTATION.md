# Client-Side Implementation Guide

## Overview
The client-side implementation is **~80% complete and dynamic**, pulling real data from Firestore. This document explains how each section works and what's needed for suppliers to appear.

---

## Client Home Screen Sections

### 1. **Categorias** (Categories)
**Purpose**: Show all available categories for event planning

**How it works**:
- Loads from `featuredCategoriesProvider`
- Fetches categories from Firestore `categories` collection
- Displays as horizontal scrollable cards with icons
- Tapping navigates to `Routes.clientCategories` (full category list)

**Data Requirements**:
```dart
// Categories should have:
{
  id: 'string',
  name: 'string',       // e.g., 'Fotografia', 'Catering'
  icon: 'string',       // e.g., '📸', '🍽️'
  description: 'string',
  isActive: true,
  order: number
}
```

**Code Location**:
- UI: `lib/features/client/presentation/screens/client_home_screen.dart` (line ~200-280)
- Provider: `lib/core/providers/category_provider.dart`
- Repository: `lib/core/services/storage_service.dart`

---

### 2. **Destaques** (Featured Suppliers)
**Purpose**: Show highlighted suppliers with good ratings

**How it works**:
```dart
// In client_home_screen.dart line 304
final featuredSuppliers = ref.watch(featuredSuppliersProvider);
```

**Firestore Query**:
```javascript
suppliers
  .where('isActive', isEqualTo: true)
  .where('isFeatured', isEqualTo: true)
  .orderBy('rating', descending: true)
  .limit(10)
```

**Data Requirements for Suppliers to Appear**:
```dart
{
  id: 'string',
  businessName: 'string',
  category: 'string',
  rating: number,          // Rating (0-5.0)
  isActive: true,          // ✅ REQUIRED
  isFeatured: true,        // ✅ REQUIRED FOR DESTAQUES
  isVerified: boolean,
  photos: List<String>,    // At least 1 photo recommended
  location: {
    city: 'string',
    province: 'string',
    country: 'Angola'
  }
}
```

**Why Suppliers Might Not Appear**:
1. ❌ `isActive` is false or missing
2. ❌ `isFeatured` is false or missing
3. ❌ Rating is 0 or very low (sorted by rating)
4. ❌ Document doesn't exist in Firestore

**Code Location**:
- UI: `lib/features/client/presentation/screens/client_home_screen.dart` (line 303-340)
- Provider: `lib/core/providers/supplier_provider.dart`
- Query: `lib/core/services/storage_service.dart` line 166-176

---

### 3. **Perto de Si** (Nearby Suppliers)
**Purpose**: Show suppliers near the client's location

**How it works**:
```dart
// In client_home_screen.dart line 469-470
final suppliersState = ref.watch(browseSuppliersProvider);
final suppliers = suppliersState.suppliers.take(5).toList();
```

**Firestore Query**:
```javascript
suppliers
  .where('isActive', isEqualTo: true)
  .orderBy('rating', descending: true)
  .limit(20)
```

**Notes**:
- Currently shows first 5 suppliers from general query
- Does NOT filter by location yet (can be enhanced)
- Orders by rating (highest first)

**Data Requirements**:
```dart
{
  id: 'string',
  businessName: 'string',
  isActive: true,          // ✅ REQUIRED
  rating: number,
  location: {
    city: 'string',        // Could be used for proximity
    province: 'string',
    geopoint: GeoPoint     // For distance calculation (optional)
  }
}
```

**Enhancement Opportunity**:
To make it truly "nearby", you could:
1. Get client's current location
2. Filter by `location.city` matching client's city
3. Or use `location.geopoint` for radius search

**Code Location**:
- UI: `lib/features/client/presentation/screens/client_home_screen.dart` (line 468-540)
- Provider: `lib/core/providers/supplier_provider.dart`
- Query: `lib/core/services/storage_service.dart` line 129-163

---

## How to Make David (Supplier) Appear

### Option 1: Update via Firebase Console
1. Go to Firebase Console → Firestore Database
2. Find `suppliers` collection
3. Find David's supplier document
4. Add/Update fields:
   ```
   isActive: true
   isFeatured: true
   rating: 4.5 (or any value 0-5)
   ```

### Option 2: Update via Flutter Code
Create a script in `lib/scripts/update_supplier.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> updateDavidSupplier() async {
  final db = FirebaseFirestore.instance;

  // Find David's supplier by userId or businessName
  final snapshot = await db.collection('suppliers')
      .where('businessName', isEqualTo: 'David') // Or use userId
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) {
    print('❌ David supplier not found');
    return;
  }

  final docId = snapshot.docs.first.id;

  // Update with required fields
  await db.collection('suppliers').doc(docId).update({
    'isActive': true,
    'isFeatured': true,
    'rating': 4.8,
    'reviewCount': 12,
    'isVerified': true,
  });

  print('✅ David supplier updated successfully');
}
```

### Option 3: Check Existing Data
Run this query in Firebase Console to see David's current data:
```javascript
// In Firestore Console, filter suppliers collection:
userId == "davidUserId"  // Replace with actual user ID

// Check these fields:
- isActive: should be true
- isFeatured: should be true for Destaques
- rating: should be > 0
```

---

## Required Firestore Indexes

For the queries to work properly, you need these indexes:

### 1. Featured Suppliers Index
```
Collection: suppliers
Fields indexed:
  - isActive (Ascending)
  - isFeatured (Ascending)
  - rating (Descending)
```

### 2. General Suppliers Index
```
Collection: suppliers
Fields indexed:
  - isActive (Ascending)
  - rating (Descending)
```

### 3. Category Filter Index
```
Collection: suppliers
Fields indexed:
  - isActive (Ascending)
  - category (Ascending)
  - rating (Descending)
```

**How to Add**: Firebase will auto-prompt when you run queries, or add manually in:
Firebase Console → Firestore → Indexes → "Create Index"

---

## Testing Checklist

### ✅ Verify Suppliers Appear

1. **Check Firestore Data**:
   ```bash
   # Firebase Console → Firestore → suppliers collection
   # Verify at least one document has:
   - isActive: true
   - isFeatured: true
   - rating: > 0
   - businessName: filled
   - photos: array with at least 1 URL
   ```

2. **Check Client Home Loading**:
   ```dart
   // In client_home_screen.dart initState (line 27-29)
   Future.microtask(() {
     ref.read(browseSuppliersProvider.notifier).loadSuppliers();
   });
   ```

3. **Check Provider State**:
   - Add debug print in `loadSuppliers()` method
   - Check if data is actually being fetched
   - Check console for Firestore errors

4. **Check UI Rendering**:
   ```dart
   // In _buildFeaturedSection (line 326-329)
   child: featuredSuppliers.isEmpty
       ? const Center(child: Text('Nenhum fornecedor em destaque'))
       : ListView.builder(...)
   ```

### ✅ Verify Categories Appear

1. **Check Firestore**:
   ```bash
   # Firebase Console → Firestore → categories collection
   # Should have documents like:
   {
     id: 'photography',
     name: 'Fotografia',
     icon: '📸',
     isActive: true
   }
   ```

2. **Check Provider**:
   ```dart
   // categories_provider.dart has fallback default categories
   // So even without Firestore, defaults should show
   ```

---

## Location System (Angola)

### Location Constants Created
File: `lib/core/constants/angola_locations.dart`

**All 18 Provinces**:
- Luanda, Bengo, Benguela, Bié, Cabinda
- Cuando Cubango, Cuanza Norte, Cuanza Sul, Cunene
- Huambo, Huíla, Lunda Norte, Lunda Sul
- Malanje, Moxico, Namibe, Uíge, Zaire

**Major Cities by Province**:
- Luanda: Luanda, Viana, Cacuaco, Cazenga, Talatona, Kilamba, Belas
- Benguela: Benguela, Lobito, Catumbela, Baía Farta
- Huambo: Huambo, Caála, Longonjo, Bailundo
- Huíla: Lubango, Chibia, Matala, Humpata
- (See file for complete list)

**Usage**:
```dart
import 'package:boda_connect/core/constants/angola_locations.dart';

// Get all provinces
final provinces = AngolaLocations.provinceNames;

// Get cities for a province
final luandaCities = AngolaLocations.getCitiesForProvince('Luanda');

// Get province for a city
final province = AngolaLocations.getProvinceForCity('Lobito'); // Returns 'Benguela'

// Check if valid
if ('Luanda'.isAngolaProvince) {
  // ...
}
```

---

## Dynamic vs Static Data

### ✅ DYNAMIC (Loads from Firestore)
- Suppliers (all queries)
- Categories
- Packages
- Bookings
- Favorites
- Reviews
- User profile data
- Profile stats (Reservas, Favoritos, Avaliações)

### ⚠️ STATIC (Hardcoded)
1. **Category Subcategories** (client_categories_screen.dart line 388-404):
   ```dart
   final subcategoriesMap = {
     'Fotografia': ['Fotógrafos', 'Videógrafos', ...],
     'Catering': ['Catering completo', 'Bolos', ...],
   };
   ```
   **Todo**: Move to Firestore subcategories collection

2. **Popular Searches** (client_search_screen.dart line 29-36):
   ```dart
   final List<String> _popularSearches = [
     '💍 Casamento',
     '🎂 Aniversário',
     ...
   ];
   ```
   **Todo**: Could be dynamic from analytics or admin config

3. **Default Categories** (category_model.dart line 64-115):
   ```dart
   List<CategoryModel> getDefaultCategories() {
     return [
       CategoryModel(id: 'photography', name: 'Fotografia', ...),
       // ... 8 categories
     ];
   }
   ```
   **Note**: This is CORRECT - provides fallback when Firestore unavailable

---

## Common Issues & Solutions

### Issue 1: "Nenhum fornecedor encontrado" / "Nenhum fornecedor em destaque"

**Causes**:
1. No suppliers in Firestore
2. Suppliers have `isActive: false`
3. No suppliers have `isFeatured: true` (for Destaques)
4. Missing Firestore index

**Solutions**:
1. Add test suppliers to Firestore
2. Update existing suppliers with `isActive: true`, `isFeatured: true`
3. Create required Firestore indexes
4. Check Firestore console logs for permission/index errors

### Issue 2: Categories Not Showing

**Causes**:
1. Firestore categories collection empty
2. Categories have `isActive: false`

**Solutions**:
1. Default categories should still show (fallback)
2. Add categories to Firestore `categories` collection
3. Ensure `isActive: true` on category documents

### Issue 3: Location Shows Only "Luanda, Angola"

**Cause**: User profile doesn't have location data

**Solution**:
1. Use Angola location constants file
2. Update user profile with proper `location.city` and `location.province`
3. Add location picker using Angola provinces/cities

---

## Next Steps

### High Priority
1. ✅ Ensure David supplier has correct fields in Firestore
2. ✅ Create Firestore indexes for queries
3. ⚠️ Move subcategories to Firestore
4. ⚠️ Add location picker with Angola provinces

### Medium Priority
5. Enhance "Perto de si" with actual proximity filtering
6. Add GeoPoint to supplier locations
7. Implement distance calculation
8. Add location permission handling

### Low Priority
9. Make popular searches dynamic
10. Add supplier analytics
11. Implement advanced search filters
12. Add map view for suppliers

---

## Related Files

### Core
- `lib/core/constants/angola_locations.dart` - Location constants
- `lib/core/models/supplier_model.dart` - Supplier data model
- `lib/core/providers/supplier_provider.dart` - Supplier state management
- `lib/core/repositories/supplier_repository.dart` - Supplier data access
- `lib/core/services/storage_service.dart` - Firestore queries

### Client Screens
- `lib/features/client/presentation/screens/client_home_screen.dart` - Main dashboard
- `lib/features/client/presentation/screens/client_search_screen.dart` - Search & filters
- `lib/features/client/presentation/screens/client_categories_screen.dart` - Category browse
- `lib/features/client/presentation/screens/client_supplier_detail_screen.dart` - Supplier profile
- `lib/features/client/presentation/screens/client_profile_screen.dart` - User profile (UPDATED with dynamic stats)

---

**Last Updated**: 2026-01-21
**Status**: Client-side ~80% complete, mostly dynamic, minor enhancements needed
