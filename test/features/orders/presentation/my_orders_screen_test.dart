import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';
import 'package:customer_app/features/orders/presentation/screens/my_orders_screen.dart';
import 'package:customer_app/features/orders/presentation/screens/order_confirmation_screen.dart';
import 'package:customer_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_details_provider.dart';
import '../../../helpers/fixed_orders_notifier.dart';

PlacedOrder _order({
  required String id,
  OrderStatus status = OrderStatus.placed,
}) {
  return PlacedOrder(
    id: id,
    userId: 'user-1',
    restaurantId: 'a2b',
    restaurantName: 'A2B Restaurant',
    grandTotal: 372.76,
    itemCount: 2,
    createdAt: DateTime(2026, 8, 16, 13, 5),
    status: status,
    itemTotal: 320,
    deliveryFee: 30,
    platformFee: 5,
    gstAmount: 17.76,
    items: const [
      OrderLineItem(
        foodId: 'food-a',
        foodName: 'Mini Meals',
        quantity: 2,
        price: 160,
      ),
    ],
  );
}

void main() {
  testWidgets('empty orders shows the empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([]),
          ),
        ],
        child: const MaterialApp(home: MyOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('Your delicious journey starts here.'), findsOneWidget);
    expect(find.text('Browse Restaurants'), findsOneWidget);
    expect(find.text('Order screen will be soon'), findsNothing);
    expect(find.text('Orders screen coming soon'), findsNothing);
  });

  testWidgets('lists ongoing and past orders from the customer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([
              _order(id: 'ongoing-1'),
              _order(id: 'past-1', status: OrderStatus.delivered),
            ]),
          ),
        ],
        child: const MaterialApp(home: MyOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ongoing Orders'), findsOneWidget);
    expect(find.text('Past Orders'), findsOneWidget);
    expect(find.text('A2B Restaurant'), findsNWidgets(2));
    expect(find.text('Order Placed'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('View Order'), findsNWidgets(2));
    expect(find.text('Reorder'), findsOneWidget);
    expect(find.text('Your Food Rating'), findsOneWidget);
    expect(find.text('Delivery Rating'), findsOneWidget);
    expect(find.text('Track Order'), findsNothing);
  });

  testWidgets('View Order opens order details', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          restaurantDetailsProvider.overrideWith((ref, id) async => null),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([_order(id: 'abc12345xyz')]),
          ),
        ],
        child: const MaterialApp(home: MyOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    expect(find.text('Order #ABC12345'), findsWidgets);
    expect(find.text('TRACK YOUR ORDER'), findsOneWidget);
    expect(find.text('Mini Meals  \u00d7 2'), findsOneWidget);
    expect(find.text('Bill Details'), findsOneWidget);
    await tester.ensureVisible(find.text('Pay on Delivery'));
    expect(find.text('Pay on Delivery'), findsOneWidget);
  });

  testWidgets('delivered order shows inline rating stars that open the rating '
      'screen', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          restaurantDetailsProvider.overrideWith((ref, id) async => null),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([
              _order(id: 'delivered-1', status: OrderStatus.delivered),
            ]),
          ),
        ],
        child: const MaterialApp(home: MyOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tapping the 4th food star opens the rating screen with 4 selected.
    expect(find.text('Your Food Rating'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_border_rounded).at(3));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));

    expect(find.text('Meal from A2B Restaurant'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('confirmation View Order opens the new order details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = _order(id: 'neworder1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          restaurantDetailsProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp(home: OrderConfirmationScreen(order: order)),
      ),
    );

    expect(find.text('Order placed'), findsOneWidget);
    expect(find.text('View Order'), findsOneWidget);
    expect(find.text('My Orders'), findsOneWidget);
    await tester.tap(find.text('View Order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    expect(find.text('A2B Restaurant'), findsOneWidget);
    expect(find.text('Final Payable'), findsOneWidget);
    expect(find.text('TRACK YOUR ORDER'), findsOneWidget);
  });

  testWidgets('View Order opens the tapped order, not a sibling order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          restaurantDetailsProvider.overrideWith((ref, id) async => null),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([
              _order(id: 'aaaa1111first'),
              _order(id: 'bbbb2222scnd'),
            ]),
          ),
        ],
        child: const MaterialApp(home: MyOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View Order'), findsNWidgets(2));
    await tester.tap(find.text('View Order').at(1));
    await tester.pumpAndSettle();

    final details = tester.widget<OrderDetailsScreen>(
      find.byType(OrderDetailsScreen),
    );
    expect(details.orderId, 'bbbb2222scnd');
    expect(find.text('Order #BBBB2222'), findsWidgets);
  });
}
