import 'package:algoliasearch/algoliasearch.dart';
import 'package:flutter/foundation.dart';

/// Algolia Search Service for full-text search across suppliers and packages
class SearchService {
  static final SearchService _instance = SearchService._();
  factory SearchService() => _instance;
  SearchService._();

  // Placeholder values - must be replaced with real credentials
  static const String _placeholderAppId = 'YOUR_ALGOLIA_APP_ID';
  static const String _placeholderApiKey = 'YOUR_ALGOLIA_SEARCH_API_KEY';

  late final SearchClient _client;
  bool _isInitialized = false;

  /// Check if credentials are placeholder values
  static bool _isPlaceholder(String value) {
    return value.isEmpty ||
        value.startsWith('YOUR_') ||
        value == _placeholderAppId ||
        value == _placeholderApiKey;
  }

  /// Initialize Algolia client
  /// Throws [StateError] if placeholder credentials are used
  Future<void> initialize({
    required String appId,
    required String apiKey,
  }) async {
    if (_isInitialized) return;

    // Validate credentials are not placeholders
    if (_isPlaceholder(appId) || _isPlaceholder(apiKey)) {
      const errorMessage = 'Algolia credentials not configured. '
          'Replace YOUR_ALGOLIA_APP_ID and YOUR_ALGOLIA_SEARCH_API_KEY '
          'with real credentials from your Algolia dashboard.';
      debugPrint('❌ $errorMessage');
      throw StateError(errorMessage);
    }

    _client = SearchClient(appId: appId, apiKey: apiKey);
    _isInitialized = true;
    debugPrint('✅ Algolia Search initialized');
  }

  /// Search suppliers
  Future<SearchResults> searchSuppliers({
    required String query,
    String? category,
    String? city,
    double? minRating,
    int? minPrice,
    int? maxPrice,
    int page = 0,
    int hitsPerPage = 20,
  }) async {
    if (!_isInitialized) {
      throw Exception('SearchService not initialized. Call initialize() first.');
    }

    try {
      // Build filters
      final filters = <String>[];

      if (category != null && category.isNotEmpty) {
        filters.add('category:"$category"');
      }
      if (city != null && city.isNotEmpty) {
        filters.add('location.city:"$city"');
      }
      if (minRating != null) {
        filters.add('rating >= $minRating');
      }
      if (minPrice != null) {
        filters.add('minPrice >= $minPrice');
      }
      if (maxPrice != null) {
        filters.add('maxPrice <= $maxPrice');
      }

      // Always filter for active suppliers
      filters.add('isActive:true');

      final response = await _client.searchSingleIndex(
        indexName: 'suppliers',
        searchParams: SearchParamsObject(
          query: query,
          page: page,
          hitsPerPage: hitsPerPage,
          filters: filters.isNotEmpty ? filters.join(' AND ') : null,
          attributesToRetrieve: [
            'objectID',
            'businessName',
            'category',
            'subcategory',
            'description',
            'location',
            'rating',
            'reviewCount',
            'minPrice',
            'maxPrice',
            'photos',
            'isVerified',
            'tier',
          ],
        ),
      );

      return SearchResults(
        hits: response.hits.map((hit) => SearchHit.fromAlgolia(hit)).toList(),
        nbHits: response.nbHits ?? 0,
        page: response.page ?? 0,
        nbPages: response.nbPages ?? 0,
        hitsPerPage: response.hitsPerPage ?? hitsPerPage,
        query: query,
      );
    } catch (e) {
      debugPrint('❌ Algolia search error: $e');
      rethrow;
    }
  }

