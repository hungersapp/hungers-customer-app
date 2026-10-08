import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceable_destination_provider.dart';
import 'package:customer_app/features/dashboard/domain/entities/category.dart';
import 'package:customer_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:customer_app/features/dashboard/domain/usecases/get_categories_usecase.dart';
import 'package:customer_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/domain/usecases/get_food_by_id_usecase.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/foods/presentation/screens/category_foods_screen.dart';
import 'package:customer_app/features/foods/presentation/screens/food_details_screen.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';
import 'package:customer_app/features/restaurants/domain/usecases/get_restaurant_by_id.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/screens/restaurant_details_screen.dart';
import 'package:customer_app/features/search/domain/entities/search_result_entity.dart';
import 'package:customer_app/features/search/domain/repositories/search_repository.dart';
import 'package:customer_app/features/search/domain/usecases/search_usecase.dart';
import 'package:customer_app/features/search/presentation/pages/search_screen.dart';
import 'package:customer_app/features/search/presentation/providers/search_provider.dart';
import 'package:customer_app/features/search/presentation/widgets/no_result_widget.dart';
import 'package:customer_app/features/search/presentation/widgets/search_loading.dart';
import 'package:customer_app/features/search/presentation/widgets/search_result_tile.dart';

import '../../../helpers/discovery_fixtures.dart';

