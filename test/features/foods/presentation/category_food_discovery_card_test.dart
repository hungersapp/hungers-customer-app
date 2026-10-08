import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/foods/presentation/widgets/category_food_discovery_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('left image has finite size and hierarchy content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CategoryFoodDiscoveryCard(
          key: const Key('category-food-card-f1'),
          foodName: 'Veg Meals',
          restaurantName: 'Ammaiappar Hotel',
          description: 'Steamed rice with sambar and two vegetable sides.',
          price: 120,
          distanceLabel: '1.8 km',
          cuisineLabel: 'South Indian',
          onAddTap: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('category-food-card-f1')), findsOneWidget);
    expect(find.byKey(const Key('category-food-image')), findsOneWidget);
    expect(find.text('Ammaiappar Hotel'), findsOneWidget);
    expect(find.text('Veg Meals'), findsOneWidget);
    expect(find.text('1.8 km'), findsOneWidget);
    expect(find.text('South Indian'), findsOneWidget);
    expect(
      find.text('Steamed rice with sambar and two vegetable sides.'),
      findsOneWidget,
    );
    expect(find.text('₹120'), findsOneWidget);
    expect(find.text('ADD'), findsOneWidget);

    final cardBox = tester.getRect(
      find.byKey(const Key('category-food-card-f1')),
    );
    final imageBox = tester.getRect(
      find.byKey(const Key('category-food-image')),
    );
    final restaurantBox = tester.getRect(find.text('Ammaiappar Hotel'));

    expect(imageBox.left, lessThan(restaurantBox.left));
    expect(imageBox.height.isFinite, isTrue);
    expect(imageBox.height, greaterThan(0));
    expect(imageBox.width / cardBox.width, inInclusiveRange(0.35, 0.40));
  });

  testWidgets(
    'lays out inside finite-width unbounded-height ListView (regression)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 2,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const CategoryFoodDiscoveryCard(
                    key: Key('list-card'),
                    foodName: 'Veg Meals',
                    restaurantName: 'Ammaiappar Hotel',
                    description: 'Homestyle meals with sambar.',
                    price: 120,
                    distanceLabel: '1.8 km',
                    cuisineLabel: 'South Indian',
                  );
                }
                return const CategoryFoodDiscoveryCard(
                  key: Key('list-card-2'),
                  foodName: 'Pizza',
                  restaurantName: 'Restaurant B',
                  price: 180,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(IntrinsicHeight), findsNothing);
      expect(find.byKey(const Key('list-card')), findsOneWidget);
      expect(find.byKey(const Key('list-card-2')), findsOneWidget);

      final imageFinder = find.descendant(
        of: find.byKey(const Key('list-card')),
        matching: find.byKey(const Key('category-food-image')),
      );
      final imageSize = tester.getSize(imageFinder);
      expect(imageSize.width.isFinite, isTrue);
      expect(imageSize.height.isFinite, isTrue);
      expect(imageSize.height, greaterThan(0));
    },
  );

  testWidgets('missing description collapses cleanly', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CategoryFoodDiscoveryCard(
          foodName: 'Idli',
          restaurantName: 'Hotel A',
          price: 40,
          distanceLabel: '2.0 km',
          cuisineLabel: 'South Indian',
        ),
      ),
    );

    expect(find.text('Hotel A'), findsOneWidget);
    expect(find.text('Idli'), findsOneWidget);
    expect(find.text('₹40'), findsOneWidget);
    expect(find.textContaining('Steamed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long text does not overflow', (tester) async {
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        fail(details.toString());
      }
      FlutterError.presentError(details);
    };

    await tester.pumpWidget(
      _wrap(
        CategoryFoodDiscoveryCard(
          foodName: 'Extra Long Special Festival Combo Meal With Many Words',
          restaurantName:
              'Very Long Restaurant Name That Should Ellipsize Properly',
          description:
              'A very long description that should wrap to at most two lines and then ellipsize without breaking the card layout on a normal phone width.',
          price: 999,
          distanceLabel: '12 km',
          cuisineLabel:
              'South Indian • Chinese • Continental • Fast Food • Desserts',
          onAddTap: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ADD'), findsOneWidget);
    expect(find.text('₹999'), findsOneWidget);
  });

  testWidgets('ADD action callback fires', (tester) async {
    var added = false;
    await tester.pumpWidget(
      _wrap(
        CategoryFoodDiscoveryCard(
          foodName: 'Burger',
          restaurantName: 'Burger House',
          price: 99,
          onAddTap: () => added = true,
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pump();
    expect(added, isTrue);
  });

  testWidgets('multiple cards render as separate vertical entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: const [
            CategoryFoodDiscoveryCard(
              key: Key('card-a'),
              foodName: 'Pizza A',
              restaurantName: 'Restaurant A',
              price: 150,
            ),
            SizedBox(height: 12),
            CategoryFoodDiscoveryCard(
              key: Key('card-b'),
              foodName: 'Pizza B',
              restaurantName: 'Restaurant B',
              price: 180,
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('card-a')), findsOneWidget);
    expect(find.byKey(const Key('card-b')), findsOneWidget);
    expect(find.text('Restaurant A'), findsOneWidget);
    expect(find.text('Restaurant B'), findsOneWidget);

    final a = tester.getRect(find.byKey(const Key('card-a')));
    final b = tester.getRect(find.byKey(const Key('card-b')));
    expect(b.top, greaterThan(a.bottom));
  });
}
