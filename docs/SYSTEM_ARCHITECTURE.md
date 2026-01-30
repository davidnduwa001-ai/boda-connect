# BODA CONNECT - Production Marketplace System Architecture

## Executive Summary

BODA CONNECT is a production-ready wedding services marketplace connecting couples (Clients) with verified service providers (Suppliers). This document outlines the complete system architecture for a legally compliant, secure, and scalable platform handling real payments.

---

## 1. System Overview

### 1.1 Core Actors
- **Client (Noiva/Casal)**: Wedding couples searching for and booking services
- **Supplier (Fornecedor)**: Verified service providers (photographers, venues, caterers, etc.)
- **Admin**: Platform moderators with full oversight capabilities

### 1.2 Technology Stack
- **Frontend**: Flutter (iOS, Android, Web)
- **State Management**: Riverpod
- **Backend**: Firebase (Firestore, Auth, Storage, Functions)
- **Payments**: Stripe Connect (future integration)
- **Real-time**: Firestore streams

---

## 2. Data Models

### 2.1 User Model
```dart
class UserModel {
  String id;
  String email;
  String name;
  String? phone;
  String? photoUrl;
  UserRole role; // client, supplier, admin
  bool isVerified;
  bool isOnline;
  DateTime createdAt;
  DateTime lastActiveAt;
  NotificationSettings notificationSettings;
}
```

### 2.2 Supplier Model (Extended)
```dart
class SupplierModel {
  String id;
  String userId;
  String businessName;
  String description;
  SupplierCategory category;
  List<String> subcategories;

  // Location
  String city;
  String state;
  GeoPoint? location;
  int serviceRadius; // km

  // Verification
  VerificationStatus verificationStatus; // pending, verified, rejected, suspended
  List<VerificationDocument> documents;
  DateTime? verifiedAt;
  String? verificationNote;

  // Stats (denormalized for performance)
  int viewCount;
  int leadCount;
  int favoriteCount;
  int confirmedBookings;
  int completedBookings;
  double rating;
  int reviewCount;
  double responseRate;
  Duration avgResponseTime;

  // Business Details
  PriceRange priceRange;
  List<String> mediaUrls;
  List<Package> packages;
  WorkingHours workingHours;
  List<String> paymentMethods;

  // Ranking Factors
  bool isPremium;
  int profileCompleteness; // 0-100
  DateTime createdAt;
}
```

### 2.3 Verification Document Model
```dart
class VerificationDocument {
  String id;
  String supplierId;
  DocumentType type; // businessLicense, identityDocument, portfolio, insurance
  String fileUrl;
  DocumentStatus status; // pending, approved, rejected
  String? rejectionReason;
  DateTime uploadedAt;
  DateTime? reviewedAt;
  String? reviewedBy;
}

enum DocumentType {
  businessLicense,    // CNPJ/Business registration
  identityDocument,   // RG/CPF
  portfolio,          // Work samples
  insurance,          // Professional liability
  bankAccount,        // For payments
}
```

### 2.4 Booking Model (Enhanced)
```dart
class BookingModel {
  String id;
  String clientId;
  String supplierId;
  String? packageId;

  // Event Details
  DateTime eventDate;
  String eventType;
  String? eventLocation;
  String? eventNotes;

  // Financial
  double basePrice;
  double? customOfferPrice;
  double platformFee; // 10-15%
  double supplierPayout;
  double totalAmount;
  String currency;

  // Status Flow
  BookingStatus status;
  List<BookingStatusHistory> statusHistory;

  // Cancellation
  CancellationPolicy cancellationPolicy;
  DateTime? cancelledAt;
  String? cancellationReason;
  String? cancelledBy;
  double? refundAmount;

  // Timestamps
  DateTime createdAt;
  DateTime? confirmedAt;
  DateTime? paidAt;
  DateTime? completedAt;
}

enum BookingStatus {
  pending,      // Initial request
  accepted,     // Supplier accepted
  rejected,     // Supplier declined
  confirmed,    // Client confirmed (awaiting payment)
  paid,         // Payment received
  inProgress,   // Event date approaching/ongoing
  completed,    // Service delivered
  cancelled,    // Cancelled by either party
  disputed,     // Under dispute resolution
  refunded,     // Refund processed
}
```

