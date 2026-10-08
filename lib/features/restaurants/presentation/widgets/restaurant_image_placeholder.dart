import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Placeholder shown while a restaurant image loads or when loading fails.
class RestaurantImagePlaceholder extends StatelessWidget {
  const RestaurantImagePlaceholder({
    super.key,
    this.showProgress = false,
    this.progress,
  });

  final bool showProgress;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border.withValues(alpha: 0.35),
      child: Center(
        child: showProgress
            ? SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: progress,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.restaurant_menu_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }
}
