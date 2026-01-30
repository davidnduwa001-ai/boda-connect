import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/search_service.dart';

// ==================== SEARCH SERVICE PROVIDER ====================

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

// ==================== SEARCH STATE ====================

class SearchState {
  final String query;
  final SearchResults? supplierResults;
  final SearchResults? packageResults;
  final List<String> suggestions;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final SearchFilters filters;

  const SearchState({
    this.query = '',
    this.supplierResults,
    this.packageResults,
    this.suggestions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.filters = const SearchFilters(),
  });

  SearchState copyWith({
    String? query,
    SearchResults? supplierResults,
    SearchResults? packageResults,
    List<String>? suggestions,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    SearchFilters? filters,
  }) {
    return SearchState(
      query: query ?? this.query,
      supplierResults: supplierResults ?? this.supplierResults,
      packageResults: packageResults ?? this.packageResults,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      filters: filters ?? this.filters,
    );
  }

  bool get hasResults =>
      (supplierResults?.hits.isNotEmpty ?? false) ||
      (packageResults?.hits.isNotEmpty ?? false);

  int get totalResults =>
      (supplierResults?.nbHits ?? 0) + (packageResults?.nbHits ?? 0);
}

// ==================== SEARCH FILTERS ====================

class SearchFilters {
  final String? category;
  final String? city;
  final double? minRating;
  final int? minPrice;
  final int? maxPrice;

  const SearchFilters({
    this.category,
    this.city,
    this.minRating,
    this.minPrice,
    this.maxPrice,
  });

  SearchFilters copyWith({
    String? category,
    String? city,
    double? minRating,
    int? minPrice,
    int? maxPrice,
    bool clearCategory = false,
    bool clearCity = false,
    bool clearMinRating = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return SearchFilters(
      category: clearCategory ? null : (category ?? this.category),
      city: clearCity ? null : (city ?? this.city),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
    );
  }

  bool get hasActiveFilters =>
      category != null ||
      city != null ||
      minRating != null ||
      minPrice != null ||
      maxPrice != null;

  SearchFilters clear() => const SearchFilters();
}

// ==================== SEARCH NOTIFIER ====================

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchService _searchService;

  SearchNotifier(this._searchService) : super(const SearchState());

  /// Initialize search service (call on app startup)
  Future<void> initialize({
    required String appId,
    required String apiKey,
  }) async {
    try {
      await _searchService.initialize(appId: appId, apiKey: apiKey);
    } catch (e) {
      debugPrint('❌ Failed to initialize search: $e');
    }
  }

  /// Update search query and fetch suggestions
  Future<void> updateQuery(String query) async {
    state = state.copyWith(query: query);

    if (query.length >= 2) {
      try {
        final suggestions = await _searchService.getSuggestions(query: query);
        state = state.copyWith(suggestions: suggestions);
      } catch (e) {
        debugPrint('❌ Error fetching suggestions: $e');
      }
    } else {
      state = state.copyWith(suggestions: []);
    }
  }

  /// Perform search for suppliers and packages
  Future<void> search({String? query}) async {
    final searchQuery = query ?? state.query;
    if (searchQuery.isEmpty) return;

    state = state.copyWith(
      query: searchQuery,
      isLoading: true,
      error: null,
    );

    try {
      // Search suppliers and packages in parallel
      final results = await Future.wait([
        _searchService.searchSuppliers(
          query: searchQuery,
          category: state.filters.category,
          city: state.filters.city,
          minRating: state.filters.minRating,
          minPrice: state.filters.minPrice,
          maxPrice: state.filters.maxPrice,
        ),
        _searchService.searchPackages(
          query: searchQuery,
          category: state.filters.category,
          minPrice: state.filters.minPrice,
          maxPrice: state.filters.maxPrice,
        ),
      ]);

      state = state.copyWith(
        supplierResults: results[0],
        packageResults: results[1],
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Search error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Erro na pesquisa: $e',
      );
    }
  }

  /// Load more supplier results
  Future<void> loadMoreSuppliers() async {
    if (state.isLoadingMore) return;
    if (state.supplierResults == null || !state.supplierResults!.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.supplierResults!.page + 1;
      final moreResults = await _searchService.searchSuppliers(
        query: state.query,
        category: state.filters.category,
        city: state.filters.city,
        minRating: state.filters.minRating,
        minPrice: state.filters.minPrice,
        maxPrice: state.filters.maxPrice,
        page: nextPage,
      );

      final combinedHits = [
        ...state.supplierResults!.hits,
        ...moreResults.hits,
      ];

      state = state.copyWith(
        supplierResults: SearchResults(
          hits: combinedHits,
          nbHits: moreResults.nbHits,
          page: moreResults.page,
          nbPages: moreResults.nbPages,
          hitsPerPage: moreResults.hitsPerPage,
          query: moreResults.query,
        ),
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('❌ Error loading more suppliers: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Update search filters
  void updateFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
  }

  /// Clear filters and re-search
  Future<void> clearFilters() async {
    state = state.copyWith(filters: const SearchFilters());
    if (state.query.isNotEmpty) {
      await search();
    }
  }

  /// Clear all search state
  void clear() {
    state = const SearchState();
  }
}

// ==================== PROVIDER ====================

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final searchService = ref.watch(searchServiceProvider);
  return SearchNotifier(searchService);
});

// ==================== RECENT SEARCHES PROVIDER ====================

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super([]);

  static const int _maxRecentSearches = 10;

  void addSearch(String query) {
    if (query.isEmpty) return;

    final updated = [
      query,
      ...state.where((s) => s != query),
    ].take(_maxRecentSearches).toList();

    state = updated;
  }

  void removeSearch(String query) {
    state = state.where((s) => s != query).toList();
  }

  void clearAll() {
    state = [];
  }
}
