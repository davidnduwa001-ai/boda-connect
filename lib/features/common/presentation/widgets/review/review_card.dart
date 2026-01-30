import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/models/review_model.dart';
import '../../../../../core/constants/colors.dart';

/// Widget to display a single review card
class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool showResponse;
  final VoidCallback? onRespond;
  final VoidCallback? onReport;
  final VoidCallback? onDispute;

  const ReviewCard({
    super.key,
    required this.review,
    this.showResponse = true,
    this.onRespond,
    this.onReport,
    this.onDispute,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Rating and Date
            _buildHeader(),
            const SizedBox(height: 12),

            // Tags
            if (review.tags.isNotEmpty) ...[
              _buildTags(),
              const SizedBox(height: 12),
            ],

            // Comment
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              Text(
                review.comment!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Photos
            if (review.photos != null && review.photos!.isNotEmpty) ...[
              _buildPhotos(),
              const SizedBox(height: 12),
            ],

            // Response (if exists)
            if (showResponse &&
                review.response != null &&
                review.response!.isNotEmpty) ...[
              _buildResponse(),
              const SizedBox(height: 12),
            ],

            // Action buttons
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Rating stars
        Row(
          children: [
            ...List.generate(5, (index) {
              return Icon(
                index < review.rating.round()
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.amber,
                size: 20,
              );
            }),
            const SizedBox(width: 8),
            Text(
              review.rating.toStringAsFixed(1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        // Date
        Text(
          _formatDate(review.createdAt),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: review.tags.map((tag) {
        return Chip(
          label: Text(
            tag,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: AppColors.info.withValues(alpha: 0.1),
          labelStyle: const TextStyle(color: AppColors.info),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _buildPhotos() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: review.photos!.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                review.photos![index],
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponse() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.reply, size: 16, color: AppColors.info),
              const SizedBox(width: 6),
              Text(
                'Resposta do ${review.reviewedType == 'supplier' ? 'Fornecedor' : 'Cliente'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.response!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
          if (review.respondedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatDate(review.respondedAt!),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final hasActions = onRespond != null || onReport != null || onDispute != null;
    if (!hasActions) return const SizedBox.shrink();

    return Row(
      children: [
        if (onRespond != null)
          TextButton.icon(
            onPressed: onRespond,
            icon: const Icon(Icons.reply, size: 16),
            label: const Text('Responder'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        if (onDispute != null)
          TextButton.icon(
            onPressed: onDispute,
            icon: const Icon(Icons.gavel, size: 16),
            label: const Text('Contestar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        const Spacer(),
        if (onReport != null)
          IconButton(
            onPressed: onReport,
            icon: const Icon(Icons.flag_outlined, size: 20),
            color: Colors.red,
            tooltip: 'Reportar avaliação',
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoje';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Há $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    } else {
      return DateFormat('d MMM yyyy', 'pt_PT').format(date);
    }
  }
}

/// Widget to display review statistics
class ReviewStats extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;

  const ReviewStats({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Average rating
                Column(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalReviews ${totalReviews == 1 ? 'avaliação' : 'avaliações'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 32),

                // Rating distribution
                Expanded(
                  child: Column(
                    children: List.generate(5, (index) {
                      final stars = 5 - index;
                      final count = ratingDistribution[stars] ?? 0;
                      final percentage =
                          totalReviews > 0 ? count / totalReviews : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              '$stars',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.info,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
