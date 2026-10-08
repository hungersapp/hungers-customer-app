import '../entities/food_entity.dart';
import '../repositories/food_repository.dart';

class GetFoodByIdUseCase {
  final FoodRepository repository;

  const GetFoodByIdUseCase(this.repository);

  Future<FoodEntity> call(String foodId) {
    return repository.getFoodById(foodId);
  }
}
