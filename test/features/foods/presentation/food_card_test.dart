import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/cart_quantity.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/presentation/widgets/food_card.dart';

FoodEntity _food({
  required String id,
  required String name,
  required double price,
}) {
  return FoodEntity(
    id: id,
    restaurantId: 'a2b',
    name: name,
    description: '',
    price: price,
    imageUrl: '',
    category: 'meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: false,
    rating: 4.5,
  );
}

CartEntity _cartItem({required FoodEntity food, required int quantity}) {
  return CartEntity(
    id: food.id,
    userId: 'user-1',
    restaurantId: food.restaurantId,
    restaurantName: 'A2B',
    foodId: food.id,
    foodName: food.name,
    foodImage: food.imageUrl,
    price: food.price,
    quantity: quantity,
    isVeg: food.isVeg,
    isAvailable: food.isAvailable,
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  final foodA = _food(id: 'food-a', name: 'Mini Meals', price: 160);
  final foodB = _food(id: 'food-b', name: 'Food B', price: 99);

  testWidgets('step 1: both food cards display entity names and prices', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Row(
          children: [
            Expanded(
              child: FoodCard(
                foodName: foodA.name,
                restaurantName: 'A2B',
                showRestaurantName: false,
                price: foodA.finalPrice,
                rating: foodA.rating,
                quantity: 0,
              ),
            ),
            Expanded(
              child: FoodCard(
                foodName: foodB.name,
                restaurantName: 'A2B',
                showRestaurantName: false,
                price: foodB.finalPrice,
                rating: foodB.rating,
                quantity: 0,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('Food B'), findsOneWidget);
    expect(find.text('\u20B9160'), findsOneWidget);
    expect(find.text('\u20B999'), findsOneWidget);
    expect(find.text('ADD'), findsNWidgets(2));
  });

  testWidgets('step 2: ADD on Food A shows stepper only on Food A', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Row(
          children: [
            Expanded(
              child: FoodCard(
                foodName: foodA.name,
                restaurantName: 'A2B',
                showRestaurantName: false,
                price: foodA.finalPrice,
                rating: foodA.rating,
                quantity: 1,
              ),
            ),
            Expanded(
              child: FoodCard(
                foodName: foodB.name,
                restaurantName: 'A2B',
                showRestaurantName: false,
                price: foodB.finalPrice,
                rating: foodB.rating,
                quantity: 0,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('Food B'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('ADD'), findsOneWidget);
  });

  testWidgets('steps 3-6: returning with two cart items keeps both cards', (
    tester,
  ) async {
    final cartItems = [
      _cartItem(food: foodA, quantity: 2),
      _cartItem(food: foodB, quantity: 1),
    ];
    final quantities = CartQuantity.indexByFoodId(cartItems);

    await tester.pumpWidget(
      _wrap(
        Row(
          children: [
            Expanded(
              child: FoodCard(
                foodName: foodA.name,
                restaurantName: 'A2B',
                showRestaurantName: false,
                price: foodA.finalPrice,
                rating: foodA.rating,
                quantity: quantities[foodA.id] ?? 0,
              ),
            ),
            Expanded(
              child: FoodCard(
                foodName: foodB.name,
                restaurantName: 'A2B',
                showRestaurantName: false,
                price: foodB.finalPrice,
                rating: foodB.rating,
                quantity: quantities[foodB.id] ?? 0,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('Food B'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('ADD'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quantity 0 shows ADD and + / - only change that food', (
    tester,
  ) async {
    var quantityA = 0;
    var quantityB = 0;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return Row(
              children: [
                Expanded(
                  child: FoodCard(
                    foodName: foodA.name,
                    restaurantName: 'A2B',
                    showRestaurantName: false,
                    price: foodA.finalPrice,
                    rating: foodA.rating,
                    quantity: quantityA,
                    onAddTap: () => setState(() => quantityA = 1),
                    onIncreaseTap: () => setState(() => quantityA += 1),
                    onDecreaseTap: () => setState(() {
                      quantityA -= 1;
                      if (quantityA < 0) {
                        quantityA = 0;
                      }
                    }),
                  ),
                ),
                Expanded(
                  child: FoodCard(
                    foodName: foodB.name,
                    restaurantName: 'A2B',
                    showRestaurantName: false,
                    price: foodB.finalPrice,
                    rating: foodB.rating,
                    quantity: quantityB,
                    onAddTap: () => setState(() => quantityB = 1),
                    onIncreaseTap: () => setState(() => quantityB += 1),
                    onDecreaseTap: () => setState(() {
                      quantityB -= 1;
                      if (quantityB < 0) {
                        quantityB = 0;
                      }
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('ADD').first);
    await tester.pump();
    expect(quantityA, 1);
    expect(quantityB, 0);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(quantityA, 2);
    expect(quantityB, 0);

    await tester.tap(find.text('ADD'));
    await tester.pump();
    expect(quantityA, 2);
    expect(quantityB, 1);

    await tester.tap(find.byIcon(Icons.remove_rounded).first);
    await tester.pump();
    expect(quantityA, 1);
    expect(quantityB, 1);
  });

  testWidgets('ADD does not navigate when card onTap is set', (tester) async {
    final observer = _PushObserver();
    var added = false;
    var openedDetails = false;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: FoodCard(
            foodName: foodA.name,
            restaurantName: 'A2B',
            showRestaurantName: false,
            price: foodA.finalPrice,
            rating: foodA.rating,
            quantity: 0,
            onTap: () => openedDetails = true,
            onAddTap: () => added = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pump();

    expect(added, isTrue);
    expect(openedDetails, isFalse);
    expect(observer.pushCount, 0);
  });

  testWidgets('card body tap opens details via onTap', (tester) async {
    var openedDetails = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodCard(
            foodName: foodA.name,
            restaurantName: 'A2B',
            showRestaurantName: false,
            price: foodA.finalPrice,
            rating: foodA.rating,
            quantity: 0,
            onTap: () => openedDetails = true,
            onAddTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mini Meals'));
    await tester.pump();

    expect(openedDetails, isTrue);
  });
}

class _PushObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      pushCount += 1;
    }
  }
}
