# How to Seed Categories

## ✅ Quick Start - Use the App Button

The easiest way to seed categories is now directly from the app:

1. **Run the app** (on emulator or device)
2. **Navigate to Settings**:
   - For Client: Home → Profile → Settings (gear icon)
   - For Supplier: Dashboard → Settings
3. **Scroll down** to "FERRAMENTAS DE DEBUG" section
4. **Click "Seed Categories" button**
5. **Wait** for the success message ✅

That's it! The categories will be created in Firestore.

---

## What Gets Seeded

The button will create **8 categories** in Firestore:

1. 📸 **Fotografia** (Photography) - with 7 subcategories
2. 🎥 **Vídeo** (Video) - with 5 subcategories
3. 🍽️ **Catering** - with 6 subcategories
4. 🎵 **Música e DJs** - with 5 subcategories
5. 🎨 **Decoração** (Decoration) - with 6 subcategories
6. 📸 **Fotografia e Vídeo** (Combined) - with 4 subcategories
7. 🏛️ **Espaços** (Venues) - with 5 subcategories
8. 🎂 **Bolo e Doces** (Cake & Sweets) - with 4 subcategories

Each category includes:
- Name
- Icon emoji
- Color
- Active status
- Subcategories list
- Supplier count (auto-calculated)

---

## Alternative Methods

### Method 2: Direct Code Call

You can also call the seeding function directly from anywhere in your code:

```dart
import 'package:boda_connect/scripts/seed_categories.dart';

// In any async function:
await SeedCategories.seedToFirestore();
await SeedCategories.updateAllSupplierCounts();
```

### Method 3: Auto-Seed on First Launch

Add this to your app initialization (e.g., in main.dart or home screen):

```dart
import 'package:boda_connect/scripts/seed_categories.dart';

// Check if categories exist, if not, seed them
final exists = await SeedCategories.categoriesExist();
if (!exists) {
  await SeedCategories.seedToFirestore();
  await SeedCategories.updateAllSupplierCounts();
}
```

---

## Verification

After seeding, verify the categories were created:

1. **In Firebase Console**:
   - Go to Firestore Database
   - Look for `categories` collection
   - Should see 8 documents

2. **In the App**:
   - Navigate to Categories screen (client side)
   - Should see all 8 categories with icons

---

## Troubleshooting

### Categories Already Exist
If categories already exist, the button will ask if you want to overwrite them.

### Permission Error
Make sure you're authenticated and have write access to Firestore.

### Network Error
Make sure you have internet connection and Firebase is properly configured.

---

## Removing Debug Button (Production)

Before releasing to production, remove the debug section from `settings_screen.dart`:

1. Open `lib/features/common/presentation/screens/settings_screen.dart`
2. Remove or comment out the "FERRAMENTAS DE DEBUG" section
3. Remove the import: `import '../widgets/seed_categories_button.dart';`

Or wrap it in a debug flag:

```dart
// Only show in debug mode
if (kDebugMode) {
  _buildSectionHeader('FERRAMENTAS DE DEBUG'),
  Container(...),
}
```

---

**Last Updated**: 2026-01-21
