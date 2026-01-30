// Run this file to seed categories to Firestore
// dart run lib/scripts/run_seed_categories.dart
// OR add a button in the app to trigger SeedCategories.seedToFirestore()

import 'package:boda_connect/scripts/seed_categories.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  print('🚀 Starting category seeding...\n');

  // Check if categories already exist
  final exists = await SeedCategories.categoriesExist();
  if (exists) {
    print('⚠️  Categories already exist in Firestore.');
    print('Do you want to proceed anyway? (This will overwrite existing categories)');
    print('Press Ctrl+C to cancel or wait 5 seconds to continue...\n');
    await Future.delayed(const Duration(seconds: 5));
  }

  // Seed the categories
  await SeedCategories.seedToFirestore();

  print('\n🎉 Category seeding complete!');
  print('📊 Now updating supplier counts...\n');

  // Update supplier counts for all categories
  await SeedCategories.updateAllSupplierCounts();

  print('\n✅ All done! Categories are ready to use.');
}
