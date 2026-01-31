import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/models/user_model.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/category_provider.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/providers/favorites_provider.dart';
import 'package:boda_connect/core/providers/client_view_provider.dart';
import 'package:boda_connect/core/providers/cart_provider.dart';
import 'package:boda_connect/core/providers/location_provider.dart';
import 'package:boda_connect/core/providers/suspension_provider.dart';
import 'package:boda_connect/core/providers/navigation_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/suspension_service.dart';
import 'package:boda_connect/core/widgets/loading_widget.dart';
import 'package:boda_connect/core/widgets/app_cached_image.dart';
import 'package:boda_connect/core/widgets/tier_badge.dart';
import 'package:boda_connect/features/common/presentation/widgets/warning_banner.dart';
import 'package:boda_connect/features/client/presentation/widgets/client_bottom_nav.dart';
import 'package:boda_connect/shared/widgets/network_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for header entrance animation
  late final AnimationController _headerAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize header animation (one-time entrance, 300ms)
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Start animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerAnimationController.forward();
    });

    // Load suppliers and request location when screen initializes
    Future.microtask(() {
      ref.read(browseSuppliersProvider.notifier).loadSuppliers();
      _requestLocationPermission();
      // Set nav index to home
      ref.read(clientNavIndexProvider.notifier).state = ClientNavTab.home.tabIndex;
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  /// Request location permission and update user location
  Future<void> _requestLocationPermission() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final hasPermission = await locationService.checkLocationPermission();

      if (hasPermission) {
        // Update user location in Firestore
        await locationService.updateUserLocation();
        debugPrint('✅ User location updated');
      } else {
        debugPrint('⚠️ Location permission not granted');
      }
    } catch (e) {
      debugPrint('❌ Error requesting location: $e');
    }
  }

  /// Get time-based greeting in Portuguese
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde';
    } else {
      return 'Boa noite';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.uid ?? '';
    final userRating = currentUser?.rating ?? 5.0;
    final isWideScreen = AppDimensions.isWideScreen(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NetworkIndicator(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(browseSuppliersProvider.notifier).loadSuppliers();
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = AppDimensions.getHorizontalPadding(context);
                final maxWidth = AppDimensions.getMaxContentWidth(context);

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(currentUser),
                          // Warning banner if user has violations
                          if (userId.isNotEmpty)
                            ref.watch(warningLevelProvider(userId)).when(
                              data: (level) => level != WarningLevel.none
                                ? WarningBanner(level: level, rating: userRating)
                                : const SizedBox.shrink(),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          _buildSearchBar(),
                          _buildEventBanner(),
                          _buildCategoriesSection(),
                          // For wide screens, show featured and nearby side by side
                          if (isWideScreen)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildFeaturedSection()),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildNearbySection()),
                                ],
                              ),
                            )
                          else ...[
                            _buildFeaturedSection(),
                            _buildNearbySection(),
                          ],
                          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: const ClientBottomNav(),
    );
  }

  Widget _buildHeader(UserModel? currentUser) {
    // PERFORMANCE: User data passed from parent build() to avoid duplicate watch
    // FIX: Handle empty string names - split('').first returns '' which bypasses ?? fallback
    final namePart = currentUser?.name?.split(' ').firstOrNull;
    final userName = (namePart != null && namePart.isNotEmpty) ? namePart : 'Cliente';
    final userLocation = currentUser?.location?.city ?? 'Luanda, Angola';

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Animated greeting with fade + slide entrance
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_getTimeBasedGreeting()}, $userName!', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: AppColors.peach,),
                      const SizedBox(width: 4),
                      Text(userLocation,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push(Routes.notifications),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_outlined,
                          color: AppColors.gray700,),
                    ),
                    // Notification Badge - UI-FIRST: Uses projection-based count
                    Consumer(
                      builder: (context, ref, child) {
                        // Use projection for real-time unread count
                        final unreadCount = ref.watch(clientUnreadNotificationsProvider);

                        if (unreadCount == 0) return const SizedBox.shrink();

                        return Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push(Routes.clientCart),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_cart_outlined,
                          color: AppColors.gray700,),
                    ),
                    // Cart Badge
                    Consumer(
                      builder: (context, ref, child) {
                        final cartItemCount = ref.watch(cartItemCountProvider);

                        if (cartItemCount == 0) return const SizedBox.shrink();

                        return Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.peach,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                cartItemCount > 99 ? '99+' : cartItemCount.toString(),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chat button with unread message count badge
              GestureDetector(
                onTap: () => context.push(Routes.chatList),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_outline,
                          color: AppColors.gray700,),
                    ),
                    // Message Badge - Uses projection-based count
                    Consumer(
                      builder: (context, ref, child) {
                        final unreadCount = ref.watch(clientUnreadMessagesProvider);

                        if (unreadCount == 0) return const SizedBox.shrink();

                        return Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.peach,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: GestureDetector(
        onTap: () => context.push(Routes.clientSearch),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.gray400),
              const SizedBox(width: 12),
              Text(
                'Pesquisar fornecedores...',
                style: AppTextStyles.body.copyWith(color: AppColors.gray400),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.peachLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: AppColors.peach, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventBanner() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.peach, AppColors.peachDark]),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planeje seu evento dos sonhos! ✨',
                  style: AppTextStyles.h3.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Encontre os melhores fornecedores para casamentos, aniversários e mais.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push(Routes.clientCategories),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.peach,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10,),
                  ),
                  child: const Text('Explorar'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.celebration, color: AppColors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final isWideScreen = AppDimensions.isWideScreen(context);
    final gridColumns = AppDimensions.getGridColumns(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categorias', style: AppTextStyles.h3),
              GestureDetector(
                onTap: () => context.push(Routes.clientCategories),
                child: Text('Ver todas',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.peach),),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final categories = ref.watch(featuredCategoriesProvider);

            if (categories.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text('Nenhuma categoria disponível'),
                ),
              );
            }

            // Use grid for wide screens, horizontal list for mobile
            if (isWideScreen) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: categories.length > gridColumns * 2
                      ? gridColumns * 2
                      : categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _buildCategoryItem(cat);
                  },
                ),
              );
            }

            return SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return GestureDetector(
                    onTap: () =>
                        context.push(Routes.clientCategoryDetail, extra: cat),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: cat.color,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(cat.icon,
                                  style: const TextStyle(fontSize: 28),),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryItem(dynamic cat) {
    return GestureDetector(
      onTap: () => context.push(Routes.clientCategoryDetail, extra: cat),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cat.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cat.name,
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    // Use real-time stream to ensure deleted suppliers are removed immediately
    final featuredSuppliersAsync = ref.watch(featuredSuppliersStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Destaques', style: AppTextStyles.h3),
              GestureDetector(
                onTap: () => context.push(Routes.clientSearch),
                child: Text('Ver todos',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.peach),),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: featuredSuppliersAsync.when(
            data: (featuredSuppliers) {
              if (featuredSuppliers.isEmpty) {
                return const Center(
                  child: Text('Nenhum fornecedor em destaque'),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                itemCount: featuredSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = featuredSuppliers[index];
                  return _buildSupplierCard(supplier);
                },
              );
            },
            loading: () => _buildFeaturedShimmer(),
            error: (error, _) => Center(
              child: Text(
                'Erro ao carregar destaques',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierCard(dynamic supplier) {
    // Support both SupplierModel and Map for backwards compatibility
    final supplierId = supplier is Map ? supplier['id'] as String : supplier.id;
    final name = supplier is Map ? supplier['name'] as String : supplier.businessName;
    final category = supplier is Map ? supplier['category'] as String : supplier.category;
    final rating = supplier is Map ? supplier['rating'] as double : supplier.rating;
    final reviews = supplier is Map ? supplier['reviews'] as int : supplier.reviewCount;
    final price = supplier is Map ? supplier['price'] as String : supplier.priceRange;
    final verified = supplier is Map ? supplier['verified'] as bool : supplier.isVerified;
    final tier = supplier is SupplierModel ? supplier.tier : SupplierTier.starter;

    // Get supplier photos - handle SupplierModel directly
    final List<String> photos = supplier is SupplierModel
        ? supplier.photos
        : (supplier is Map ? (supplier['photos'] as List<dynamic>?)?.cast<String>() ?? [] : []);
    final hasPhoto = photos.isNotEmpty;

    // Check if supplier is in favorites
    final favoritesState = ref.watch(favoritesProvider);
    final isFavorite = favoritesState.isFavorite(supplierId);

    return GestureDetector(
      onTap: () => context.push(Routes.clientSupplierDetail, extra: supplierId),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badges overlay using Stack
            SizedBox(
              height: 100,
              child: Stack(
                children: [
                  // Background image or placeholder
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppDimensions.radiusLg),),
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      color: AppColors.gray200,
                      child: hasPhoto
                          ? AppCachedImage(
                              imageUrl: photos.first,
                              fit: BoxFit.cover,
                              errorWidget: const Center(
                                child: Icon(Icons.store, color: AppColors.gray400, size: 40),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.store, color: AppColors.gray400, size: 40),
                            ),
                    ),
                  ),
                  // Tier badge and verified badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Tier indicator
                        TierIndicator(tier: tier),
                        if (tier != SupplierTier.starter && verified)
                          const SizedBox(height: 4),
                        // Verified badge
                        if (verified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2,),
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified,
                                    color: AppColors.white, size: 12,),
                                const SizedBox(width: 2),
                                Text('Verificado',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.white, fontSize: 9,),),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () async {
                        await ref.read(favoritesProvider.notifier).toggleFavorite(supplierId);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? AppColors.error : AppColors.peach,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: AppColors.warning, size: 14,),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1),
                          style: AppTextStyles.caption
                              .copyWith(fontWeight: FontWeight.w600),),
                      Text(' ($reviews)',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.peach, fontWeight: FontWeight.w600,),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbySection() {
    final suppliersState = ref.watch(browseSuppliersProvider);
    final suppliers = suppliersState.suppliers.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Perto de si', style: AppTextStyles.h3),
              GestureDetector(
                onTap: () => context.push(Routes.clientSearch),
                child: Text('Ver todos',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.peach),),
              ),
            ],
          ),
        ),
        if (suppliersState.isLoading)
          _buildNearbyShimmer()
        else if (suppliers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppDimensions.md),
            child: Center(child: Text('Nenhum fornecedor encontrado')),
          )
        else
          ...suppliers.map(_buildNearbyCard),
      ],
    );
  }

  Widget _buildNearbyCard(SupplierModel supplier) {
    return GestureDetector(
      onTap: () => context.push(Routes.clientSupplierDetail, extra: supplier.id),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppDimensions.md, 0, AppDimensions.md, 12,),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                height: 70,
                color: AppColors.gray200,
                child: supplier.photos.isNotEmpty
                    ? AppCachedImage(
                        imageUrl: supplier.photos.first,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorWidget: const Icon(Icons.store, color: AppColors.gray400),
                      )
                    : const Icon(Icons.store, color: AppColors.gray400),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          supplier.businessName,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TierIndicator(tier: supplier.tier),
                      if (supplier.tier != SupplierTier.starter && supplier.isVerified)
                        const SizedBox(width: 4),
                      if (supplier.isVerified)
                        const Icon(Icons.verified,
                            color: AppColors.info, size: 16,),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(supplier.category,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: AppColors.warning, size: 14,),
                      const SizedBox(width: 4),
                      Text(supplier.rating.toStringAsFixed(1),
                          style: AppTextStyles.caption
                              .copyWith(fontWeight: FontWeight.w600),),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on,
                          color: AppColors.gray400, size: 14,),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          supplier.location?.city ?? 'Luanda',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  supplier.priceRange,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.peach, fontWeight: FontWeight.w600,),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right, color: AppColors.gray400),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer loading for featured suppliers section
  Widget _buildFeaturedShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        itemCount: 3,
        itemBuilder: (context, index) {
          return ShimmerLoading(
            child: Container(
              width: 200,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppDimensions.radiusLg),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shimmer loading for nearby suppliers section
  Widget _buildNearbyShimmer() {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.md, 0, AppDimensions.md, 12,
          ),
          child: ShimmerLoading(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          margin: const EdgeInsets.only(right: 40),
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 100,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 140,
                          decoration: BoxDecoration(
                            color: AppColors.gray300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
