import 'package:cloud_firestore/cloud_firestore.dart';

/// Script to populate Firestore with comprehensive test data
/// Run this with: dart run scripts/populate_test_data.dart
void main() async {
  print('🚀 Starting database population...\n');

  // Initialize Firestore (you'll need to configure this with your project)
  final firestore = FirebaseFirestore.instance;

  try {
    await populateDatabase(firestore);
    print('\n✅ Database population completed successfully!');
  } catch (e) {
    print('\n❌ Error populating database: $e');
  }
}

Future<void> populateDatabase(FirebaseFirestore firestore) async {
  // 1. Create Categories
  print('📂 Creating categories...');
  await createCategories(firestore);

  // 2. Create Suppliers (with packages)
  print('👔 Creating suppliers with packages...');
  final supplierIds = await createSuppliers(firestore);

  // 3. Create Reviews for suppliers
  print('⭐ Creating reviews...');
  await createReviews(firestore, supplierIds);

  // 4. Create sample bookings
  print('📅 Creating sample bookings...');
  await createBookings(firestore, supplierIds);

  // 5. Create sample conversations
  print('💬 Creating sample conversations...');
  await createConversations(firestore, supplierIds);
}

// ==================== CATEGORIES ====================

Future<void> createCategories(FirebaseFirestore firestore) async {
  final categories = [
    {
      'name': 'Fotografia',
      'namePt': 'Fotografia',
      'icon': 'camera',
      'description': 'Fotógrafos profissionais para capturar momentos especiais',
      'order': 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Decoração',
      'namePt': 'Decoração',
      'icon': 'celebration',
      'description': 'Decoração elegante para transformar seu evento',
      'order': 2,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Catering',
      'namePt': 'Catering',
      'icon': 'restaurant',
      'description': 'Serviços de alimentação e bebidas',
      'order': 3,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Música',
      'namePt': 'Música',
      'icon': 'music_note',
      'description': 'DJs, bandas e músicos ao vivo',
      'order': 4,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Espaços',
      'namePt': 'Espaços',
      'icon': 'location_city',
      'description': 'Salões e espaços para eventos',
      'order': 5,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Transporte',
      'namePt': 'Transporte',
      'icon': 'directions_car',
      'description': 'Carros de luxo e transporte para eventos',
      'order': 6,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
  ];

  for (var category in categories) {
    await firestore.collection('categories').add(category);
    print('  ✓ Created category: ${category['name']}');
  }
}

// ==================== SUPPLIERS ====================

Future<List<String>> createSuppliers(FirebaseFirestore firestore) async {
  final supplierIds = <String>[];

  final suppliers = [
    // Photography suppliers
    {
      'userId': 'BiAuKwtQwOdVN7SJlgLkezJQhh1', // Existing supplier
      'businessName': 'Fotografia Premium',
      'category': 'Fotografia',
      'description': 'Especialistas em fotografia de casamento com mais de 10 anos de experiência. Capturamos os momentos mais especiais do seu dia.',
      'phone': '+244923456789',
      'email': 'davidnduwa5@gmail.com',
      'location': 'Luanda, Angola',
      'rating': 4.9,
      'totalReviews': 127,
      'accountAgeDays': 425,
      'serviceCount': 18,
      'responseRate': 0.98,
      'completionRate': 0.99,
      'isVerified': true,
      'isFeatured': true,
      'photoUrl': 'https://images.unsplash.com/photo-1554080353-a576cf803bda?w=400',
      'coverPhoto': 'https://images.unsplash.com/photo-1519741497674-611481863552?w=800',
      'portfolioImages': [
        'https://images.unsplash.com/photo-1606800052052-a08af7148866?w=600',
        'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=600',
        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=600',
      ],
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 425))),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'userId': 'supplier_photo_002',
      'businessName': 'Momentos Eternos Fotografia',
      'category': 'Fotografia',
      'description': 'Fotografia artística e cinematográfica. Transformamos seu casamento em uma obra de arte visual.',
      'phone': '+244923456790',
      'email': 'momentos@eternos.ao',
      'location': 'Benguela, Angola',
      'rating': 4.7,
      'totalReviews': 85,
      'accountAgeDays': 320,
      'serviceCount': 12,
      'responseRate': 0.95,
      'completionRate': 0.97,
      'isVerified': true,
      'isFeatured': false,
      'photoUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      'coverPhoto': 'https://images.unsplash.com/photo-1465495976277-4387d4b0b4c6?w=800',
      'portfolioImages': [
        'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?w=600',
        'https://images.unsplash.com/photo-1583939003579-730e3918a45a?w=600',
      ],
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 320))),
      'updatedAt': FieldValue.serverTimestamp(),
    },

    // Decoration suppliers
    {
      'userId': 'supplier_deco_001',
      'businessName': 'Elegância Decorações',
      'category': 'Decoração',
      'description': 'Decoração sofisticada e personalizada para seu casamento dos sonhos. Flores, iluminação e arranjos exclusivos.',
      'phone': '+244923456791',
      'email': 'contato@elegancia.ao',
      'location': 'Luanda, Angola',
      'rating': 4.8,
      'totalReviews': 103,
      'accountAgeDays': 380,
      'serviceCount': 15,
      'responseRate': 0.96,
      'completionRate': 0.98,
      'isVerified': true,
      'isFeatured': true,
      'photoUrl': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400',
      'coverPhoto': 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=800',
      'portfolioImages': [
        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=600',
        'https://images.unsplash.com/photo-1478146896981-b80fe463b330?w=600',
        'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=600',
      ],
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 380))),
      'updatedAt': FieldValue.serverTimestamp(),
    },

    // Catering suppliers
    {
      'userId': 'supplier_catering_001',
      'businessName': 'Sabor & Festa Catering',
      'category': 'Catering',
      'description': 'Catering de alta qualidade com menu personalizado. Buffet completo, bar aberto e serviço impecável.',
      'phone': '+244923456792',
      'email': 'reservas@saborfesta.ao',
      'location': 'Luanda, Angola',
      'rating': 4.6,
      'totalReviews': 94,
      'accountAgeDays': 290,
      'serviceCount': 11,
      'responseRate': 0.93,
      'completionRate': 0.95,
      'isVerified': true,
      'isFeatured': false,
      'photoUrl': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      'coverPhoto': 'https://images.unsplash.com/photo-1555244162-803834f70033?w=800',
      'portfolioImages': [
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600',
        'https://images.unsplash.com/photo-1555244162-803834f70033?w=600',
      ],
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 290))),
      'updatedAt': FieldValue.serverTimestamp(),
    },

    // Music suppliers
    {
      'userId': 'supplier_music_001',
      'businessName': 'DJ Ritmo Eventos',
      'category': 'Música',
      'description': 'DJ profissional com equipamento de som de alta qualidade. Repertório variado para todos os gostos.',
      'phone': '+244923456793',
      'email': 'dj@ritmo.ao',
      'location': 'Luanda, Angola',
      'rating': 4.5,
      'totalReviews': 67,
      'accountAgeDays': 180,
      'serviceCount': 8,
      'responseRate': 0.91,
      'completionRate': 0.94,
      'isVerified': false,
      'isFeatured': false,
      'photoUrl': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400',
      'coverPhoto': 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800',
      'portfolioImages': [
        'https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?w=600',
      ],
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 180))),
      'updatedAt': FieldValue.serverTimestamp(),
    },

    // Venue suppliers
    {
      'userId': 'supplier_venue_001',
      'businessName': 'Salão Jardim Real',
      'category': 'Espaços',
      'description': 'Espaço amplo e elegante com jardim e área coberta. Capacidade para até 300 convidados. Estacionamento privativo.',
      'phone': '+244923456794',
      'email': 'reservas@jardimreal.ao',
      'location': 'Talatona, Luanda',
      'rating': 4.9,
      'totalReviews': 156,
      'accountAgeDays': 550,
      'serviceCount': 20,
      'responseRate': 0.99,
      'completionRate': 0.99,
      'isVerified': true,
      'isFeatured': true,
      'photoUrl': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      'coverPhoto': 'https://images.unsplash.com/photo-1519167758481-83f29da8c2af?w=800',
      'portfolioImages': [
        'https://images.unsplash.com/photo-1519167758481-83f29da8c2af?w=600',
        'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=600',
        'https://images.unsplash.com/photo-1478146896981-b80fe463b330?w=600',
      ],
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 550))),
      'updatedAt': FieldValue.serverTimestamp(),
    },
  ];

  for (var supplier in suppliers) {
    final docRef = await firestore.collection('suppliers').add(supplier);
    supplierIds.add(docRef.id);
    print('  ✓ Created supplier: ${supplier['businessName']}');

    // Create packages for each supplier
    await createPackagesForSupplier(firestore, docRef.id, supplier);
  }

  return supplierIds;
}

