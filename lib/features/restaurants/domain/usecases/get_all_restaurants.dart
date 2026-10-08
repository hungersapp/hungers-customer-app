import '../../../location/domain/entities/user_location.dart';
import '../entities/restaurant_entity.dart';
import '../repositories/restaurant_repository.dart';
import '../restaurant_delivery_range.dart';
import '../restaurant_discovery_query.dart';
import '../discovery_debug_log.dart';

/// Customer-listable restaurants that can deliver to [destination].
///
/// Reads only geohash4 cells covering the destination (bounded per cell),
/// then applies the 15 km Haversine rule. There is no nationwide fallback.
class GetAllRestaurants {
  final RestaurantRepository repository;

  const GetAllRestaurants({required this.repository});

  Future<List<RestaurantEntity>> call({
    required UserLocation? destination,
  }) async {
    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(destination);
    discoveryDebug(
      'dest=${destination?.latitude},${destination?.longitude} '
      'selectedByCustomer=${destination?.selectedByCustomer} '
      'isLiveGpsDefault=${destination?.isLiveGpsDefault} '
      'geohash4Cells=$cells',
    );
    if (cells.isEmpty) {
      discoveryDebug('first_empty_stage=geohash cell generation');
      return const [];
    }
    final restaurants = await repository.getDiscoverableRestaurants(
      geohash4Cells: cells,
    );
    discoveryDebug('after_geohash_query=${restaurants.length}');
    if (restaurants.isEmpty) {
      discoveryDebug(
        'first_empty_stage=Firestore geohash4 equality query '
        '(if restaurants exist nearby: geohash4 missing, production backfill required)',
      );
      return const [];
    }
    final within = RestaurantDeliveryRange.within(
      restaurants: restaurants,
      destination: destination,
    );
    discoveryDebug(
      'after_15km=${within.length} removed_outside_15km=${restaurants.length - within.length}',
    );
    if (within.isEmpty) {
      discoveryDebug('first_empty_stage=Haversine 15 km filter');
    }
    return within;
  }
}
