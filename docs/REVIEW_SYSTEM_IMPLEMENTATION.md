# Review System Implementation - Phase 1 Complete ✅

## Overview

Implemented a comprehensive **two-way review system** inspired by Uber/Lyft architecture, where both clients and suppliers can rate each other after completing a booking. This is Phase 1 of the complete Trust & Safety System.

---

## ✅ What's Implemented

### 1. ReviewModel - Two-Way Rating Support

**File**: [lib/core/models/review_model.dart](../lib/core/models/review_model.dart)

Complete review model with support for bidirectional reviews:

```dart
class ReviewModel {
  final String id;
  final String bookingId;          // Which booking this reviews

  // Two-way support
  final String reviewerId;          // Person leaving review
  final String reviewerType;        // 'client' or 'supplier'
  final String reviewedId;          // Person being reviewed
  final String reviewedType;        // 'client' or 'supplier'

  // Review content
  final double rating;              // 1-5 stars
  final String? comment;
  final List<String> tags;          // Predefined tags
  final List<String>? photos;       // Photo evidence

  // Context
  final String serviceCategory;
  final DateTime serviceDate;

  // Status & moderation
  final bool isPublic;
  final bool isFlagged;
  final String? flagReason;
  final ReviewStatus status;        // pending, approved, rejected, disputed, resolved

  // Timestamps & response
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;
  final String? response;           // Reviewed user can respond
}
```

**ReviewStatus Enum**:
- `pending` - Under review (new reviews start here)
- `approved` - Published and visible
- `rejected` - Violated guidelines
- `disputed` - Being investigated
- `resolved` - Dispute resolved

**Predefined Tags**:

For **Suppliers** (10 tags):
- Profissional
- Pontual
- Qualidade excelente
- Boa comunicação
- Bom valor
- Criativo
- Flexível
- Amigável
- Organizado
- Superou expectativas

For **Clients** (8 tags):
- Respeitoso
- Comunicativo
- Pagamento pontual
- Detalhes precisos
- Recomendaria
- Organizado
- Amigável
- Instruções claras

---

### 2. ReviewRepository - Complete Data Layer

**File**: [lib/core/repositories/review_repository.dart](../lib/core/repositories/review_repository.dart)

**Key Methods**:

#### Query Reviews
```dart
// Get reviews FOR a user (reviews they received)
Future<List<ReviewModel>> getReviewsForUser({
  required String userId,
  String? userType,
  int limit = 50,
})

// Get reviews BY a user (reviews they left)
Future<List<ReviewModel>> getReviewsByUser({
  required String userId,
  String? userType,
  int limit = 50,
})

// Get all reviews for a booking (both directions)
Future<List<ReviewModel>> getBookingReviews(String bookingId)

// Real-time stream
Stream<List<ReviewModel>> getReviewsStreamForUser({
  required String userId,
  String? userType,
  int limit = 50,
})
```

#### Submit & Update Reviews
```dart
// Submit new review (client→supplier OR supplier→client)
Future<String?> submitReview({
  required String bookingId,
  required String reviewerId,
  required String reviewerType,
  required String reviewedId,
  required String reviewedType,
  required String serviceCategory,
  required DateTime serviceDate,
  required double rating,
  String? comment,
  List<String>? tags,
  List<File>? photoFiles,
})

// Update existing review
Future<bool> updateReview({
  required String reviewId,
  double? rating,
  String? comment,
  List<String>? tags,
  List<String>? photos,
})

// Delete review
Future<bool> deleteReview(String reviewId)
```

#### Response System
```dart
// Add response to a review
Future<bool> addResponse({
  required String reviewId,
  required String response,
})

// Update response
Future<bool> updateResponse({
  required String reviewId,
  required String response,
})

// Delete response
Future<bool> deleteResponse(String reviewId)
```

