import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/presentation/widgets/cart_suggestions_section.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';

FoodEntity _food({
  required String id,
  required String name,
  required String restaurantId,
  required double price,
}) {
  return FoodEntity(
    id: id,
    restaurantId: restaurantId,
    name: name,
    description: '',
    price: price,
    imageUrl: '',
    category: 'meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: false,
    rating: 4.2,
  );
}

void main() {
  testWidgets('shows only foods from the same restaurant', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantFoodsProvider.overrideWith((ref, restaurantId) async {
            return [
              _food(
                id: 'food-a',
                name: 'Mini Meals',
                restaurantId: 'a2b',
                price: 160,
              ),
              _food(
                id: 'food-b',
                name: 'Food B',
                restaurantId: 'a2b',
                price: 99,
              ),
              _food(
                id: 'food-other',
                name: 'Other Restaurant Food',
                restaurantId: 'other',
                price: 80,
              ),
            ];
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CartSuggestionsSection(
              userId: 'user-1',
              restaurantId: 'a2b',
              restaurantName: 'A2B Restaurant',
              cartItems: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add more from A2B Restaurant'), findsOneWidget);
    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('Food B'), findsOneWidget);
    expect(find.text('Other Restaurant Food'), findsNothing);
    expect(find.text('ADD'), findsWidgets);
  });
}