### 2.5 Cancellation Policy Model
```dart
class CancellationPolicy {
  // 72-hour rule
  static const Duration freeCancellationWindow = Duration(hours: 72);

  // Refund tiers based on time before event
  static double getRefundPercentage(Duration timeBeforeEvent) {
    if (timeBeforeEvent > Duration(days: 30)) return 100.0;
    if (timeBeforeEvent > Duration(days: 14)) return 75.0;
    if (timeBeforeEvent > Duration(days: 7)) return 50.0;
    if (timeBeforeEvent > Duration(hours: 72)) return 25.0;
    return 0.0; // No refund within 72 hours
  }
}
```

### 2.6 Review Model (Enhanced)
```dart
class ReviewModel {
  String id;
  String bookingId; // REQUIRED - links to completed booking
  String clientId;
  String supplierId;

  // Rating
  double overallRating; // 1-5
  Map<String, double> categoryRatings; // quality, communication, punctuality, value

  // Content
  String? title;
  String content;
  List<String> photoUrls;
  List<String> tags; // "Great Communication", "On Time", etc.

  // Moderation
  ReviewStatus status; // pending, approved, rejected, flagged
  String? moderationNote;
  bool isVerifiedPurchase; // Always true since booking required

  // Response
  String? supplierResponse;
  DateTime? responseAt;

  // Timestamps
  DateTime createdAt;
  DateTime? approvedAt;
}

enum ReviewStatus {
  pending,   // Awaiting moderation
  approved,  // Visible to public
  rejected,  // Violated guidelines
  flagged,   // Under investigation
}
```

### 2.7 Dispute Model (Enhanced)
```dart
class DisputeModel {
  String id;
  String bookingId;
  String reporterId; // Who filed
  String reportedId; // Against whom
  ReporterRole reporterRole; // client or supplier

  // Classification
  DisputeCategory category;
  DisputeSeverity severity; // low, medium, high, critical

  // Details
  String title;
  String description;
  List<String> evidenceUrls; // Screenshots, photos
  List<String> messageIds; // Referenced chat messages

  // Resolution
  DisputeStatus status;
  String? assignedAdminId;
  String? resolution;
  DisputeOutcome? outcome;
  double? refundAmount;

  // Timeline
  DateTime createdAt;
  DateTime? assignedAt;
  DateTime? resolvedAt;
  List<DisputeNote> adminNotes;
}

enum DisputeCategory {
  serviceNotDelivered,
  qualityIssue,
  paymentDispute,
  noShow,
  harassment,
  fraudulentActivity,
  policyViolation,
  other,
}

enum DisputeStatus {
  open,
  underReview,
  awaitingResponse,
  resolved,
  escalated,
  closed,
}

enum DisputeOutcome {
  clientFavored,      // Full/partial refund to client
  supplierFavored,    // Supplier keeps payment
  mutualAgreement,    // Both parties agreed
  noAction,           // Insufficient evidence
  accountSuspended,   // Severe violation
}
```

### 2.8 Support Ticket Model
```dart
class SupportTicket {
  String id;
  String userId;
  String userRole; // client, supplier

  // Classification
  TicketCategory category;
  TicketPriority priority;

  // Content
  String subject;
  String description;
  List<String> attachmentUrls;

  // Assignment
  String? assignedAdminId;
  TicketStatus status;

  // Communication
  List<TicketMessage> messages;

  // Timestamps
  DateTime createdAt;
  DateTime? firstResponseAt;
  DateTime? resolvedAt;
}

enum TicketCategory {
  accountIssue,
  paymentProblem,
  technicalBug,
  featureRequest,
  bookingHelp,
  verificationHelp,
  general,
}
```

---

## 3. User Flows

### 3.1 Supplier Verification Flow
```
1. Supplier Registration
   └─> Create Account
       └─> Basic Profile Setup (name, category, location)
           └─> status = "pending_verification"

2. Document Upload
   └─> Upload Required Documents:
       ├─> Business License (CNPJ) [REQUIRED]
       ├─> Identity Document (RG/CPF) [REQUIRED]
       ├─> Portfolio (min 5 photos) [REQUIRED]
       └─> Insurance (optional but recommended)

3. Admin Review
   └─> Admin sees in Dashboard
       └─> Reviews each document
           ├─> APPROVE: All docs valid
           │   └─> status = "verified"
           │       └─> Supplier appears in search
           │           └─> Gets "Verified" badge
           │
           └─> REJECT: Issues found
               └─> status = "rejected"
                   └─> Email sent with reasons
                       └─> Supplier can re-upload

4. Post-Verification
   └─> Verified suppliers:
       ├─> Appear in search results
       ├─> Show verified badge
       ├─> Can receive bookings
       └─> Rank higher in search
```

