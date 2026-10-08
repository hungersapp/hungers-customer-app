import '../entities/restaurant_entity.dart';

abstract class RestaurantRepository {
  /// Visible+open restaurants in [geohash4Cells] (bounded per cell).
  ///
  /// This is the customer discovery read. It must never download the
  /// nationwide catalog.
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  });

  /// Get all restaurants
  Future<List<RestaurantEntity>> getAllRestaurants();

  /// Get featured restaurants
  Future<List<RestaurantEntity>> getFeaturedRestaurants();

  /// Get popular restaurants
  Future<List<RestaurantEntity>> getPopularRestaurants();

  /// Get nearby restaurants
  Future<List<RestaurantEntity>> getNearbyRestaurants();

  /// Get restaurant by ID
  Future<RestaurantEntity?> getRestaurantById(String restaurantId);

  /// Search restaurants
  Future<List<RestaurantEntity>> searchRestaurants(String keyword);
}