#### Moderation & Flags
```dart
// Flag a review
Future<bool> flagReview({
  required String reviewId,
  required String flagReason,
})

// Approve review (admin)
Future<bool> approveReview(String reviewId)

// Reject review (admin)
Future<bool> rejectReview(String reviewId, String reason)

// Dispute review
Future<bool> disputeReview(String reviewId)

// Resolve disputed review (admin)
Future<bool> resolveReview(String reviewId, bool approve)

// Report review
Future<bool> reportReview({
  required String reviewId,
  required String reportedBy,
  required String reason,
})
```

#### Statistics
```dart
// Get review statistics
Future<ReviewStats> getUserStats({
  required String userId,
  required String userType,
})

// Automatic rating updates
// Whenever a review is submitted/updated/deleted, the user's average rating is automatically recalculated
```

---

### 3. ReviewProvider - Riverpod State Management

**File**: [lib/core/providers/review_provider.dart](../lib/core/providers/review_provider.dart)

**Stream Providers** (Real-time):
```dart
// Reviews FOR a user (received)
final reviewsForUserProvider = StreamProvider.family<List<ReviewModel>, ReviewsForUserParams>

// Supplier reviews (legacy compatibility)
final supplierReviewsStreamProvider = StreamProvider.family<List<ReviewModel>, String>
```

**Future Providers** (One-time fetch):
```dart
// Reviews BY a user (left by them)
final reviewsByUserProvider = FutureProvider.family<List<ReviewModel>, ReviewsByUserParams>

// All reviews for a booking
final bookingReviewsProvider = FutureProvider.family<List<ReviewModel>, String>

// Check if user reviewed a booking
final hasUserReviewedBookingProvider = FutureProvider.family<bool, HasReviewedParams>

// User review statistics
final userReviewStatsProvider = FutureProvider.family<ReviewStats, UserStatsParams>

// Legacy: Supplier stats
final supplierReviewStatsProvider = FutureProvider.family<ReviewStats, String>
```

**StateNotifier** (for mutations):
```dart
final reviewProvider = StateNotifierProvider<ReviewNotifier, ReviewState>

// Methods available:
- loadSupplierReviews(String supplierId)
- loadClientReviews(String clientId)
- submitReview(...)
- updateReview(...)
- deleteReview(String reviewId)
- addResponse(...)
- flagReview(...)
- disputeReview(String reviewId)
- reportReview(...)
```

---

### 4. LeaveReviewScreen - User Interface

**File**: [lib/features/client/presentation/screens/leave_review_screen.dart](../lib/features/client/presentation/screens/leave_review_screen.dart)

Comprehensive review submission screen with:

#### Features:
1. **Booking Information Card**
   - Shows event name, location, and date
   - Context for what's being reviewed

2. **Rating Section**
   - Interactive 5-star rating selector
   - Real-time rating label (Excelente, Muito Bom, etc.)
   - Required field

3. **Tags Section**
   - Predefined tag chips
   - Auto-selects appropriate tags based on reviewedType
   - Multi-select (optional)

4. **Comment Section**
   - Multi-line text input
   - 500 character limit
   - Optional field

5. **Photo Upload**
   - Up to 5 photos
   - Image picker integration
   - Preview with remove option
   - Optional field

6. **Submit Button**
   - Loading state during submission
   - Success/error feedback with SnackBars
   - Returns to previous screen on success

