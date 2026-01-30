import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Safety Score Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Safety Score Calculation
/// 2. Badge Eligibility
/// 3. Response Rate Calculation
/// 4. Category Ranking
/// 5. Score Components
/// 6. Score Updates
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Safety Score Calculation Tests', () {
    test('should calculate safety score with all components', () {
      // Safety score components:
      // - Profile completeness (15%)
      // - Verification status (20%)
      // - Response rate (15%)
      // - Rating score (25%)
      // - Cancellation rate (15%)
      // - Account age (10%)

      final profileScore = 0.90; // 90% complete
      final verificationScore = 1.0; // Fully verified
      final responseRate = 0.95; // 95% response rate
      final ratingScore = 0.96; // 4.8/5 = 0.96
      final cancellationScore = 0.98; // 2% cancellation = 0.98
      final accountAgeScore = 0.80; // 8 months / 10 months cap

      final safetyScore = (profileScore * 0.15) +
          (verificationScore * 0.20) +
          (responseRate * 0.15) +
          (ratingScore * 0.25) +
          (cancellationScore * 0.15) +
          (accountAgeScore * 0.10);

      // Actual calculation: 0.135 + 0.20 + 0.1425 + 0.24 + 0.147 + 0.08 = 0.9445
      expect(safetyScore, closeTo(0.9445, 0.001));
    });

    test('should store safety score in Firestore', () async {
      await fakeFirestore.collection('safety_scores').doc('supplier-123').set({
        'supplierId': 'supplier-123',
        'overallScore': 0.95,
        'components': {
          'profileCompleteness': 0.90,
          'verificationStatus': 1.0,
          'responseRate': 0.95,
          'ratingScore': 0.96,
          'cancellationScore': 0.98,
          'accountAgeScore': 0.80,
        },
        'badges': ['verified', 'fast_responder', 'top_rated'],
        'lastCalculatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('safety_scores').doc('supplier-123').get();
      expect(doc.data()?['overallScore'], 0.95);
      expect((doc.data()?['badges'] as List).length, 3);
    });

    test('should calculate minimum safety score for new supplier', () {
      // New supplier with minimal data
      final profileScore = 0.30; // 30% complete
      final verificationScore = 0.0; // Not verified
      final responseRate = 0.0; // No messages yet
      final ratingScore = 0.0; // No reviews
      final cancellationScore = 1.0; // No cancellations
      final accountAgeScore = 0.10; // 1 month

      final safetyScore = (profileScore * 0.15) +
          (verificationScore * 0.20) +
          (responseRate * 0.15) +
          (ratingScore * 0.25) +
          (cancellationScore * 0.15) +
          (accountAgeScore * 0.10);

      expect(safetyScore, closeTo(0.205, 0.001));
    });
  });

  group('Profile Completeness Tests', () {
    test('should calculate profile completeness score', () {
      // Required fields and weights:
      // - Name: 10%
      // - Photo: 15%
      // - Description: 15%
      // - Category: 10%
      // - Services: 10%
      // - Location: 10%
      // - Packages: 15%
      // - Portfolio: 15%

      final fields = {
        'name': true, // 10%
        'photo': true, // 15%
        'description': true, // 15%
        'category': true, // 10%
        'services': true, // 10%
        'location': true, // 10%
        'packages': true, // 15%
        'portfolio': false, // 0% (missing)
      };

      final weights = {
        'name': 0.10,
        'photo': 0.15,
        'description': 0.15,
        'category': 0.10,
        'services': 0.10,
        'location': 0.10,
        'packages': 0.15,
        'portfolio': 0.15,
      };

      var completeness = 0.0;
      fields.forEach((field, completed) {
        if (completed) {
          completeness += weights[field]!;
        }
      });

      expect(completeness, 0.85);
    });
  });

  group('Verification Status Tests', () {
    test('should calculate verification score', () {
      // Verification levels:
      // - Email verified: 0.25
      // - Phone verified: 0.25
      // - ID verified: 0.25
      // - Business verified: 0.25

      expect(_calculateVerificationScore(email: true, phone: false, id: false, business: false), 0.25);
      expect(_calculateVerificationScore(email: true, phone: true, id: false, business: false), 0.50);
      expect(_calculateVerificationScore(email: true, phone: true, id: true, business: false), 0.75);
      expect(_calculateVerificationScore(email: true, phone: true, id: true, business: true), 1.0);
    });
  });

  group('Response Rate Calculation Tests', () {
    test('should calculate response rate from conversations', () async {
      // Supplier has 10 conversations
      // Responded to 8 within 24 hours
      // Responded to 1 after 24 hours
      // Never responded to 1

      final totalConversations = 10;
      final respondedWithin24h = 8;
      final respondedLate = 1;
      // 1 conversation never responded (implicit from total - responded)

      // Response rate = (responded within 24h + late * 0.5) / total
      final responseRate = (respondedWithin24h + (respondedLate * 0.5)) / totalConversations;

      expect(responseRate, 0.85);
    });

    test('should track quick response rate', () async {
      // Messages and response times
      final responseTimes = [5, 15, 30, 45, 60, 90, 120, 180]; // minutes

      // Quick response = under 60 minutes
      final quickResponses = responseTimes.where((t) => t <= 60).length;
      final quickResponseRate = quickResponses / responseTimes.length;

      expect(quickResponseRate, 0.625); // 5 out of 8

      await fakeFirestore.collection('supplier_stats').doc('supplier-123').set({
        'totalResponses': responseTimes.length,
        'quickResponses': quickResponses,
        'quickResponseRate': quickResponseRate,
        'averageResponseTime': responseTimes.reduce((a, b) => a + b) ~/ responseTimes.length,
      });

      final stats = await fakeFirestore.collection('supplier_stats').doc('supplier-123').get();
      expect(stats.data()?['quickResponseRate'], 0.625);
    });
  });

  group('Rating Score Tests', () {
    test('should convert rating to normalized score', () {
      // Rating is 1-5, normalize to 0-1
      expect(_normalizeRating(5.0), 1.0);
      expect(_normalizeRating(4.5), 0.875);
      expect(_normalizeRating(4.0), 0.75);
      expect(_normalizeRating(3.5), 0.625);
      expect(_normalizeRating(3.0), 0.5);
      expect(_normalizeRating(1.0), 0.0);
    });

    test('should apply weight based on review count', () {
      // More reviews = more confidence in rating
      // Weight formula: min(reviewCount / 50, 1.0)

      expect(_getReviewCountWeight(0), 0.0);
      expect(_getReviewCountWeight(10), 0.2);
      expect(_getReviewCountWeight(25), 0.5);
      expect(_getReviewCountWeight(50), 1.0);
      expect(_getReviewCountWeight(100), 1.0); // Capped at 1.0
    });

    test('should calculate weighted rating score', () {
      // Supplier A: 5.0 rating, 5 reviews
      // Supplier B: 4.5 rating, 50 reviews

      final supplierA = _normalizeRating(5.0) * _getReviewCountWeight(5);
      final supplierB = _normalizeRating(4.5) * _getReviewCountWeight(50);

      expect(supplierA, 0.1); // 1.0 * 0.1
      expect(supplierB, 0.875); // 0.875 * 1.0

      // Supplier B has higher weighted score despite lower rating
      expect(supplierB, greaterThan(supplierA));
    });
  });

  group('Cancellation Score Tests', () {
    test('should calculate cancellation score', () {
      // Cancellation score = 1 - (cancellations / totalBookings)
      // Penalize higher cancellation rates

      expect(_calculateCancellationScore(0, 100), 1.0); // No cancellations
      expect(_calculateCancellationScore(5, 100), 0.95); // 5% cancellation
      expect(_calculateCancellationScore(10, 100), 0.90); // 10% cancellation
      expect(_calculateCancellationScore(25, 100), 0.75); // 25% cancellation
      expect(_calculateCancellationScore(50, 100), 0.50); // 50% cancellation
    });

    test('should only count supplier-initiated cancellations', () async {
      await fakeFirestore.collection('bookings').add({
        'supplierId': 'supplier-123',
        'status': 'cancelled',
        'cancelledBy': 'supplier',
      });
      await fakeFirestore.collection('bookings').add({
        'supplierId': 'supplier-123',
        'status': 'cancelled',
        'cancelledBy': 'client', // Not counted
      });
      await fakeFirestore.collection('bookings').add({
        'supplierId': 'supplier-123',
        'status': 'completed',
      });

      final supplierCancellations = await fakeFirestore
          .collection('bookings')
          .where('supplierId', isEqualTo: 'supplier-123')
          .where('status', isEqualTo: 'cancelled')
          .where('cancelledBy', isEqualTo: 'supplier')
          .get();

      expect(supplierCancellations.docs.length, 1);
    });
  });

  group('Account Age Score Tests', () {
    test('should calculate account age score', () {
      // Account age score capped at 12 months
      // Score = min(monthsActive / 12, 1.0)

      expect(_calculateAccountAgeScore(0), 0.0);
      expect(_calculateAccountAgeScore(3), 0.25);
      expect(_calculateAccountAgeScore(6), 0.5);
      expect(_calculateAccountAgeScore(12), 1.0);
      expect(_calculateAccountAgeScore(24), 1.0); // Capped
    });
  });

  group('Badge Eligibility Tests', () {
    test('should check verified badge eligibility', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'emailVerified': true,
        'phoneVerified': true,
        'idVerified': true,
        'businessVerified': true,
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      final isFullyVerified = doc.data()?['emailVerified'] == true &&
          doc.data()?['phoneVerified'] == true &&
          doc.data()?['idVerified'] == true &&
          doc.data()?['businessVerified'] == true;

      expect(isFullyVerified, true);
    });

    test('should check fast responder badge eligibility', () async {
      await fakeFirestore.collection('supplier_stats').doc('supplier-123').set({
        'responseRate': 0.98,
        'averageResponseTime': 20, // minutes
      });

      final stats = await fakeFirestore.collection('supplier_stats').doc('supplier-123').get();
      final isEligible = stats.data()?['responseRate'] >= 0.95 &&
          stats.data()?['averageResponseTime'] <= 30;

      expect(isEligible, true);
    });

    test('should check top rated badge eligibility', () async {
      await fakeFirestore.collection('suppliers').doc('supplier-123').set({
        'rating': 4.8,
        'reviewCount': 30,
      });

      final doc = await fakeFirestore.collection('suppliers').doc('supplier-123').get();
      final isEligible = doc.data()?['rating'] >= 4.8 && doc.data()?['reviewCount'] >= 25;

      expect(isEligible, true);
    });

    test('should check expert badge eligibility (top 5% in category)', () async {
      // Create suppliers in same category
      for (int i = 0; i < 20; i++) {
        await fakeFirestore.collection('suppliers').add({
          'category': 'fotografia',
          'rating': 3.5 + (i * 0.07), // Ratings from 3.5 to 4.83
          'reviewCount': 10 + i,
          'isActive': true,
        });
      }

      // Get all suppliers in category sorted by rating
      final suppliers = await fakeFirestore
          .collection('suppliers')
          .where('category', isEqualTo: 'fotografia')
          .orderBy('rating', descending: true)
          .get();

      // Top 5% = 1 supplier out of 20
      final top5PercentCount = (suppliers.docs.length * 0.05).ceil();
      final topSuppliers = suppliers.docs.take(top5PercentCount);

      expect(topSuppliers.length, 1);
      expect(topSuppliers.first.data()['rating'], greaterThanOrEqualTo(4.8));
    });

    test('should check newcomer badge eligibility', () {
      final accountCreatedAt = DateTime.now().subtract(const Duration(days: 25));
      final daysSinceCreation = DateTime.now().difference(accountCreatedAt).inDays;

      // Newcomer = account less than 30 days old
      final isNewcomer = daysSinceCreation < 30;

      expect(isNewcomer, true);
    });
  });

  group('Category Ranking Tests', () {
    test('should calculate category ranking score', () async {
      // Create suppliers with different scores
      final suppliersData = [
        {'id': 's1', 'rating': 4.9, 'reviewCount': 100, 'responseRate': 0.98},
        {'id': 's2', 'rating': 4.5, 'reviewCount': 50, 'responseRate': 0.90},
        {'id': 's3', 'rating': 4.8, 'reviewCount': 75, 'responseRate': 0.95},
        {'id': 's4', 'rating': 4.2, 'reviewCount': 25, 'responseRate': 0.85},
        {'id': 's5', 'rating': 4.7, 'reviewCount': 60, 'responseRate': 0.92},
      ];

      // Calculate composite ranking score
      // Score = (rating * 0.4) + (normalizedReviewCount * 0.3) + (responseRate * 0.3)
      final rankings = suppliersData.map((s) {
        final normalizedReviews = (s['reviewCount'] as int) / 100;
        final score = ((s['rating'] as double) / 5 * 0.4) +
            (normalizedReviews * 0.3) +
            ((s['responseRate'] as double) * 0.3);
        return {'id': s['id'], 'score': score};
      }).toList();

      rankings.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      expect(rankings[0]['id'], 's1'); // Highest score
      expect(rankings[4]['id'], 's4'); // Lowest score
    });

    test('should determine percentile rank', () async {
      // Supplier with rank 5 out of 100 suppliers
      final rank = 5;
      final totalSuppliers = 100;
      final percentileRank = ((totalSuppliers - rank) / totalSuppliers) * 100;

      expect(percentileRank, 95.0); // Top 5%
    });
  });

  group('Score Update Tests', () {
    test('should update safety score on new review', () async {
      await fakeFirestore.collection('safety_scores').doc('supplier-123').set({
        'overallScore': 0.85,
        'components': {
          'ratingScore': 0.80,
        },
        'lastCalculatedAt': Timestamp.now(),
      });

      // New review comes in, rating improved
      await fakeFirestore.collection('safety_scores').doc('supplier-123').update({
        'components.ratingScore': 0.85,
        'overallScore': 0.87, // Recalculated
        'lastCalculatedAt': Timestamp.now(),
      });

      final doc = await fakeFirestore.collection('safety_scores').doc('supplier-123').get();
      expect(doc.data()?['overallScore'], 0.87);
    });

    test('should track score history', () async {
      await fakeFirestore
          .collection('safety_scores')
          .doc('supplier-123')
          .collection('history')
          .add({
        'score': 0.85,
        'timestamp': Timestamp.now(),
      });

      await fakeFirestore
          .collection('safety_scores')
          .doc('supplier-123')
          .collection('history')
          .add({
        'score': 0.87,
        'timestamp': Timestamp.now(),
      });

      final history = await fakeFirestore
          .collection('safety_scores')
          .doc('supplier-123')
          .collection('history')
          .orderBy('timestamp', descending: true)
          .get();

      expect(history.docs.length, 2);
      expect(history.docs[0].data()['score'], 0.87); // Latest
    });
  });
}

// Helper functions

double _calculateVerificationScore({
  required bool email,
  required bool phone,
  required bool id,
  required bool business,
}) {
  var score = 0.0;
  if (email) score += 0.25;
  if (phone) score += 0.25;
  if (id) score += 0.25;
  if (business) score += 0.25;
  return score;
}

double _normalizeRating(double rating) {
  return (rating - 1) / 4; // Convert 1-5 to 0-1
}

double _getReviewCountWeight(int reviewCount) {
  if (reviewCount <= 0) return 0.0;
  return (reviewCount / 50).clamp(0.0, 1.0);
}

double _calculateCancellationScore(int cancellations, int totalBookings) {
  if (totalBookings == 0) return 1.0;
  return 1.0 - (cancellations / totalBookings);
}

double _calculateAccountAgeScore(int monthsActive) {
  return (monthsActive / 12).clamp(0.0, 1.0);
}
