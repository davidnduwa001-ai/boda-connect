# Trust & Safety Architecture - Uber/Lyft Model for Boda Connect

## Overview

Implementing a robust trust and safety system similar to Uber/Lyft to ensure quality service and protect both clients and suppliers.

---

## Core Principles (Inspired by Uber/Lyft)

### 1. Two-Way Rating System
- Both clients AND suppliers rate each other
- Ratings affect user standing and visibility
- Low-rated users face consequences

### 2. Automated Safety Triggers
- Automatic actions based on rating thresholds
- Escalation system for serious violations
- Progressive discipline approach

### 3. Report System
- Multiple report categories
- Severity levels
- Investigation workflow

### 4. Quality Control
- Minimum rating requirements
- Activity-based reputation
- Verification badges

---

## Data Models

### 1. Review Model

```dart
class ReviewModel {
  final String id;
  final String bookingId;          // Which booking this is for

  // Who is reviewing whom
  final String reviewerId;          // Person leaving review
  final String reviewerType;        // 'client' or 'supplier'
  final String reviewedId;          // Person being reviewed
  final String reviewedType;        // 'client' or 'supplier'

  // Review content
  final double rating;              // 1-5 stars
  final String? comment;
  final List<String> tags;          // e.g., ['professional', 'on-time', 'quality-work']
  final List<String>? photos;       // Photo evidence

  // Context
  final String serviceCategory;     // What service was provided
  final DateTime serviceDate;       // When service occurred

  // Status
  final bool isPublic;              // Visible to others
  final bool isFlagged;             // Flagged for review
  final String? flagReason;
  final ReviewStatus status;        // pending, approved, rejected, disputed

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;      // When reviewed user responded
  final String? response;           // Supplier/client response to review
}

enum ReviewStatus {
  pending,      // Under review
  approved,     // Published
  rejected,     // Violated guidelines
  disputed,     // Being investigated
  resolved,     // Dispute resolved
}
```

### 2. Report Model

```dart
class ReportModel {
  final String id;
  final String reporterId;
  final String reporterType;        // 'client' or 'supplier'
  final String reportedId;
  final String reportedType;

  // Report details
  final ReportCategory category;
  final ReportSeverity severity;    // Auto-calculated or admin-set
  final String description;
  final List<String>? evidence;     // Photos, screenshots
  final String? bookingId;          // Related booking if applicable

  // Investigation
  final ReportStatus status;
  final String? investigatorId;     // Admin handling this
  final DateTime? investigatedAt;
  final String? investigationNotes;
  final ReportAction? actionTaken;

  // Timestamps
  final DateTime createdAt;
  final DateTime? resolvedAt;
}

enum ReportCategory {
  // Supplier issues (by clients)
  noShow,                    // Supplier didn't show up
  lateArrival,              // Significantly late
  poorQuality,              // Service quality issues
  unprofessional,           // Rude, inappropriate behavior
  overcharging,             // Price manipulation
  fraudulent,               // Fake service, scam
  harassment,               // Sexual/verbal harassment
  discrimination,           // Based on race, gender, etc.

  // Client issues (by suppliers)
  clientNoShow,             // Client not present
  nonPayment,               // Refused to pay
  abusiveBehavior,          // Rude, threatening
  falseInformation,         // Lied about event details
  cancelledLastMinute,      // Cancelled too late
  unsafeEnvironment,        // Dangerous location/situation

  // Platform abuse (both)
  fakeReview,               // Fraudulent review
  spam,                     // Spamming messages
  accountHacking,           // Compromised account
  multipleAccounts,         // Creating fake accounts
  other,
}

enum ReportSeverity {
  low,        // Minor issue, warning
  medium,     // Suspension possible
  high,       // Immediate suspension
  critical,   // Permanent ban, legal involvement
}

enum ReportStatus {
  pending,      // Waiting for review
  investigating, // Under investigation
  resolved,     // Completed
  dismissed,    // No action needed
  escalated,    // Sent to higher level
}

enum ReportAction {
  noAction,
  warning,
  temporarySuspension,
  permanentBan,
  accountReview,
  refundIssued,
  other,
}
```

### 3. User Safety Score Model

