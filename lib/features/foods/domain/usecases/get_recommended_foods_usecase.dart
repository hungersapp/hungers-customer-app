import '../../../location/domain/entities/user_location.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';
import '../../../restaurants/domain/restaurant_delivery_range.dart';
import '../entities/food_entity.dart';
import '../repositories/food_repository.dart';

class GetRecommendedFoodsUseCase {
  final FoodRepository repository;

  /// Resolves the restaurant (and its coordinates) that sells the foods.
  final RestaurantRepository restaurants;

  const GetRecommendedFoodsUseCase(this.repository, this.restaurants);

  /// The restaurant's recommended foods — only when that restaurant can
  /// deliver to [destination], the customer's selected delivery destination.
  ///
  /// The recommendation query and its order are unchanged; this only gates
  /// whether they are shown. Eligibility is the same [RestaurantDeliveryRange]
  /// rule Home discovery uses. Fail-closed: no destination, an unknown or
  /// non-customer-listable restaurant, or one out of range yields an empty
  /// list, and the foods are not even read.
  Future<List<FoodEntity>> call(
    String restaurantId, {
    required UserLocation? destination,
  }) async {
    if (destination == null) {
      return const [];
    }

    final restaurant = await restaurants.getRestaurantById(restaurantId);
    if (restaurant == null) {
      return const [];
    }

    final deliverable = RestaurantDeliveryRange.within(
      restaurants: [restaurant],
      destination: destination,
    );
    if (deliverable.isEmpty) {
      return const [];
    }

    return repository.getRecommendedFoods(restaurantId);
  }
}
