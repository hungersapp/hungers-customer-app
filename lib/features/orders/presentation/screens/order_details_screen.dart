import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/date_format.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/keep_screen_awake.dart';
import '../../../../core/widgets/sized_network_image.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../restaurants/presentation/providers/restaurant_details_provider.dart';
import '../../../reviews/presentation/screens/rate_order_screen.dart';
import '../../domain/entities/placed_order.dart';
import '../../domain/order_tracking_map_plan.dart';
import '../../domain/rider_location_freshness.dart';
import '../../../cart/presentation/widgets/bill_details_card.dart';
import '../providers/order_provider.dart';
import '../providers/rider_location_provider.dart';
import '../widgets/delivery_partner_card.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/order_tracking_map.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;
  final PlacedOrder? initialOrder;

  static const double _contentMaxWidth = 920;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final passed = initialOrder;

    if (passed != null && (userId == null || passed.userId == userId)) {
      return _orderBody(context, ref, passed, userId);
    }

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details'), centerTitle: true),
        body: const Center(child: Text('Please login to view this order.')),
      );
    }

    final async = ref.watch(
      orderDetailsProvider(OrderLookup(userId: userId, orderId: orderId)),
    );

    return async.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details'), centerTitle: true),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Unable to load this order',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(
                      orderDetailsProvider(
                        OrderLookup(userId: userId, orderId: orderId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (order) => _orderBody(context, ref, order, userId),
    );
  }

  Widget _orderBody(
    BuildContext context,
    WidgetRef ref,
    PlacedOrder order,
    String? userId,
  ) {
    final pickupUsable = hasUsableMapCoordinates(
      order.pickupLocation?.latitude,
      order.pickupLocation?.longitude,
    );
    double? restaurantLatitude;
    double? restaurantLongitude;
    if (!pickupUsable && order.restaurantId.trim().isNotEmpty) {
      final restaurant =
          ref.watch(restaurantDetailsProvider(order.restaurantId)).valueOrNull;
      restaurantLatitude = restaurant?.latitude;
      restaurantLongitude = restaurant?.longitude;
    }

    return _OrderDetailsBody(
      order: order,
      restaurantLatitude: restaurantLatitude,
      restaurantLongitude: restaurantLongitude,
      onReorder: order.status.canReorder && userId != null
          ? () => _reorder(context, ref, userId, order)
          : null,
    );
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    String userId,
    PlacedOrder order,
  ) async {
    if (order.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order has no items to reorder.')),
      );
      return;
    }

    try {
      for (final item in order.items) {
        await ref
            .read(cartNotifierProvider.notifier)
            .addToCart(
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
        const SnackBar(content: Text('Unable to reorder. Please try again.')),
      );
    }
  }
}

class _OrderDetailsBody extends ConsumerWidget {
  const _OrderDetailsBody({
    required this.order,
    this.onReorder,
    this.restaurantLatitude,
    this.restaurantLongitude,
  });

  final PlacedOrder order;
  final VoidCallback? onReorder;
  final double? restaurantLatitude;
  final double? restaurantLongitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryLines = _deliveryLines(order.deliveryAddress);
    final paymentStatus = order.paymentStatus.trim();
    final tracking = order.status.isOngoing
        ? ref.watch(riderTrackingProvider(order.id)).asData?.value
        : null;
    final rider = tracking != null && tracking.isLiveTrackingActive
        ? tracking.riderLocation
        : null;
    final now = DateTime.now();
    final fresh = rider != null && rider.isFreshAt(now);
    final mapPlan = buildOrderTrackingMapPlan(
      status: trackingMapStatus(
        orderStatus: order.status,
        deliveryJobStatus: tracking?.status,
      ),
      pickup: order.pickupLocation,
      deliveryAddress: order.deliveryAddress,
      restaurantLatitude: restaurantLatitude,
      restaurantLongitude: restaurantLongitude,
      restaurantName: order.restaurantName.trim().isEmpty
          ? 'Restaurant'
          : order.restaurantName.trim(),
      riderLatitude: fresh ? rider.latitude : null,
      riderLongitude: fresh ? rider.longitude : null,
      riderUpdatedAt: fresh ? rider.updatedAt : null,
      riderLocationFresh: fresh,
    );
    final riderLocationStale = rider != null && !fresh;

