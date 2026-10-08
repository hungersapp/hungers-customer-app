import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/date_format.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../domain/entities/placed_order.dart';
import '../../../reviews/presentation/screens/rate_order_screen.dart';
import '../providers/order_provider.dart';
import 'order_details_screen.dart';
import '../widgets/order_status_chip.dart';

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({
    super.key,
    this.showBackButton = false,
    this.onBrowseRestaurants,
  });

  final bool showBackButton;
  final VoidCallback? onBrowseRestaurants;

  static const double _contentMaxWidth = 920;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        centerTitle: true,
        automaticallyImplyLeading: showBackButton,
      ),
      body: userId == null
          ? const _MessageView(message: 'Please login to view your orders.')
          : ref.watch(customerOrdersProvider(userId)).when(
                loading: () => const _OrdersLoadingView(),
                error: (_, _) => _OrdersErrorView(
                  onRetry: () => ref.invalidate(customerOrdersProvider(userId)),
                ),
                data: (page) {
                  final orders = page.orders;
                  if (orders.isEmpty) {
                    return _EmptyOrdersView(
                      onBrowse: onBrowseRestaurants ??
                          () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.dashboard,
                              (route) =>
                                  route.settings.name == AppRoutes.login ||
                                  route.settings.name == AppRoutes.splash,
                            );
                          },
                    );
                  }

                  final ongoing =
                      orders.where((order) => order.status.isOngoing).toList();
                  final past =
                      orders.where((order) => order.status.isPast).toList();

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _contentMaxWidth,
                      ),
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(customerOrdersProvider(userId));
                          await ref.read(customerOrdersProvider(userId).future);
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            if (ongoing.isNotEmpty) ...[
                              const _SectionTitle(title: 'Ongoing Orders'),
                              const SizedBox(height: 12),
                              for (final order in ongoing) ...[
                                _OrderCard(
                                  order: order,
                                  onView: () => _openDetails(context, order),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                            if (past.isNotEmpty) ...[
                              if (ongoing.isNotEmpty) const SizedBox(height: 8),
                              const _SectionTitle(title: 'Past Orders'),
                              const SizedBox(height: 12),
              for (final order in past) ...[
                                _OrderCard(
                                  order: order,
                                  onView: () => _openDetails(context, order),
                                  onReorder: () => _reorder(
                                    context: context,
                                    ref: ref,
                                    userId: userId,
                                    order: order,
                                  ),
                                  onRate: order.canReview
                                      ? ({rating, deliveryRating}) => _openRate(
                                          context,
                                          order,
                                          rating: rating,
                                          deliveryRating: deliveryRating,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                            if (page.hasMore) ...[
                              const SizedBox(height: 8),
                              if (page.isLoadingMore)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              else
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      ref
                                          .read(
                                            customerOrdersProvider(
                                              userId,
                                            ).notifier,
                                          )
                                          .loadMore();
                                    },
                                    child: const Text('Load More'),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  void _openDetails(BuildContext context, PlacedOrder order) {
    Navigator.push(
      context,
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
  }

  void _openRate(
    BuildContext context,
    PlacedOrder order, {
    int? rating,
    int? deliveryRating,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RateOrderScreen(
          order: order,
          initialRating: rating,
          initialDeliveryRating: deliveryRating,
        ),
      ),
    );
  }

  Future<void> _reorder({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required PlacedOrder order,
  }) async {
    if (order.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order has no items to reorder.')),
      );
      return;
    }

    try {
      for (final item in order.items) {
        await ref.read(cartNotifierProvider.notifier).addToCart(
              CartEntity(
                id: item.foodId,
                userId: userId,
                restaurantId: order.restaurantId,
                restaurantName: order.restaurantName,
                foodId: item.foodId,
                foodName: item.foodName,
                foodImage: item.foodImage,
                price: item.price,
                offerPrice: item.offerPrice,
                quantity: item.quantity,
                isVeg: item.isVeg,
                isAvailable: true,
                createdAt: DateTime.now(),
              ),
            );
        if (ref.read(cartNotifierProvider).hasError) {
          throw StateError('Unable to add item');
        }
      }

      if (!context.mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.cart),
          builder: (_) => const CartScreen(),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to reorder. Please try again.'),
        ),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onView,
    this.onReorder,
    this.onRate,
  });

  final PlacedOrder order;
  final VoidCallback onView;
  final VoidCallback? onReorder;

  /// Opens the rating screen with the tapped star pre-selected.
  final void Function({int? rating, int? deliveryRating})? onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    order.restaurantName.isEmpty
                        ? 'Restaurant'
                        : order.restaurantName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OrderStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Order #${order.shortId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              order.itemsSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  formatInr(order.grandTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  formatOrderDateTime(order.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Order',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (onReorder != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onReorder,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reorder',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (onRate != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _InlineRating(
                        label: 'Your Food Rating',
                        onRate: (rating) => onRate!(rating: rating),
                      ),
                    ),
                    const VerticalDivider(
                      width: 16,
                      color: AppColors.divider,
                    ),
                    Expanded(
                      child: _InlineRating(
                        label: 'Delivery Rating',
                        onRate: (rating) => onRate!(deliveryRating: rating),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (order.hasReview) ...[
              const SizedBox(height: 10),
              const Text(
                '✓ Reviewed',
                style: TextStyle(
                  color: AppColors.freshGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Your Food Rating ☆☆☆☆☆" on a delivered order: tapping a star opens the
/// rating screen with it pre-selected.
class _InlineRating extends StatelessWidget {
  const _InlineRating({required this.label, required this.onRate});

  final String label;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              InkResponse(
                onTap: () => onRate(i),
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
                  child: Icon(
                    Icons.star_border_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
                    semanticLabel: '$label: $i of 5',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyOrdersView extends StatelessWidget {
  const _EmptyOrdersView({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: MyOrdersScreen._contentMaxWidth,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No orders yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your delicious journey starts here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onBrowse,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Browse Restaurants',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersLoadingView extends StatelessWidget {
  const _OrdersLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}

class _OrdersErrorView extends StatelessWidget {
  const _OrdersErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load orders',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
