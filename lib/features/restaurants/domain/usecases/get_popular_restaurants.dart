import '../../../location/domain/entities/user_location.dart';
import '../entities/restaurant_entity.dart';
import '../repositories/restaurant_repository.dart';
import '../restaurant_delivery_range.dart';
import '../restaurant_discovery_query.dart';

/// The best-rated restaurants that can deliver to [destination].
///
/// Ranking happens over the geohash-bounded, 15 km-scoped set — never a
/// nationwide top-20 that could leave a local customer with an empty list.
class GetPopularRestaurants {
  final RestaurantRepository repository;

  const GetPopularRestaurants({required this.repository});

  static const int limit = 20;

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
    return rankByRating(scoped, limit: limit);
  }

  /// Stable rating sort: ties keep incoming order (typically name).
  static List<RestaurantEntity> rankByRating(
    Iterable<RestaurantEntity> restaurants, {
    int limit = GetPopularRestaurants.limit,
  }) {
    final scoped = restaurants.toList();
    final order = {for (var i = 0; i < scoped.length; i++) scoped[i].id: i};
    final ranked = [...scoped]
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : order[a.id]!.compareTo(order[b.id]!);
      });
    return ranked.take(limit).toList();
  }
}
