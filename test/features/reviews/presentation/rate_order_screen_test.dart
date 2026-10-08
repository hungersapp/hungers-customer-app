import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';
import 'package:customer_app/features/reviews/domain/submit_order_review_request.dart';
import 'package:customer_app/features/reviews/domain/usecases/submit_order_review_usecase.dart';
import 'package:customer_app/features/reviews/presentation/providers/review_provider.dart';
import 'package:customer_app/features/reviews/presentation/screens/rate_order_screen.dart';
import '../../../helpers/fixed_orders_notifier.dart';

class _FakeReviewDatasource implements ReviewFunctionsDatasource {
  SubmitOrderReviewRequest? lastRequest;
  Object? error;
  int calls = 0;

  @override
  Future<String> submitOrderReview(SubmitOrderReviewRequest request) async {
    calls += 1;
    lastRequest = request;
    if (error != null) {
      throw error!;
    }
    return '${request.orderId}_user-1';
  }
}

PlacedOrder _order() {
  return PlacedOrder(
    id: 'order-1',
    userId: 'user-1',
    restaurantId: 'r1',
    restaurantName: 'A2B',
    grandTotal: 200,
    itemCount: 1,
    createdAt: DateTime(2026, 9, 24),
    status: OrderStatus.delivered,
    items: const [
      OrderLineItem(
        foodId: 'food-1',
        foodName: 'Mini Meals',
        quantity: 1,
        price: 160,
      ),
    ],
  );
}

