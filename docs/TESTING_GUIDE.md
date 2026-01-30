# Testing Guide - Boda Connect

This guide will help you verify all implemented features are working correctly.

## Prerequisites

Before testing:
1. Ensure Firebase is properly configured
2. Firestore security rules are deployed
3. At least 2 test accounts created (1 client, 1 supplier)
4. Flutter app is running without compilation errors

---

## Test Plan Overview

### ✅ Feature 1: Text Messaging with Firestore Persistence
### ✅ Feature 2: Search Filtering and Sorting
### ✅ Feature 3: Navigation Buttons
### ✅ Feature 4: Price Negotiation Flow
### ✅ Feature 5: Tier System Display
### ✅ Feature 6: Complete Booking Flow

---

## 1. Text Messaging Test

**Goal:** Verify messages persist to Firestore and sync across devices

### Test Steps:

#### Setup:
1. Log in as **Client** on Device/Browser 1
2. Log in as **Supplier** on Device/Browser 2 (or use incognito)

#### Test A: Send Message from Client
1. **Client Device:**
   - Navigate to a supplier profile
   - Click "Enviar Mensagem" or similar chat button
   - Type a message: "Hello, I'm interested in your services"
   - Press Send
   - ✅ **Verify:** Message appears immediately in chat
   - ✅ **Verify:** Message shows timestamp

2. **Supplier Device:**
   - Navigate to "Mensagens" section
   - ✅ **Verify:** New conversation appears with client's name
   - Open the conversation
   - ✅ **Verify:** Client's message is visible
   - ✅ **Verify:** Message timestamp matches

#### Test B: Reply and Sync
1. **Supplier Device:**
   - In the same conversation, type: "Hello! I'd be happy to help"
   - Press Send
   - ✅ **Verify:** Message appears immediately

2. **Client Device:**
   - Close and reopen the app (or refresh)
   - Open the conversation
   - ✅ **Verify:** Both messages are visible
   - ✅ **Verify:** Messages are in correct chronological order
   - ✅ **Verify:** Client's message shows on right side
   - ✅ **Verify:** Supplier's message shows on left side

#### Test C: Firestore Verification
1. Open Firebase Console → Firestore Database
2. Navigate to `conversations` collection
3. ✅ **Verify:** Conversation document exists with both participant IDs
4. Navigate to `messages` subcollection
5. ✅ **Verify:** Both messages are stored with:
   - `text` field
   - `senderId` field
   - `receiverId` field
   - `timestamp` field
   - `conversationId` field

**Expected Result:** Messages persist across app restarts and sync between devices in real-time or on reload.

---

## 2. Search Filtering Test

**Goal:** Verify search filters properly filter and sort suppliers

### Test Steps:

#### Setup:
1. Log in as **Client**
2. Ensure database has suppliers with different ratings (e.g., 3.5, 4.0, 4.5, 5.0)

#### Test A: Rating Filter
1. Navigate to "Pesquisar" (Search) screen
2. Tap on filter icon (if available) or scroll to filter section
3. Find "Avaliação Mínima" (Minimum Rating) slider or selector
4. Set minimum rating to **4.0**
5. ✅ **Verify:** Only suppliers with rating ≥ 4.0 are displayed
6. Change minimum rating to **4.5**
7. ✅ **Verify:** List updates to show only suppliers with rating ≥ 4.5
8. Set minimum rating back to **0.0** (or minimum)
9. ✅ **Verify:** All suppliers are shown again

#### Test B: Sort by Rating
1. In search results, find "Ordenar por" (Sort by) dropdown
2. Select "Avaliação" (Rating)
3. ✅ **Verify:** Suppliers are displayed in descending rating order (highest first)
4. Select "Relevância" (Relevance)
5. ✅ **Verify:** Original order is restored

#### Test C: Combined Filters
1. Set minimum rating to **4.0**
2. Sort by "Avaliação"
3. ✅ **Verify:** Only suppliers with rating ≥ 4.0 are shown
4. ✅ **Verify:** They are sorted by rating (highest to lowest)

#### Test D: No Results Message
1. Set minimum rating to **5.0** (assuming no suppliers have exactly 5.0)
2. ✅ **Verify:** Empty state message appears
3. ✅ **Verify:** Message says "Nenhum fornecedor encontrado"
4. ✅ **Verify:** Suggestion to adjust filters is shown

**Expected Result:** Filters correctly reduce result set, sorting works, empty states are helpful.

