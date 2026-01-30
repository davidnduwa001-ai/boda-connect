import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/supplier_model.dart';

/// Search filter parameters
class SearchFilters {
  final String? query;
  final String? category;
  final List<String>? subcategories;
  final String? city;
  final String? province;
  final double? maxDistance; // km
  final double? userLatitude;
  final double? userLongitude;
  final double? minRating;
  final DateTime? eventDate;
  final bool verifiedOnly;
  final bool featuredOnly;
  final SortOption sortBy;

  const SearchFilters({
    this.query,
    this.category,
    this.subcategories,
    this.city,
    this.province,
    this.maxDistance,
    this.userLatitude,
    this.userLongitude,
    this.minRating,
    this.eventDate,
    this.verifiedOnly = false,
    this.featuredOnly = false,
    this.sortBy = SortOption.relevance,
  });

  SearchFilters copyWith({
    String? query,
    String? category,
    List<String>? subcategories,
    String? city,
    String? province,
    double? maxDistance,
    double? userLatitude,
    double? userLongitude,
    double? minRating,
    DateTime? eventDate,
    bool? verifiedOnly,
    bool? featuredOnly,
    SortOption? sortBy,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      category: category ?? this.category,
      subcategories: subcategories ?? this.subcategories,
      city: city ?? this.city,
      province: province ?? this.province,
      maxDistance: maxDistance ?? this.maxDistance,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      minRating: minRating ?? this.minRating,
      eventDate: eventDate ?? this.eventDate,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters =>
      category != null ||
      city != null ||
      minRating != null ||
      verifiedOnly ||
      featuredOnly;
}

/// Sort options for search results
enum SortOption {
  relevance,
  rating,
  distance,
  newest,
  mostPopular,
  mostReviews,
}

/// Supplier with calculated search score
class RankedSupplier {
  final SupplierModel supplier;
  final double score;
  final Map<String, double> scoreBreakdown;
  final double? distance; // km, if location provided

  const RankedSupplier({
    required this.supplier,
    required this.score,
    required this.scoreBreakdown,
    this.distance,
  });
}

/// Service for search ranking and discovery
class SearchRankingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ranking weights (total = 100)
  static const double verificationWeight = 35.0;
  static const double ratingWeight = 25.0;
  static const double responseWeight = 15.0;
  static const double completenessWeight = 15.0;
  static const double popularityWeight = 10.0;

  // Boost multipliers
  static const double featuredBoost = 1.20;
  static const double newSupplierBoost = 1.05; // First 30 days

  /// Calculate search score for a supplier
  double calculateScore(SupplierModel supplier, SearchFilters? filters) {
    double score = 0.0;

    // 1. Verification Status (35% weight)
    double verificationScore = 0;
    if (supplier.isVerified) {
      verificationScore = verificationWeight;
    } else if (supplier.isActive) {
      // Active but not verified gets partial score
      verificationScore = verificationWeight * 0.3;
    }
    score += verificationScore;

    // 2. Rating Score (25% weight)
    double ratingScore = 0;
    if (supplier.reviewCount >= 3) {
      // Enough reviews for meaningful rating
      ratingScore = (supplier.rating / 5.0) * ratingWeight;
    } else if (supplier.reviewCount > 0) {
      // Few reviews - partial weight
      ratingScore = (supplier.rating / 5.0) * ratingWeight * 0.6;
    } else {
      // No reviews - neutral score
      ratingScore = ratingWeight * 0.5;
    }
    score += ratingScore;

    // 3. Response Quality (15% weight)
    double responseScore = (supplier.responseRate / 100) * responseWeight;
    score += responseScore;

    // 4. Profile Completeness (15% weight)
    double completenessScore = _calculateProfileCompleteness(supplier) * completenessWeight;
    score += completenessScore;

    // 5. Popularity (10% weight) - based on views and favorites
    double popularityScore = 0;
    final viewScore = (supplier.viewCount / 1000).clamp(0.0, 1.0);
    final favoriteScore = (supplier.favoriteCount / 100).clamp(0.0, 1.0);
    final bookingScore = (supplier.completedBookings / 50).clamp(0.0, 1.0);
    popularityScore = ((viewScore + favoriteScore + bookingScore) / 3) * popularityWeight;
    score += popularityScore;

    // Apply boosts
    double totalBoost = 1.0;

    // Featured boost
    if (supplier.isFeatured) {
      totalBoost *= featuredBoost;
    }

    // New supplier boost (first 30 days)
    final daysSinceJoined =
        DateTime.now().difference(supplier.createdAt).inDays;
    if (daysSinceJoined <= 30) {
      totalBoost *= newSupplierBoost;
    }

    score *= totalBoost;

    return score;
  }

  /// Calculate profile completeness (0.0 to 1.0)
  double _calculateProfileCompleteness(SupplierModel supplier) {
    int totalFields = 10;
    int filledFields = 0;

    // Required fields
    if (supplier.businessName.isNotEmpty) filledFields++;
    if (supplier.description.isNotEmpty) filledFields++;
    if (supplier.category.isNotEmpty) filledFields++;

    // Optional but valuable
    if (supplier.photos.isNotEmpty) filledFields++;
    if (supplier.portfolioPhotos.length >= 3) filledFields++;
    if (supplier.phone != null || supplier.whatsapp != null) filledFields++;
    if (supplier.location?.city != null) filledFields++;
    if (supplier.workingHours != null) filledFields++;
    if (supplier.specialties.isNotEmpty) filledFields++;
    if (supplier.yearsExperience != null) filledFields++;

    return filledFields / totalFields;
  }

  /// Get score breakdown for debugging/transparency
  Map<String, double> getScoreBreakdown(SupplierModel supplier) {
    final breakdown = <String, double>{};

    // Verification
    if (supplier.isVerified) {
      breakdown['verification'] = verificationWeight;
    } else if (supplier.isActive) {
      breakdown['verification'] = verificationWeight * 0.3;
    } else {
      breakdown['verification'] = 0;
    }

    // Rating
    if (supplier.reviewCount >= 3) {
      breakdown['rating'] = (supplier.rating / 5.0) * ratingWeight;
    } else if (supplier.reviewCount > 0) {
      breakdown['rating'] = (supplier.rating / 5.0) * ratingWeight * 0.6;
    } else {
      breakdown['rating'] = ratingWeight * 0.5;
    }

    // Response
    breakdown['response'] = (supplier.responseRate / 100) * responseWeight;

    // Completeness
    breakdown['completeness'] = _calculateProfileCompleteness(supplier) * completenessWeight;

    // Popularity
    final viewScore = (supplier.viewCount / 1000).clamp(0.0, 1.0);
    final favoriteScore = (supplier.favoriteCount / 100).clamp(0.0, 1.0);
    breakdown['popularity'] = ((viewScore + favoriteScore) / 2) * popularityWeight;

    // Boosts
    if (supplier.isFeatured) {
      breakdown['featuredBoost'] = featuredBoost;
    }

    return breakdown;
  }

  /// Search and rank suppliers
  Future<List<RankedSupplier>> searchSuppliers({
    required SearchFilters filters,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore.collection('suppliers')
          .where('isActive', isEqualTo: true);

      // Apply basic filters that Firestore can handle
      if (filters.category != null && filters.category!.isNotEmpty) {
        query = query.where('category', isEqualTo: filters.category);
      }

      if (filters.verifiedOnly) {
        query = query.where('isVerified', isEqualTo: true);
      }

      if (filters.featuredOnly) {
        query = query.where('isFeatured', isEqualTo: true);
      }

      // Get more results than needed for client-side filtering and sorting
      final fetchLimit = limit * 3;
      query = query.limit(fetchLimit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      // Convert to supplier models
      List<SupplierModel> suppliers = snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc))
          .toList();

      // Apply client-side filters
      suppliers = _applyClientSideFilters(suppliers, filters);

      // Calculate scores and create ranked list
      List<RankedSupplier> rankedSuppliers = suppliers.map((supplier) {
        final score = calculateScore(supplier, filters);
        final breakdown = getScoreBreakdown(supplier);
        double? distance;

        if (filters.userLatitude != null &&
            filters.userLongitude != null &&
            supplier.location?.geopoint != null) {
          distance = _calculateDistance(
            filters.userLatitude!,
            filters.userLongitude!,
            supplier.location!.geopoint!.latitude,
            supplier.location!.geopoint!.longitude,
          );
        }

        return RankedSupplier(
          supplier: supplier,
          score: score,
          scoreBreakdown: breakdown,
          distance: distance,
        );
      }).toList();

      // Apply distance filter if specified
      if (filters.maxDistance != null) {
        rankedSuppliers = rankedSuppliers
            .where((rs) => rs.distance == null || rs.distance! <= filters.maxDistance!)
            .toList();
      }

      // Sort based on sort option
      rankedSuppliers = _sortResults(rankedSuppliers, filters.sortBy);

      // Return limited results
      return rankedSuppliers.take(limit).toList();
    } catch (e) {
      debugPrint('Error searching suppliers: $e');
      return [];
    }
  }