void main() {
  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('submit is blocked until a star rating is chosen', (
    tester,
  ) async {
    await setTallSurface(tester);
    final datasource = _FakeReviewDatasource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          submitOrderReviewUseCaseProvider.overrideWithValue(
            SubmitOrderReviewUseCase(datasource),
          ),
        ],
        child: MaterialApp(home: RateOrderScreen(order: _order())),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Please select a star rating.'), findsOneWidget);
    expect(datasource.calls, 0);
  });

  testWidgets('successful review shows thanks and returns Reviewed', (
    tester,
  ) async {
    await setTallSurface(tester);
    final datasource = _FakeReviewDatasource();
    final order = _order();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          submitOrderReviewUseCaseProvider.overrideWithValue(
            SubmitOrderReviewUseCase(datasource),
          ),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([order]),
          ),
          orderDetailsProvider.overrideWith((ref, lookup) async => order),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RateOrderScreen(order: order),
                      ),
                    );
                  },
                  child: const Text('Open rate'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open rate'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(datasource.calls, 1);
    expect(datasource.lastRequest?.restaurantRating, 1);
    // The form gives way to the full-screen thank-you…
    expect(find.text('Thank you for your valuable\nfeedback!'), findsOneWidget);
    expect(find.text('🥰'), findsOneWidget);
    expect(find.text('Submit'), findsNothing);

    // …which closes itself and returns to the order.
    await tester.pump(RateOrderScreen.thankYouDuration);
    await tester.pumpAndSettle();
    expect(find.byType(RateOrderScreen), findsNothing);
    expect(find.text('Open rate'), findsOneWidget);
  });

  testWidgets('the thank-you can be closed straight away, reporting success', (
    tester,
  ) async {
    await setTallSurface(tester);
    final datasource = _FakeReviewDatasource();
    final order = _order();
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          submitOrderReviewUseCaseProvider.overrideWithValue(
            SubmitOrderReviewUseCase(datasource),
          ),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([order]),
          ),
          orderDetailsProvider.overrideWith((ref, lookup) async => order),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => RateOrderScreen(order: order),
                      ),
                    );
                  },
                  child: const Text('Open rate'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open rate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_border_rounded).at(3));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(RateOrderScreen), findsNothing);
    expect(result, isTrue);
    expect(datasource.lastRequest?.restaurantRating, 4);
  });

  testWidgets('dish thumbs, detailed review and delivery rating are submitted '
      'with the star rating', (tester) async {
    await setTallSurface(tester);
    final datasource = _FakeReviewDatasource();
    final order = _order();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          submitOrderReviewUseCaseProvider.overrideWithValue(
            SubmitOrderReviewUseCase(datasource),
          ),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([order]),
          ),
          orderDetailsProvider.overrideWith((ref, lookup) async => order),
        ],
        child: MaterialApp(home: RateOrderScreen(order: order)),
      ),
    );

    // Layout from the reference: title, stars, then the three sections with
    // only the dishes open.
    expect(find.text('Meal from A2B'), findsOneWidget);
    expect(find.text('Rate your ordered dishes'), findsOneWidget);
    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('Add a detailed review'), findsOneWidget);
    expect(find.text('Rate your delivery partner'), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));

    await tester.tap(find.byIcon(Icons.star_border_rounded).at(4));
    await tester.pump();
    await tester.tap(find.byTooltip('Liked it'));
    await tester.pump();

    await tester.tap(find.text('Add a detailed review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Great taste'));
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Tell us more about your order (optional)',
      ),
      'Lovely meal',
    );

    await tester.tap(find.text('Rate your delivery partner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_border_rounded).at(2));
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    final request = datasource.lastRequest!;
    expect(request.restaurantRating, 5);
    expect(request.restaurantTags, ['Great taste']);
    expect(request.restaurantComment, 'Lovely meal');
    expect(request.deliveryRating, 3);
    expect(request.foodRatings.single.foodId, 'food-1');
    expect(request.foodRatings.single.rating, 5);

    await tester.pump(RateOrderScreen.thankYouDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('backend failure stays on the form with an error', (
    tester,
  ) async {
    await setTallSurface(tester);
    final datasource = _FakeReviewDatasource()
      ..error = Exception('Unable to submit the review.');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          submitOrderReviewUseCaseProvider.overrideWithValue(
            SubmitOrderReviewUseCase(datasource),
          ),
        ],
        child: MaterialApp(home: RateOrderScreen(order: _order())),
      ),
    );

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(datasource.calls, 1);
    expect(find.byType(RateOrderScreen), findsOneWidget);
    expect(find.textContaining('Unable to submit the review.'), findsOneWidget);
  });

  group('reference details', () {
    Finder starFace() => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_StarFacePainter',
    );

    Future<_FakeReviewDatasource> pumpRate(
      WidgetTester tester, {
      int? initialRating,
      int? initialDeliveryRating,
    }) async {
      await setTallSurface(tester);
      final datasource = _FakeReviewDatasource();
      final order = _order();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            submitOrderReviewUseCaseProvider.overrideWithValue(
              SubmitOrderReviewUseCase(datasource),
            ),
            customerOrdersProvider.overrideWith(
              () => FixedCustomerOrdersNotifier([order]),
            ),
            orderDetailsProvider.overrideWith((ref, lookup) async => order),
          ],
          child: MaterialApp(
            home: RateOrderScreen(
              order: order,
              initialRating: initialRating,
              initialDeliveryRating: initialDeliveryRating,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return datasource;
    }

    testWidgets('the chosen star shows an animated face; the others do not', (
      tester,
    ) async {
      await pumpRate(tester);
      expect(starFace(), findsNothing);

      await tester.tap(find.byIcon(Icons.star_border_rounded).at(1));
      await tester.pump();
      // Mid-animation and settled, exactly one face — on the chosen star.
      await tester.pump(const Duration(milliseconds: 200));
      expect(starFace(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(starFace(), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));

      // Picking another star moves the face there.
      await tester.tap(find.byIcon(Icons.star_border_rounded).last);
      await tester.pumpAndSettle();
      expect(starFace(), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    });

    testWidgets('the star tapped on the order card arrives pre-selected', (
      tester,
    ) async {
      final datasource = await pumpRate(tester, initialRating: 4);

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(datasource.lastRequest?.restaurantRating, 4);
      expect(datasource.lastRequest?.deliveryRating, isNull);
      await tester.pump(RateOrderScreen.thankYouDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('a delivery star tapped on the order card opens the delivery '
        'section with it selected; the order still needs its own rating', (
      tester,
    ) async {
      final datasource = await pumpRate(tester, initialDeliveryRating: 3);

      // Delivery section is open with 3 of its 5 stars filled.
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(
        find.text('Tell us about the delivery (optional)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('Please select a star rating.'), findsOneWidget);
      expect(datasource.calls, 0);

      await tester.tap(find.byIcon(Icons.star_border_rounded).at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(datasource.lastRequest?.restaurantRating, 5);
      expect(datasource.lastRequest?.deliveryRating, 3);
      await tester.pump(RateOrderScreen.thankYouDuration);
      await tester.pumpAndSettle();
    });
  });
}
