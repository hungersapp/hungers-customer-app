import '../entities/food_entity.dart';
import '../repositories/food_repository.dart';

class GetFoodsByRestaurantUseCase {
  final FoodRepository repository;

  const GetFoodsByRestaurantUseCase(this.repository);

  Future<List<FoodEntity>> call(String restaurantId) {
    return repository.getFoodsByRestaurant(restaurantId);
  }
}
