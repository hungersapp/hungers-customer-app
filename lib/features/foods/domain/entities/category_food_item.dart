import '../../../restaurants/domain/entities/restaurant_entity.dart';
import 'food_entity.dart';

/// Food row for Home category browse, with eligible restaurant context.
class CategoryFoodItem {
  const CategoryFoodItem({required this.food, required this.restaurant});

  final FoodEntity food;
  final RestaurantEntity restaurant;

  String get restaurantName => restaurant.name;
}
