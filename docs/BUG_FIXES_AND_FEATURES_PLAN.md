# Bug Fixes and New Features Implementation Plan

**Date**: 2026-01-21
**Status**: Planning

---

## Issues to Fix

### 1. ✅ Favorites/Like Functionality (WORKING - NO FIX NEEDED)
**Status**: The favorites system is fully implemented and functional
- UI buttons exist in supplier detail screen and home screen
- Firestore integration complete with user favorites array
- Riverpod provider manages state correctly
- **Action**: Verify user is logged in and test functionality

### 2. ❌ Text Messaging Not Working
**Problem**: Messages are not saved to Firestore - only stored in local memory
**Root Cause**: Chat detail screen uses local state instead of repository layer
**Files to Fix**:
- `lib/features/chat/presentation/screens/chat_detail_screen.dart`

**Solution**:
- Integrate ChatRepository and SendMessage use case
- Replace local message list with Firestore StreamBuilder
- Connect send button to actual Firestore write operation

### 3. ❌ Search Bar Filter Not Working
**Problem**: Filter options (price, rating, sort) are collected but not applied
**Root Cause**: Filters are UI-state only, not sent to Firestore query
**Files to Fix**:
- `lib/features/client/presentation/screens/client_search_screen.dart`
- `lib/core/services/storage_service.dart`

**Solution**:
- Add filter parameters to searchSuppliers() method
- Implement client-side filtering for price/rating
- Apply sorting to results

### 4. ❌ Cart "Explorar Pacote" Button Not Working
**Problem**: Button needs to navigate to packages/categories
**Status**: Needs investigation - button may work but unclear destination
**Files to Check**:
- `lib/features/client/presentation/screens/cart_screen.dart`

**Solution**:
- Verify navigation routes are properly configured
- Test empty cart "Explorar Pacotes" button

### 5. ❌ "Ver Todos" Buttons Not Working
**Problem**: Featured and nearby "Ver todos" buttons may not navigate properly
**Files to Fix**:
- `lib/features/client/presentation/screens/client_home_screen.dart`

**Solution**:
- Verify route navigation for featured suppliers
- Verify route navigation for nearby suppliers

---

## New Features to Implement

### 6. 🆕 Price Negotiation Flow
**Requirements**:
1. When client receives proposal in chat, show two buttons: "Aceitar" and "Recusar"
2. If "Aceitar" → Add package directly to cart
3. If "Recusar" → Show price input dialog
4. Client enters counter-offer price
5. Send counter-offer message to supplier
6. Supplier sees counter-offer and can accept/reject
7. Continue negotiation until agreement or cancellation

**Files to Create/Modify**:
- Create `lib/features/chat/presentation/widgets/proposal_message_widget.dart`
- Modify `lib/features/chat/presentation/screens/chat_detail_screen.dart`
- Create negotiation state management in chat provider
- Add counter-offer dialog component

**Data Model**:
```dart
class ProposalMessage {
  String packageId;
  String packageName;
  double proposedPrice;
  String status; // 'pending', 'accepted', 'rejected', 'counter_offer'
  double? counterOfferPrice;
  String? counterOfferNotes;
}
```

### 7. 🆕 Uber-Style Tier System
**Requirements**:
- Categories: Basic, Gold, Diamond, Premium
- Tier based on:
  - Number of services provided
  - Average rating (5-star system)
  - Number of positive reviews
  - Account age
  - Response time
  - Completion rate

**Tier Benefits**:
- **Basic**: Standard listing
- **Gold**: Featured placement (sometimes), badge
- **Diamond**: Priority in search, featured placement, verified badge, analytics
- **Premium**: Top search placement, highlighted listing, dedicated support, premium badge

**Files to Create**:
- `lib/core/models/supplier_tier.dart` - Tier enum and benefits
- `lib/core/services/tier_calculation_service.dart` - Calculate tier based on metrics
- `lib/features/supplier/presentation/widgets/tier_badge_widget.dart` - Display tier badge
- Modify `SupplierModel` to include tier field

**Tier Calculation Logic**:
```dart
enum SupplierTier {
  basic,    // Default for new suppliers
  gold,     // 4.5+ rating, 20+ reviews, 3+ months
  diamond,  // 4.7+ rating, 50+ reviews, 6+ months, 90%+ response
  premium,  // 4.9+ rating, 100+ reviews, 12+ months, 95%+ response
}
```

---

## Implementation Order

### Phase 1: Critical Bug Fixes
1. Fix text messaging (highest priority - core functionality)
2. Fix search filtering
3. Verify and fix "Ver todos" navigation
4. Verify cart navigation

### Phase 2: Price Negotiation
1. Create proposal message widget
2. Add accept/reject buttons
3. Implement counter-offer dialog
4. Add negotiation state to chat
5. Test full negotiation flow

### Phase 3: Tier System
1. Create tier model and enum
2. Implement tier calculation service
3. Add tier field to supplier model
4. Create tier badge UI components
5. Update search/browse to prioritize by tier
6. Add tier benefits (featured placement, etc.)
7. Create admin tool to manually adjust tiers (optional)

