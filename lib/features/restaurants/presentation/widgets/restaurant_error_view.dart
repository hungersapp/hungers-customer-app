import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class RestaurantErrorView extends StatelessWidget {
  const RestaurantErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
    this.icon = Icons.error_outline_rounded,
    this.compact = true,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = compact ? 22.0 : 72.0;
    final maxMessageHeight = compact ? 56.0 : 240.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: compact ? AppSpacing.sm : AppSpacing.xxl,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: iconSize, color: AppColors.error),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style:
                          (compact
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.titleLarge)
                              ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxMessageHeight),
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
