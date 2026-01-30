# 🧪 COMPLETE SUPPLIER TESTING GUIDE

## 📋 Overview

Step-by-step guide to fully test all supplier features in Boda Connect, from registration to managing bookings and receiving payments.

---

## 🚀 PHASE 1: SUPPLIER REGISTRATION

### Test 1.1: Google Sign-In Registration

**Steps:**
```
1. Open app
2. Tap "Começar" (Get Started)
3. Tap "Registrar como Fornecedor"
4. Tap "Registrar com Google"
5. Select Google account from picker
```

**Expected Results:**
- ✅ Account picker shows (all Google accounts)
- ✅ Loading spinner appears during sign-in
- ✅ Redirected to Step 1: Basic Data screen
- ✅ No errors in console

**What to Check:**
- Console shows: `✅ Google sign in successful`
- No "user-disabled" errors
- Account picker shows every time (not cached)

---

### Test 1.2: Step 1 - Basic Data (Dados Básicos)

**Screen:** `supplier_basic_data_screen.dart`

**Steps:**
```
1. Fill in all fields:
   - Nome: "João Silva"
   - Nome do Negócio: "João Silva Fotografia"
   - Telefone: "+244 923 456 789"
   - WhatsApp: "+244 923 456 789"
   - Email: "joao@example.com"
   - Província: "Luanda"
   - Cidade: "Luanda"
2. Optional: Upload profile photo
3. Tap "Continuar"
```

**Expected Results:**
- ✅ All fields accept input
- ✅ Phone number validates Angolan format
- ✅ Email validates format
- ✅ Profile photo picker opens (camera/gallery)
- ✅ Photo preview shows after selection
- ✅ Progress bar shows 1/5 complete
- ✅ Navigates to Step 2

**What to Check:**
- Profile photo uploaded to Firebase Storage
- Data saved in registration provider
- Validation errors show for invalid inputs

---

### Test 1.3: Step 2 - Service Type (Tipo de Serviço)

**Screen:** `supplier_service_type_screen.dart`

**Steps:**
```
1. View available categories:
   - Fotografia 📷
   - Decoração 🎨
   - Catering 🍽️
   - Música 🎵
   - Espaços 🏛️
   - Transporte 🚗
2. Select "Fotografia"
3. View subcategories (event types):
   - Casamentos
   - Aniversários
   - Formaturas
   - Eventos Corporativos
4. Select "Casamentos" and "Aniversários"
5. Tap "Continuar"
```

**Expected Results:**
- ✅ All 6 categories load from Firestore
- ✅ Can select one category
- ✅ Subcategories appear after selection
- ✅ Can select multiple subcategories
- ✅ Selected items highlighted in peach color
- ✅ Progress bar shows 2/5
- ✅ Navigates to Step 3

**What to Check:**
- Categories loaded via `categoryProvider`
- Firestore query: `categories.where('isActive', isEqualTo: true)`
- Selected data saved in provider

---

### Test 1.4: Step 3 - Description (Descrição do Serviço)

**Screen:** `supplier_service_description_screen.dart`

**Steps:**
```
1. Enter description:
   "Fotografia profissional para casamentos e eventos em Luanda.
    Experiência de 5 anos, equipamento profissional, edição incluída."
2. Optional: Add features:
   - "Equipamento profissional"
   - "Edição de fotos incluída"
   - "Entrega em 7 dias"
3. Tap "Continuar"
```

**Expected Results:**
- ✅ Text area accepts multi-line input
- ✅ Character count shows (if implemented)
- ✅ Features can be added/removed
- ✅ Progress bar shows 3/5
- ✅ Navigates to Step 4

**What to Check:**
- Description saves properly
- Features list updates in real-time
- Validation for minimum description length

---

### Test 1.5: Step 4 - Upload Photos/Videos

**Screen:** `supplier_upload_content_screen.dart`

**Steps:**
```
1. Tap "Adicionar Fotos"
2. Select 5 photos from gallery
3. Verify photos preview shows
4. Optional: Tap "Adicionar Vídeo"
5. Select video from gallery
6. Verify video preview shows
7. Delete one photo by tapping X
8. Add another photo to replace
9. Tap "Continuar"
```

