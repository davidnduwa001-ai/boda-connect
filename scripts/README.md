# Database Population Script

## Quick Setup - Populate Your Firebase Database

This script will automatically create realistic test data in your Firebase database.

---

## What Will Be Created

✅ **6 Categories** (Fotografia, Decoração, Catering, Música, Espaços, Transporte)
✅ **5 Suppliers** (including your existing one + 4 new ones)
✅ **15-20 Packages** (3-4 packages per supplier)
✅ **20-25 Reviews** (realistic reviews with ratings)
✅ **3 Bookings** (pending, confirmed statuses)
✅ **1 Conversation** (with 3 messages between client and supplier)

---

## Prerequisites

1. Firebase CLI installed
2. Logged into Firebase
3. Firebase Admin SDK configured

---

## Step 1: Install Firebase Admin SDK

```bash
cd c:\Users\admin\Desktop\boda_connect_flutter_full_starter
npm install firebase-admin
```

---

## Step 2: Set Firebase Project

```bash
firebase use boda-connect-49eb9
```

---

## Step 3: Run the Script

```bash
node scripts/populate_firestore.js
```

---

## Expected Output

```
🚀 Starting Firestore population...

👤 Using existing users:
   Client: LZWFAQQ9dEgFhBSEGvX5tELTRW63
   Supplier: BiAuKwtQwOdVN7SJlgLkezJQhh1

📂 Creating categories...
   ✓ Fotografia
   ✓ Decoração
   ✓ Catering
   ✓ Música
   ✓ Espaços
   ✓ Transporte

👔 Finding existing supplier...
   ✓ Found existing supplier

👔 Creating additional suppliers...
   ✓ Elegância Decorações
   ✓ Sabor & Festa Catering
   ✓ DJ Ritmo Eventos
   ✓ Salão Jardim Real

📦 Creating packages...
   ✓ 3 packages for Fotografia Premium
   ✓ 3 packages for Elegância Decorações
   ✓ 2 packages for Sabor & Festa Catering
   ✓ 2 packages for DJ Ritmo Eventos
   ✓ 3 packages for Salão Jardim Real

⭐ Creating reviews...
   ✓ 4 reviews for supplier
   ✓ 5 reviews for supplier
   ✓ 3 reviews for supplier
   ✓ 4 reviews for supplier
   ✓ 5 reviews for supplier

📅 Creating bookings...
   ✓ Booking 1 (pending)
   ✓ Booking 2 (confirmed)
   ✓ Booking 3 (confirmed)

💬 Creating conversation...
   ✓ Conversation created
   ✓ 3 messages created

✅ Database population completed successfully!

📊 Summary:
   ✓ 6 Categories
   ✓ 5 Suppliers
   ✓ 15-20 Packages
   ✓ 20-30 Reviews
   ✓ 3 Bookings
   ✓ 1 Conversation with messages

🎉 All done! Your database is ready for testing.
```

---

## Troubleshooting

### Error: "firebase-admin" not found

**Solution:**
```bash
npm install firebase-admin
```

### Error: "Permission denied"

**Solution:**
Make sure you're logged into Firebase:
```bash
firebase login
firebase use boda-connect-49eb9
```

### Error: "Cannot find existing supplier"

**Solution:**
The script looks for supplier with userId: `BiAuKwtQwOdVN7SJlgLkezJQhh1`
Check if this user exists in your `suppliers` collection.

### Error: "admin.initializeApp()"

**Solution:**
Make sure you're running the script from the project root directory:
```bash
cd c:\Users\admin\Desktop\boda_connect_flutter_full_starter
node scripts/populate_firestore.js
```

---

## After Running the Script

### Test the Complete Flow:

**As Client (Yaneli):**
1. Open app → See 6 categories
2. Browse "Fotografia" → See multiple suppliers
3. Open David's profile → See 3 packages
4. Add "Pacote Premium" to cart
5. Go to cart → See item
6. Proceed to checkout
7. Complete payment
8. View bookings → See new booking
9. Open chat → See existing conversation
10. Favorite suppliers → Heart icon should work

**As Supplier (David):**
1. Open app → Dashboard shows stats
2. View orders → See 1-2 incoming bookings
3. Accept/Reject bookings
4. View chat → See client's message
5. Reply to client
6. View reviews → See your ratings

---

## Clean Up (Optional)

If you want to start fresh, delete all test data:

```bash
# WARNING: This deletes ALL data in your database
firebase firestore:delete --all-collections --project boda-connect-49eb9
```

Then run the populate script again.

---

## Manual Verification in Firebase Console

After running the script, verify in Firebase Console:

1. **Categories** - Should have 6 documents
2. **Suppliers** - Should have 5 documents
3. **Packages** - Should have 15-20 documents
4. **Reviews** - Should have 20-25 documents
5. **Bookings** - Should have 3 documents
6. **Conversations** - Should have 1 document
   - With "messages" subcollection (3 messages)

---

## Need Help?

If the script doesn't work, you can manually populate data using the instructions in:
`test_data/IMPORT_INSTRUCTIONS.md`
