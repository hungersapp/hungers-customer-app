import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_provider.dart';
import '../../data/datasources/food_firestore_datasource.dart';
import '../../data/repositories/food_repository_impl.dart';
import '../../domain/entities/category_food_item.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/repositories/food_repository.dart';
import '../../domain/usecases/get_customer_foods_by_category_usecase.dart';
import '../../domain/usecases/get_food_by_id_usecase.dart';
import '../../domain/usecases/get_foods_by_category_usecase.dart';
import '../../domain/usecases/get_foods_by_restaurant_usecase.dart';
import '../../domain/usecases/get_recommended_foods_usecase.dart';

/// Firebase Firestore
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Datasource
final foodDatasourceProvider = Provider<FoodFirestoreDatasource>((ref) {
  return FoodFirestoreDatasource(ref.read(firestoreProvider));
});

/// Repository
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepositoryImpl(ref.read(foodDatasourceProvider));
});

/// UseCases
final getFoodsByRestaurantUseCaseProvider =
    Provider<GetFoodsByRestaurantUseCase>((ref) {
      return GetFoodsByRestaurantUseCase(ref.read(foodRepositoryProvider));
    });

final getRecommendedFoodsUseCaseProvider = Provider<GetRecommendedFoodsUseCase>(
  (ref) {
    return GetRecommendedFoodsUseCase(
      ref.read(foodRepositoryProvider),
      ref.read(restaurantRepositoryProvider),
    );
  },
);

final getFoodsByCategoryUseCaseProvider = Provider<GetFoodsByCategoryUseCase>((
  ref,
) {
  return GetFoodsByCategoryUseCase(ref.read(foodRepositoryProvider));
});

final getCustomerFoodsByCategoryUseCaseProvider =
    Provider<GetCustomerFoodsByCategoryUseCase>((ref) {
      return GetCustomerFoodsByCategoryUseCase(
        foodRepository: ref.read(foodRepositoryProvider),
        restaurantRepository: ref.read(restaurantRepositoryProvider),
      );
    });

final getFoodByIdUseCaseProvider = Provider<GetFoodByIdUseCase>((ref) {
  return GetFoodByIdUseCase(ref.read(foodRepositoryProvider));
});

/// Restaurant Foods
final restaurantFoodsProvider =
    FutureProvider.autoDispose.family<List<FoodEntity>, String>(
  (ref, restaurantId) {
    return ref.read(getFoodsByRestaurantUseCaseProvider).call(restaurantId);
  },
);

/// Recommended Foods
///
/// Scoped to the selected delivery destination; re-runs when it changes.
final recommendedFoodsProvider =
    FutureProvider.family<List<FoodEntity>, String>((ref, restaurantId) async {
      final destination = await ref.watch(
        serviceableDeliveryDestinationProvider.future,
      );
      return ref
          .read(getRecommendedFoodsUseCaseProvider)
          .call(restaurantId, destination: destination);
    });

/// Category Parameter
class FoodCategoryParams {
  final String restaurantId;
  final String category;

  const FoodCategoryParams({
    required this.restaurantId,
    required this.category,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodCategoryParams &&
          restaurantId == other.restaurantId &&
          category == other.category;

  @override
  int get hashCode => Object.hash(restaurantId, category);
}

/// Category Foods (restaurant-scoped)
final categoryFoodsProvider =
    FutureProvider.family<List<FoodEntity>, FoodCategoryParams>((ref, params) {
      return ref
          .read(getFoodsByCategoryUseCaseProvider)
          .call(restaurantId: params.restaurantId, category: params.category);
    });

/// Home category browse (global; restaurant-eligibility applied in usecase).
/// Key is category **name** stored on `foods.category`.
final customerCategoryFoodsProvider =
    FutureProvider.family<List<CategoryFoodItem>, String>((
      ref,
      categoryName,
    ) async {
      // Scoped to the customer's selected delivery destination (not raw GPS);
      // watched so a changed destination reloads the category.
      final destination = await ref.watch(
        serviceableDeliveryDestinationProvider.future,
      );
      // Not served / nothing chosen: nothing to list, nothing to read.
      if (destination == null) {
        return const [];
      }
      return ref
          .read(getCustomerFoodsByCategoryUseCaseProvider)
          .call(categoryName, destination: destination);
    });

/// Single Food
final foodByIdProvider = FutureProvider.family<FoodEntity, String>((
  ref,
  foodId,
) {
  return ref.read(getFoodByIdUseCaseProvider).call(foodId);
});
