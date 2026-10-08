import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/usecases/get_popular_restaurants.dart';
import 'discoverable_restaurants_provider.dart';

/// Popular restaurants for the selected destination.
///
/// Ranks the shared [discoverableRestaurantsProvider] list (already
/// geohash-bounded and 15 km scoped). Does not issue a second catalog read.
final popularRestaurantProvider =
    AsyncNotifierProvider<PopularRestaurantNotifier, List<RestaurantEntity>>(
      PopularRestaurantNotifier.new,
    );

class PopularRestaurantNotifier extends AsyncNotifier<List<RestaurantEntity>> {
  @override
  Future<List<RestaurantEntity>> build() async {
    await ref.watch(serviceableDeliveryDestinationProvider.future);
    final restaurants = await ref.watch(
      discoverableRestaurantsProvider.future,
    );
    return GetPopularRestaurants.rankByRating(restaurants);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.invalidate(discoverableRestaurantsProvider);
      final restaurants = await ref.read(
        discoverableRestaurantsProvider.future,
      );
      return GetPopularRestaurants.rankByRating(restaurants);
    });
  }
}