```dart
class SafetyScoreModel {
  final String userId;
  final String userType;           // 'client' or 'supplier'

  // Ratings
  final double overallRating;      // Average rating (1-5)
  final int totalReviews;
  final Map<int, int> ratingDistribution; // {5: 45, 4: 30, 3: 15, 2: 8, 1: 2}

  // Behavior metrics
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double completionRate;     // % of completed bookings
  final double cancellationRate;

  // Safety incidents
  final int totalReports;          // Reports against this user
  final int seriousViolations;     // High severity reports
  final int warnings;
  final int suspensions;

  // Reliability (supplier-specific)
  final double? responseRate;      // % of messages responded to
  final double? onTimeRate;        // % of bookings where supplier was on time
  final double? qualityScore;      // Based on review tags

  // Status
  final SafetyStatus status;
  final String? statusReason;
  final DateTime? statusExpiresAt;

  // Verification
  final bool isVerified;           // Identity verified
  final bool isBackgroundChecked;  // Background check passed
  final List<String> badges;       // ['top-rated', 'reliable', 'verified']

  final DateTime updatedAt;
}

enum SafetyStatus {
  good,              // Good standing
  warning,           // Has warnings
  probation,         // On probation
  suspended,         // Temporarily suspended
  banned,            // Permanently banned
  underReview,       // Being investigated
}
```

### 4. Incident Model

```dart
class IncidentModel {
  final String id;
  final String userId;
  final String userType;

  // Incident details
  final IncidentType type;
  final IncidentSeverity severity;
  final String description;
  final String? bookingId;
  final String? reportId;

  // Action taken
  final IncidentAction action;
  final String actionReason;
  final DateTime? actionExpiresAt;   // For temporary suspensions

  // Status
  final bool isActive;
  final String? adminId;
  final String? adminNotes;

  final DateTime createdAt;
  final DateTime? resolvedAt;
}

enum IncidentType {
  lowRating,
  multipleReports,
  seriousViolation,
  patternOfAbuse,
  fraudulentActivity,
  other,
}

enum IncidentSeverity {
  minor,
  moderate,
  severe,
  critical,
}

enum IncidentAction {
  warning,
  ratingPenalty,
  visibilityReduction,
  temporarySuspension,
  permanentBan,
  accountReview,
  requireRetraining,
}
```

---

## Firestore Structure

```
/reviews
  /{reviewId}
    - reviewerId, reviewedId, rating, comment, tags, etc.

/reports
  /{reportId}
    - reporterId, reportedId, category, severity, status, etc.

/safetyScores
  /{userId}
    - overallRating, totalReviews, completionRate, status, etc.

/incidents
  /{incidentId}
    - userId, type, action, severity, etc.

/safetyAlerts (for admins)
  /{alertId}
    - userId, alertType, priority, status

/disputedReviews
  /{reviewId}
    - Original review data + dispute info

/userFlags (automated triggers)
  /{userId}
    - flags: ['low-rating', 'multiple-reports', 'cancellation-rate']
    - flaggedAt, autoActions
```

---

## Automated Safety Rules (Uber/Lyft Style)

### For Suppliers:

```dart
// RULE 1: Rating Threshold
if (overallRating < 4.0 && totalReviews >= 10) {
  action: WARNING;
  message: "Your rating is below our minimum standard";
  consequence: "Visibility reduced in search results";
}

if (overallRating < 3.5 && totalReviews >= 20) {
  action: PROBATION;
  message: "Your account is under review";
  consequence: "New bookings temporarily paused";
  duration: 7 days;
}

if (overallRating < 3.0 && totalReviews >= 25) {
  action: SUSPENSION;
  message: "Your account has been suspended";
  consequence: "Cannot accept new bookings";
  duration: 30 days;
  appeal: true;
}

// RULE 2: Cancellation Rate
if (cancellationRate > 15% && totalBookings >= 10) {
  action: WARNING;
  penalty: "Reduced search ranking";
}

if (cancellationRate > 25% && totalBookings >= 15) {
  action: PROBATION;
  penalty: "Temporary suspension from featured listings";
}

// RULE 3: Multiple Reports
if (totalReports >= 3 in last 30 days) {
  action: AUTOMATIC_REVIEW;
  consequence: "Account flagged for investigation";
}

if (seriousViolations >= 1) {
  action: IMMEDIATE_SUSPENSION;
  consequence: "Account suspended pending investigation";
  duration: "Until resolved";
}

// RULE 4: No-Show Pattern
if (noShowCount >= 2 in last 60 days) {
  action: WARNING;
  penalty: "Must provide 48hr cancellation notice";
}

if (noShowCount >= 3 in last 90 days) {
  action: SUSPENSION;
  duration: 14 days;
}

// RULE 5: Response Time (Quality Badge)
if (responseRate > 90% && avgResponseTime < 2 hours) {
  badge: "RESPONSIVE";
  benefit: "+10% search ranking boost";
}

if (responseRate < 50% && totalMessages >= 20) {
  penalty: "Removed from featured listings";
}
```

### For Clients:

