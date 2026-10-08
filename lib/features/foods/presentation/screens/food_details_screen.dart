import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sized_network_image.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/domain/cart_quantity.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../cart/presentation/widgets/bottom_cart_bar.dart';
import '../../domain/entities/food_entity.dart';
import 'food_details_args.dart';

class FoodDetailsScreen extends ConsumerStatefulWidget {
  const FoodDetailsScreen({
    super.key,
    required this.food,
    required this.restaurantName,
  });

  final FoodEntity food;
  final String restaurantName;

  static const double _contentMaxWidth = 920;

  @override
  ConsumerState<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends ConsumerState<FoodDetailsScreen> {
  bool _updating = false;

  FoodEntity get food => widget.food;

  String get _displayName {
    if (food.name.trim().isNotEmpty) {
      return food.name.trim();
    }
    return food.description.trim().isNotEmpty
        ? food.description.trim()
        : 'Food item';
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    var quantity = 0;
    var itemCount = 0;
    double? cartTotal;

    if (userId != null) {
      final cartItems = ref.watch(cartItemsProvider(userId)).valueOrNull;
      if (cartItems != null) {
        quantity = CartQuantity.forFood(cartItems, food.id);
        itemCount = cartItems.fold<int>(
          0,
          (total, item) => total + item.quantity,
        );
      }
      cartTotal = ref.watch(cartTotalProvider(userId)).valueOrNull;
    }

    final showCartBar = itemCount > 0;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Food Details'), centerTitle: true),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FoodDetailsScreen._contentMaxWidth,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: food.imageUrl.trim().isEmpty
                        ? const ColoredBox(
                            color: AppColors.border,
                            child: Center(
                              child: Icon(
                                Icons.fastfood_rounded,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : SizedNetworkImage(
                            url: food.imageUrl,
                            fit: BoxFit.cover,
                            error: const ColoredBox(
                              color: AppColors.border,
                              child: Center(
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VegBadge(isVeg: food.isVeg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.restaurantName.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.restaurantName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RatingChip(rating: food.rating, count: food.ratingCount),
                    if (food.offerLabel != null) ...[
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            food.offerLabel!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  formatInr(food.finalPrice),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (food.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    food.description.trim(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (quantity > 0)
                  _QuantityControls(
                    quantity: quantity,
                    isUpdating: _updating,
                    onIncrease: () => _changeQuantity(quantity + 1),
                    onDecrease: () => _changeQuantity(quantity - 1),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _updating ? null : _addFood,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _updating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textLight,
                              ),
                            )
                          : const Text(
                              'ADD TO CART',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: showCartBar
          ? BottomCartBar(
              itemCount: itemCount,
              total: cartTotal,
              maxWidth: FoodDetailsScreen._contentMaxWidth,
              onViewCart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: AppRoutes.cart),
                    builder: (_) => const CartScreen(),
                  ),
                );
              },
            )
          : null,
    );
  }

  Future<void> _addFood() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _showMessage('Please login to add items.');
      return;
    }
    if (_updating) {
      return;
    }

    setState(() => _updating = true);
    try {
      await ref
          .read(cartNotifierProvider.notifier)
          .addToCart(
            CartEntity(
              id: food.id,
              userId: userId,
              restaurantId: food.restaurantId,
              restaurantName: widget.restaurantName,
              foodId: food.id,
              foodName: _displayName,
              foodImage: food.imageUrl,
              price: food.price,
              offerPrice: food.offerPrice,
              quantity: 1,
              isVeg: food.isVeg,
              isAvailable: food.isAvailable,
              createdAt: DateTime.now(),
            ),
          );
      if (ref.read(cartNotifierProvider).hasError) {
        _showMessage('Unable to add item. Please try again.');
        return;
      }
      await ref.read(cartItemsProvider(userId).future);
    } catch (_) {
      _showMessage('Unable to add item. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _changeQuantity(int nextQuantity) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _showMessage('Please login to update your cart.');
      return;
    }
    if (_updating) {
      return;
    }

    setState(() => _updating = true);
    try {
      await ref
          .read(cartNotifierProvider.notifier)
          .updateQuantity(
            userId: userId,
            foodId: food.id,
            quantity: nextQuantity,
          );
      if (ref.read(cartNotifierProvider).hasError) {
        _showMessage('Unable to update quantity. Please try again.');
        return;
      }
      await ref.read(cartItemsProvider(userId).future);
    } catch (_) {
      _showMessage('Unable to update quantity. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _VegBadge extends StatelessWidget {
  const _VegBadge({required this.isVeg});

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
        width: 18,
        height: 18,
        child: Center(
          child: isVeg
              ? Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                )
              : Transform.rotate(
                  angle: 0.785398,
                  child: Container(width: 6, height: 6, color: color),
                ),
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, this.count = 0});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: AppColors.textLight,
            ),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuantityControls extends StatelessWidget {
  const _QuantityControls({
    required this.quantity,
    required this.isUpdating,
    required this.onIncrease,
    required this.onDecrease,
  });

  final int quantity;
  final bool isUpdating;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              onPressed: isUpdating ? null : onDecrease,
              icon: const Icon(Icons.remove_rounded, color: AppColors.primary),
            ),
            Expanded(
              child: Center(
                child: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            IconButton(
              onPressed: isUpdating ? null : onIncrease,
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience opener used by food menu cards.
void openFoodDetails(
  BuildContext context, {
  required FoodEntity food,
  required String restaurantName,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      settings: RouteSettings(
        name: AppRoutes.foodDetails,
        arguments: FoodDetailsArgs(food: food, restaurantName: restaurantName),
      ),
      builder: (_) =>
          FoodDetailsScreen(food: food, restaurantName: restaurantName),
    ),
  );
}
