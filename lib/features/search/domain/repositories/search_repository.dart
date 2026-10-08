import '../entities/search_result_entity.dart';

abstract class SearchRepository {
  /// Search restaurants in nearby geohash cells only.
  Future<List<SearchResultEntity>> searchRestaurants(
    String query, {
    List<String> geohash4Cells = const [],
    int limit = 20,
  });

  /// Search foods sold by nearby restaurants only.
  Future<List<SearchResultEntity>> searchFoods(
    String query, {
    List<String> restaurantIds = const [],
    int limit = 20,
  });

  /// Universal search (Restaurants + Foods)
  Future<List<SearchResultEntity>> searchAll(
    String query, {
    List<String> geohash4Cells = const [],
    List<String> restaurantIds = const [],
    int limit = 20,
  });
}