```dart
// RULE 1: Client Rating
if (overallRating < 3.5 && totalReviews >= 5) {
  action: WARNING;
  message: "Suppliers may decline your bookings";
}

if (overallRating < 3.0 && totalReviews >= 10) {
  action: PROBATION;
  consequence: "Require upfront payment for all bookings";
}

// RULE 2: Payment Issues
if (nonPaymentReports >= 1) {
  action: IMMEDIATE_RESTRICTION;
  consequence: "Upfront payment required";
}

if (nonPaymentReports >= 2) {
  action: SUSPENSION;
  duration: "Until payment disputes resolved";
}

// RULE 3: Last-Minute Cancellations
if (lastMinuteCancellations >= 3 in last 60 days) {
  action: WARNING;
  penalty: "Cancellation fees applied";
}

// RULE 4: Abusive Behavior
if (harassmentReports >= 1) {
  action: IMMEDIATE_REVIEW;
  consequence: "Account suspended pending investigation";
}
```

---

## Review System Architecture

### 1. Post-Booking Review Flow

```dart
// After booking is completed
class ReviewFlow {
  static Future<void> initiateReview(String bookingId) async {
    final booking = await getBooking(bookingId);

    // Wait 2 hours after event
    await Future.delayed(Duration(hours: 2));

    // Send review request to both parties
    await sendReviewRequest(
      to: booking.clientId,
      about: booking.supplierId,
      type: 'supplier',
    );

    await sendReviewRequest(
      to: booking.supplierId,
      about: booking.clientId,
      type: 'client',
    );

    // Reminder after 24 hours if not completed
    await scheduleReminder(bookingId, Duration(hours: 24));
  }
}
```

### 2. Review Guidelines

**What clients can review about suppliers:**
- ✅ Service quality
- ✅ Professionalism
- ✅ Punctuality
- ✅ Communication
- ✅ Value for money

**What suppliers can review about clients:**
- ✅ Communication
- ✅ Respect & courtesy
- ✅ Accuracy of event details
- ✅ Payment promptness
- ✅ Would work with again

### 3. Review Moderation

```dart
// Auto-filter for inappropriate content
Future<bool> moderateReview(ReviewModel review) async {
  // Check for profanity
  if (containsProfanity(review.comment)) {
    return false; // Reject
  }

  // Check for personal information
  if (containsPersonalInfo(review.comment)) {
    return false;
  }

  // Check for off-platform solicitation
  if (containsContactInfo(review.comment)) {
    return false;
  }

  // Flag suspicious patterns
  if (isLikelySuspicious(review)) {
    await flagForManualReview(review);
  }

  return true; // Approve
}
```

---

## Report Handling Workflow

### 1. Report Submission

```dart
class ReportSubmission {
  static Future<void> submitReport({
    required String reporterId,
    required String reportedId,
    required ReportCategory category,
    required String description,
    List<String>? evidence,
    String? bookingId,
  }) async {
    // Calculate severity
    final severity = calculateSeverity(category);

    // Create report
    final report = ReportModel(
      id: generateId(),
      reporterId: reporterId,
      reportedId: reportedId,
      category: category,
      severity: severity,
      description: description,
      evidence: evidence,
      bookingId: bookingId,
      status: ReportStatus.pending,
      createdAt: DateTime.now(),
    );

    await saveReport(report);

    // Auto-actions for high severity
    if (severity == ReportSeverity.critical) {
      await handleCriticalReport(report);
    }

    // Notify admins
    await notifyAdmins(report);
  }

  static Future<void> handleCriticalReport(ReportModel report) async {
    // Immediate suspension for serious violations
    if (report.category == ReportCategory.harassment ||
        report.category == ReportCategory.fraudulent) {
      await suspendUser(
        userId: report.reportedId,
        reason: 'Critical safety violation',
        duration: null, // Indefinite until review
      );
    }
  }
}
```

### 2. Investigation Process

```dart
class ReportInvestigation {
  static Future<void> investigate(String reportId) async {
    final report = await getReport(reportId);

    // Gather evidence
    final relatedBooking = await getBooking(report.bookingId);
    final chatHistory = await getChatHistory(report.reporterId, report.reportedId);
    final userHistory = await getSafetyScore(report.reportedId);
    final previousReports = await getPreviousReports(report.reportedId);

    // Analyze pattern
    final isPatternViolation = previousReports.length >= 2 &&
        previousReports.any((r) => r.category == report.category);

    // Determine action
    final action = determineAction(
      report: report,
      userHistory: userHistory,
      isPattern: isPatternViolation,
    );

    // Execute action
    await executeAction(report.reportedId, action);

    // Update report
    await updateReport(reportId, {
      'status': ReportStatus.resolved,
      'actionTaken': action,
      'resolvedAt': DateTime.now(),
    });

    // Notify reporter of outcome
    await notifyReporter(report.reporterId, action);
  }
}
```

