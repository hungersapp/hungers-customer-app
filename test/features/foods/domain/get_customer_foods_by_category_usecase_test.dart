import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/domain/usecases/get_customer_foods_by_category_usecase.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';

/// The customer's selected delivery destination in these tests: Madurai.
final _madurai = UserLocation(
  latitude: 9.9195,
  longitude: 78.1193,
  city: 'Madurai',
  state: 'Tamil Nadu',
  pincode: '625001',
  updatedAt: DateTime(2026, 1, 1),
);

FoodEntity _food({
  required String id,
  required String restaurantId,
  required String category,
  bool isAvailable = true,
  FoodReviewStatus status = FoodReviewStatus.approved,
}) {
  return FoodEntity(
    id: id,
    restaurantId: restaurantId,
    name: id,
    description: '',
    price: 100,
    imageUrl: '',
    category: category,
    isVeg: true,
    isAvailable: isAvailable,
    isRecommended: false,
    rating: 4.5,
    status: status,
  );
}

RestaurantEntity _restaurant({
  required String id,
  required String name,
  bool isCustomerVisible = true,
  bool isActive = true,
  bool isOpen = true,
  String onboardingStatus = 'approved',
  bool isVerified = true,
  int approvedFoodCount = 2,
  // Madurai by default; discovery is scoped to the delivery destination, so
  // the fixture needs real coordinates (the (0,0) placeholder is unusable).
  double latitude = 9.9252,
  double longitude = 78.1198,
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
    isOpen: isOpen,
    isFeatured: false,
    openingTime: '',
    closingTime: '',
    cuisines: const [],
    isCustomerVisible: isCustomerVisible,
    isActive: isActive,
    approvedFoodCount: approvedFoodCount,
    onboardingStatus: onboardingStatus,
    isVerified: isVerified,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeFoodRepository implements FoodRepository {
  _FakeFoodRepository(this.byCategoryName);

  final Map<String, List<FoodEntity>> byCategoryName;
  String? lastCategoryName;
  int lastLimit = 30;
  List<String> lastRestaurantIds = const [];
  String? lastStartAfterName;

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async {
    lastCategoryName = categoryName;
    lastLimit = limit;
    lastRestaurantIds = restaurantIds;
    lastStartAfterName = startAfterName;
    final all = List<FoodEntity>.from(byCategoryName[categoryName] ?? const []);
    if (restaurantIds.isEmpty) {
      return const [];
    }
    final allowed = restaurantIds.toSet();
    var filtered =
        all.where((food) => allowed.contains(food.restaurantId)).toList()
          ..sort((a, b) {
            final byName = a.name.compareTo(b.name);
            if (byName != 0) {
              return byName;
            }
            return a.id.compareTo(b.id);
          });
    final cursor = startAfterName?.trim() ?? '';
    if (cursor.isNotEmpty) {
      filtered = filtered
          .where((food) => food.name.compareTo(cursor) > 0)
          .toList();
    }
    return filtered.take(limit).toList();
  }

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async =>
      [];

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async => [];

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async => [];

  @override
  Future<FoodEntity> getFoodById(String foodId) {
    throw UnimplementedError();
  }

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async => null;
}

class _FakeRestaurantRepository implements RestaurantRepository {
  _FakeRestaurantRepository(this.restaurants);

  final List<RestaurantEntity> restaurants;

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => restaurants;

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async => restaurants;

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async => [];

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async => [];

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async => [];

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async =>
      null;

  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async => [];
}

void main() {
  test(
    'queries foods by category NAME and keeps eligible restaurants only',
    () async {
      final foods = _FakeFoodRepository({
        'Pizza': [
          _food(id: 'ok', restaurantId: 'r1', category: 'Pizza'),
          _food(id: 'hidden-rest', restaurantId: 'r-hidden', category: 'Pizza'),
        ],
      });
      final restaurants = _FakeRestaurantRepository([
        _restaurant(id: 'r1', name: 'Open Pizza Place'),
      ]);

      final usecase = GetCustomerFoodsByCategoryUseCase(
        foodRepository: foods,
        restaurantRepository: restaurants,
      );

      final items = await usecase('Pizza', destination: _madurai);

      expect(foods.lastCategoryName, 'Pizza');
      expect(items, hasLength(1));
      expect(items.single.food.id, 'ok');
      expect(items.single.restaurantName, 'Open Pizza Place');
    },
  );

  test('returns empty when category name is blank', () async {
    final foods = _FakeFoodRepository({
      'Pizza': [_food(id: 'ok', restaurantId: 'r1', category: 'Pizza')],
    });
    final restaurants = _FakeRestaurantRepository([
      _restaurant(id: 'r1', name: 'Open Pizza Place'),
    ]);

    final usecase = GetCustomerFoodsByCategoryUseCase(
      foodRepository: foods,
      restaurantRepository: restaurants,
    );

    expect(await usecase('   ', destination: _madurai), isEmpty);
    expect(foods.lastCategoryName, isNull);
  });

  test('excludes foods from non-listable restaurants', () async {
    // getAllRestaurants already returns only listable restaurants in production;
    // simulate that by omitting ineligible restaurants from the list.
    final foods = _FakeFoodRepository({
      'Burger': [
        _food(id: 'closed', restaurantId: 'r-closed', category: 'Burger'),
      ],
    });
    final restaurants = _FakeRestaurantRepository(const []);

    final usecase = GetCustomerFoodsByCategoryUseCase(
      foodRepository: foods,
      restaurantRepository: restaurants,
    );

    expect(await usecase('Burger', destination: _madurai), isEmpty);
  });

  group('scoped to the delivery destination', () {
    // Madurai destination; Chennai is ~430 km away.
    final foods = _FakeFoodRepository({
      'Pizza': [
        _food(
          id: 'madurai-pizza',
          restaurantId: 'r-madurai',
          category: 'Pizza',
        ),
        _food(
          id: 'chennai-pizza',
          restaurantId: 'r-chennai',
          category: 'Pizza',
        ),
      ],
    });
    final restaurants = _FakeRestaurantRepository([
      _restaurant(id: 'r-madurai', name: 'Madurai Pizza'),
      _restaurant(
        id: 'r-chennai',
        name: 'Chennai Pizza',
        latitude: 13.0827,
        longitude: 80.2707,
      ),
    ]);

    test(
      'a category only lists dishes from restaurants that can deliver there',
      () async {
        final usecase = GetCustomerFoodsByCategoryUseCase(
          foodRepository: foods,
          restaurantRepository: restaurants,
        );

        final items = await usecase('Pizza', destination: _madurai);

        expect(items.map((i) => i.food.id), ['madurai-pizza']);
      },
    );

    test(
      'with no destination nothing is discoverable (no nationwide fallback)',
      () async {
        final usecase = GetCustomerFoodsByCategoryUseCase(
          foodRepository: foods,
          restaurantRepository: restaurants,
        );

        expect(await usecase('Pizza', destination: null), isEmpty);
      },
    );

    test(
      'category foods are bounded and scoped to nearby restaurant ids',
      () async {
        final foods = _FakeFoodRepository({
          'Pizza': [
            for (var i = 0; i < 40; i++)
              _food(id: 'pizza-$i', restaurantId: 'near', category: 'Pizza'),
          ],
        });
        final restaurants = _FakeRestaurantRepository([
          _restaurant(id: 'near', name: 'Near'),
        ]);
        final items = await GetCustomerFoodsByCategoryUseCase(
          foodRepository: foods,
          restaurantRepository: restaurants,
        )('Pizza', destination: _madurai);

        expect(items, hasLength(GetCustomerFoodsByCategoryUseCase.pageSize));
        expect(foods.lastLimit, GetCustomerFoodsByCategoryUseCase.pageSize + 1);
        expect(foods.lastRestaurantIds, ['near']);
      },
    );

    test('0 foods is an empty last page', () async {
      final page = await GetCustomerFoodsByCategoryUseCase(
        foodRepository: _FakeFoodRepository({}),
        restaurantRepository: _FakeRestaurantRepository([
          _restaurant(id: 'near', name: 'Near'),
        ]),
      ).page('Pizza', destination: _madurai);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('1 food is a last page of one', () async {
      final page = await GetCustomerFoodsByCategoryUseCase(
        foodRepository: _FakeFoodRepository({
          'Pizza': [
            _food(id: 'p-001', restaurantId: 'near', category: 'Pizza'),
          ],
        }),
        restaurantRepository: _FakeRestaurantRepository([
          _restaurant(id: 'near', name: 'Near'),
        ]),
      ).page('Pizza', destination: _madurai);
      expect(page.items, hasLength(1));
      expect(page.hasMore, isFalse);
    });

    test('31 foods paginate without duplicates', () async {
      final foods = _FakeFoodRepository({
        'Pizza': [
          for (var i = 0; i < 31; i++)
            _food(
              id: 'p-${i.toString().padLeft(3, '0')}',
              restaurantId: 'near',
              category: 'Pizza',
            ),
        ],
      });
      final useCase = GetCustomerFoodsByCategoryUseCase(
        foodRepository: foods,
        restaurantRepository: _FakeRestaurantRepository([
          _restaurant(id: 'near', name: 'Near'),
        ]),
      );
      final first = await useCase.page('Pizza', destination: _madurai);
      final second = await useCase.page(
        'Pizza',
        destination: _madurai,
        startAfterName: first.cursor,
      );

      expect(first.items, hasLength(30));
      expect(first.hasMore, isTrue);
      expect(second.items, hasLength(1));
      expect(second.hasMore, isFalse);
      expect(
        {...first.items, ...second.items}.map((item) => item.food.id).toSet(),
        hasLength(31),
      );
    });

    test('60+ foods fill two full pages then a remainder', () async {
      final foods = _FakeFoodRepository({
        'Pizza': [
          for (var i = 0; i < 61; i++)
            _food(
              id: 'p-${i.toString().padLeft(3, '0')}',
              restaurantId: 'near',
              category: 'Pizza',
            ),
        ],
      });
      final useCase = GetCustomerFoodsByCategoryUseCase(
        foodRepository: foods,
        restaurantRepository: _FakeRestaurantRepository([
          _restaurant(id: 'near', name: 'Near'),
        ]),
      );
      final first = await useCase.page('Pizza', destination: _madurai);
      final second = await useCase.page(
        'Pizza',
        destination: _madurai,
        startAfterName: first.cursor,
      );
      final third = await useCase.page(
        'Pizza',
        destination: _madurai,
        startAfterName: second.cursor,
      );

      expect(first.items, hasLength(30));
      expect(first.hasMore, isTrue);
      expect(second.items, hasLength(30));
      expect(second.hasMore, isTrue);
      expect(third.items, hasLength(1));
      expect(third.hasMore, isFalse);
    });
  });
}
