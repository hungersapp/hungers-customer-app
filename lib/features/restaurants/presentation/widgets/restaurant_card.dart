import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/restaurant_entity.dart';
import 'restaurant_cover_image.dart';
import 'restaurant_rating.dart';

/// Home restaurant card: large cover, name, rating, cuisine, distance, ETA.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.distanceLabel,
  });

  final RestaurantEntity restaurant;
  final VoidCallback? onTap;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuisineLabel = restaurant.cuisines
        .where((c) => c.trim().isNotEmpty)
        .join(' • ');

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RestaurantCoverImage(
                imageUrl: restaurant.displayImageUrl,
                aspectRatio: 16 / 9,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.card),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        RestaurantRating(rating: restaurant.rating),
                      ],
                    ),
                    if (cuisineLabel.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        cuisineLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _MetaRow(
                      distanceLabel: distanceLabel,
                      deliveryTime: restaurant.deliveryTime,
                      isOpen: restaurant.isOpen,
                      isPureVeg: restaurant.isPureVeg,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.distanceLabel,
    required this.deliveryTime,
    required this.isOpen,
    required this.isPureVeg,
  });

  final String? distanceLabel;
  final int deliveryTime;
  final bool isOpen;
  final bool isPureVeg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (distanceLabel != null && distanceLabel!.isNotEmpty)
          _MetaItem(
            icon: Icons.near_me_rounded,
            iconColor: AppColors.iconMuted,
            label: distanceLabel!,
            style: muted,
          ),
        _MetaItem(
          icon: Icons.access_time_rounded,
          iconColor: AppColors.primary,
          label: '$deliveryTime mins',
          style: muted,
        ),
        if (isOpen)
          _MetaItem(
            icon: Icons.circle,
            iconColor: AppColors.freshGreen,
            iconSize: 8,
            label: 'Open',
            style: muted?.copyWith(
              color: AppColors.freshGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (isPureVeg)
          _MetaItem(
            icon: Icons.eco_rounded,
            iconColor: AppColors.freshGreen,
            label: 'Veg',
            style: muted?.copyWith(
              color: AppColors.freshGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.style,
    this.iconSize = 14,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: AppSpacing.xs),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ],
    );
  }
}
