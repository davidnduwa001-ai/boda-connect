/**
 * Firebase Firestore Test Data Population Script
 *
 * Run with: node scripts/populate_firestore.js
 *
 * Make sure you're in the project directory and Firebase is initialized
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
// Uses the service account credentials from Firebase project
try {
  admin.initializeApp();
  console.log('✅ Firebase Admin initialized');
} catch (error) {
  console.log('⚠️ Firebase Admin already initialized');
}

const db = admin.firestore();

// ==================== MAIN FUNCTION ====================

async function populateDatabase() {
  console.log('\n🚀 Starting Firestore population...\n');

  try {
    // Get existing user IDs
    const clientId = 'LZWFAQQ9dEgFhBSEGvX5tELTRW63';
    const existingSupplierId = 'BiAuKwtQwOdVN7SJlgLkezJQhh1';

    console.log('👤 Using existing users:');
    console.log(`   Client: ${clientId}`);
    console.log(`   Supplier: ${existingSupplierId}\n`);

    // 1. Create Categories
    console.log('📂 Creating categories...');
    await createCategories();

    // 2. Get existing supplier ID
    console.log('\n👔 Finding existing supplier...');
    const existingSupplierDocId = await getSupplierDocId(existingSupplierId);

    if (!existingSupplierDocId) {
      console.log('❌ Could not find existing supplier document. Please check the userId.');
      return;
    }

    // 3. Create additional suppliers
    console.log('\n👔 Creating additional suppliers...');
    const newSupplierIds = await createSuppliers();
    const allSupplierIds = [existingSupplierDocId, ...newSupplierIds];

    // 4. Create packages for all suppliers
    console.log('\n📦 Creating packages...');
    await createPackages(allSupplierIds);

    // 5. Create reviews
    console.log('\n⭐ Creating reviews...');
    await createReviews(allSupplierIds, clientId);

    // 6. Create bookings
    console.log('\n📅 Creating bookings...');
    await createBookings(allSupplierIds, clientId);

    // 7. Create conversation
    console.log('\n💬 Creating conversation...');
    await createConversation(clientId, existingSupplierId, existingSupplierDocId);

    console.log('\n✅ Database population completed successfully!');
    console.log('\n📊 Summary:');
    console.log('   ✓ 6 Categories');
    console.log(`   ✓ ${allSupplierIds.length} Suppliers`);
    console.log('   ✓ 15-20 Packages');
    console.log('   ✓ 20-30 Reviews');
    console.log('   ✓ 3 Bookings');
    console.log('   ✓ 1 Conversation with messages');

  } catch (error) {
    console.error('\n❌ Error:', error);
  }
}

// ==================== CATEGORIES ====================

async function createCategories() {
  const categories = [
    { name: 'Fotografia', icon: 'camera', description: 'Fotógrafos profissionais', order: 1 },
    { name: 'Decoração', icon: 'celebration', description: 'Decoração elegante', order: 2 },
    { name: 'Catering', icon: 'restaurant', description: 'Serviços de alimentação', order: 3 },
    { name: 'Música', icon: 'music_note', description: 'DJs e bandas', order: 4 },
    { name: 'Espaços', icon: 'location_city', description: 'Salões para eventos', order: 5 },
    { name: 'Transporte', icon: 'directions_car', description: 'Carros de luxo', order: 6 },
  ];

  for (const cat of categories) {
    await db.collection('categories').add({
      ...cat,
      namePt: cat.name,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`   ✓ ${cat.name}`);
  }
}

// ==================== SUPPLIERS ====================

async function getSupplierDocId(userId) {
  const snapshot = await db.collection('suppliers').where('userId', '==', userId).limit(1).get();

  if (snapshot.empty) {
    return null;
  }

  return snapshot.docs[0].id;
}

async function createSuppliers() {
  const suppliers = [
    {
      userId: 'supplier_deco_001',
      businessName: 'Elegância Decorações',
      category: 'Decoração',
      description: 'Decoração sofisticada e personalizada para seu casamento dos sonhos',
      phone: '+244923456791',
      email: 'contato@elegancia.ao',
      location: 'Luanda, Angola',
      rating: 4.8,
      totalReviews: 0,
      accountAgeDays: 380,
      serviceCount: 15,
      responseRate: 0.96,
      completionRate: 0.98,
      isVerified: true,
      isFeatured: true,
    },
    {
      userId: 'supplier_catering_001',
      businessName: 'Sabor & Festa Catering',
      category: 'Catering',
      description: 'Catering de alta qualidade com menu personalizado',
      phone: '+244923456792',
      email: 'reservas@saborfesta.ao',
      location: 'Luanda, Angola',
      rating: 4.6,
      totalReviews: 0,
      accountAgeDays: 290,
      serviceCount: 11,
      responseRate: 0.93,
      completionRate: 0.95,
      isVerified: true,
      isFeatured: false,
    },
    {
      userId: 'supplier_music_001',
      businessName: 'DJ Ritmo Eventos',
      category: 'Música',
      description: 'DJ profissional com equipamento de som de alta qualidade',
      phone: '+244923456793',
      email: 'dj@ritmo.ao',
      location: 'Luanda, Angola',
      rating: 4.5,
      totalReviews: 0,
      accountAgeDays: 180,
      serviceCount: 8,
      responseRate: 0.91,
      completionRate: 0.94,
      isVerified: false,
      isFeatured: false,
    },
    {
      userId: 'supplier_venue_001',
      businessName: 'Salão Jardim Real',
      category: 'Espaços',
      description: 'Espaço amplo e elegante com jardim e área coberta',
      phone: '+244923456794',
      email: 'reservas@jardimreal.ao',
      location: 'Talatona, Luanda',
      rating: 4.9,
      totalReviews: 0,
      accountAgeDays: 550,
      serviceCount: 20,
      responseRate: 0.99,
      completionRate: 0.99,
      isVerified: true,
      isFeatured: true,
    },
  ];

  const supplierIds = [];

  for (const supplier of suppliers) {
    const docRef = await db.collection('suppliers').add({
      ...supplier,
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - supplier.accountAgeDays * 24 * 60 * 60 * 1000)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    supplierIds.push(docRef.id);
    console.log(`   ✓ ${supplier.businessName}`);
  }

  return supplierIds;
}

// ==================== PACKAGES ====================

async function createPackages(supplierIds) {
  // Get supplier details to create appropriate packages
  for (const supplierId of supplierIds) {
    const supplierDoc = await db.collection('suppliers').doc(supplierId).get();
    const supplier = supplierDoc.data();

    let packages = [];

    switch (supplier.category) {
      case 'Fotografia':
        packages = [
          { name: 'Básico', price: 85000, duration: 4, description: '4 horas • 200 fotos • Álbum digital', isPopular: false },
          { name: 'Premium', price: 150000, duration: 8, description: '8 horas • 400 fotos • Álbum físico • Vídeo', isPopular: true },
          { name: 'Completo', price: 280000, duration: 12, description: 'Dia completo • Fotos ilimitadas • Vídeo • Drone', isPopular: false },
        ];
        break;

      case 'Decoração':
        packages = [
          { name: 'Simples', price: 120000, duration: 6, description: '50 convidados • Arranjos florais • Centros de mesa', isPopular: false },
          { name: 'Premium', price: 280000, duration: 8, description: '150 convidados • Flores premium • Iluminação', isPopular: true },
          { name: 'Luxo', price: 450000, duration: 10, description: '300 convidados • Flores importadas • LED', isPopular: false },
        ];
        break;

      case 'Catering':
        packages = [
          { name: 'Básico', price: 175000, duration: 6, description: '50 convidados • 3 pratos • Sobremesa', isPopular: false },
          { name: 'Premium', price: 420000, duration: 8, description: '150 convidados • 5 pratos • Bar aberto', isPopular: true },
        ];
        break;

      case 'Música':
        packages = [
          { name: 'DJ 4h', price: 65000, duration: 4, description: 'DJ • Som • Iluminação básica', isPopular: false },
          { name: 'DJ Completo', price: 135000, duration: 8, description: 'DJ + MC • Som premium • LED • Fumaça', isPopular: true },
        ];
        break;

      case 'Espaços':
        packages = [
          { name: 'Básico', price: 150000, duration: 6, description: '100 convidados • Mobília • 6 horas', isPopular: false },
          { name: 'Premium', price: 280000, duration: 10, description: '200 convidados • Salão + Jardim • 10 horas', isPopular: true },
          { name: 'Exclusivo', price: 450000, duration: 12, description: '300 convidados • Tudo incluído • 12 horas', isPopular: false },
        ];
        break;

      default:
        packages = [
          { name: 'Padrão', price: 100000, duration: 6, description: 'Serviço completo', isPopular: true },
        ];
    }

    for (const pkg of packages) {
      await db.collection('packages').add({
        supplierId,
        supplierName: supplier.businessName,
        category: supplier.category,
        name: pkg.name,
        description: pkg.description,
        price: pkg.price,
        duration: pkg.duration,
        features: pkg.description.split(' • '),
        isPopular: pkg.isPopular,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(`   ✓ ${packages.length} packages for ${supplier.businessName}`);
  }
}

// ==================== REVIEWS ====================

async function createReviews(supplierIds, clientId) {
  const reviews = [
    { rating: 5, comment: 'Serviço excelente! Superou todas as expectativas.' },
    { rating: 5, comment: 'Perfeito! Recomendo 100%.' },
    { rating: 4, comment: 'Muito bom! Apenas pequenos detalhes poderiam melhorar.' },
    { rating: 5, comment: 'Simplesmente perfeito! Profissionalismo nota 10.' },
    { rating: 4.5, comment: 'Ótimo serviço e preço justo.' },
  ];

  const clientNames = ['Ana Silva', 'Pedro Costa', 'Maria Santos', 'João Ferreira', 'Sofia Lima'];

  for (const supplierId of supplierIds) {
    const numReviews = 3 + Math.floor(Math.random() * 3); // 3-5 reviews

    for (let i = 0; i < numReviews; i++) {
      const review = reviews[i % reviews.length];
      const daysAgo = 30 + (i * 15);

      await db.collection('reviews').add({
        supplierId,
        clientId,
        clientName: clientNames[i % clientNames.length],
        rating: review.rating,
        comment: review.comment,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000)),
      });
    }

    // Update supplier's totalReviews count
    await db.collection('suppliers').doc(supplierId).update({
      totalReviews: numReviews,
    });

    console.log(`   ✓ ${numReviews} reviews for supplier`);
  }
}

// ==================== BOOKINGS ====================

async function createBookings(supplierIds, clientId) {
  const bookings = [
    {
      packageName: 'Pacote Premium',
      eventDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      guestCount: 150,
      totalPrice: 150000,
      status: 'pending',
      paymentStatus: 'pending',
      paymentMethod: 'creditCard',
      notes: 'Casamento de Maria e João',
      daysAgo: 2,
    },
    {
      packageName: 'Decoração Premium',
      eventDate: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000),
      guestCount: 200,
      totalPrice: 280000,
      status: 'confirmed',
      paymentStatus: 'paid',
      paymentMethod: 'bankTransfer',
      notes: 'Preferência: cores branco e dourado',
      daysAgo: 5,
    },
    {
      packageName: 'Pacote Completo',
      eventDate: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000),
      guestCount: 180,
      totalPrice: 280000,
      status: 'confirmed',
      paymentStatus: 'partial',
      paymentMethod: 'creditCard',
      notes: 'Casamento de Ana e Pedro',
      daysAgo: 10,
    },
  ];

  for (let i = 0; i < bookings.length; i++) {
    const booking = bookings[i];
    const supplierId = supplierIds[i % supplierIds.length];

    // Get supplier name
    const supplierDoc = await db.collection('suppliers').doc(supplierId).get();
    const supplierName = supplierDoc.data().businessName;

    await db.collection('bookings').add({
      clientId,
      clientName: 'Yaneli',
      supplierId,
      supplierName,
      packageName: booking.packageName,
      eventDate: admin.firestore.Timestamp.fromDate(booking.eventDate),
      guestCount: booking.guestCount,
      totalPrice: booking.totalPrice,
      status: booking.status,
      paymentStatus: booking.paymentStatus,
      paymentMethod: booking.paymentMethod,
      notes: booking.notes,
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - booking.daysAgo * 24 * 60 * 60 * 1000)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`   ✓ Booking ${i + 1} (${booking.status})`);
  }
}

// ==================== CONVERSATION ====================

async function createConversation(clientId, supplierUserId, supplierDocId) {
  // Create conversation
  const convRef = await db.collection('conversations').add({
    participants: [clientId, supplierUserId],
    clientId,
    supplierId: supplierUserId,
    clientName: 'Yaneli',
    supplierName: 'David Nduwa',
    lastMessage: 'Perfeito! Meu casamento será dia 15 de Março.',
    lastMessageAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 90 * 60 * 1000)),
    lastMessageSenderId: clientId,
    isActive: true,
    unreadCount: {
      [clientId]: 0,
      [supplierUserId]: 1,
    },
    createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)),
  });

  console.log(`   ✓ Conversation created`);

  // Create messages
  const messages = [
    {
      senderId: clientId,
      receiverId: supplierUserId,
      senderName: 'Yaneli',
      text: 'Olá! Vi seu trabalho no BODA CONNECT e gostaria de mais informações sobre o pacote Premium.',
      minutesAgo: 120,
      isRead: true,
    },
    {
      senderId: supplierUserId,
      receiverId: clientId,
      senderName: 'David Nduwa',
      text: 'Olá Yaneli! Obrigado pelo interesse. O pacote Premium inclui 8 horas de cobertura, 400 fotos editadas, álbum físico e vídeo resumo. O valor é 150.000 Kz.',
      minutesAgo: 110,
      isRead: true,
    },
    {
      senderId: clientId,
      receiverId: supplierUserId,
      senderName: 'Yaneli',
      text: 'Perfeito! Meu casamento será dia 15 de Março. Vocês têm disponibilidade?',
      minutesAgo: 90,
      isRead: false,
    },
  ];

  for (const msg of messages) {
    await convRef.collection('messages').add({
      senderId: msg.senderId,
      receiverId: msg.receiverId,
      senderName: msg.senderName,
      text: msg.text,
      type: 'text',
      isRead: msg.isRead,
      timestamp: admin.firestore.Timestamp.fromDate(new Date(Date.now() - msg.minutesAgo * 60 * 1000)),
    });
  }

  console.log(`   ✓ 3 messages created`);
}

// ==================== RUN ====================

populateDatabase().then(() => {
  console.log('\n🎉 All done! Your database is ready for testing.\n');
  process.exit(0);
}).catch((error) => {
  console.error('\n💥 Fatal error:', error);
  process.exit(1);
});
