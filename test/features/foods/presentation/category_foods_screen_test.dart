import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/dashboard/domain/entities/category.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/foods/presentation/screens/category_foods_screen.dart';
import 'package:customer_app/features/foods/presentation/screens/food_details_screen.dart';
import 'package:customer_app/features/foods/presentation/widgets/category_food_discovery_card.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceable_destination_provider.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';

import '../../../helpers/destination_fakes.dart';

FoodEntity _food({
  required String id,
  required String name,
  String category = 'Pizza',
  String restaurantId = 'r1',
  String imageUrl = '',
  double price = 199,
}) {
  return FoodEntity(
    id: id,
    restaurantId: restaurantId,
    name: name,
    description: '',
    price: price,
    imageUrl: imageUrl,
    category: category,
    isVeg: true,
    isAvailable: true,
    isRecommended: false,
    rating: 4.2,
    status: FoodReviewStatus.approved,
  );
}

RestaurantEntity _restaurant({
  required String id,
  required String name,
  double latitude = 11.0,
  double longitude = 78.0,
  List<String> cuisines = const ['South Indian'],
}) {
  final now = DateTime(2026, 1, 1);
  return RestaurantEntity(
    id: id,
    name: name,
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: '',
    latitude: latitude,
    longitude: longitude,
    rating: 4.5,
    totalRatings: 1,
    deliveryTime: 30,
    deliveryFee: 0,
    minimumOrderAmount: 0,
    isPureVeg: false,
    isOpen: true,
    isFeatured: false,
    openingTime: '',
    closingTime: '',
    cuisines: cuisines,
    isCustomerVisible: true,
    isActive: true,
    approvedFoodCount: 2,
    onboardingStatus: 'approved',
    isVerified: true,
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryFoodRepository implements FoodRepository {
  _MemoryFoodRepository(this.foods);

  final List<FoodEntity> foods;

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async {
    var list = foods.where((food) => food.category == categoryName).toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        if (byName != 0) {
          return byName;
        }
        return a.id.compareTo(b.id);
      });
    if (restaurantIds.isNotEmpty) {
      final allowed = restaurantIds.toSet();
      list = list.where((food) => allowed.contains(food.restaurantId)).toList();
    }
    final cursor = startAfterName?.trim() ?? '';
    if (cursor.isNotEmpty) {
      list = list.where((food) => food.name.compareTo(cursor) > 0).toList();
    }
    return list.take(limit).toList(growable: false);
  }

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

class _MemoryRestaurantRepository implements RestaurantRepository {
  _MemoryRestaurantRepository(this.restaurants);

  final List<RestaurantEntity> restaurants;

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => restaurants;

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async => restaurants;

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
  const category = Category(
    id: 'pizza',
    name: 'Pizza',
    imageUrl: '',
    isActive: true,
    displayOrder: 1,
  );

  testWidgets('empty category result shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          foodRepositoryProvider.overrideWithValue(_MemoryFoodRepository([])),
          restaurantRepositoryProvider.overrideWithValue(
            _MemoryRestaurantRepository([
              _restaurant(id: 'r1', name: 'Pizza Hut'),
            ]),
          ),
        ],
        child: const MaterialApp(home: CategoryFoodsScreen(category: category)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No foods available'), findsOneWidget);
  });

  testWidgets('food tap opens existing FoodDetailsScreen', (tester) async {
    final food = _food(id: 'margherita', name: 'Margherita');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          // Discovery is scoped to the delivery destination: the restaurant
          // (11.0, 78.0) must be within range of it to be listed.
          serviceableDeliveryDestinationProvider.overrideWith(
            (ref) async => UserLocation(
              latitude: 11.0,
              longitude: 78.0,
              city: 'Salem',
              state: 'TN',
              updatedAt: DateTime(2026, 1, 1),
              pincode: '636001',
            ),
          ),
          foodRepositoryProvider.overrideWithValue(
            _MemoryFoodRepository([food]),
          ),
          restaurantRepositoryProvider.overrideWithValue(
            _MemoryRestaurantRepository([
              _restaurant(id: 'r1', name: 'Pizza Hut'),
            ]),
          ),
        ],
        child: const MaterialApp(home: CategoryFoodsScreen(category: category)),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Margherita'));
    await tester.pumpAndSettle();

    expect(find.byType(FoodDetailsScreen), findsOneWidget);
    expect(find.text('Margherita'), findsWidgets);
  });

  testWidgets(
    'multiple restaurants render separate discovery cards with details',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user-1'),
            userLocationProvider.overrideWith((ref, userId) async {
              return UserLocation(
                latitude: 11.0,
                longitude: 78.0,
                city: 'Salem',
                state: 'TN',
                updatedAt: DateTime(2026, 1, 1),
                pincode: '636001',
              );
            }),
            // Tukkito serves the destination's pincode, so discovery follows.
            serviceabilityRepositoryProvider.overrideWithValue(
              FakeServiceabilityRepository(),
            ),
            foodRepositoryProvider.overrideWithValue(
              _MemoryFoodRepository([
                _food(
                  id: 'food-a',
                  name: 'Pizza A',
                  restaurantId: 'r1',
                  price: 150,
                ),
                _food(
                  id: 'food-b',
                  name: 'Pizza B',
                  restaurantId: 'r2',
                  price: 180,
                ),
              ]),
            ),
            restaurantRepositoryProvider.overrideWithValue(
              _MemoryRestaurantRepository([
                _restaurant(
                  id: 'r1',
                  name: 'Restaurant A',
                  latitude: 11.01,
                  longitude: 78.01,
                  cuisines: const ['Italian'],
                ),
                _restaurant(
                  id: 'r2',
                  name: 'Restaurant B',
                  latitude: 11.02,
                  longitude: 78.02,
                  cuisines: const ['Fast Food'],
                ),
              ]),
            ),
          ],
          child: const MaterialApp(
            home: CategoryFoodsScreen(category: category),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CategoryFoodDiscoveryCard), findsNWidgets(2));
      expect(find.text('Restaurant A'), findsOneWidget);
      expect(find.text('Restaurant B'), findsOneWidget);
      expect(find.text('Pizza A'), findsOneWidget);
      expect(find.text('Pizza B'), findsOneWidget);
      expect(find.text('Italian'), findsOneWidget);
      expect(find.text('Fast Food'), findsOneWidget);
      expect(find.text('₹150'), findsOneWidget);
      expect(find.text('₹180'), findsOneWidget);
      expect(find.textContaining('km'), findsNWidgets(2));
      expect(find.text('ADD'), findsNWidgets(2));

      final a = tester.getRect(
        find.byKey(const ValueKey('category-food-card-food-a')),
      );
      final b = tester.getRect(
        find.byKey(const ValueKey('category-food-card-food-b')),
      );
      expect(b.top, greaterThan(a.bottom));
    },
  );

  testWidgets('30 foods show a full first page and Load More', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _nearbyCategoryOverrides(
          foods: [
            for (var i = 0; i < 30; i++)
              _food(
                id: 'p-${i.toString().padLeft(2, '0')}',
                name: 'Pizza ${i.toString().padLeft(2, '0')}',
              ),
          ],
        ),
        child: const MaterialApp(home: CategoryFoodsScreen(category: category)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pizza 00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Load More'), 400);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();

    expect(find.text('Load More'), findsNothing);
    await tester.scrollUntilVisible(find.text('Pizza 29'), 400);
    expect(find.text('Pizza 29'), findsOneWidget);
  });

  testWidgets('31 foods paginate without duplicates', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _nearbyCategoryOverrides(
          foods: [
            for (var i = 0; i < 31; i++)
              _food(
                id: 'p-${i.toString().padLeft(2, '0')}',
                name: 'Pizza ${i.toString().padLeft(2, '0')}',
              ),
          ],
        ),
        child: const MaterialApp(home: CategoryFoodsScreen(category: category)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pizza 00'), findsOneWidget);
    expect(find.text('Pizza 30'), findsNothing);
    await tester.scrollUntilVisible(find.text('Load More'), 400);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Pizza 30'), 400);
    expect(find.text('Pizza 30'), findsOneWidget);
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('60+ foods load two extra pages then end', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _nearbyCategoryOverrides(
          foods: [
            for (var i = 0; i < 61; i++)
              _food(
                id: 'p-${i.toString().padLeft(2, '0')}',
                name: 'Pizza ${i.toString().padLeft(2, '0')}',
              ),
          ],
        ),
        child: const MaterialApp(home: CategoryFoodsScreen(category: category)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pizza 00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Load More'), 400);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pizza 59'), 400);
    expect(find.text('Pizza 59'), findsOneWidget);
    expect(find.text('Pizza 60'), findsNothing);
    await tester.scrollUntilVisible(find.text('Load More'), 400);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pizza 60'), 400);
    expect(find.text('Pizza 60'), findsOneWidget);
    expect(find.text('Load More'), findsNothing);
  });
}

List<Override> _nearbyCategoryOverrides({required List<FoodEntity> foods}) {
  return [
    currentUserIdProvider.overrideWithValue(null),
    serviceableDeliveryDestinationProvider.overrideWith(
      (ref) async => UserLocation(
        latitude: 11.0,
        longitude: 78.0,
        city: 'Salem',
        state: 'TN',
        updatedAt: DateTime(2026, 1, 1),
        pincode: '636001',
      ),
    ),
    foodRepositoryProvider.overrideWithValue(_MemoryFoodRepository(foods)),
    restaurantRepositoryProvider.overrideWithValue(
      _MemoryRestaurantRepository([_restaurant(id: 'r1', name: 'Pizza Hut')]),
    ),
  ];
}
