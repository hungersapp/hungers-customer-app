import '../../../location/domain/entities/user_location.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';
import '../../../restaurants/domain/restaurant_delivery_range.dart';
import '../../../restaurants/domain/restaurant_discovery_query.dart';
import '../entities/category_food_item.dart';
import '../entities/category_foods_page.dart';
import '../repositories/food_repository.dart';

/// Loads customer-visible foods for a Home category **name**.
///
/// Nearby restaurants are loaded via geohash cells (bounded). Foods are
/// then queried with `restaurantId` `whereIn` chunks — never the whole
/// category collection.
class GetCustomerFoodsByCategoryUseCase {
  const GetCustomerFoodsByCategoryUseCase({
    required this.foodRepository,
    required this.restaurantRepository,
  });

  final FoodRepository foodRepository;
  final RestaurantRepository restaurantRepository;

  static const int pageSize = 30;

  Future<List<CategoryFoodItem>> call(
    String categoryName, {
    required UserLocation? destination,
    int limit = pageSize,
  }) async {
    return (await page(
      categoryName,
      destination: destination,
      limit: limit,
    )).items;
  }

  Future<CategoryFoodsPage> page(
    String categoryName, {
    required UserLocation? destination,
    int limit = pageSize,
    String? startAfterName,
  }) async {
    final name = categoryName.trim();
    if (name.isEmpty) {
      return const CategoryFoodsPage(items: [], hasMore: false);
    }

    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(destination);
    if (cells.isEmpty) {
      return const CategoryFoodsPage(items: [], hasMore: false);
    }

    final restaurants = RestaurantDeliveryRange.within(
      restaurants: await restaurantRepository.getDiscoverableRestaurants(
        geohash4Cells: cells,
      ),
      destination: destination,
    );
    if (restaurants.isEmpty) {
      return const CategoryFoodsPage(items: [], hasMore: false);
    }
    final restaurantById = {
      for (final restaurant in restaurants) restaurant.id: restaurant,
    };

    final foods = await foodRepository.getCustomerFoodsByCategoryName(
      name,
      restaurantIds: restaurantById.keys.toList(),
      limit: limit + 1,
      startAfterName: startAfterName,
    );
    final items = <CategoryFoodItem>[];
    for (final food in foods) {
      final restaurant = restaurantById[food.restaurantId];
      if (restaurant == null) {
        continue;
      }
      items.add(CategoryFoodItem(food: food, restaurant: restaurant));
    }
    final hasMore = items.length > limit;
    final pageItems = hasMore ? items.take(limit).toList() : items;
    return CategoryFoodsPage(
      items: pageItems,
      cursor: pageItems.isEmpty ? null : pageItems.last.food.name,
      hasMore: hasMore,
    );
  }
}