    // Keep the screen awake only while this order is still ongoing (live
    // tracking) — a past/terminal order (delivered/cancelled) being
    // viewed here needs no wakelock, and leaving this screen entirely
    // always disables it (see KeepScreenAwakeWhile's own doc comment).
    return KeepScreenAwakeWhile(
      keepAwake: order.status.isOngoing,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details'), centerTitle: true),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: OrderDetailsScreen._contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                _StatusHero(order: order),
                if (!mapPlan.isEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  OrderTrackingMap(plan: mapPlan),
                  if (riderLocationStale) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Rider location is temporarily unavailable',
                      key: Key('rider-location-unavailable'),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ] else if (fresh) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Rider approaching',
                      key: const Key('rider-approaching'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      RiderLocationFreshness.updatedLabel(rider.updatedAt, now),
                      key: const Key('rider-location-updated'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
                if (tracking != null && tracking.isAssigned) ...[
                  const SizedBox(height: AppSpacing.md),
                  DeliveryPartnerCard(order: order, tracking: tracking),
                ],
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Restaurant',
                  child: Text(
                    order.restaurantName.trim().isEmpty
                        ? 'Restaurant'
                        : order.restaurantName.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Your Items',
                  child: Column(
                    children: [
                      if (order.items.isEmpty)
                        Text(
                          order.itemsSummary,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        for (var i = 0; i < order.items.length; i++) ...[
                          _ItemRow(item: order.items[i]),
                          if (i < order.items.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                height: 1,
                                color: AppColors.divider,
                              ),
                            ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _OrderBillCard(order: order),
                if (deliveryLines != null || order.hasRecipient) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Delivery Address',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.hasRecipient
                              ? 'Delivering to recipient'
                              : 'Delivering to you',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (order.hasRecipient) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            order.recipientName!.trim(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if ((order.recipientPhone ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              order.recipientPhone!.trim(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                        if (deliveryLines != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            deliveryLines,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Payment',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.paymentMethodLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (paymentStatus.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Status: $paymentStatus',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (order.status == OrderStatus.delivered) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _ReviewOrderAction(order: order),
                ],
                if (onReorder != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: onReorder,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                    child: const Text(
                      'Reorder',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _deliveryLines(OrderDeliveryAddress? address) {
    if (address == null) {
      return null;
    }

    final lines = <String>[];
    final street = address.address?.trim() ?? '';
    if (street.isNotEmpty) {
      lines.add(street);
    }

    final city = address.city?.trim() ?? '';
    final state = address.state?.trim() ?? '';
    final cityState = [
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ].join(', ');
    if (cityState.isNotEmpty) {
      lines.add(cityState);
    }

    final pin = address.pincode?.trim() ?? '';
    if (pin.isNotEmpty) {
      lines.add(pin);
    }

    if (lines.isEmpty) {
      return null;
    }
    return lines.join('\n');
  }
}

class _ReviewOrderAction extends ConsumerStatefulWidget {
  const _ReviewOrderAction({required this.order});

  final PlacedOrder order;

  @override
  ConsumerState<_ReviewOrderAction> createState() => _ReviewOrderActionState();
}

class _ReviewOrderActionState extends ConsumerState<_ReviewOrderAction> {
  bool _submittedLocally = false;

  bool get _reviewed => widget.order.hasReview || _submittedLocally;

  Future<void> _openRate() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RateOrderScreen(order: widget.order),
      ),
    );
    if (!mounted || submitted != true) {
      return;
    }
    setState(() => _submittedLocally = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_reviewed) {
      return const Text(
        '✓ Reviewed',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.freshGreen,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'How was your order?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Rate your experience',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _openRate,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textLight,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
          ),
          child: const Text(
            'Rate Your Order',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.order});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(order.status);

    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              Text(
                'TRACK YOUR ORDER',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OrderStatusChip(status: order.status),
              const SizedBox(height: AppSpacing.md),
              Text(
                _messageFor(order.status),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Order #${order.shortId}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatOrderDateTime(order.createdAt),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _messageFor(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return 'Waiting for payment confirmation. The restaurant receives your order once payment is verified.';
      case OrderStatus.placed:
        return 'Your order has been placed.';
      case OrderStatus.confirmed:
        return 'Restaurant has confirmed your order.';
      case OrderStatus.preparing:
        return 'Your food is being prepared.';
      case OrderStatus.ready:
        return 'Your order is ready.';
      case OrderStatus.outForDelivery:
        return 'Your order is on the way.';
      case OrderStatus.delivered:
        return 'Your order has been delivered.';
      case OrderStatus.cancelled:
        return 'This order was cancelled.';
    }
  }

  static Color _accentFor(OrderStatus status) {
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

class _OrderBillCard extends StatelessWidget {
  const _OrderBillCard({required this.order});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    return CheckoutBillSummary(summary: order.billingSummary);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderLineItem item;

  static const double _thumbSize = 52;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FoodThumb(
          imageUrl: item.foodImage,
          isVeg: item.isVeg,
          size: _thumbSize,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.foodName.trim().isEmpty ? 'Item' : item.foodName.trim()}  \u00d7 ${item.quantity}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatInr(item.unitPrice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          formatInr(item.lineTotal),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _FoodThumb extends StatelessWidget {
  const _FoodThumb({
    required this.imageUrl,
    required this.isVeg,
    required this.size,
  });

  final String imageUrl;
  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: url.isEmpty
                ? const _FoodPlaceholder()
                : SizedNetworkImage(
                    url: url,
                    fit: BoxFit.cover,
                    error: const _FoodPlaceholder(),
                    placeholder: const _FoodPlaceholder(showProgress: true),
                  ),
          ),
          Positioned(top: 4, left: 4, child: _VegDot(isVeg: isVeg)),
        ],
      ),
    );
  }
}

class _FoodPlaceholder extends StatelessWidget {
  const _FoodPlaceholder({this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border.withValues(alpha: 0.5),
      child: Center(
        child: showProgress
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.fastfood_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }
}

class _VegDot extends StatelessWidget {
  const _VegDot({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 1.2),
      ),
      child: SizedBox(
        width: 12,
        height: 12,
        child: Center(
          child: isVeg
              ? Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                )
              : Transform.rotate(
                  angle: 0.785398,
                  child: Container(width: 4, height: 4, color: color),
                ),
        ),
      ),
    );
  }
}
