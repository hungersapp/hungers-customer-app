import 'package:flutter/material.dart';

import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sized_network_image.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({
    super.key,
    required this.foodName,
    required this.restaurantName,
    required this.price,
    required this.rating,
    this.imageUrl,
    this.isVeg = true,
    this.isFavorite = false,
    this.showRestaurantName = true,
    this.offerText,
    this.quantity = 0,
    this.isUpdating = false,
    this.onTap,
    this.onFavoriteTap,
    this.onAddTap,
    this.onIncreaseTap,
    this.onDecreaseTap,
  });

  final String foodName;
  final String restaurantName;
  final double price;
  final double rating;

  final String? imageUrl;
  final String? offerText;

  final bool isVeg;
  final bool isFavorite;
  final bool showRestaurantName;

  /// Current cart quantity for THIS food. 0 shows ADD.
  final int quantity;
  final bool isUpdating;

  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onIncreaseTap;
  final VoidCallback? onDecreaseTap;

  static const double imageAspectRatio = 16 / 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Keep ADD / quantity outside the card InkWell so ADD never opens details.
    final detailsArea = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FoodImage(
          imageUrl: imageUrl,
          isVeg: isVeg,
          isFavorite: isFavorite,
          offerText: offerText,
          onFavoriteTap: onFavoriteTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (foodName.trim().isNotEmpty)
                Text(
                  foodName.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              if (showRestaurantName && restaurantName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              _RatingBadge(rating: rating),
            ],
          ),
        ),
      ],
    );

    return Material(
      color: AppColors.surface,
      elevation: 1.5,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          onTap == null
              ? detailsArea
              : InkWell(onTap: onTap, child: detailsArea),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
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
                const SizedBox(width: 6),
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
          ),
        ],
      ),
    );
  }
}

class _FoodImage extends StatelessWidget {
  const _FoodImage({
    required this.isVeg,
    required this.isFavorite,
    this.imageUrl,
    this.offerText,
    this.onFavoriteTap,
  });

  final String? imageUrl;
  final bool isVeg;
  final bool isFavorite;
  final String? offerText;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: FoodCard.imageAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(),
          Positioned(top: 8, left: 8, child: _VegIndicator(isVeg: isVeg)),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: AppColors.surface,
              elevation: 1,
              shadowColor: AppColors.shadow,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onFavoriteTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: AppColors.accent,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
          if (offerText != null && offerText!.isNotEmpty)
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    offerText!,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final url = imageUrl;

    if (url == null || url.isEmpty) {
      return const _FoodImagePlaceholder();
    }

    return SizedNetworkImage(
      url: url,
      fit: BoxFit.cover,
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
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

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              color: AppColors.textLight,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
