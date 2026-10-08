import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Displays the restaurant rating badge.
class RestaurantRating extends StatelessWidget {
  const RestaurantRating({
    super.key,
    required this.rating,
    this.ratingCount,
    this.showRatingCount = false,
    this.backgroundColor = AppColors.freshGreen,
    this.textColor = AppColors.textLight,
  });

  final double rating;
  final int? ratingCount;
  final bool showRatingCount;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: textColor, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  rating.toStringAsFixed(1),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showRatingCount && ratingCount != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text('($ratingCount)', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
