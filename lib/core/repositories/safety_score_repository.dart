import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/safety_score_model.dart';
import '../models/report_model.dart';
import '../models/review_model.dart';
import 'notification_repository.dart';

class SafetyScoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationRepository _notificationRepository = NotificationRepository();

  // ==================== THRESHOLDS ====================

  // Rating thresholds
  static const double suspensionRatingThreshold = 3.0;
  static const double probationRatingThreshold = 3.5;
  static const double warningRatingThreshold = 4.0;
  static const double topRatedThreshold = 4.8;
  static const int topRatedMinReviews = 50;

  // Report thresholds
  static const int criticalReportThreshold = 1;
  static const int highReportThreshold = 3;
  static const int warningReportThreshold = 5;
  static const int suspensionReportThreshold = 10;

  // Behavior thresholds
  static const double highCancellationThreshold = 0.40;
  static const double warningCancellationThreshold = 0.30;
  static const double alertCancellationThreshold = 0.20;
  static const double lowCompletionThreshold = 0.60;
  static const double warningCompletionThreshold = 0.70;
  static const double alertCompletionThreshold = 0.80;

  // Badge thresholds
  static const double reliableCompletionThreshold = 0.95;
  static const double responsiveRateThreshold = 0.90;
  static const int professionalMinBookings = 100;

  // ==================== CALCULATE SAFETY SCORE ====================

  /// Calculate and update safety score for a user
  Future<SafetyScoreModel?> calculateSafetyScore(String userId) async {
    try {
      debugPrint('📊 Calculating safety score for user: $userId');

      // Get user type (supplier or client)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('❌ User not found: $userId');
        return null;
      }
      final userType = userDoc.data()?['userType'] as String? ?? 'client';

      // Gather all metrics
      final reviewStats = await _getReviewStats(userId);
      final reportStats = await _getReportStats(userId);
      final behaviorStats = await _getBehaviorStats(userId);

      // Calculate base safety score (0-100)
      final score = _computeSafetyScore(
        reviewStats: reviewStats,
        reportStats: reportStats,
        behaviorStats: behaviorStats,
      );

      // Determine safety status based on thresholds
      final status = _determineSafetyStatus(
        rating: reviewStats['rating'] ?? 0.0,
        totalReports: reportStats['total'] ?? 0,
        criticalReports: reportStats['critical'] ?? 0,
        cancellationRate: behaviorStats['cancellation'] ?? 0.0,
        completionRate: behaviorStats['completion'] ?? 0.0,
      );

      // Check for eligible badges
      final eligibleBadges = await _checkBadgeEligibility(
        userId: userId,
        userType: userType,
        rating: reviewStats['rating'] ?? 0.0,
        totalReviews: reviewStats['total'] ?? 0,
        completionRate: behaviorStats['completion'] ?? 0.0,
        responseRate: behaviorStats['response'] ?? 0.0,
        totalBookings: behaviorStats['totalBookings'] ?? 0,
        behaviorReports: reportStats['behavior'] ?? 0,
      );

      // Get current safety score to preserve warning history
      final currentScore = await getSafetyScore(userId);

      final now = DateTime.now();
      final safetyScore = SafetyScoreModel(
        userId: userId,
        userType: userType,
        overallRating: reviewStats['rating'] ?? 0.0,
        totalReviews: reviewStats['total'] ?? 0,
        totalReports: reportStats['total'] ?? 0,
        criticalReports: reportStats['critical'] ?? 0,
        highReports: reportStats['high'] ?? 0,
        resolvedReports: reportStats['resolved'] ?? 0,
        dismissedReports: reportStats['dismissed'] ?? 0,
        completionRate: behaviorStats['completion'] ?? 0.0,
        cancellationRate: behaviorStats['cancellation'] ?? 0.0,
        responseRate: behaviorStats['response'] ?? 0.0,
        onTimeRate: behaviorStats['onTime'] ?? 0.0,
        status: status,
        badges: eligibleBadges,
        lastWarningDate: currentScore?.lastWarningDate,
        warningCount: currentScore?.warningCount ?? 0,
        probationStartDate: status == SafetyStatus.probation
            ? (currentScore?.probationStartDate ?? now)
            : null,
        suspensionStartDate: status == SafetyStatus.suspended
            ? (currentScore?.suspensionStartDate ?? now)
            : null,
        suspensionEndDate: currentScore?.suspensionEndDate,
        safetyScore: score,
        lastCalculated: now,
        createdAt: currentScore?.createdAt ?? now,
        updatedAt: now,
      );

      // Save to Firestore
      await _firestore
          .collection('safetyScores')
          .doc(userId)
          .set(safetyScore.toFirestore());

      debugPrint('✅ Safety score calculated: $score for user $userId');
      return safetyScore;
    } catch (e) {
      debugPrint('❌ Error calculating safety score: $e');
      return null;
    }
  }

  /// Get review statistics for a user
  Future<Map<String, dynamic>> _getReviewStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('reviewedId', isEqualTo: userId)
          .where('status', isEqualTo: ReviewStatus.approved.name)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'rating': 0.0, 'total': 0};
      }

      final reviews = snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();

      final totalRating = reviews.fold<double>(
        0.0,
        (sum, review) => sum + review.rating,
      );
      final avgRating = totalRating / reviews.length;

      return {
        'rating': avgRating,
        'total': reviews.length,
      };
    } catch (e) {
      debugPrint('❌ Error fetching review stats: $e');
      return {'rating': 0.0, 'total': 0};
    }
  }

  /// Get report statistics for a user
  Future<Map<String, dynamic>> _getReportStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reportedId', isEqualTo: userId)
          .get();

      final reports = snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();

      final criticalCount =
          reports.where((r) => r.severity == ReportSeverity.critical).length;
      final highCount =
          reports.where((r) => r.severity == ReportSeverity.high).length;
      final resolvedCount =
          reports.where((r) => r.status == ReportStatus.resolved).length;
      final dismissedCount =
          reports.where((r) => r.status == ReportStatus.dismissed).length;

      // Count behavior-related reports
      final behaviorCategories = [
        ReportCategory.harassment,
        ReportCategory.discrimination,
        ReportCategory.unprofessional,
        ReportCategory.threatening,
      ];
      final behaviorReports = reports
          .where((r) => behaviorCategories.contains(r.category))
          .length;

      return {
        'total': reports.length,
        'critical': criticalCount,
        'high': highCount,
        'resolved': resolvedCount,
        'dismissed': dismissedCount,
        'behavior': behaviorReports,
      };
    } catch (e) {
      debugPrint('❌ Error fetching report stats: $e');
      return {
        'total': 0,
        'critical': 0,
        'high': 0,
        'resolved': 0,
        'dismissed': 0,
        'behavior': 0,
      };
    }
  }

  /// Get behavior statistics from bookings
  Future<Map<String, dynamic>> _getBehaviorStats(String userId) async {
    try {
      // Get all bookings for user (as client or supplier)
      final clientBookings = await _firestore
          .collection('bookings')
          .where('clientId', isEqualTo: userId)
          .get();

      final supplierBookings = await _firestore
          .collection('bookings')
          .where('supplierId', isEqualTo: userId)
          .get();

      final allBookings = [...clientBookings.docs, ...supplierBookings.docs];

      if (allBookings.isEmpty) {
        return {
          'completion': 0.0,
          'cancellation': 0.0,
          'response': 0.0,
          'onTime': 0.0,
          'totalBookings': 0,
        };
      }

      int completedCount = 0;
      int cancelledCount = 0;
      int onTimeCount = 0;

      for (final doc in allBookings) {
        final data = doc.data();
        final status = data['status'] as String?;

        if (status == 'completed') completedCount++;
        if (status == 'cancelled') cancelledCount++;

        // Check on-time (if booking has startTime and actualStartTime)
        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        final actualStartTime =
            (data['actualStartTime'] as Timestamp?)?.toDate();
        if (startTime != null && actualStartTime != null) {
          if (actualStartTime.isBefore(startTime.add(const Duration(minutes: 15)))) {
            onTimeCount++;
          }
        }
      }

      final total = allBookings.length;
      final completionRate = completedCount / total;
      final cancellationRate = cancelledCount / total;
      final onTimeRate = total > 0 ? onTimeCount / total : 0.0;

      // Calculate response rate from chat messages
      final responseRate = await _calculateResponseRate(userId);

      return {
        'completion': completionRate,
        'cancellation': cancellationRate,
        'response': responseRate,
        'onTime': onTimeRate,
        'totalBookings': total,
      };
    } catch (e) {
      debugPrint('❌ Error fetching behavior stats: $e');
      return {
        'completion': 0.0,
        'cancellation': 0.0,
        'response': 0.0,
        'onTime': 0.0,
        'totalBookings': 0,
      };
    }
  }

  /// Calculate response rate from chat messages
  /// Measures how often and quickly a user responds to messages
  Future<double> _calculateResponseRate(String userId) async {
    try {
      // Get conversations where user is a participant
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .limit(50)
          .get();

      if (conversationsSnapshot.docs.isEmpty) {
        return 0.85; // Default rate for users without chat history
      }

      int totalMessagesReceived = 0;
      int messagesRespondedTo = 0;
      int quickResponses = 0; // Responded within 1 hour

      for (final convDoc in conversationsSnapshot.docs) {
        final conversationId = convDoc.id;

        // Get messages in this conversation
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('createdAt', descending: false)
            .limit(100)
            .get();

        final messages = messagesSnapshot.docs;

        for (int i = 0; i < messages.length; i++) {
          final message = messages[i].data();
          final senderId = message['senderId'] as String?;

          // If message was sent TO this user (not by them)
          if (senderId != null && senderId != userId) {
            totalMessagesReceived++;

            // Check if user responded (next message from them)
            for (int j = i + 1; j < messages.length; j++) {
              final nextMessage = messages[j].data();
              final nextSenderId = nextMessage['senderId'] as String?;

              if (nextSenderId == userId) {
                messagesRespondedTo++;

                // Check response time
                final messageTime = (message['createdAt'] as Timestamp?)?.toDate();
                final responseTime = (nextMessage['createdAt'] as Timestamp?)?.toDate();

                if (messageTime != null && responseTime != null) {
                  final responseDelay = responseTime.difference(messageTime);
                  if (responseDelay.inHours <= 1) {
                    quickResponses++;
                  }
                }
                break; // Found response, move to next received message
              }
            }
          }
        }
      }

      if (totalMessagesReceived == 0) {
        return 0.85; // Default rate
      }

      // Calculate response rate (weighted: 70% responded, 30% quick response)
      final responseRatio = messagesRespondedTo / totalMessagesReceived;
      final quickResponseRatio = messagesRespondedTo > 0
          ? quickResponses / messagesRespondedTo
          : 0.0;

      final responseRate = (responseRatio * 0.7) + (quickResponseRatio * 0.3);

      debugPrint('📊 Response rate for $userId: ${(responseRate * 100).toStringAsFixed(1)}%');
      return responseRate.clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('❌ Error calculating response rate: $e');
      return 0.85; // Default fallback
    }
  }

  /// Compute safety score (0-100) based on all metrics
  double _computeSafetyScore({
    required Map<String, dynamic> reviewStats,
    required Map<String, dynamic> reportStats,
    required Map<String, dynamic> behaviorStats,
  }) {
    // Start with 100 points
    double score = 100.0;

    // Deduct for low rating (max -30 points)
    final rating = reviewStats['rating'] ?? 0.0;
    if (rating < 5.0 && reviewStats['total'] >= 5) {
      final ratingPenalty = (5.0 - rating) * 6; // -6 points per star below 5
      score -= ratingPenalty;
    }

    // Deduct for reports (max -40 points)
    final criticalReports = reportStats['critical'] ?? 0;
    final highReports = reportStats['high'] ?? 0;
    final reportPenalty = (criticalReports * 20) + (highReports * 10);
    score -= reportPenalty.clamp(0, 40);

    // Deduct for cancellations (max -15 points)
    final cancellationRate = behaviorStats['cancellation'] ?? 0.0;
    if (cancellationRate > 0.1) {
      final cancellationPenalty = (cancellationRate - 0.1) * 100;
      score -= cancellationPenalty.clamp(0, 15);
    }

    // Deduct for low completion rate (max -15 points)
    final completionRate = behaviorStats['completion'] ?? 0.0;
    if (completionRate < 0.9) {
      final completionPenalty = (0.9 - completionRate) * 100;
      score -= completionPenalty.clamp(0, 15);
    }

    return score.clamp(0, 100);
  }

  /// Determine safety status based on thresholds
  SafetyStatus _determineSafetyStatus({
    required double rating,
    required int totalReports,
    required int criticalReports,
    required double cancellationRate,
    required double completionRate,
  }) {
    // Suspension conditions
    if (rating < suspensionRatingThreshold ||
        criticalReports >= criticalReportThreshold ||
        cancellationRate > highCancellationThreshold ||
        completionRate < lowCompletionThreshold ||
        totalReports >= suspensionReportThreshold) {
      return SafetyStatus.suspended;
    }

    // Probation conditions
    if (rating < probationRatingThreshold ||
        totalReports >= highReportThreshold ||
        cancellationRate > warningCancellationThreshold ||
        completionRate < warningCompletionThreshold) {
      return SafetyStatus.probation;
    }

    // Warning conditions
    if (rating < warningRatingThreshold ||
        totalReports >= warningReportThreshold ||
        cancellationRate > alertCancellationThreshold ||
        completionRate < alertCompletionThreshold) {
      return SafetyStatus.warning;
    }

    return SafetyStatus.safe;
  }

  /// Check badge eligibility
  Future<List<Badge>> _checkBadgeEligibility({
    required String userId,
    required String userType,
    required double rating,
    required int totalReviews,
    required double completionRate,
    required double responseRate,
    required int totalBookings,
    required int behaviorReports,
  }) async {
    final badges = <Badge>[];
    final now = DateTime.now();

    // Top Rated badge
    if (rating >= topRatedThreshold && totalReviews >= topRatedMinReviews) {
      badges.add(Badge(type: BadgeType.topRated, awardedAt: now));
    }

    // Reliable badge
    if (completionRate >= reliableCompletionThreshold && totalBookings >= 20) {
      badges.add(Badge(type: BadgeType.reliable, awardedAt: now));
    }

    // Responsive badge
    if (responseRate >= responsiveRateThreshold && totalBookings >= 10) {
      badges.add(Badge(type: BadgeType.responsive, awardedAt: now));
    }

    // Professional badge
    if (behaviorReports == 0 && totalBookings >= professionalMinBookings) {
      badges.add(Badge(type: BadgeType.professional, awardedAt: now));
    }

    // Verified badge (check if user has verified identity)
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final isVerified = userDoc.data()?['isVerified'] as bool? ?? false;
    if (isVerified) {
      badges.add(Badge(type: BadgeType.verified, awardedAt: now));
    }

    // Expert badge (top 5% in category for suppliers)
    if (userType == 'supplier') {
      final isExpert = await _checkExpertBadgeEligibility(userId, rating, totalReviews);
      if (isExpert) {
        badges.add(Badge(type: BadgeType.expert, awardedAt: now));
      }
    }

    return badges;
  }

  /// Check if supplier is eligible for Expert badge (top 5% in their category)
  Future<bool> _checkExpertBadgeEligibility(
    String userId,
    double rating,
    int totalReviews,
  ) async {
    try {
      // Minimum requirements for expert badge
      if (rating < 4.5 || totalReviews < 25) {
        return false;
      }

      // Get supplier's category
      final supplierDoc = await _firestore.collection('suppliers').doc(userId).get();
      if (!supplierDoc.exists) return false;

      final supplierData = supplierDoc.data()!;
      final category = supplierData['category'] as String?;
      if (category == null) return false;

      // Get all suppliers in the same category with ratings
      final categorySuppliers = await _firestore
          .collection('suppliers')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .get();

      if (categorySuppliers.docs.length < 10) {
        // Not enough suppliers in category for meaningful ranking
        // Award expert badge if they have excellent stats
        return rating >= 4.8 && totalReviews >= 30;
      }

      // Calculate ranking score for each supplier
      final rankings = <Map<String, dynamic>>[];

      for (final doc in categorySuppliers.docs) {
        final supplierId = doc.id;

        // Get supplier's rating
        final reviewsSnapshot = await _firestore
            .collection('reviews')
            .where('reviewedId', isEqualTo: supplierId)
            .where('status', isEqualTo: 'approved')
            .get();

        if (reviewsSnapshot.docs.isEmpty) continue;

        double totalRating = 0;
        for (final reviewDoc in reviewsSnapshot.docs) {
          totalRating += (reviewDoc.data()['rating'] as num?)?.toDouble() ?? 0;
        }
        final avgRating = totalRating / reviewsSnapshot.docs.length;
        final reviewCount = reviewsSnapshot.docs.length;

        // Calculate ranking score (weighted: 60% rating, 40% review count normalized)
        // Normalize review count: log scale to prevent outliers from dominating
        final normalizedReviews = reviewCount > 0
            ? (reviewCount / 100).clamp(0.0, 1.0) // Cap at 100 reviews
            : 0.0;
        final rankingScore = (avgRating / 5.0 * 0.6) + (normalizedReviews * 0.4);

        rankings.add({
          'supplierId': supplierId,
          'rating': avgRating,
          'reviewCount': reviewCount,
          'rankingScore': rankingScore,
        });
      }

      // Sort by ranking score (highest first)
      rankings.sort((a, b) =>
          (b['rankingScore'] as double).compareTo(a['rankingScore'] as double));

      // Find user's position
      final userPosition = rankings.indexWhere((r) => r['supplierId'] == userId);

      if (userPosition == -1) return false;

      // Check if in top 5%
      final top5PercentThreshold = (rankings.length * 0.05).ceil();
      final isTop5Percent = userPosition < top5PercentThreshold;

      debugPrint('📊 Category ranking for $userId: '
          'Position ${userPosition + 1}/${rankings.length} '
          '(Top 5% threshold: $top5PercentThreshold) - '
          'Expert eligible: $isTop5Percent');

      return isTop5Percent;
    } catch (e) {
      debugPrint('❌ Error checking expert badge eligibility: $e');
      return false;
    }
  }

  // ==================== GET SAFETY SCORE ====================

  /// Get safety score for a user
  ///
  /// @deprecated UI-FIRST VIOLATION: safetyScores collection is ADMIN/BACKEND-ONLY.
  /// Client/Supplier cannot read from this collection.
  /// Use this only in admin screens or Cloud Functions.
  @Deprecated('safetyScores is admin-only. Do not use in client/supplier UI.')
  Future<SafetyScoreModel?> getSafetyScore(String userId) async {
    try {
      final doc = await _firestore.collection('safetyScores').doc(userId).get();
      if (doc.exists) {
        return SafetyScoreModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // Gracefully handle permission errors (expected for client/supplier)
      debugPrint('⚠️ getSafetyScore failed (admin-only collection): $e');
      return null;
    }
  }

  // ==================== AUTOMATED ACTIONS ====================

  /// Check thresholds and trigger automated actions
  Future<List<String>> checkThresholdsAndTriggerActions(String userId) async {
    final actions = <String>[];

    try {
      final score = await calculateSafetyScore(userId);
      if (score == null) return actions;

      // Issue warning if needed
      if (score.status == SafetyStatus.warning &&
          score.lastWarningDate == null) {
        await _issueWarning(userId, 'Métricas de segurança abaixo do esperado');
        actions.add('warning_issued');
      }

      // Apply probation if needed
      if (score.status == SafetyStatus.probation &&
          score.probationStartDate == null) {
        await _applyProbation(userId, 'Múltiplas violações detectadas');
        actions.add('probation_applied');
      }

      // Suspend account if needed
      if (score.status == SafetyStatus.suspended &&
          score.suspensionStartDate == null) {
        await _suspendAccount(
          userId,
          'Violações graves das diretrizes da plataforma',
          null, // Indefinite suspension
        );
        actions.add('account_suspended');
      }

      return actions;
    } catch (e) {
      debugPrint('❌ Error checking thresholds: $e');
      return actions;
    }
  }

  /// Issue warning to user
  Future<void> _issueWarning(String userId, String reason) async {
    try {
      final score = await getSafetyScore(userId);
      final now = DateTime.now();

      await _firestore.collection('safetyScores').doc(userId).update({
        'lastWarningDate': Timestamp.fromDate(now),
        'warningCount': (score?.warningCount ?? 0) + 1,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Send warning notification to user
      await _notificationRepository.createNotification(
        userId: userId,
        title: 'Aviso de Segurança',
        body: 'A sua conta recebeu um aviso. Por favor, reveja as políticas da plataforma para evitar restrições.',
        type: 'safety_warning',
        data: {'warningCount': (score?.warningCount ?? 0) + 1},
      );

      debugPrint('⚠️ Warning issued to user: $userId');
    } catch (e) {
      debugPrint('❌ Error issuing warning: $e');
    }
  }

  /// Apply probation to user
  Future<void> _applyProbation(String userId, String reason) async {
    try {
      final now = DateTime.now();

      await _firestore.collection('safetyScores').doc(userId).update({
        'status': SafetyStatus.probation.name,
        'probationStartDate': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Send probation notification to user
      await _notificationRepository.createNotification(
        userId: userId,
        title: 'Conta em Período Probatório',
        body: 'A sua conta foi colocada em período probatório devido a: $reason. Por favor, melhore o seu comportamento na plataforma.',
        type: 'safety_probation',
        data: {'reason': reason, 'startDate': now.toIso8601String()},
      );

      debugPrint('🔒 Probation applied to user: $userId');
    } catch (e) {
      debugPrint('❌ Error applying probation: $e');
    }
  }

  /// Suspend user account
  Future<void> _suspendAccount(
    String userId,
    String reason,
    Duration? duration,
  ) async {
    try {
      final now = DateTime.now();
      final endDate = duration != null ? now.add(duration) : null;

      await _firestore.collection('safetyScores').doc(userId).update({
        'status': SafetyStatus.suspended.name,
        'suspensionStartDate': Timestamp.fromDate(now),
        'suspensionEndDate':
            endDate != null ? Timestamp.fromDate(endDate) : null,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Disable user account in users collection
      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'suspendedAt': Timestamp.fromDate(now),
        'suspensionReason': reason,
      });

      // Send suspension notification to user
      final durationText = duration != null
          ? 'por ${duration.inDays} dias'
          : 'permanentemente';
      await _notificationRepository.createNotification(
        userId: userId,
        title: 'Conta Suspensa',
        body: 'A sua conta foi suspensa $durationText devido a: $reason. Contacte o suporte para mais informações.',
        type: 'safety_suspension',
        data: {
          'reason': reason,
          'startDate': now.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
          'isPermanent': duration == null,
        },
      );

      debugPrint('🚫 Account suspended: $userId');
    } catch (e) {
      debugPrint('❌ Error suspending account: $e');
    }
  }

  /// Award badge to user
  Future<void> awardBadge(String userId, BadgeType badgeType) async {
    try {
      final score = await getSafetyScore(userId);
      if (score == null) return;

      // Check if badge already awarded
      if (score.hasBadge(badgeType)) {
        debugPrint('ℹ️ Badge already awarded: ${badgeType.name}');
        return;
      }

      final newBadge = Badge(type: badgeType, awardedAt: DateTime.now());
      final updatedBadges = [...score.badges, newBadge];

      await _firestore.collection('safetyScores').doc(userId).update({
        'badges': updatedBadges.map((b) => b.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Send congratulations notification
      final badgeNames = {
        BadgeType.verified: 'Verificado',
        BadgeType.topRated: 'Top Avaliado',
        BadgeType.reliable: 'Confiável',
        BadgeType.responsive: 'Resposta Rápida',
        BadgeType.professional: 'Profissional',
        BadgeType.expert: 'Especialista',
      };
      await _notificationRepository.createNotification(
        userId: userId,
        title: 'Parabéns! Novo Distintivo',
        body: 'Você ganhou o distintivo "${badgeNames[badgeType] ?? badgeType.name}"! Continue com o excelente trabalho.',
        type: 'badge_awarded',
        data: {'badgeType': badgeType.name},
      );

      debugPrint('🎖️ Badge awarded: ${badgeType.name} to user $userId');
    } catch (e) {
      debugPrint('❌ Error awarding badge: $e');
    }
  }
}
