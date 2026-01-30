import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/favorites_provider.dart';
import 'package:boda_connect/core/providers/navigation_provider.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/widgets/loading_widget.dart';
import 'package:boda_connect/core/widgets/app_cached_image.dart';
import 'package:boda_connect/core/widgets/tier_badge.dart';
import 'package:boda_connect/features/client/presentation/widgets/client_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClientFavoritesScreen extends ConsumerStatefulWidget {
  const ClientFavoritesScreen({super.key});

  @override
  ConsumerState<ClientFavoritesScreen> createState() => _ClientFavoritesScreenState();
}

class _ClientFavoritesScreenState extends ConsumerState<ClientFavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // Load favorites when screen opens
    Future.microtask(() {
      ref.read(favoritesProvider.notifier).loadFavorites();
      // Set nav index to favorites
      ref.read(clientNavIndexProvider.notifier).state = ClientNavTab.favorites.tabIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(favoritesProvider);
    final favorites = favoritesState.favoriteSuppliers;

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
          'Favoritos',
          style: AppTextStyles.h3.copyWith(color: AppColors.gray900),
        ),
        centerTitle: true,
        actions: [
          if (favorites.isNotEmpty)
            TextButton(
              onPressed: _showClearAllDialog,
              child: Text(
                'Limpar',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
      body: favoritesState.isLoading
          ? const ShimmerListLoading(itemCount: 4, itemHeight: 100)
          : favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(favorites),
      bottomNavigationBar: const ClientBottomNav(),
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
            child: const Icon(
              Icons.favorite_outline,
              size: 48,
              color: AppColors.peach,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Nenhum favorito ainda', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Explore fornecedores e adicione\naos seus favoritos',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push(Routes.clientSearch),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: const Text('Explorar Fornecedores'),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(List<SupplierModel> favorites) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: favorites.length,
      itemBuilder: (context, index) => _buildFavoriteCard(favorites[index]),
    );
  }

  Widget _buildFavoriteCard(SupplierModel supplier) {
    return Dismissible(
      key: Key(supplier.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: const Icon(Icons.delete, color: AppColors.white),
      ),
      onDismissed: (direction) {
        _removeFavorite(supplier);
      },
      child: GestureDetector(
        onTap: () => context.push(Routes.clientSupplierDetail, extra: supplier.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              // Supplier Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    if (supplier.photos.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppCachedImage(
                          imageUrl: supplier.photos.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: const Center(
                            child: Icon(Icons.store, color: AppColors.gray400, size: 32),
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(Icons.store, color: AppColors.gray400, size: 32),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => _removeFavorite(supplier),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: AppColors.error,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Supplier Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            supplier.businessName,
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TierIndicator(tier: supplier.tier),
                        if (supplier.tier != SupplierTier.starter && supplier.isVerified)
                          const SizedBox(width: 4),
                        if (supplier.isVerified)
                          const Icon(Icons.verified, color: AppColors.info, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      supplier.category,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.warning, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          supplier.rating.toStringAsFixed(1),
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          ' (${supplier.reviewCount})',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on, color: AppColors.gray400, size: 14),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            supplier.location?.city ?? 'Luanda',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      supplier.priceRange,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.peach,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  void _removeFavorite(SupplierModel supplier) async {
    final success = await ref.read(favoritesProvider.notifier).removeFavorite(supplier.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${supplier.businessName} removido dos favoritos'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              ref.read(favoritesProvider.notifier).addFavorite(supplier.id);
            },
          ),
        ),
      );
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Favoritos?'),
        content: const Text(
          'Tem certeza que deseja remover todos os fornecedores dos seus favoritos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(favoritesProvider.notifier).clearAllFavorites();
            },
            child: const Text('Limpar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
