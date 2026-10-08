import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/app/app_pages.dart';
import 'package:customer_app/app/app_routes.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/foods/presentation/screens/food_details_screen.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_details_provider.dart';
import 'package:customer_app/features/restaurants/presentation/screens/restaurant_details_screen.dart';

RestaurantEntity _restaurant() {
  return RestaurantEntity(
    id: 'a2b',
    name: 'A2B Restaurant',
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: 'Anna Nagar, Madurai',
    latitude: 0,
    longitude: 0,
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

FoodEntity _food({required String id, required String name}) {
  return FoodEntity(
    id: id,
    restaurantId: 'a2b',
    name: name,
    description: '',
    price: 160,
    imageUrl: '',
    category: 'meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: false,
    rating: 4.5,
  );
}

void main() {
  testWidgets(
    'restaurant details stay visible after opening and closing cart',
    (tester) async {
      final restaurant = _restaurant();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            restaurantFoodsProvider.overrideWith(
              (ref, restaurantId) async => [
                _food(id: 'food-a', name: 'Mini Meals'),
                _food(id: 'food-b', name: 'Food B'),
              ],
            ),
          ],
          child: MaterialApp(
            home: RestaurantDetailsScreen(restaurant: restaurant),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A2B Restaurant'), findsOneWidget);
      expect(find.text('Popular Foods'), findsOneWidget);
      expect(find.text('Mini Meals'), findsOneWidget);
      expect(find.text('Food B'), findsOneWidget);

      final context = tester.element(find.byType(RestaurantDetailsScreen));
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.cart),
          builder: (_) => const CartScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(RestaurantDetailsScreen), findsOneWidget);
      expect(find.text('A2B Restaurant'), findsOneWidget);
      expect(find.text('Popular Foods'), findsOneWidget);
      expect(find.text('Mini Meals'), findsOneWidget);
      expect(find.text('Food B'), findsOneWidget);
    },
  );

  test('restaurant-details without arguments does not build a blank route', () {
    final route = AppPages.onGenerateRoute(
      const RouteSettings(name: AppRoutes.restaurantDetails),
    );

    expect(route, isA<MaterialPageRoute<void>>());
    expect(route!.settings.name, AppRoutes.dashboard);
  });

  test('restaurant-details restores the last viewed restaurant', () {
    final restaurant = _restaurant();
    final route = AppPages.onGenerateRoute(
      const RouteSettings(name: AppRoutes.restaurantDetails),
      lastViewedRestaurant: restaurant,
    );

    expect(route, isA<MaterialPageRoute<void>>());
    expect(route!.settings.name, AppRoutes.restaurantDetails);
    expect(route.settings.arguments, restaurant);
  });

  test(
    'restaurant-details with a RestaurantEntity keeps the details screen',
    () {
      final restaurant = _restaurant();
      final route = AppPages.onGenerateRoute(
        RouteSettings(name: AppRoutes.restaurantDetails, arguments: restaurant),
      );

      expect(route, isA<MaterialPageRoute<void>>());
      expect(route!.settings.name, AppRoutes.restaurantDetails);
    },
  );

  test('lastViewedRestaurantProvider stores the opened restaurant', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final restaurant = _restaurant();
    container.read(lastViewedRestaurantProvider.notifier).state = restaurant;

    expect(container.read(lastViewedRestaurantProvider)?.id, 'a2b');
    expect(
      container.read(lastViewedRestaurantProvider)?.name,
      'A2B Restaurant',
    );
  });

  testWidgets('tapping a food card opens food details, not an empty page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final restaurant = _restaurant();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          restaurantFoodsProvider.overrideWith(
            (ref, restaurantId) async => [
              _food(id: 'food-a', name: 'Mini Meals'),
              _food(id: 'food-b', name: 'Food B'),
            ],
          ),
        ],
        child: MaterialApp(
          home: RestaurantDetailsScreen(restaurant: restaurant),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Mini Meals'));
    await tester.tap(find.text('Mini Meals'));
    await tester.pumpAndSettle();

    expect(find.byType(FoodDetailsScreen), findsOneWidget);
    expect(find.text('Food Details'), findsOneWidget);
    expect(find.text('Mini Meals'), findsWidgets);
    expect(find.text('A2B Restaurant'), findsWidgets);
    expect(find.text('Popular Foods'), findsNothing);
  });
}
