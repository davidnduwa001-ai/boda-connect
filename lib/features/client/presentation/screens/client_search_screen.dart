import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/providers/category_provider.dart';
import 'package:boda_connect/core/providers/favorites_provider.dart';
import 'package:boda_connect/core/providers/navigation_provider.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/widgets/app_cached_image.dart';
import 'package:boda_connect/core/widgets/tier_badge.dart';
import 'package:boda_connect/features/client/presentation/widgets/client_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClientSearchScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final String? initialSubcategory;

  const ClientSearchScreen({
    super.key,
    this.initialCategory,
    this.initialSubcategory,
  });

  @override
  ConsumerState<ClientSearchScreen> createState() => _ClientSearchScreenState();
}

class _ClientSearchScreenState extends ConsumerState<ClientSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _showFilters = false;
  String? _selectedCategoryId;
  RangeValues _priceRange = const RangeValues(0, 500000);
  double _minRating = 0;
  String _sortBy = 'relevance';

  final List<String> _popularSearches = [
    '💍 Casamento',
    '🎂 Aniversário',
    '🏢 Corporativo',
    '🎓 Formatura',
    '👶 Batizado',
    '🎉 Festa',
  ];

  final List<String> _recentSearches = [];
  bool _hasSearched = false;

  // ValueNotifier to track if search text is not empty (for clear button visibility)
  // This avoids rebuilding the entire widget on every keystroke
  final _hasSearchTextNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    // Listen to search controller for clear button visibility
    _searchController.addListener(_onSearchTextChanged);

    // Check if initial category was passed
    if (widget.initialCategory != null) {
      _selectedCategoryId = widget.initialCategory;
      _hasSearched = true; // Show results immediately when category is pre-selected
    } else {
      _searchFocusNode.requestFocus();
    }

    Future.microtask(() {
      // Set nav index to search
      ref.read(clientNavIndexProvider.notifier).state = ClientNavTab.search.tabIndex;

      // Load suppliers based on initial category
      if (widget.initialCategory != null) {
        ref.read(browseSuppliersProvider.notifier).filterByCategory(
          widget.initialCategory,
        );
      } else {
        ref.read(browseSuppliersProvider.notifier).loadSuppliers();
      }
    });
  }

  void _onSearchTextChanged() {
    _hasSearchTextNotifier.value = _searchController.text.isNotEmpty;

    // Auto-search after 2+ characters with debounce
    final value = _searchController.text;
    if (value.length >= 2) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // Only search if the value hasn't changed
        if (_searchController.text == value && mounted) {
          _performSearch();
        }
      });
    } else if (value.isEmpty && _hasSearched) {
      setState(() => _hasSearched = false);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _hasSearchTextNotifier.dispose();
    super.dispose();
  }

  void _performSearch() {
    if (_searchController.text.isNotEmpty || _selectedCategoryId != null) {
      setState(() => _hasSearched = true);
      _searchFocusNode.unfocus();

      // Get filter values (only pass if they're meaningful)
      final minRating = _minRating > 0 ? _minRating : null;
      final query = _searchController.text.trim();

      // CATEGORY-STRICT SEARCH: When category is selected, search ONLY within that category
      if (_selectedCategoryId != null && query.isNotEmpty) {
        // Use category-strict search to prevent cross-category pollution
        ref.read(browseSuppliersProvider.notifier).searchInCategory(
          query,
          _selectedCategoryId!,
          minRating: minRating,
        );
      } else if (_selectedCategoryId != null) {
        // Filter by category only (no search query)
        ref.read(browseSuppliersProvider.notifier).filterByCategory(
          _selectedCategoryId,
          minRating: minRating,
        );
      } else if (query.isNotEmpty) {
        // Search across all categories (no category filter)
        ref.read(browseSuppliersProvider.notifier).searchSuppliers(
          query,
          minRating: minRating,
        );
      } else {
        // No filters - load all suppliers
        ref.read(browseSuppliersProvider.notifier).loadSuppliers(
          minRating: minRating,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final browseState = ref.watch(browseSuppliersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_showFilters) _buildFiltersPanel(categoriesAsync),
            _buildCategoryChips(categoriesAsync),
            if (!_hasSearched) ...[
              Expanded(child: _buildSearchSuggestions()),
            ] else ...[
              _buildResultsHeader(browseState.suppliers.length),
              Expanded(child: _buildSearchResults(browseState)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const ClientBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      color: AppColors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.gray700,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: _hasSearchTextNotifier,
                builder: (context, hasText, child) {
                  return TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onSubmitted: (_) => _performSearch(),
                    decoration: InputDecoration(
                      hintText: 'Buscar fornecedores...',
                      hintStyle: AppTextStyles.body.copyWith(
                        color: AppColors.gray400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.gray400,
                        size: 20,
                      ),
                      suffixIcon: hasText
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _hasSearched = false);
                              },
                              child: const Icon(
                                Icons.close,
                                color: AppColors.gray400,
                                size: 18,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: 12,
                      ),
                    ),
                    style: AppTextStyles.body,
                    // No onChanged needed - listener handles text changes
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _showFilters ? AppColors.peach : AppColors.gray100,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(
                Icons.tune,
                color: _showFilters ? AppColors.white : AppColors.gray700,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(AsyncValue categoriesAsync) {
    return categoriesAsync.when(
      data: (categories) {
        final allCategories = [
          {'id': null, 'name': 'Todos', 'icon': Icons.apps},
          ...categories.map((c) => {
                'id': c.id,
                'name': c.name,
                'icon': Icons.category,
              })
        ];

        return Container(
          height: 50,
          color: AppColors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: AppDimensions.xs,
            ),
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final category = allCategories[index];
              final isSelected = _selectedCategoryId == category['id'] ||
                  (_selectedCategoryId == null && index == 0);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryId = index == 0 ? null : category['id'] as String?;
                  });
                  if (_hasSearched) {
                    _performSearch();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.peach : AppColors.gray100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        size: 16,
                        color: isSelected ? AppColors.white : AppColors.gray700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category['name'] as String,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected ? AppColors.white : AppColors.gray700,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 50),
      error: (_, __) => const SizedBox(height: 50),
    );
  }

  Widget _buildFiltersPanel(AsyncValue categoriesAsync) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Faixa de Preço',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          RangeSlider(
            values: _priceRange,
            max: 500000,
            divisions: 50,
            activeColor: AppColors.peach,
            inactiveColor: AppColors.gray200,
            labels: RangeLabels(
              '${(_priceRange.start / 1000).toInt()}k Kz',
              '${(_priceRange.end / 1000).toInt()}k Kz',
            ),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_priceRange.start / 1000).toInt()}k Kz',
                style: AppTextStyles.caption,
              ),
              Text(
                '${(_priceRange.end / 1000).toInt()}k Kz',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          Text(
            'Avaliação Mínima',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: List.generate(5, (index) {
              final rating = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _minRating = rating.toDouble()),
                child: Container(
                  margin: const EdgeInsets.only(right: AppDimensions.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _minRating >= rating
                        ? AppColors.warning.withValues(alpha: 0.2)
                        : AppColors.gray100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _minRating >= rating
                          ? AppColors.warning
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 14,
                        color: _minRating >= rating
                            ? AppColors.warning
                            : AppColors.gray400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$rating+',
                        style: AppTextStyles.caption.copyWith(
                          color: _minRating >= rating
                              ? AppColors.warning
                              : AppColors.gray700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppDimensions.md),

          Text(
            'Ordenar Por',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.xs,
            children: [
              _buildSortChip('relevance', 'Relevância'),
              _buildSortChip('rating', 'Avaliação'),
              _buildSortChip('price_low', 'Menor Preço'),
              _buildSortChip('price_high', 'Maior Preço'),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _priceRange = const RangeValues(0, 500000);
                      _minRating = 0;
                      _sortBy = 'relevance';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gray700,
                    side: const BorderSide(color: AppColors.gray300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _showFilters = false);
                    _performSearch();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peach,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Aplicar Filtros'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String value, String label) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peach : AppColors.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? AppColors.white : AppColors.gray700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buscas Recentes',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_recentSearches.clear),
                  child: Text(
                    'Limpar',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.peachDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            ...List.generate(_recentSearches.length, (index) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.history,
                  color: AppColors.gray400,
                  size: 20,
                ),
                title: Text(
                  _recentSearches[index],
                  style: AppTextStyles.body,
                ),
                trailing: const Icon(
                  Icons.north_west,
                  color: AppColors.gray400,
                  size: 16,
                ),
                onTap: () {
                  _searchController.text = _recentSearches[index];
                  _performSearch();
                },
              );
            }),
            const SizedBox(height: AppDimensions.lg),
          ],

          Text(
            'Buscas Populares',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: _popularSearches.map((search) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = search.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                  _performSearch();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    search,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count resultados encontrados',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: AppColors.gray700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ver mapa',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.gray700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Apply client-side filters to search results
  List<SupplierModel> _applyFilters(List<SupplierModel> suppliers) {
    var filtered = suppliers.where((supplier) {
      // Filter by minimum rating
      if (_minRating > 0 && supplier.rating < _minRating) return false;

      // Filter by price range (using supplier's minPrice field)
      final supplierMinPrice = supplier.minPrice ?? 0;
      final supplierMaxPrice = supplier.maxPrice ?? supplierMinPrice;

      // Only filter if price range has been adjusted from defaults
      if (_priceRange.start > 0 || _priceRange.end < 500000) {
        // Supplier must have some price overlap with the filter range
        // Skip suppliers with no price info (priceOnRequest or no minPrice)
        if (!supplier.priceOnRequest && supplierMinPrice > 0) {
          // Check if supplier's price range overlaps with filter range
          if (supplierMinPrice > _priceRange.end) return false;
          if (supplierMaxPrice > 0 && supplierMaxPrice < _priceRange.start) return false;
        }
      }

      return true;
    }).toList();

    // Apply sorting
    switch (_sortBy) {
      case 'rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'price_low':
        // Sort by minPrice ascending (cheapest first)
        filtered.sort((a, b) {
          final priceA = a.minPrice ?? 999999999;
          final priceB = b.minPrice ?? 999999999;
          return priceA.compareTo(priceB);
        });
        break;
      case 'price_high':
        // Sort by minPrice descending (most expensive first)
        filtered.sort((a, b) {
          final priceA = a.minPrice ?? 0;
          final priceB = b.minPrice ?? 0;
          return priceB.compareTo(priceA);
        });
        break;
      case 'relevance':
      default:
        // Keep original order (relevance from search)
        break;
    }

    return filtered;
  }

  Widget _buildSearchResults(BrowseSuppliersState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.peach));
    }

    if (state.error != null) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(browseSuppliersProvider.notifier).loadSuppliers();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(state.error!, style: AppTextStyles.body),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Apply filters to search results
    final filteredSuppliers = _applyFilters(state.suppliers);

    if (filteredSuppliers.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(browseSuppliersProvider.notifier).loadSuppliers();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: AppColors.gray400),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum fornecedor encontrado',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                  if (state.suppliers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tente ajustar os filtros',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray400),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedCategoryId != null) {
          await ref.read(browseSuppliersProvider.notifier).filterByCategory(_selectedCategoryId);
        } else {
          await ref.read(browseSuppliersProvider.notifier).loadSuppliers();
        }
      },
      child: CustomScrollView(
        slivers: [
          // CATEGORY-FILTERED DESTAQUE SECTION
          // Only shows when a category is selected - ensures featured suppliers match the category
          if (_selectedCategoryId != null) ...[
            SliverToBoxAdapter(
              child: _buildCategoryFeaturedSection(_selectedCategoryId!),
            ),
          ],

          // Regular search results
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final supplier = filteredSuppliers[index];
                  return _buildResultCard(supplier);
                },
                childCount: filteredSuppliers.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a category-filtered "Destaque" section
  /// Only shows featured suppliers within the selected category
  Widget _buildCategoryFeaturedSection(String category) {
    final featuredAsync = ref.watch(categoryFeaturedSuppliersProvider(category));

    return featuredAsync.when(
      data: (featuredSuppliers) {
        if (featuredSuppliers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.md,
                AppDimensions.sm,
                AppDimensions.md,
                AppDimensions.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: AppColors.premium,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Destaques em $category',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                itemCount: featuredSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = featuredSuppliers[index];
                  return _buildFeaturedCard(supplier);
                },
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: Text(
                'Todos os Fornecedores',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Builds a compact featured supplier card for horizontal scrolling
  Widget _buildFeaturedCard(SupplierModel supplier) {
    final favoritesState = ref.watch(favoritesProvider);
    final isFavorite = favoritesState.isFavorite(supplier.id);

    return GestureDetector(
      onTap: () => context.push(Routes.clientSupplierDetail, extra: supplier.id),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badges
            SizedBox(
              height: 90,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusMd),
                    ),
                    child: Container(
                      height: 90,
                      width: double.infinity,
                      color: AppColors.gray200,
                      child: supplier.photos.isNotEmpty
                          ? AppCachedImage(
                              imageUrl: supplier.photos.first,
                              fit: BoxFit.cover,
                              errorWidget: const Center(
                                child: Icon(Icons.store, color: AppColors.gray400, size: 32),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.store, color: AppColors.gray400, size: 32),
                            ),
                    ),
                  ),
                  // Premium badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.premium,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium, color: AppColors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            'Destaque',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () async {
                        await ref.read(favoritesProvider.notifier).toggleFavorite(supplier.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? AppColors.error : AppColors.gray400,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.businessName,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.warning, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          supplier.rating.toStringAsFixed(1),
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' (${supplier.reviewCount})',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      supplier.priceRange,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.peach,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(SupplierModel supplier) {
    // Check if supplier is in favorites
    final favoritesState = ref.watch(favoritesProvider);
    final isFavorite = favoritesState.isFavorite(supplier.id);

    return GestureDetector(
      onTap: () => context.push(Routes.clientSupplierDetail, extra: supplier.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusMd),
                  ),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    color: AppColors.gray200,
                    child: supplier.photos.isNotEmpty
                        ? AppCachedImage(
                            imageUrl: supplier.photos.first,
                            fit: BoxFit.cover,
                            errorWidget: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: AppColors.gray400,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: AppColors.gray400,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: AppDimensions.sm,
                  left: AppDimensions.sm,
                  child: Row(
                    children: [
                      TierIndicator(tier: supplier.tier),
                      if (supplier.tier != SupplierTier.starter && supplier.isVerified)
                        const SizedBox(width: 6),
                      if (supplier.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified,
                                size: 12,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Verificado',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (supplier.isFeatured) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.premium,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                size: 12,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Premium',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: AppDimensions.sm,
                  right: AppDimensions.sm,
                  child: GestureDetector(
                    onTap: () async {
                      await ref.read(favoritesProvider.notifier).toggleFavorite(supplier.id);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_outline,
                        size: 18,
                        color: isFavorite ? AppColors.error : AppColors.gray700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          supplier.businessName,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            supplier.rating.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' (${supplier.reviewCount})',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    supplier.category,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.peachDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.gray400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        supplier.location?.city ?? 'Luanda',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        supplier.priceRange,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: AppDimensions.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Text(
                          'Ver Perfil',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