  /// Apply filters that can't be done in Firestore query
  List<SupplierModel> _applyClientSideFilters(
    List<SupplierModel> suppliers,
    SearchFilters filters,
  ) {
    return suppliers.where((supplier) {
      // Text search in name and description
      if (filters.query != null && filters.query!.isNotEmpty) {
        final query = filters.query!.toLowerCase();
        final nameMatch = supplier.businessName.toLowerCase().contains(query);
        final descMatch = supplier.description.toLowerCase().contains(query);
        final categoryMatch = supplier.category.toLowerCase().contains(query);
        final keywordMatch = supplier.searchKeywords.any(
          (keyword) => keyword.toLowerCase().contains(query),
        );

        if (!nameMatch && !descMatch && !categoryMatch && !keywordMatch) {
          return false;
        }
      }

      // City filter
      if (filters.city != null && filters.city!.isNotEmpty) {
        final supplierCity = supplier.location?.city?.toLowerCase() ?? '';
        if (!supplierCity.contains(filters.city!.toLowerCase())) {
          return false;
        }
      }

      // Province filter
      if (filters.province != null && filters.province!.isNotEmpty) {
        final supplierProvince = supplier.location?.province?.toLowerCase() ?? '';
        if (!supplierProvince.contains(filters.province!.toLowerCase())) {
          return false;
        }
      }

      // Rating filter
      if (filters.minRating != null && supplier.rating < filters.minRating!) {
        return false;
      }

      // Subcategories filter
      if (filters.subcategories != null && filters.subcategories!.isNotEmpty) {
        final hasMatchingSubcategory = supplier.subcategories
            .any((sub) => filters.subcategories!.contains(sub));
        if (!hasMatchingSubcategory) return false;
      }

      return true;
    }).toList();
  }