---

## Technical Details

### Text Messaging Fix
**Current Flow** (Broken):
```
User types → _sendMessage() → _actualSendMessage() → setState() only
```

**Fixed Flow**:
```
User types → _sendMessage() → ChatRepository.sendMessage() → Firestore write → StreamBuilder updates UI
```

**Required Changes**:
1. Add ChatRepository injection via Riverpod
2. Replace `_messages` list with `StreamBuilder<List<MessageModel>>`
3. Call `sendMessage` use case on button press
4. Remove local state management

### Search Filtering Fix
**Current**: Filters stored in UI state only
**Fix**: Apply filters to query results

```dart
// Add to storage_service.dart
Future<List<SupplierModel>> searchSuppliers(
  String query, {
  double? minPrice,
  double? maxPrice,
  double? minRating,
  String? sortBy,
}) async {
  var querySnapshot = await suppliers
      .where('isActive', isEqualTo: true)
      .orderBy('businessName')
      .startAt([query])
      .endAt(['$query\uf8ff'])
      .get();

  var results = querySnapshot.docs
      .map((doc) => SupplierModel.fromFirestore(doc))
      .toList();

  // Client-side filtering
  if (minRating != null) {
    results = results.where((s) => s.rating >= minRating).toList();
  }

  // Apply sorting
  if (sortBy == 'rating') {
    results.sort((a, b) => b.rating.compareTo(a.rating));
  } else if (sortBy == 'price_low') {
    results.sort((a, b) => a.basePrice.compareTo(b.basePrice));
  }

  return results;
}
```

### Price Negotiation Implementation
**Message Types**:
- `proposal` - Initial proposal from supplier
- `counter_offer` - Client's counter-offer
- `accepted` - Proposal/counter accepted
- `rejected` - Proposal/counter rejected

**UI Flow**:
```
Chat Message → Check if type == 'proposal' → Show ProposalWidget
ProposalWidget → [Aceitar] [Recusar]
  → If Aceitar: Add to cart + send acceptance message
  → If Recusar: Show dialog → Enter price → Send counter-offer message
```

### Tier System Implementation
**Firestore Structure**:
```
suppliers/{supplierId}
├── tier: string ('basic', 'gold', 'diamond', 'premium')
├── tierUpdatedAt: timestamp
├── tierMetrics: {
│   ├── totalReviews: number
│   ├── averageRating: number
│   ├── accountAge: number (days)
│   ├── responseRate: number (0-100)
│   ├── completionRate: number (0-100)
│   └── serviceCount: number
│   }
```

**Automatic Tier Calculation** (Cloud Function):
```javascript
exports.calculateSupplierTier = functions.firestore
  .document('suppliers/{supplierId}')
  .onUpdate(async (change, context) => {
    const metrics = await getSupplierMetrics(context.params.supplierId);
    const tier = calculateTier(metrics);

    await change.after.ref.update({
      tier: tier,
      tierUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
```

---

## Testing Checklist

### Text Messaging
- [ ] Send text message
- [ ] Verify message appears in Firestore
- [ ] Reload app and verify messages persist
- [ ] Test with two different users
- [ ] Verify contact detection still works

### Search Filtering
- [ ] Search by business name
- [ ] Apply price range filter
- [ ] Apply rating filter
- [ ] Test sorting options
- [ ] Verify results update correctly

### Navigation Buttons
- [ ] Click "Ver todos" in featured section
- [ ] Click "Ver todos" in nearby section
- [ ] Click "Explorar Pacotes" in empty cart
- [ ] Verify all navigate to correct screens

### Price Negotiation
- [ ] Supplier sends proposal
- [ ] Client sees accept/reject buttons
- [ ] Client accepts → added to cart
- [ ] Client rejects → counter-offer dialog opens
- [ ] Client sends counter-offer
- [ ] Supplier sees counter-offer
- [ ] Continue negotiation until agreement

### Tier System
- [ ] New supplier starts at Basic
- [ ] Supplier with good metrics promoted to Gold
- [ ] Verify tier badge displays correctly
- [ ] Higher tier suppliers appear first in search
- [ ] Verify tier benefits are applied

---

## Files to Create

1. `lib/features/chat/presentation/widgets/proposal_message_widget.dart`
2. `lib/features/chat/presentation/widgets/counter_offer_dialog.dart`
3. `lib/core/models/supplier_tier.dart`
4. `lib/core/services/tier_calculation_service.dart`
5. `lib/features/supplier/presentation/widgets/tier_badge_widget.dart`
6. `functions/src/calculateSupplierTier.ts` (Cloud Function)

## Files to Modify

1. `lib/features/chat/presentation/screens/chat_detail_screen.dart` - Fix messaging
2. `lib/features/client/presentation/screens/client_search_screen.dart` - Fix filtering
3. `lib/core/services/storage_service.dart` - Add filter parameters
4. `lib/core/models/supplier_model.dart` - Add tier field
5. `lib/features/client/presentation/screens/client_home_screen.dart` - Verify navigation

---

**Status**: Ready to implement
**Estimated Time**: 2-3 days for all phases
