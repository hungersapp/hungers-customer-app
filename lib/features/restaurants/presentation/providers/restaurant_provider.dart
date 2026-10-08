import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/restaurant_firestore_datasource.dart';
import '../../data/repositories/restaurant_repository_impl.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../../domain/usecases/get_all_restaurants.dart';
import '../../domain/usecases/get_featured_restaurants.dart';
import '../../domain/usecases/get_nearby_restaurants.dart';
import '../../domain/usecases/get_popular_restaurants.dart';
import '../../domain/usecases/get_restaurant_by_id.dart';
import '../../domain/usecases/search_restaurants.dart';

/// Datasource
final restaurantDatasourceProvider = Provider<RestaurantFirestoreDatasource>((
  ref,
) {
  return RestaurantFirestoreDatasource();
});

/// Repository
final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepositoryImpl(
    datasource: ref.watch(restaurantDatasourceProvider),
  );
});

/// UseCases

final getAllRestaurantsProvider = Provider<GetAllRestaurants>((ref) {
  return GetAllRestaurants(repository: ref.watch(restaurantRepositoryProvider));
});

final getFeaturedRestaurantsProvider = Provider<GetFeaturedRestaurants>((ref) {
  return GetFeaturedRestaurants(
    repository: ref.watch(restaurantRepositoryProvider),
  );
});

final getPopularRestaurantsProvider = Provider<GetPopularRestaurants>((ref) {
  return GetPopularRestaurants(
    repository: ref.watch(restaurantRepositoryProvider),
  );
});

final getNearbyRestaurantsProvider = Provider<GetNearbyRestaurants>((ref) {
  return GetNearbyRestaurants(
    repository: ref.watch(restaurantRepositoryProvider),
  );
});

final getRestaurantByIdProvider = Provider<GetRestaurantById>((ref) {
  return GetRestaurantById(repository: ref.watch(restaurantRepositoryProvider));
});

final searchRestaurantsProvider = Provider<SearchRestaurants>((ref) {
  return SearchRestaurants(repository: ref.watch(restaurantRepositoryProvider));
});