**Expected Results:**
- ✅ Minimum 3 photos required
- ✅ Maximum 10 photos allowed
- ✅ Photos show in grid preview
- ✅ Can delete photos
- ✅ Can add video (1 max)
- ✅ Video thumbnail shows
- ✅ Counter shows "5 / 10" photos
- ✅ Progress bar shows 4/5
- ✅ Navigates to Step 5

**What to Check:**
- Photos stored in registration provider
- File size validation (if implemented)
- Image compression applied
- Video size limit respected

---

### Test 1.6: Step 5 - Pricing & Availability

**Screen:** `supplier_pricing_availability_screen.dart`

**Steps:**
```
1. Enter pricing:
   - Preço Mínimo: "50000" (50,000 AOA)
   - Preço Máximo: "150000" (150,000 AOA)
2. Optional: Create package:
   - Nome: "Pacote Básico"
   - Descrição: "4 horas de cobertura"
   - Preço: "75000"
3. Set availability (optional)
4. Tap "Concluir Registo"
```

**Expected Results:**
- ✅ Accepts numeric input
- ✅ Currency format shows (Kz)
- ✅ Package creation works
- ✅ Loading spinner shows during save
- ✅ Success message appears
- ✅ Navigates to Supplier Dashboard

**What to Check:**
- Console: `✅ Supplier registration completed: {supplierId}`
- Firestore: `suppliers/{supplierId}` document created
- Firestore: `users/{userId}` updated with `userType: 'supplier'`
- Photos uploaded to Firebase Storage
- All registration data cleared from provider

---

## 🏠 PHASE 2: SUPPLIER DASHBOARD

### Test 2.1: Dashboard Load

**Screen:** `supplier_dashboard_screen.dart`

**Steps:**
```
1. After registration, observe dashboard
2. Check personalized greeting
3. Review statistics cards
4. Scroll through sections
```

**Expected Results:**
- ✅ Greeting shows: "Olá, João! 👋" (first name)
- ✅ Loading spinner shows while fetching data
- ✅ Stats grid shows 4 cards:
  - Pedidos Hoje: 0
  - Receita Mês: 0 Kz
  - Avaliação: 5.0 ★
  - Taxa Resposta: 0%
- ✅ Recent Orders section (empty initially)
- ✅ Upcoming Events section (empty initially)
- ✅ Quick Actions: "Novo Pacote", "Atualizar Agenda"

**What to Check:**
- Dashboard loads without errors
- Real-time listener attached to bookings
- Stats calculate correctly
- Bottom navigation shows 5 tabs

---

### Test 2.2: Bottom Navigation

**Steps:**
```
1. Tap "Pacotes" tab
2. Tap "Agenda" tab
3. Tap "Receita" tab
4. Tap "Perfil" tab
5. Tap "Dashboard" to return
```

**Expected Results:**
- ✅ Each tab navigates correctly
- ✅ Active tab highlighted in peach
- ✅ Icons change color when selected

---

## 📦 PHASE 3: MANAGE PACKAGES

### Test 3.1: View Packages

**Screen:** `supplier_packages_screen.dart`

**Steps:**
```
1. From dashboard, tap "Gerir Pacotes"
2. View package list
```

**Expected Results:**
- ✅ Shows packages created during registration
- ✅ If empty, shows "Create first package" message
- ✅ Each package card shows:
  - Package name
  - Price
  - Description
  - Edit/Delete buttons

---

### Test 3.2: Create New Package

**Steps:**
```
1. Tap "Criar Novo Pacote" (+) button
2. Fill in package details:
   - Nome: "Pacote Premium"
   - Descrição: "Cobertura completa de 8 horas com 2 fotógrafos"
   - Preço: "150000"
   - Categoria: "Fotografia"
3. Tap "Criar Pacote"
```

**Expected Results:**
- ✅ Form validates all required fields
- ✅ Loading spinner during creation
- ✅ Success message appears
- ✅ New package appears in list
- ✅ Firestore: `packages/{packageId}` created

**What to Check:**
- Package linked to supplier via `supplierId`
- `isActive: true` by default
- `createdAt` timestamp set
- Package appears in client search

---

### Test 3.3: Edit Package

**Steps:**
```
1. Tap existing package card
2. Tap "Edit" button
3. Change price to "160000"
4. Update description
5. Save changes
```

**Expected Results:**
- ✅ Current values pre-filled in form
- ✅ Can modify all fields
- ✅ Save updates Firestore
- ✅ Changes reflect immediately in list

