import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../domain/entities/restaurant_entity.dart';
import 'discoverable_restaurants_provider.dart';

/// Restaurant List Provider
///
/// Reuses [discoverableRestaurantsProvider] so See All does not re-download
/// the catalog after Popular Near You already loaded it.
final restaurantListProvider =
    AsyncNotifierProvider<RestaurantListNotifier, List<RestaurantEntity>>(
      RestaurantListNotifier.new,
    );

class RestaurantListNotifier extends AsyncNotifier<List<RestaurantEntity>> {
  @override
  Future<List<RestaurantEntity>> build() async {
    await ref.watch(serviceableDeliveryDestinationProvider.future);
    return ref.watch(discoverableRestaurantsProvider.future);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.invalidate(discoverableRestaurantsProvider);
      return ref.read(discoverableRestaurantsProvider.future);
    });
  }
}