### 3.2 Booking Flow with Cancellation
```
1. Client Discovers Supplier
   └─> Search/Browse
       └─> View Profile (trackView)
           └─> View Package/Send Message

2. Booking Request
   └─> Client selects date + package/custom offer
       └─> status = "pending"
           └─> Supplier notified

3. Supplier Response (48h limit)
   ├─> ACCEPT
   │   └─> status = "accepted"
   │       └─> Client notified
   │           └─> Client confirms + pays
   │               └─> status = "paid"
   │
   └─> REJECT (with reason)
       └─> status = "rejected"
           └─> Client notified

4. Pre-Event Period
   └─> Either party can cancel:
       ├─> > 72h before: Standard refund policy applies
       └─> < 72h before: No refund (emergency only)

5. Event Execution
   └─> status = "in_progress"
       └─> Service delivered
           └─> Supplier marks complete
               └─> status = "completed"

6. Post-Completion
   └─> Client can leave review (7 day window)
       └─> Supplier can respond
           └─> Stats updated
```

### 3.3 Dispute Resolution Flow
```
1. Dispute Filed
   └─> Client/Supplier submits dispute
       └─> Attaches evidence (screenshots, chat)
           └─> status = "open"
               └─> Admin notified

2. Initial Review (24h SLA)
   └─> Admin reviews submission
       └─> Assigns severity level
           └─> status = "under_review"
               └─> Requests response from other party

3. Investigation (48-72h)
   └─> Both parties can submit additional evidence
       └─> Admin reviews chat history
           └─> Admin may contact parties

4. Resolution
   └─> Admin decides outcome:
       ├─> CLIENT_FAVORED: Refund issued
       ├─> SUPPLIER_FAVORED: Payment released
       ├─> MUTUAL: Partial resolution
       └─> ACCOUNT_ACTION: Suspension/ban

5. Appeal (optional)
   └─> 7-day window to appeal
       └─> Senior admin review
           └─> Final decision
```

---

## 4. Search & Discovery Algorithm

### 4.1 Ranking Formula
```dart
double calculateSearchScore(Supplier s, SearchFilters filters) {
  double score = 0.0;

  // 1. Verification Status (40% weight)
  if (s.isVerified) score += 40;
  else if (s.verificationStatus == 'pending') score += 10;

  // 2. Rating Score (25% weight)
  if (s.reviewCount >= 3) {
    score += (s.rating / 5.0) * 25;
  } else {
    score += 12.5; // Neutral for new suppliers
  }

  // 3. Response Quality (15% weight)
  score += (s.responseRate / 100) * 10;
  score += (1 - (s.avgResponseTime.inHours / 24).clamp(0, 1)) * 5;

  // 4. Online/Activity Boost (10% weight)
  if (s.isOnline) score += 5;
  if (s.lastActiveAt.isAfter(DateTime.now().subtract(Duration(hours: 24)))) {
    score += 5;
  }

  // 5. Profile Completeness (10% weight)
  score += (s.profileCompleteness / 100) * 10;

  // 6. Premium Boost (bonus)
  if (s.isPremium) score *= 1.15;

  return score;
}
```

### 4.2 Filter Application
```dart
List<Supplier> applyFilters(List<Supplier> suppliers, SearchFilters f) {
  return suppliers.where((s) {
    // Category filter
    if (f.category != null && s.category != f.category) return false;

    // Location filter
    if (f.city != null && s.city != f.city) return false;
    if (f.maxDistance != null && calculateDistance(f.location, s.location) > f.maxDistance) {
      return false;
    }

    // Price range filter
    if (f.minPrice != null && s.priceRange.max < f.minPrice) return false;
    if (f.maxPrice != null && s.priceRange.min > f.maxPrice) return false;

    // Rating filter
    if (f.minRating != null && s.rating < f.minRating) return false;

    // Availability filter (requires calendar check)
    if (f.eventDate != null && !s.isAvailable(f.eventDate)) return false;

    // Verified only filter
    if (f.verifiedOnly && !s.isVerified) return false;

    return true;
  }).toList()
    ..sort((a, b) => calculateSearchScore(b, f).compareTo(calculateSearchScore(a, f)));
}
```