---

## 3. Navigation Buttons Test

**Goal:** Verify all navigation buttons work correctly

### Test Steps:

#### Test A: Empty Cart Navigation
1. Log in as **Client**
2. Navigate to "Carrinho" (Cart) screen
3. Ensure cart is empty
4. ✅ **Verify:** Empty cart illustration is shown
5. Click "Explorar Pacotes" button
6. ✅ **Verify:** Navigate to Categories/Browse screen (NOT back to previous screen)
7. ✅ **Verify:** Can see supplier categories or supplier list

#### Test B: "Ver Todos" (See All) Buttons
1. From Home screen, find "Destaque" (Featured) section
2. Click "Ver todos" button
3. ✅ **Verify:** Navigate to full list of featured suppliers

4. Go back to Home screen
5. Find "Perto de Você" (Near You) section
6. Click "Ver todos" button
7. ✅ **Verify:** Navigate to full list of nearby suppliers

#### Test C: Package Selection Button
1. Navigate to any supplier detail page
2. Scroll to "Pacotes" (Packages) section
3. Click "Selecionar Pacote" button on any package card
4. ✅ **Verify:** Navigate to Package Detail screen
5. ✅ **Verify:** Package details are displayed correctly
6. ✅ **Verify:** Package name, price, description are visible

**Expected Result:** All navigation buttons navigate to correct screens, no dead-end buttons.

---

## 4. Price Negotiation Test

**Goal:** Verify price negotiation widgets display correctly (integration test to be done separately)

### Test Steps:

#### Test A: ProposalMessageWidget Visual Test
1. Open the file: `lib/features/chat/presentation/widgets/proposal_message_widget.dart`
2. Check widget parameters can be set:
   - ✅ packageName
   - ✅ price
   - ✅ notes
   - ✅ validUntil
   - ✅ status (pending/accepted/rejected/counter-offered)
   - ✅ onAccept callback
   - ✅ onReject callback

3. Widget should display:
   - ✅ Package name in bold
   - ✅ Price formatted with currency
   - ✅ Status badge with color coding
   - ✅ Accept/Reject buttons (when status is 'pending' and not from me)
   - ✅ Notes section (if provided)
   - ✅ Valid until date (if provided)

#### Test B: CounterOfferDialog Visual Test
1. Open the file: `lib/features/chat/presentation/widgets/counter_offer_dialog.dart`
2. Check dialog can be opened with:
   - ✅ originalPrice parameter
   - ✅ packageName parameter

3. Dialog should display:
   - ✅ Original price with strikethrough
   - ✅ Price input field
   - ✅ Notes input field (optional)
   - ✅ "Enviar Contraproposta" button
   - ✅ "Cancelar" button

4. Validation should work:
   - ✅ Price field is required
   - ✅ Price must be a valid number
   - ✅ Price must be lower than original price
   - ✅ Notes limited to 200 characters

**Note:** Full integration test requires chat screen integration (future enhancement).

**Expected Result:** Widgets are properly implemented and ready for integration.

---

## 5. Tier System Test

**Goal:** Verify tier calculation and badge display work correctly

### Test Steps:

#### Test A: Tier Badge Widget Visual Test
1. Find a supplier profile screen that shows tier badge
2. Look for TierBadgeWidget display
3. ✅ **Verify:** Badge shows correct emoji:
   - Basic: (none or basic icon)
   - Gold: 🥇
   - Diamond: 💎
   - Premium: 👑
4. ✅ **Verify:** Badge has gradient background
5. ✅ **Verify:** Badge shows tier name in Portuguese
6. ✅ **Verify:** Badge has subtle shadow effect

#### Test B: Tier Calculation Logic Test

**Manual Test in Dart:**
Create a test file or use Dart DevTools:

