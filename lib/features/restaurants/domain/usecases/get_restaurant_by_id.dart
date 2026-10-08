import '../entities/restaurant_entity.dart';
import '../repositories/restaurant_repository.dart';

class GetRestaurantById {
  final RestaurantRepository repository;

  const GetRestaurantById({required this.repository});

  Future<RestaurantEntity?> call(String restaurantId) async {
    return await repository.getRestaurantById(restaurantId);
  }
}