---

### Test 3.4: Delete Package

**Steps:**
```
1. Tap package card
2. Tap "Delete" button
3. Confirm deletion in dialog
```

**Expected Results:**
- ✅ Confirmation dialog appears
- ✅ Package removed from list
- ✅ Firestore: `isActive` set to `false` (soft delete)

---

## 👤 PHASE 4: SUPPLIER PROFILE

### Test 4.1: View Own Profile

**Screen:** `supplier_profile_screen.dart`

**Steps:**
```
1. Tap "Perfil" tab in bottom nav
2. Review profile sections
```

**Expected Results:**
- ✅ Profile header shows:
  - Profile picture (first uploaded photo)
  - Business name
  - Rating (5.0 initially)
  - Category
  - Phone
  - Email
  - Location
- ✅ Performance card shows stats
- ✅ Menu sections organized:
  - CONTA (Account)
  - NEGÓCIO (Business)
  - SUPORTE (Support)

**What to Check:**
- Profile photo loads from `supplier.photos.first`
- If photos array empty, shows business icon
- Contact info visible (this is YOUR profile)

---

### Test 4.2: Edit Profile

**Steps:**
```
1. Tap "Editar Perfil"
2. Update business name
3. Change phone number
4. Add website URL
5. Add social media links:
   - Instagram: "@joaofotografia"
   - Facebook: "joaosilva.foto"
6. Save changes
```

**Expected Results:**
- ✅ Current data pre-filled
- ✅ All fields editable
- ✅ Social links saved
- ✅ Success confirmation
- ✅ Profile updates immediately

---

### Test 4.3: View Public Profile

**Screen:** `supplier_public_profile_screen.dart`

**Steps:**
```
1. From profile menu, tap "Perfil Público"
2. Review what clients see
```

**Expected Results:**
- ✅ Blue banner: "Visualização do Perfil"
- ✅ Profile card shows:
  - Profile picture (circular)
  - Business name
  - Category
  - Rating
  - Location (city, province ONLY)
- ✅ Contact info NOT visible:
  - ❌ Phone hidden
  - ❌ Email hidden
  - ❌ Website hidden
- ✅ Portfolio section shows all photos in grid
- ✅ Description displayed
- ✅ Specialties shown (subcategories)

**What to Check:**
- Privacy: No contact details visible
- Photos grid: 3 columns
- Tap photo: Opens full-screen view
- "Editar Perfil" button navigates to edit screen

---

### Test 4.4: Manage Portfolio

**Steps:**
```
1. In public profile, scroll to "Portfólio"
2. Tap "Gerir" button
3. View current photos
4. Tap "Adicionar Fotos"
5. Select 2 new photos
6. Upload them
7. Delete one old photo
```

**Expected Results:**
- ✅ Management dialog opens
- ✅ Current photos show in grid
- ✅ Can add new photos (up to 10 total)
- ✅ Upload shows progress
- ✅ Can delete photos (X button on each)
- ✅ Changes save to Firestore
- ✅ Updated photos show immediately

---

## 📅 PHASE 5: AVAILABILITY & CALENDAR

### Test 5.1: View Calendar

**Screen:** `supplier_availability_screen.dart`

**Steps:**
```
1. From dashboard, tap "Atualizar Agenda"
2. View calendar
```

**Expected Results:**
- ✅ Calendar shows current month
- ✅ Can navigate between months
- ✅ Confirmed bookings show as busy dates
- ✅ Available dates selectable

---

### Test 5.2: Block Dates

**Steps:**
```
1. Tap future date (e.g., next Saturday)
2. Mark as "Indisponível" (Unavailable)
3. Save changes
```

**Expected Results:**
- ✅ Date marked with different color
- ✅ Clients cannot book that date
- ✅ Calendar updates in real-time

---

## 💰 PHASE 6: PAYMENT METHODS

### Test 6.1: Add Payment Method

**Screen:** `payment_methods_screen.dart`

**Steps:**
```
1. From profile, tap "Métodos de Pagamento"
2. Tap "Adicionar Método"
3. Select method type:
   - "Transferência Bancária"
4. Enter details:
   - Banco: "BAI"
   - IBAN: "AO06123456789012345678901"
   - Titular: "João Silva"
5. Set as default
6. Save
```

