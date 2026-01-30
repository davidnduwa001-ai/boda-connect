# Firebase Test Data Import Instructions

## Quick Setup - Import Test Data to Firebase

This guide will help you populate your Firebase database with comprehensive test data to properly test the client-supplier flow.

---

## Option 1: Manual Import via Firebase Console (RECOMMENDED)

### Step 1: Prepare Your Existing Users

You already have 2 users in your database:
1. **Client:** Yaneli (`LZWFAQQ9dEgFhBSEGvX5tELTRW63`)
2. **Supplier:** David Nduwa (`BiAuKwtQwOdVN7SJlgLkezJQhh1`)

We'll use these to create realistic test data.

---

### Step 2: Import Categories

1. Go to Firebase Console → Firestore Database
2. Click "Start collection"
3. Collection ID: `categories`
4. Add these 6 documents manually (or use the JSON files I'll create):

**Document 1:**
```
Document ID: (auto-generated)
Fields:
  name: "Fotografia"
  namePt: "Fotografia"
  icon: "camera"
  description: "Fotógrafos profissionais para capturar momentos especiais"
  order: 1
  isActive: true
  createdAt: (current timestamp)
```

Repeat for: Decoração, Catering, Música, Espaços, Transporte

---

### Step 3: Create More Suppliers

Since you only have 1 supplier (David), let's create a few more manually:

**Go to Firestore → suppliers collection → Add document:**

**Supplier 2 - Elegância Decorações:**
```json
{
  "userId": "supplier_deco_001",
  "businessName": "Elegância Decorações",
  "category": "Decoração",
  "description": "Decoração sofisticada e personalizada para seu casamento dos sonhos",
  "phone": "+244923456791",
  "email": "contato@elegancia.ao",
  "location": "Luanda, Angola",
  "rating": 4.8,
  "totalReviews": 103,
  "accountAgeDays": 380,
  "serviceCount": 15,
  "responseRate": 0.96,
  "completionRate": 0.98,
  "isVerified": true,
  "isFeatured": true,
  "photoUrl": "https://via.placeholder.com/400",
  "coverPhoto": "https://via.placeholder.com/800",
  "createdAt": (timestamp),
  "updatedAt": (timestamp)
}
```

**Supplier 3 - Salão Jardim Real:**
```json
{
  "userId": "supplier_venue_001",
  "businessName": "Salão Jardim Real",
  "category": "Espaços",
  "description": "Espaço amplo e elegante com jardim e área coberta",
  "phone": "+244923456794",
  "email": "reservas@jardimreal.ao",
  "location": "Talatona, Luanda",
  "rating": 4.9,
  "totalReviews": 156,
  "accountAgeDays": 550,
  "serviceCount": 20,
  "responseRate": 0.99,
  "completionRate": 0.99,
  "isVerified": true,
  "isFeatured": true,
  "photoUrl": "https://via.placeholder.com/400",
  "coverPhoto": "https://via.placeholder.com/800",
  "createdAt": (timestamp),
  "updatedAt": (timestamp)
}
```

---

### Step 4: Create Packages

For EACH supplier, create 2-3 packages:

**Go to Firestore → packages collection → Add document:**

**For David Nduwa (Photography):**

**Package 1 - Básico:**
```json
{
  "supplierId": "(David's supplier doc ID)",
  "supplierName": "Fotografia Premium",
  "name": "Pacote Básico",
  "description": "4 horas de cobertura\n200 fotos editadas\nÁlbum digital",
  "price": 85000,
  "duration": 4,
  "category": "Fotografia",
  "features": ["4 horas", "200 fotos", "Álbum digital"],
  "isPopular": false,
  "isActive": true,
  "createdAt": (timestamp),
  "updatedAt": (timestamp)
}
```

**Package 2 - Premium:**
```json
{
  "supplierId": "(David's supplier doc ID)",
  "supplierName": "Fotografia Premium",
  "name": "Pacote Premium",
  "description": "8 horas de cobertura\n400 fotos editadas\nÁlbum físico + digital\nVídeo resumo",
  "price": 150000,
  "duration": 8,
  "category": "Fotografia",
  "features": ["8 horas", "400 fotos", "Álbum físico", "Vídeo resumo"],
  "isPopular": true,
  "isActive": true,
  "createdAt": (timestamp),
  "updatedAt": (timestamp)
}
```

**Package 3 - Completo:**
```json
{
  "supplierId": "(David's supplier doc ID)",
  "supplierName": "Fotografia Premium",
  "name": "Pacote Completo",
  "description": "Cobertura completa\nFotos ilimitadas\n2 álbuns físicos\nVídeo completo\nDrone",
  "price": 280000,
  "duration": 12,
  "category": "Fotografia",
  "features": ["Dia completo", "Fotos ilimitadas", "2 álbuns", "Vídeo", "Drone"],
  "isPopular": false,
  "isActive": true,
  "createdAt": (timestamp),
  "updatedAt": (timestamp)
}
```

**Repeat similar packages for other suppliers** (adjust prices and descriptions for their categories).

---

### Step 5: Create Reviews

**Go to Firestore → reviews collection → Add document:**

**Review 1 (for David):**
```json
{
  "supplierId": "(David's supplier doc ID)",
  "clientId": "LZWFAQQ9dEgFhBSEGvX5tELTRW63",
  "clientName": "Ana Silva",
  "rating": 5.0,
  "comment": "Serviço excelente! Superou todas as expectativas. Muito profissional.",
  "createdAt": (timestamp - 30 days ago)
}
```

**Review 2:**
```json
{
  "supplierId": "(David's supplier doc ID)",
  "clientId": "LZWFAQQ9dEgFhBSEGvX5tELTRW63",
  "clientName": "Pedro Costa",
  "rating": 5.0,
  "comment": "Perfeito! Recomendo 100%. Fizeram um trabalho incrível no nosso casamento.",
  "createdAt": (timestamp - 45 days ago)
}
```

Create **3-5 reviews per supplier** to make ratings realistic.

---

### Step 6: Create Sample Bookings

**Go to Firestore → bookings collection → Add document:**

**Booking 1 (Pending):**
```json
{
  "clientId": "LZWFAQQ9dEgFhBSEGvX5tELTRW63",
  "clientName": "Yaneli",
  "supplierId": "(David's supplier doc ID)",
  "supplierName": "Fotografia Premium",
  "packageId": "(Package Premium ID)",
  "packageName": "Pacote Premium",
  "eventDate": (timestamp - 30 days from now),
  "guestCount": 150,
  "totalPrice": 150000,
  "status": "pending",
  "paymentStatus": "pending",
  "paymentMethod": "creditCard",
  "notes": "Casamento de Maria e João",
  "createdAt": (timestamp),
  "updatedAt": (timestamp)
}
```

**Booking 2 (Confirmed):**
```json
{
  "clientId": "LZWFAQQ9dEgFhBSEGvX5tELTRW63",
  "clientName": "Yaneli",
  "supplierId": "(Decoration supplier ID)",
  "supplierName": "Elegância Decorações",
  "packageId": "(Package ID)",
  "packageName": "Decoração Premium",
  "eventDate": (timestamp - 45 days from now),
  "guestCount": 200,
  "totalPrice": 280000,
  "status": "confirmed",
  "paymentStatus": "paid",
  "paymentMethod": "bankTransfer",
  "notes": "Preferência por cores: branco e dourado",
  "createdAt": (timestamp - 5 days),
  "updatedAt": (timestamp)
}
```

---

## Option 2: Quick Test with Cloud Shell (FASTEST)

I'll create a simplified Firebase Admin script you can run in Firebase Cloud Shell:

### Steps:

1. **Open Firebase Console**
2. Click the **terminal icon** (Cloud Shell) at top right
3. **Copy-paste the script** I'll create
4. Run it

Let me create that script now...

---

## What You'll Have After Import:

✅ **6 Categories** (Fotografia, Decoração, Catering, Música, Espaços, Transporte)
✅ **6 Suppliers** (various categories with realistic data)
✅ **15-20 Packages** (multiple packages per supplier)
✅ **20-30 Reviews** (realistic reviews with ratings)
✅ **3-5 Bookings** (different statuses: pending, confirmed, completed)
✅ **1 Conversation** (with 3 messages between client and supplier)

---

## Test Flow After Import:

### As Client (Yaneli):
1. ✅ Browse categories
2. ✅ See multiple suppliers per category
3. ✅ View supplier profiles with packages
4. ✅ Add packages to cart
5. ✅ Complete checkout
6. ✅ View bookings
7. ✅ Chat with suppliers
8. ✅ Favorite suppliers

### As Supplier (David):
1. ✅ View incoming bookings
2. ✅ Accept/reject bookings
3. ✅ Chat with clients
4. ✅ View reviews
5. ✅ Manage packages

---

## Estimated Time:

- **Manual import:** 20-30 minutes (but most complete control)
- **Cloud Shell script:** 2-3 minutes (fastest)

---

## Which Method Do You Want?

**Tell me and I'll provide:**
1. **Manual step-by-step** - I'll guide you through each document
2. **Cloud Shell script** - One-click automated import
3. **CSV/JSON files** - You import via Firebase Console import feature

Just let me know which you prefer! 🚀