  /// Sort results based on selected option
  List<RankedSupplier> _sortResults(
    List<RankedSupplier> suppliers,
    SortOption sortBy,
  ) {
    switch (sortBy) {
      case SortOption.relevance:
        // Sort by score (verified first, then by score)
        suppliers.sort((a, b) {
          // Verified suppliers always first
          if (a.supplier.isVerified && !b.supplier.isVerified) return -1;
          if (!a.supplier.isVerified && b.supplier.isVerified) return 1;
          // Then by score
          return b.score.compareTo(a.score);
        });
        break;

      case SortOption.rating:
        suppliers.sort((a, b) {
          // Consider review count for meaningful comparison
          final aWeightedRating = a.supplier.rating *
              (a.supplier.reviewCount > 0 ? 1 : 0.5);
          final bWeightedRating = b.supplier.rating *
              (b.supplier.reviewCount > 0 ? 1 : 0.5);
          return bWeightedRating.compareTo(aWeightedRating);
        });
        break;

      case SortOption.distance:
        suppliers.sort((a, b) {
          final aDist = a.distance ?? double.infinity;
          final bDist = b.distance ?? double.infinity;
          return aDist.compareTo(bDist);
        });
        break;

      case SortOption.newest:
        suppliers.sort((a, b) =>
            b.supplier.createdAt.compareTo(a.supplier.createdAt));
        break;

      case SortOption.mostPopular:
        suppliers.sort((a, b) {
          final aPopularity =
              a.supplier.viewCount + (a.supplier.favoriteCount * 10);
          final bPopularity =
              b.supplier.viewCount + (b.supplier.favoriteCount * 10);
          return bPopularity.compareTo(aPopularity);
        });
        break;

      case SortOption.mostReviews:
        suppliers.sort((a, b) =>
            b.supplier.reviewCount.compareTo(a.supplier.reviewCount));
        break;
    }

    return suppliers;
  }

  /// Calculate distance between two points (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Get featured/promoted suppliers
  Future<List<SupplierModel>> getFeaturedSuppliers({int limit = 6}) async {
    try {
      // Get featured verified suppliers with good ratings
      final snapshot = await _firestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .where('isVerified', isEqualTo: true)
          .where('isFeatured', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      if (snapshot.docs.length < limit) {
        // Fill with top-rated verified suppliers
        final additionalSnapshot = await _firestore
            .collection('suppliers')
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: true)
            .orderBy('rating', descending: true)
            .limit(limit)
            .get();

        final existingIds = snapshot.docs.map((d) => d.id).toSet();
        final additional = additionalSnapshot.docs
            .where((d) => !existingIds.contains(d.id))
            .take(limit - snapshot.docs.length);

        return [...snapshot.docs, ...additional]
            .map((doc) => SupplierModel.fromFirestore(doc))
            .toList();
      }

      return snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting featured suppliers: $e');
      return [];
    }
  }

  /// Get suppliers by category with ranking
  Future<List<RankedSupplier>> getSuppliersByCategory({
    required String category,
    int limit = 20,
  }) async {
    return searchSuppliers(
      filters: SearchFilters(category: category),
      limit: limit,
    );
  }

  /// Get nearby suppliers
  Future<List<RankedSupplier>> getNearbySuppliers({
    required double latitude,
    required double longitude,
    double maxDistance = 50, // km
    int limit = 20,
  }) async {
    return searchSuppliers(
      filters: SearchFilters(
        userLatitude: latitude,
        userLongitude: longitude,
        maxDistance: maxDistance,
        sortBy: SortOption.distance,
      ),
      limit: limit,
    );
  }

  /// Get top-rated suppliers
  Future<List<SupplierModel>> getTopRatedSuppliers({
    String? category,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .where('isVerified', isEqualTo: true);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query
          .orderBy('rating', descending: true)
          .orderBy('reviewCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting top-rated suppliers: $e');
      return [];
    }
  }

  /// Get recently added suppliers
  Future<List<SupplierModel>> getNewSuppliers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting new suppliers: $e');
      return [];
    }
  }

  /// Get available categories with supplier counts
  Future<Map<String, int>> getCategoryCounts() async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .where('isActive', isEqualTo: true)
          .get();

      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          counts[category] = (counts[category] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      debugPrint('Error getting category counts: $e');
      return {};
    }
  }
}
