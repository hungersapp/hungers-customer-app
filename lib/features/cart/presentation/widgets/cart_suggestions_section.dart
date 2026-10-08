import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sized_network_image.dart';
import '../../../foods/domain/entities/food_entity.dart';
import '../../../foods/presentation/providers/food_provider.dart';
import '../../domain/cart_quantity.dart';
import '../../domain/entities/cart_entity.dart';
import '../providers/cart_provider.dart';

/// Compact same-restaurant suggestions. Reuses [restaurantFoodsProvider]
/// (one restaurant query, not one query per card).
class CartSuggestionsSection extends ConsumerWidget {
  const CartSuggestionsSection({
    super.key,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.cartItems,
  });

  final String userId;
  final String restaurantId;
  final String restaurantName;
  final List<CartEntity> cartItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(restaurantFoodsProvider(restaurantId));
    final quantities = CartQuantity.indexByFoodId(cartItems);

    return foodsAsync.maybeWhen(
      data: (foods) {
        final sameRestaurantFoods = foods
            .where(
              (food) =>
                  food.restaurantId.isEmpty ||
                  food.restaurantId == restaurantId,
            )
            .toList();
        if (sameRestaurantFoods.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              restaurantName.trim().isEmpty
                  ? 'Add more from this restaurant'
                  : 'Add more from $restaurantName',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 228,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sameRestaurantFoods.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final food = sameRestaurantFoods[index];
                  return _SuggestionCard(
                    food: food,
                    quantity: quantities[food.id] ?? 0,
                    onAdd: () => _addFood(ref, food),
                    onIncrease: () => _changeQuantity(
                      ref,
                      food,
                      (quantities[food.id] ?? 0) + 1,
                    ),
                    onDecrease: () => _changeQuantity(
                      ref,
                      food,
                      (quantities[food.id] ?? 0) - 1,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Future<void> _addFood(WidgetRef ref, FoodEntity food) {
    return ref.read(cartNotifierProvider.notifier).addToCart(
          CartEntity(
            id: food.id,
            userId: userId,
            restaurantId: restaurantId,
            restaurantName: restaurantName,
            foodId: food.id,
            foodName: food.name,
            foodImage: food.imageUrl,
            price: food.price,
            offerPrice: food.offerPrice,
            quantity: 1,
            isVeg: food.isVeg,
            isAvailable: food.isAvailable,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _changeQuantity(
    WidgetRef ref,
    FoodEntity food,
    int nextQuantity,
  ) {
    return ref.read(cartNotifierProvider.notifier).updateQuantity(
          userId: userId,
          foodId: food.id,
          quantity: nextQuantity,
        );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.food,
    required this.quantity,
    required this.onAdd,
    required this.onIncrease,
    required this.onDecrease,
  });

  final FoodEntity food;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: food.imageUrl.isEmpty
                  ? const ColoredBox(
                      color: AppColors.border,
                      child: Center(
                        child: Icon(
                          Icons.fastfood_rounded,
                          color: AppColors.textSecondary,
                          size: 28,
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
                            color: AppColors.textSecondary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    food.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatInr(food.finalPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      quantity > 0
                          ? _MiniStepper(
                              quantity: quantity,
                              onIncrease: onIncrease,
                              onDecrease: onDecrease,
                            )
                          : _MiniAddButton(onPressed: onAdd),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAddButton extends StatelessWidget {
  const _MiniAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        minimumSize: const Size(48, 28),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text(
        'ADD',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary),
      ),
      child: SizedBox(
        height: 28,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniIconButton(
              icon: Icons.remove_rounded,
              onPressed: onDecrease,
            ),
            Text(
              '$quantity',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            _MiniIconButton(
              icon: Icons.add_rounded,
              onPressed: onIncrease,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 28,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 28),
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 14, color: AppColors.primary),
      ),
    );
  }
}
