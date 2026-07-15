import 'package:flutter/material.dart';

import 'food_card.dart';

class FoodSection extends StatelessWidget {
  const FoodSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Popular Foods",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          height: 250,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 10,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, index) {
              return FoodCard(
                foodName: "Chicken Burger",
                restaurantName: "Hungers Restaurant",
                price: "₹149",
                rating: 4.8,
                imageUrl: null,
                isVeg: false,
                isFavorite: false,
                onTap: () {
                  // TODO:
                  // Navigate to Food Details
                },
                onFavoriteTap: () {
                  // TODO:
                  // Toggle Favorite
                },
              );
            },
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}