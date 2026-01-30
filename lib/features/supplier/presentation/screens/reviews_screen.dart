import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/models/review_category_models.dart';
import '../../../../core/providers/reviews_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final String? supplierId;

  const ReviewsScreen({super.key, this.supplierId});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('pt', timeago.PtBrMessages());
    _loadReviews();
  }

  void _loadReviews() {
    // Reviews are loaded automatically by the provider
    // No need for explicit loading
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final supplierId = widget.supplierId ?? currentUser?.uid ?? '';
    final reviewsAsync = ref.watch(reviewsProvider(supplierId));
    final statsAsync = ref.watch(reviewStatsProvider(supplierId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Avaliações'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: reviewsAsync.when(
        data: (reviews) => Column(
          children: [
            // Statistics Header
            statsAsync.when(
              data: (stats) => _buildStatisticsHeader(stats),
              loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox(),
            ),

            // Reviews List
            Expanded(
              child: reviews.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.md),
                      itemBuilder: (_, index) {
                        return _buildReviewCard(reviews[index]);
                      },
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Erro ao carregar avaliações: $error'),
        ),
      ),
    );
  }

  Widget _buildStatisticsHeader(ReviewStats stats) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Average Rating
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      stats.averageRating.toStringAsFixed(1),
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: AppColors.peach,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < stats.averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.totalReviews} ${stats.totalReviews == 1 ? "avaliação" : "avaliações"}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Rating Distribution
              Expanded(
                flex: 3,
                child: Column(
                  children: List.generate(5, (index) {
                    final stars = 5 - index;
                    final percentage = stats.getRatingPercentage(stars);
                    final count = stats.ratingDistribution[stars] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '$stars',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: percentage,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.peach,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '$count',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.grey.shade600,
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
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Client Info & Rating
          Row(
            children: [
              // Client Photo
              CircleAvatar(
                radius: 20,
                backgroundImage: review.clientPhoto != null
                    ? NetworkImage(review.clientPhoto!)
                    : null,
                child: review.clientPhoto == null
                    ? Text(
                        review.clientName?.substring(0, 1).toUpperCase() ?? 'C',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Client Name & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.clientName ?? 'Cliente',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (review.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeago.format(review.createdAt, locale: 'pt'),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Star Rating
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating.round()
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  );
                }),
              ),
            ],
          ),

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!,
              style: AppTextStyles.body,
            ),
          ],

          // Photos
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      review.photos[index],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          ],

          // Supplier Reply
          if (review.supplierReply != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppDimensions.sm),
              decoration: BoxDecoration(
                color: AppColors.peach.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.store,
                        size: 16,
                        color: AppColors.peach,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resposta do Fornecedor',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.peach,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.supplierReply!,
                    style: AppTextStyles.bodySmall,
                  ),
                  if (review.supplierReplyAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(review.supplierReplyAt!, locale: 'pt'),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhuma avaliação ainda',
            style: AppTextStyles.h3.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'As avaliações dos clientes aparecerão aqui',
            style: AppTextStyles.body.copyWith(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