RestaurantEntity _restaurant() {
  return RestaurantEntity(
    id: 'a2b',
    name: 'A2B Restaurant',
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: 'Anna Nagar, Madurai',
    latitude: 9.9252,
    longitude: 78.1198,
    rating: 4.5,
    totalRatings: 10,
    deliveryTime: 25,
    deliveryFee: 30,
    minimumOrderAmount: 150,
    isPureVeg: true,
    isOpen: true,
    isFeatured: false,
    openingTime: '08:00',
    closingTime: '22:00',
    cuisines: const ['South Indian'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

FoodEntity _food() {
  return const FoodEntity(
    id: 'food-a',
    restaurantId: 'a2b',
    name: 'Mini Meals',
    description: 'South Indian thali',
    price: 160,
    imageUrl: '',
    category: 'meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: true,
    rating: 4.5,
    status: FoodReviewStatus.approved,
  );
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository(this.results);

  final List<SearchResultEntity> results;
  int searchAllCalls = 0;
  String? lastQuery;

  @override
  Future<List<SearchResultEntity>> searchAll(
    String query, {
    List<String> geohash4Cells = const [],
    List<String> restaurantIds = const [],
    int limit = 20,
  }) async {
    searchAllCalls += 1;
    lastQuery = query;
    return results;
  }

  @override
  Future<List<SearchResultEntity>> searchFoods(
    String query, {
    List<String> restaurantIds = const [],
    int limit = 20,
  }) async => results;

  @override
  Future<List<SearchResultEntity>> searchRestaurants(
    String query, {
    List<String> geohash4Cells = const [],
    int limit = 20,
  }) async => results;
}

class _PendingSearchRepository implements SearchRepository {
  _PendingSearchRepository(this.pending);

  final Completer<List<SearchResultEntity>> pending;

  @override
  Future<List<SearchResultEntity>> searchAll(
    String query, {
    List<String> geohash4Cells = const [],
    List<String> restaurantIds = const [],
    int limit = 20,
  }) => pending.future;

  @override
  Future<List<SearchResultEntity>> searchFoods(
    String query, {
    List<String> restaurantIds = const [],
    int limit = 20,
  }) => pending.future;

  @override
  Future<List<SearchResultEntity>> searchRestaurants(
    String query, {
    List<String> geohash4Cells = const [],
    int limit = 20,
  }) => pending.future;
}

class _FakeRestaurantRepository implements RestaurantRepository {
  _FakeRestaurantRepository({this.restaurant, List<RestaurantEntity>? listable})
    : listable =
          listable ??
          [testRestaurant(id: 'a2b'), testRestaurant(id: 'missing')];

  /// Every customer-listable restaurant (what search resolves coordinates from).
  final List<RestaurantEntity> listable;

  RestaurantEntity? restaurant;
  int getByIdCalls = 0;
  String? lastId;

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async {
    getByIdCalls += 1;
    lastId = restaurantId;
    return restaurant;
  }

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => listable;

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async => listable;

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async => const [];

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async => const [];

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async => const [];

  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async =>
      const [];
}

class _FakeFoodRepository implements FoodRepository {
  _FakeFoodRepository({this.food, this.throwOnGet = false});

  FoodEntity? food;
  bool throwOnGet;
  int getByIdCalls = 0;

  @override
  Future<FoodEntity> getFoodById(String foodId) async {
    getByIdCalls += 1;
    if (throwOnGet || food == null) {
      throw Exception('Food not found');
    }
    return food!;
  }

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async => food;

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async => const [];

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async => const [];

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async =>
      const [];

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async =>
      const [];
}

class _CategoryDashboardRepository implements DashboardRepository {
  const _CategoryDashboardRepository(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> getCategories() async => categories;
}

Future<void> _pumpSearch(
  WidgetTester tester, {
  required List<SearchResultEntity> results,
  RestaurantEntity? restaurant,
  FoodEntity? food,
  bool foodThrows = false,
  bool noDestination = false,
  _FakeSearchRepository? searchRepo,
  _FakeRestaurantRepository? restaurantRepo,
  _FakeFoodRepository? foodRepo,
  GetCategoriesUseCase? categoriesUseCase,
}) async {
  final search = searchRepo ?? _FakeSearchRepository(results);
  final restaurants =
      restaurantRepo ?? _FakeRestaurantRepository(restaurant: restaurant);
  final foods =
      foodRepo ?? _FakeFoodRepository(food: food, throwOnGet: foodThrows);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        // Search is scoped to the selected delivery destination (Madurai).
        serviceableDeliveryDestinationProvider.overrideWith(
          (ref) async => noDestination ? null : destinationIn(madurai),
        ),
        searchUseCaseProvider.overrideWithValue(
          SearchUseCase(search, restaurants),
        ),
        getCategoriesUseCaseProvider.overrideWithValue(
          categoriesUseCase ?? emptyCategoriesUseCase,
        ),
        customerCategoryFoodsProvider.overrideWith(
          (ref, categoryName) async => const [],
        ),
        getRestaurantByIdProvider.overrideWithValue(
          GetRestaurantById(repository: restaurants),
        ),
        getFoodByIdUseCaseProvider.overrideWithValue(GetFoodByIdUseCase(foods)),
        restaurantFoodsProvider.overrideWith(
          (ref, restaurantId) async => const <FoodEntity>[],
        ),
      ],
      child: const MaterialApp(home: SearchScreen()),
    ),
  );
  await tester.pump();
}

Future<void> _typeQueryAndWait(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('restaurant result tap opens restaurant details', (tester) async {
    final restaurant = _restaurant();
    final restaurants = _FakeRestaurantRepository(restaurant: restaurant);

    await _pumpSearch(
      tester,
      results: const [
        SearchResultEntity(
          id: 'a2b',
          title: 'A2B Restaurant',
          subtitle: 'South Indian',
          imageUrl: '',
          type: SearchResultType.restaurant,
        ),
      ],
      restaurantRepo: restaurants,
    );

    await _typeQueryAndWait(tester, 'a2b');

    expect(find.text('A2B Restaurant'), findsWidgets);
    await tester.tap(find.text('A2B Restaurant').last);
    await tester.pumpAndSettle();

    expect(restaurants.getByIdCalls, 1);
    expect(restaurants.lastId, 'a2b');
    expect(find.byType(RestaurantDetailsScreen), findsOneWidget);

    final detailsContext = tester.element(find.byType(RestaurantDetailsScreen));
    Navigator.of(detailsContext).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(RestaurantDetailsScreen), findsNothing);
  });

  testWidgets('food result tap opens food details', (tester) async {
    final food = _food();
    final foods = _FakeFoodRepository(food: food);

    await _pumpSearch(
      tester,
      results: const [
        SearchResultEntity(
          id: 'food-a',
          title: 'Mini Meals',
          subtitle: 'A2B Restaurant',
          imageUrl: '',
          type: SearchResultType.food,
          restaurantId: 'a2b',
        ),
      ],
      foodRepo: foods,
    );

    await _typeQueryAndWait(tester, 'meals');

    await tester.tap(find.text('Mini Meals'));
    await tester.pumpAndSettle();

    expect(foods.getByIdCalls, 1);
    expect(find.byType(FoodDetailsScreen), findsOneWidget);
    expect(find.text('Mini Meals'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(FoodDetailsScreen), findsNothing);
  });

  testWidgets('category result tap opens filtered category foods', (
    tester,
  ) async {
    await _pumpSearch(
      tester,
      results: const [],
      categoriesUseCase: GetCategoriesUseCase(
        const _CategoryDashboardRepository([
          Category(
            id: 'cat-pizza',
            name: 'Pizza',
            imageUrl: '',
            isActive: true,
            displayOrder: 1,
          ),
        ]),
      ),
    );

    await _typeQueryAndWait(tester, 'pizza');
    expect(find.byType(SearchResultTile), findsOneWidget);
    await tester.tap(find.byType(SearchResultTile));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryFoodsScreen), findsOneWidget);
    expect(find.text('No foods available'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('restaurant lookup failure stays on search', (tester) async {
    final restaurants = _FakeRestaurantRepository(restaurant: null);

    await _pumpSearch(
      tester,
      results: const [
        SearchResultEntity(
          id: 'missing',
          title: 'Gone Restaurant',
          subtitle: 'Closed',
          imageUrl: '',
          type: SearchResultType.restaurant,
        ),
      ],
      restaurantRepo: restaurants,
    );

    await _typeQueryAndWait(tester, 'gone');
    await tester.tap(find.text('Gone Restaurant'));
    await tester.pumpAndSettle();

    expect(restaurants.getByIdCalls, 1);
    expect(find.byType(RestaurantDetailsScreen), findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('This restaurant is not available.'), findsOneWidget);
  });

  testWidgets('food lookup failure stays on search', (tester) async {
    final foods = _FakeFoodRepository(throwOnGet: true);

    await _pumpSearch(
      tester,
      results: const [
        SearchResultEntity(
          id: 'gone-food',
          title: 'Missing Dish',
          subtitle: 'Somewhere',
          imageUrl: '',
          type: SearchResultType.food,
          restaurantId: 'a2b',
        ),
      ],
      foodRepo: foods,
    );

    await _typeQueryAndWait(tester, 'missing');
    await tester.tap(find.text('Missing Dish'));
    await tester.pumpAndSettle();

    expect(foods.getByIdCalls, 1);
    expect(find.byType(FoodDetailsScreen), findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Unable to open this item.'), findsOneWidget);
  });

  testWidgets('search shows loading while debounce request runs', (
    tester,
  ) async {
    final pending = Completer<List<SearchResultEntity>>();
    final search = _PendingSearchRepository(pending);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          serviceableDeliveryDestinationProvider.overrideWith(
            (ref) async => destinationIn(madurai),
          ),
          searchUseCaseProvider.overrideWithValue(
            SearchUseCase(search, _FakeRestaurantRepository()),
          ),
          getCategoriesUseCaseProvider.overrideWithValue(
            emptyCategoriesUseCase,
          ),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(SearchLoading), findsOneWidget);

    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(NoResultWidget), findsOneWidget);
  });

  testWidgets('search empty state remains when query has no matches', (
    tester,
  ) async {
    await _pumpSearch(tester, results: const []);
    await _typeQueryAndWait(tester, 'zzzz');

    expect(find.byType(NoResultWidget), findsOneWidget);
    expect(find.text('No Results Found'), findsOneWidget);
  });

  testWidgets(
    'search says no restaurants are available when the LOCATION is the reason '
    '(none chosen or not served), not that the words matched nothing',
    (tester) async {
      await _pumpSearch(tester, results: const [], noDestination: true);
      await _typeQueryAndWait(tester, 'pizza');

      expect(
        find.text('Sorry, no restaurants available in this location.'),
        findsOneWidget,
      );
      expect(
        find.text('Try choosing a different delivery location.'),
        findsOneWidget,
      );
      expect(find.text('No Results Found'), findsNothing);
    },
  );

  testWidgets('search debounce still issues a single delayed query', (
    tester,
  ) async {
    final search = _FakeSearchRepository(const []);

    await _pumpSearch(tester, results: const [], searchRepo: search);

    await tester.enterText(find.byType(TextField), 'p');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'pi');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(search.searchAllCalls, 1);
    expect(search.lastQuery, 'pizza');
  });
}
