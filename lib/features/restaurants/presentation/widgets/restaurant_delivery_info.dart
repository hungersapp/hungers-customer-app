import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Displays delivery time and minimum order amount without overflowing. The
/// delivery fee is not shown here: it is priced by the backend on the road
/// distance to the customer's address (cart and checkout show it).
class RestaurantDeliveryInfo extends StatelessWidget {
  const RestaurantDeliveryInfo({
    super.key,
    required this.deliveryTime,
    required this.minimumOrderAmount,
  });

  final int deliveryTime;
  final double minimumOrderAmount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout = constraints.maxWidth < 280;

        final items = [
          _DeliveryInfoChip(
            icon: Icons.access_time_rounded,
            label: '$deliveryTime mins',
          ),
          _DeliveryInfoChip(
            icon: Icons.shopping_bag_outlined,
            label: 'Min ₹${minimumOrderAmount.toStringAsFixed(0)}',
          ),
        ];

        if (useCompactLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }

        return Wrap(spacing: 12, runSpacing: 8, children: items);
      },
    );
  }
}

class _DeliveryInfoChip extends StatelessWidget {
  const _DeliveryInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
