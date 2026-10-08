import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class RestaurantEmptyView extends StatelessWidget {
  const RestaurantEmptyView({
    super.key,
    this.title = 'Sorry, no restaurants available in this location.',
    this.message = 'Try choosing a different delivery location.',
    this.icon = Icons.restaurant_outlined,
    this.buttonText,
    this.onPressed,
  });

  final String title;
  final String message;
  final IconData icon;

  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: AppColors.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (buttonText != null && onPressed != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(buttonText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