```dart
import 'package:boda_connect/core/models/supplier_tier.dart';
import 'package:boda_connect/core/services/tier_calculation_service.dart';

void testTierCalculation() {
  // Test Basic Tier
  final basicMetrics = SupplierMetrics(
    rating: 3.0,
    totalReviews: 5,
    accountAgeDays: 30,
    serviceCount: 1,
    responseRate: 0.5,
    completionRate: 0.5,
  );
  final tier1 = TierCalculationService.calculateTier(basicMetrics);
  print('Basic tier test: ${tier1.labelPt}'); // Should be "Básico"

  // Test Gold Tier
  final goldMetrics = SupplierMetrics(
    rating: 4.5,
    totalReviews: 25,
    accountAgeDays: 100,
    serviceCount: 6,
    responseRate: 0.85,
    completionRate: 0.85,
  );
  final tier2 = TierCalculationService.calculateTier(goldMetrics);
  print('Gold tier test: ${tier2.labelPt}'); // Should be "Ouro"

  // Test Diamond Tier
  final diamondMetrics = SupplierMetrics(
    rating: 4.8,
    totalReviews: 60,
    accountAgeDays: 200,
    serviceCount: 12,
    responseRate: 0.92,
    completionRate: 0.92,
  );
  final tier3 = TierCalculationService.calculateTier(diamondMetrics);
  print('Diamond tier test: ${tier3.labelPt}'); // Should be "Diamante"

  // Test Premium Tier
  final premiumMetrics = SupplierMetrics(
    rating: 4.95,
    totalReviews: 150,
    accountAgeDays: 400,
    serviceCount: 20,
    responseRate: 0.98,
    completionRate: 0.99,
  );
  final tier4 = TierCalculationService.calculateTier(premiumMetrics);
  print('Premium tier test: ${tier4.labelPt}'); // Should be "Premium"
}
```

#### Test C: Tier Progress Test
1. Use `TierCalculationService.getNextTierProgress()` method
2. Pass in metrics that don't meet next tier
3. ✅ **Verify:** Returns current tier
4. ✅ **Verify:** Returns next tier
5. ✅ **Verify:** Returns progress percentage (0.0 to 1.0)
6. ✅ **Verify:** Returns list of missing requirements in Portuguese

**Expected Result:** Tier calculation follows Uber-style progression, badges display correctly.

---

## 6. Complete Booking Flow Test

**Goal:** Verify entire client-to-supplier booking flow works end-to-end

### Test Steps:

#### Step 1: Client Home to Search
1. Log in as **Client**
2. From home screen, tap "Pesquisar" or search icon
3. ✅ **Verify:** Search screen opens
4. Enter search term (e.g., "fotografia")
5. ✅ **Verify:** Suppliers matching search appear

#### Step 2: Supplier Detail View
1. Tap on any supplier card
2. ✅ **Verify:** Supplier detail screen opens
3. ✅ **Verify:** Supplier name, rating, bio visible
4. ✅ **Verify:** Tier badge visible (if applicable)
5. ✅ **Verify:** List of packages visible
6. Scroll to packages section

#### Step 3: Package Selection
1. On any package card, tap "Selecionar Pacote" button
2. ✅ **Verify:** Navigate to Package Detail screen (NOT empty handler!)
3. ✅ **Verify:** Package name, price, description visible
4. ✅ **Verify:** "Adicionar ao Carrinho" button visible

#### Step 4: Add to Cart
1. On package detail screen, tap "Adicionar ao Carrinho"
2. ✅ **Verify:** Success message appears
3. ✅ **Verify:** Cart icon badge updates (shows "1")
4. Navigate to cart screen

#### Step 5: Cart Review
1. On cart screen, verify:
   - ✅ Package name visible
   - ✅ Supplier name visible
   - ✅ Price visible
   - ✅ Total price calculated correctly
2. ✅ **Verify:** "Finalizar Pedido" button visible and enabled
3. Tap "Finalizar Pedido"

#### Step 6: Checkout
1. On checkout screen, verify:
   - ✅ Order summary visible
   - ✅ Package details visible
   - ✅ Total price matches cart
   - ✅ Payment method selector visible
2. Select a payment method (e.g., "Cartão de Crédito")
3. ✅ **Verify:** Selected payment method is highlighted
4. Tap "Confirmar Pedido" or similar button

#### Step 7: Payment Success
1. ✅ **Verify:** Navigate to success/confirmation screen
2. ✅ **Verify:** Success message or icon visible
3. ✅ **Verify:** Order number or booking ID visible
4. ✅ **Verify:** "Ver Pedidos" or "Voltar ao Início" button visible

#### Step 8: Supplier Order View
1. Log out and log in as **Supplier** (or switch account)
2. Navigate to "Pedidos" or "Orders" section
3. ✅ **Verify:** New order appears in list
4. ✅ **Verify:** Order shows:
   - Client name
   - Package name
   - Price
   - Status (should be "Pendente" or "pending")
5. Tap on the order

#### Step 9: Supplier Order Detail
1. On order detail screen, verify:
   - ✅ Client information visible
   - ✅ Package details visible
   - ✅ Event date/time (if applicable)
   - ✅ Status badge visible
