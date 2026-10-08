import '../entities/food_entity.dart';

abstract class FoodRepository {
  /// Get all available foods for a restaurant
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId);

  /// Get recommended foods for a restaurant
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId);

  /// Get foods by category
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  });

  /// Approved + available foods matching [categoryName] on `foods.category`
  /// sold by [restaurantIds] only. Never a nationwide category scan.
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  });

  /// Get a single food by its ID (customer-visible only).
  Future<FoodEntity> getFoodById(String foodId);

  /// Raw food document for checkout validation (includes unavailable foods).
  Future<FoodEntity?> getFoodDocumentById(String foodId);
}