**Expected Results:**
- ✅ Form validates IBAN format
- ✅ Can set as default
- ✅ Method saved to Firestore
- ✅ Shows in list with bank icon

---

### Test 6.2: Add Multiple Methods

**Steps:**
```
1. Add second method:
   - Type: "Multicaixa"
   - Number: "923 456 789"
2. Add third method:
   - Type: "PayPal"
   - Email: "joao@example.com"
```

**Expected Results:**
- ✅ All methods show in list
- ✅ Default method marked
- ✅ Can switch default
- ✅ Can edit/delete each

---

## 📬 PHASE 7: RECEIVING BOOKINGS (Requires Client)

### Test 7.1: Simulate Client Booking

**Setup:**
```
1. Open second device/emulator OR use browser
2. Register as client (different Google account)
3. Complete client registration
```

**Client Steps:**
```
1. Browse suppliers
2. Find your supplier (João Silva Fotografia)
3. Tap to view profile
4. Select package: "Pacote Premium"
5. Fill booking details:
   - Event: "Casamento"
   - Date: [Future date]
   - Time: "14:00"
   - Location: "Luanda"
   - Guests: 100
6. Add to cart
7. Proceed to checkout
8. Submit booking (pending payment)
```

**Expected on Supplier Device:**
- ✅ Real-time notification arrives
- ✅ Notification badge updates
- ✅ Dashboard "Pedidos Hoje" increments to 1
- ✅ Booking appears in "Recent Orders"
- ✅ Status shows "Pendente" (orange badge)

**What to Check:**
- Console: Real-time listener fired
- Firestore: `bookings/{bookingId}` created with:
  - `supplierId`: Your supplier ID
  - `clientId`: Client's user ID
  - `status`: 'pending'
  - `createdAt`: Timestamp

---

### Test 7.2: View Booking Details

**Steps:**
```
1. From dashboard, tap booking card
2. Review all details
```

**Expected Results:**
- ✅ Shows all booking info:
  - Client name
  - Event type
  - Date & time
  - Location
  - Number of guests
  - Package selected
  - Total price
  - Status
- ✅ Action buttons available:
  - "Responder" (opens chat)
  - "Aceitar"
  - "Rejeitar"

---

### Test 7.3: Accept Booking

**Steps:**
```
1. In booking detail, tap "Aceitar"
2. Confirm acceptance
```

**Expected Results:**
- ✅ Confirmation dialog appears
- ✅ Status updates to "Confirmado"
- ✅ Client receives notification
- ✅ Both dashboards sync in real-time
- ✅ Booking moves to "Upcoming Events"
- ✅ Date blocked in calendar

**What to Check:**
- Firestore: `status` changed to 'confirmed'
- Notification created for client
- Real-time update on client device

---

### Test 7.4: Reject Booking

**Steps:**
```
1. Receive another booking
2. Tap "Rejeitar"
3. Enter reason: "Data já reservada"
4. Confirm rejection
```

**Expected Results:**
- ✅ Reason dialog appears
- ✅ Status updates to "Cancelado"
- ✅ Client notified with reason
- ✅ Date becomes available again

---

## 💬 PHASE 8: CHAT & NEGOTIATION

### Test 8.1: Initiate Chat from Booking

**Steps:**
```
1. From booking detail, tap "Responder"
2. Chat screen opens
```

**Expected Results:**
- ✅ Chat loads conversation with client
- ✅ Client name shows in header
- ✅ Previous messages load (if any)

---

### Test 8.2: Send Messages

**Steps:**
```
1. Type message: "Olá! Recebi o seu pedido de reserva."
2. Tap send
3. Type: "Posso oferecer desconto de 10% para pagamento antecipado."
4. Send
```

**Expected Results:**
- ✅ Messages appear immediately in chat
- ✅ Client receives real-time messages
- ✅ Unread count updates on client side
- ✅ Last message preview updates in chat list

**What to Check:**
- Firestore: Messages in `conversations/{conversationId}/messages`
- Real-time listener updating both devices
- `lastMessageAt` updated in conversation
- `unreadCount` incremented for receiver

---

### Test 8.3: Send Quote

**Steps:**
```
1. In chat, tap attachment icon (if available)
2. Select "Enviar Orçamento"
3. Fill quote details:
   - Service: "Cobertura 6 horas + edição"
   - Price: "100000 AOA"
   - Validity: "7 dias"
4. Send quote
```