// ==================== PACKAGES ====================

Future<void> createPackagesForSupplier(
  FirebaseFirestore firestore,
  String supplierId,
  Map<String, dynamic> supplier,
) async {
  List<Map<String, dynamic>> packages = [];

  switch (supplier['category']) {
    case 'Fotografia':
      packages = [
        {
          'name': 'Pacote Básico',
          'description': '4 horas de cobertura\n200 fotos editadas\nÁlbum digital\nEntrega em 30 dias',
          'price': 85000,
          'duration': 4,
          'features': ['4 horas', '200 fotos', 'Álbum digital', '30 dias entrega'],
          'isPopular': false,
        },
        {
          'name': 'Pacote Premium',
          'description': '8 horas de cobertura\n400 fotos editadas\nÁlbum físico + digital\nVídeo resumo\nEntrega em 20 dias',
          'price': 150000,
          'duration': 8,
          'features': ['8 horas', '400 fotos', 'Álbum físico', 'Vídeo resumo', '20 dias'],
          'isPopular': true,
        },
        {
          'name': 'Pacote Completo',
          'description': 'Cobertura completa\nFotos ilimitadas\n2 álbuns físicos\nVídeo completo\nDrone\nEntrega em 15 dias',
          'price': 280000,
          'duration': 12,
          'features': ['Dia completo', 'Fotos ilimitadas', '2 álbuns', 'Vídeo', 'Drone', '15 dias'],
          'isPopular': false,
        },
      ];
      break;

    case 'Decoração':
      packages = [
        {
          'name': 'Decoração Simples',
          'description': 'Decoração de mesas\nArranjos florais básicos\nCentros de mesa\n50 convidados',
          'price': 120000,
          'duration': 6,
          'features': ['50 convidados', 'Arranjos florais', 'Centros de mesa'],
          'isPopular': false,
        },
        {
          'name': 'Decoração Premium',
          'description': 'Decoração completa\nArranjos florais premium\nIluminação ambiente\nTapete vermelho\n150 convidados',
          'price': 280000,
          'duration': 8,
          'features': ['150 convidados', 'Flores premium', 'Iluminação', 'Tapete'],
          'isPopular': true,
        },
        {
          'name': 'Decoração Luxo',
          'description': 'Decoração de luxo completa\nFlores importadas\nIluminação LED\nEstrutura especial\n300 convidados',
          'price': 450000,
          'duration': 10,
          'features': ['300 convidados', 'Flores importadas', 'LED', 'Estrutura'],
          'isPopular': false,
        },
      ];
      break;

    case 'Catering':
      packages = [
        {
          'name': 'Menu Básico',
          'description': 'Buffet com 3 pratos principais\nSobremesa\nBebidas não alcoólicas\n50 convidados',
          'price': 175000,
          'duration': 6,
          'features': ['50 convidados', '3 pratos', 'Sobremesa', 'Bebidas'],
          'isPopular': false,
        },
        {
          'name': 'Menu Premium',
          'description': 'Buffet completo com 5 pratos\nBar aberto\nSobremesas variadas\nWaiter service\n150 convidados',
          'price': 420000,
          'duration': 8,
          'features': ['150 convidados', '5 pratos', 'Bar aberto', 'Waiter'],
          'isPopular': true,
        },
      ];
      break;

    case 'Música':
      packages = [
        {
          'name': 'DJ 4 Horas',
          'description': 'DJ profissional\nEquipamento de som\nIluminação básica\n4 horas',
          'price': 65000,
          'duration': 4,
          'features': ['4 horas', 'Som', 'Iluminação'],
          'isPopular': false,
        },
        {
          'name': 'DJ Completo',
          'description': 'DJ + MC\nEquipamento premium\nIluminação LED\nFumaça\n8 horas',
          'price': 135000,
          'duration': 8,
          'features': ['8 horas', 'DJ + MC', 'LED', 'Fumaça'],
          'isPopular': true,
        },
      ];
      break;

    case 'Espaços':
      packages = [
        {
          'name': 'Aluguel Básico',
          'description': 'Salão para 100 convidados\nMesas e cadeiras\n6 horas\nEstacionamento',
          'price': 150000,
          'duration': 6,
          'features': ['100 convidados', 'Mobília', '6 horas', 'Parking'],
          'isPopular': false,
        },
        {
          'name': 'Pacote Premium',
          'description': 'Salão + Jardim para 200 convidados\nMobília completa\nDecoração básica\n10 horas\nEstacionamento',
          'price': 280000,
          'duration': 10,
          'features': ['200 convidados', 'Salão + Jardim', '10 horas', 'Decoração'],
          'isPopular': true,
        },
        {
          'name': 'Pacote Exclusivo',
          'description': 'Espaço completo para 300 convidados\nTudo incluído\n12 horas\nEstacionamento VIP\nSegurança',
          'price': 450000,
          'duration': 12,
          'features': ['300 convidados', 'Tudo incluído', '12 horas', 'VIP'],
          'isPopular': false,
        },
      ];
      break;

    default:
      packages = [
        {
          'name': 'Pacote Padrão',
          'description': 'Serviço completo para seu evento',
          'price': 100000,
          'duration': 6,
          'features': ['Serviço completo'],
          'isPopular': true,
        },
      ];
  }

  for (var package in packages) {
    await firestore.collection('packages').add({
      ...package,
      'supplierId': supplierId,
      'supplierName': supplier['businessName'],
      'category': supplier['category'],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  print('    → Created ${packages.length} packages for ${supplier['businessName']}');
}

// ==================== REVIEWS ====================

Future<void> createReviews(FirebaseFirestore firestore, List<String> supplierIds) async {
  final reviewTexts = [
    {'rating': 5.0, 'comment': 'Serviço excelente! Superou todas as expectativas. Muito profissional e atencioso.'},
    {'rating': 5.0, 'comment': 'Perfeito! Recomendo 100%. Fizeram um trabalho incrível no nosso casamento.'},
    {'rating': 4.0, 'comment': 'Muito bom! Apenas alguns pequenos detalhes poderiam melhorar, mas no geral excelente.'},
    {'rating': 5.0, 'comment': 'Simplesmente perfeito! Não tenho palavras para agradecer o trabalho impecável.'},
    {'rating': 4.5, 'comment': 'Ótimo serviço e preço justo. Valeu muito a pena contratar.'},
    {'rating': 5.0, 'comment': 'Maravilhoso! Todos os convidados elogiaram. Profissionalismo nota 10.'},
    {'rating': 4.0, 'comment': 'Bom serviço. Cumpriram tudo que foi combinado. Recomendo.'},
    {'rating': 5.0, 'comment': 'Exceptional service! Every detail was perfect. Highly recommend!'},
  ];

  for (var supplierId in supplierIds) {
    // Create 3-5 reviews per supplier
    final numReviews = 3 + (supplierId.hashCode % 3);

    for (var i = 0; i < numReviews; i++) {
      final review = reviewTexts[i % reviewTexts.length];

      await firestore.collection('reviews').add({
        'supplierId': supplierId,
        'clientId': 'LZWFAQQ9dEgFhBSEGvX5tELTRW63', // Existing client
        'clientName': 'Yaneli',
        'rating': review['rating'],
        'comment': review['comment'],
        'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(Duration(days: 30 + (i * 15))),
        ),
      });
    }
    print('  ✓ Created $numReviews reviews for supplier');
  }
}

// ==================== BOOKINGS ====================

Future<void> createBookings(FirebaseFirestore firestore, List<String> supplierIds) async {
  if (supplierIds.isEmpty) return;

  final statuses = ['pending', 'confirmed', 'completed', 'cancelled'];

  for (var i = 0; i < 3; i++) {
    final supplierId = supplierIds[i % supplierIds.length];

    await firestore.collection('bookings').add({
      'clientId': 'LZWFAQQ9dEgFhBSEGvX5tELTRW63',
      'clientName': 'Yaneli',
      'supplierId': supplierId,
      'packageName': 'Pacote Premium',
      'eventDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 30 + (i * 10)))),
      'guestCount': 150,
      'totalPrice': 150000 + (i * 50000),
      'status': statuses[i % statuses.length],
      'paymentStatus': 'pending',
      'notes': 'Casamento de ${['Maria e João', 'Ana e Pedro', 'Sofia e Carlos'][i]}',
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: i * 5))),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('  ✓ Created booking #${i + 1}');
  }
}

// ==================== CONVERSATIONS ====================

Future<void> createConversations(FirebaseFirestore firestore, List<String> supplierIds) async {
  if (supplierIds.isEmpty) return;

  final supplierId = supplierIds[0]; // Use first supplier

  // Create conversation
  final convRef = await firestore.collection('conversations').add({
    'participants': ['LZWFAQQ9dEgFhBSEGvX5tELTRW63', 'BiAuKwtQwOdVN7SJlgLkezJQhh1'],
    'clientId': 'LZWFAQQ9dEgFhBSEGvX5tELTRW63',
    'supplierId': 'BiAuKwtQwOdVN7SJlgLkezJQhh1',
    'clientName': 'Yaneli',
    'supplierName': 'David Nduwa',
    'lastMessage': 'Olá! Gostaria de mais informações sobre o pacote Premium',
    'lastMessageAt': FieldValue.serverTimestamp(),
    'lastMessageSenderId': 'LZWFAQQ9dEgFhBSEGvX5tELTRW63',
    'isActive': true,
    'unreadCount': {
      'LZWFAQQ9dEgFhBSEGvX5tELTRW63': 0,
      'BiAuKwtQwOdVN7SJlgLkezJQhh1': 1,
    },
    'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
  });

  print('  ✓ Created conversation');

  // Create messages in conversation
  final messages = [
    {
      'senderId': 'LZWFAQQ9dEgFhBSEGvX5tELTRW63',
      'receiverId': 'BiAuKwtQwOdVN7SJlgLkezJQhh1',
      'senderName': 'Yaneli',
      'text': 'Olá! Vi seu trabalho no BODA CONNECT e gostaria de mais informações sobre o pacote Premium.',
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
      'type': 'text',
      'isRead': true,
    },
    {
      'senderId': 'BiAuKwtQwOdVN7SJlgLkezJQhh1',
      'receiverId': 'LZWFAQQ9dEgFhBSEGvX5tELTRW63',
      'senderName': 'David Nduwa',
      'text': 'Olá Yaneli! Obrigado pelo interesse. O pacote Premium inclui 8 horas de cobertura, 400 fotos editadas, álbum físico e vídeo resumo. O valor é 150.000 Kz.',
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 1, minutes: 50))),
      'type': 'text',
      'isRead': true,
    },
    {
      'senderId': 'LZWFAQQ9dEgFhBSEGvX5tELTRW63',
      'receiverId': 'BiAuKwtQwOdVN7SJlgLkezJQhh1',
      'senderName': 'Yaneli',
      'text': 'Perfeito! Meu casamento será dia 15 de Março. Vocês têm disponibilidade?',
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 1, minutes: 30))),
      'type': 'text',
      'isRead': false,
    },
  ];

  for (var message in messages) {
    await convRef.collection('messages').add(message);
  }

  print('  ✓ Created 3 messages in conversation');
}
