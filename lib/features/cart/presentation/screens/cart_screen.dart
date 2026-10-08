import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sized_network_image.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../offers/domain/entities/offer.dart';
import '../../../offers/domain/offer_failure.dart';
import '../../../offers/presentation/providers/offer_providers.dart';
import '../../../offers/presentation/widgets/offers_savings_section.dart';
import '../../../orders/domain/entities/placed_order.dart';
import '../../../serviceability/domain/geo_distance.dart';
import '../../../orders/presentation/screens/checkout_screen.dart';
import '../../domain/entities/cart_entity.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_destination_warning.dart';
import '../widgets/cart_suggestions_section.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const double _contentMaxWidth = 920;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Cart'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Please login'),
        ),
      );
    }

    final cartItems = ref.watch(cartItemsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Cart'),
        centerTitle: true,
      ),
      body: cartItems.when(
        loading: () => const _CartLoadingView(),
        error: (_, _) => _CartErrorView(
          onRetry: () {
            ref.invalidate(cartItemsProvider(userId));
            ref.invalidate(cartTotalProvider(userId));
          },
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyCartView();
          }

          final restaurantName = _singleRestaurantName(items);
          final restaurantId = _singleRestaurantId(items);

          return Column(
            children: [
              Expanded(
                child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _contentMaxWidth,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (restaurantName != null) ...[
                      _RestaurantHeader(name: restaurantName),
                      const SizedBox(height: 16),
                    ],
                    if (restaurantId != null)
                      CartDestinationWarning(restaurantId: restaurantId),
                    Text(
                      'Your Items',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < items.length; i++) ...[
                      _CartItemCard(
                        item: items[i],
                        showRestaurantName: restaurantName == null,
                        onIncrease: () {
                          ref.read(cartNotifierProvider.notifier).updateQuantity(
                                userId: userId,
                                foodId: items[i].foodId,
                                quantity: items[i].quantity + 1,
                              );
                        },
                        onDecrease: () async {
                          final nextQuantity = items[i].quantity - 1;

                          if (nextQuantity <= 0) {
                            final confirmed = await _confirmRemoveItem(
                              context,
                              items[i].foodName,
                            );
                            if (!confirmed || !context.mounted) {
                              return;
                            }
                          }

                          if (!context.mounted) {
                            return;
                          }

                          ref.read(cartNotifierProvider.notifier).updateQuantity(
                                userId: userId,
                                foodId: items[i].foodId,
                                quantity: nextQuantity,
                              );
                        },
                        onRemove: () async {
                          final confirmed = await _confirmRemoveItem(
                            context,
                            items[i].foodName,
                          );
                          if (!confirmed || !context.mounted) {
                            return;
                          }

                          ref.read(cartNotifierProvider.notifier).removeItem(
                                userId: userId,
                                foodId: items[i].foodId,
                              );
                        },
                      ),
                      if (i < items.length - 1) const SizedBox(height: 12),
                    ],
                    if (restaurantId != null) ...[
                      const SizedBox(height: 20),
                      CartSuggestionsSection(
                        userId: userId,
                        restaurantId: restaurantId,
                        restaurantName: restaurantName ??
                            items.first.restaurantName,
                        cartItems: items,
                      ),
                    ],
                    if (restaurantId != null) ...[
                      const SizedBox(height: 20),
                      _CartOffers(
                        userId: userId,
                        restaurantId: restaurantId,
                        items: items,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _CartDeliveryFee(userId: userId, items: items),
                    const SizedBox(height: 8),
                    Text(
                      'Taxes are added at checkout.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
                ),
              ),
              // Pinned: the total and the way forward stay in view.
              Material(
                color: AppColors.surface,
                elevation: 8,
                shadowColor: AppColors.shadow,
                child: SafeArea(
                  top: false,
                  child: Align(
                    alignment: Alignment.center,
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _contentMaxWidth,
                      ),
                      child: _CheckoutBar(
                        itemTotal: items.fold<double>(
                          0,
                          (total, item) => total + item.totalPrice,
                        ),
                        onCheckout: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: AppRoutes.checkout,
                              ),
                              builder: (_) => const CheckoutScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _singleRestaurantName(List<CartEntity> items) {
    final names = items
        .map((item) => item.restaurantName.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (names.length == 1) {
      return names.first;
    }

    return null;
  }

  String? _singleRestaurantId(List<CartEntity> items) {
    final ids = items
        .map((item) => item.restaurantId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (ids.length == 1) {
      return ids.first;
    }

    return null;
  }
}

class _RestaurantHeader extends StatelessWidget {
  const _RestaurantHeader({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Add more items',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.showRestaurantName,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final CartEntity item;
  final bool showRestaurantName;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.foodImage.isEmpty
                  ? const _FoodImageFallback()
                  : SizedNetworkImage(
                      url: item.foodImage,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      error: const _FoodImageFallback(),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _VegDot(isVeg: item.isVeg),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.foodName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showRestaurantName && item.restaurantName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    formatInr(item.finalPrice),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _QuantityStepper(
                        quantity: item.quantity,
                        onIncrease: onIncrease,
                        onDecrease: onDecrease,
                      ),
                      const Spacer(),
                      Text(
                        formatInr(item.totalPrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
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

class _FoodImageFallback extends StatelessWidget {
  const _FoodImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border.withValues(alpha: 0.6),
      child: const SizedBox(
        width: 96,
        height: 96,
        child: Icon(
          Icons.fastfood_rounded,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _VegDot extends StatelessWidget {
  const _VegDot({
    required this.isVeg,
  });

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: SizedBox(
        width: 14,
        height: 14,
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
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
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary),
      ),
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(
              icon: Icons.remove_rounded,
              onPressed: onDecrease,
            ),
            SizedBox(
              width: 22,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            _StepperButton(
              icon: Icons.add_rounded,
              onPressed: onIncrease,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: 32,
          height: 34,
        ),
        visualDensity: VisualDensity.compact,
        icon: Icon(
          icon,
          size: 18,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.itemTotal,
    required this.onCheckout,
  });

  final double itemTotal;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Item total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatInr(itemTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FilledButton(
                onPressed: onCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Proceed to Checkout',
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// Offers & Savings in the cart. Apply asks the backend to price this cart
/// with the offer (using the saved delivery address); the offer is only
/// shown as applied — and carried to checkout — once the backend accepts it.
class _CartOffers extends ConsumerStatefulWidget {
  const _CartOffers({
    required this.userId,
    required this.restaurantId,
    required this.items,
  });

  final String userId;
  final String restaurantId;
  final List<CartEntity> items;

  @override
  ConsumerState<_CartOffers> createState() => _CartOffersState();
}

class _CartOffersState extends ConsumerState<_CartOffers> {
  String? _busyOfferId;
  String? _message;

  /// The backend-confirmed saving and the cart contents it was confirmed for.
  double? _savedAmount;
  String? _savedForCart;

  String get _cartKey => ([
        for (final item in widget.items) '${item.foodId}:${item.quantity}',
      ]..sort())
          .join(',');

  double get _itemTotal => widget.items.fold<double>(
        0,
        (total, item) => total + item.totalPrice,
      );

  Future<void> _apply(Offer offer) async {
    final location = ref.read(userLocationProvider(widget.userId)).valueOrNull;
    if (location == null || !location.isCompleteForCheckout) {
      setState(() => _message = OfferFailureMessages.needsAddress);
      return;
    }
    final cartKey = _cartKey;
    setState(() {
      _busyOfferId = offer.id;
      _message = null;
    });
    try {
      final quote = await requestCheckoutQuote(
        ref.read(checkoutQuoteDatasourceProvider),
        items: widget.items,
        location: location,
        paymentMethod: OrderPaymentMethod.payOnDelivery.placeOrderValue,
        offer: offer,
      );
      if (!mounted) {
        return;
      }
      ref.read(appliedOfferProvider.notifier).state = AppliedOffer(
        offer: offer,
        restaurantId: widget.restaurantId,
      );
      setState(() {
        _busyOfferId = null;
        _savedAmount = quote.discount;
        _savedForCart = cartKey;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyOfferId = null;
        _message = error is OfferRejectedException
            ? OfferFailureMessages.forCode(
                error.code,
                offer: offer,
                itemTotal: _itemTotal,
              )
            : OfferFailureMessages.unavailable;
      });
    }
  }

  void _remove() {
    ref.read(appliedOfferProvider.notifier).state = null;
    setState(() {
      _message = null;
      _savedAmount = null;
      _savedForCart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final applied = appliedOfferFor(
      ref.watch(appliedOfferProvider),
      widget.restaurantId,
    );
    return OffersSavingsSection(
      restaurantId: widget.restaurantId,
      itemTotal: _itemTotal,
      appliedOffer: applied,
      // A saving confirmed for a different cart is not shown; checkout
      // re-prices the current one.
      savedAmount: _savedForCart == _cartKey ? _savedAmount : null,
      busyOfferId: _busyOfferId,
      message: _message,
      onApply: _apply,
      onRemove: _remove,
    );
  }
}

/// The delivery fee for this cart at the saved delivery address, as priced by
/// the backend (`quoteOrder`, road distance). The app holds no delivery rate
/// of its own: without a backend price this shows no amount.
class _CartDeliveryFee extends ConsumerStatefulWidget {
  const _CartDeliveryFee({required this.userId, required this.items});

  final String userId;
  final List<CartEntity> items;

  @override
  ConsumerState<_CartDeliveryFee> createState() => _CartDeliveryFeeState();
}

class _CartDeliveryFeeState extends ConsumerState<_CartDeliveryFee> {
  String? _key;
  double? _fee;
  double? _distanceKm;
  String? _error;

  // The fee depends only on the restaurant and the address, so changing a
  // quantity does not ask the backend again.
  String _keyFor(UserLocation location) => [
        widget.items.first.restaurantId.trim(),
        location.latitude.toStringAsFixed(6),
        location.longitude.toStringAsFixed(6),
      ].join('|');

  Future<void> _load(String key, UserLocation location) async {
    setState(() {
      _key = key;
      _fee = null;
      _distanceKm = null;
      _error = null;
    });
    try {
      final quote = await requestCheckoutQuote(
        ref.read(checkoutQuoteDatasourceProvider),
        items: widget.items,
        location: location,
        paymentMethod: OrderPaymentMethod.payOnDelivery.placeOrderValue,
      );
      if (!mounted || _key != key) {
        return;
      }
      setState(() {
        _fee = quote.deliveryFee;
        _distanceKm = quote.distanceKm;
      });
    } catch (error) {
      if (!mounted || _key != key) {
        return;
      }
      setState(() {
        _error = error is CheckoutQuoteUnavailableException &&
                error.code == 'NOT_SERVICEABLE'
            ? OfferFailureMessages.beyondDeliveryDistance
            : 'Delivery fee will be shown at checkout.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = ref.watch(userLocationProvider(widget.userId)).valueOrNull;
    final hasAddress = location != null && location.isCompleteForCheckout;

    if (hasAddress) {
      final key = _keyFor(location);
      if (key != _key) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && key != _key) {
            _load(key, location);
          }
        });
      }
    }

    final fee = _fee;
    final distanceKm = _distanceKm;
    final String value;
    String? caption;
    if (!hasAddress) {
      value = '—';
      caption = 'Add your delivery address to see the delivery fee.';
    } else if (fee != null) {
      value = formatInr(fee);
      caption = distanceKm == null
          ? null
          : '${GeoDistance.formatKmLabel(distanceKm)} from the restaurant';
    } else if (_error != null) {
      value = '—';
      caption = _error;
    } else {
      value = 'Calculating…';
    }

    return Container(
      key: const ValueKey<String>('cart-delivery-fee'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.delivery_dining_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delivery Fee',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                value,
                key: const ValueKey<String>('cart-delivery-fee-value'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CartScreen._contentMaxWidth,
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
                    Icons.shopping_cart_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your cart is empty',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Looks like you haven't added\nanything to your cart yet.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.dashboard,
                      (route) =>
                          route.settings.name == AppRoutes.login ||
                          route.settings.name == AppRoutes.splash,
                    );
                  },
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

class _CartLoadingView extends StatelessWidget {
  const _CartLoadingView();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CartScreen._contentMaxWidth,
        ),
        child: Shimmer.fromColors(
          baseColor: AppColors.border,
          highlightColor: AppColors.surface,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                height: 22,
                width: 160,
                color: AppColors.surface,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < 3; i++) ...[
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmRemoveItem(
  BuildContext context,
  String foodName,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Remove item?'),
        content: Text(
          'Remove $foodName from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

class _CartErrorView extends StatelessWidget {
  const _CartErrorView({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CartScreen._contentMaxWidth,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  'Unable to load your cart',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
