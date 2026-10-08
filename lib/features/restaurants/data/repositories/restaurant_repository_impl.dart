import '../../domain/entities/restaurant_entity.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../datasource/restaurant_firestore_datasource.dart';

class RestaurantRepositoryImpl implements RestaurantRepository {
  final RestaurantFirestoreDatasource datasource;

  RestaurantRepositoryImpl({required this.datasource});

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) {
    return datasource.getDiscoverableRestaurants(
      geohash4Cells: geohash4Cells,
      featuredOnly: featuredOnly,
    );
  }

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async {
    return await datasource.getAllRestaurants();
  }

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async {
    return await datasource.getFeaturedRestaurants();
  }

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async {
    return await datasource.getPopularRestaurants();
  }

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async {
    return await datasource.getNearbyRestaurants();
  }

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async {
    return await datasource.getRestaurantById(restaurantId);
  }

  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async {
    return await datasource.searchRestaurants(keyword);
  }
}