---

## Badge & Verification System

### Verification Levels

```dart
enum VerificationLevel {
  none,           // No verification
  emailVerified,  // Email confirmed
  phoneVerified,  // Phone confirmed
  idVerified,     // Government ID checked
  businessVerified, // Business documents verified (suppliers)
  backgroundChecked, // Background check completed
}

class VerificationBadge {
  final String name;
  final String icon;
  final VerificationLevel level;
  final String description;
  final List<String> requirements;
}

// Available badges
const badges = [
  VerificationBadge(
    name: 'Verified',
    icon: '✓',
    level: VerificationLevel.idVerified,
    description: 'Identity verified',
    requirements: ['Government ID', 'Selfie photo'],
  ),
  VerificationBadge(
    name: 'Top Rated',
    icon: '⭐',
    level: VerificationLevel.none,
    description: '4.8+ rating with 50+ reviews',
    requirements: ['Rating ≥ 4.8', 'Reviews ≥ 50'],
  ),
  VerificationBadge(
    name: 'Reliable',
    icon: '🎯',
    level: VerificationLevel.none,
    description: '95%+ completion rate',
    requirements: ['Completion rate ≥ 95%', 'Bookings ≥ 20'],
  ),
  VerificationBadge(
    name: 'Responsive',
    icon: '⚡',
    level: VerificationLevel.none,
    description: 'Responds within 2 hours',
    requirements: ['Response rate ≥ 90%', 'Avg response < 2hrs'],
  ),
  VerificationBadge(
    name: 'Professional',
    icon: '💼',
    level: VerificationLevel.businessVerified,
    description: 'Registered business',
    requirements: ['Business license', 'Tax ID'],
  ),
];
```

---

## UI Components

### 1. Supplier Profile - Safety Info Display

```dart
class SupplierSafetyCard extends StatelessWidget {
  final SafetyScoreModel safetyScore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Overall rating
          Row(
            children: [
              Text('${safetyScore.overallRating.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.star, color: Colors.amber, size: 36),
              Text('(${safetyScore.totalReviews} avaliações)'),
            ],
          ),

          // Rating distribution
          RatingDistributionChart(safetyScore.ratingDistribution),

          // Badges
          Wrap(
            children: safetyScore.badges.map((badge) =>
              Chip(label: Text(badge), avatar: Icon(getBadgeIcon(badge)))
            ).toList(),
          ),

          // Key metrics
          MetricRow('Taxa de conclusão', '${(safetyScore.completionRate * 100).toInt()}%'),
          MetricRow('Taxa de resposta', '${(safetyScore.responseRate! * 100).toInt()}%'),
          MetricRow('Pontualidade', '${(safetyScore.onTimeRate! * 100).toInt()}%'),
        ],
      ),
    );
  }
}
```

### 2. Leave Review Screen

```dart
class LeaveReviewScreen extends StatefulWidget {
  final String bookingId;
  final String reviewedId;
  final String reviewedType; // 'supplier' or 'client'
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  double _rating = 0;
  String _comment = '';
  List<String> _selectedTags = [];

  // Tag options based on type
  final supplierTags = [
    'Profissional',
    'Pontual',
    'Qualidade excelente',
    'Boa comunicação',
    'Bom valor',
    'Criativo',
    'Flexível',
  ];

  final clientTags = [
    'Respeitoso',
    'Comunicativo',
    'Pagamento pontual',
    'Detalhes precisos',
    'Recomendaria',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Avaliar ${widget.reviewedType}')),
      body: Column(
        children: [
          // Star rating
          RatingBar(
            initialRating: _rating,
            onRatingUpdate: (rating) => setState(() => _rating = rating),
          ),

          // Tags
          Text('O que se destacou?'),
          Wrap(
            children: (widget.reviewedType == 'supplier' ? supplierTags : clientTags)
              .map((tag) => FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              ))
              .toList(),
          ),

          // Comment
          TextField(
            decoration: InputDecoration(
              labelText: 'Conte mais sobre sua experiência (opcional)',
              hintText: 'Seja específico e construtivo...',
            ),
            maxLines: 5,
            onChanged: (value) => _comment = value,
          ),

          // Submit
          ElevatedButton(
            onPressed: _submitReview,
            child: Text('Publicar Avaliação'),
          ),

          // Guidelines
          Text(
            'Por favor, seja honesto e respeitoso. Avaliações abusivas serão removidas.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      showError('Por favor, selecione uma classificação');
      return;
    }

    final review = ReviewModel(
      id: generateId(),
      bookingId: widget.bookingId,
      reviewerId: currentUserId,
      reviewerType: currentUserType,
      reviewedId: widget.reviewedId,
      reviewedType: widget.reviewedType,
      rating: _rating,
      comment: _comment.isEmpty ? null : _comment,
      tags: _selectedTags,
      serviceCategory: bookingCategory,
      serviceDate: bookingDate,
      isPublic: true,
      isFlagged: false,
      status: ReviewStatus.pending,
      createdAt: DateTime.now(),
    );

    await submitReview(review);
    Navigator.pop(context);
  }
}
```

