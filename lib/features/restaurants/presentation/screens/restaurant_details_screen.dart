import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sized_network_image.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../cart/presentation/widgets/bottom_cart_bar.dart';
import '../../../foods/presentation/widgets/food_section.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../providers/restaurant_details_provider.dart';

class RestaurantDetailsScreen extends ConsumerWidget {
  final RestaurantEntity restaurant;

  const RestaurantDetailsScreen({super.key, required this.restaurant});

  static const double _contentMaxWidth = 960;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastViewed = ref.read(lastViewedRestaurantProvider);
    if (lastViewed?.id != restaurant.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ref.read(lastViewedRestaurantProvider.notifier).state = restaurant;
      });
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final heroHeight = screenWidth >= 900
        ? 180.0
        : (screenWidth * 0.38).clamp(148.0, 188.0);
    final horizontalPadding = screenWidth >= 600 ? 24.0 : 16.0;
    final userId = ref.watch(currentUserIdProvider);

    // Count and subtotal come from the same optimistic view the menu rows
    // use, so the sticky bar moves with every ADD / + / − tap.
    var itemCount = 0;
    double? cartTotal;
    if (userId != null) {
      final cartItems = ref.watch(effectiveCartItemsProvider(userId));
      if (cartItems != null) {
        itemCount = cartItems.fold<int>(
          0,
          (total, item) => total + item.quantity,
        );
        cartTotal = cartItems.fold<double>(
          0,
          (total, item) => total + item.totalPrice,
        );
      }
    }

    final showCartBar = itemCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: false,
            expandedHeight: heroHeight,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: _AppBarCircleButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            actions: [
              _AppBarCircleButton(
                icon: Icons.favorite_border_rounded,
                iconColor: AppColors.accent,
                onPressed: () {
                  // TODO: Favourite
                },
              ),
              const SizedBox(width: 8),
              _AppBarCircleButton(
                icon: Icons.share_rounded,
                onPressed: () {
                  // TODO: Share
                },
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _RestaurantHero(imageUrl: restaurant.displayImageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RestaurantInfo(restaurant: restaurant),
                      const SizedBox(height: 24),
                      FoodSection(
                        restaurantId: restaurant.id,
                        restaurantName: restaurant.name,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: showCartBar
          ? BottomCartBar(
              itemCount: itemCount,
              total: cartTotal,
              maxWidth: _contentMaxWidth,
              onViewCart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: AppRoutes.cart),
                    builder: (_) => const CartScreen(),
                  ),
                );
              },
            )
          : null,
    );
  }
}

class _AppBarCircleButton extends StatelessWidget {
  const _AppBarCircleButton({
    required this.icon,
    this.iconColor = AppColors.secondary,
    this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

class _RestaurantHero extends StatelessWidget {
  const _RestaurantHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: imageUrl.isNotEmpty
          ? SizedNetworkImage(
              url: imageUrl,
              fit: BoxFit.cover,
              placeholder: const _HeroFallback(),
              error: const _HeroFallback(),
            )
          : const _HeroFallback(),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border.withValues(alpha: 0.45),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 48,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _RestaurantInfo extends StatelessWidget {
  const _RestaurantInfo({required this.restaurant});

  final RestaurantEntity restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuisineLabel = restaurant.cuisines.join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (restaurant.logoUrl.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedNetworkImage(
                  url: restaurant.logoUrl.trim(),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  error: const SizedBox(width: 56, height: 56),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                restaurant.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MetaChip(
              icon: Icons.star_rounded,
              iconColor: AppColors.warning,
              label: restaurant.rating.toStringAsFixed(1),
            ),
            const _MetaDot(),
            _MetaChip(
              icon: Icons.schedule_rounded,
              label: '${restaurant.deliveryTime} mins',
            ),
            // The delivery fee depends on the road distance to the address
            // and is priced by the backend, so it is shown in the cart and
            // at checkout rather than as a fixed amount here.
            const _MetaDot(),
            const _MetaChip(
              icon: Icons.delivery_dining_rounded,
              label: 'Delivery fee by distance',
            ),
            if (restaurant.minimumOrderAmount > 0) ...[
              const _MetaDot(),
              _MetaChip(
                icon: Icons.shopping_bag_outlined,
                label: 'Min ${formatInrWhole(restaurant.minimumOrderAmount)}',
              ),
            ],
          ],
        ),
        if (cuisineLabel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            cuisineLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
        if (restaurant.address.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  restaurant.address,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _OpenStatusChip(isOpen: restaurant.isOpen),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '•',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OpenStatusChip extends StatelessWidget {
  const _OpenStatusChip({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final background = isOpen
        ? AppColors.success.withValues(alpha: 0.12)
        : AppColors.error.withValues(alpha: 0.10);
    final foreground = isOpen ? AppColors.success : AppColors.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: foreground),
            const SizedBox(width: 8),
            Text(
              isOpen ? 'Open Now' : 'Closed',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
