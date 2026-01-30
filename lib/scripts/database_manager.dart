import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'seed_categories.dart';

/// Database Manager for clearing and seeding fresh data
class DatabaseManager {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections to clear
  static const List<String> _collections = [
    'users',
    'suppliers',
    'categories',
    'bookings',
    'reviews',
    'chats',
    'messages',
    'notifications',
    'reports',
    'disputes',
    'payments',
    'safetyScores',
    'favorites',
  ];

  /// Clear all data from all collections
  static Future<void> clearAllData() async {
    debugPrint('🗑️ Clearing all database collections...\n');

    for (final collection in _collections) {
      await _clearCollection(collection);
    }

    debugPrint('\n✅ All collections cleared!');
  }

  /// Clear a specific collection
  static Future<void> _clearCollection(String collectionName) async {
    try {
      final snapshot = await _db.collection(collectionName).get();
      final batch = _db.batch();
      int count = 0;

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
      }

      if (count > 0) {
        await batch.commit();
        debugPrint('🗑️ Cleared $count documents from $collectionName');
      } else {
        debugPrint('⏭️ $collectionName is already empty');
      }
    } catch (e) {
      debugPrint('❌ Error clearing $collectionName: $e');
    }
  }

  /// Seed fresh data: categories, suppliers, and a client
  static Future<void> seedFreshData() async {
    debugPrint('\n🌱 Seeding fresh data...\n');

    // 1. Seed categories
    debugPrint('📂 Seeding categories...');
    await SeedCategories.seedToFirestore();

    // 2. Seed suppliers
    debugPrint('\n👔 Seeding suppliers...');
    await _seedSuppliers();

    // 3. Seed client
    debugPrint('\n👤 Seeding client...');
    await _seedClient();

    // 4. Update supplier counts
    debugPrint('\n📊 Updating supplier counts...');
    await SeedCategories.updateAllSupplierCounts();

    debugPrint('\n✅ Fresh data seeding complete!');
  }

  /// Clear everything and seed fresh data
  static Future<void> resetAndSeed() async {
    await clearAllData();
    await seedFreshData();
  }

  /// Seed sample suppliers
  static Future<void> _seedSuppliers() async {
    final suppliers = _getSampleSuppliers();

    for (final supplier in suppliers) {
      try {
        final docRef = _db.collection('suppliers').doc();
        supplier['id'] = docRef.id;
        await docRef.set(supplier);
        debugPrint('✅ Created supplier: ${supplier['businessName']}');
      } catch (e) {
        debugPrint('❌ Error creating supplier: $e');
      }
    }
  }

  /// Seed sample client
  static Future<void> _seedClient() async {
    final client = _getSampleClient();

    try {
      final docRef = _db.collection('users').doc();
      client['id'] = docRef.id;
      await docRef.set(client);
      debugPrint('✅ Created client: ${client['name']}');
    } catch (e) {
      debugPrint('❌ Error creating client: $e');
    }
  }

  /// Get sample suppliers data
  static List<Map<String, dynamic>> _getSampleSuppliers() {
    final now = DateTime.now();

    return [
      // Fotografia
      {
        'businessName': 'Studio Luz & Arte',
        'ownerName': 'Carlos Mendes',
        'email': 'carlos@studioluzearte.ao',
        'phone': '+244923456789',
        'category': 'Fotografia',
        'subcategories': ['Casamentos', 'Eventos Corporativos', 'Retratos'],
        'description': 'Estúdio fotográfico profissional com mais de 10 anos de experiência em Luanda. Especializados em casamentos, eventos corporativos e sessões de retrato.',
        'photos': [
          'https://images.unsplash.com/photo-1606216794074-735e91aa2c92?w=800',
          'https://images.unsplash.com/photo-1537633552985-df8429e8048b?w=800',
          'https://images.unsplash.com/photo-1519741497674-611481863552?w=800',
        ],
        'videos': [],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'address': 'Rua Comandante Gika, Maianga',
          'latitude': -8.8383,
          'longitude': 13.2344,
        },
        'priceRange': {'min': 50000, 'max': 300000, 'currency': 'AOA'},
        'rating': 4.8,
        'reviewCount': 127,
        'completedBookings': 245,
        'isVerified': true,
        'isActive': true,
        'isFeatured': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 365))),
        'updatedAt': Timestamp.fromDate(now),
      },
      {
        'businessName': 'Momentos Eternos',
        'ownerName': 'Ana Silva',
        'email': 'ana@momentoseternos.ao',
        'phone': '+244912345678',
        'category': 'Fotografia',
        'subcategories': ['Casamentos', 'Batizados', 'Aniversários'],
        'description': 'Capturamos os momentos mais especiais da sua vida com um olhar artístico e sensível. Fotografia de casamentos e eventos familiares.',
        'photos': [
          'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=800',
          'https://images.unsplash.com/photo-1465495976277-4387d4b0b4c6?w=800',
        ],
        'videos': [],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'address': 'Talatona, Luanda Sul',
          'latitude': -8.9147,
          'longitude': 13.1897,
        },
        'priceRange': {'min': 40000, 'max': 200000, 'currency': 'AOA'},
        'rating': 4.6,
        'reviewCount': 89,
        'completedBookings': 156,
        'isVerified': true,
        'isActive': true,
        'isFeatured': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 200))),
        'updatedAt': Timestamp.fromDate(now),
      },

      // Decoração
      {
        'businessName': 'Decor Dreams Angola',
        'ownerName': 'Maria João',
        'email': 'maria@decordreams.ao',
        'phone': '+244934567890',
        'category': 'Decoração',
        'subcategories': ['Casamentos', 'Festas', 'Eventos Corporativos'],
        'description': 'Transformamos espaços em sonhos! Decoração elegante e personalizada para casamentos, festas e eventos corporativos.',
        'photos': [
          'https://images.unsplash.com/photo-1478146896981-b80fe463b330?w=800',
          'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=800',
          'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=800',
        ],
        'videos': [],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'address': 'Miramar, Luanda',
          'latitude': -8.8147,
          'longitude': 13.2297,
        },
        'priceRange': {'min': 100000, 'max': 500000, 'currency': 'AOA'},
        'rating': 4.9,
        'reviewCount': 203,
        'completedBookings': 312,
        'isVerified': true,
        'isActive': true,
        'isFeatured': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 500))),
        'updatedAt': Timestamp.fromDate(now),
      },

      // Catering
      {
        'businessName': 'Sabores de Angola',
        'ownerName': 'José António',
        'email': 'jose@saboresdeangola.ao',
        'phone': '+244945678901',
        'category': 'Catering',
        'subcategories': ['Casamentos', 'Eventos Corporativos', 'Festas Privadas'],
        'description': 'Catering de excelência com pratos tradicionais angolanos e culinária internacional. Menus personalizados para todos os tipos de eventos.',
        'photos': [
          'https://images.unsplash.com/photo-1555244162-803834f70033?w=800',
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
        ],
        'videos': [],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'address': 'Ingombota, Luanda',
          'latitude': -8.8247,
          'longitude': 13.2397,
        },
        'priceRange': {'min': 80000, 'max': 400000, 'currency': 'AOA'},
        'rating': 4.7,
        'reviewCount': 156,
        'completedBookings': 278,
        'isVerified': true,
        'isActive': true,
        'isFeatured': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 300))),
        'updatedAt': Timestamp.fromDate(now),
      },

      // Música
      {
        'businessName': 'DJ Kizomba King',
        'ownerName': 'Pedro Neto',
        'email': 'pedro@kizombaking.ao',
        'phone': '+244956789012',
        'category': 'Música',
        'subcategories': ['DJ', 'Kizomba', 'Afrobeats'],
        'description': 'O melhor DJ de Luanda para casamentos e festas! Especializado em Kizomba, Semba, Afrobeats e música internacional.',
        'photos': [
          'https://images.unsplash.com/photo-1571266028243-3716f02d4c12?w=800',
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800',
        ],
        'videos': [],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'address': 'Alvalade, Luanda',
          'latitude': -8.8347,
          'longitude': 13.2497,
        },
        'priceRange': {'min': 60000, 'max': 250000, 'currency': 'AOA'},
        'rating': 4.8,
        'reviewCount': 178,
        'completedBookings': 320,
        'isVerified': true,
        'isActive': true,
        'isFeatured': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 400))),
        'updatedAt': Timestamp.fromDate(now),
      },

      // Espaços
      {
        'businessName': 'Salão Girassol',
        'ownerName': 'Teresa Lopes',
        'email': 'teresa@salaogirassol.ao',
        'phone': '+244967890123',
        'category': 'Espaços',
        'subcategories': ['Casamentos', 'Conferências', 'Festas'],
        'description': 'Salão de eventos elegante com capacidade para até 500 pessoas. Localização privilegiada e estacionamento amplo.',
        'photos': [
          'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800',
          'https://images.unsplash.com/photo-1505236858219-8359eb29e329?w=800',
        ],
        'videos': [],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'address': 'Camama, Luanda',
          'latitude': -8.9047,
          'longitude': 13.1997,
        },
        'priceRange': {'min': 200000, 'max': 800000, 'currency': 'AOA'},
        'rating': 4.5,
        'reviewCount': 98,
        'completedBookings': 145,
        'isVerified': true,
        'isActive': true,
        'isFeatured': false,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 600))),
        'updatedAt': Timestamp.fromDate(now),
      },

      // Transporte
      {
        'businessName': 'Luxo Wheels Angola',
        'ownerName': 'Manuel Costa',
        'email': 'manuel@luxowheels.ao',
        'phone': '+244978901234',
        'category': 'Transporte',
        'subcategories': ['Carros de Luxo', 'Limusines', 'Carros Clássicos'],
        'description': 'Frota de carros de luxo para casamentos e eventos especiais. Mercedes, BMW, Rolls Royce e carros clássicos disponíveis.',
        'photos': [
          'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?w=800',
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=800',
        ],
        'videos': [],
        'location': {
          'city': 'Luanda',
          'province': 'Luanda',
          'address': 'Viana, Luanda',
          'latitude': -8.8947,
          'longitude': 13.3797,
        },
        'priceRange': {'min': 100000, 'max': 500000, 'currency': 'AOA'},
        'rating': 4.9,
        'reviewCount': 67,
        'completedBookings': 98,
        'isVerified': true,
        'isActive': true,
        'isFeatured': true,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 250))),
        'updatedAt': Timestamp.fromDate(now),
      },
    ];
  }

  /// Get sample client data
  static Map<String, dynamic> _getSampleClient() {
    final now = DateTime.now();

    return {
      'name': 'Joana Fernandes',
      'email': 'joana.fernandes@email.com',
      'phone': '+244911223344',
      'role': 'client',
      'profilePhoto': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
      'location': {
        'city': 'Luanda',
        'province': 'Luanda',
        'address': 'Maianga, Luanda',
      },
      'preferences': {
        'language': 'pt',
        'notifications': true,
        'emailNotifications': true,
      },
      'isActive': true,
      'isVerified': true,
      'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
      'updatedAt': Timestamp.fromDate(now),
    };
  }
}