2. Look for action buttons:
   - ✅ "Aceitar" button visible
   - ✅ "Recusar" button visible

**Expected Result:** Complete flow from search to booking confirmation works without errors or dead ends.

---

## Common Issues to Check

### Issue 1: Messages Not Persisting
**Symptoms:** Messages disappear after app restart
**Check:**
- Firebase configuration correct?
- Firestore rules deployed?
- Console shows "✅ Message sent to Firestore" log?
- Conversation ID is being generated/retrieved?

### Issue 2: Filters Not Working
**Symptoms:** Changing filters doesn't update results
**Check:**
- `_applyFilters()` method is being called?
- Filter values are being updated in state?
- ListView is rebuilding when filters change?

### Issue 3: Navigation Goes to Wrong Screen
**Symptoms:** Button click goes to unexpected screen
**Check:**
- Using `context.go()` vs `context.push()` correctly?
- Route paths match defined routes?
- Extra parameters being passed correctly?

### Issue 4: Package Selection Does Nothing
**Symptoms:** "Selecionar Pacote" button click has no effect
**Check:**
- Button's `onPressed` is NOT empty: `onPressed: () {}`
- Should have: `onPressed: () { context.push(Routes.clientPackageDetail, extra: package); }`

### Issue 5: Tier Badge Not Showing
**Symptoms:** No tier badge visible on supplier profiles
**Check:**
- TierBadgeWidget is included in supplier card/profile?
- Supplier has tier data?
- Basic tier returns `SizedBox.shrink()` (no badge by design)

---

## Automated Testing (Future Enhancement)

For production, consider adding:
1. **Widget Tests** for each UI component
2. **Integration Tests** for complete flows
3. **Unit Tests** for business logic (tier calculation, etc.)
4. **Firestore Emulator Tests** for database operations

---

## Test Results Template

Copy this and fill out as you test:

```
# Test Results - [Date]

## 1. Text Messaging
- [ ] Messages send successfully
- [ ] Messages persist to Firestore
- [ ] Messages sync across devices
- [ ] Conversation created correctly
- Issues found: _______________

## 2. Search Filtering
- [ ] Rating filter works
- [ ] Sort by rating works
- [ ] Combined filters work
- [ ] Empty state shows correctly
- Issues found: _______________

## 3. Navigation Buttons
- [ ] Cart "Explorar Pacotes" navigates correctly
- [ ] "Ver todos" buttons work
- [ ] Package selection navigates correctly
- Issues found: _______________

## 4. Price Negotiation
- [ ] ProposalMessageWidget displays correctly
- [ ] CounterOfferDialog opens and validates
- [ ] Widgets ready for integration
- Issues found: _______________

## 5. Tier System
- [ ] Tier badges display correctly
- [ ] Tier calculation logic works
- [ ] Progress calculation works
- Issues found: _______________

## 6. Complete Booking Flow
- [ ] Search to supplier detail works
- [ ] Package selection works
- [ ] Add to cart works
- [ ] Checkout works
- [ ] Supplier receives order
- Issues found: _______________

## Overall Status
- [ ] All tests passed
- [ ] Ready for production
- [ ] Issues need fixing

Critical issues: _______________
Non-critical issues: _______________
```

---

## Quick Smoke Test (5 Minutes)

If you want a quick verification:

1. **Login** as client ✅
2. **Search** for supplier ✅
3. **Select package** and verify it opens detail screen ✅
4. **Add to cart** ✅
5. **Send message** to supplier and check Firebase Console ✅
6. **Apply rating filter** and verify results change ✅
7. **Navigate** from empty cart using "Explorar Pacotes" ✅

If all 7 steps work, core functionality is good!

---

## Need Help?

If you encounter issues:
1. Check Flutter console for error messages
2. Check Firebase Console → Firestore for data
3. Check browser console (for Flutter Web)
4. Verify Firestore rules are deployed
5. Ensure all dependencies are installed (`flutter pub get`)

**Files to reference:**
- Chat implementation: `lib/features/chat/presentation/screens/chat_detail_screen.dart`
- Search filters: `lib/features/client/presentation/screens/client_search_screen.dart`
- Navigation fixes: `lib/features/client/presentation/screens/cart_screen.dart` & `client_supplier_detail_screen.dart`
- Tier system: `lib/core/models/supplier_tier.dart` & `lib/core/services/tier_calculation_service.dart`
