import 'package:flutter/material.dart';

import '../../domain/entities/restaurant_entity.dart';

class RestaurantHeader extends StatelessWidget {
  final RestaurantEntity restaurant;

  const RestaurantHeader({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Restaurant Name
          Text(
            restaurant.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          /// Rating • Delivery Time • Delivery Fee
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),

              const SizedBox(width: 4),

              Text(
                restaurant.rating.toStringAsFixed(1),
                style: theme.textTheme.bodyMedium,
              ),
              if (restaurant.totalRatings > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '(${restaurant.totalRatings})',
                  style: theme.textTheme.bodySmall,
                ),
              ],

              const SizedBox(width: 16),

              const Icon(Icons.access_time, size: 18),

              const SizedBox(width: 4),

              Text(
                '${restaurant.deliveryTime} mins',
                style: theme.textTheme.bodyMedium,
              ),

            ],
          ),

          const SizedBox(height: 12),

          /// Cuisine
          if (restaurant.cuisines.isNotEmpty)
            Text(
              restaurant.cuisines.join(', '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),

          const SizedBox(height: 10),

          /// Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 18),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  restaurant.address,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          /// Open / Closed
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: restaurant.isOpen
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: restaurant.isOpen ? Colors.green : Colors.red,
                ),

                const SizedBox(width: 8),

                Text(
                  restaurant.isOpen ? 'Open Now' : 'Closed',
                  style: TextStyle(
                    color: restaurant.isOpen
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
