import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to populate Firestore with test data
/// This is for development/testing purposes only
class SeedDatabaseService {
  final FirebaseFirestore _firestore;

  SeedDatabaseService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Seed the entire database with test data
  Future<void> seedDatabase({
    required String existingClientId,
    required String existingSupplierId,
  }) async {
    debugPrint('🌱 Starting database seeding...');

    try {
      // 1. Create categories
      await _createCategories();

      // 2. Get existing supplier document ID (create if doesn't exist)
      String? existingSupplierDocId = await _getSupplierDocId(existingSupplierId);

      if (existingSupplierDocId == null) {
        debugPrint('⚠️  Supplier profile not found, creating one...');
        existingSupplierDocId = await _createMainSupplierProfile(existingSupplierId);
      }

      // 3. Create additional suppliers
      final newSupplierIds = await _createSuppliers();
      final allSupplierIds = [existingSupplierDocId, ...newSupplierIds];

      // 4. Create packages
      await _createPackages(allSupplierIds);

      // 5. Create reviews
      await _createReviews(allSupplierIds, existingClientId);

      // 6. Create bookings
      await _createBookings(allSupplierIds, existingClientId);

      // 7. Create conversation
      await _createConversation(
        existingClientId,
        existingSupplierId,
        existingSupplierDocId,
      );

      debugPrint('✅ Database seeding completed!');
    } catch (e) {
      debugPrint('❌ Seeding error: $e');
      rethrow;
    }
  }

  // ==================== CATEGORIES ====================

