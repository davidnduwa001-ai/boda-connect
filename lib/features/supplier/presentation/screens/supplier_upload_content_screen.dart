import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/providers/supplier_registration_provider.dart';
import '../../../../core/routing/route_names.dart';

class SupplierUploadContentScreen extends ConsumerStatefulWidget {
  const SupplierUploadContentScreen({super.key});

  @override
  ConsumerState<SupplierUploadContentScreen> createState() =>
      _SupplierUploadContentScreenState();
}

class _SupplierUploadContentScreenState
    extends ConsumerState<SupplierUploadContentScreen> {
  static const int _maxPhotos = 10;
  static const int _minPhotos = 5;

  final List<({XFile file, Uint8List bytes})> _photos = [];
  ({XFile file, Uint8List bytes})? _video;

  bool get _canContinue => _photos.length >= _minPhotos;

  Future<void> _pickPhotos() async {
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo de $_maxPhotos fotos atingido'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      final remainingSlots = _maxPhotos - _photos.length;
      final imagesToAdd = images.take(remainingSlots).toList();

      // Read bytes for each image (cross-platform compatible)
      final photosToAdd = <({XFile file, Uint8List bytes})>[];
      for (final img in imagesToAdd) {
        final bytes = await img.readAsBytes();
        photosToAdd.add((file: img, bytes: bytes));
      }

      setState(() {
        _photos.addAll(photosToAdd);
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );

    if (video != null) {
      final bytes = await video.readAsBytes();
      setState(() {
        _video = (file: video, bytes: bytes);
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _removeVideo() {
    setState(() {
      _video = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.screenPaddingHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.8,
                      backgroundColor: AppColors.gray200,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '80%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'Upload de Conteúdo',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Mostre o seu trabalho',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            // Photos section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Fotos do trabalho *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_photos.length} / $_maxPhotos',
                  style: TextStyle(
                    fontSize: 12,
                    color: _photos.length >= _minPhotos
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Photo grid
            if (_photos.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photos.length + (_photos.length < _maxPhotos ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _photos.length) {
                    return _buildAddPhotoButton();
                  }
                  return _buildPhotoTile(index);
                },
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Upload box when empty
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                    border: Border.all(
                      color: AppColors.gray300,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.peach.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 28,
                            color: AppColors.peach,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Adicionar fotos',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.peach,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Mínimo $_minPhotos fotos',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                border: Border.all(
                  color: AppColors.peach.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: AppColors.peach,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fotos reais aumentam suas chances de receber pedidos. Mínimo de $_minPhotos fotos necessárias.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Video section
            Row(
              children: [
                const Text(
                  'Vídeo de apresentação',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.premiumLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: const Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.premium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Video upload
            GestureDetector(
              onTap: _video == null ? _pickVideo : null,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                  border: Border.all(
                    color: _video != null ? AppColors.success : AppColors.gray300,
                  ),
                  color: _video != null
                      ? AppColors.successLight
                      : Colors.transparent,
                ),
                child: _video != null
                    ? Stack(
                        children: [
                          const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 36,
                                  color: AppColors.success,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Vídeo adicionado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeVideo,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_outlined,
                              size: 36,
                              color: AppColors.gray400,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Adicionar vídeo (opcional)',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Destaque seu perfil com um vídeo',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Máximo 50MB. Formatos: MP4, MOV, AVI',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                onPressed: _canContinue
                    ? () {
                        // Save photos and video to registration provider
                        ref.read(supplierRegistrationProvider.notifier).updateUploadContent(
                          portfolioImages: _photos.map((p) => p.file).toList(),
                          videoFile: _video?.file,
                        );
                        context.go(Routes.supplierPricing);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peach,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.gray200,
                  disabledForegroundColor: AppColors.textTertiary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                  ),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _photos[index].bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Capa',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.gray300,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: AppColors.peach,
            size: 28,
          ),
        ),
      ),
    );
  }
}