#### Usage:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => LeaveReviewScreen(
      booking: bookingModel,
      reviewedId: supplierId,
      reviewedType: 'supplier',
    ),
  ),
);
```

---

### 5. ReviewCard - Display Component

**File**: [lib/features/common/presentation/widgets/review/review_card.dart](../lib/features/common/presentation/widgets/review/review_card.dart)

Reusable widget for displaying reviews with:

#### Features:
1. **Header**
   - Star rating visualization
   - Numeric rating
   - Relative date ("Hoje", "Há 3 dias", etc.)

2. **Tags Display**
   - Chip-style tag display
   - Color-coded with AppColors.info

3. **Comment**
   - Formatted text display
   - Only shown if present

4. **Photos Grid**
   - Horizontal scrollable gallery
   - Network image loading with error handling

5. **Response Section**
   - Highlighted container
   - Shows response from reviewed user
   - Displays response date

6. **Action Buttons**
   - Responder (Respond)
   - Contestar (Dispute)
   - Reportar (Report)
   - Configurable via callbacks

#### Usage:
```dart
ReviewCard(
  review: reviewModel,
  showResponse: true,
  onRespond: () => _handleRespond(),
  onReport: () => _handleReport(),
  onDispute: () => _handleDispute(),
)
```

**Companion Widget**: `ReviewStatsWidget`
- Displays average rating
- Shows total review count
- Distribution histogram (5 stars → 1 star)
- Visual progress bars for each rating level

---

## 🔄 Two-Way Review Flow

### Scenario 1: Client Reviews Supplier

After booking completion:

1. Client goes to completed booking
2. Taps "Deixar Avaliação"
3. Opens LeaveReviewScreen with:
   - `reviewedId`: supplierId
   - `reviewedType`: 'supplier'
4. System automatically determines:
   - `reviewerId`: clientId (from Firebase Auth)
   - `reviewerType`: 'client'
5. Submits review
6. Supplier's average rating updates automatically

### Scenario 2: Supplier Reviews Client

After booking completion:

1. Supplier goes to completed booking
2. Taps "Avaliar Cliente"
3. Opens LeaveReviewScreen with:
   - `reviewedId`: clientId
   - `reviewedType`: 'client'
4. System automatically determines:
   - `reviewerId`: supplierId (from Firebase Auth)
   - `reviewerType`: 'supplier'
5. Submits review
6. Client's rating updates (stored in users collection)

---

## 📊 Data Structure

### Firestore Collection: `reviews`

```javascript
{
  "id": "review_abc123",
  "bookingId": "booking_xyz789",

  // Two-way support
  "reviewerId": "user_client123",
  "reviewerType": "client",
  "reviewedId": "user_supplier456",
  "reviewedType": "supplier",

  // Content
  "rating": 4.5,
  "comment": "Excelente serviço!",
  "tags": ["professional", "punctual", "excellent-quality"],
  "photos": [
    "https://storage.googleapis.com/...",
    "https://storage.googleapis.com/..."
  ],

  // Context
  "serviceCategory": "photography",
  "serviceDate": Timestamp,

  // Status
  "isPublic": true,
  "isFlagged": false,
  "flagReason": null,
  "status": "approved",

  // Timestamps
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "respondedAt": Timestamp,
  "response": "Obrigado pelo feedback!"
}
```

### Auto-Updated Fields

When reviews are submitted/updated/deleted:

**For Suppliers** (`suppliers/{supplierId}`):
```javascript
{
  "rating": 4.5,          // Average of all approved reviews
  "reviewCount": 42,      // Total approved reviews
  "updatedAt": Timestamp
}
```

**For Clients** (`users/{clientId}`):
```javascript
{
  "rating": 4.2,          // Average of all approved reviews
  "reviewCount": 8,       // Total approved reviews
  "updatedAt": Timestamp
}
```

---

## 🔐 Firestore Security Rules

Add these rules to ensure proper access control:

```javascript
match /reviews/{reviewId} {
  // Anyone can read approved public reviews
  allow read: if resource.data.status == 'approved' && resource.data.isPublic == true;

  // Reviewer can read their own review
  allow read: if request.auth.uid == resource.data.reviewerId;

  // Reviewed user can read reviews about them
  allow read: if request.auth.uid == resource.data.reviewedId;

  // Only authenticated users who completed a booking can create review
  allow create: if request.auth != null
    && request.resource.data.reviewerId == request.auth.uid
    && request.resource.data.status == 'pending'
    && !exists(/databases/$(database)/documents/reviews/$(reviewId))
    && hasCompletedBooking(request.resource.data.bookingId, request.auth.uid);

  // Reviewer can update their own review
  allow update: if request.auth.uid == resource.data.reviewerId
    && request.resource.data.reviewerId == resource.data.reviewerId;  // Can't change reviewer

  // Reviewed user can add/update response
  allow update: if request.auth.uid == resource.data.reviewedId
    && onlyUpdatingResponse(request.resource.data, resource.data);

  // Reviewer can delete their own review
  allow delete: if request.auth.uid == resource.data.reviewerId;
}

