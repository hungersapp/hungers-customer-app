import '../../domain/entities/search_result_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_firestore_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchFirestoreDatasource datasource;

  SearchRepositoryImpl(this.datasource);

  @override
  Future<List<SearchResultEntity>> searchRestaurants(
    String query, {
    List<String> geohash4Cells = const [],
    int limit = SearchFirestoreDatasource.defaultLimit,
  }) {
    return datasource.searchRestaurants(
      query,
      geohash4Cells: geohash4Cells,
      limit: limit,
    );
  }

  @override
  Future<List<SearchResultEntity>> searchFoods(
    String query, {
    List<String> restaurantIds = const [],
    int limit = SearchFirestoreDatasource.defaultLimit,
  }) {
    return datasource.searchFoods(
      query,
      restaurantIds: restaurantIds,
      limit: limit,
    );
  }

  @override
  Future<List<SearchResultEntity>> searchAll(
    String query, {
    List<String> geohash4Cells = const [],
    List<String> restaurantIds = const [],
    int limit = SearchFirestoreDatasource.defaultLimit,
  }) {
    return datasource.searchAll(
      query,
      geohash4Cells: geohash4Cells,
      restaurantIds: restaurantIds,
      limit: limit,
    );
  }
}
