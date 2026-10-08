import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Displays restaurant cuisines and address.
class RestaurantInfo extends StatelessWidget {
  const RestaurantInfo({
    super.key,
    required this.cuisines,
    required this.address,
  });

  final List<String> cuisines;
  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuisineLabel = cuisines.join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cuisineLabel.isNotEmpty)
          Text(
            cuisineLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        if (address.isNotEmpty) ...[
          if (cuisineLabel.isNotEmpty) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