---

## 5. Security Considerations

### 5.1 Authentication & Authorization
```dart
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own data
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    // Suppliers
    match /suppliers/{supplierId} {
      allow read: if true; // Public profiles
      allow write: if request.auth.uid == resource.data.userId;

      // Only verified suppliers appear in search
      allow list: if resource.data.verificationStatus == 'verified';
    }

    // Bookings - both parties can read, only creator can write initially
    match /bookings/{bookingId} {
      allow read: if request.auth.uid == resource.data.clientId
                  || request.auth.uid == resource.data.supplierId;
      allow create: if request.auth.uid == request.resource.data.clientId;
      allow update: if isValidStatusTransition();
    }

    // Reviews - only after completed booking
    match /reviews/{reviewId} {
      allow read: if true;
      allow create: if hasCompletedBooking(request.auth.uid, request.resource.data.supplierId);
      allow update: if request.auth.uid == resource.data.clientId
                    && resource.data.status == 'pending';
    }

    // Messages - only participants
    match /conversations/{conversationId}/messages/{messageId} {
      allow read, write: if request.auth.uid in resource.data.participants;
    }

    // Admin access
    match /{document=**} {
      allow read, write: if isAdmin(request.auth.uid);
    }
  }
}
```

### 5.2 Data Validation
```dart
// Server-side validation (Cloud Functions)
exports.validateBooking = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();

    // Validate supplier exists and is verified
    const supplier = await admin.firestore()
      .collection('suppliers')
      .doc(booking.supplierId)
      .get();

    if (!supplier.exists || supplier.data().verificationStatus !== 'verified') {
      await snap.ref.delete();
      throw new Error('Invalid supplier');
    }

    // Validate date is in future
    if (booking.eventDate.toDate() < new Date()) {
      await snap.ref.delete();
      throw new Error('Event date must be in future');
    }

    // Validate price matches package or is custom offer
    if (booking.packageId) {
      const pkg = supplier.data().packages.find(p => p.id === booking.packageId);
      if (!pkg || pkg.price !== booking.basePrice) {
        await snap.ref.delete();
        throw new Error('Price mismatch');
      }
    }
  });
```

### 5.3 Rate Limiting
```dart
// Implement rate limiting for sensitive operations
class RateLimiter {
  static const maxBookingsPerDay = 10;
  static const maxMessagesPerMinute = 30;
  static const maxReviewsPerDay = 5;

  static Future<bool> canPerformAction(String userId, String action) async {
    final key = '${userId}_${action}';
    final count = await getActionCount(key);

    switch (action) {
      case 'booking':
        return count < maxBookingsPerDay;
      case 'message':
        return count < maxMessagesPerMinute;
      case 'review':
        return count < maxReviewsPerDay;
      default:
        return true;
    }
  }
}
```

### 5.4 PII Protection
- All sensitive data encrypted at rest (Firebase default)
- Phone numbers masked in UI until booking confirmed
- Email addresses never exposed to other users
- Document URLs are signed with expiring tokens
- Chat history preserved for disputes but purged after 2 years

---

## 6. Admin Dashboard Features

### 6.1 Dashboard Sections
1. **Overview**
   - Total users, suppliers, bookings
   - Revenue metrics
   - Active disputes count
   - Pending verifications

2. **User Management**
   - Search/filter users
   - View user details
   - Suspend/ban accounts
   - Reset passwords

3. **Supplier Management**
   - All suppliers list
   - Verification queue
   - Document review
   - Performance metrics

4. **Verification Queue**
   - Pending applications
   - Document viewer
   - Approve/reject with notes
   - Batch processing

5. **Booking Management**
   - All bookings
   - Filter by status
   - Override status (with reason)
   - Refund processing

6. **Dispute Center**
   - Open disputes
   - Assignment queue
   - Investigation tools
   - Resolution history

