import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/providers/reviews_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class SubmitReviewDialog extends ConsumerStatefulWidget {
  final String bookingId;
  final String supplierId;
  final String supplierName;

  const SubmitReviewDialog({
    super.key,
    required this.bookingId,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  ConsumerState<SubmitReviewDialog> createState() => _SubmitReviewDialogState();
}

class _SubmitReviewDialogState extends ConsumerState<SubmitReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _imagePicker = ImagePicker();

  double _rating = 0.0;
  List<({XFile file, Uint8List bytes})> _selectedPhotos = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: BoxDecoration(
                color: AppColors.peach.withAlpha((0.1 * 255).toInt()),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avaliar Fornecedor',
                          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.supplierName,
                          style: AppTextStyles.body.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating Section
                      Text(
                        'Qual foi a sua experiência?',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          children: [
                            // Star Rating
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final starValue = index + 1;
                                return IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _rating = starValue.toDouble();
                                    });
                                  },
                                  icon: Icon(
                                    _rating >= starValue ? Icons.star : Icons.star_border,
                                    size: 48,
                                    color: _rating >= starValue
                                        ? Colors.amber
                                        : Colors.grey.shade300,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            if (_rating > 0)
                              Text(
                                _getRatingLabel(_rating),
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.peach,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Comment Section
                      Text(
                        'Conte-nos mais sobre a sua experiência',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commentController,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Descreva o que achou do serviço...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.all(AppDimensions.md),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, escreva um comentário';
                          }
                          if (value.trim().length < 10) {
                            return 'O comentário deve ter pelo menos 10 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Photos Section
                      Text(
                        'Adicionar fotos (opcional)',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _buildPhotoSection(),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting || _rating == 0
                              ? null
                              : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.peach,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : Text(
                                  'Enviar Avaliação',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        // Selected Photos Grid
        if (_selectedPhotos.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedPhotos.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedPhotos[index].bytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPhotos.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],

        // Add Photo Button
        if (_selectedPhotos.length < 5)
          OutlinedButton.icon(
            onPressed: _pickPhotos,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(
              _selectedPhotos.isEmpty
                  ? 'Adicionar Fotos'
                  : 'Adicionar Mais (${_selectedPhotos.length}/5)',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickPhotos() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        final remainingSlots = 5 - _selectedPhotos.length;
        final filesToAdd = pickedFiles.take(remainingSlots).toList();

        // Read bytes for each file (cross-platform compatible)
        final photosToAdd = <({XFile file, Uint8List bytes})>[];
        for (final xFile in filesToAdd) {
          final bytes = await xFile.readAsBytes();
          photosToAdd.add((file: xFile, bytes: bytes));
        }

        setState(() {
          _selectedPhotos.addAll(photosToAdd);
        });

        if (pickedFiles.length > remainingSlots && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Máximo de 5 fotos permitido. ${pickedFiles.length - remainingSlots} foto(s) não adicionada(s).'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao selecionar fotos')),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma classificação')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(authProvider).firebaseUser;
      if (currentUser == null) {
        throw Exception('Utilizador não autenticado');
      }

      final reviewId = await ref.read(reviewNotifierProvider.notifier).submitReview(
        bookingId: widget.bookingId,
        clientId: currentUser.uid,
        supplierId: widget.supplierId,
        clientName: currentUser.displayName,
        clientPhoto: currentUser.photoURL,
        rating: _rating,
        comment: _commentController.text.trim(),
        photoFiles: _selectedPhotos.isNotEmpty ? _selectedPhotos.map((p) => p.file).toList() : null,
      );

      if (mounted) {
        if (reviewId != null) {
          Navigator.pop(context, true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avaliação enviada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao enviar avaliação'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5.0) return 'Excelente! ⭐';
    if (rating >= 4.0) return 'Muito Bom! 👍';
    if (rating >= 3.0) return 'Bom 😊';
    if (rating >= 2.0) return 'Razoável 😐';
    return 'Precisa Melhorar 😕';
  }
}
