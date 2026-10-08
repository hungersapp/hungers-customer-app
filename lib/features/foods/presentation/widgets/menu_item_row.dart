import 'package:flutter/material.dart';

import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sized_network_image.dart';

/// One restaurant-menu item as a horizontal row: details on the left, the
/// food photo with ADD / quantity controls on the right.
///
/// ADD and the stepper sit outside the details tap target, so adding an item
/// never opens the food details page.
class MenuItemRow extends StatelessWidget {
  const MenuItemRow({
    super.key,
    required this.foodId,
    required this.name,
    required this.price,
    this.originalPrice,
    this.description = '',
    this.rating = 0,
    this.ratingCount = 0,
    this.imageUrl,
    this.isVeg = true,
    this.isRecommended = false,
    this.offerText,
    this.quantity = 0,
    this.onTap,
    this.onAdd,
    this.onIncrease,
    this.onDecrease,
  });

  final String foodId;
  final String name;

  /// What the customer pays per unit.
  final double price;

  /// Shown struck through when it is above [price].
  final double? originalPrice;
  final String description;
  final double rating;
  final int ratingCount;
  final String? imageUrl;
  final bool isVeg;
  final bool isRecommended;
  final String? offerText;

  /// Cart quantity for this food. 0 shows ADD.
  final int quantity;

  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  static const double imageSize = 116;
  static const double _controlHeight = 36;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStrike = originalPrice != null && originalPrice! > price;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _VegMark(isVeg: isVeg),
            if (isRecommended) ...[
              const SizedBox(width: 8),
              Text(
                'Bestseller',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              formatInrWhole(price),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (hasStrike) ...[
              const SizedBox(width: 6),
              Text(
                formatInrWhole(originalPrice!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
            if (offerText != null && offerText!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  offerText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.freshGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (rating > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 15,
                color: AppColors.freshGreen,
              ),
              const SizedBox(width: 2),
              Text(
                ratingCount > 0
                    ? '${rating.toStringAsFixed(1)} ($ratingCount)'
                    : rating.toStringAsFixed(1),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: onTap == null
                ? details
                : InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: details,
                  ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: imageSize,
            height: imageSize + _controlHeight / 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: imageSize,
                  child: GestureDetector(
                    onTap: onTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _image(),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 0,
                  height: _controlHeight,
                  child: quantity > 0
                      ? _Stepper(
                          foodId: foodId,
                          quantity: quantity,
                          onIncrease: onIncrease,
                          onDecrease: onDecrease,
                        )
                      : _AddButton(foodId: foodId, onPressed: onAdd),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return const _ImageFallback();
    }
    return SizedNetworkImage(
      url: url,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.cover,
      placeholder: const _ImageFallback(),
      error: const _ImageFallback(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border.withValues(alpha: 0.6),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 28,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _VegMark extends StatelessWidget {
  const _VegMark({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.error;
    return Semantics(
      label: isVeg ? 'Vegetarian' : 'Non-vegetarian',
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.foodId, this.onPressed});

  final String foodId;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('menu-add-$foodId'),
        onTap: onPressed,
        child: const Center(
          child: Text(
            'ADD',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.foodId,
    required this.quantity,
    this.onIncrease,
    this.onDecrease,
  });

  final String foodId;
  final int quantity;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      elevation: 2,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey<String>('menu-decrease-$foodId'),
              onTap: onDecrease,
              child: const Center(
                child: Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: AppColors.textLight,
                  semanticLabel: 'Decrease quantity',
                ),
              ),
            ),
          ),
          Text(
            '$quantity',
            key: ValueKey<String>('menu-quantity-$foodId'),
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: InkWell(
              key: ValueKey<String>('menu-increase-$foodId'),
              onTap: onIncrease,
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.textLight,
                  semanticLabel: 'Increase quantity',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
