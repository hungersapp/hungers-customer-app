import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Favorite toggle overlay for restaurant cards.
class RestaurantFavoriteButton extends StatelessWidget {
  const RestaurantFavoriteButton({
    super.key,
    required this.isFavorite,
    this.onTap,
  });

  final bool isFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: AppColors.accent,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Pure-vegetarian badge overlay for restaurant cards.
class RestaurantVegBadge extends StatelessWidget {
  const RestaurantVegBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'PURE VEG',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
