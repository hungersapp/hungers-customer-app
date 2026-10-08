import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../location/presentation/providers/selected_destination_provider.dart';
import '../../../restaurants/domain/restaurant_delivery_range.dart';
import '../../../restaurants/presentation/providers/restaurant_details_provider.dart';
import '../../../serviceability/presentation/providers/destination_serviceability_provider.dart';
import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';

/// Re-checks whether the cart's restaurant can still deliver after the
/// customer changes discovery/delivery location. Does not clear or rewrite
/// the cart — checkout remains the place that blocks [placeOrder].
class CartDestinationWarning extends ConsumerWidget {
  const CartDestinationWarning({required this.restaurantId, super.key});

  final String restaurantId;

  static const outOfRangeMessage =
      'This restaurant cannot deliver to your selected location. '
      'Change your location or choose a closer restaurant. Your cart is unchanged.';

  static const notServedMessage =
      'This location is not currently served. '
      'Change your location or choose a saved address. Your cart is unchanged.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceability = ref.watch(destinationServiceabilityProvider);
    final destination = ref.watch(serviceableDeliveryDestinationProvider);
    final restaurant = ref.watch(restaurantDetailsProvider(restaurantId));

    if (serviceability.isLoading ||
        destination.isLoading ||
        restaurant.isLoading) {
      return const SizedBox.shrink();
    }

    if (serviceability.hasError ||
        serviceability.valueOrNull ==
            DestinationServiceability.unavailable ||
        serviceability.valueOrNull ==
            DestinationServiceability.notServiceable) {
      return const _Banner(message: notServedMessage);
    }

    final dest = destination.valueOrNull;
    final place = restaurant.valueOrNull;
    if (dest == null) {
      final selected =
          ref.watch(selectedDeliveryDestinationProvider).valueOrNull;
      if (selected == null) {
        return const SizedBox.shrink();
      }
      return const _Banner(message: notServedMessage);
    }
    if (place == null) {
      return const SizedBox.shrink();
    }
    if (!RestaurantDeliveryRange.isWithinRange(
      restaurant: place,
      destination: dest,
    )) {
      return const _Banner(message: outOfRangeMessage);
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
          ),
        ),
      ),
    );
  }
}
