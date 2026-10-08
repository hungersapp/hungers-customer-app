import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/placed_order.dart';
import 'my_orders_screen.dart';
import 'order_details_screen.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.order,
  });

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 44,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Order placed',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.restaurantName.isEmpty
                        ? 'Your order is confirmed.'
                        : 'Your order from ${order.restaurantName} is confirmed.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formatInr(order.grandTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}  \u2022  Pay on delivery',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: RouteSettings(
                              name: AppRoutes.orderDetails,
                              arguments: order,
                            ),
                            builder: (_) => OrderDetailsScreen(
                              orderId: order.id,
                              initialOrder: order,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'View Order',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: const RouteSettings(name: AppRoutes.orders),
                            builder: (_) =>
                                const MyOrdersScreen(showBackButton: true),
                          ),
                        );
                      },
                      child: const Text(
                        'My Orders',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        if (navigator.canPop()) {
                          navigator.popUntil(
                            (route) =>
                                route.settings.name ==
                                    AppRoutes.restaurantDetails ||
                                route.settings.name == AppRoutes.dashboard ||
                                route.isFirst,
                          );
                          return;
                        }
                        navigator.pushNamedAndRemoveUntil(
                          AppRoutes.dashboard,
                          (route) => false,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Back to Menu',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
