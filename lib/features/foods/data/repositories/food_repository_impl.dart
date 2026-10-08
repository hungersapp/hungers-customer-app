import '../../domain/entities/food_entity.dart';
import '../../domain/repositories/food_repository.dart';
import '../datasources/food_firestore_datasource.dart';

class FoodRepositoryImpl implements FoodRepository {
  final FoodFirestoreDatasource datasource;

  const FoodRepositoryImpl(this.datasource);

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async {
    return await datasource.getFoodsByRestaurant(restaurantId);
  }

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async {
    return await datasource.getRecommendedFoods(restaurantId);
  }

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async {
    return await datasource.getFoodsByCategory(
      restaurantId: restaurantId,
      category: category,
    );
  }

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) {
    return datasource.getCustomerFoodsByCategoryName(
      categoryName,
      restaurantIds: restaurantIds,
      limit: limit,
      startAfterName: startAfterName,
    );
  }

  @override
  Future<FoodEntity> getFoodById(String foodId) async {
    return await datasource.getFoodById(foodId);
  }

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) {
    return datasource.getFoodDocumentById(foodId);
  }
}
