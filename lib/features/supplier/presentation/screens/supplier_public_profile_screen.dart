import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../widgets/stats_grid_widget.dart';

class SupplierPublicProfileScreen extends ConsumerStatefulWidget {
  const SupplierPublicProfileScreen({super.key});

  @override
  ConsumerState<SupplierPublicProfileScreen> createState() =>
      _SupplierPublicProfileScreenState();
}

class _SupplierPublicProfileScreenState
    extends ConsumerState<SupplierPublicProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(supplierProvider.notifier).loadCurrentSupplier();
    });
  }

  @override
  Widget build(BuildContext context) {
    final supplierState = ref.watch(supplierProvider);
    final supplier = supplierState.currentSupplier;

    if (supplierState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.peach)),
      );
    }

    if (supplier == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil Público'),
        ),
        body: const Center(
          child: Text('Perfil não encontrado'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: Text('Perfil Público',
            style: AppTextStyles.h3.copyWith(color: AppColors.gray900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewBanner(),
            _buildActionButtons(context),
            _buildStatsSection(),
            _buildProfileCard(supplier),
            if (supplier.socialLinks != null && supplier.socialLinks!.isNotEmpty)
              _buildSocialLinks(supplier),
            _buildAboutSection(supplier),
            if (supplier.subcategories.isNotEmpty) _buildSpecialties(supplier),
            _buildPortfolio(supplier),
            _buildTipCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBanner() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: const Icon(Icons.visibility, color: AppColors.info),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visualização do Perfil',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.info)),
                Text(
                  'Esta é a aparência do seu perfil para clientes na plataforma',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final supplier = ref.watch(supplierProvider).currentSupplier;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => context.push(Routes.supplierProfileEdit),
              icon: const Icon(Icons.edit, color: AppColors.white, size: 18),
              label: Text('Editar Perfil',
                  style: AppTextStyles.button.copyWith(color: AppColors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.peach,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                if (supplier != null) {
                  Share.share(
                    'Confira o perfil de ${supplier.businessName} no BODA CONNECT!\n\n'
                    '${supplier.description}\n\n'
                    'Categoria: ${supplier.category}\n'
                    'Avaliação: ⭐ ${supplier.rating.toStringAsFixed(1)} (${supplier.reviewCount} avaliações)',
                  );
                }
              },
              icon:
                  const Icon(Icons.share, color: AppColors.gray700, size: 18),
              label: Text('Partilhar',
                  style:
                      AppTextStyles.button.copyWith(color: AppColors.gray700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final supplier = ref.watch(supplierProvider).currentSupplier;

    if (supplier == null) {
      return const SizedBox.shrink();
    }

    // Use the new StatsGridWidget for real-time stats from Firestore
    // Falls back to local supplier data if stream fails
    return StatsGridWidget(
      supplierId: supplier.id,
      showTenure: false,
      showLeads: false,
      compact: true,
      padding: const EdgeInsets.all(AppDimensions.md),
    );
  }

  Widget _buildProfileCard(supplier) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [AppColors.peach, AppColors.peachDark]),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusLg)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppDimensions.radiusLg)),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 4),
                    ),
                    child: supplier.photos.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              supplier.photos.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.camera_alt,
                                      color: AppColors.gray400, size: 32),
                            ),
                          )
                        : const Icon(Icons.camera_alt,
                            color: AppColors.gray400, size: 32),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    children: [
                      Text(supplier.businessName, style: AppTextStyles.h3),
                      Text(supplier.category,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 4),
                          Text(supplier.rating.toStringAsFixed(1),
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.bold)),
                          Text(' (${supplier.reviewCount} avaliações)',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      if (supplier.location?.city != null)
                        _buildContactInfo(Icons.location_on_outlined,
                            '${supplier.location!.city}, ${supplier.location!.province ?? "Angola"}'),
                      const SizedBox(height: 4),
                      // Member since badge (Tenure)
                      _buildContactInfo(
                        Icons.schedule_outlined,
                        'Membro desde ${supplier.createdAt.year}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.gray400),
          const SizedBox(width: 8),
          Text(text,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSocialLinks(supplier) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppDimensions.sm,
        runSpacing: AppDimensions.sm,
        children: supplier.socialLinks!.entries.map<Widget>((entry) {
          IconData icon;
          Color color;

          switch (entry.key.toLowerCase()) {
            case 'instagram':
              icon = Icons.camera_alt;
              color = AppColors.peach;
              break;
            case 'facebook':
              icon = Icons.facebook;
              color = const Color(0xFF1877F2);
              break;
            case 'twitter':
              icon = Icons.chat;
              color = const Color(0xFF1DA1F2);
              break;
            default:
              icon = Icons.link;
              color = AppColors.gray700;
          }

          return _buildSocialButton(icon, entry.value, color);
        }).toList(),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.white, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAboutSection(supplier) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sobre', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          Text(
            supplier.description.isNotEmpty
                ? supplier.description
                : 'Sem descrição disponível',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialties(supplier) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Especialidades', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: supplier.subcategories.map<Widget>((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(s, style: AppTextStyles.bodySmall),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolio(supplier) {
    final hasPhotos = supplier.photos.isNotEmpty;
    final hasVideos = supplier.videos.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Portfólio', style: AppTextStyles.h3),
              TextButton.icon(
                onPressed: () => _showPortfolioManagement(supplier),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Gerir'),
                style: TextButton.styleFrom(foregroundColor: AppColors.peach),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          if (!hasPhotos && !hasVideos)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        size: 48, color: AppColors.gray300),
                    const SizedBox(height: 12),
                    Text('Nenhum conteúdo no portfólio',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showPortfolioManagement(supplier),
                      icon: const Icon(Icons.add_photo_alternate, size: 18),
                      label: const Text('Adicionar Fotos/Vídeos'),
                      style:
                          TextButton.styleFrom(foregroundColor: AppColors.peach),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Photos Section
                if (hasPhotos) ...[
                  Row(
                    children: [
                      const Icon(Icons.photo_library,
                          size: 16, color: AppColors.gray400),
                      const SizedBox(width: 4),
                      Text('Fotos (${supplier.photos.length})',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: supplier.photos.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _viewMedia(supplier.photos, index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                            child: Image.network(
                              supplier.photos[index],
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Center(
                                  child: Icon(Icons.image,
                                      color: AppColors.gray400)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                // Videos Section
                if (hasVideos) ...[
                  if (hasPhotos) const SizedBox(height: AppDimensions.md),
                  Row(
                    children: [
                      const Icon(Icons.videocam,
                          size: 16, color: AppColors.gray400),
                      const SizedBox(width: 4),
                      Text('Vídeos (${supplier.videos.length})',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: supplier.videos.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _viewVideo(supplier.videos[index]),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm),
                                child: Image.network(
                                  _getVideoThumbnail(supplier.videos[index]),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (c, e, s) => const Center(
                                      child: Icon(Icons.videocam,
                                          color: AppColors.gray400)),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.play_arrow,
                                    color: AppColors.white, size: 24),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _getVideoThumbnail(String videoUrl) {
    // For YouTube videos
    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      String? videoId;
      if (videoUrl.contains('youtube.com')) {
        // Safe extraction: check if 'v=' exists and has content after it
        final parts = videoUrl.split('v=');
        if (parts.length > 1 && parts[1].isNotEmpty) {
          videoId = parts[1].split('&')[0];
        }
      } else {
        // youtu.be format: get last path segment
        final lastSegment = videoUrl.split('/').last;
        if (lastSegment.isNotEmpty) {
          videoId = lastSegment.split('?')[0]; // Remove query params if any
        }
      }
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
      }
    }
    // For other videos or invalid URLs, return the original URL
    return videoUrl;
  }

  void _viewMedia(List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _PhotoGalleryDialog(
        photos: photos,
        initialIndex: initialIndex,
      ),
    );
  }

  void _viewVideo(String videoUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  void _showPortfolioManagement(supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PortfolioManagementSheet(supplier: supplier),
    );
  }

  Widget _buildTipCard() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: const Icon(Icons.star, color: AppColors.warning),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mantenha Atualizado',
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'Perfis completos e atualizados recebem até 3x mais visualizações e reservas. Adicione fotos, descrições detalhadas e informações de contato.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== PORTFOLIO MANAGEMENT SHEET ====================

class _PortfolioManagementSheet extends ConsumerStatefulWidget {
  final dynamic supplier;

  const _PortfolioManagementSheet({required this.supplier});

  @override
  ConsumerState<_PortfolioManagementSheet> createState() =>
      _PortfolioManagementSheetState();
}

class _PortfolioManagementSheetState
    extends ConsumerState<_PortfolioManagementSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _videoUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Gerir Portfólio',
                      style: AppTextStyles.h3
                          .copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add Photos Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Adicionar Fotos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.peach,
                        side: const BorderSide(color: AppColors.peach),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // Add Video Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showAddVideoDialog,
                      icon: const Icon(Icons.video_library),
                      label: const Text('Adicionar Vídeo (URL)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.peach,
                        side: const BorderSide(color: AppColors.peach),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.lg),

                  // Current Photos
                  if (widget.supplier.photos.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.photo_library,
                            size: 18, color: AppColors.gray700),
                        const SizedBox(width: 8),
                        Text('Fotos (${widget.supplier.photos.length})',
                            style: AppTextStyles.bodyLarge
                                .copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: widget.supplier.photos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.gray200,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm),
                                child: Image.network(
                                  widget.supplier.photos[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (c, e, s) => const Center(
                                      child: Icon(Icons.image,
                                          color: AppColors.gray400)),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _deletePhoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: AppColors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.lg),
                  ],

                  // Current Videos
                  if (widget.supplier.videos.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.videocam,
                            size: 18, color: AppColors.gray700),
                        const SizedBox(width: 8),
                        Text('Vídeos (${widget.supplier.videos.length})',
                            style: AppTextStyles.bodyLarge
                                .copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: widget.supplier.videos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.gray200,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusSm),
                                    child: Image.network(
                                      _getVideoThumbnail(
                                          widget.supplier.videos[index]),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (c, e, s) => const Center(
                                          child: Icon(Icons.videocam,
                                              color: AppColors.gray400)),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(Icons.play_arrow,
                                        color: AppColors.white, size: 20),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _deleteVideo(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: AppColors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppDimensions.lg),
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.peach),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getVideoThumbnail(String videoUrl) {
    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      final videoId = videoUrl.contains('youtube.com')
          ? videoUrl.split('v=')[1].split('&')[0]
          : videoUrl.split('/').last;
      return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
    }
    return videoUrl;
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isEmpty) return;

      setState(() {
        _isLoading = true;
      });

      // Upload images and get URLs
      final List<String> newPhotoUrls = [];
      for (final image in images) {
        final url = await _uploadImageToStorage(image);
        if (url != null) {
          newPhotoUrls.add(url);
        }
      }

      if (newPhotoUrls.isEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao fazer upload das imagens'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Update supplier photos
      final updatedPhotos = <String>[
        ...widget.supplier.photos,
        ...newPhotoUrls,
      ];

      final success = await ref
          .read(supplierProvider.notifier)
          .updateSupplierPhotos(updatedPhotos);

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotos adicionadas com sucesso'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao adicionar fotos'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Upload image to Firebase Storage and return the download URL
  Future<String?> _uploadImageToStorage(XFile image) async {
    try {
      final supplierId = widget.supplier.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'portfolio_${timestamp}_${image.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('suppliers')
          .child(supplierId)
          .child('portfolio')
          .child(fileName);

      final bytes = await image.readAsBytes();
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _showAddVideoDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Vídeo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cole o URL do vídeo do YouTube ou outra plataforma:',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _videoUrlController,
              decoration: const InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _videoUrlController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addVideo();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addVideo() async {
    final videoUrl = _videoUrlController.text.trim();
    if (videoUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Update supplier videos
    final updatedVideos = <String>[
      ...widget.supplier.videos,
      videoUrl,
    ];

    final success = await ref
        .read(supplierProvider.notifier)
        .updateSupplierVideos(updatedVideos);

    setState(() {
      _isLoading = false;
    });

    _videoUrlController.clear();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vídeo adicionado com sucesso'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao adicionar vídeo'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deletePhoto(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Foto?'),
        content:
            const Text('Tem certeza que deseja excluir esta foto do portfólio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    // Remove photo from list
    final updatedPhotos = List<String>.from(widget.supplier.photos)
      ..removeAt(index);

    final success = await ref
        .read(supplierProvider.notifier)
        .updateSupplierPhotos(updatedPhotos);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto removida'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover foto'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteVideo(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Vídeo?'),
        content: const Text(
            'Tem certeza que deseja excluir este vídeo do portfólio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    // Remove video from list
    final updatedVideos = List<String>.from(widget.supplier.videos)
      ..removeAt(index);

    final success = await ref
        .read(supplierProvider.notifier)
        .updateSupplierVideos(updatedVideos);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vídeo removido'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover vídeo'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ==================== PHOTO GALLERY DIALOG ====================

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
          // Photo PageView with pinch-to-zoom
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.photos[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                          color: AppColors.peach,
                        ),
                      );
                    },
                    errorBuilder: (c, e, s) => const Center(
                      child: Icon(Icons.error_outline, color: Colors.white54, size: 48),
                    ),
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

// ==================== VIDEO PLAYER DIALOG ====================

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
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
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