function hasCompletedBooking(bookingId, userId) {
  let booking = get(/databases/$(database)/documents/bookings/$(bookingId)).data;
  return booking.status == 'completed'
    && (booking.clientId == userId || booking.supplierId == userId);
}

function onlyUpdatingResponse(newData, oldData) {
  return newData.diff(oldData).affectedKeys().hasOnly(['response', 'respondedAt', 'updatedAt']);
}
```

---

## 🔍 Firestore Indexes Required

Add to [firestore.indexes.json](../firestore.indexes.json):

```json
{
  "indexes": [
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "reviewedId", "order": "ASCENDING"},
        {"fieldPath": "reviewedType", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "reviewerId", "order": "ASCENDING"},
        {"fieldPath": "reviewerType", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "bookingId", "order": "ASCENDING"},
        {"fieldPath": "reviewerId", "order": "ASCENDING"}
      ]
    }
  ]
}
```

Deploy with:
```bash
firebase deploy --only firestore:indexes
```

---

## 📝 Integration Example

### Display Supplier Reviews on Profile

```dart
class SupplierProfileScreen extends ConsumerWidget {
  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get review stats
    final statsAsync = ref.watch(supplierReviewStatsProvider(supplierId));

    // Get reviews stream
    final reviewsAsync = ref.watch(
      reviewsForUserProvider(
        ReviewsForUserParams(
          userId: supplierId,
          userType: 'supplier',
          limit: 20,
        ),
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          // Stats
          statsAsync.when(
            data: (stats) => ReviewStatsWidget(
              averageRating: stats.averageRating,
              totalReviews: stats.totalReviews,
              ratingDistribution: stats.ratingDistribution,
            ),
            loading: () => CircularProgressIndicator(),
            error: (e, st) => Text('Error loading stats'),
          ),

          // Reviews list
          reviewsAsync.when(
            data: (reviews) => ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                return ReviewCard(
                  review: reviews[index],
                  onReport: () => _reportReview(reviews[index].id),
                );
              },
            ),
            loading: () => CircularProgressIndicator(),
            error: (e, st) => Text('Error loading reviews'),
          ),
        ],
      ),
    );
  }
}
```

### Prompt User to Leave Review After Booking

```dart
void _promptReview(BuildContext context, BookingModel booking) async {
  // Check if already reviewed
  final hasReviewed = await ref.read(
    hasUserReviewedBookingProvider(
      HasReviewedParams(
        bookingId: booking.id,
        userId: currentUserId,
      ),
    ).future,
  );

  if (hasReviewed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Você já avaliou esta reserva')),
    );
    return;
  }

  // Navigate to review screen
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LeaveReviewScreen(
        booking: booking,
        reviewedId: booking.supplierId,
        reviewedType: 'supplier',
      ),
    ),
  );

  if (result == true) {
    // Review submitted successfully
    _refreshBookings();
  }
}
```

---

## ⏭️ Next Steps (Phase 2 & 3)

### Phase 2: Report System ⏳

- Create ReportModel
- Create ReportRepository
- Implement report submission UI
- Admin investigation dashboard
- Automated handling for critical reports

### Phase 3: Safety Scoring System ⏳

- Create SafetyScoreModel
- Implement automated score calculation
- Rating thresholds and warnings
- Display safety metrics on profiles
- Badge system (Verified, Top Rated, etc.)
- Automated suspension logic

---

## 📚 Files Modified/Created

### Created:
1. `lib/core/models/review_model.dart` - ReviewModel with two-way support
2. `lib/features/client/presentation/screens/leave_review_screen.dart` - Review submission UI
3. `lib/features/common/presentation/widgets/review/review_card.dart` - Review display components
4. `docs/REVIEW_SYSTEM_IMPLEMENTATION.md` - This documentation

### Modified:
1. `lib/core/repositories/review_repository.dart` - Updated for two-way reviews
2. `lib/core/providers/review_provider.dart` - Updated providers for new model

---

**Status**: ✅ Phase 1 Complete - Review System Fully Implemented

**Last Updated**: 2026-01-21
