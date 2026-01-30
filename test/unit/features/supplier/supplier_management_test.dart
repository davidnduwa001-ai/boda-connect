import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Supplier Management Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Supplier Registration & Profile
/// 2. Package Management
/// 3. Portfolio/Gallery Management
/// 4. Working Hours & Availability
/// 5. Category & Service Types
/// 6. Supplier Stats & Analytics
/// 7. Verification & Badges
/// 8. Tier System
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Supplier Registration Tests', () {
    test('should create supplier profile with all required fields', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'userId': 'user-456',
        'businessName': 'Foto Premium Angola',
        'ownerName': 'Maria Silva',
        'email': 'contact@fotopremium.ao',
        'phone': '+244923456789',
        'category': 'fotografia',
        'description': 'Especialistas em fotografia de casamento e eventos',
        'services': ['Fotografia', 'Vídeo', 'Drone', 'Álbuns'],
        'location': {
          'address': 'Rua Principal, Luanda',
          'city': 'Luanda',
          'province': 'Luanda',
          'latitude': -8.8383,
          'longitude': 13.2344,
        },
        'rating': 0.0,
        'reviewCount': 0,
        'isVerified': false,
        'isActive': true,
        'tier': 'basic',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['businessName'], 'Foto Premium Angola');
      expect(doc.data()?['category'], 'fotografia');
      expect(doc.data()?['tier'], 'basic');
    });

    test('should update supplier profile', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'businessName': 'Old Name',
        'description': 'Old description',
      });

      await fakeFirestore.collection('suppliers').doc('supplier-123').update({
        'businessName': 'Foto Premium Angola',
        'description': 'Nova descrição atualizada',
        'updatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect(doc.data()?['businessName'], 'Foto Premium Angola');
    });
  });

  group('Package Management Tests', () {
    test('should create package with pricing and features', () async {
      await fakeFirestore.collection('packages').doc('package-123').set({
        'supplierId': 'supplier-456',
        'name': 'Pacote Diamante',
        'description': 'Cobertura completa do seu casamento',
        'price': 250000,
        'currency': 'AOA',
        'duration': 480, // 8 hours
        'maxEvents': 1,
        'features': [
          'Cobertura de 8 horas',
          'Fotografia e Vídeo 4K',
          'Drone aéreo',
          'Álbum digital com 500+ fotos',
          'Álbum físico premium',
          'Edição profissional',
        ],
        'deliverables': {
          'photos': 500,
          'editedPhotos': 100,
          'videos': 1,
          'albums': 2,
        },
        'deliveryDays': 30,
        'isActive': true,
        'isFeatured': true,
        'position': 1,
        'createdAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('packages').doc('package-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['price'], 250000);
      expect((doc.data()?['features'] as List).length, 6);
    });

    test('should get packages ordered by position', () async {
      await fakeFirestore.collection('packages').add({
        'supplierId': 'supplier-123',
        'name': 'Pacote Premium',
        'price': 200000,
        'position': 2,
        'isActive': true,
      });
      await fakeFirestore.collection('packages').add({
        'supplierId': 'supplier-123',
        'name': 'Pacote Básico',
        'price': 100000,
        'position': 3,
        'isActive': true,
      });
      await fakeFirestore.collection('packages').add({
        'supplierId': 'supplier-123',
        'name': 'Pacote Diamante',
        'price': 300000,
        'position': 1,
        'isActive': true,
      });

      final packages = await fakeFirestore
          .collection('packages')
          .where('supplierId', isEqualTo: 'supplier-123')
          .where('isActive', isEqualTo: true)
          .orderBy('position')
          .get();

      expect(packages.docs.length, 3);
      expect(packages.docs[0].data()['name'], 'Pacote Diamante');
      expect(packages.docs[1].data()['name'], 'Pacote Premium');
      expect(packages.docs[2].data()['name'], 'Pacote Básico');
    });

    test('should add package customization options', () async {
      await fakeFirestore.collection('package_customizations').add({
        'packageId': 'package-123',
        'supplierId': 'supplier-456',
        'name': 'Álbum Extra',
        'description': 'Álbum adicional de 30 páginas',
        'price': 25000,
        'maxQuantity': 5,
        'isRequired': false,
        'isActive': true,
      });
      await fakeFirestore.collection('package_customizations').add({
        'packageId': 'package-123',
        'supplierId': 'supplier-456',
        'name': 'Hora Extra',
        'description': 'Hora adicional de cobertura',
        'price': 15000,
        'maxQuantity': 4,
        'isRequired': false,
        'isActive': true,
      });

      final customizations = await fakeFirestore
          .collection('package_customizations')
          .where('packageId', isEqualTo: 'package-123')
          .get();

      expect(customizations.docs.length, 2);
    });

    test('should deactivate package', () async {
      await fakeFirestore.collection('packages').doc('package-123').set({
        'isActive': true,
      });

      await fakeFirestore.collection('packages').doc('package-123').update({
        'isActive': false,
        'deactivatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('packages').doc('package-123').get();
      expect(doc.data()?['isActive'], false);
    });
  });

  group('Portfolio Management Tests', () {
    test('should add portfolio item', () async {
      await fakeFirestore.collection('portfolios').add({
        'supplierId': 'supplier-123',
        'type': 'image',
        'url': 'https://storage.example.com/portfolio/photo1.jpg',
        'thumbnailUrl': 'https://storage.example.com/portfolio/photo1_thumb.jpg',
        'title': 'Casamento João e Maria',
        'description': 'Cerimônia ao ar livre em Luanda',
        'eventType': 'wedding',
        'category': 'fotografia',
        'tags': ['casamento', 'ao ar livre', 'luanda'],
        'position': 1,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      final portfolio = await fakeFirestore
          .collection('portfolios')
          .where('supplierId', isEqualTo: 'supplier-123')
          .get();

      expect(portfolio.docs.length, 1);
      expect(portfolio.docs.first.data()['type'], 'image');
    });

    test('should add video to portfolio', () async {
      await fakeFirestore.collection('portfolios').add({
        'supplierId': 'supplier-123',
        'type': 'video',
        'url': 'https://www.youtube.com/watch?v=abc123',
        'thumbnailUrl': 'https://img.youtube.com/vi/abc123/hqdefault.jpg',
        'title': 'Vídeo de Casamento',
        'duration': 180, // seconds
        'platform': 'youtube',
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      final videos = await fakeFirestore
          .collection('portfolios')
          .where('supplierId', isEqualTo: 'supplier-123')
          .where('type', isEqualTo: 'video')
          .get();

      expect(videos.docs.length, 1);
      expect(videos.docs.first.data()['platform'], 'youtube');
    });

    test('should reorder portfolio items', () async {
      final items = [
        {'id': 'item-1', 'position': 1},
        {'id': 'item-2', 'position': 2},
        {'id': 'item-3', 'position': 3},
      ];

      for (final item in items) {
        await fakeFirestore.collection('portfolios').doc(item['id'] as String).set({
          'supplierId': 'supplier-123',
          'position': item['position'],
        });
      }

      // Reorder: move item-3 to position 1
      await fakeFirestore.collection('portfolios').doc('item-1').update({'position': 2});
      await fakeFirestore.collection('portfolios').doc('item-2').update({'position': 3});
      await fakeFirestore.collection('portfolios').doc('item-3').update({'position': 1});

      final doc = await fakeFirestore.collection('portfolios').doc('item-3').get();
      expect(doc.data()?['position'], 1);
    });

    test('should delete portfolio item', () async {
      await fakeFirestore.collection('portfolios').doc('item-123').set({
        'supplierId': 'supplier-456',
        'url': 'https://example.com/photo.jpg',
      });

      await fakeFirestore.collection('portfolios').doc('item-123').delete();

      final doc = await fakeFirestore.collection('portfolios').doc('item-123').get();
      expect(doc.exists, isFalse);
    });
  });

  group('Working Hours Tests', () {
    test('should set working hours', () async {
      // First create the supplier document
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'name': 'Test Supplier',
        'category': 'Fotografia',
      });

      // Then update with working hours
      await fakeFirestore.collection('suppliers').doc('supplier-123').update({
        'workingHours': {
          'monday': {'open': '09:00', 'close': '18:00', 'isOpen': true},
          'tuesday': {'open': '09:00', 'close': '18:00', 'isOpen': true},
          'wednesday': {'open': '09:00', 'close': '18:00', 'isOpen': true},
          'thursday': {'open': '09:00', 'close': '18:00', 'isOpen': true},
          'friday': {'open': '09:00', 'close': '18:00', 'isOpen': true},
          'saturday': {'open': '10:00', 'close': '16:00', 'isOpen': true},
          'sunday': {'open': null, 'close': null, 'isOpen': false},
        },
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      final workingHours = doc.data()?['workingHours'] as Map;
      expect(workingHours['monday']['isOpen'], true);
      expect(workingHours['sunday']['isOpen'], false);
    });

    test('should block specific dates', () async {
      await fakeFirestore.collection('supplier_blocked_dates').add({
        'supplierId': 'supplier-123',
        'date': '2024-12-25',
        'reason': 'Natal',
        'isRecurring': true,
      });
      await fakeFirestore.collection('supplier_blocked_dates').add({
        'supplierId': 'supplier-123',
        'date': '2024-06-15',
        'reason': 'Evento pessoal',
        'isRecurring': false,
      });

      final blockedDates = await fakeFirestore
          .collection('supplier_blocked_dates')
          .where('supplierId', isEqualTo: 'supplier-123')
          .get();

      expect(blockedDates.docs.length, 2);
    });

    test('should check availability for date', () async {
      await fakeFirestore.collection('supplier_availability').doc('supplier-123_2024-06-15').set({
        'supplierId': 'supplier-123',
        'date': '2024-06-15',
        'isAvailable': true,
        'maxBookings': 1,
        'currentBookings': 0,
      });

      final availability = await fakeFirestore
          .collection('supplier_availability')
          .doc('supplier-123_2024-06-15')
          .get();

      expect(availability.data()?['isAvailable'], true);
      expect(availability.data()?['currentBookings'], lessThan(availability.data()?['maxBookings']));
    });
  });

  group('Category & Service Type Tests', () {
    test('should get suppliers by category', () async {
      await fakeFirestore.collection('suppliers').add({
        'category': 'fotografia',
        'isActive': true,
      });
      await fakeFirestore.collection('suppliers').add({
        'category': 'fotografia',
        'isActive': true,
      });
      await fakeFirestore.collection('suppliers').add({
        'category': 'decoracao',
        'isActive': true,
      });

      final photographers = await fakeFirestore
          .collection('suppliers')
          .where('category', isEqualTo: 'fotografia')
          .where('isActive', isEqualTo: true)
          .get();

      expect(photographers.docs.length, 2);
    });

    test('should filter by multiple services', () async {
      await fakeFirestore.collection('suppliers').add({
        'category': 'fotografia',
        'services': ['Fotografia', 'Vídeo', 'Drone'],
        'isActive': true,
      });
      await fakeFirestore.collection('suppliers').add({
        'category': 'fotografia',
        'services': ['Fotografia'],
        'isActive': true,
      });

      final withDrone = await fakeFirestore
          .collection('suppliers')
          .where('services', arrayContains: 'Drone')
          .get();

      expect(withDrone.docs.length, 1);
    });
  });

  group('Supplier Stats Tests', () {
    test('should track supplier statistics', () async {
      await fakeFirestore.collection('supplier_stats').doc('supplier-123').set({
        'totalBookings': 50,
        'completedBookings': 45,
        'cancelledBookings': 3,
        'pendingBookings': 2,
        'totalRevenue': 5000000, // AOA
        'averageOrderValue': 100000,
        'responseRate': 0.95,
        'averageResponseTime': 30, // minutes
        'profileViews': 500,
        'favoriteCount': 25,
        'updatedAt': Timestamp.now(),
      });

      final stats = await fakeFirestore.collection('supplier_stats').doc('supplier-123').get();
      expect(stats.data()?['responseRate'], 0.95);
      expect(stats.data()?['completedBookings'], 45);
    });

    test('should update stats on new booking', () async {
      await fakeFirestore.collection('supplier_stats').doc('supplier-123').set({
        'totalBookings': 50,
        'pendingBookings': 2,
      });

      await fakeFirestore.collection('supplier_stats').doc('supplier-123').update({
        'totalBookings': FieldValue.increment(1),
        'pendingBookings': FieldValue.increment(1),
      });

      final stats = await fakeFirestore.collection('supplier_stats').doc('supplier-123').get();
      expect(stats.data()?['totalBookings'], 51);
      expect(stats.data()?['pendingBookings'], 3);
    });

    test('should track monthly revenue', () async {
      await fakeFirestore.collection('supplier_monthly_stats').add({
        'supplierId': 'supplier-123',
        'month': '2024-01',
        'revenue': 500000,
        'bookings': 5,
        'averageRating': 4.8,
      });
      await fakeFirestore.collection('supplier_monthly_stats').add({
        'supplierId': 'supplier-123',
        'month': '2024-02',
        'revenue': 750000,
        'bookings': 7,
        'averageRating': 4.9,
      });

      final monthlyStats = await fakeFirestore
          .collection('supplier_monthly_stats')
          .where('supplierId', isEqualTo: 'supplier-123')
          .orderBy('month')
          .get();

      expect(monthlyStats.docs.length, 2);
    });
  });

  group('Verification & Badges Tests', () {
    test('should submit verification request', () async {
      await fakeFirestore.collection('verification_requests').add({
        'supplierId': 'supplier-123',
        'type': 'business',
        'documents': [
          {'type': 'nif', 'url': 'https://storage.example.com/nif.pdf'},
          {'type': 'alvara', 'url': 'https://storage.example.com/alvara.pdf'},
        ],
        'status': 'pending',
        'submittedAt': Timestamp.now(),
      });

      final requests = await fakeFirestore
          .collection('verification_requests')
          .where('supplierId', isEqualTo: 'supplier-123')
          .where('status', isEqualTo: 'pending')
          .get();

      expect(requests.docs.length, 1);
    });

    test('should approve verification and add badge', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'isVerified': false,
        'badges': [],
      });

      await fakeFirestore.collection('suppliers').doc('supplier-123').update({
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'badges': FieldValue.arrayUnion(['verified_business']),
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect(doc.data()?['isVerified'], true);
      expect((doc.data()?['badges'] as List).contains('verified_business'), true);
    });

    test('should earn expert badge based on performance', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'rating': 4.9,
        'reviewCount': 50,
        'badges': ['verified_business'],
      });

      // Check eligibility: rating >= 4.8 AND reviewCount >= 30
      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      final rating = doc.data()?['rating'] as double;
      final reviewCount = doc.data()?['reviewCount'] as int;

      if (rating >= 4.8 && reviewCount >= 30) {
        await fakeFirestore.collection('suppliers').doc('supplier-123').update({
          'badges': FieldValue.arrayUnion(['expert']),
        });
      }

      final updated = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect((updated.data()?['badges'] as List).contains('expert'), true);
    });

    test('should earn fast responder badge', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'badges': [],
      });

      await fakeFirestore.collection('supplier_stats').doc('supplier-123').set({
        'responseRate': 0.98,
        'averageResponseTime': 15, // minutes
      });

      // Check eligibility: responseRate >= 0.95 AND averageResponseTime <= 30
      final stats = await fakeFirestore.collection('supplier_stats').doc('supplier-123').get();
      final responseRate = stats.data()?['responseRate'] as double;
      final responseTime = stats.data()?['averageResponseTime'] as int;

      if (responseRate >= 0.95 && responseTime <= 30) {
        await fakeFirestore.collection('suppliers').doc('supplier-123').update({
          'badges': FieldValue.arrayUnion(['fast_responder']),
        });
      }

      final updated = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect((updated.data()?['badges'] as List).contains('fast_responder'), true);
    });
  });

  group('Tier System Tests', () {
    test('should calculate tier based on revenue', () {
      // Tier thresholds (monthly revenue in AOA):
      // Basic: 0 - 500,000
      // Bronze: 500,001 - 1,500,000
      // Silver: 1,500,001 - 5,000,000
      // Gold: 5,000,001 - 15,000,000
      // Platinum: > 15,000,000

      expect(_calculateTier(0), 'basic');
      expect(_calculateTier(250000), 'basic');
      expect(_calculateTier(500000), 'basic');
      expect(_calculateTier(500001), 'bronze');
      expect(_calculateTier(1000000), 'bronze');
      expect(_calculateTier(1500001), 'silver');
      expect(_calculateTier(3000000), 'silver');
      expect(_calculateTier(5000001), 'gold');
      expect(_calculateTier(10000000), 'gold');
      expect(_calculateTier(15000001), 'platinum');
      expect(_calculateTier(50000000), 'platinum');
    });

    test('should update supplier tier', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'tier': 'basic',
      });

      await fakeFirestore.collection('suppliers').doc('supplier-123').update({
        'tier': 'silver',
        'tierUpdatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect(doc.data()?['tier'], 'silver');
    });

    test('should get tier benefits', () {
      final benefits = _getTierBenefits('gold');

      expect(benefits['commissionRate'], 8.0);
      expect(benefits['featuredListings'], 3);
      expect(benefits['prioritySupport'], true);
    });
  });

  group('Supplier Search & Ranking Tests', () {
    test('should search suppliers by name', () async {
      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Foto Premium Angola',
        'isActive': true,
      });
      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Decorações Luxo',
        'isActive': true,
      });

      // In real app, this would use Algolia
      final suppliers = await fakeFirestore.collection('suppliers').get();
      final matching = suppliers.docs.where((doc) {
        final name = doc.data()['businessName'] as String;
        return name.toLowerCase().contains('foto');
      }).toList();

      expect(matching.length, 1);
    });

    test('should rank suppliers by score', () async {
      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Supplier A',
        'rating': 4.9,
        'reviewCount': 100,
        'tier': 'gold',
        'isActive': true,
      });
      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Supplier B',
        'rating': 4.5,
        'reviewCount': 50,
        'tier': 'silver',
        'isActive': true,
      });
      await fakeFirestore.collection('suppliers').add({
        'businessName': 'Supplier C',
        'rating': 4.8,
        'reviewCount': 75,
        'tier': 'gold',
        'isActive': true,
      });

      final suppliers = await fakeFirestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .get();

      expect(suppliers.docs[0].data()['rating'], 4.9);
    });
  });

  group('Supplier Favorites Tests', () {
    test('should add supplier to favorites', () async {
      await fakeFirestore.collection('favorites').add({
        'userId': 'client-123',
        'supplierId': 'supplier-456',
        'createdAt': Timestamp.now(),
      });

      final favorites = await fakeFirestore
          .collection('favorites')
          .where('userId', isEqualTo: 'client-123')
          .get();

      expect(favorites.docs.length, 1);
    });

    test('should remove supplier from favorites', () async {
      final docRef = await fakeFirestore.collection('favorites').add({
        'userId': 'client-123',
        'supplierId': 'supplier-456',
      });

      await docRef.delete();

      final favorites = await fakeFirestore
          .collection('favorites')
          .where('userId', isEqualTo: 'client-123')
          .where('supplierId', isEqualTo: 'supplier-456')
          .get();

      expect(favorites.docs.isEmpty, true);
    });

    test('should update supplier favorite count', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'favoriteCount': 10,
      });

      await fakeFirestore.collection('suppliers').doc('supplier-123').update({
        'favoriteCount': FieldValue.increment(1),
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      expect(doc.data()?['favoriteCount'], 11);
    });
  });
}