### 3. Report User Screen

```dart
class ReportUserScreen extends StatefulWidget {
  final String reportedId;
  final String reportedType;
  final String? bookingId;
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  ReportCategory? _selectedCategory;
  String _description = '';
  List<File> _evidence = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reportar ${widget.reportedType}')),
      body: Column(
        children: [
          Text('O que aconteceu?', style: TextStyle(fontSize: 18)),

          // Category selection
          ...ReportCategory.values.map((category) =>
            RadioListTile<ReportCategory>(
              title: Text(getCategoryName(category)),
              subtitle: Text(getCategoryDescription(category)),
              value: category,
              groupValue: _selectedCategory,
              onChanged: (value) => setState(() => _selectedCategory = value),
            )
          ),

          // Description
          TextField(
            decoration: InputDecoration(
              labelText: 'Descreva o que aconteceu',
              hintText: 'Seja específico...',
            ),
            maxLines: 4,
            onChanged: (value) => _description = value,
          ),

          // Evidence upload
          ElevatedButton.icon(
            icon: Icon(Icons.attach_file),
            label: Text('Adicionar evidência (fotos, capturas de tela)'),
            onPressed: _pickEvidence,
          ),

          // Submit
          ElevatedButton(
            onPressed: _submitReport,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Enviar Relatório'),
          ),

          // Disclaimer
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Text(
              '⚠️ Relatórios falsos podem resultar em suspensão da sua conta. '
              'Por favor, reporte apenas violações legítimas.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      showError('Selecione uma categoria');
      return;
    }

    if (_description.length < 20) {
      showError('Por favor, forneça mais detalhes (mínimo 20 caracteres)');
      return;
    }

    await ReportSubmission.submitReport(
      reporterId: currentUserId,
      reportedId: widget.reportedId,
      category: _selectedCategory!,
      description: _description,
      evidence: _evidence.map((f) => f.path).toList(),
      bookingId: widget.bookingId,
    );

    showSuccess('Relatório enviado. Nossa equipe irá investigar.');
    Navigator.pop(context);
  }
}
```

---

## Implementation Steps

### Phase 1: Basic Review System (Week 1-2)
- [ ] Create ReviewModel and Firestore collection
- [ ] Implement post-booking review flow
- [ ] Build review submission UI
- [ ] Display reviews on profiles
- [ ] Calculate average ratings

### Phase 2: Safety Scoring (Week 3-4)
- [ ] Create SafetyScoreModel
- [ ] Implement automated score calculation
- [ ] Add rating thresholds and warnings
- [ ] Display safety metrics on profiles
- [ ] Implement badge system

### Phase 3: Report System (Week 5-6)
- [ ] Create ReportModel and UI
- [ ] Implement report submission
- [ ] Build admin investigation dashboard
- [ ] Add automated critical report handling
- [ ] Implement dispute resolution

### Phase 4: Automated Safety Rules (Week 7-8)
- [ ] Implement rating-based actions
- [ ] Add cancellation rate monitoring
- [ ] Build incident tracking system
- [ ] Create automated suspension logic
- [ ] Implement appeal process

### Phase 5: Verification & Badges (Week 9-10)
- [ ] ID verification flow
- [ ] Business verification for suppliers
- [ ] Automated badge awarding
- [ ] Background check integration
- [ ] Verification UI components

---

## Next Steps

Would you like me to:

1. **Implement the Review System first?**
   - Create all review models
   - Build review submission screens
   - Add review display to profiles

2. **Create the Report System?**
   - Build report models and screens
   - Implement admin dashboard
   - Add automated safety rules

3. **Build Safety Score calculation?**
   - Automated scoring system
   - Rating thresholds
   - Badge awarding logic

Let me know which part you'd like me to start implementing!

---

**Last Updated**: 2026-01-21
**Status**: 📋 Architecture Complete - Ready for Implementation