**Expected Results:**
- ✅ Quote appears as special message bubble
- ✅ Shows price prominently
- ✅ Client can accept/decline quote
- ✅ Quote data saved in message

---

### Test 8.4: Receive Client Messages

**Steps:**
```
1. Client sends: "Aceito o orçamento!"
2. Observe supplier device
```

**Expected Results:**
- ✅ Message arrives in real-time (< 1 second)
- ✅ Notification appears
- ✅ Chat badge updates
- ✅ Message shows in conversation

---

## 💳 PHASE 9: PAYMENT & COMPLETION

### Test 9.1: Client Pays Booking

**Client Device Steps:**
```
1. Go to booking
2. Tap "Pagar"
3. Select payment method
4. Enter payment proof (screenshot/reference)
5. Submit payment
```

**Expected on Supplier Device:**
- ✅ Booking status updates to "Pago"
- ✅ Payment notification received
- ✅ Payment proof visible in booking detail
- ✅ Revenue stats update

---

### Test 9.2: Mark Service Complete

**Steps:**
```
1. After event date passes
2. Open booking
3. Tap "Marcar como Concluído"
4. Confirm completion
```

**Expected Results:**
- ✅ Status changes to "Concluído"
- ✅ Booking moves to completed list
- ✅ Revenue counted in stats
- ✅ Client can now leave review

---

### Test 9.3: View Revenue

**Screen:** `supplier_revenue_screen.dart`

**Steps:**
```
1. Tap "Receita" tab
2. Review financial data
```

**Expected Results:**
- ✅ Shows monthly revenue
- ✅ Lists all completed bookings
- ✅ Shows payment status for each
- ✅ Total calculated correctly

---

## ⭐ PHASE 10: REVIEWS & RATINGS

### Test 10.1: Receive Review

**Client Device Steps:**
```
1. After booking completed
2. Go to booking detail
3. Tap "Avaliar Fornecedor"
4. Give 5 stars
5. Write review: "Excelente serviço! Muito profissional."
6. Submit
```

**Expected on Supplier Device:**
- ✅ Review appears in profile
- ✅ Rating recalculates (average)
- ✅ Review count increments
- ✅ Shows on public profile

---

### Test 10.2: View All Reviews

**Steps:**
```
1. From profile, tap "Avaliações"
2. View review list
```

**Expected Results:**
- ✅ All reviews listed
- ✅ Sorted by date (newest first)
- ✅ Shows client name, rating, comment
- ✅ Cannot delete (enforced by rules)

---

## 🔔 PHASE 11: NOTIFICATIONS

### Test 11.1: Notification Types

**Test each notification scenario:**

**New Booking:**
```
Client creates booking → Supplier receives notification
- Title: "Nova Reserva"
- Body: "Você recebeu uma nova reserva de [Client Name]"
- Tap → Opens booking detail
```

**Booking Accepted:**
```
Supplier accepts → Client receives notification
- Title: "Reserva Confirmada"
- Body: "[Supplier] confirmou sua reserva"
```

**New Message:**
```
Client sends message → Supplier receives notification
- Title: "Nova Mensagem"
- Body: "[Client]: [Message preview]"
- Tap → Opens chat
```

**Payment Received:**
```
Client pays → Supplier receives notification
- Title: "Pagamento Recebido"
- Body: "Pagamento confirmado para reserva #[ID]"
```

**New Review:**
```
Client reviews → Supplier receives notification
- Title: "Nova Avaliação"
- Body: "[Client] deixou uma avaliação de [X] estrelas"
```

**Expected for All:**
- ✅ Notification appears in system tray
- ✅ Badge count updates
- ✅ Tap notification navigates correctly
- ✅ Notification saved in Firestore
- ✅ Shown in notifications screen

---

### Test 11.2: Notification Settings

**Steps:**
```
1. Go to Settings → Notificações
2. Toggle each setting:
   - Notificações (master)
   - Push notifications
   - Email notifications
   - SMS notifications
   - Marketing emails
```

**Expected Results:**
- ✅ Master toggle disables all sub-toggles
- ✅ Each toggle works independently
- ✅ Settings save (local state)
- ✅ Visual feedback (peach color when on)

---

## 🛡️ PHASE 12: ACCOUNT & SETTINGS

### Test 12.1: Language Settings