7. **Review Moderation**
   - Flagged reviews
   - Pending reviews
   - Edit/remove reviews
   - Appeal handling

8. **Support Tickets**
   - Ticket queue
   - Assignment
   - Response templates
   - SLA tracking

9. **Analytics**
   - User growth
   - Booking trends
   - Revenue reports
   - Category performance

10. **Settings**
    - Platform fees
    - Cancellation policies
    - Notification templates
    - Feature flags

---

## 7. Edge Cases

### 7.1 Booking Edge Cases
| Scenario | Handling |
|----------|----------|
| Supplier unresponsive for 48h | Auto-reject, notify client |
| Client no-show | Supplier marks complete, client can't dispute |
| Supplier no-show | Auto-dispute, priority resolution |
| Double booking | Prevent in code, alert if detected |
| Payment fails | Hold booking, retry window (24h) |
| Supplier account suspended mid-booking | Admin contact, manual resolution |

### 7.2 Review Edge Cases
| Scenario | Handling |
|----------|----------|
| Review before completion | Blocked by system |
| Review after 30 days | Still allowed but flagged |
| Duplicate review | Blocked, show existing |
| Review on cancelled booking | Not allowed |
| Supplier self-review | Blocked by auth rules |
| Review contains PII | Auto-flag for moderation |

### 7.3 Dispute Edge Cases
| Scenario | Handling |
|----------|----------|
| Both parties file dispute | Merge into single case |
| Evidence deleted | System preserves chat on dispute |
| Supplier closes account | Freeze funds, continue process |
| Appeal after timeout | Reject with explanation |
| Insufficient evidence | No action, clear documentation |

---

## 8. Performance Requirements

### 8.1 SLAs
- **Search Response**: < 500ms (p95)
- **Page Load**: < 2s (initial), < 500ms (subsequent)
- **Real-time Updates**: < 100ms latency
- **Uptime**: 99.9% (target 99.999%)

### 8.2 Scalability Targets
- 100,000+ suppliers
- 1,000,000+ users
- 10,000 concurrent connections
- 1,000 bookings/day

### 8.3 Optimization Strategies
1. **Denormalized Stats**: Counters on documents, not computed
2. **Pagination**: 20 items default, cursor-based
3. **Caching**: Provider-level caching with TTL
4. **Lazy Loading**: Images, media on scroll
5. **Offline Support**: Firestore persistence enabled

---

## 9. Implementation Priority

### Phase 1: Core Security (Week 1-2)
- [ ] Firestore security rules update
- [ ] Server-side validation functions
- [ ] Rate limiting implementation
- [ ] Admin authentication

### Phase 2: Verification System (Week 3-4)
- [ ] Document upload UI
- [ ] Admin verification queue
- [ ] Approval/rejection workflow
- [ ] Verified badge display

### Phase 3: Enhanced Search (Week 5)
- [ ] Ranking algorithm implementation
- [ ] Verified-first sorting
- [ ] Response rate calculation
- [ ] Online status tracking

### Phase 4: Cancellation & Disputes (Week 6-7)
- [ ] 72-hour rule implementation
- [ ] Refund calculation
- [ ] Dispute filing UI
- [ ] Admin resolution tools

### Phase 5: Admin Dashboard (Week 8-9)
- [ ] Full dashboard UI
- [ ] All moderation features
- [ ] Analytics implementation
- [ ] Support ticket system

### Phase 6: Polish & Testing (Week 10)
- [ ] Edge case testing
- [ ] Performance optimization
- [ ] Security audit
- [ ] Documentation

---

## 10. Appendix

### A. Status Transition Matrix
```
Booking Status Transitions:
pending → accepted | rejected
accepted → confirmed | cancelled
confirmed → paid | cancelled
paid → in_progress | cancelled (with refund) | disputed
in_progress → completed | disputed
completed → (final) | disputed
disputed → resolved
cancelled → (final)
refunded → (final)
```

### B. Notification Events
- Booking request received
- Booking accepted/rejected
- Payment received
- Event reminder (24h, 1h before)
- Review reminder (post-completion)
- Dispute update
- Verification status change
- Support ticket response

### C. Analytics Events
- profile_view
- search_performed
- booking_created
- booking_completed
- review_submitted
- message_sent
- favorite_added
- dispute_filed
