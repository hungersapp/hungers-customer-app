import '../../../location/domain/entities/user_location.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';
import '../../../restaurants/domain/restaurant_delivery_range.dart';
import '../../../restaurants/domain/restaurant_discovery_query.dart';
import '../entities/search_result_entity.dart';
import '../repositories/search_repository.dart';

/// Search, scoped to the customer's selected delivery destination.
///
/// Keyword match is bounded (geohash cells + nearby restaurant ids). A
/// restaurant/food result is kept only when [RestaurantDeliveryRange] says
/// it can deliver to [destination]. Fail-closed with no destination.
///
/// Load More is not offered: restaurant hits and food hits come from
/// different collections and cannot share a Firestore cursor without
/// skipping or duplicating results. Each source is capped at [resultLimit].
class SearchUseCase {
  const SearchUseCase(this.repository, this.restaurants);

  final SearchRepository repository;

  final RestaurantRepository restaurants;

  static const int resultLimit = 20;

  Future<List<SearchResultEntity>> searchRestaurants(
    String query, {
    required UserLocation? destination,
  }) {
    return _scoped(destination, (cells, ids) {
      return repository.searchRestaurants(
        query,
        geohash4Cells: cells,
        limit: resultLimit,
      );
    });
  }

  Future<List<SearchResultEntity>> searchFoods(
    String query, {
    required UserLocation? destination,
  }) {
    return _scoped(destination, (cells, ids) {
      return repository.searchFoods(
        query,
        restaurantIds: ids,
        limit: resultLimit,
      );
    });
  }

  Future<List<SearchResultEntity>> searchAll(
    String query, {
    required UserLocation? destination,
  }) {
    return _scoped(destination, (cells, ids) {
      return repository.searchAll(
        query,
        geohash4Cells: cells,
        restaurantIds: ids,
        limit: resultLimit,
      );
    });
  }

  Future<List<SearchResultEntity>> _scoped(
    UserLocation? destination,
    Future<List<SearchResultEntity>> Function(
      List<String> cells,
      List<String> restaurantIds,
    )
    search,
  ) async {
    if (destination == null) {
      return const [];
    }

    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(destination);
    if (cells.isEmpty) {
      return const [];
    }

    final listable = RestaurantDeliveryRange.within(
      restaurants: await restaurants.getDiscoverableRestaurants(
        geohash4Cells: cells,
      ),
      destination: destination,
    );
    if (listable.isEmpty) {
      return const [];
    }

    final deliverableIds = listable.map((restaurant) => restaurant.id).toSet();
    final matches = await search(cells, deliverableIds.toList());
    if (matches.isEmpty) {
      return const [];
    }

    return matches.where((result) {
      if (result.type == SearchResultType.category) {
        return result.id.trim().isNotEmpty && result.title.trim().isNotEmpty;
      }
      final restaurantId = result.owningRestaurantId;
      return restaurantId.isNotEmpty && deliverableIds.contains(restaurantId);
    }).toList();
  }
}
