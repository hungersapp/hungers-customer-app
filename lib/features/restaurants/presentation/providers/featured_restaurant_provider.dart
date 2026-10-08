import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/domain/entities/user_location.dart';
import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../domain/entities/restaurant_entity.dart';
import 'restaurant_provider.dart';

/// Featured Restaurant Provider
///
/// Featured restaurants that can deliver to the customer's selected delivery
/// destination; reloads when the destination changes.
final featuredRestaurantProvider =
    AsyncNotifierProvider<FeaturedRestaurantNotifier, List<RestaurantEntity>>(
      FeaturedRestaurantNotifier.new,
    );

class FeaturedRestaurantNotifier extends AsyncNotifier<List<RestaurantEntity>> {
  @override
  Future<List<RestaurantEntity>> build() async {
    final destination = await ref.watch(
      serviceableDeliveryDestinationProvider.future,
    );
    return _loadFeaturedRestaurants(destination);
  }

  Future<List<RestaurantEntity>> _loadFeaturedRestaurants(
    UserLocation? destination,
  ) async {
    // Not served / nothing chosen: nothing to list, nothing to read.
    if (destination == null) {
      return const [];
    }
    final useCase = ref.read(getFeaturedRestaurantsProvider);
    return await useCase(destination: destination);
  }

  /// Refresh Featured Restaurants
  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final destination = await ref.read(
        serviceableDeliveryDestinationProvider.future,
      );
      return _loadFeaturedRestaurants(destination);
    });
  }
}
