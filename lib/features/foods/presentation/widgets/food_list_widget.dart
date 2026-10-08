import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/food_provider.dart';
import 'food_card.dart';

class FoodListWidget extends ConsumerWidget {
  final String restaurantId;
  final String restaurantName;

  const FoodListWidget({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(restaurantFoodsProvider(restaurantId));

    return foodsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),

      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(error.toString(), textAlign: TextAlign.center),
        ),
      ),

      data: (foods) {
        if (foods.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text("No Foods Available")),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
          itemCount: foods.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final food = foods[index];

            return FoodCard(
              key: ValueKey(food.id),
              foodName: food.name,
              restaurantName: restaurantName,
              price: food.finalPrice,
              rating: food.rating,
              imageUrl: food.imageUrl.isEmpty ? null : food.imageUrl,
              isVeg: food.isVeg,
              isFavorite: false,
              offerText: food.offerLabel,
              onAddTap: () {
                // Cart is wired from FoodSection on the restaurant screen.
              },
            );
          },
        );
      },
    );
  }
}
