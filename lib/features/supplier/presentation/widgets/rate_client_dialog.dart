import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/providers/reviews_provider.dart';
import '../../../../core/providers/supplier_provider.dart';

/// Dialog for suppliers to rate clients after a completed booking
class RateClientDialog extends ConsumerStatefulWidget {
  final String bookingId;
  final String clientId;
  final String clientName;

  const RateClientDialog({
    super.key,
    required this.bookingId,
    required this.clientId,
    required this.clientName,
  });

  @override
  ConsumerState<RateClientDialog> createState() => _RateClientDialogState();
}

class _RateClientDialogState extends ConsumerState<RateClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  double _rating = 0.0;
  final Set<String> _selectedTags = {};
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
                          'Avaliar Cliente',
                          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.clientName,
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
                        'Como foi a sua experiência com este cliente?',
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

                      // Tags Section
                      Text(
                        'O que destacou neste cliente? (opcional)',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ClientReviewTags.all.map((tag) {
                          final isSelected = _selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                              });
                            },
                            selectedColor: AppColors.peach.withAlpha((0.2 * 255).toInt()),
                            checkmarkColor: AppColors.peach,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.peach : Colors.grey.shade700,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Comment Section
                      Text(
                        'Deixe um comentário (opcional)',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commentController,
                        maxLines: 4,
                        maxLength: 300,
                        decoration: InputDecoration(
                          hintText: 'Descreva a sua experiência com o cliente...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.all(AppDimensions.md),
                        ),
                      ),
                      const SizedBox(height: 24),

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
                                  'Enviar Avaliacao',
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

  Future<void> _handleSubmit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma classificacao')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supplier = ref.read(supplierProvider).currentSupplier;
      if (supplier == null) {
        throw Exception('Fornecedor nao encontrado');
      }

      final reviewId = await ref.read(reviewNotifierProvider.notifier).submitClientReview(
        bookingId: widget.bookingId,
        supplierId: supplier.id,
        clientId: widget.clientId,
        supplierName: supplier.businessName,
        rating: _rating,
        comment: _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : 'Sem comentario',
        tags: _selectedTags.toList(),
      );

      if (mounted) {
        if (reviewId != null) {
          Navigator.pop(context, true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avaliacao enviada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final errorState = ref.read(reviewNotifierProvider);
          final errorMessage = errorState.error?.toString() ?? 'Erro ao enviar avaliacao';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage.replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5.0) return 'Excelente!';
    if (rating >= 4.0) return 'Muito Bom!';
    if (rating >= 3.0) return 'Bom';
    if (rating >= 2.0) return 'Razoavel';
    return 'Precisa Melhorar';
  }
}
