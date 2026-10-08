import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/app/app_pages.dart';
import 'package:customer_app/app/app_routes.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/presentation/screens/food_details_args.dart';
import 'package:customer_app/features/foods/presentation/screens/food_details_screen.dart';

FoodEntity _food() {
  return const FoodEntity(
    id: 'food-a',
    restaurantId: 'a2b',
    name: 'Mini Meals',
    description: 'South Indian thali with rice and sides.',
    price: 160,
    imageUrl: '',
    category: 'meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: true,
    rating: 4.5,
  );
}

void main() {
  testWidgets('food details shows the selected food content', (tester) async {
    final food = _food();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: FoodDetailsScreen(food: food, restaurantName: 'A2B Restaurant'),
        ),
      ),
    );

    expect(find.text('Food Details'), findsOneWidget);
    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('A2B Restaurant'), findsOneWidget);
    expect(
      find.text('South Indian thali with rice and sides.'),
      findsOneWidget,
    );
    expect(find.text('ADD TO CART'), findsOneWidget);
    expect(find.textContaining('160'), findsOneWidget);
  });

  test('food-details route without args does not build a blank route', () {
    final route = AppPages.onGenerateRoute(
      const RouteSettings(name: AppRoutes.foodDetails),
    );

    expect(route, isA<MaterialPageRoute<void>>());
    expect(route!.settings.name, AppRoutes.dashboard);
  });

  test('food-details route with FoodDetailsArgs keeps the details screen', () {
    final food = _food();
    final route = AppPages.onGenerateRoute(
      RouteSettings(
        name: AppRoutes.foodDetails,
        arguments: FoodDetailsArgs(
          food: food,
          restaurantName: 'A2B Restaurant',
        ),
      ),
    );

    expect(route, isA<MaterialPageRoute<void>>());
    expect(route!.settings.name, AppRoutes.foodDetails);
  });
}
