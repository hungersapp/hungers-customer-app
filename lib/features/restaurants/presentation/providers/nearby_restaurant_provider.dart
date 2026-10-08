import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/restaurant_delivery_range.dart';
import 'discoverable_restaurants_provider.dart';

/// Restaurants that can deliver to the destination, closest first.
final nearbyRestaurantProvider =
    AsyncNotifierProvider<NearbyRestaurantNotifier, List<RestaurantEntity>>(
      NearbyRestaurantNotifier.new,
    );

class NearbyRestaurantNotifier extends AsyncNotifier<List<RestaurantEntity>> {
  @override
  Future<List<RestaurantEntity>> build() async {
    final destination = await ref.watch(
      serviceableDeliveryDestinationProvider.future,
    );
    final restaurants = await ref.watch(
      discoverableRestaurantsProvider.future,
    );
    if (destination == null) {
      return restaurants;
    }
    double distanceOf(RestaurantEntity restaurant) =>
        RestaurantDeliveryRange.distanceKm(
          restaurant: restaurant,
          destination: destination,
        ) ??
        double.infinity;
    return [...restaurants]
      ..sort((a, b) => distanceOf(a).compareTo(distanceOf(b)));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.invalidate(discoverableRestaurantsProvider);
      return build();
    });
  }
}
