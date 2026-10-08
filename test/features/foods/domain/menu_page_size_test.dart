import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/foods/data/datasources/food_firestore_datasource.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/domain/usecases/get_foods_by_restaurant_usecase.dart';

class _PagedMenuRepository implements FoodRepository {
  _PagedMenuRepository(this.foods);

  final List<FoodEntity> foods;

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async {
    return foods.take(FoodFirestoreDatasource.menuPageSize).toList();
  }

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async =>
      const [];

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async => const [];

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async => const [];

  @override
  Future<FoodEntity> getFoodById(String foodId) {
    throw UnimplementedError();
  }

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async => null;
}

FoodEntity _food(String id) {
  return FoodEntity(
    id: id,
    restaurantId: 'rest-1',
    name: id,
    description: '',
    price: 100,
    imageUrl: '',
    category: 'Meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: false,
    rating: 4.5,
    status: FoodReviewStatus.approved,
  );
}

void main() {
  test('restaurant menu first page is bounded at 20', () async {
    final foods = [for (var i = 0; i < 45; i++) _food('f-$i')];
    final page = await GetFoodsByRestaurantUseCase(
      _PagedMenuRepository(foods),
    ).call('rest-1');

    expect(page, hasLength(FoodFirestoreDatasource.menuPageSize));
    expect(page.first.id, 'f-0');
    expect(page.last.id, 'f-19');
  });
}
