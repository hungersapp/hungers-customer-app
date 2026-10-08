import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/date_format.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../location/presentation/helpers/open_delivery_location_chooser.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../location/presentation/screens/saved_addresses_screen.dart';
import '../../../orders/domain/entities/placed_order.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../orders/presentation/screens/my_orders_screen.dart';
import '../../../orders/presentation/screens/order_details_screen.dart';
import '../../../orders/presentation/widgets/order_status_chip.dart';
import '../../../restaurants/presentation/providers/restaurant_details_provider.dart';
import '../../../serviceability/presentation/providers/serviceability_provider.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    this.showBackButton = false,
  });

  final bool showBackButton;

  static const double _contentMaxWidth = 920;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: showBackButton,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(
                  user: user,
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(
                          name: AppRoutes.editProfile,
                        ),
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                _TrackYourOrderSection(userId: userId),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel(label: 'My Activity'),
                const SizedBox(height: AppSpacing.sm),
                _MenuCard(
                  children: [
                    _ProfileMenuTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'My Orders',
                      subtitle: 'View your recent orders',
                      onTap: () => _openOrders(context),
                    ),
                    _ProfileMenuTile(
                      icon: Icons.star_outline_rounded,
                      title: 'Reviews',
                      subtitle: 'Rate delivered orders',
                      onTap: () => _openOrders(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel(label: 'Saved'),
                const SizedBox(height: AppSpacing.sm),
                _SavedSection(userId: userId),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel(label: 'More'),
                const SizedBox(height: AppSpacing.sm),
                _MenuCard(
                  children: [
                    const _ProfileMenuTile(
                      icon: Icons.local_offer_outlined,
                      title: 'Offers & Coupons',
                      subtitle: 'Coming soon',
                      comingSoon: true,
                    ),
                    const _ProfileMenuTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Coming soon',
                      comingSoon: true,
                    ),
                    _ProfileMenuTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Name and account details',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: AppRoutes.editProfile,
                            ),
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                    _ProfileMenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'Send us a message',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton(
                  onPressed: () => _confirmLogout(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                  ),
                  child: const Text(
                    'Logout',
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

  void _openOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.orders),
        builder: (_) => const MyOrdersScreen(showBackButton: true),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
            'You will need to sign in again to place orders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textLight,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    await ref.read(authProvider.notifier).logout();

    if (userId != null) {
      ref.invalidate(cartItemsProvider(userId));
      ref.invalidate(cartTotalProvider(userId));
      ref.invalidate(cartItemCountProvider(userId));
      ref.invalidate(customerOrdersProvider(userId));
      ref.invalidate(userLocationProvider(userId));
      ref.invalidate(deliveryPincodeProvider(userId));
    }
    ref.read(serviceabilityProvider.notifier).invalidate();
    ref.read(lastViewedRestaurantProvider.notifier).state = null;

    if (!context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onEdit,
  });

  final AuthUser? user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _displayName(user);
    final mobile = _displayMobile(user);
    final photoUrl = user?.photoUrl?.trim() ?? '';

    return Material(
      color: AppColors.surface,
      elevation: 1.5,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: photoUrl.isEmpty
                  ? null
                  : ResizeImage(NetworkImage(photoUrl), width: 136, height: 136),
              child: photoUrl.isEmpty
                  ? Text(
                      _initials(name),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    mobile,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  static String _displayName(AuthUser? user) {
    final name = user?.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Customer';
  }

  static String _displayMobile(AuthUser? user) {
    final mobile = user?.mobileNumber?.trim();
    if (mobile != null && mobile.isNotEmpty) {
      return mobile;
    }
    return 'Mobile not added';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'T';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _TrackYourOrderSection extends ConsumerWidget {
  const _TrackYourOrderSection({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(label: 'Track Your Order'),
        const SizedBox(height: AppSpacing.sm),
        if (userId == null)
          const _NoActiveOrderCard()
        else
          ref.watch(customerOrdersProvider(userId!)).when(
                loading: () => const _TrackOrderLoadingCard(),
                error: (_, _) => _TrackOrderErrorCard(
                  onRetry: () {
                    ref.invalidate(customerOrdersProvider(userId!));
                  },
                ),
                data: (page) {
                  final active = page.orders
                      .where((order) => order.status.isOngoing)
                      .toList();
                  if (active.isEmpty) {
                    return const _NoActiveOrderCard();
                  }
                  return _ActiveOrderCard(
                    order: active.first,
                    onView: () => _openOrderDetails(context, active.first),
                  );
                },
              ),
      ],
    );
  }

  void _openOrderDetails(BuildContext context, PlacedOrder order) {
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
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.order,
    required this.onView,
  });

  final PlacedOrder order;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restaurant = order.restaurantName.trim().isEmpty
        ? 'Restaurant'
        : order.restaurantName.trim();

    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Active order',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    OrderStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  restaurant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Order #${order.shortId}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatOrderDateTime(order.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatInrWhole(order.grandTotal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: onView,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      child: const Text(
                        'View Order',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoActiveOrderCard extends StatelessWidget {
  const _NoActiveOrderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primary.withValues(alpha: 0.9),
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Your next meal is waiting',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No active orders right now.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              child: const Text(
                'Explore Food',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackOrderLoadingCard extends StatelessWidget {
  const _TrackOrderLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Checking active orders…',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackOrderErrorCard extends StatelessWidget {
  const _TrackOrderErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'Unable to load active order',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, 40),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedSection extends ConsumerWidget {
  const _SavedSection({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String locationSubtitle = 'Not configured';

    if (userId != null) {
      final locationAsync = ref.watch(userLocationProvider(userId!));
      locationSubtitle = locationAsync.when(
        loading: () => 'Loading…',
        error: (_, _) => 'Not configured',
        data: (UserLocation? location) {
          if (location == null) {
            return 'Not configured';
          }
          final label = location.displayAddress.trim();
          return label.isEmpty ? 'Not configured' : label;
        },
      );
    }

    return _MenuCard(
      children: [
                    _ProfileMenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'Delivery Location',
                      subtitle: locationSubtitle,
                      onTap: () => openDeliveryLocationChooser(context, ref),
                    ),
                    _ProfileMenuTile(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Saved Addresses',
                      subtitle: 'Home, Work, Other',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedAddressesScreen(),
                          ),
                        );
                      },
                    ),
        const _ProfileMenuTile(
          icon: Icons.favorite_border_rounded,
          title: 'Favourites',
          subtitle: 'Coming soon',
          comingSoon: true,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(
                height: 1,
                indent: 56,
                color: AppColors.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final enabled = !comingSoon && onTap != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      minVerticalPadding: AppSpacing.sm,
      onTap: comingSoon
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title will be available soon.')),
              );
            }
          : onTap,
      leading: Icon(
        icon,
        color: comingSoon ? AppColors.textSecondary : AppColors.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: comingSoon ? AppColors.textSecondary : AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
      trailing: comingSoon
          ? const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
            )
          : (enabled
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                )
              : null),
    );
  }
}