**Steps:**
```
1. Go to Settings → Idioma
2. Tap to open selector
3. Select "English"
```

**Expected Results:**
- ✅ Dialog shows 4 languages
- ✅ Current selection marked
- ✅ Snackbar confirms: "Idioma alterado para English"

---

### Test 12.2: Region Settings

**Steps:**
```
1. Settings → Região
2. Select "Benguela"
```

**Expected Results:**
- ✅ Shows 18 Angolan provinces
- ✅ Can select any province
- ✅ Confirmation snackbar appears

---

### Test 12.3: Font Size

**Steps:**
```
1. Settings → Tamanho da Fonte
2. Select "Grande"
```

**Expected Results:**
- ✅ Shows 4 size options
- ✅ Snackbar with "Reiniciar" button
- ✅ Selection saved

---

### Test 12.4: Theme

**Steps:**
```
1. Settings → Tema
2. Select "Escuro"
```

**Expected Results:**
- ✅ Shows 3 options (Claro, Escuro, Automático)
- ✅ Selection saves
- ✅ Note: Full dark mode implementation may be TODO

---

### Test 12.5: Violations Screen

**Steps:**
```
1. Settings → Violações & Avisos
2. View violations screen
```

**Expected Results:**
- ✅ Screen loads without authentication error
- ✅ Shows warning level card
- ✅ Shows account status
- ✅ Shows violations list (empty if none)
- ✅ Guidelines displayed

---

### Test 12.6: Help Center

**Steps:**
```
1. Settings → Central de Ajuda
2. Browse help topics
```

**Expected Results:**
- ✅ FAQ sections load
- ✅ Can expand/collapse topics
- ✅ Contact support button works

---

### Test 12.7: Logout

**Steps:**
```
1. Profile → Logout button
2. Confirm logout
```

**Expected Results:**
- ✅ Confirmation dialog appears
- ✅ Signs out from Firebase
- ✅ Clears local state
- ✅ Redirects to welcome screen

---

## 🧹 PHASE 13: DATA MANAGEMENT (Debug Tools)

### Test 13.1: Seed Categories

**Steps:**
```
1. Settings → Debug Tools
2. Tap "Seed Categories"
3. Wait for completion
```

**Expected Results:**
- ✅ Loading indicator shows
- ✅ Success message appears
- ✅ 6 categories created in Firestore
- ✅ Categories appear in supplier/client registration

**What to Check:**
- Firestore: `categories` collection has 6 documents
- Each has `isActive: true`

---

### Test 13.2: Clean Database (Use with Caution!)

**Steps:**
```
1. Settings → Debug Tools
2. Tap "Clean Database"
3. Confirm action
4. Wait for completion
```

**Expected Results:**
- ✅ WARNING dialog appears
- ✅ All test data deleted
- ✅ User signed out
- ✅ App returns to welcome

**Warning:** This deletes ALL data! Use only for testing.

---

## 📊 COMPLETE TEST CHECKLIST

### Registration Flow
- [ ] Google Sign-In works
- [ ] Account picker shows
- [ ] Step 1: Basic data saves
- [ ] Step 2: Category selection works
- [ ] Step 3: Description saves
- [ ] Step 4: Photos upload (3-10)
- [ ] Step 5: Pricing saves
- [ ] Registration completes successfully
- [ ] Redirects to dashboard

### Profile & Portfolio
- [ ] Profile picture shows
- [ ] Public profile loads
- [ ] Contact info hidden from public
- [ ] Location visible
- [ ] Portfolio photos show in grid
- [ ] Can add/delete portfolio photos
- [ ] Edit profile works
- [ ] Social links save

### Dashboard & Stats
- [ ] Personalized greeting shows
- [ ] Stats cards load
- [ ] Loading spinner during data fetch
- [ ] Recent orders section updates
- [ ] Upcoming events section updates
- [ ] Bottom navigation works

### Packages
- [ ] View packages list
- [ ] Create new package
- [ ] Edit existing package
- [ ] Delete package (soft delete)
- [ ] Packages appear in client search

### Bookings (Requires Client)
- [ ] Receive booking notification
- [ ] View booking details
- [ ] Accept booking
- [ ] Reject booking
- [ ] Real-time status updates
- [ ] Calendar updates

### Chat
- [ ] Chat opens from booking
- [ ] Send text messages
- [ ] Receive messages in real-time
- [ ] Unread count updates
- [ ] Message history loads
- [ ] Send quote (if implemented)

