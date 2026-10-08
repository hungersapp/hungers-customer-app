import '../../../location/domain/entities/user_location.dart';
import '../entities/restaurant_entity.dart';
import '../repositories/restaurant_repository.dart';
import '../restaurant_delivery_range.dart';
import '../restaurant_discovery_query.dart';

/// Featured restaurants that can deliver to [destination].
class GetFeaturedRestaurants {
  final RestaurantRepository repository;

  const GetFeaturedRestaurants({required this.repository});

  Future<List<RestaurantEntity>> call({
    required UserLocation? destination,
  }) async {
    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(destination);
    if (cells.isEmpty) {
      return const [];
    }
    final restaurants = await repository.getDiscoverableRestaurants(
      geohash4Cells: cells,
      featuredOnly: true,
    );
    return RestaurantDeliveryRange.within(
      restaurants: restaurants,
      destination: destination,
    );
  }
}
