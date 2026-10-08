import '../../../location/domain/entities/user_location.dart';
import '../entities/restaurant_entity.dart';
import '../repositories/restaurant_repository.dart';
import '../restaurant_delivery_range.dart';

class SearchRestaurants {
  final RestaurantRepository repository;

  const SearchRestaurants({required this.repository});

  /// Restaurants matching [keyword] that can deliver to [destination] (the
  /// customer's selected delivery destination). No destination → empty, never
  /// the nationwide match list.
  Future<List<RestaurantEntity>> call(
    String keyword, {
    required UserLocation? destination,
  }) async {
    if (destination == null) {
      return const [];
    }
    return RestaurantDeliveryRange.within(
      restaurants: await repository.searchRestaurants(keyword),
      destination: destination,
    );
  }
}
