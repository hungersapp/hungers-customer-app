import '../entities/food_entity.dart';
import '../repositories/food_repository.dart';

class GetFoodsByCategoryUseCase {
  final FoodRepository repository;

  const GetFoodsByCategoryUseCase(this.repository);

  Future<List<FoodEntity>> call({
    required String restaurantId,
    required String category,
  }) {
    return repository.getFoodsByCategory(
      restaurantId: restaurantId,
      category: category,
    );
  }
}
