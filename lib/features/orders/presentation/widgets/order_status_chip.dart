import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/placed_order.dart';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({
    super.key,
    required this.status,
  });

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  static Color _colorFor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.outForDelivery:
        return AppColors.info;
      case OrderStatus.awaitingPayment:
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return AppColors.warning;
      case OrderStatus.placed:
      case OrderStatus.confirmed:
        return AppColors.primary;
    }
  }
}
