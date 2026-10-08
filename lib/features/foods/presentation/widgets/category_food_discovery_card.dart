import 'package:flutter/material.dart';

import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/sized_network_image.dart';

/// Horizontal restaurant-food discovery card for category browse.
///
/// Left (~37% width): full-height food image.
/// Right: restaurant → food → distance/cuisine → description → price + ADD.
class CategoryFoodDiscoveryCard extends StatelessWidget {
  const CategoryFoodDiscoveryCard({
    super.key,
    required this.foodName,
    required this.restaurantName,
    required this.price,
    this.description,
    this.imageUrl,
    this.distanceLabel,
    this.cuisineLabel,
    this.isVeg = true,
    this.quantity = 0,
    this.isUpdating = false,
    this.onTap,
    this.onAddTap,
    this.onIncreaseTap,
    this.onDecreaseTap,
  });

  final String foodName;
  final String restaurantName;
  final double price;
  final String? description;
  final String? imageUrl;
  final String? distanceLabel;
  final String? cuisineLabel;
  final bool isVeg;
  final int quantity;
  final bool isUpdating;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onIncreaseTap;
  final VoidCallback? onDecreaseTap;

  /// Fraction of card width for the left food image (35–40%).
  static const double imageWidthFraction = 0.37;

  /// Minimum image height so the left pane stays visually dominant without
  /// IntrinsicHeight (unsafe under ListView unbounded max height).
  static const double minImageHeight = 118;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedDescription = description?.trim() ?? '';
    final trimmedDistance = distanceLabel?.trim() ?? '';
    final trimmedCuisine = cuisineLabel?.trim() ?? '';
    final hasMeta = trimmedDistance.isNotEmpty || trimmedCuisine.isNotEmpty;

    return Material(
      color: AppColors.surface,
      elevation: 1.5,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ListView children get maxHeight=Infinity. Do not use
            // IntrinsicHeight here — give the image deterministic size.
            final imageWidth = constraints.maxWidth * imageWidthFraction;
            final imageHeight = imageWidth < minImageHeight
                ? minImageHeight
                : imageWidth;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  key: const Key('category-food-image'),
                  width: imageWidth,
                  height: imageHeight,
                  child: _FoodImagePane(imageUrl: imageUrl, isVeg: isVeg),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (restaurantName.trim().isNotEmpty)
                          Text(
                            restaurantName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        if (foodName.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            foodName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ],
                        if (hasMeta) ...[
                          const SizedBox(height: 4),
                          _DistanceCuisineRow(
                            distanceLabel: trimmedDistance,
                            cuisineLabel: trimmedCuisine,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ],
                        if (trimmedDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            trimmedDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                formatInrWhole(price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            quantity > 0
                                ? _QuantityStepper(
                                    quantity: quantity,
                                    isUpdating: isUpdating,
                                    onIncrease: onIncreaseTap,
                                    onDecrease: onDecreaseTap,
                                  )
                                : _AddButton(
                                    onPressed: isUpdating ? null : onAddTap,
                                    isUpdating: isUpdating,
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DistanceCuisineRow extends StatelessWidget {
  const _DistanceCuisineRow({
    required this.distanceLabel,
    required this.cuisineLabel,
    required this.style,
  });

  final String distanceLabel;
  final String cuisineLabel;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (distanceLabel.isNotEmpty)
          Text(
            distanceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        if (distanceLabel.isNotEmpty && cuisineLabel.isNotEmpty)
          Text('  ·  ', style: style),
        if (cuisineLabel.isNotEmpty)
          Expanded(
            child: Text(
              cuisineLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
  }
}

class _FoodImagePane extends StatelessWidget {
  const _FoodImagePane({required this.isVeg, this.imageUrl});

  final String? imageUrl;
  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildImage(),
        Positioned(top: 8, left: 8, child: _VegIndicator(isVeg: isVeg)),
      ],
    );
  }

  Widget _buildImage() {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      return const _FoodImagePlaceholder();
    }

    return SizedNetworkImage(
      url: url,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: const _FoodImagePlaceholder(showProgress: true),
      error: const _FoodImagePlaceholder(),
    );
  }
}

class _FoodImagePlaceholder extends StatelessWidget {
  const _FoodImagePlaceholder({this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border.withValues(alpha: 0.45),
      child: Center(
        child: showProgress
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.fastfood_rounded,
                size: 28,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }
}

class _VegIndicator extends StatelessWidget {
  const _VegIndicator({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1.4),
      ),
      child: SizedBox(
        width: 15,
        height: 15,
        child: Center(
          child: isVeg
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                )
              : Transform.rotate(
                  angle: 0.785398,
                  child: Container(width: 5, height: 5, color: color),
                ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onPressed, this.isUpdating = false});

  final VoidCallback? onPressed;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        minimumSize: const Size(64, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: isUpdating
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textLight,
              ),
            )
          : const Text(
              'ADD',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.isUpdating,
    this.onIncrease,
    this.onDecrease,
  });

  final int quantity;
  final bool isUpdating;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary),
      ),
      child: SizedBox(
        height: 32,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperIconButton(
              icon: Icons.remove_rounded,
              onPressed: isUpdating ? null : onDecrease,
            ),
            SizedBox(
              width: 22,
              child: Center(
                child: isUpdating
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            _StepperIconButton(
              icon: Icons.add_rounded,
              onPressed: isUpdating ? null : onIncrease,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  const _StepperIconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 32,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 32),
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