// Helper function to calculate tier
String _calculateTier(int monthlyRevenue) {
  if (monthlyRevenue > 15000000) return 'platinum';
  if (monthlyRevenue > 5000000) return 'gold';
  if (monthlyRevenue > 1500000) return 'silver';
  if (monthlyRevenue > 500000) return 'bronze';
  return 'basic';
}

// Helper function to get tier benefits
Map<String, dynamic> _getTierBenefits(String tier) {
  switch (tier) {
    case 'platinum':
      return {
        'commissionRate': 5.0,
        'featuredListings': 10,
        'prioritySupport': true,
        'analyticsAccess': 'advanced',
      };
    case 'gold':
      return {
        'commissionRate': 8.0,
        'featuredListings': 3,
        'prioritySupport': true,
        'analyticsAccess': 'advanced',
      };
    case 'silver':
      return {
        'commissionRate': 10.0,
        'featuredListings': 1,
        'prioritySupport': false,
        'analyticsAccess': 'basic',
      };
    case 'bronze':
      return {
        'commissionRate': 12.0,
        'featuredListings': 0,
        'prioritySupport': false,
        'analyticsAccess': 'basic',
      };
    default:
      return {
        'commissionRate': 15.0,
        'featuredListings': 0,
        'prioritySupport': false,
        'analyticsAccess': 'none',
      };
  }
}
