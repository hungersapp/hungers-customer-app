import '../../domain/entities/food_entity.dart';

/// Route arguments for [FoodDetailsScreen]. Reuses existing [FoodEntity].
class FoodDetailsArgs {
  const FoodDetailsArgs({required this.food, required this.restaurantName});

  final FoodEntity food;
  final String restaurantName;
}