  /// Search packages
  Future<SearchResults> searchPackages({
    required String query,
    String? category,
    int? minPrice,
    int? maxPrice,
    int page = 0,
    int hitsPerPage = 20,
  }) async {
    if (!_isInitialized) {
      throw Exception('SearchService not initialized. Call initialize() first.');
    }

    try {
      final filters = <String>[];

      if (category != null && category.isNotEmpty) {
        filters.add('category:"$category"');
      }
      if (minPrice != null) {
        filters.add('price >= $minPrice');
      }
      if (maxPrice != null) {
        filters.add('price <= $maxPrice');
      }

      filters.add('isActive:true');

      final response = await _client.searchSingleIndex(
        indexName: 'packages',
        searchParams: SearchParamsObject(
          query: query,
          page: page,
          hitsPerPage: hitsPerPage,
          filters: filters.isNotEmpty ? filters.join(' AND ') : null,
        ),
      );

      return SearchResults(
        hits: response.hits.map((hit) => SearchHit.fromAlgolia(hit)).toList(),
        nbHits: response.nbHits ?? 0,
        page: response.page ?? 0,
        nbPages: response.nbPages ?? 0,
        hitsPerPage: response.hitsPerPage ?? hitsPerPage,
        query: query,
      );
    } catch (e) {
      debugPrint('❌ Algolia packages search error: $e');
      rethrow;
    }
  }

  /// Get search suggestions (autocomplete)
  Future<List<String>> getSuggestions({
    required String query,
    int limit = 5,
  }) async {
    if (!_isInitialized || query.length < 2) {
      return [];
    }

    try {
      final response = await _client.searchSingleIndex(
        indexName: 'suppliers',
        searchParams: SearchParamsObject(
          query: query,
          hitsPerPage: limit,
          attributesToRetrieve: ['businessName', 'category'],
        ),
      );

      final suggestions = <String>{};
      for (final hit in response.hits) {
        final data = hit as Map<String, dynamic>;
        if (data['businessName'] != null) {
          suggestions.add(data['businessName'] as String);
        }
        if (data['category'] != null) {
          suggestions.add(data['category'] as String);
        }
      }

      return suggestions.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Algolia suggestions error: $e');
      return [];
    }
  }
}

/// Search results wrapper
class SearchResults {
  final List<SearchHit> hits;
  final int nbHits;
  final int page;
  final int nbPages;
  final int hitsPerPage;
  final String query;

  const SearchResults({
    required this.hits,
    required this.nbHits,
    required this.page,
    required this.nbPages,
    required this.hitsPerPage,
    required this.query,
  });

  bool get hasMore => page < nbPages - 1;
}

/// Individual search hit
class SearchHit {
  final String objectId;
  final String? businessName;
  final String? category;
  final String? subcategory;
  final String? description;
  final Map<String, dynamic>? location;
  final double? rating;
  final int? reviewCount;
  final int? minPrice;
  final int? maxPrice;
  final List<String>? photos;
  final bool? isVerified;
  final String? tier;
  final Map<String, dynamic> rawData;

  const SearchHit({
    required this.objectId,
    this.businessName,
    this.category,
    this.subcategory,
    this.description,
    this.location,
    this.rating,
    this.reviewCount,
    this.minPrice,
    this.maxPrice,
    this.photos,
    this.isVerified,
    this.tier,
    required this.rawData,
  });

  factory SearchHit.fromAlgolia(dynamic hit) {
    final data = hit as Map<String, dynamic>;
    return SearchHit(
      objectId: data['objectID'] as String? ?? '',
      businessName: data['businessName'] as String?,
      category: data['category'] as String?,
      subcategory: data['subcategory'] as String?,
      description: data['description'] as String?,
      location: data['location'] as Map<String, dynamic>?,
      rating: (data['rating'] as num?)?.toDouble(),
      reviewCount: data['reviewCount'] as int?,
      minPrice: data['minPrice'] as int?,
      maxPrice: data['maxPrice'] as int?,
      photos: (data['photos'] as List?)?.cast<String>(),
      isVerified: data['isVerified'] as bool?,
      tier: data['tier'] as String?,
      rawData: data,
    );
  }

  String? get city => location?['city'] as String?;
  String? get firstPhoto => photos?.isNotEmpty == true ? photos!.first : null;
}
