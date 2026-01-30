import 'package:flutter/material.dart';

/// An efficient star rating widget that avoids List.generate in build
/// Uses a Row with fixed children count for better performance
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool showHalfStars;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 16,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.showHalfStars = false,
  });

  @override
  Widget build(BuildContext context) {
    final int fullStars = rating.floor();
    final bool hasHalfStar = showHalfStars && (rating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStar(0, fullStars, hasHalfStar),
        _buildStar(1, fullStars, hasHalfStar),
        _buildStar(2, fullStars, hasHalfStar),
        _buildStar(3, fullStars, hasHalfStar),
        _buildStar(4, fullStars, hasHalfStar),
      ],
    );
  }

  Widget _buildStar(int index, int fullStars, bool hasHalfStar) {
    IconData icon;
    Color color;

    if (index < fullStars) {
      icon = Icons.star;
      color = activeColor;
    } else if (index == fullStars && hasHalfStar) {
      icon = Icons.star_half;
      color = activeColor;
    } else {
      icon = Icons.star_border;
      color = inactiveColor;
    }

    return Icon(icon, size: size, color: color);
  }
}

/// A compact star rating display with rating value
class StarRatingWithValue extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double starSize;
  final TextStyle? textStyle;

  const StarRatingWithValue({
    super.key,
    required this.rating,
    this.reviewCount = 0,
    this.starSize = 14,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: starSize, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: textStyle ?? TextStyle(
            fontSize: starSize - 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (reviewCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: textStyle?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ) ?? TextStyle(
              fontSize: starSize - 2,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}
