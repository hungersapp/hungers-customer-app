import '../../../location/domain/entities/user_location.dart';
import '../entities/restaurant_entity.dart';
import '../repositories/restaurant_repository.dart';
import '../restaurant_delivery_range.dart';
import '../restaurant_discovery_query.dart';

/// Restaurants that can deliver to [destination], closest first.
class GetNearbyRestaurants {
  final RestaurantRepository repository;

  const GetNearbyRestaurants({required this.repository});

  Future<List<RestaurantEntity>> call({
    required UserLocation? destination,
  }) async {
    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(destination);
    if (cells.isEmpty) {
      return const [];
    }
    final restaurants = await repository.getDiscoverableRestaurants(
      geohash4Cells: cells,
    );
    final scoped = RestaurantDeliveryRange.within(
      restaurants: restaurants,
      destination: destination,
    );
    if (destination == null) {
      return scoped;
    }
    double distanceOf(RestaurantEntity restaurant) =>
        RestaurantDeliveryRange.distanceKm(
          restaurant: restaurant,
          destination: destination,
        ) ??
        double.infinity;
    return [...scoped]..sort((a, b) => distanceOf(a).compareTo(distanceOf(b)));
  }
}