  Future<void> _createCategories() async {
    debugPrint('📂 Creating categories...');

    // Check if categories already exist
    final existingCategories = await _firestore.collection('categories').get();
    if (existingCategories.docs.isNotEmpty) {
      debugPrint('   ⚠️  Categories already exist, skipping creation');
      return;
    }

    final categories = [
      {
        'name': 'Fotografia',
        'namePt': 'Fotografia',
        'icon': 'camera',
        'description': 'Fotógrafos profissionais',
        'order': 1
      },
      {
        'name': 'Decoração',
        'namePt': 'Decoração',
        'icon': 'celebration',
        'description': 'Decoração elegante',
        'order': 2
      },
      {
        'name': 'Catering',
        'namePt': 'Catering',
        'icon': 'restaurant',
        'description': 'Serviços de alimentação',
        'order': 3
      },
      {
        'name': 'Música',
        'namePt': 'Música',
        'icon': 'music_note',
        'description': 'DJs e bandas',
        'order': 4
      },
      {
        'name': 'Espaços',
        'namePt': 'Espaços',
        'icon': 'location_city',
        'description': 'Salões para eventos',
        'order': 5
      },
      {
        'name': 'Transporte',
        'namePt': 'Transporte',
        'icon': 'directions_car',
        'description': 'Carros de luxo',
        'order': 6
      },
    ];

    for (var cat in categories) {
      await _firestore.collection('categories').add({
        ...cat,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    debugPrint('   ✓ Created ${categories.length} categories');
  }

  // ==================== SUPPLIERS ====================

  Future<String?> _getSupplierDocId(String userId) async {
    final snapshot = await _firestore
        .collection('suppliers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  Future<String> _createMainSupplierProfile(String userId) async {
    debugPrint('👔 Creating main supplier profile for user: $userId');

    final now = Timestamp.now();
    final supplierData = {
      'userId': userId,
      'businessName': 'Fotografia Premium',
      'category': 'Fotografia',
      'subcategories': [],
      'description':
          'Serviços profissionais de fotografia para capturar os melhores momentos do seu evento',
      'phone': '+244923456789',
      'email': 'contact@fotografiapremium.ao',
      'website': null,
      'socialLinks': null,
      'location': {
        'address': '',
        'city': 'Luanda',
        'province': 'Luanda',
        'country': 'Angola',
        'geopoint': null,
      },
      'photos': [],
      'portfolioPhotos': [],
      'videos': [],
      'rating': 5.0,
      'reviewCount': 0,
      'completedBookings': 0,
      'responseRate': 1.0,
      'responseTime': 'Menos de 1 hora',
      'isVerified': true,
      'isActive': true,
      'isFeatured': false,
      'languages': ['pt'],
      'workingHours': null,
      'createdAt': now,
      'updatedAt': now,
    };

    final docRef = await _firestore.collection('suppliers').add(supplierData);
    debugPrint('   ✓ Created main supplier profile: ${docRef.id} for user: $userId');
    return docRef.id;
  }

  Future<List<String>> _createSuppliers() async {
    debugPrint('👔 Creating suppliers...');

    final suppliers = [
      {
        'userId': 'supplier_deco_001',
        'businessName': 'Elegância Decorações',
        'category': 'Decoração',
        'description':
            'Decoração sofisticada e personalizada para seu casamento',
        'phone': '+244923456791',
        'email': 'contato@elegancia.ao',
        'location': 'Luanda, Angola',
        'rating': 4.8,
        'totalReviews': 0,
        'accountAgeDays': 380,
        'serviceCount': 15,
        'responseRate': 0.96,
        'completionRate': 0.98,
        'isVerified': true,
        'isFeatured': true,
      },
      {
        'userId': 'supplier_catering_001',
        'businessName': 'Sabor & Festa Catering',
        'category': 'Catering',
        'description': 'Catering de alta qualidade com menu personalizado',
        'phone': '+244923456792',
        'email': 'reservas@saborfesta.ao',
        'location': 'Luanda, Angola',
        'rating': 4.6,
        'totalReviews': 0,
        'accountAgeDays': 290,
        'serviceCount': 11,
        'responseRate': 0.93,
        'completionRate': 0.95,
        'isVerified': true,
        'isFeatured': false,
      },
      {
        'userId': 'supplier_music_001',
        'businessName': 'DJ Ritmo Eventos',
        'category': 'Música',
        'description': 'DJ profissional com equipamento de som de alta qualidade',
        'phone': '+244923456793',
        'email': 'dj@ritmo.ao',
        'location': 'Luanda, Angola',
        'rating': 4.5,
        'totalReviews': 0,
        'accountAgeDays': 180,
        'serviceCount': 8,
        'responseRate': 0.91,
        'completionRate': 0.94,
        'isVerified': false,
        'isFeatured': false,
      },
      {
        'userId': 'supplier_venue_001',
        'businessName': 'Salão Jardim Real',
        'category': 'Espaços',
        'description': 'Espaço amplo e elegante com jardim e área coberta',
        'phone': '+244923456794',
        'email': 'reservas@jardimreal.ao',
        'location': 'Talatona, Luanda',
        'rating': 4.9,
        'totalReviews': 0,
        'accountAgeDays': 550,
        'serviceCount': 20,
        'responseRate': 0.99,
        'completionRate': 0.99,
        'isVerified': true,
        'isFeatured': true,
      },
    ];

    final supplierIds = <String>[];

    for (var supplier in suppliers) {
      final accountAgeDays = supplier['accountAgeDays'] as int;
      final createdDate = DateTime.now().subtract(Duration(days: accountAgeDays));

      // Remove rating field to comply with security rules (must be 5.0 on creation)
      final supplierData = Map<String, dynamic>.from(supplier);
      supplierData.remove('rating');

      final docRef = await _firestore.collection('suppliers').add({
        ...supplierData,
        'rating': 5.0, // Set to 5.0 as required by security rules
        'reviewCount': 0,
        'completedBookings': 0,
        'createdAt': Timestamp.fromDate(createdDate),
        'updatedAt': FieldValue.serverTimestamp(),
        'photos': [],
        'portfolioPhotos': [],
      });
      supplierIds.add(docRef.id);
    }

    debugPrint('   ✓ Created ${suppliers.length} suppliers');
    return supplierIds;
  }

  // ==================== PACKAGES ====================

  Future<void> _createPackages(List<String> supplierIds) async {
    debugPrint('📦 Creating packages...');

    int totalPackages = 0;

    for (var supplierId in supplierIds) {
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      final supplier = supplierDoc.data()!;
      final category = supplier['category'] as String;

      final packages = _getPackagesForCategory(category);

      for (var pkg in packages) {
        await _firestore.collection('packages').add({
          'supplierId': supplierId,
          'supplierName': supplier['businessName'],
          'category': category,
          'name': pkg['name'],
          'description': pkg['description'],
          'price': pkg['price'],
          'duration': pkg['duration'],
          'features': (pkg['description'] as String).split(' • '),
          'isPopular': pkg['isPopular'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        totalPackages++;
      }
    }

    debugPrint('   ✓ Created $totalPackages packages');
  }

  List<Map<String, dynamic>> _getPackagesForCategory(String category) {
    switch (category) {
      case 'Fotografia':
        return [
          {
            'name': 'Básico',
            'price': 85000,
            'duration': 4,
            'description': '4 horas • 200 fotos • Álbum digital',
            'isPopular': false
          },
          {
            'name': 'Premium',
            'price': 150000,
            'duration': 8,
            'description': '8 horas • 400 fotos • Álbum físico • Vídeo',
            'isPopular': true
          },
          {
            'name': 'Completo',
            'price': 280000,
            'duration': 12,
            'description': 'Dia completo • Fotos ilimitadas • Vídeo • Drone',
            'isPopular': false
          },
        ];

      case 'Decoração':
        return [
          {
            'name': 'Simples',
            'price': 120000,
            'duration': 6,
            'description': '50 convidados • Arranjos florais • Centros de mesa',
            'isPopular': false
          },
          {
            'name': 'Premium',
            'price': 280000,
            'duration': 8,
            'description': '150 convidados • Flores premium • Iluminação',
            'isPopular': true
          },
          {
            'name': 'Luxo',
            'price': 450000,
            'duration': 10,
            'description': '300 convidados • Flores importadas • LED',
            'isPopular': false
          },
        ];

      case 'Catering':
        return [
          {
            'name': 'Básico',
            'price': 175000,
            'duration': 6,
            'description': '50 convidados • 3 pratos • Sobremesa',
            'isPopular': false
          },
          {
            'name': 'Premium',
            'price': 420000,
            'duration': 8,
            'description': '150 convidados • 5 pratos • Bar aberto',
            'isPopular': true
          },
        ];

      case 'Música':
        return [
          {
            'name': 'DJ 4h',
            'price': 65000,
            'duration': 4,
            'description': 'DJ • Som • Iluminação básica',
            'isPopular': false
          },
          {
            'name': 'DJ Completo',
            'price': 135000,
            'duration': 8,
            'description': 'DJ + MC • Som premium • LED • Fumaça',
            'isPopular': true
          },
        ];

      case 'Espaços':
        return [
          {
            'name': 'Básico',
            'price': 150000,
            'duration': 6,
            'description': '100 convidados • Mobília • 6 horas',
            'isPopular': false
          },
          {
            'name': 'Premium',
            'price': 280000,
            'duration': 10,
            'description': '200 convidados • Salão + Jardim • 10 horas',
            'isPopular': true
          },
          {
            'name': 'Exclusivo',
            'price': 450000,
            'duration': 12,
            'description': '300 convidados • Tudo incluído • 12 horas',
            'isPopular': false
          },
        ];

      default:
        return [
          {
            'name': 'Padrão',
            'price': 100000,
            'duration': 6,
            'description': 'Serviço completo',
            'isPopular': true
          },
        ];
    }
  }

  // ==================== REVIEWS ====================

  Future<void> _createReviews(List<String> supplierIds, String clientId) async {
    debugPrint('⭐ Creating reviews...');

    final reviews = [
      {'rating': 5.0, 'comment': 'Serviço excelente! Superou expectativas.'},
      {'rating': 5.0, 'comment': 'Perfeito! Recomendo 100%.'},
      {'rating': 4.0, 'comment': 'Muito bom! Pequenos detalhes poderiam melhorar.'},
      {'rating': 5.0, 'comment': 'Simplesmente perfeito! Profissionalismo nota 10.'},
      {'rating': 4.5, 'comment': 'Ótimo serviço e preço justo.'},
    ];

    final clientNames = [
      'Ana Silva',
      'Pedro Costa',
      'Maria Santos',
      'João Ferreira',
      'Sofia Lima'
    ];

    int totalReviews = 0;

    for (var supplierId in supplierIds) {
      final numReviews = 3 + (supplierId.hashCode % 3);

      for (var i = 0; i < numReviews; i++) {
        final review = reviews[i % reviews.length];
        final daysAgo = 30 + (i * 15);
        final createdDate = DateTime.now().subtract(Duration(days: daysAgo));

        await _firestore.collection('reviews').add({
          'supplierId': supplierId,
          'clientId': clientId,
          'clientName': clientNames[i % clientNames.length],
          'rating': review['rating'],
          'comment': review['comment'],
          'createdAt': Timestamp.fromDate(createdDate),
        });
        totalReviews++;
      }

      // Update supplier's reviewCount (skip if we don't own this supplier)
      // Only the owner can update supplier documents due to security rules
      try {
        await _firestore.collection('suppliers').doc(supplierId).update({
          'reviewCount': numReviews,
        });
      } catch (e) {
        // Permission denied for suppliers we don't own - that's expected
        debugPrint('   ⚠️  Could not update review count for supplier $supplierId (not owner)');
      }
    }

    debugPrint('   ✓ Created $totalReviews reviews');
  }

  // ==================== BOOKINGS ====================

  Future<void> _createBookings(List<String> supplierIds, String clientId) async {
    debugPrint('📅 Creating bookings...');

    final bookings = [
      {
        'packageName': 'Pacote Premium',
        'eventDate': DateTime.now().add(const Duration(days: 30)),
        'guestCount': 150,
        'totalPrice': 150000,
        'status': 'pending',
        'paymentStatus': 'pending',
        'paymentMethod': 'creditCard',
        'notes': 'Casamento de Maria e João',
        'daysAgo': 2,
      },
      {
        'packageName': 'Decoração Premium',
        'eventDate': DateTime.now().add(const Duration(days: 45)),
        'guestCount': 200,
        'totalPrice': 280000,
        'status': 'confirmed',
        'paymentStatus': 'paid',
        'paymentMethod': 'bankTransfer',
        'notes': 'Preferência: cores branco e dourado',
        'daysAgo': 5,
      },
      {
        'packageName': 'Pacote Completo',
        'eventDate': DateTime.now().add(const Duration(days: 60)),
        'guestCount': 180,
        'totalPrice': 280000,
        'status': 'confirmed',
        'paymentStatus': 'partial',
        'paymentMethod': 'creditCard',
        'notes': 'Casamento de Ana e Pedro',
        'daysAgo': 10,
      },
    ];

    for (var i = 0; i < bookings.length; i++) {
      final booking = bookings[i];
      final supplierId = supplierIds[i % supplierIds.length];

      // Get supplier name
      final supplierDoc = await _firestore.collection('suppliers').doc(supplierId).get();
      final supplierName = supplierDoc.data()?['businessName'] ?? 'Supplier';

      final createdDate =
          DateTime.now().subtract(Duration(days: booking['daysAgo'] as int));

      await _firestore.collection('bookings').add({
        'clientId': clientId,
        'clientName': 'Yaneli',
        'supplierId': supplierId,
        'supplierName': supplierName,
        'packageName': booking['packageName'],
        'eventDate': Timestamp.fromDate(booking['eventDate'] as DateTime),
        'guestCount': booking['guestCount'],
        'totalPrice': booking['totalPrice'],
        'status': booking['status'],
        'paymentStatus': booking['paymentStatus'],
        'paymentMethod': booking['paymentMethod'],
        'notes': booking['notes'],
        'createdAt': Timestamp.fromDate(createdDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    debugPrint('   ✓ Created ${bookings.length} bookings');
  }

  // ==================== CONVERSATION ====================

  Future<void> _createConversation(
    String clientId,
    String supplierUserId,
    String supplierDocId,
  ) async {
    debugPrint('💬 Creating conversation...');

    // Create conversation
    final convRef = await _firestore.collection('conversations').add({
      'participants': [clientId, supplierUserId],
      'clientId': clientId,
      'supplierId': supplierUserId,
      'clientName': 'Yaneli',
      'supplierName': 'David Nduwa',
      'lastMessage': 'Perfeito! Meu casamento será dia 15 de Março.',
      'lastMessageAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 90)),
      ),
      'lastMessageSenderId': clientId,
      'isActive': true,
      'unreadCount': {
        clientId: 0,
        supplierUserId: 1,
      },
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 2)),
      ),
    });

    // Create messages
    final messages = [
      {
        'senderId': clientId,
        'receiverId': supplierUserId,
        'senderName': 'Yaneli',
        'text':
            'Olá! Vi seu trabalho no BODA CONNECT e gostaria de mais informações sobre o pacote Premium.',
        'minutesAgo': 120,
        'isRead': true,
      },
      {
        'senderId': supplierUserId,
        'receiverId': clientId,
        'senderName': 'David Nduwa',
        'text':
            'Olá Yaneli! Obrigado pelo interesse. O pacote Premium inclui 8 horas de cobertura, 400 fotos editadas, álbum físico e vídeo resumo. O valor é 150.000 Kz.',
        'minutesAgo': 110,
        'isRead': true,
      },
      {
        'senderId': clientId,
        'receiverId': supplierUserId,
        'senderName': 'Yaneli',
        'text': 'Perfeito! Meu casamento será dia 15 de Março. Vocês têm disponibilidade?',
        'minutesAgo': 90,
        'isRead': false,
      },
    ];

    for (var msg in messages) {
      await convRef.collection('messages').add({
        'senderId': msg['senderId'],
        'receiverId': msg['receiverId'],
        'senderName': msg['senderName'],
        'text': msg['text'],
        'type': 'text',
        'isRead': msg['isRead'],
        'timestamp': Timestamp.fromDate(
          DateTime.now().subtract(Duration(minutes: msg['minutesAgo'] as int)),
        ),
      });
    }

    debugPrint('   ✓ Created conversation with messages');
  }
}
