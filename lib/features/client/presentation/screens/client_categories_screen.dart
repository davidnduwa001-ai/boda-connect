import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/category_provider.dart';
import 'package:boda_connect/core/models/category_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClientCategoriesScreen extends ConsumerStatefulWidget {
  const ClientCategoriesScreen({super.key});

  @override
  ConsumerState<ClientCategoriesScreen> createState() => _ClientCategoriesScreenState();
}

class _ClientCategoriesScreenState extends ConsumerState<ClientCategoriesScreen> {
  final Set<int> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    // Use live counts provider for accurate supplier counts
    final categoriesAsync = ref.watch(categoriesWithLiveCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Categorias',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.gray700),
            onPressed: () => context.push(Routes.clientSearch),
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) => _buildContent(categories),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.peach)),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildContent(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate total suppliers across all categories
    final totalSuppliers = categories.fold<int>(0, (sum, c) => sum + c.supplierCount);

    return Column(
      children: [
        // Stats Header
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          color: AppColors.white,
          child: Row(
            children: [
              _buildStatCard(
                '${categories.length}',
                'Categorias',
                Icons.category_outlined,
                AppColors.peach,
              ),
              const SizedBox(width: AppDimensions.sm),
              _buildStatCard(
                '$totalSuppliers+',
                'Fornecedores',
                Icons.storefront_outlined,
                AppColors.info,
              ),
              const SizedBox(width: AppDimensions.sm),
              _buildStatCard(
                '${categories.length * 5}+',
                'Serviços',
                Icons.miscellaneous_services_outlined,
                AppColors.success,
              ),
            ],
          ),
        ),
        // Categories List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesWithLiveCountsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.md),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isExpanded = _expandedCategories.contains(index);
                return _buildCategoryCard(category, index, isExpanded);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: AppDimensions.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category, int index, bool isExpanded) {
    // Get subcategories from category model (loaded from Firestore)
    final subcategories = category.subcategories.isNotEmpty
        ? category.subcategories
        : ['Todos os serviços'];

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(index);
                } else {
                  _expandedCategories.add(index);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: isExpanded ? category.color.withValues(alpha: 0.1) : AppColors.white,
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(
                        top: Radius.circular(AppDimensions.radiusLg),
                      )
                    : BorderRadius.circular(AppDimensions.radiusLg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? AppColors.white
                          : category.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        category.icon,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${subcategories.length} tipos • ${category.supplierCount} fornecedores',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Subcategories
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  child: Column(
                    children: subcategories.map((subcategory) {
                      return _buildSubcategoryItem(subcategory, category);
                    }).toList(),
                  ),
                ),
                // View All Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.md,
                    0,
                    AppDimensions.md,
                    AppDimensions.md,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        context.push(
                          Routes.clientSearch,
                          extra: {'category': category.name},
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.peach,
                        side: const BorderSide(color: AppColors.peach),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Ver todos em ${category.name}'),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(String subcategory, CategoryModel category) {
    return GestureDetector(
      onTap: () {
        context.push(
          Routes.clientSearch,
          extra: {'category': category.name, 'subcategory': subcategory},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: category.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                subcategory,
                style: AppTextStyles.body,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.gray400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.peachLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined, size: 48, color: AppColors.peach),
          ),
          const SizedBox(height: 24),
          const Text('Nenhuma categoria disponível', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Verifique sua conexão e tente novamente',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Erro ao carregar categorias', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(categoriesWithLiveCountsProvider),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

}
