import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/supplier_model.dart';

/// Service for managing supplier onboarding approval workflow (Uber-style)
///
/// This handles the account-level approval process:
/// - PENDING_REVIEW: New supplier waiting for admin review
/// - ACTIVE: Approved and can access dashboard
/// - NEEDS_CLARIFICATION: Admin requested changes
/// - REJECTED: Application denied
/// - SUSPENDED: Account suspended (post-approval)
class SupplierOnboardingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _suppliersRef => _firestore.collection('suppliers');

  // ==================== SUPPLIER-FACING METHODS ====================

  /// Get current onboarding status for a supplier
  Future<SupplierOnboardingStatus?> getOnboardingStatus(String supplierId) async {
    try {
      final doc = await _suppliersRef.doc(supplierId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return SupplierOnboardingStatus.fromFirestore(supplierId, data);
    } catch (e) {
      debugPrint('Error getting onboarding status: $e');
      return null;
    }
  }

  /// Stream onboarding status (for real-time updates on waiting screen)
  Stream<SupplierOnboardingStatus?> streamOnboardingStatus(String supplierId) {
    return _suppliersRef.doc(supplierId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      return SupplierOnboardingStatus.fromFirestore(supplierId, data);
    });
  }

  /// Resubmit after making requested changes (NEEDS_CLARIFICATION → PENDING_REVIEW)
  Future<bool> resubmitForReview(String supplierId) async {
    try {
      final doc = await _suppliersRef.doc(supplierId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final currentStatus = SupplierAccountStatus.values.firstWhere(
        (e) => e.name == data['accountStatus'],
        orElse: () => SupplierAccountStatus.pendingReview,
      );

      // Only allow resubmission from needsClarification status
      if (currentStatus != SupplierAccountStatus.needsClarification) {
        debugPrint('Cannot resubmit: current status is ${currentStatus.name}');
        return false;
      }

      await _suppliersRef.doc(supplierId).update({
        'accountStatus': SupplierAccountStatus.pendingReview.name,
        'resubmittedAt': Timestamp.now(),
        'rejectionReason': null, // Clear previous feedback
      });

      debugPrint('Supplier $supplierId resubmitted for review');
      return true;
    } catch (e) {
      debugPrint('Error resubmitting for review: $e');
      return false;
    }
  }

  // ==================== ADMIN METHODS ====================

  /// Get all suppliers pending review (for admin queue)
  Future<List<SupplierOnboardingStatus>> getPendingReviewSuppliers() async {
    try {
      debugPrint('🔍 getPendingReviewSuppliers: querying for accountStatus=${SupplierAccountStatus.pendingReview.name}');

      // First, let's check ALL suppliers to debug
      final allSuppliers = await _suppliersRef.limit(10).get();
      debugPrint('📊 Total suppliers in collection: ${allSuppliers.docs.length}');
      for (final doc in allSuppliers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('  - ${doc.id}: accountStatus=${data['accountStatus']}, createdAt=${data['createdAt']}');
      }

      final snapshot = await _suppliersRef
          .where('accountStatus', isEqualTo: SupplierAccountStatus.pendingReview.name)
          .orderBy('createdAt', descending: false) // Oldest first (FIFO)
          .limit(50)
          .get();

      debugPrint('📊 Found ${snapshot.docs.length} pending review suppliers');
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SupplierOnboardingStatus.fromFirestore(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting pending review suppliers: $e');
      return [];
    }
  }

  /// Stream pending review suppliers (for real-time admin queue)
  Stream<List<SupplierOnboardingStatus>> streamPendingReviewSuppliers() {
    debugPrint('🔍 Querying suppliers with accountStatus: ${SupplierAccountStatus.pendingReview.name}');

    // First, let's debug by getting ALL suppliers
    _suppliersRef.limit(10).get().then((allDocs) {
      debugPrint('📊 DEBUG - All suppliers in collection: ${allDocs.docs.length}');
      for (final doc in allDocs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('  📄 ${doc.id}: accountStatus="${data['accountStatus']}", createdAt=${data['createdAt']}');
      }
    });

    return _suppliersRef
        .where('accountStatus', isEqualTo: SupplierAccountStatus.pendingReview.name)
        .limit(50)
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error in streamPendingReviewSuppliers: $error');
        })
        .map((snapshot) {
          debugPrint('📊 Found ${snapshot.docs.length} pending suppliers (without orderBy)');
          final results = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('  ✅ Supplier: ${doc.id}, status: ${data['accountStatus']}, createdAt: ${data['createdAt']}');
            return SupplierOnboardingStatus.fromFirestore(doc.id, data);
          }).toList();
          // Sort by createdAt in memory instead
          results.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
          return results;
        });
  }

  /// Stream suppliers by status (generic method)
  Stream<List<SupplierOnboardingStatus>> streamSuppliersByStatus(SupplierAccountStatus status) {
    return _suppliersRef
        .where('accountStatus', isEqualTo: status.name)
        .limit(50)
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error in streamSuppliersByStatus($status): $error');
        })
        .map((snapshot) {
          final results = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return SupplierOnboardingStatus.fromFirestore(doc.id, data);
          }).toList();
          results.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          return results;
        });
  }

  /// APPROVE supplier application (PENDING_REVIEW → ACTIVE)
  Future<bool> approveSupplier({
    required String supplierId,
    required String adminId,
    String? adminNote,
  }) async {
    try {
      debugPrint('📤 approveSupplier: supplierId=$supplierId, adminId=$adminId');

      // First check if the document exists
      final docSnapshot = await _suppliersRef.doc(supplierId).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ approveSupplier: Supplier document not found: $supplierId');
        return false;
      }

      await _suppliersRef.doc(supplierId).update({
        'accountStatus': SupplierAccountStatus.active.name,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'adminNote': adminNote,
        'rejectionReason': null,
        'isActive': true, // Enable supplier visibility
        // Set authoritative fields for backend eligibility (isSupplierBookable)
        'lifecycle_state': 'active',
        'visibility': {'is_listed': true},
        'blocks': {'bookings_globally': false, 'scheduled_blocks': []},
        'rate_limit': {'exceeded': false},
      });

      debugPrint('✅ Supplier $supplierId APPROVED by $adminId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error approving supplier: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// REQUEST CHANGES from supplier (PENDING_REVIEW → NEEDS_CLARIFICATION)
  Future<bool> requestChanges({
    required String supplierId,
    required String adminId,
    required String clarificationRequest,
  }) async {
    try {
      debugPrint('📤 requestChanges: supplierId=$supplierId, adminId=$adminId');

      if (clarificationRequest.trim().isEmpty) {
        debugPrint('❌ requestChanges: Clarification request cannot be empty');
        return false;
      }

      // First check if the document exists
      final docSnapshot = await _suppliersRef.doc(supplierId).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ requestChanges: Supplier document not found: $supplierId');
        return false;
      }

      await _suppliersRef.doc(supplierId).update({
        'accountStatus': SupplierAccountStatus.needsClarification.name,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'rejectionReason': clarificationRequest, // Use this field for feedback
        'isActive': false,
      });

      debugPrint('⚠️ Supplier $supplierId - Changes requested by $adminId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error requesting changes: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// REJECT supplier application (PENDING_REVIEW → REJECTED)
  Future<bool> rejectSupplier({
    required String supplierId,
    required String adminId,
    required String rejectionReason,
  }) async {
    try {
      debugPrint('📤 rejectSupplier: supplierId=$supplierId, adminId=$adminId');

      if (rejectionReason.trim().isEmpty) {
        debugPrint('❌ rejectSupplier: Rejection reason cannot be empty');
        return false;
      }

      // First check if the document exists
      final docSnapshot = await _suppliersRef.doc(supplierId).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ rejectSupplier: Supplier document not found: $supplierId');
        return false;
      }

      await _suppliersRef.doc(supplierId).update({
        'accountStatus': SupplierAccountStatus.rejected.name,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'rejectionReason': rejectionReason,
        'isActive': false,
      });

      debugPrint('❌ Supplier $supplierId REJECTED by $adminId: $rejectionReason');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error rejecting supplier: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// DELETE a supplier completely (admin only)
  Future<bool> deleteSupplier({
    required String supplierId,
    required String adminId,
  }) async {
    try {
      debugPrint('🗑️ deleteSupplier: supplierId=$supplierId, adminId=$adminId');

      // First check if the document exists
      final docSnapshot = await _suppliersRef.doc(supplierId).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ deleteSupplier: Supplier document not found: $supplierId');
        return false;
      }

      await _suppliersRef.doc(supplierId).delete();

      debugPrint('🗑️ Supplier $supplierId DELETED by $adminId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting supplier: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// SUSPEND an active supplier (ACTIVE → SUSPENDED)
  Future<bool> suspendSupplier({
    required String supplierId,
    required String adminId,
    required String suspensionReason,
  }) async {
    try {
      await _suppliersRef.doc(supplierId).update({
        'accountStatus': SupplierAccountStatus.suspended.name,
        'suspendedAt': Timestamp.now(),
        'suspendedBy': adminId,
        'rejectionReason': suspensionReason,
        'isActive': false,
      });

      debugPrint('🚫 Supplier $supplierId SUSPENDED by $adminId');
      return true;
    } catch (e) {
      debugPrint('Error suspending supplier: $e');
      return false;
    }
  }

  /// REACTIVATE a suspended supplier (SUSPENDED → ACTIVE)
  Future<bool> reactivateSupplier({
    required String supplierId,
    required String adminId,
  }) async {
    try {
      await _suppliersRef.doc(supplierId).update({
        'accountStatus': SupplierAccountStatus.active.name,
        'reactivatedAt': Timestamp.now(),
        'reactivatedBy': adminId,
        'rejectionReason': null,
        'isActive': true,
      });

      debugPrint('✅ Supplier $supplierId REACTIVATED by $adminId');
      return true;
    } catch (e) {
      debugPrint('Error reactivating supplier: $e');
      return false;
    }
  }

  // ==================== IDENTITY VERIFICATION METHODS ====================

  /// Log identity verification transition for audit trail
  Future<void> _logIdentityVerificationTransition({
    required String supplierId,
    required String adminId,
    required String previousStatus,
    required String newStatus,
    String? reason,
  }) async {
    try {
      final auditRef = _firestore.collection('identity_verification_audit').doc();
      await auditRef.set({
        'id': auditRef.id,
        'supplierId': supplierId,
        'adminId': adminId,
        'previousStatus': previousStatus,
        'newStatus': newStatus,
        'reason': reason,
        'timestamp': Timestamp.now(),
        'action': _getAuditAction(previousStatus, newStatus),
      });
      debugPrint('📋 Identity verification audit logged: $supplierId ($previousStatus → $newStatus)');
    } catch (e) {
      debugPrint('⚠️ Failed to log identity verification audit: $e');
      // Don't throw - audit logging failure shouldn't block the operation
    }
  }

  String _getAuditAction(String previousStatus, String newStatus) {
    if (newStatus == 'verified') return 'VERIFY';
    if (newStatus == 'rejected') return 'REJECT';
    if (newStatus == 'pending') return 'RESET';
    return 'UPDATE';
  }

  /// VERIFY supplier identity (identity_verification_status → verified)
  /// This is SEPARATE from onboarding approval
  Future<bool> verifyIdentity({
    required String supplierId,
    required String adminId,
  }) async {
    try {
      debugPrint('📤 verifyIdentity: supplierId=$supplierId, adminId=$adminId');

      final docSnapshot = await _suppliersRef.doc(supplierId).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ verifyIdentity: Supplier document not found: $supplierId');
        return false;
      }

      // Get previous status for audit
      final data = docSnapshot.data() as Map<String, dynamic>;
      final previousStatus = data['identityVerificationStatus'] as String? ?? 'pending';

      await _suppliersRef.doc(supplierId).update({
        'identityVerificationStatus': IdentityVerificationStatus.verified.name,
        'identityVerifiedAt': Timestamp.now(),
        'identityVerifiedBy': adminId,
        'identityVerificationRejectionReason': null,
        // Set full compliance object for backend eligibility (isSupplierBookable)
        'compliance': {'payouts_ready': true, 'kyc_status': 'verified'},
      });

      // Log audit trail
      await _logIdentityVerificationTransition(
        supplierId: supplierId,
        adminId: adminId,
        previousStatus: previousStatus,
        newStatus: 'verified',
      );

      debugPrint('✅ Supplier $supplierId identity VERIFIED by $adminId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error verifying identity: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// REJECT supplier identity verification (identity_verification_status → rejected)
  Future<bool> rejectIdentityVerification({
    required String supplierId,
    required String adminId,
    required String rejectionReason,
  }) async {
    try {
      debugPrint('📤 rejectIdentityVerification: supplierId=$supplierId, adminId=$adminId');

      if (rejectionReason.trim().isEmpty) {
        debugPrint('❌ rejectIdentityVerification: Rejection reason cannot be empty');
        return false;
      }

      final docSnapshot = await _suppliersRef.doc(supplierId).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ rejectIdentityVerification: Supplier document not found: $supplierId');
        return false;
      }

      // Get previous status for audit
      final data = docSnapshot.data() as Map<String, dynamic>;
      final previousStatus = data['identityVerificationStatus'] as String? ?? 'pending';

      await _suppliersRef.doc(supplierId).update({
        'identityVerificationStatus': IdentityVerificationStatus.rejected.name,
        'identityVerifiedAt': Timestamp.now(),
        'identityVerifiedBy': adminId,
        'identityVerificationRejectionReason': rejectionReason,
      });

      // Log audit trail
      await _logIdentityVerificationTransition(
        supplierId: supplierId,
        adminId: adminId,
        previousStatus: previousStatus,
        newStatus: 'rejected',
        reason: rejectionReason,
      );

      debugPrint('❌ Supplier $supplierId identity REJECTED by $adminId: $rejectionReason');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error rejecting identity verification: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Reset identity verification to pending (for re-submission)
  Future<bool> resetIdentityVerification({
    required String supplierId,
    String? adminId,
  }) async {
    try {
      debugPrint('📤 resetIdentityVerification: supplierId=$supplierId');

      final docSnapshot = await _suppliersRef.doc(supplierId).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ resetIdentityVerification: Supplier document not found: $supplierId');
        return false;
      }

      // Get previous status for audit
      final data = docSnapshot.data() as Map<String, dynamic>;
      final previousStatus = data['identityVerificationStatus'] as String? ?? 'pending';

      await _suppliersRef.doc(supplierId).update({
        'identityVerificationStatus': IdentityVerificationStatus.pending.name,
        'identityVerificationRejectionReason': null,
      });

      // Log audit trail (adminId is optional for supplier-initiated resets)
      await _logIdentityVerificationTransition(
        supplierId: supplierId,
        adminId: adminId ?? 'system',
        previousStatus: previousStatus,
        newStatus: 'pending',
        reason: 'Reset for re-submission',
      );

      debugPrint('🔄 Supplier $supplierId identity verification reset to pending');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error resetting identity verification: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get onboarding statistics for admin dashboard
  Future<OnboardingStats> getOnboardingStats() async {
    try {
      final pendingCount = await _suppliersRef
          .where('accountStatus', isEqualTo: SupplierAccountStatus.pendingReview.name)
          .count()
          .get();

      final activeCount = await _suppliersRef
          .where('accountStatus', isEqualTo: SupplierAccountStatus.active.name)
          .count()
          .get();

      final needsClarificationCount = await _suppliersRef
          .where('accountStatus', isEqualTo: SupplierAccountStatus.needsClarification.name)
          .count()
          .get();

      final rejectedCount = await _suppliersRef
          .where('accountStatus', isEqualTo: SupplierAccountStatus.rejected.name)
          .count()
          .get();

      final suspendedCount = await _suppliersRef
          .where('accountStatus', isEqualTo: SupplierAccountStatus.suspended.name)
          .count()
          .get();

      return OnboardingStats(
        pendingReview: pendingCount.count ?? 0,
        active: activeCount.count ?? 0,
        needsClarification: needsClarificationCount.count ?? 0,
        rejected: rejectedCount.count ?? 0,
        suspended: suspendedCount.count ?? 0,
      );
    } catch (e) {
      debugPrint('Error getting onboarding stats: $e');
      return OnboardingStats.empty();
    }
  }
}

/// Onboarding status model for supplier-facing screens and admin review
/// Contains ALL registration data for comprehensive admin review
class SupplierOnboardingStatus {
  final String supplierId;
  final SupplierAccountStatus accountStatus;
  final String? businessName;
  final String? category;
  final List<String> subcategories;
  final String? description;
  final String? city;
  final String? province;
  final String? address;
  final SupplierEntityType entityType;
  final String? nif;
  final IdentityDocumentType? idDocumentType;
  final String? idDocumentNumber;
  final String? idDocumentUrl;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime? createdAt;
  final DateTime? resubmittedAt;

  // Contact info
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;

  // Media
  final List<String> photos;
  final List<String> portfolioPhotos;
  final List<String> videos;

  // Pricing
  final int? minPrice;
  final int? maxPrice;
  final bool priceOnRequest;

  // Identity Verification (SEPARATE from onboarding approval)
  final IdentityVerificationStatus identityVerificationStatus;
  final DateTime? identityVerifiedAt;
  final String? identityVerifiedBy;
  final String? identityVerificationRejectionReason;
  final List<String> verificationDocuments;

  SupplierOnboardingStatus({
    required this.supplierId,
    required this.accountStatus,
    this.businessName,
    this.category,
    this.subcategories = const [],
    this.description,
    this.city,
    this.province,
    this.address,
    this.entityType = SupplierEntityType.individual,
    this.nif,
    this.idDocumentType,
    this.idDocumentNumber,
    this.idDocumentUrl,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    this.createdAt,
    this.resubmittedAt,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.photos = const [],
    this.portfolioPhotos = const [],
    this.videos = const [],
    this.minPrice,
    this.maxPrice,
    this.priceOnRequest = false,
    this.identityVerificationStatus = IdentityVerificationStatus.pending,
    this.identityVerifiedAt,
    this.identityVerifiedBy,
    this.identityVerificationRejectionReason,
    this.verificationDocuments = const [],
  });

  factory SupplierOnboardingStatus.fromFirestore(String id, Map<String, dynamic> data) {
    // Parse location data
    final locationData = data['location'] as Map<String, dynamic>?;

    return SupplierOnboardingStatus(
      supplierId: id,
      accountStatus: SupplierAccountStatus.values.firstWhere(
        (e) => e.name == data['accountStatus'],
        orElse: () => SupplierAccountStatus.pendingReview,
      ),
      businessName: data['businessName'] as String?,
      category: data['category'] as String?,
      subcategories: _parseStringList(data['subcategories']),
      description: data['description'] as String?,
      city: locationData?['city'] as String? ?? data['city'] as String?,
      province: locationData?['province'] as String? ?? data['province'] as String?,
      address: locationData?['address'] as String?,
      entityType: SupplierEntityType.values.firstWhere(
        (e) => e.name == data['entityType'],
        orElse: () => SupplierEntityType.individual,
      ),
      nif: data['nif'] as String?,
      idDocumentType: data['idDocumentType'] != null
          ? IdentityDocumentType.values.firstWhere(
              (e) => e.name == data['idDocumentType'],
              orElse: () => IdentityDocumentType.bilheteIdentidade,
            )
          : null,
      idDocumentNumber: data['idDocumentNumber'] as String?,
      idDocumentUrl: data['idDocumentUrl'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resubmittedAt: (data['resubmittedAt'] as Timestamp?)?.toDate(),
      // Contact info
      phone: data['phone']?.toString(),
      whatsapp: data['whatsapp']?.toString(),
      email: data['email']?.toString(),
      website: data['website'] as String?,
      // Media
      photos: _parseStringList(data['photos']),
      portfolioPhotos: _parseStringList(data['portfolioPhotos']),
      videos: _parseStringList(data['videos']),
      // Pricing
      minPrice: (data['minPrice'] as num?)?.toInt(),
      maxPrice: (data['maxPrice'] as num?)?.toInt(),
      priceOnRequest: data['priceOnRequest'] as bool? ?? false,
      // Identity Verification
      identityVerificationStatus: IdentityVerificationStatus.values.firstWhere(
        (e) => e.name == (data['identityVerificationStatus'] as String?),
        orElse: () => IdentityVerificationStatus.pending,
      ),
      identityVerifiedAt: (data['identityVerifiedAt'] as Timestamp?)?.toDate(),
      identityVerifiedBy: data['identityVerifiedBy'] as String?,
      identityVerificationRejectionReason: data['identityVerificationRejectionReason'] as String?,
      verificationDocuments: _parseStringList(data['verificationDocuments']),
    );
  }

  /// Helper to parse string lists from Firestore
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  /// Get all photos (profile + portfolio)
  List<String> get allPhotos => [...photos, ...portfolioPhotos];

  /// Get formatted price display
  String get priceDisplay {
    if (priceOnRequest) return 'Preço sob consulta';
    if (minPrice != null && maxPrice != null) {
      return '${_formatPrice(minPrice!)} - ${_formatPrice(maxPrice!)} Kz';
    }
    if (minPrice != null) return 'Desde ${_formatPrice(minPrice!)} Kz';
    if (maxPrice != null) return 'Até ${_formatPrice(maxPrice!)} Kz';
    return 'Preço não definido';
  }

  static String _formatPrice(int price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toString();
  }

  /// Check if supplier can access the main dashboard
  bool get canAccessDashboard => accountStatus == SupplierAccountStatus.active;

  /// Check if supplier should see pending review screen
  bool get isPendingReview => accountStatus == SupplierAccountStatus.pendingReview;

  /// Check if supplier needs to make changes
  bool get needsClarification => accountStatus == SupplierAccountStatus.needsClarification;

  /// Check if application was rejected
  bool get isRejected => accountStatus == SupplierAccountStatus.rejected;

  /// Check if account is suspended
  bool get isSuspended => accountStatus == SupplierAccountStatus.suspended;

  /// Check if identity is verified
  bool get isIdentityVerified => identityVerificationStatus == IdentityVerificationStatus.verified;

  /// Check if identity verification is pending
  bool get isIdentityPending => identityVerificationStatus == IdentityVerificationStatus.pending;

  /// Check if identity verification was rejected
  bool get isIdentityRejected => identityVerificationStatus == IdentityVerificationStatus.rejected;

  /// Check if supplier is eligible for bookings
  /// Requires BOTH onboarding approval AND identity verification
  bool get isEligibleForBookings =>
      accountStatus == SupplierAccountStatus.active &&
      identityVerificationStatus == IdentityVerificationStatus.verified;

  /// Check if bookings are blocked due to identity verification
  bool get isBlockedByIdentityVerification =>
      accountStatus == SupplierAccountStatus.active &&
      identityVerificationStatus != IdentityVerificationStatus.verified;

  /// Get identity verification status display text (Portuguese)
  String get identityVerificationStatusText {
    switch (identityVerificationStatus) {
      case IdentityVerificationStatus.pending:
        return 'Verificação Pendente';
      case IdentityVerificationStatus.verified:
        return 'Identidade Verificada';
      case IdentityVerificationStatus.rejected:
        return 'Verificação Rejeitada';
    }
  }

  /// Get user-friendly status text (Portuguese)
  String get statusText {
    switch (accountStatus) {
      case SupplierAccountStatus.pendingReview:
        return 'Em Análise';
      case SupplierAccountStatus.active:
        return 'Activo';
      case SupplierAccountStatus.needsClarification:
        return 'Requer Alterações';
      case SupplierAccountStatus.rejected:
        return 'Rejeitado';
      case SupplierAccountStatus.suspended:
        return 'Suspenso';
    }
  }

  /// Get status description for display (Portuguese)
  String get statusDescription {
    switch (accountStatus) {
      case SupplierAccountStatus.pendingReview:
        return 'A sua candidatura está a ser analisada pela nossa equipa. Receberá uma notificação assim que houver uma actualização.';
      case SupplierAccountStatus.active:
        return 'A sua conta está activa. Pode aceder ao painel e receber pedidos de clientes.';
      case SupplierAccountStatus.needsClarification:
        return 'A nossa equipa solicitou algumas alterações. Por favor, reveja o feedback e resubmeta a sua candidatura.';
      case SupplierAccountStatus.rejected:
        return 'Infelizmente, a sua candidatura não foi aprovada. Consulte o motivo abaixo.';
      case SupplierAccountStatus.suspended:
        return 'A sua conta foi temporariamente suspensa. Entre em contacto com o suporte para mais informações.';
    }
  }
}

/// Onboarding statistics for admin dashboard
class OnboardingStats {
  final int pendingReview;
  final int active;
  final int needsClarification;
  final int rejected;
  final int suspended;

  OnboardingStats({
    required this.pendingReview,
    required this.active,
    required this.needsClarification,
    required this.rejected,
    required this.suspended,
  });

  factory OnboardingStats.empty() => OnboardingStats(
        pendingReview: 0,
        active: 0,
        needsClarification: 0,
        rejected: 0,
        suspended: 0,
      );

  int get total => pendingReview + active + needsClarification + rejected + suspended;
}
