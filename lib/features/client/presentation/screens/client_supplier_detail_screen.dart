import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/providers/favorites_provider.dart';
import 'package:boda_connect/core/providers/reviews_provider.dart';
import 'package:boda_connect/core/providers/booking_provider.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/supplier_stats_provider.dart';
import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/models/package_model.dart';
import 'package:boda_connect/core/models/review_category_models.dart';
import 'package:boda_connect/core/services/deep_link_service.dart';
import 'package:boda_connect/core/widgets/app_cached_image.dart';
import 'package:boda_connect/core/widgets/tier_badge.dart';
import 'package:boda_connect/features/client/presentation/widgets/availability_calendar_widget.dart';
import 'package:boda_connect/features/client/presentation/widgets/submit_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ClientSupplierDetailScreen extends ConsumerStatefulWidget {

  const ClientSupplierDetailScreen({super.key, this.supplierId});
  final String? supplierId;

  @override
  ConsumerState<ClientSupplierDetailScreen> createState() => _ClientSupplierDetailScreenState();
}

class _ClientSupplierDetailScreenState extends ConsumerState<ClientSupplierDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentImageIndex = 0;
  DateTime? _selectedAvailabilityDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 tabs now

    // Load favorites and track profile view
    Future.microtask(() {
      ref.read(favoritesProvider.notifier).loadFavorites();

      // Track profile view (passive view when page loads)
      final supplierId = widget.supplierId;
      final currentUser = ref.read(currentUserProvider);
      if (supplierId != null && currentUser != null) {
        ref.read(supplierStatsProvider(supplierId).notifier).trackView(
          currentUser.uid,
          source: 'supplier_detail',
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supplierId = widget.supplierId;

    if (supplierId == null || supplierId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Fornecedor não encontrado')),
      );
    }

    final supplierAsync = ref.watch(supplierDetailProvider(supplierId));
    final packagesAsync = ref.watch(supplierPackagesDetailProvider(supplierId));
    final reviewsAsync = ref.watch(reviewsProvider(supplierId));

    return supplierAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.peach)),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('Erro ao carregar fornecedor: $error')),
      ),
      data: (supplier) {
        if (supplier == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Erro')),
            body: const Center(child: Text('Fornecedor não encontrado')),
          );
        }

        final packages = packagesAsync.asData?.value ?? [];
        final reviews = reviewsAsync.asData?.value ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(supplier),
              SliverToBoxAdapter(child: _buildHeaderInfo(supplier)),
              SliverToBoxAdapter(child: _buildTabBar()),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAboutTab(supplier),
                    _buildPortfolioTab(supplier),
                    _buildPackagesTab(packages),
                    _buildReviewsTab(supplier, reviews),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(supplier),
        );
      },
    );
  }

  Widget _buildSliverAppBar(SupplierModel supplier) {
    final favoritesState = ref.watch(favoritesProvider);
    final isFavorite = favoritesState.isFavorite(supplier.id);
    final images = supplier.photos.isNotEmpty ? supplier.photos : [''];

    // Responsive height based on screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight < 600 ? 200.0 : (screenHeight < 800 ? 250.0 : 280.0);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.white,
      leading: _buildCircleButton(Icons.arrow_back, () => context.pop()),
      actions: [
        _buildCircleButton(Icons.share_outlined, () => _shareSupplier(supplier)),
        const SizedBox(width: 8),
        _buildCircleButton(
          isFavorite ? Icons.favorite : Icons.favorite_outline,
          () => _toggleFavorite(supplier.id),
          iconColor: isFavorite ? AppColors.error : AppColors.gray900,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            if (images.isNotEmpty && images.first.isNotEmpty)
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _currentImageIndex = i),
                itemBuilder: (context, index) => ColoredBox(
                  color: AppColors.gray200,
                  child: AppCachedImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    errorWidget: const Center(
                      child: Icon(Icons.image, size: 64, color: AppColors.gray400),
                    ),
                  ),
                ),
              )
            else
              const ColoredBox(
                color: AppColors.gray200,
                child: Center(
                  child: Icon(Icons.business, size: 64, color: AppColors.gray400),
                ),
              ),
            if (images.isNotEmpty && images.first.isNotEmpty && images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == i
                            ? AppColors.white
                            : AppColors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            if (images.isNotEmpty && images.first.isNotEmpty)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1}/${images.length}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(String supplierId) async {
    final favoritesState = ref.read(favoritesProvider);
    if (favoritesState.isFavorite(supplierId)) {
      await ref.read(favoritesProvider.notifier).removeFavorite(supplierId);
    } else {
      await ref.read(favoritesProvider.notifier).addFavorite(supplierId);
    }
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, {Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor ?? AppColors.gray900, size: 20),
      ),
    );
  }

  Widget _buildHeaderInfo(SupplierModel supplier) {
    final location = supplier.location?.city ?? 'Luanda';

    // Watch calculated response time from provider
    final responseTimeAsync = ref.watch(supplierResponseTimeProvider(supplier.id));
    final responseTimeDisplay = responseTimeAsync.when(
      loading: () => '...',
      error: (_, __) => supplier.responseTime ?? '-',
      data: (stats) => stats.displayText,
    );

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TierBadge(tier: supplier.tier),
              if (supplier.tier != SupplierTier.starter && supplier.isVerified)
                const SizedBox(width: 8),
              if (supplier.isVerified)
                _buildBadge('Verificado', Icons.verified, AppColors.info, AppColors.infoLight),
              if (supplier.isFeatured) ...[
                const SizedBox(width: 8),
                _buildBadge('Premium', Icons.workspace_premium, AppColors.premium, AppColors.premiumLight),
              ],
              if (_isNewMember(supplier)) ...[
                const SizedBox(width: 8),
                _buildBadge('Novo Membro', Icons.fiber_new, AppColors.success, AppColors.successLight),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(supplier.businessName, style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(
            supplier.category,
            style: AppTextStyles.body.copyWith(
              color: AppColors.peachDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              const Icon(Icons.star, size: 18, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(
                supplier.rating.toStringAsFixed(1),
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                ' (${supplier.reviewCount} avaliações)',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppDimensions.md),
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.gray400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          // Stats row with real-time data
          Row(
            children: [
              _buildStatItem(Icons.visibility_outlined, '${supplier.viewCount}', 'Visualizações'),
              _buildStatItem(Icons.favorite_outline, '${supplier.favoriteCount}', 'Favoritos'),
              _buildStatItem(Icons.event_available_outlined, '${supplier.confirmedBookings}', 'Agendados'),
              _buildStatItem(Icons.check_circle_outline, '${supplier.completedBookings}', 'Concluídos'),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              _buildStatItem(Icons.speed_outlined, '${supplier.responseRate.toInt()}%', 'Taxa resposta'),
              _buildStatItem(Icons.timer_outlined, responseTimeDisplay, 'Responde em'),
              _buildStatItem(Icons.schedule_outlined, _getMemberSince(supplier), 'Membro desde'),
            ],
          ),
        ],
      ),
    );
  }

  String _getMemberSince(SupplierModel supplier) {
    final years = DateTime.now().difference(supplier.createdAt).inDays ~/ 365;
    if (years >= 1) return '$years ${years == 1 ? 'ano' : 'anos'}';
    final months = DateTime.now().difference(supplier.createdAt).inDays ~/ 30;
    if (months >= 1) return '$months ${months == 1 ? 'mês' : 'meses'}';
    return 'Novo';
  }

  /// Check if supplier is a new member (joined within last 90 days)
  bool _isNewMember(SupplierModel supplier) {
    final daysSinceJoined = DateTime.now().difference(supplier.createdAt).inDays;
    return daysSinceJoined <= 90;
  }

  Widget _buildBadge(String text, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        margin: const EdgeInsets.only(right: AppDimensions.xs),
        decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        child: Column(children: [
          Icon(icon, size: 20, color: AppColors.gray700),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10)),
        ],),
      ),
    );
  }

  Widget _buildTabBar() {
    return ColoredBox(
      color: AppColors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.peach,
        unselectedLabelColor: AppColors.gray400,
        indicatorColor: AppColors.peach,
        labelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Sobre'),
          Tab(text: 'Portfólio'),
          Tab(text: 'Pacotes'),
          Tab(text: 'Avaliações'),
        ],
      ),
    );
  }

  Widget _buildAboutTab(SupplierModel supplier) {
    final location = supplier.location?.city != null
        ? '${supplier.location!.city}${supplier.location!.province != null ? ', ${supplier.location!.province}' : ''}'
        : 'Luanda';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          const Text('Descrição', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          Text(
            supplier.description,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),

          // Subcategories/Services
          if (supplier.subcategories.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.lg),
            const Text('Serviços', style: AppTextStyles.h3),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supplier.subcategories.map((service) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.peach.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    service,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.peachDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Languages
          if (supplier.languages.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.lg),
            _buildLanguagesSection(supplier.languages),
          ],

          // Working Hours
          if (supplier.workingHours != null) ...[
            const SizedBox(height: AppDimensions.lg),
            _buildWorkingHoursSection(supplier.workingHours!),
          ],

          // Social Links
          if (supplier.socialLinks != null && supplier.socialLinks!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.lg),
            _buildSocialLinksSection(supplier.socialLinks!),
          ],

          // Trust Signals
          const SizedBox(height: AppDimensions.lg),
          _buildTrustSignalsSection(supplier),

          // Statistics
          const SizedBox(height: AppDimensions.lg),
          _buildStatisticsSection(supplier),

          // Availability Calendar
          const SizedBox(height: AppDimensions.lg),
          _buildAvailabilitySection(supplier),

          // Location
          const SizedBox(height: AppDimensions.lg),
          const Text('Localização', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          _buildContactItem(Icons.location_on_outlined, location),
          const SizedBox(height: AppDimensions.sm),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.peach.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.peach.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.peach, size: 20),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    'Por segurança, use apenas as mensagens do app para comunicar com fornecedores',
                    style: AppTextStyles.caption.copyWith(color: AppColors.peach),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          _buildMapSection(supplier),

          // Contact Information (only visible after confirmed booking)
          const SizedBox(height: AppDimensions.lg),
          _buildContactRevealSection(supplier),
          const SizedBox(height: AppDimensions.lg),
        ],
      ),
    );
  }

  // ==================== CONTACT REVEAL SECTION ====================
  Widget _buildContactRevealSection(SupplierModel supplier) {
    final contactVisibilityAsync = ref.watch(supplierContactVisibilityProvider(supplier.id));

    return contactVisibilityAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (visibility) {
        // Check if supplier has any contact info to show
        final hasPhone = supplier.phone != null && supplier.phone!.isNotEmpty;
        final hasWhatsapp = supplier.whatsapp != null && supplier.whatsapp!.isNotEmpty;
        final hasEmail = supplier.email != null && supplier.email!.isNotEmpty;

        if (!hasPhone && !hasWhatsapp && !hasEmail) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  visibility.hasActiveBooking ? Icons.contact_phone : Icons.lock_outline,
                  size: 20,
                  color: visibility.hasActiveBooking ? AppColors.success : AppColors.gray700,
                ),
                const SizedBox(width: 8),
                Text(
                  visibility.hasActiveBooking ? 'Informações de Contacto' : 'Contacto Directo',
                  style: AppTextStyles.h3,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),

            if (visibility.hasActiveBooking) ...[
              // Show contact info - booking confirmed
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.successLight, width: 2),
                ),
                child: Column(
                  children: [
                    // Success banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm, horizontal: AppDimensions.md),
                      margin: const EdgeInsets.only(bottom: AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, size: 18, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reserva confirmada - contacto desbloqueado',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Phone
                    if (hasPhone)
                      _buildContactRevealItem(
                        icon: Icons.phone,
                        label: 'Telefone',
                        value: supplier.phone!,
                        color: AppColors.info,
                        onTap: () {
                          // Track call click (high-value interaction)
                          final currentUser = ref.read(currentUserProvider);
                          if (currentUser != null) {
                            ref.read(supplierStatsProvider(supplier.id).notifier)
                                .trackCallClick(currentUser.uid);
                          }
                          _launchPhone(supplier.phone!);
                        },
                      ),
                    // WhatsApp
                    if (hasWhatsapp) ...[
                      if (hasPhone) const SizedBox(height: AppDimensions.sm),
                      _buildContactRevealItem(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        value: supplier.whatsapp!,
                        color: const Color(0xFF25D366),
                        onTap: () {
                          // Track WhatsApp click (high-value interaction)
                          final currentUser = ref.read(currentUserProvider);
                          if (currentUser != null) {
                            ref.read(supplierStatsProvider(supplier.id).notifier)
                                .trackWhatsAppClick(currentUser.uid);
                          }
                          _launchWhatsApp(supplier.whatsapp!);
                        },
                      ),
                    ],
                    // Email
                    if (hasEmail) ...[
                      if (hasPhone || hasWhatsapp) const SizedBox(height: AppDimensions.sm),
                      _buildContactRevealItem(
                        icon: Icons.email,
                        label: 'Email',
                        value: supplier.email!,
                        color: AppColors.peach,
                        onTap: () => _launchEmail(supplier.email!),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // Show locked state - no confirmed booking
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Lock icon and message
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: const Icon(Icons.lock, size: 32, color: AppColors.gray400),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contacto protegido',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'As informações de contacto directo ficam disponíveis após a confirmação da sua reserva.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    // Preview of what's available (blurred/hidden)
                    Row(
                      children: [
                        if (hasPhone)
                          _buildLockedContactPreview(Icons.phone, 'Telefone'),
                        if (hasPhone && (hasWhatsapp || hasEmail))
                          const SizedBox(width: AppDimensions.sm),
                        if (hasWhatsapp)
                          _buildLockedContactPreview(Icons.chat, 'WhatsApp'),
                        if (hasWhatsapp && hasEmail)
                          const SizedBox(width: AppDimensions.sm),
                        if (hasEmail)
                          _buildLockedContactPreview(Icons.email, 'Email'),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    // CTA to book
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.sm),
                      decoration: BoxDecoration(
                        color: AppColors.peach.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.peach),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Faça uma reserva para desbloquear o contacto directo',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.peachDark,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildContactRevealItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.white),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedContactPreview(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm, horizontal: AppDimensions.xs),
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.gray400),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.gray400,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 60,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Remove any non-numeric characters except +
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ==================== LANGUAGES SECTION ====================
  Widget _buildLanguagesSection(List<String> languages) {
    final languageData = {
      'pt': {'name': 'Português', 'flag': '🇵🇹'},
      'en': {'name': 'English', 'flag': '🇬🇧'},
      'fr': {'name': 'Français', 'flag': '🇫🇷'},
      'es': {'name': 'Español', 'flag': '🇪🇸'},
      'zh': {'name': '中文', 'flag': '🇨🇳'},
      'ar': {'name': 'العربية', 'flag': '🇸🇦'},
      'ru': {'name': 'Русский', 'flag': '🇷🇺'},
      'de': {'name': 'Deutsch', 'flag': '🇩🇪'},
      'it': {'name': 'Italiano', 'flag': '🇮🇹'},
      'umbundu': {'name': 'Umbundu', 'flag': '🇦🇴'},
      'kimbundu': {'name': 'Kimbundu', 'flag': '🇦🇴'},
      'kikongo': {'name': 'Kikongo', 'flag': '🇦🇴'},
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.translate, size: 20, color: AppColors.gray700),
            const SizedBox(width: 8),
            const Text('Idiomas', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: languages.map((lang) {
            final data = languageData[lang];
            final flag = data?['flag'] ?? '';
            final name = data?['name'] ?? lang;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (flag.isNotEmpty) ...[
                    Text(flag, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    name,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.gray700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== WORKING HOURS SECTION ====================
  Widget _buildWorkingHoursSection(WorkingHours workingHours) {
    final dayNames = {
      'monday': 'Segunda',
      'tuesday': 'Terça',
      'wednesday': 'Quarta',
      'thursday': 'Quinta',
      'friday': 'Sexta',
      'saturday': 'Sábado',
      'sunday': 'Domingo',
    };

    final orderedDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, size: 20, color: AppColors.gray700),
            const SizedBox(width: 8),
            const Text('Horário de Funcionamento', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: orderedDays.map((day) {
              final hours = workingHours.schedule[day];
              final isOpen = hours?.isOpen ?? false;
              final isToday = _isToday(day);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        dayNames[day] ?? day,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday ? AppColors.peach : AppColors.gray700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        isOpen
                            ? '${hours?.openTime ?? '09:00'} - ${hours?.closeTime ?? '18:00'}'
                            : 'Fechado',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isOpen ? AppColors.success : AppColors.error,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Hoje',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  bool _isToday(String day) {
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final todayIndex = DateTime.now().weekday - 1; // 1=Monday, 7=Sunday
    return weekdays[todayIndex] == day;
  }

  // ==================== SOCIAL LINKS SECTION ====================
  Widget _buildSocialLinksSection(Map<String, String> socialLinks) {
    final socialIcons = {
      'instagram': Icons.camera_alt,
      'facebook': Icons.facebook,
      'twitter': Icons.alternate_email,
      'whatsapp': Icons.chat,
      'website': Icons.language,
    };

    final socialColors = {
      'instagram': const Color(0xFFE4405F),
      'facebook': const Color(0xFF1877F2),
      'twitter': const Color(0xFF1DA1F2),
      'whatsapp': const Color(0xFF25D366),
      'website': AppColors.gray700,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.share, size: 20, color: AppColors.gray700),
            const SizedBox(width: 8),
            const Text('Redes Sociais', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: socialLinks.entries.map((entry) {
            final icon = socialIcons[entry.key] ?? Icons.link;
            final color = socialColors[entry.key] ?? AppColors.gray700;

            return GestureDetector(
              onTap: () => _openUrl(entry.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      entry.key.substring(0, 1).toUpperCase() + entry.key.substring(1),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ==================== TRUST SIGNALS SECTION ====================
  Widget _buildTrustSignalsSection(SupplierModel supplier) {
    final hasExperience = supplier.yearsExperience != null && supplier.yearsExperience! > 0;
    final hasTeamSize = supplier.teamSize != null && supplier.teamSize! > 0;
    final hasCompletedBookings = supplier.completedBookings > 0;
    final hasGoodResponseRate = supplier.responseRate >= 0.7;
    final isVerified = supplier.isVerified;

    // Only show section if there's at least one trust signal to display
    final signalCount = [hasExperience, hasTeamSize, hasCompletedBookings, hasGoodResponseRate, isVerified]
        .where((s) => s)
        .length;

    if (signalCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 20, color: AppColors.gray700),
            const SizedBox(width: 8),
            const Text('Indicadores de Confiança', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // First row of trust signals
              Row(
                children: [
                  if (hasExperience)
                    Expanded(
                      child: _buildTrustSignalItem(
                        icon: Icons.workspace_premium,
                        value: '${supplier.yearsExperience}+ anos',
                        label: 'Experiência',
                        color: AppColors.premium,
                      ),
                    ),
                  if (hasExperience && hasTeamSize) const SizedBox(width: 12),
                  if (hasTeamSize)
                    Expanded(
                      child: _buildTrustSignalItem(
                        icon: Icons.groups_outlined,
                        value: '${supplier.teamSize} ${supplier.teamSize == 1 ? 'pessoa' : 'pessoas'}',
                        label: 'Equipa',
                        color: AppColors.info,
                      ),
                    ),
                  if (!hasExperience && !hasTeamSize) const Spacer(),
                ],
              ),
              if ((hasExperience || hasTeamSize) && (hasCompletedBookings || hasGoodResponseRate || isVerified))
                const SizedBox(height: AppDimensions.md),
              // Second row of trust signals
              Row(
                children: [
                  if (hasCompletedBookings)
                    Expanded(
                      child: _buildTrustSignalItem(
                        icon: Icons.event_available,
                        value: '${supplier.completedBookings} eventos',
                        label: 'Concluídos',
                        color: AppColors.success,
                      ),
                    ),
                  if (hasCompletedBookings && hasGoodResponseRate) const SizedBox(width: 12),
                  if (hasGoodResponseRate)
                    Expanded(
                      child: _buildTrustSignalItem(
                        icon: Icons.speed,
                        value: '${(supplier.responseRate * 100).toInt()}%',
                        label: 'Taxa de resposta',
                        color: AppColors.peach,
                      ),
                    ),
                  if (!hasCompletedBookings && !hasGoodResponseRate) const Spacer(),
                ],
              ),
              // Verified badge (full width if present)
              if (isVerified) ...[
                if (hasExperience || hasTeamSize || hasCompletedBookings || hasGoodResponseRate)
                  const SizedBox(height: AppDimensions.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm, horizontal: AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        'Fornecedor Verificado pelo Boda Connect',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrustSignalItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATISTICS SECTION ====================
  Widget _buildStatisticsSection(SupplierModel supplier) {
    // Use real-time stats provider for accurate counts
    final statsAsync = ref.watch(supplierStatsStreamProvider(supplier.id));

    return statsAsync.when(
      loading: () => _buildStatisticsContent(
        viewCount: supplier.viewCount,
        favoriteCount: supplier.favoriteCount,
        completedBookings: supplier.completedBookings,
      ),
      error: (_, __) => _buildStatisticsContent(
        viewCount: supplier.viewCount,
        favoriteCount: supplier.favoriteCount,
        completedBookings: supplier.completedBookings,
      ),
      data: (stats) => _buildStatisticsContent(
        viewCount: stats.viewCount,
        favoriteCount: stats.favoriteCount,
        completedBookings: stats.completedBookings,
      ),
    );
  }

  Widget _buildStatisticsContent({
    required int viewCount,
    required int favoriteCount,
    required int completedBookings,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insights, size: 20, color: AppColors.gray700),
            const SizedBox(width: 8),
            const Text('Estatísticas', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.visibility_outlined,
                value: '$viewCount',
                label: 'Visualizações',
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.favorite_outline,
                value: '$favoriteCount',
                label: 'Favoritos',
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline,
                value: '$completedBookings',
                label: 'Reservas',
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== AVAILABILITY SECTION ====================
  Widget _buildAvailabilitySection(SupplierModel supplier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, size: 20, color: AppColors.gray700),
            const SizedBox(width: 8),
            const Text('Disponibilidade', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        AvailabilityCalendarWidget(
          supplierId: supplier.id,
          initialSelectedDate: _selectedAvailabilityDate,
          onDateSelected: (date) {
            setState(() {
              _selectedAvailabilityDate = date;
            });
          },
        ),
        if (_selectedAvailabilityDate != null) ...[
          const SizedBox(height: AppDimensions.sm),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data selecionada: ${DateFormat('dd/MM/yyyy').format(_selectedAvailabilityDate!)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==================== PORTFOLIO TAB ====================
  Widget _buildPortfolioTab(SupplierModel supplier) {
    final hasPhotos = supplier.portfolioPhotos.isNotEmpty || supplier.photos.length > 1;
    final hasVideos = supplier.videos.isNotEmpty;

    if (!hasPhotos && !hasVideos) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 64, color: AppColors.gray300),
              SizedBox(height: 16),
              Text(
                'Nenhum conteúdo no portfólio',
                style: AppTextStyles.body,
              ),
              SizedBox(height: 8),
              Text(
                'Este fornecedor ainda não adicionou fotos ou vídeos ao portfólio',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Combine portfolio photos and additional photos (skip first as it's the cover)
    final allPhotos = [
      ...supplier.portfolioPhotos,
      if (supplier.photos.length > 1) ...supplier.photos.skip(1),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Videos Section
          if (hasVideos) ...[
            Row(
              children: [
                const Icon(Icons.videocam, size: 20, color: AppColors.gray700),
                const SizedBox(width: 8),
                const Text('Vídeos', style: AppTextStyles.h3),
                const Spacer(),
                Text(
                  '${supplier.videos.length} vídeo${supplier.videos.length > 1 ? 's' : ''}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: supplier.videos.length,
                itemBuilder: (context, index) {
                  return _buildVideoThumbnail(supplier.videos[index], index);
                },
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
          ],

          // Photos Section
          if (allPhotos.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.photo_library, size: 20, color: AppColors.gray700),
                const SizedBox(width: 8),
                const Text('Fotos', style: AppTextStyles.h3),
                const Spacer(),
                Text(
                  '${allPhotos.length} foto${allPhotos.length > 1 ? 's' : ''}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: allPhotos.length,
              itemBuilder: (context, index) {
                return _buildPhotoGridItem(allPhotos[index], index, allPhotos);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(String videoUrl, int index) {
    return GestureDetector(
      onTap: () => _showVideoPlayer(videoUrl),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Stack(
          children: [
            // Video thumbnail placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Container(
                color: AppColors.gray900.withValues(alpha: 0.8),
                child: const Center(
                  child: Icon(Icons.video_library, size: 48, color: AppColors.gray400),
                ),
              ),
            ),
            // Play button overlay
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.peach.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow, color: AppColors.white, size: 32),
              ),
            ),
            // Video number badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Vídeo ${index + 1}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGridItem(String photoUrl, int index, List<String> allPhotos) {
    return GestureDetector(
      onTap: () => _showPhotoGallery(allPhotos, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: AppCachedImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          errorWidget: Container(
            color: AppColors.gray200,
            child: const Center(
              child: Icon(Icons.broken_image, color: AppColors.gray400),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoGallery(List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => _PhotoGalleryDialog(
        photos: photos,
        initialIndex: initialIndex,
      ),
    );
  }

  void _showVideoPlayer(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => _VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  /// Build map widget with fallback for when Google Maps is not configured
  Widget _buildMapWidget(SupplierModel supplier, LatLng position, bool hasCoordinates, String locationText) {
    // Use a StatefulBuilder to handle potential errors with GoogleMap widget
    return StatefulBuilder(
      builder: (context, setState) {
        try {
          return AbsorbPointer(
            // Prevent map gestures, only allow tap to open in external maps
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: position,
                zoom: hasCoordinates ? 15 : 12,
              ),
              markers: {
                Marker(
                  markerId: MarkerId(supplier.id),
                  position: position,
                  infoWindow: InfoWindow(
                    title: supplier.businessName,
                    snippet: locationText,
                  ),
                ),
              },
              mapType: MapType.normal,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              liteModeEnabled: true,
            ),
          );
        } catch (e) {
          // Fallback when Google Maps fails to load
          return _buildMapPlaceholder(locationText);
        }
      },
    );
  }

  /// Fallback placeholder when Google Maps is not available
  Widget _buildMapPlaceholder(String locationText) {
    return Container(
      color: AppColors.gray100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: AppColors.gray400),
            const SizedBox(height: 8),
            Text(
              locationText,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray700),
            ),
            const SizedBox(height: 4),
            Text(
              'Toque para abrir no mapa',
              style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(SupplierModel supplier) {
    final hasCoordinates = supplier.location?.geopoint != null;
    final locationText = supplier.location?.city != null
        ? '${supplier.location!.city}${supplier.location!.province != null ? ', ${supplier.location!.province}' : ''}'
        : 'Luanda';

    // Default to Luanda coordinates if no location is available
    final latitude = supplier.location?.geopoint?.latitude ?? -8.8390;
    final longitude = supplier.location?.geopoint?.longitude ?? 13.2894;
    final position = LatLng(latitude, longitude);

    return GestureDetector(
      onTap: () => _openInMaps(supplier),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            // Map widget with error handling for when Google Maps API key is not configured
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: _buildMapWidget(supplier, position, hasCoordinates, locationText),
            ),
            // Location info overlay
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.peach),
                    const SizedBox(width: 4),
                    Text(
                      locationText,
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            // "Tap to open" hint
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.peach.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasCoordinates ? Icons.directions : Icons.search,
                      size: 14,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasCoordinates ? 'Ver rotas' : 'Pesquisar',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontSize: 11,
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

  Future<void> _openInMaps(SupplierModel supplier) async {
    final geopoint = supplier.location?.geopoint;
    final locationName = supplier.location?.city ?? supplier.businessName;

    Uri mapUri;

    if (geopoint != null) {
      // Open with exact coordinates
      mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${geopoint.latitude},${geopoint.longitude}',
      );
    } else {
      // Search by location name or business name
      final query = Uri.encodeComponent('$locationName ${supplier.businessName}');
      mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }

    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir o mapa')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
    }
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.gray400),
        const SizedBox(width: AppDimensions.sm),
        Text(text, style: AppTextStyles.body),
      ],),
    );
  }

  Widget _buildPackagesTab(List<PackageModel> packages) {
    if (packages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.gray300),
              SizedBox(height: 16),
              Text(
                'Nenhum pacote disponível',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: packages.length,
      itemBuilder: (context, index) => _buildPackageCard(packages[index]),
    );
  }

  Widget _buildPackageCard(PackageModel package) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: package.isFeatured ? AppColors.peach : AppColors.border, width: package.isFeatured ? 2 : 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (package.isFeatured)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg - 2)),
            ),
            child: Center(child: Text('⭐ Mais Popular', style: AppTextStyles.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w600))),
          ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(package.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              Text(_formatPrice(package.price), style: AppTextStyles.h3.copyWith(color: AppColors.peachDark)),
            ],),
            const SizedBox(height: 4),
            Text(package.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.md),
            ...package.includes.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text(f, style: AppTextStyles.bodySmall),
              ],),
            ),),
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.push(Routes.clientPackageDetail, extra: package);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: package.isFeatured ? AppColors.peach : AppColors.gray100,
                  foregroundColor: package.isFeatured ? AppColors.white : AppColors.gray700,
                ),
                child: const Text('Selecionar Pacote'),
              ),
            ),
          ],),
        ),
      ],),
    );
  }

  Widget _buildReviewsTab(SupplierModel supplier, List<ReviewModel> reviews) {
    final reviewStatsAsync = ref.watch(reviewStatsProvider(supplier.id));
    final currentUser = ref.watch(authProvider).firebaseUser;
    final clientBookings = ref.watch(clientBookingsProvider);

    // Check if user has a completed booking with this supplier
    bool canWriteReview = false;
    String? eligibleBookingId;
    if (currentUser != null) {
      final completedBookings = clientBookings.where((b) =>
          b.supplierId == supplier.id &&
          b.status.name == 'completed').toList();
      if (completedBookings.isNotEmpty) {
        // Check if user hasn't already reviewed this booking
        final alreadyReviewed = reviews.any((r) =>
            r.bookingId == completedBookings.first.id &&
            r.clientId == currentUser.uid);
        if (!alreadyReviewed) {
          canWriteReview = true;
          eligibleBookingId = completedBookings.first.id;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              boxShadow: AppColors.cardShadow,
            ),
            child: reviewStatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Erro ao carregar estatísticas'),
              data: (stats) => Row(
                children: [
                  Column(
                    children: [
                      Text(
                        stats.averageRating.toStringAsFixed(1),
                        style: AppTextStyles.h1.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < stats.averageRating.floor() ? Icons.star : Icons.star_border,
                            size: 16,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stats.totalReviews} avaliações',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppDimensions.lg),
                  Expanded(
                    child: Column(
                      children: [
                        _buildRatingBar(5, stats.getRatingPercentage(5)),
                        _buildRatingBar(4, stats.getRatingPercentage(4)),
                        _buildRatingBar(3, stats.getRatingPercentage(3)),
                        _buildRatingBar(2, stats.getRatingPercentage(2)),
                        _buildRatingBar(1, stats.getRatingPercentage(1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Write Review Button
          if (currentUser != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppDimensions.md),
              child: ElevatedButton.icon(
                onPressed: canWriteReview && eligibleBookingId != null
                    ? () => _showReviewDialog(supplier, eligibleBookingId!)
                    : null,
                icon: const Icon(Icons.rate_review),
                label: Text(canWriteReview
                    ? 'Escrever Avaliação'
                    : 'Complete uma reserva para avaliar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peach,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.gray200,
                  disabledForegroundColor: AppColors.gray400,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ),

          const Text('Avaliações dos Clientes', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.md),
          if (reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhuma avaliação ainda',
                  style: AppTextStyles.body,
                ),
              ),
            )
          else
            ...reviews.map(_buildReviewCard),
        ],
      ),
    );
  }

  void _showReviewDialog(SupplierModel supplier, String bookingId) {
    showDialog(
      context: context,
      builder: (context) => SubmitReviewDialog(
        bookingId: bookingId,
        supplierId: supplier.id,
        supplierName: supplier.businessName,
      ),
    ).then((submitted) {
      if (submitted == true) {
        // Refresh reviews after submission
        ref.invalidate(reviewsProvider(supplier.id));
        ref.invalidate(reviewStatsProvider(supplier.id));
      }
    });
  }

  Widget _buildRatingBar(int stars, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$stars', style: AppTextStyles.caption),
        const SizedBox(width: 4),
        const Icon(Icons.star, size: 12, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
      ],),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final dateFormat = DateFormat('dd MMM yyyy', 'pt_PT');
    final formattedDate = dateFormat.format(review.createdAt);

    // Generate initials from client name
    final clientName = review.clientName ?? 'Anônimo';
    final initials = clientName.split(' ').take(2).map((n) => n.isNotEmpty ? n[0] : '').join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.peachLight,
                backgroundImage: review.clientPhoto != null ? NetworkImage(review.clientPhoto!) : null,
                child: review.clientPhoto == null
                    ? Text(
                        initials,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.peachDark,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (review.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Verificado',
                        style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              review.comment!,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(SupplierModel supplier) {
    // IMPORTANT: Use supplier.id (document ID) for chat to match booking supplierId
    // This ensures conversations can be found when supplier clicks "Responder" on bookings
    // Bookings store supplierId = supplier.id (document ID), so chat must use the same
    final supplierIdForChat = supplier.id;

    // Check if supplier allows messages
    final allowsMessages = supplier.allowsMessages;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(color: AppColors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: allowsMessages
            ? SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Track contact click (high-value interaction)
                    final currentUser = ref.read(currentUserProvider);
                    if (currentUser != null) {
                      ref.read(supplierStatsProvider(supplier.id).notifier)
                          .trackContactClick(currentUser.uid);
                    }
                    context.push(
                      '${Routes.chatDetail}?userId=$supplierIdForChat&userName=${Uri.encodeComponent(supplier.businessName)}',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peach,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                  ),
                  icon: const Icon(Icons.message_outlined),
                  label: Text('Enviar Mensagem', style: AppTextStyles.button.copyWith(color: AppColors.white)),
                ),
              )
            : Container(
                width: double.infinity,
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, color: AppColors.gray400, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Este fornecedor não aceita mensagens',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatPrice(int price) {
    final formatted = price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted Kz';
  }

  Future<void> _shareSupplier(SupplierModel supplier) async {
    Uri? shareLink;
    try {
      shareLink = await DeepLinkService().createSupplierLink(
        supplierId: supplier.id,
        supplierName: supplier.businessName,
        imageUrl: supplier.photos.isNotEmpty ? supplier.photos.first : null,
      );
    } catch (e) {
      debugPrint('Failed to create share link: $e');
    }
    // Format rating
    final ratingText = supplier.rating > 0
        ? '⭐ ${supplier.rating.toStringAsFixed(1)} (${supplier.reviewCount} avaliações)'
        : 'Novo fornecedor';

    // Format location - only show city/province, not full address (respects privacy)
    final locationText = supplier.location != null
        ? '📍 ${supplier.location!.city ?? ''}, ${supplier.location!.province ?? ''}'
        : '';

    // Format categories
    final categories = supplier.subcategories.isNotEmpty
        ? supplier.subcategories.join(', ')
        : supplier.category;

    // Build share text - PRIVACY: Only include phone if supplier allows it
    final phoneText = supplier.publicPhone != null ? '📞 ${supplier.publicPhone}\n' : '';

    final linkText = shareLink != null ? 'Link: $shareLink\n' : '';
    final text = '''
🎉 Confira este fornecedor no Boda Connect!

👤 ${supplier.businessName}
$locationText
$ratingText

🔖 Categoria: $categories

${supplier.description.isNotEmpty ? '📋 Sobre:\n${supplier.description.length > 200 ? '${supplier.description.substring(0, 200)}...' : supplier.description}\n' : ''}
${supplier.isVerified ? '✅ Fornecedor verificado\n' : ''}
$phoneText📱 Baixe o Boda Connect e entre em contato!
$linkText
''';

    Share.share(
      text,
      subject: 'Fornecedor: ${supplier.businessName}',
    );
  }
}

/// Full-screen photo gallery dialog
class _PhotoGalleryDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _PhotoGalleryDialog({required this.photos, this.initialIndex = 0});

  @override
  State<_PhotoGalleryDialog> createState() => _PhotoGalleryDialogState();
}

class _PhotoGalleryDialogState extends State<_PhotoGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Photo PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: AppCachedImage(
                    imageUrl: widget.photos[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
          // Page indicator
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Video player dialog
class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerDialog({required this.videoUrl});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      setState(() => _isInitialized = true);
      _controller.play();
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: _isInitialized ? _controller.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_hasError)
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('Erro ao carregar vídeo', style: TextStyle(color: Colors.white54)),
                ],
              )
            else if (!_isInitialized)
              const CircularProgressIndicator(color: AppColors.peach)
            else
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    if (!_controller.value.isPlaying)
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                      ),
                  ],
                ),
              ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
