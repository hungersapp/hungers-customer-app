import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/app/app_pages.dart';
import 'package:customer_app/app/app_routes.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/dashboard/domain/entities/category.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/foods/presentation/screens/category_foods_screen.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';

class _EmptyFoodRepository implements FoodRepository {
  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async => const [];

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async =>
      const [];

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async =>
      const [];

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async => const [];

  @override
  Future<FoodEntity> getFoodById(String foodId) {
    throw UnimplementedError();
  }

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async => null;
}

class _EmptyRestaurantRepository implements RestaurantRepository {
  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => const [];

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async => const [];

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async => const [];

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async => const [];

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async => const [];

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async =>
      null;

  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async =>
      const [];
}

void main() {
  const pizza = Category(
    id: 'pizza',
    name: 'Pizza',
    imageUrl: '',
    isActive: true,
    displayOrder: 1,
  );

  final overrides = <Override>[
    currentUserIdProvider.overrideWithValue(null),
    foodRepositoryProvider.overrideWithValue(_EmptyFoodRepository()),
    restaurantRepositoryProvider.overrideWithValue(
      _EmptyRestaurantRepository(),
    ),
  ];

  testWidgets('category route opens CategoryFoodsScreen with valid args', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          onGenerateRoute: (settings) => AppPages.onGenerateRoute(settings),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.categoryFoods, arguments: pizza);
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryFoodsScreen), findsOneWidget);
    expect(find.text('Pizza'), findsWidgets);
  });

  test('onGenerateRoute accepts Category and rejects invalid args', () {
    final ok = AppPages.onGenerateRoute(
      const RouteSettings(name: AppRoutes.categoryFoods, arguments: pizza),
    );
    final bad = AppPages.onGenerateRoute(
      const RouteSettings(name: AppRoutes.categoryFoods, arguments: 'bad'),
    );

    expect(ok, isA<MaterialPageRoute<dynamic>>());
    expect((ok as MaterialPageRoute<dynamic>).settings.arguments, pizza);

    expect(bad, isA<MaterialPageRoute<dynamic>>());
    expect(
      (bad as MaterialPageRoute<dynamic>).settings.name,
      AppRoutes.dashboard,
    );
  });
}
