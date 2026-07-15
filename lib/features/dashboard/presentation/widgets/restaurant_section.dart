import 'package:flutter/material.dart';

import 'restaurant_card.dart';

class RestaurantSection extends StatelessWidget {
  const RestaurantSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Nearby Restaurants",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 14),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 14),
          itemBuilder: (_, index) {
            return RestaurantCard(
              restaurantName:
                  "Hungers Restaurant ${index + 1}",
              cuisine:
                  "South Indian • Chinese • Fast Food",
              rating: 4.7,
              deliveryTime: "25 mins",
              deliveryFee: "₹40",
            );
          },
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}