### Payments
- [ ] Add payment method
- [ ] Set default method
- [ ] View payment proof
- [ ] Track payment status
- [ ] Revenue stats update

### Reviews
- [ ] Receive review
- [ ] Rating recalculates
- [ ] Review shows on profile
- [ ] View all reviews

### Notifications
- [ ] New booking notification
- [ ] New message notification
- [ ] Payment notification
- [ ] Review notification
- [ ] Badge counts update
- [ ] Tap notification navigates

### Settings
- [ ] Language selector (4 options)
- [ ] Region selector (18 provinces)
- [ ] Font size selector (4 sizes)
- [ ] Theme selector (3 options)
- [ ] Notification toggles work
- [ ] Master toggle disables all

### Account
- [ ] Violations screen loads
- [ ] No authentication errors
- [ ] Help center accessible
- [ ] Logout works

---

## 🐛 COMMON ISSUES & FIXES

### Issue 1: Profile Picture Not Showing
**Symptoms:** Default icon shows instead of photo

**Check:**
```
1. Firebase Console → Storage
2. Look for: suppliers/temp_{userId}/
3. Verify images exist
```

**Fix:**
- Re-upload photos during registration
- Check Firebase Storage rules allow public read
- Verify `photos` array in Firestore has URLs

---

### Issue 2: Bookings Not Appearing
**Symptoms:** Dashboard shows empty

**Check:**
```
1. Firestore → bookings collection
2. Verify supplierId matches
3. Check real-time listener console logs
```

**Fix:**
- Ensure client created booking correctly
- Check Firestore indexes deployed
- Verify real-time listener active

---

### Issue 3: Chat Not Real-Time
**Symptoms:** Messages delayed

**Check:**
```
1. Console logs for "snapshots()" listener
2. Network tab - WebSocket connection
3. Firestore rules allow read/write
```

**Fix:**
- Check internet connection
- Verify Firestore rules
- Ensure indexes deployed

---

### Issue 4: Notifications Not Arriving
**Symptoms:** No push notifications

**Check:**
```
1. Firebase Console → Cloud Messaging
2. Device FCM token registered
3. Notification permissions granted
```

**Fix:**
- Request notification permission
- Verify FCM configuration
- Check notification service running

---

## 📱 TESTING ENVIRONMENTS

### Recommended Setup:

**Primary Device (Supplier):**
- Android emulator or physical device
- Google account: supplier@test.com
- Role: Supplier

**Secondary Device (Client):**
- Different Android emulator or physical device
- Google account: client@test.com
- Role: Client

**Alternative:**
- Use Chrome browser for client (web version)
- Mobile device for supplier

---

## ✅ SUCCESS CRITERIA

After completing all tests, you should have:

- ✅ Registered supplier account with complete profile
- ✅ 5+ portfolio photos uploaded and visible
- ✅ 2+ packages created
- ✅ Payment methods configured
- ✅ Received and processed at least 1 booking
- ✅ Exchanged messages with client
- ✅ Received payment notification
- ✅ Completed booking and received review
- ✅ All settings tested and working
- ✅ No authentication errors
- ✅ Real-time features working (< 1s latency)

---

## 📝 TEST REPORT TEMPLATE

After testing, document:

```markdown
## Test Report - [Date]

### Environment
- Device: [Android Emulator / Physical]
- OS Version: Android [X]
- App Version: 1.0.0

### Tests Passed ✅
- [List all passing tests]

### Tests Failed ❌
- [List failures with details]

### Bugs Found 🐛
1. [Bug description]
   - Steps to reproduce
   - Expected vs Actual
   - Severity: Critical/High/Medium/Low

### Performance ⚡
- Dashboard load time: [X]s
- Message delivery: [X]ms
- Photo upload time: [X]s

### Recommendations 💡
- [Suggestions for improvement]
```

---

## 🎯 FINAL NOTES

- **Test incrementally**: Don't skip steps
- **Use real data**: Actual photos, realistic descriptions
- **Test edge cases**: Empty states, errors, network issues
- **Monitor console**: Watch for errors and warnings
- **Check Firestore**: Verify data saved correctly
- **Test real-time**: Use 2 devices simultaneously
- **Document bugs**: Screenshot + steps to reproduce

**Happy Testing!** 🚀
